extends Node3D

@export var survey_material: ShaderMaterial
@onready var block = $Block
@onready var walker: CharacterBody3D = $Walker
var driving := false
var can_enter_car := false
var orbit_yaw := 0.0
var orbit_pitch := .31
var manual_look := 0.0
var road_bump := 0.0
var last_road := true
var camera_road_phase := 0.0
var drive_audio := preload("res://drive_audio.gd").new()
var gear_readout := Label.new()
@onready var camera: Camera3D = $Camera
@onready var body: Node3D = $Body
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
var motion_setting := 2
const MIN_HEIGHT := 1.7
const MAX_HEIGHT := 1800.0

func _ready() -> void:
	add_child(drive_audio)
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
	if not web:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func look(delta: Vector2) -> void:
	if driving:
		orbit_yaw-=delta.x*.0034
		orbit_pitch=clampf(orbit_pitch+delta.y*.0025,.07,1.14)
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
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
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
		if not web and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if mouse_captured():
			look(event.screen_relative)

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
	if not driving and block.reserve.interact(): return
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
		drive_audio.park()
		gear_readout.hide()
		block.reverse_wait=0
		block.backing=false
		block.steer=0
		block.driver_speed=0
		pitch=0
		yaw=block.parked.global_rotation.y
		camera.rotation=Vector3(pitch,yaw,0)
	elif walker.position.distance_to(block.parked.global_position)<5.8:
		driving=true
		orbit_yaw=block.parked.global_rotation.y
		orbit_pitch=.31
		manual_look=0
		road_bump=0
		last_road=on_road(block.parked.global_position)
		walker.velocity = Vector3.ZERO
		stride.reset()
	block.driven=driving
	update_hud()

func _physics_process(dt: float) -> void:
	if warmup_frame >= 0: return
	if driving:
		var dir:=input_direction()
		block.drive(dt,-dir.z,dir.x)
		drive_audio.update(block.driver_speed,-dir.z,block.side_accel,dt)
		chase_view(dt)
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
	var acceleration := 14.0 if target.length_squared() > walker.velocity.length_squared() else 28.0
	var intended := walker.velocity.move_toward(target, acceleration * dt)
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
		var normal := hit.get_normal()
		if intended.dot(normal) < 0.0:
			intended = intended.slide(normal)
		remaining = hit.get_remainder().slide(normal)
	walker.velocity = intended
	var travelled := walker.position - start
	var motion:=Vector2(travelled.x,travelled.z)
	if stride.winter:
		walker.position.y=move_toward(walker.position.y,stride.winter.walking_height(walker.global_position),1.8*dt)
	stride.advance(walker.global_position,motion.length(),dt,motion.normalized())

func on_road(world: Vector3) -> bool:
	var pixel:=Vector2i(floori(world.x)+1350,floori(world.z)+1500)
	return Rect2i(Vector2i.ZERO,stride.ROADS.get_size()).has_point(pixel) and stride.ROADS.get_bitv(pixel)

func chase_view(dt: float) -> void:
	var car: CharacterBody3D=block.parked
	var speed: float=absf(block.driver_speed)
	manual_look=maxf(0,manual_look-dt)
	if manual_look<=0 and speed>1.0:
		orbit_yaw=lerp_angle(orbit_yaw,car.global_rotation.y,1.0-exp(-2.6*dt))
	var paved:=on_road(car.global_position)
	if paved!=last_road:
		road_bump=minf(speed*.008,.07)
		last_road=paved
	camera_road_phase=fmod(camera_road_phase+speed*dt*2.7,TAU)
	var heave: float=(road_bump+sin(camera_road_phase)*minf(speed*.0005,.009))*stride.strength
	road_bump*=exp(-10.*dt)
	var pivot:=car.global_position+Vector3.UP*(1.15+heave)
	var offset:=Basis(Vector3.UP,orbit_yaw)*Vector3(0,sin(orbit_pitch),cos(orbit_pitch))
	var reach:=5.8+minf(speed*.045,.95)
	var query:=PhysicsRayQueryParameters3D.create(pivot,pivot+offset*reach,3,[car.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): reach=maxf(.35,pivot.distance_to(hit.position)-.22)
	camera.position=pivot+offset*reach
	camera.look_at(pivot-offset.slide(Vector3.UP)*1.7)
