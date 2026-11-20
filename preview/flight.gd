extends Node3D

@onready var camera: Camera3D = $Camera
var speed_mph := 95.0
var yaw := 0.0
var pitch := 0.0
var web: JavaScriptObject
var look_finger := -1
var dragging := false
var frames := 0
var last_move_usec := 0
const METRES_PER_SECOND_PER_MPH := 0.44704
const MIN_HEIGHT := 1.7
const MAX_HEIGHT := 1800.0

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
	get_window().focus_entered.connect(_reset_clock)

func _reset_clock() -> void:
	last_move_usec = 0

func _resize() -> void:
	var pixels := get_window().size
	get_viewport().scaling_3d_scale = minf(1.0, sqrt(2100000.0 / (float(pixels.x) * pixels.y)))

func _release() -> void:
	_reset_clock()
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

func _process(_dt: float) -> void:
	# Engine delta can omit elapsed time at low frame rates. Free flight has no physics steps.
	var now := Time.get_ticks_usec()
	var elapsed := (now - last_move_usec) / 1_000_000.0 if last_move_usec != 0 else 0.0
	last_move_usec = now
	var dir := Vector3.ZERO
	if not web or not bool(web.midtownInControls):
		dir.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		dir.z = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		dir.y = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if web:
		speed_mph = float(web.midtownSpeed)
		dir += Vector3(float(web.midtownX), float(web.midtownY), float(web.midtownZ))
	var motion := camera.global_basis.x * dir.x + camera.global_basis.z * dir.z + Vector3.UP * dir.y
	if (camera.position.y <= MIN_HEIGHT + 0.001 and motion.y < 0.0) or (camera.position.y >= MAX_HEIGHT - 0.001 and motion.y > 0.0):
		motion.y = 0.0
	camera.position += motion.normalized() * speed_mph * METRES_PER_SECOND_PER_MPH * elapsed
	camera.position = camera.position.clamp(Vector3(-1350, MIN_HEIGHT, -1500), Vector3(1350, MAX_HEIGHT, 1500))
	frames += 1
	if web and (frames == 2 or frames % 15 == 0):
		web.midtownReady = true
		web.midtownCamera = "%.2f,%.2f,%.2f,%.3f,%.3f" % [camera.position.x, camera.position.y, camera.position.z, yaw, pitch]
