extends Node3D

const GRADE := preload("res://survey/grade.gd")

@export var survey_material: ShaderMaterial
@onready var block = $Block
@onready var walker: CharacterBody3D = $Walker
var driving := false
var brake_pressed := false
var turn_signal_direction := 0
var signal_start_yaw := 0.0
var signal_turned := false
var airborne := false
var jump_requested := false
var vertical_speed := 0.0
const JUMP_SPEED := 3.35
const GRAVITY := 9.81
var previous_steer_key := 0
var steer_key_seconds := 0.0
var can_enter_car := false
var orbit_yaw := 0.0
const CHASE_PITCH := .31
const CAMERA_CLEARANCE := .25
var orbit_pitch := CHASE_PITCH
var camera_probe := SphereShape3D.new()
var manual_look := 0.0
var drive_audio := preload("res://drive_audio.gd").new()
var gear_readout := Label.new()
@onready var camera: Camera3D = $Camera
@onready var body: Node3D = $Body
var pilot_return: Transform3D
var pilot_return_feet: Vector3
var at_pilot := false
var return_view: Transform3D
var speed_mph := 95.0
var yaw := 0.0
var pitch := 0.0
var web: JavaScriptObject
var look_finger := -1
@onready var crosshair: Label = $Overlay/Crosshair
var hud_visible := true
var frames := 0
var warmup_frame := -1
var street_view: Transform3D
var last_move_usec := 0
const METRES_PER_SECOND_PER_MPH := 0.44704
@onready var stride = $Stride
@onready var revolving_doors := get_tree().get_nodes_in_group("revolving_doors")
var motion_setting := 2
const MIN_HEIGHT := 1.7
const MAX_HEIGHT := 1800.0

func _ready() -> void:
	camera_probe.radius = CAMERA_CLEARANCE
	block.parked.add_child(drive_audio)
	$Overlay.add_child(gear_readout)
	gear_readout.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	gear_readout.offset_left=-165
	gear_readout.offset_top=-100
	gear_readout.offset_right=-24
	gear_readout.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	gear_readout.add_theme_constant_override("outline_size",5)
	gear_readout.add_theme_font_size_override("font_size",22)
	gear_readout.hide()
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
		warmup_frame = 0
		set_motion_level(int(web.midtownMotionLevel))
		_resize()
		get_window().size_changed.connect(_resize)
	elif not DisplayServer.is_touchscreen_available() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_window().focus_exited.connect(_release)
	get_window().focus_entered.connect(_reset_clock)

func _reset_clock() -> void:
	last_move_usec = 0

func _resize() -> void:
	var pixels := get_window().size
	var budget := 900000.0 if OS.has_feature("web_ios") or OS.has_feature("web_android") else 2100000.0
	get_viewport().scaling_3d_scale = minf(1.0, sqrt(budget / maxf(1.0, float(pixels.x) * pixels.y)))

func _release() -> void:
	_reset_clock()
	look_finger = -1
	jump_requested = false
	if not web:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func look(delta: Vector2) -> void:
	if driving:
		orbit_yaw-=delta.x*.0034
		orbit_pitch=clampf(orbit_pitch+delta.y*.0025,-PI*.5,PI*.5)
		manual_look=1.5
		return
	yaw -= delta.x * .0026
	pitch = clampf(pitch - delta.y * .0026, -1.53, 1.53)
	camera.rotation = Vector3(pitch, yaw, 0)

func _unhandled_input(event: InputEvent) -> void:
	if warmup_frame >= 0: return
	if not web and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_V, KEY_ESCAPE]:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not web and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		set_motion_level((motion_setting + 2) % 3)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		visit_pilot()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		toggle_body()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if not body.visible: interact()
	elif driving and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		select_signal(1 if event.physical_keycode == KEY_RIGHT else -1)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		if not driving and not body.visible: jump_requested = true
	elif event is InputEventScreenTouch:
		if event.pressed and look_finger == -1:
			look_finger = event.index
		elif not event.pressed and event.index == look_finger:
			look_finger = -1
	elif event is InputEventScreenDrag and event.index == look_finger:
		look(event.screen_relative)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if not web and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if mouse_captured():
			look(event.screen_relative)

func visit_pilot() -> void:
	if driving or body.visible: return
	if at_pilot:
		walker.global_position = pilot_return_feet
		camera.global_transform = pilot_return
	else:
		pilot_return = camera.global_transform
		pilot_return_feet = walker.global_position
		var at: Vector3 = $HeraldSquare.LOOKOUT
		at.y = GRADE.height(at)
		walker.global_position = at
		camera.global_position = at + Vector3.UP*MIN_HEIGHT
		camera.look_at($HeraldSquare.TOWER)
	yaw = camera.rotation.y
	pitch = camera.rotation.x
	walker.velocity = Vector3.ZERO
	airborne = false
	jump_requested = false
	vertical_speed = 0.
	stride.reset()
	at_pilot = not at_pilot

func set_motion_level(level: int) -> void:
	motion_setting = clampi(level, 0, 2)
	stride.strength = [0.0, 0.45, 1.0][motion_setting]

func mouse_captured() -> bool:
	return bool(web.midtownLocked) if web else Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func toggle_body() -> void:
	if driving:
		return
	stride.reset()
	walker.velocity = Vector3.ZERO
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
	if warmup_frame >= 0:
		warm_street_views()
		return
	crosshair.visible = mouse_captured() and not driving and (not bool(web.midtownHudHidden) if web else hud_visible)
	if web and int(web.midtownMotionLevel) != motion_setting:
		set_motion_level(int(web.midtownMotionLevel))
	if web and bool(web.midtownToggleBody):
		web.midtownToggleBody = false
		toggle_body()
	# Engine delta can omit elapsed time at low frame rates. Free flight has no physics steps.
	var now := Time.get_ticks_usec()
	var elapsed := (now - last_move_usec) / 1_000_000.0 if last_move_usec != 0 else 0.0
	last_move_usec = now
	if web and bool(web.midtownJump):
		web.midtownJump = false
		if not driving and not body.visible: jump_requested = true
	if web and int(web.midtownSignal) != 0:
		if driving: select_signal(signi(int(web.midtownSignal)))
		web.midtownSignal = 0
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
		web.midtownCamera = "%.2f,%.2f,%.2f,%.3f,%.3f" % [camera.position.x, camera.position.y, camera.position.z, yaw, pitch]
		if frames == 2:
			web.midtownReady = true

# WebGL compiles material and light combinations on first draw. Show the block
# and its first crossing from each side while the opaque loader is still up.
func warm_street_views() -> void:
	if warmup_frame == 0:
		street_view = camera.transform
	if warmup_frame == 16:
		camera.transform = street_view
		warmup_frame = -1
		return
	camera.transform = street_view
	var along_sidewalk := -street_view.basis.z.slide(Vector3.UP).normalized()
	if warmup_frame < 4:
		camera.rotate_y(warmup_frame * PI / 2.0)
	elif warmup_frame < 12:
		# On the approach, the sedan, shop windows and streetlights overlap.
		camera.position += along_sidewalk * 8.0
		camera.rotate_y((warmup_frame - 4) * PI / 4.0)
	else:
		camera.position += along_sidewalk * 35.0
		camera.rotate_y((warmup_frame - 12) * PI / 2.0)
	warmup_frame += 1

func input_direction() -> Vector3:
	var dir := Vector3.ZERO
	if not web or not bool(web.midtownInControls):
		dir.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		dir.z = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		dir.y = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if web:
		dir += Vector3(float(web.midtownX), float(web.midtownY), float(web.midtownZ))
	return dir

func select_signal(direction: int) -> void:
	turn_signal_direction = 0 if turn_signal_direction == direction else direction
	signal_start_yaw = block.parked.global_rotation.y
	signal_turned = false

func drive_from_input(dt: float) -> void:
	var accelerator := 0.0
	var brake := 0.0
	var turn := 0.0
	var handbrake := false
	var steer_key := 0
	if not web or not bool(web.midtownInControls):
		accelerator = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		brake = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		handbrake = Input.is_physical_key_pressed(KEY_SHIFT)
		var left := Input.is_physical_key_pressed(KEY_A)
		var right := Input.is_physical_key_pressed(KEY_D)
		steer_key = int(right) - int(left)
	if steer_key == 0 or steer_key != previous_steer_key:
		steer_key_seconds = 0.0
	previous_steer_key = steer_key
	if steer_key != 0:
		steer_key_seconds += dt
		# A digital tap trims the line at highway speed. Holding the same
		# direction builds to full lock. Handbraking keeps its immediate response.
		var highway := smoothstep(32., 72., absf(block.driver_speed) / METRES_PER_SECOND_PER_MPH)
		var held := smoothstep(.045, .51, steer_key_seconds)
		var strength := 1.0 if handbrake else lerpf(1.0, lerpf(.055, 1., held), highway)
		turn = float(steer_key) * strength
	if web:
		var pedals := clampf(float(web.midtownZ), -1.0, 1.0)
		accelerator = maxf(accelerator, -pedals)
		brake = maxf(brake, pedals)
		turn += float(web.midtownX)
	brake_pressed = handbrake or (brake > 0 and (not block.backing or accelerator > 0)) or (block.backing and accelerator > 0)
	var throttle := -brake if brake > 0.0 else accelerator
	block.drive(dt, throttle, turn, not (accelerator > 0.0 and brake > 0.0), handbrake)
	if turn_signal_direction != 0:
		var turn_angle := -turn_signal_direction * angle_difference(signal_start_yaw, block.parked.global_rotation.y)
		signal_turned = signal_turned or (turn_angle > deg_to_rad(28.) and not block.backing)
		if signal_turned and absf(turn) < .1 and absf(block.steer) < .035:
			turn_signal_direction = 0
	drive_audio.update(block.driver_speed, block.side_accel, dt, block.backing, block.drift_angle, block.rear_snow_cover)

func fly(dir: Vector3, elapsed: float) -> void:
	var motion := camera.global_basis.x * dir.x + camera.global_basis.z * dir.z + Vector3.UP * dir.y
	if (camera.position.y <= MIN_HEIGHT + 0.001 and motion.y < 0.0) or (camera.position.y >= MAX_HEIGHT - 0.001 and motion.y > 0.0):
		motion.y = 0.0
	camera.position += motion.normalized() * speed_mph * METRES_PER_SECOND_PER_MPH * elapsed
	camera.position = camera.position.clamp(Vector3(-1350, MIN_HEIGHT, -1500), Vector3(1350, MAX_HEIGHT, 1500))
	camera.position.y = maxf(camera.position.y, GRADE.height(camera.position)+MIN_HEIGHT)


func update_hud() -> void:
	if web: web.midtownStreetMode("drive" if driving else ("fly" if body.visible else "walk"), can_enter_car)

func interact() -> void:
	if body.visible: return
	if not driving and block.reserve.interact(): return
	if driving:
		if absf(block.driver_speed)>.15: return
		var side: Vector3 = block.parked.global_basis.x
		var exit_at: Vector3 = block.parked.global_position + side*1.65
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = $Walker/Shape.shape
		params.collision_mask = 3
		var space := get_world_3d().direct_space_state
		var clear := false
		for offset in [side, -side, block.parked.global_basis.z*1.8]:
			exit_at = block.parked.global_position + offset*1.65
			exit_at.y = GRADE.height(exit_at,.15)
			params.transform = Transform3D(Basis.IDENTITY, exit_at + Vector3.UP*.94)
			if space.intersect_shape(params,1).is_empty():
				clear = true
				break
		if not clear: return
		walker.global_position = exit_at
		driving = false
		brake_pressed = false
		turn_signal_direction = 0
		drive_audio.park()
		gear_readout.hide()
		block.shift_wait=0
		block.backing=false
		block.reset_steering()
		block.drift_angle=0.0
		block.driver_speed=0
		pitch=0
		yaw=block.parked.global_rotation.y
		camera.rotation=Vector3(pitch,yaw,0)
	elif walker.position.distance_to(block.parked.global_position)<5.8:
		driving=true
		previous_steer_key=0
		steer_key_seconds=0.0
		orbit_yaw=block.parked.global_rotation.y
		orbit_pitch=CHASE_PITCH
		manual_look=0
		airborne = false
		jump_requested = false
		vertical_speed = 0.
		walker.velocity = Vector3.ZERO
		stride.reset()
	block.driven=driving
	update_hud()

func _physics_process(dt: float) -> void:
	if warmup_frame >= 0: return
	if driving:
		var previous_yaw: float = block.parked.global_rotation.y
		drive_from_input(dt)
		chase_view(dt, angle_difference(previous_yaw, block.parked.global_rotation.y))
		gear_readout.visible=(not bool(web.midtownHudHidden) if web else hud_visible)
		gear_readout.text="%s   %d mph" % ["R" if block.backing else "D",roundi(absf(block.driver_speed)/METRES_PER_SECOND_PER_MPH)]
	elif not body.visible:
		var input:=input_direction()
		var flat:=Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.z).limit_length(1.0)
		var sprint := Input.is_physical_key_pressed(KEY_SHIFT) or (web != null and bool(web.midtownSprint))
		walk(flat, sprint, dt)
	block.street_user=block.to_local(walker.global_position)

func walk(direction: Vector3, sprint: bool, dt: float) -> void:
	var target: Vector3 = direction * (stride.SPRINT_SPEED if sprint else stride.WALK_SPEED)
	for door in revolving_doors:
		target = door.walking_velocity(walker.global_position, target)
	var acceleration := 14.0 if target.length_squared() > walker.velocity.length_squared() else 28.0
	var intended := walker.velocity.move_toward(target, acceleration * dt * (.14 if airborne else 1.0))
	var remaining := intended * dt
	var start := walker.position
	# Floating move_and_slide restores full speed along the surface after contact.
	# Project only the unconsumed motion, retaining its tangential magnitude.
	for contact in 3:
		if remaining.length_squared() < 0.00000001:
			break
		var hit := walker.move_and_collide(remaining)
		if not hit:
			break
		if direction.length_squared() > .0001 and hit.get_collider().has_meta("revolving_door"):
			var door = hit.get_collider().get_meta("revolving_door")
			if door.try_push(hit, walker, hit.get_remainder(), dt):
				remaining = hit.get_remainder()
				continue
		var normal := hit.get_normal()
		if intended.dot(normal) < 0.0:
			intended = intended.slide(normal)
		remaining = hit.get_remainder().slide(normal)
	walker.velocity = intended
	var travelled := walker.position - start
	var motion:=Vector2(travelled.x,travelled.z)
	var ground: float = stride.winter.walking_height(walker.global_position) if stride.winter else $HeraldSquare.walking_height(walker.global_position,.15)
	var raised := walker.position.y > ground + .23
	var supported := raised and walker.test_move(walker.global_transform,Vector3.DOWN*.035)
	if jump_requested and not airborne and (not raised or supported):
		airborne = true
		vertical_speed = JUMP_SPEED
	jump_requested = false
	if airborne or (raised and not supported):
		airborne = true
		var rise := vertical_speed*dt - .5*GRAVITY*dt*dt
		vertical_speed -= GRAVITY*dt
		var contact := walker.move_and_collide(Vector3.UP*rise)
		if contact and rise > 0.:
			vertical_speed = minf(vertical_speed,0.)
		if rise <= 0. and (walker.position.y <= ground or (contact and contact.get_normal().y > .55)):
			walker.position.y = maxf(ground, walker.position.y)
			airborne = false
			if vertical_speed < -1.:
				stride.play_step(walker.global_position,clampf(-vertical_speed/5.,0.,1.),stride.WALK_SPEED)
			vertical_speed = 0.
	elif not supported:
		walker.position.y = move_toward(walker.position.y,ground,1.8*dt)
	stride.advance(walker.global_position,0. if airborne else motion.length(),dt,motion.normalized())

func on_road(world: Vector3) -> bool:
	var pixel:=Vector2i(floori(world.x)+1350,floori(world.z)+1500)
	return Rect2i(Vector2i.ZERO,stride.ROADS.get_size()).has_point(pixel) and stride.ROADS.get_bitv(pixel)

func chase_view(dt: float, car_yaw_change: float = 0.0) -> void:
	var car: CharacterBody3D=block.parked
	var speed: float=absf(block.driver_speed)
	var holding_view := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or look_finger >= 0
	if holding_view:
		# Deliberately holding a view pins its angle relative to the car.
		orbit_yaw = wrapf(orbit_yaw + car_yaw_change, -PI, PI)
		manual_look = 1.5
	elif speed > 1.0:
		manual_look = maxf(0.0, manual_look - dt)
		if manual_look == 0.0:
			# Small corrections remain visible against the lane. A sustained corner
			# opens a larger heading gap and brings the camera around sooner.
			var gap := angle_difference(orbit_yaw, car.global_rotation.y)
			var rate := lerpf(1.35, 5.5, smoothstep(deg_to_rad(5.), deg_to_rad(25.), absf(gap)))
			var step := gap * (1.0 - exp(-rate * dt))
			orbit_yaw = wrapf(orbit_yaw + clampf(step, -2.4*dt, 2.4*dt), -PI, PI)
			orbit_pitch = lerpf(orbit_pitch, CHASE_PITCH, 1.0-exp(-1.8*dt))
	# The sprung body already follows the four tire contacts.
	var pivot := car.global_position + Vector3.UP * 1.15
	var reach := 5.8 + minf(speed*.045, .95)
	var yaw_basis := Basis(Vector3.UP, orbit_yaw)
	var horizontal := yaw_basis.z
	var pitch_limit := orbit_pitch
	if orbit_pitch < 0.0:
		# The survey pavement is rendered geometry without a floor collider.
		var sample_at := pivot + horizontal * cos(orbit_pitch) * reach
		var floor_y: float = stride.winter.walking_height(sample_at) if stride.winter else GRADE.height(sample_at)
		var lowest := asin(clampf((floor_y + CAMERA_CLEARANCE - pivot.y) / reach, -1., 1.))
		pitch_limit = maxf(orbit_pitch, lowest)
	var offset := horizontal * cos(pitch_limit) + Vector3.UP * sin(pitch_limit)
	var sweep := PhysicsShapeQueryParameters3D.new()
	sweep.shape = camera_probe
	sweep.transform.origin = pivot
	sweep.motion = offset * reach
	sweep.collision_mask = 3
	sweep.exclude = [car.get_rid()]
	var fraction := get_world_3d().direct_space_state.cast_motion(sweep)[0]
	camera.global_position = pivot + sweep.motion * fraction
	# The stored yaw supplies a stable right axis even when looking straight down or up.
	var back := (offset * reach * maxf(.001, fraction) + horizontal * cos(pitch_limit) * 1.7).normalized()
	camera.global_basis = Basis(yaw_basis.x, back.cross(yaw_basis.x).normalized(), back)
