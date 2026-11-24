extends Node3D

const STREET := preload("res://survey/1350-street.json")
const GRADE := preload("res://survey/grade.gd")
const STONE := preload("res://survey/masonry.gdshader")
const LOOKOUT := Vector3(-391,0,341) # Broadway plaza, southwest of West 35th
const TOWER := Vector3(-352,29,296)
var vestibules: Array[Dictionary] = []

func point(data: Array) -> Vector3:
	return Vector3(data[0],data[1],data[2])

func _ready() -> void:
	var data: Dictionary = STREET.data
	position = point(data.world_origin)
	var mesh: MeshInstance3D = find_children("*","MeshInstance3D",true,false)[0]
	for i in mesh.mesh.get_surface_count():
		var stock := mesh.mesh.surface_get_material(i)
		if stock.resource_name in ["BuffBrick","OfficePanel","IndianaStone"]:
			var material := ShaderMaterial.new()
			material.shader = STONE
			material.set_shader_parameter("brick",stock.resource_name!="IndianaStone")
			material.set_shader_parameter("bond", preload("res://survey/buff-running-bond.png"))
			material.set_shader_parameter("grain",preload("res://winter/frontage/white_sandstone_blocks_02_diffuse.jpg"))
			material.set_shader_parameter("relief",preload("res://winter/frontage/white_sandstone_blocks_02_nor_gl.jpg"))
			mesh.set_surface_override_material(i,material)
		if stock.resource_name in ["Window","BrightGlass","CoolWindow","WarmWindow"]:
			var pane := ShaderMaterial.new()
			pane.shader = preload("res://survey/office_glass.gdshader")
			pane.set_shader_parameter("pane_tint",stock.albedo_color)
			var glow: Color = stock.emission if stock.emission_enabled else Color.BLACK
			pane.set_shader_parameter("room_light",Vector3(glow.r,glow.g,glow.b))
			mesh.set_surface_override_material(i,pane)
		if stock.resource_name == "Granite":
			var granite := stock.duplicate() as StandardMaterial3D
			granite.albedo_color = Color("#c6c1b7")
			granite.uv1_triplanar = true
			granite.uv1_scale = Vector3.ONE * .8
			granite.albedo_texture = preload("res://winter/frontage/granite_tile_03_diffuse.jpg")
			granite.normal_enabled = true
			granite.normal_texture = preload("res://winter/frontage/granite_tile_03_nor_gl.jpg")
			granite.normal_scale = .35
			granite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mesh.set_surface_override_material(i,granite)
		if stock.resource_name=="DisplayGlass":
			var window := StandardMaterial3D.new()
			window.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			window.albedo_color = Color(.34,.47,.50,.27)
			window.roughness = .16
			window.metallic = 0.
			window.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(i,window)
	for fixture: Array in data.bank_lamps:
		var lamp := SpotLight3D.new()
		lamp.position = point(fixture[0])
		add_child(lamp)
		lamp.look_at(to_global(point(fixture[1])))
		lamp.light_color = Color("#ffe2b9")
		lamp.light_energy = 3.0
		lamp.spot_range = 5.4
		lamp.spot_angle = 59.
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 19.
		lamp.distance_fade_length = 12.
	for door: Dictionary in data.doors:
		install_door(door)
	var wall_faces := PackedVector3Array()
	for segment: Array in data.street_walls:
		var a := point(segment[0])
		var b := point(segment[1])
		a.y = GRADE.height(to_global(a))-.35
		b.y = GRADE.height(to_global(b))-.35
		var up := Vector3.UP*5.
		wall_faces.append_array(PackedVector3Array([a,a+up,b+up,a,b+up,b]))
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(wall_faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	$StreetWalls.add_child(collision)
	for entry: Dictionary in data.labels:
		if entry.text == "kiosk crest":
			var pose := Transform3D(Basis(Vector3.UP,entry.yaw),point(entry.at))
			preload("res://signs/shop_sign.gd").mount(self,preload("res://signs/kiosk-crest.png"),pose,entry.height)
			continue
		if entry.text == "Santander":
			var pose := Transform3D(Basis(Vector3.UP,entry.yaw),point(entry.at))
			preload("res://signs/shop_sign.gd").mount(self,preload("res://signs/santander.svg"),pose,entry.height)
			continue
		var sign := Label3D.new()
		sign.text = entry.text
		sign.font_size = 96
		sign.pixel_size = float(entry.height)/96.
		sign.outline_size = 0
		sign.double_sided = false
		sign.modulate = Color("#fff2d7") if entry.text=="1350" else Color("#343330")
		if entry.text == "wafels & dinges": sign.modulate = Color("#bf4834")
		sign.position = point(entry.at)
		sign.rotation.y = entry.yaw
		add_child(sign)
		if sign.text=="1350" and get_parent().has_node("Winter"):
			var lamp := OmniLight3D.new()
			lamp.light_color = Color("#ffdbac")
			lamp.light_energy = 1.55
			lamp.omni_range = 6.2
			lamp.distance_fade_enabled = true
			lamp.distance_fade_begin = 75.
			lamp.position = sign.position+sign.basis.z*.42-Vector3.UP*.60
			add_child(lamp)

func install_door(data: Dictionary) -> void:
	var origin := point(data.at)
	var frame := Node3D.new()
	frame.position = origin
	frame.rotation.y = data.yaw
	add_child(frame)
	var entry := preload("res://revolving_door.gd").new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#968066")
	metal.metallic = .72
	metal.roughness = .35
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://reserve/entrance_glass.gdshader")
	glass.set_shader_parameter("floor_y", frame.global_position.y)
	entry.finishes["rail"] = metal
	entry.finishes["door_glass"] = glass
	entry.position.y = .014-entry.SILL
	frame.add_child(entry)
	var foot_surface := ConcavePolygonShape3D.new()
	var floor_faces := PackedVector3Array()
	var edges: Array = data.floor
	for i in edges.size()-1:
		var a := point(edges[i][0])
		var b := point(edges[i][1])
		var c := point(edges[i+1][1])
		var d := point(edges[i+1][0])
		floor_faces.append_array(PackedVector3Array([a,c,b,a,d,c]))
	foot_surface.backface_collision = true
	foot_surface.set_faces(floor_faces)
	var col := CollisionShape3D.new()
	col.shape = foot_surface
	$VestibuleFloors.add_child(col)
	var housing := CylinderMesh.new()
	housing.top_radius = entry.RADIUS+.025
	housing.bottom_radius = housing.top_radius
	housing.height = .13
	housing.radial_segments = 48
	housing.rings = 0
	var cap := MeshInstance3D.new()
	cap.mesh = housing
	cap.material_override = metal
	cap.position.y = entry.HEAD-entry.SILL+.077
	frame.add_child(cap)
	vestibules.append({"frame":frame,"width":data.width,"depth":data.depth,"mouth":.842-float(data.front)})

func walking_height(world: Vector3, legacy: float) -> float:
	if not GRADE.contains(world): return legacy
	var grade := GRADE.physical_height(get_world_3d().direct_space_state,world,legacy)
	for entry in vestibules:
		var frame: Node3D = entry.frame
		var p := frame.to_local(world)
		var inside := float(entry.mouth)-p.z
		if absf(p.x)<float(entry.width)*.5 and inside>0. and inside<float(entry.depth):
			return lerpf(grade,frame.global_position.y+.014,smoothstep(0.,.65,inside))
	return grade
