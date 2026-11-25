extends SceneTree

func _initialize() -> void:
	for name in ["sam","harper","jordan","maya"]:
		var model: Node = load("res://people/"+name+".glb").instantiate()
		root.add_child(model)
		var player: AnimationPlayer = model.find_children("*","AnimationPlayer",true,false)[0]
		var library := player.get_animation_library("")
		var walks: AnimationLibrary=load("res://people/"+name+"-walks.res")
		for clip in walks.get_animation_list():
			library.add_animation("Street"+str(clip),walks.get_animation(clip))
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_scene(model,state)!=OK or doc.write_to_filesystem(state,OS.get_environment("FIFTH_STAGING")+"/"+name+".glb")!=OK:
			quit(1)
			return
		model.free()
	quit()
