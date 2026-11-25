extends SceneTree
## Run in the existing Godot preview to capture the authored runtime transforms.
var batches := {}
var palette := {}
var points := {}
var prototypes := {}
var instances := {}
var doors: Array = []
var routes: Array = []
var out: String

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	out = OS.get_environment("FIFTH_STAGING")
	DirAccess.make_dir_recursive_absolute(out)
	var scene = load("res://winter/night.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var block = scene.get_node("Block")
	var excluded: Array = [block.parked, block.cross_taxi, block.taxi]
	for w in block.walkers:
		excluded.append(w.node)
		var path := []
		for k in w.path.size():
			var xy: Vector2 = w.path[posmod(w.segment+k*w.step,w.path.size())]+w.offset
			path.append(vec(block.to_global(Vector3(xy.x,0,xy.y))))
		routes.append({"model":w.node.variant,"pace":w.pace,"position":vec(w.node.global_position),"path":path})
	var moving: Array = []
	for entry in get_nodes_in_group("revolving_doors"):
		moving.append([entry.rotor,"Revolving"])
	if block.reserve and block.reserve.get("door"):
		moving.append([block.reserve.door,"Swing"])
	for item in moving: excluded.append(item[0])
	collect(block, Transform3D.IDENTITY, excluded)
	save_mesh("AvenueStreet")
	for pair in [["Sedan",block.parked_visual], ["YellowCab",block.cab_visual]]:
		var body: Node3D = pair[1]
		collect(body.model, body.global_transform.affine_inverse(), [])
		save_mesh(pair[0])
	var wheel_centers := []
	var sedan=block.parked_visual
	var sedan_local: Transform3D=sedan.global_transform.affine_inverse()
	collect(sedan.model,sedan_local,sedan.wheels)
	save_mesh("SedanHull")
	for index in sedan.wheels.size():
		var wheel: Node3D=sedan.wheels[index]
		var center: Vector3=sedan_local*wheel.global_position
		wheel_centers.append(vec(center))
		var no_translation := Transform3D(Basis.IDENTITY,-center)
		collect(wheel,no_translation*sedan_local,[])
		save_mesh("SedanWheel"+str(index))
	var herald = scene.get_node("HeraldSquare")
	for child in herald.get_children():
		if child.name != "OfficeAndRetail":
			collect(child, Transform3D.IDENTITY, excluded)
	save_mesh("HeraldDetails")
	var winter=scene.get_node("Winter")
	# The city-wide snow height field is represented by UE terrain materials.
	# Capture the hand-placed lamps, displays and street hardware separately.
	collect(winter,Transform3D.IDENTITY,[winter.pack,winter.sidewalks])
	save_mesh("WinterStreet")
	var shop=block.reserve
	shop.cup.show()
	shop.grip.hide()
	collect(shop.cup,shop.cup.global_transform.affine_inverse(),[],false)
	save_mesh("Coffee")
	shop.grip.show()
	collect(shop.cup,shop.cup.global_transform.affine_inverse(),[],false)
	save_mesh("CoffeeHand")
	var lamps := []
	for light in winter.find_children("*","Light3D",true,false):
		if light is OmniLight3D or light is SpotLight3D:
			lamps.append([vec(light.global_position),[light.light_color.r,light.light_color.g,light.light_color.b],light.light_energy,light.omni_range if light is OmniLight3D else light.spot_range])
	var counter=shop.to_global(shop.COUNTER+Vector3(.34,1.23,-.14))
	var barista=shop.server.global_position

	for index in moving.size():
		var part: Node3D = moving[index][0]
		var label := "Door"+str(index)
		collect(part,part.global_transform.affine_inverse(),[],false)
		save_mesh(label)
		doors.append({"asset":label,"kind":moving[index][1],"pose":matrix(part.global_transform)})
	for mesh in prototypes:
		var obj := MeshInstance3D.new()
		obj.mesh=mesh
		obj.name=prototypes[mesh]
		for i in mesh.get_surface_count():
			append(mesh,i,Transform3D.IDENTITY,mesh.surface_get_material(i),Color.WHITE)
		save_mesh(prototypes[mesh])
		obj.free()
	var roads := []
	for curve in [block.route,block.cross_route]:
		var path := []
		for v in curve.get_baked_points(): path.append(vec(block.to_global(v)))
		roads.append(path)
	var f = FileAccess.open(out+"/placement.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"car":vec(block.parked.global_position),"car_forward":vec(-block.parked.global_basis.z),"player":vec(scene.get_node("Walker").global_position) if scene.has_node("Walker") else vec(block.parked.global_position+Vector3(4,0,0)), "labels":points,"instances":instances,"doors":doors,"walkers":routes,"traffic":roads,"wheel_centers":wheel_centers,"lamps":lamps,"counter":vec(counter),"barista":vec(barista)}))
	f.close()
	print("FIFTH EXPORT COMPLETE")
	quit()

func vec(v: Vector3) -> Array:
	return [v.x,v.y,v.z]

func matrix(t: Transform3D) -> Array:
	return [vec(t.origin),vec(t.basis.x),vec(t.basis.y),vec(t.basis.z)]

func collect(node: Node, origin: Transform3D, excluded: Array, instance_parts: bool=true) -> void:
	if node in excluded or node is Skeleton3D or node is Camera3D: return
	if node is Node3D and not node.visible: return
	if node is MeshInstance3D and node.mesh and node.skin == null:
		for i in node.mesh.get_surface_count():
			append(node.mesh,i,origin*node.global_transform,node.get_active_material(i),Color.WHITE)
	elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
		var m: MultiMesh = node.multimesh
		if instance_parts:
			if not prototypes.has(m.mesh): prototypes[m.mesh]="Fixture"+str(prototypes.size())
			var label: String=prototypes[m.mesh]
			if not instances.has(label): instances[label]=[]
			for j in m.instance_count:
				var pose: Transform3D = origin*node.global_transform*m.get_instance_transform(j)
				if absf(pose.basis.determinant())<.0000001: continue
				var color := m.get_instance_color(j) if m.use_colors else Color.WHITE
				var override_mat = node.material_override
				if override_mat is StandardMaterial3D:
					color *= override_mat.albedo_color
				elif override_mat is ShaderMaterial:
					for param in ["base_color","pane_tint","stone_color","tint"]:
						var value = override_mat.get_shader_parameter(param)
						if value is Color:
							color *= value
							break
				instances[label].append([matrix(pose),[color.r,color.g,color.b],m.use_colors or override_mat!=null])
			return
		for j in m.instance_count:
			var tint := m.get_instance_color(j) if m.use_colors else Color.WHITE
			for i in m.mesh.get_surface_count():
				append(m.mesh,i,origin*node.global_transform*m.get_instance_transform(j),m.mesh.surface_get_material(i),tint)
	elif node is Label3D:
		points[str(node.get_path())] = [node.text, vec(node.global_position),vec(node.global_basis.z.normalized()),node.font_size*node.pixel_size]
	elif node is Sprite3D and node.texture:
		var quad := QuadMesh.new()
		quad.size = node.texture.get_size()*node.pixel_size
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = node.texture
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		append(quad,0,origin*node.global_transform,mat,Color.WHITE)
	for child in node.get_children(): collect(child,origin,excluded,instance_parts)

func append(mesh: Mesh, idx: int, pose: Transform3D, material: Material, tint: Color) -> void:
	var mat: StandardMaterial3D
	if material is StandardMaterial3D:
		mat=material
	else:
		var key := str(material.get_instance_id()) if material else "default"
		if not palette.has(key):
			var replacement := StandardMaterial3D.new()
			replacement.albedo_color = Color(.56,.53,.48)
			if material is ShaderMaterial:
				for parameter in material.shader.get_shader_uniform_list():
					var value = material.get_shader_parameter(parameter.name)
					if value is Texture2D and parameter.name in ["grain","stone","albedo_tex","albedo_texture","brick","diffuse"]:
						replacement.albedo_texture = value
					if value is Color and parameter.name in ["tint","base_color","stone_color","pane_tint"]:
						replacement.albedo_color = value
			palette[key]=replacement
		mat=palette[key]
	if tint != Color.WHITE:
		var key := str(mat.get_instance_id())+tint.to_html()
		if not palette.has(key):
			var dyed := mat.duplicate() as StandardMaterial3D
			dyed.albedo_color = tint * mat.albedo_color
			palette[key]=dyed
		mat=palette[key]
	if not batches.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)
		batches[mat]=st
	batches[mat].append_from(mesh,idx,pose)

func save_mesh(label: String) -> void:
	if batches.is_empty(): return
	var scene := Node3D.new()
	# Split sections to stay below the ArrayMesh surface limit.
	var mesh := ArrayMesh.new()
	for mat in batches:
		if mesh.get_surface_count() % 64 == 0:
			mesh=ArrayMesh.new()
			var obj := MeshInstance3D.new()
			obj.name=label+str(scene.get_child_count())
			obj.mesh=mesh
			scene.add_child(obj)
			obj.owner=scene
		batches[mat].commit(mesh)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(scene,state)
	if err == OK: err=doc.write_to_filesystem(state,out+"/"+label+".glb")
	if err != OK:
		push_error("Export failed "+label)
		quit(1)
	print("EXPORTED ",label," materials ",batches.size())
	batches.clear()
	scene.free()
