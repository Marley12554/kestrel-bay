extends SceneTree
## Run in the existing Godot preview to capture the authored runtime transforms.
var batches := {}
var palette := {}
var points := {}
var fixture_finishes := {}
var prototypes := {}
var instances := {}
var doors: Array = []
var routes: Array = []
var out: String
var live_finishes := {}

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	out = OS.get_environment("FIFTH_STAGING")
	DirAccess.make_dir_recursive_absolute(out)
	if "--snow-data-only" in OS.get_cmdline_user_args():
		write_ground_samples()
		quit()
		return
	if DisplayServer.get_name()=="headless":
		push_error("Street export requires a render device. The headless dummy renderer discards MultiMesh instance transforms.")
		quit(1)
		return
	if "--cab-only" in OS.get_cmdline_user_args():
		var cab := preload("res://town_car.gd").new()
		cab.build(true,false)
		root.add_child(cab)
		write_cab_parts(cab)
		quit()
		return
	write_ground_samples()
	export_grade()
	var scene = load("res://winter/night.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var block = scene.get_node("Block")
	var winter = scene.get_node("Winter")
	live_finishes[winter.hot_glass] = "StreetLampGlass"
	live_finishes[winter.signal_lenses] = "TeslaIndicator"
	live_finishes[winter.headlight_lenses] = "TeslaHeadlamp"
	for key: Vector2i in block.signal_materials:
		live_finishes[block.signal_materials[key]] = "Traffic%d%d" % [key.x,key.y]
	for across: bool in block.pedestrian_materials:
		live_finishes[block.pedestrian_materials[across]] = "Pedestrian%d" % int(across)
	var flag: MeshInstance3D = block.find_child("AvenueFlag",true,false)
	if flag: live_finishes[flag.get_active_material(0)] = "AvenueFlagCloth"
	var shop = block.reserve
	# In Godot the walking controller supplies this floor height analytically.
	# Unreal walks on collision, so export the same top face under the terrazzo.
	var floor_pose: Transform3D = shop.global_transform * Transform3D(Basis.from_scale(Vector3(shop.WIDTH,.12,shop.DEPTH+.8)),Vector3(shop.WIDTH*.5,.095,-shop.DEPTH*.5+.40))
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
	var fixed_shapes := [matrix(floor_pose)]
	for parent in [block, scene.get_node("HeraldSquare")]:
		for col in parent.find_children("*","CollisionShape3D",true,false):
			if col.disabled or not col.get_parent() is StaticBody3D: continue
			var mobile := false
			for part in excluded:
				if part == col.get_parent() or part.is_ancestor_of(col): mobile = true
			if mobile: continue
			var form: Shape3D = col.shape
			var surface: Mesh
			if form is BoxShape3D:
				fixed_shapes.append(matrix(col.global_transform*Transform3D(Basis.from_scale(form.size),Vector3.ZERO)))
			elif form is ConcavePolygonShape3D:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				for vertex in form.get_faces(): st.add_vertex(vertex)
				surface = st.commit()
			elif form is CylinderShape3D:
				var tube := CylinderMesh.new()
				tube.top_radius=form.radius
				tube.bottom_radius=form.radius
				tube.height=form.height
				surface=tube
			if surface: append(surface,0,col.global_transform,null,Color.WHITE)
	save_mesh("StreetCollision")
	collect(block, Transform3D.IDENTITY, excluded)
	save_mesh("AvenueStreet")
	for pair in [["Sedan",block.parked_visual], ["YellowCab",block.cab_visual]]:
		var body: Node3D = pair[1]
		collect(body.model, body.global_transform.affine_inverse(), [])
		save_mesh(pair[0])
	write_cab_parts(block.cab_visual)
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
	# The city-wide snow height field is represented by UE terrain materials.
	# Capture the hand-placed lamps, displays and street hardware separately.
	collect(winter,Transform3D.IDENTITY,[winter.pack,winter.sidewalks])
	save_mesh("WinterStreet")
	shop.cup.show()
	shop.grip.hide()
	collect(shop.cup,shop.cup.global_transform.affine_inverse(),[],false)
	save_mesh("Coffee")
	shop.grip.show()
	collect(shop.cup,shop.cup.global_transform.affine_inverse(),[],false)
	save_mesh("CoffeeHand")
	var lamps := []
	for light in scene.find_children("*","Light3D",true,false):
		if (light is OmniLight3D or light is SpotLight3D) and light.is_visible_in_tree():
			lamps.append([vec(light.global_position),[light.light_color.r,light.light_color.g,light.light_color.b],light.light_energy,light.omni_range if light is OmniLight3D else light.spot_range,vec(-light.global_basis.z),light.spot_angle if light is SpotLight3D else 0.,light.shadow_enabled])
	var counter=shop.to_global(shop.COUNTER+Vector3(.34,1.23,-.14))
	var barista=shop.server.global_position
	var block_state := {
		"shop":matrix(shop.global_transform), "barista_forward":vec(-shop.server.global_basis.z),
		"brew_start":vec(shop.to_global(shop.COUNTER+Vector3(-.47,1.23,-.14))),
		"held_pose":matrix(Transform3D(Basis.from_euler(Vector3(-.06,-.22,-.09)),Vector3(.18,-.19,-.47))),
		"traffic_stops":[[block.cross_stop],[block.south_stop,block.north_return_stop]],
		"flag_across":vec(flag.global_basis.x.normalized()) if flag else [],
		"flag_out":vec(flag.global_basis.z.normalized()) if flag else [],
	}
	var state_file := FileAccess.open(out+"/block_state.json",FileAccess.WRITE)
	state_file.store_string(JSON.stringify(block_state))
	state_file.close()
	winter.pack.FIELD.save_png(out+"/FifthSnow.png")
	block.WALK_ICON.get_image().save_png(out+"/CrossingWalk.png")
	block.HAND_ICON.get_image().save_png(out+"/CrossingHand.png")

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
	var finish_kinds := {}
	var swatch := BoxMesh.new()
	for finish in fixture_finishes:
		if finish is ShaderMaterial and finish.shader.resource_path.ends_with("/finish.gdshader"):
			finish_kinds[fixture_finishes[finish]]="Marble" if finish.get_shader_parameter("marble") else "Terrazzo"
		append(swatch,0,Transform3D.IDENTITY,finish,Color.WHITE)
	save_mesh("FixtureFinishes")
	var unique_poses := {}
	for rows in instances.values():
		for row in rows: unique_poses[str(row[0])]=true
	if unique_poses.size()<28000:
		push_error("Missing street instance poses: "+str(unique_poses.size())+" unique transforms")
		quit(1)
		return
	print("Verified ",unique_poses.size()," distinct fixture transforms")
	var roads := []
	for curve in [block.route,block.cross_route]:
		var path := []
		for v in curve.get_baked_points(): path.append(vec(block.to_global(v)))
		roads.append(path)
	var f = FileAccess.open(out+"/placement.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"finish_kinds":finish_kinds,"fixed_shapes":fixed_shapes,"car":vec(block.parked.global_position),"car_forward":vec(-block.parked.global_basis.z),"player":vec(scene.get_node("Walker").global_position) if scene.has_node("Walker") else vec(block.parked.global_position+Vector3(4,0,0)), "labels":points,"instances":instances,"doors":doors,"walkers":routes,"traffic":roads,"wheel_centers":wheel_centers,"lamps":lamps,"counter":vec(counter),"barista":vec(barista)}))
	f.close()
	print("FIFTH EXPORT COMPLETE")
	quit()

func write_cab_parts(cab) -> void:
	var origin: Transform3D=cab.global_transform.affine_inverse()
	collect(cab.model,origin,cab.wheels)
	save_mesh("CabBody")
	var hubs := []
	for i in cab.wheels.size():
		var wheel: Node3D=cab.wheels[i]
		var hub: Vector3=origin*wheel.global_position
		hubs.append(vec(hub))
		collect(wheel,Transform3D(Basis.IDENTITY,-hub)*origin,[])
		save_mesh("CabWheel"+str(i))
	FileAccess.open(out+"/cab_hubs.json",FileAccess.WRITE).store_string(JSON.stringify(hubs))

func write_ground_samples() -> void:
	# Gameplay uses the very same source samples as the pavement material.
	var field: Image = (load("res://winter/snowpack.res") as Image).duplicate()
	field.convert(Image.FORMAT_RGBA8)
	var rgba := field.get_data()
	var samples := PackedByteArray()
	samples.resize(field.get_width()*field.get_height())
	for i in samples.size():
		samples[i]=maxi(maxi(rgba[4*i],rgba[4*i+1]),maxi(rgba[4*i+2],rgba[4*i+3]))
	var drifts: Image=load("res://winter/snow_depth.png").get_image()
	drifts.convert(Image.FORMAT_L8)
	var roads: Image=(load("res://meshes/road_mask.res") as BitMap).convert_to_image()
	roads.convert(Image.FORMAT_L8)
	roads.save_png(out+"/FifthRoads.png")
	samples.append_array(drifts.get_data())
	samples.append_array(roads.get_data())
	var target:=FileAccess.open(out+"/FifthGround.bin",FileAccess.WRITE)
	for size in [field.get_size(),drifts.get_size(),roads.get_size()]:
		target.store_32(size.x)
		target.store_32(size.y)
	target.store_buffer(samples.compress(FileAccess.COMPRESSION_DEFLATE))

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
				var finish_name := ""
				if override_mat and not m.use_colors:
					if not fixture_finishes.has(override_mat):
						fixture_finishes[override_mat]="Finish%03d" % fixture_finishes.size()
					finish_name=fixture_finishes[override_mat]
				elif override_mat is StandardMaterial3D:
					color *= override_mat.albedo_color
				instances[label].append([matrix(pose),[color.r,color.g,color.b],m.use_colors,finish_name])
			return
		for j in m.instance_count:
			var tint := m.get_instance_color(j) if m.use_colors else Color.WHITE
			for i in m.mesh.get_surface_count():
				append(m.mesh,i,origin*node.global_transform*m.get_instance_transform(j),node.material_override if node.material_override else m.mesh.surface_get_material(i),tint)
	elif node is Label3D:
		points[str(node.get_path())] = [node.text, vec(node.global_position),vec(node.global_basis.z.normalized()),node.font_size*node.pixel_size]
	elif node is Sprite3D and node.texture:
		var quad := QuadMesh.new()
		quad.size = node.texture.get_size()*node.pixel_size
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = node.texture
		mat.albedo_color = node.modulate
		var face: Mesh=quad
		if node.region_enabled:
			var region: Rect2 = node.region_rect
			quad.size=region.size*node.pixel_size
			# Preserve the crop in the mesh UVs. Material UV transforms are lost
			# on import, and an existing material keeps its original texture.
			var arrays:=quad.surface_get_arrays(0)
			var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for k in uvs.size(): uvs[k]=(region.position+uvs[k]*region.size)/Vector2(node.texture.get_size())
			arrays[Mesh.ARRAY_TEX_UV]=uvs
			var cropped:=ArrayMesh.new()
			cropped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			face=cropped
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		append(face,0,origin*node.global_transform,mat,Color.WHITE)
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
	if material is ShaderMaterial and ("glazing" in material.shader.resource_path or "entrance_glass" in material.shader.resource_path):
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mat.albedo_color=Color(.48,.62,.65,.32)
		mat.roughness=.14
	if live_finishes.has(material): mat.resource_name=live_finishes[material]
	elif fixture_finishes.has(material): mat.resource_name=fixture_finishes[material]
	elif mat.vertex_color_use_as_albedo: mat.resource_name="EnamelVertex"
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

# Match the exact cell diagonal and vertical datum of the surveyed road surface.
# The outer ring connects the level's flat surroundings to its zero-height collar.
func export_grade() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out+"/grade.json"))
	var n := int(data.samples)
	var scale_px := int(data.curb_pixels_per_metre)
	var width := (n-1)*scale_px
	var raw := Marshalls.base64_to_raw(data.navd88_cm).decompress(2*n*n, FileAccess.COMPRESSION_DEFLATE)
	var curb := Marshalls.base64_to_raw(data.surface_cm).decompress(width*width, FileAccess.COMPRESSION_DEFLATE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(-1,n+1):
		for col in range(-1,n+1):
			var i := clampi(col,0,n-1)
			var j := clampi(row,0,n-1)
			var edge := mini(mini(i,j),n-1-maxi(i,j))
			var cm := raw.decode_s16(2*(j*n+i))-curb[mini(j*scale_px,width-1)*width+mini(i*scale_px,width-1)]
			var h := (cm*.01-float(data.datum_navd88_m))*smoothstep(0.,float(data.collar),edge)
			var x := float(data.origin_en[0]-data.godot_origin_en[0])+i
			var z := float(data.godot_origin_en[1]-data.origin_en[1])-j
			if col==-1: x=-1075.
			if col==n: x=1075.
			if row==-1: z=1225.
			if row==n: z=-1225.
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(x,h-.065,z))
			if row>=0 and col>=0:
				var d := (row+1)*(n+2)+col+1
				var a := d-(n+2)-1
				for k in [a,d,a+1,a,d-1,d]: st.add_index(k)
	append(st.commit(),0,Transform3D.IDENTITY,null,Color.WHITE)
	save_mesh("GradedBase")
