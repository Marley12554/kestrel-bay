extends Node3D

@onready var camera: Camera3D = $Camera
var speed_mph := 95.0
var yaw := 0.0
var pitch := 0.0
var web: JavaScriptObject
var look_finger := -1
var dragging := false
var frames := 0

func _ready() -> void:
	camera.position = Vector3(520, 535, 940)
	camera.look_at(Vector3(-90, 95, -220))
	yaw = camera.rotation.y
	pitch = camera.rotation.x
	if OS.has_feature("web"):
		web = JavaScriptBridge.get_interface("window")
		_resize()
		get_window().size_changed.connect(_resize)
	get_window().focus_exited.connect(_release)

func _resize() -> void:
	var pixels := get_window().size
	get_viewport().scaling_3d_scale = minf(1.0, sqrt(2100000.0 / (float(pixels.x) * pixels.y)))

func _release() -> void:
	look_finger = -1
	dragging = false

func look(delta: Vector2) -> void:
	yaw -= delta.x * .0026
	pitch = clampf(pitch - delta.y * .0026, -1.53, 1.53)
	camera.rotation = Vector3(pitch, yaw, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and look_finger == -1:
			look_finger = event.index
		elif not event.pressed and event.index == look_finger:
			look_finger = -1
	elif event is InputEventScreenDrag and event.index == look_finger:
		look(event.screen_relative)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or dragging or (web and bool(web.midtownLocked)):
			look(event.screen_relative)

func _process(dt: float) -> void:
	var dir := Vector3.ZERO
	if not web or not bool(web.midtownInControls):
		dir.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		dir.z = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		dir.y = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if web:
		speed_mph = float(web.midtownSpeed)
		dir += Vector3(float(web.midtownX), float(web.midtownY), float(web.midtownZ))
	var motion := camera.global_basis.x * dir.x + camera.global_basis.z * dir.z + Vector3.UP * dir.y
	camera.position += motion.limit_length(1.0) * speed_mph * .44704 * minf(dt, .1)
	camera.position = camera.position.clamp(Vector3(-1350, 1.7, -1500), Vector3(1350, 1800, 1500))
	frames += 1
	if web and (frames == 2 or frames % 15 == 0):
		web.midtownReady = true
		web.midtownCamera = "%.2f,%.2f,%.2f,%.3f,%.3f" % [camera.position.x, camera.position.y, camera.position.z, yaw, pitch]
