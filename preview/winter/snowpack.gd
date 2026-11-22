extends Node3D

const FIELD: Image = preload("res://winter/snowpack.res")
const ORIGIN := Vector2(-240,-136)
const SUPPORT_Y := [0.,.1524,.2124,preload("res://winter/sidewalk_snow.gd").CURB_TOP]
const TILE := 8
const PIXELS_PER_METRE := 40
const MASK_SIZE := TILE*PIXELS_PER_METRE
const MAX_COMPRESSION := .36

var coarse := PlaneMesh.new()
var detailed := PlaneMesh.new()
var materials: Array[ShaderMaterial]=[]
var batches := {} # Tile key -> original MultiMesh and instance index.
var tracks := {} # Retained CPU pressure masks, including after leaving the street.
var visible_tracks := {}
var refresh_in := 0.
var pressure_revision := 0

func _ready() -> void:
	coarse.size=Vector2(TILE,TILE)
	coarse.subdivide_width=31
	coarse.subdivide_depth=31
	detailed.size=coarse.size
	detailed.subdivide_width=239
	detailed.subdivide_depth=239
	var pack_texture:=ImageTexture.create_from_image(FIELD)
	var template := ShaderMaterial.new()
	template.shader = preload("res://winter/snowpack.gdshader")
	preload("res://survey/grade.gd").bind_surface(template)
	for level in SUPPORT_Y.size():
		var m := template.duplicate() as ShaderMaterial
		m.set_shader_parameter("pack_depth",pack_texture)
		m.set_shader_parameter("grain_map",preload("res://winter/assets/snow_02_nor_gl.jpg"))
		m.set_shader_parameter("powder_map",preload("res://winter/assets/snow_02_Diffuse.jpg"))
		m.set_shader_parameter("support",level)
		m.set_shader_parameter("support_plane",SUPPORT_Y[level])
		materials.append(m)
	var sectors:={}
	for v in FIELD.get_meta("tiles"):
		var key:=Vector3i(v)
		var sector:=Vector3i(floori(key.x/4.),key.y,floori(key.z/4.))
		if not sectors.has(sector): sectors[sector]=[]
		sectors[sector].append(key)
	for keys: Array in sectors.values():
		var batch:=MultiMesh.new()
		batch.transform_format=MultiMesh.TRANSFORM_3D
		batch.mesh=coarse
		batch.instance_count=keys.size()
		for index in keys.size():
			var key:Vector3i=keys[index]
			batch.set_instance_transform(index,tile_transform(key))
			batches[key]=[batch,index]
		var view:=MultiMeshInstance3D.new()
		view.multimesh=batch
		view.material_override=materials[keys[0].y]
		view.extra_cull_margin=8.0 # Includes the surveyed elevation of snow at the edge of the old block.
		add_child(view)

func tile_transform(key: Vector3i) -> Transform3D:
	return Transform3D(Basis.IDENTITY,Vector3((key.x+.5)*TILE,SUPPORT_Y[key.y],(key.z+.5)*TILE))

func surface_at(p: Vector2) -> Vector2:
	# X is the support index, Y is the uncompressed snow thickness in metres.
	var uv:=(p-ORIGIN)*4.-Vector2(.5,.5)
	var a:=Vector2i(uv.floor())
	if a.x<0 or a.y<0 or a.x+1>=FIELD.get_width() or a.y+1>=FIELD.get_height():
		return Vector2(-1,0)
	var f:=uv-uv.floor()
	var center:=FIELD.get_pixelv(Vector2i(uv.round()))
	var index: int=-1
	for level in 4:
		if center[level]>.001: index=level; break
	if index<0: return Vector2(-1,0)
	var lo:=FIELD.get_pixelv(a).lerp(FIELD.get_pixel(a.x+1,a.y),f.x)
	var hi:=FIELD.get_pixel(a.x,a.y+1).lerp(FIELD.get_pixel(a.x+1,a.y+1),f.x)
	return Vector2(index,maxf(0.,(lo.lerp(hi,f.y)[index]*255.-1.)*(.36/254.)))

func tile_at(p:Vector2,level:int) -> Vector3i:
	return Vector3i(floori(p.x/TILE),level,floori(p.y/TILE))

func remaining(p:Vector2,surface:Vector2) -> float:
	var key:=tile_at(p,int(surface.x))
	if not tracks.has(key): return surface.y
	var texel:=Vector2i(((p-Vector2(key.x,key.z)*TILE)*PIXELS_PER_METRE).floor())
	var mask: Image=tracks[key]
	return surface.y-minf(surface.y*.94,mask.get_pixelv(texel).r*MAX_COMPRESSION)

func stamp(p:Vector2,forward:Vector2,left:bool,effort:float) -> void:
	var side:=Vector2(-forward.y,forward.x)
	var center:=p+side*(-.103 if left else .103)
	var surface:=surface_at(center)
	if surface.y<.003: return
	var lo:=Vector2i(((center-Vector2.ONE*.195)*PIXELS_PER_METRE).floor())
	var hi:=Vector2i(((center+Vector2.ONE*.195)*PIXELS_PER_METRE).ceil())
	var dirty:={}
	for y in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var sample:=(Vector2(x,y)+Vector2(.5,.5))/PIXELS_PER_METRE
			var d:=sample-center
			var along:=d.dot(forward)
			var across:=d.dot(side)*(1. if left else -1.)
			# Toe, narrower arch, and heel have distinct contact surfaces.
			var toe:=Vector2((across+.006)/.054,(along-.062)/.096).length()
			var heel:=Vector2(across/.043,(along+.095)/.057).length()
			var arch:=Vector2((across-.020)/.029,(along+.018)/.075).length()
			var sole:=1.-smoothstep(.66,1.13,minf(toe,minf(heel,arch)))
			if sole<=0.: continue
			var key:=tile_at(sample,int(surface.x))
			if not batches.has(key): continue
			if not tracks.has(key):
				tracks[key]=Image.create_empty(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_L8)
			var mask: Image=tracks[key]
			var pixel:=Vector2i(posmod(x,MASK_SIZE),posmod(y,MASK_SIZE))
			var tread:=.82+.18*cos((along+.35*absf(across))*145.)
			var pressure:=sole*tread*lerpf(.73,.97,effort)*(.10/MAX_COMPRESSION)
			mask.set_pixelv(pixel,Color.WHITE*maxf(pressure,mask.get_pixelv(pixel).r))
			dirty[key]=true
	flush_pressure(dirty)

# Paint the swept rectangle in world units. Read the actual snow support for
# each cross-section so a track follows its wheel across the curb and tile seams.
func press_strip(from: Vector2, to: Vector2, half_width: float, underside_y: float, dirty: Dictionary) -> void:
	var travel := to - from
	var forward := travel.normalized()
	if forward == Vector2.ZERO: return
	var across := forward.orthogonal()
	var steps := maxi(1, ceili(travel.length()/.12))
	var step_length := travel.length()/steps
	var extent := across.abs()*half_width + forward.abs()*(step_length*.5)
	for i in steps:
		var at := from + travel*((i+.5)/steps)
		var surface := surface_at(at)
		if surface.y < .003: continue
		var amount := surface.y*.78
		if underside_y > 0.:
			amount = clampf(SUPPORT_Y[int(surface.x)] + surface.y - underside_y, 0., surface.y)
		if amount < .003: continue
		var lo := Vector2i(((at-extent)*PIXELS_PER_METRE).floor())
		var hi := Vector2i(((at+extent)*PIXELS_PER_METRE).ceil())
		for y in range(lo.y,hi.y):
			for x in range(lo.x,hi.x):
				var delta := (Vector2(x,y)+Vector2(.5,.5))/PIXELS_PER_METRE-at
				var lateral := absf(delta.dot(across))
				if lateral>=half_width or absf(delta.dot(forward))>step_length*.5: continue
				var key := Vector3i(floori(float(x)/MASK_SIZE),int(surface.x),floori(float(y)/MASK_SIZE))
				if not batches.has(key): continue
				if not tracks.has(key):
					tracks[key]=Image.create_empty(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_L8)
				var mask: Image=tracks[key]
				var pixel := Vector2i(posmod(x,MASK_SIZE),posmod(y,MASK_SIZE))
				var pressure := amount/MAX_COMPRESSION*(1.-smoothstep(half_width*.80,half_width,lateral))
				if pressure <= mask.get_pixelv(pixel).r+.002: continue
				mask.set_pixelv(pixel,Color.WHITE*pressure)
				dirty[key]=true

func flush_pressure(dirty: Dictionary) -> void:
	if dirty.is_empty(): return
	pressure_revision += 1
	for key: Vector3i in dirty:
		if visible_tracks.has(key):
			var texture: ImageTexture=visible_tracks[key].material_override.get_shader_parameter("pressure")
			texture.update(tracks[key])
		else: show_track(key)

func show_track(key: Vector3i) -> void:
	var view:=MeshInstance3D.new()
	view.mesh=detailed
	view.transform=tile_transform(key)
	view.extra_cull_margin=8.0 # Includes the surveyed elevation of snow at the edge of the old block.
	var m:=materials[key.y].duplicate() as ShaderMaterial
	m.set_shader_parameter("pressure",ImageTexture.create_from_image(tracks[key]))
	view.material_override=m
	# Move just this batch instance below the street. The separate mesh
	# now represents the same snow with enough vertices to indent a boot.
	var slot:Array=batches[key]
	var hidden:=view.transform
	hidden.origin.y-=2.
	slot[0].set_instance_transform(slot[1],hidden)
	add_child(view)
	visible_tracks[key]=view

func _process(dt: float) -> void:
	refresh_in-=dt
	if refresh_in>0.: return
	refresh_in=.25
	var camera:=get_viewport().get_camera_3d()
	if not camera: return
	var at:=to_local(camera.global_position)
	for key: Vector3i in visible_tracks.keys():
		var node:MeshInstance3D=visible_tracks[key]
		var distance:=at.distance_to(node.position)
		if distance>30.:
			var slot:Array=batches[key]
			slot[0].set_instance_transform(slot[1],tile_transform(key))
			node.queue_free()
			visible_tracks.erase(key)
		else:
			node.mesh=detailed if distance<12. else coarse
	var center:=tile_at(Vector2(at.x,at.z),0)
	if at.y>22.: return
	for z in range(center.z-2,center.z+3):
		for x in range(center.x-2,center.x+3):
			for level in 4:
				var key:=Vector3i(x,level,z)
				if tracks.has(key) and not visible_tracks.has(key) and at.distance_squared_to(tile_transform(key).origin)<24.*24.:
					show_track(key)
