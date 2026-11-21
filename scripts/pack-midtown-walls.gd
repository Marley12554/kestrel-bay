extends SceneTree
func _initialize() -> void:
	var walls := ResourceLoader.load(ProjectSettings.globalize_path("res://../dist/midtown-source/walls.tres"))
	if not walls:
		quit(1)
		return
	quit(ResourceSaver.save(walls, "res://meshes/footprints.res", ResourceSaver.FLAG_COMPRESS))
