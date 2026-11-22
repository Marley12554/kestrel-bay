extends SceneTree

func _initialize() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var source := ProjectSettings.globalize_path("res://../dist/midtown-source/midtown.glb")
	if doc.append_from_file(source, state) != OK:
		quit(1)
		return
	var city := doc.generate_scene(state)
	if not city:
		quit(1)
		return
	var grade_surface := PackedVector3Array()
	for instance in city.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var material: StandardMaterial3D = instance.mesh.surface_get_material(surface)
			material.vertex_color_use_as_albedo = true
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				if colors[indices[i]].a < .9:
					for j in 3: grade_surface.append(instance.transform * vertices[indices[i+j]])
	if grade_surface.is_empty():
		push_error("Draped survey pavement is missing")
		city.free()
		quit(1)
		return
	var pavement := ConcavePolygonShape3D.new()
	pavement.backface_collision = true
	pavement.set_faces(grade_surface)
	if ResourceSaver.save(pavement,"res://survey/pavement.res",ResourceSaver.FLAG_COMPRESS) != OK:
		city.free()
		quit(1)
		return
	var scene := PackedScene.new()
	if scene.pack(city) != OK:
		quit(1)
		return
	var result := ResourceSaver.save(scene, "res://meshes/midtown.scn", ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	city.free()
	quit(0 if result == OK else 1)
