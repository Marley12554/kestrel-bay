extends Node3D

var frame := Transform3D.IDENTITY
var pieces := {}
var finishes := {}
var cube := BoxMesh.new()
var pipe := CylinderMesh.new()
var glazing := QuadMesh.new()

var meshes := {}
var brushed := {}
var edge_mesh: ArrayMesh

func prepare_geometry() -> void:
	pipe.top_radius=.5
	pipe.bottom_radius=.5
	pipe.height=1.0
	pipe.radial_segments=12
	pipe.rings=1
	meshes={"box":cube,"round":pipe,"pane":glazing}
	define_materials()

func material(key: String, color: String, roughness: float, metal:=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=Color(color)
	m.roughness=roughness
	m.metallic=metal
	finishes[key]=m
	return m

# A unit block with a recessed perimeter behind its front face. All instances
# share this mesh, including short cut bricks and metal window sections.
func bevel_block(inset_x: float, inset_y: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var loop := [Vector2(-.5,-.5),Vector2(-.5,.5),Vector2(.5,.5),Vector2(.5,-.5)]
	var rings: Array[PackedVector3Array] = []
	for z in [-.5,.32,.5]:
		var ring := PackedVector3Array()
		for corner: Vector2 in loop:
			var v := corner
			if z == .5: v -= corner.sign()*Vector2(inset_x,inset_y)
			ring.append(Vector3(v.x,v.y,z))
		rings.append(ring)
	var faces := [[rings[0][3],rings[0][2],rings[0][1],rings[0][0]], Array(rings[2])]
	for j in 2:
		for i in 4:
			var k := (i+1)%4
			faces.append([rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i]])
	for face: Array in faces:
		var normal: Vector3 = (face[2]-face[0]).cross(face[1]-face[0]).normalized()
		for i in [0,1,2,0,2,3]:
			surface.set_normal(normal)
			surface.add_vertex(face[i])
	return surface.commit()

func define_materials() -> void:
	for key in ["limestone","granite"]:
		var stone:=ShaderMaterial.new()
		stone.shader=preload("res://winter/frontage_stone.gdshader")
		stone.set_shader_parameter("polished",key=="granite")
		var stem: String="res://winter/frontage/"+("granite_tile_03" if key=="granite" else "white_sandstone_blocks_02")
		stone.set_shader_parameter("grain",load(stem+"_diffuse.jpg"))
		stone.set_shader_parameter("relief",load(stem+"_nor_gl.jpg"))
		finishes[key]=stone
	material("sash","#654038",.36,.43)
	material("steel","#bac2c2",.24,.8)
	material("brass","#bb945a",.30,.72)
	material("reveal","#353936",.68)
	material("wood","#624d3d",.65)
	material("bottle","#315e55",.26,.15)
	material("paper","#d7c7a3",.83)
	material("stone_inlay","#928778",.40,.1)
	material("slate","#253138",.72)
	material("shade","#9b977f",.91)
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://winter/frontage_glazing.gdshader")
	finishes["glass"] = glass
	var opal:=material("opal","#d5c5a6",.36)
	opal.emission_enabled=true
	opal.emission=Color("#ffe1a9")
	opal.emission_energy_multiplier=1.6

func piece(key: String, at: Vector3, size: Vector3, rotation:=Vector3.ZERO, shape: String="box") -> void:
	var group:=key+"/"+shape
	if not pieces.has(group): pieces[group]=[]
	pieces[group].append(frame*Transform3D(Basis.from_euler(rotation).scaled_local(size),at))

func bar(a: Vector3,b: Vector3,thick: float, key: String) -> void:
	var d:=b-a
	var rot:=Quaternion(Vector3.UP,d.normalized()).get_euler()
	piece(key,(a+b)*.5,Vector3(thick,d.length(),thick),rot,"round")

func pane(x: float,y: float,z: float,w: float,h: float) -> void:
	piece("glass",Vector3(x,y,z),Vector3(w,h,1),Vector3.ZERO,"pane")

func collider(at: Vector3, size: Vector3) -> void:
	var shape:=BoxShape3D.new()
	shape.size=size
	var col:=CollisionShape3D.new()
	col.shape=shape
	var body:=StaticBody3D.new()
	body.transform=frame*Transform3D(Basis.IDENTITY,at)
	body.add_child(col)
	add_child(body)

func shop_sign(texture: Texture2D, at: Vector3, height: float, tint := Color.WHITE, region := Rect2()) -> void:
	preload("res://signs/shop_sign.gd").mount(self, texture, frame.translated_local(at), height, tint, region)

func lettering(words: String,at: Vector3,height: float,color:=Color("#ebc58c")) -> void:
	var text:=Label3D.new()
	text.text=words
	text.font_size=96
	text.pixel_size=height/96.
	text.outline_size=0
	text.double_sided=false
	text.modulate=color
	text.transform=frame*Transform3D(Basis.IDENTITY,at)
	add_child(text)

func assemble(parent: Node3D = null) -> void:
	if parent == null: parent=self
	for group: String in pieces:
		var bits:=group.split("/")
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=meshes[bits[1]]
		multi.instance_count=pieces[group].size()
		for i in multi.instance_count:
			multi.set_instance_transform(i,pieces[group][i])
		var view:=MultiMeshInstance3D.new()
		view.multimesh=multi
		view.material_override=finishes[bits[0]]
		if bits[0] in ["brass","steel","iron","copper","shopmetal","bronze"]:
			var stock := finishes[bits[0]] as StandardMaterial3D
			if stock:
				if not brushed.has(bits[0]):
					var finish := ShaderMaterial.new()
					finish.shader = preload("res://winter/frontage_metal.gdshader")
					finish.set_shader_parameter("tint",stock.albedo_color)
					finish.set_shader_parameter("rough",stock.roughness)
					brushed[bits[0]]=finish
				view.material_override=brushed[bits[0]]
				if bits[1]=="box":
					if not edge_mesh: edge_mesh=bevel_block(.014,.014)
					multi.mesh=edge_mesh
		if bits[0] in ["glass","entry_glass"]: view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(view)
	pieces.clear()
