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
	for instance in city.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var material: StandardMaterial3D = instance.mesh.surface_get_material(surface)
			material.vertex_color_use_as_albedo = true
	var scene := PackedScene.new()
	if scene.pack(city) != OK:
		quit(1)
		return
	var result := ResourceSaver.save(scene, "res://meshes/midtown.scn", ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	city.free()
	quit(0 if result == OK else 1)
