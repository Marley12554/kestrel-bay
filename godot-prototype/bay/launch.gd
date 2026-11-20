extends Control
const CITY_PATH="res://bay/islands.tscn"
func _ready():
	$Classic.pressed.connect(func():OS.shell_open(JavaScriptBridge.eval("new URL('./classic/', location.href).href")) if OS.has_feature("web") else null)
	if OS.has_feature("web"):JavaScriptBridge.eval("if(new URLSearchParams(location.search).has('qa'))window.kbBootStages=['opening']")
	open_city.call_deferred()
func open_city():
	await get_tree().process_frame
	var city=ResourceLoader.load(CITY_PATH) as PackedScene
	if city:
		var node=city.instantiate()
		if node and node.has_method("start_test"):
			get_tree().change_scene_to_node(node)
			return
		if node:node.free()
	$Status.text="The city could not load on this device."
	$Classic.visible=OS.has_feature("web")
	push_error("Could not instantiate "+CITY_PATH)
