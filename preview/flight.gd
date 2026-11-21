extends Node3D

@export var survey_material: ShaderMaterial
@onready var block = $Block
@onready var walker: CharacterBody3D = $Walker
var driving := false
var can_enter_car := false
@onready var camera: Camera3D = $Camera
@onready var body: Node3D = $Body
var return_view: Transform3D
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
	for tile in $Survey.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = tile.global_transform * tile.get_aabb()
		if bounds.grow(360).has_point(block.global_position):
			tile.material_override = survey_material
	walker.global_position = block.to_global(Vector3(93.1,.15,-31.5))
	camera.position = walker.position + Vector3.UP * MIN_HEIGHT
	camera.look_at(block.to_global(Vector3(65.5,5.8,-1.5)))
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
	if driving: return
	yaw -= delta.x * .0026
	pitch = clampf(pitch - delta.y * .0026, -1.53, 1.53)
	camera.rotation = Vector3(pitch, yaw, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		toggle_body()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if not body.visible: interact()
	elif event is InputEventScreenTouch:
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

func toggle_body() -> void:
	if driving:
		return
	if body.visible:
		camera.transform = return_view
		body.hide()
	else:
		return_view = camera.transform
		body.position = camera.position - Vector3.UP * MIN_HEIGHT
		body.rotation.y = yaw
		body.show()
		var offset := body.basis * Vector3(1.5, 2.65, 2.8)
		if absf(body.position.x + offset.x) > 1350:
			offset.x *= -1
		if absf(body.position.z + offset.z) > 1500:
			offset.z *= -1
		camera.position = body.position + offset
		camera.position.y = minf(camera.position.y, MAX_HEIGHT)
		camera.look_at(body.position + Vector3.UP * 1.0)
	yaw = camera.rotation.y
	pitch = camera.rotation.x
	_reset_clock()
	update_hud()

func _process(_dt: float) -> void:
	if web and bool(web.midtownToggleBody):
		web.midtownToggleBody = false
		toggle_body()
	# Engine delta can omit elapsed time at low frame rates. Free flight has no physics steps.
	var now := Time.get_ticks_usec()
	var elapsed := (now - last_move_usec) / 1_000_000.0 if last_move_usec != 0 else 0.0
	last_move_usec = now
	if web and bool(web.midtownInteract):
		web.midtownInteract = false
		interact()
	if body.visible:
		if web: speed_mph = float(web.midtownSpeed)
		fly(input_direction(), elapsed)
	elif not driving:
		camera.position = walker.position + Vector3.UP * MIN_HEIGHT
	var near_car: bool = walker.position.distance_to(block.parked.global_position) < 5.8 and not body.visible
	if near_car != can_enter_car:
		can_enter_car = near_car
		update_hud()
	frames += 1
	if web and (frames == 2 or frames % 15 == 0):
		web.midtownReady = true
		web.midtownCamera = "%.2f,%.2f,%.2f,%.3f,%.3f" % [camera.position.x, camera.position.y, camera.position.z, yaw, pitch]

func input_direction() -> Vector3:
	var dir := Vector3.ZERO
	if not web or not bool(web.midtownInControls):
		dir.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		dir.z = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		dir.y = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if web:
		dir += Vector3(float(web.midtownX), float(web.midtownY), float(web.midtownZ))
	return dir

func fly(dir: Vector3, elapsed: float) -> void:
	var motion := camera.global_basis.x * dir.x + camera.global_basis.z * dir.z + Vector3.UP * dir.y
	if (camera.position.y <= MIN_HEIGHT + 0.001 and motion.y < 0.0) or (camera.position.y >= MAX_HEIGHT - 0.001 and motion.y > 0.0):
		motion.y = 0.0
	camera.position += motion.normalized() * speed_mph * METRES_PER_SECOND_PER_MPH * elapsed
	camera.position = camera.position.clamp(Vector3(-1350, MIN_HEIGHT, -1500), Vector3(1350, MAX_HEIGHT, 1500))


func update_hud() -> void:
	if web: web.midtownStreetMode("drive" if driving else ("fly" if body.visible else "walk"), can_enter_car)

func interact() -> void:
	if body.visible: return
	if driving:
		if absf(block.driver_speed)>1.1: return
		var side: Vector3 = block.parked.global_basis.x
		var exit_at: Vector3 = block.parked.global_position + side*1.65
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = $Walker/Shape.shape
		params.collision_mask = 3
		var space := get_world_3d().direct_space_state
		var clear := false
		for offset in [side, -side, block.parked.global_basis.z*1.8]:
			exit_at = block.parked.global_position + offset*1.65
			params.transform = Transform3D(Basis.IDENTITY, exit_at + Vector3.UP*.94)
			if space.intersect_shape(params,1).is_empty():
				clear = true
				break
		if not clear: return
		walker.global_position = Vector3(exit_at.x,.15,exit_at.z)
		driving = false
		block.driver_speed=0
		pitch=0
		yaw=block.parked.global_rotation.y
		camera.rotation=Vector3(pitch,yaw,0)
	elif walker.position.distance_to(block.parked.global_position)<5.8:
		driving=true
	block.driven=driving
	update_hud()

func _physics_process(dt: float) -> void:
	if driving:
		var dir:=input_direction()
		block.drive(dt,-dir.z,dir.x)
		var car: Transform3D=block.parked.global_transform
		camera.position=car*Vector3(0,3.4,6.6)
		camera.look_at(car*Vector3(0,.93,-4))
	elif not body.visible:
		var input:=input_direction()
		var flat:=Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.z).limit_length(1.0)
		walker.velocity=flat*(3.0*METRES_PER_SECOND_PER_MPH)
		walker.move_and_slide()
	block.street_user=block.to_local(walker.global_position)
