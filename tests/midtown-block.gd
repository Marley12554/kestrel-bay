extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", description)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://map.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	var block = scene.block
	block.set_physics_process(false)
	var eye: Transform3D = scene.camera.transform
	scene.toggle_body()
	check(scene.body.visible, "freecam leaves the figure on the sidewalk")
	scene.fly(Vector3.FORWARD, 1.0)
	scene.toggle_body()
	check(scene.camera.transform.is_equal_approx(eye), "return to the same viewpoint")
	scene.interact()
	check(scene.driving, "enter car at spawn")
	# Drive a closed loop with the ordinary steering and collision controller.
	var car = block.parked
	var start: Vector3 = car.position
	var goals := [Vector2(86,26), Vector2(83,36), Vector2(77,40), Vector2(-210,40), Vector2(-221,36), Vector2(-225,25), Vector2(-225,-36), Vector2(-221,-42), Vector2(-208,-43), Vector2(74,-43), Vector2(83,-40), Vector2(88,-33)]
	for dest in goals:
		for step in 4000:
			var delta: Vector2 = dest - Vector2(car.position.x,car.position.z)
			if delta.length()<3.1: break
			var angle := wrapf(atan2(-delta.x,-delta.y)-car.rotation.y,-PI,PI)
			block.drive(1.0/60, clampf((6.1-block.driver_speed)*1.5,0,1), clampf(-angle*2.4,-1,1))
		check(Vector2(car.position.x,car.position.z).distance_to(dest)<3.1,"drive to "+str(dest))
		if failures: break
	check(car.position.distance_to(start)<7, "complete the circuit")
	block.driver_speed=0
	scene.interact()
	check(not scene.driving,"exit a stopped car")
	# Time a crossing at the normal on-foot speed, between the two curbs.
	var walker: CharacterBody3D = scene.walker
	walker.position = block.to_global(Vector3(90.5,.15,-56.6))
	var origin := walker.position
	scene.yaw = block.rotation.y + PI/2
	movement_key(KEY_W,true)
	for tick in 536:
		scene._physics_process(1.0/60)
	check(absf(walker.position.distance_to(origin)-19.0)<.12, "walk the crossing from rest in 8.9 seconds")
	walker.position = origin
	walker.velocity = Vector3.ZERO
	movement_key(KEY_SHIFT,true)
	for tick in 174:
		scene._physics_process(1.0/60)
	check(absf(walker.position.distance_to(origin)-19.0)<.12, "sprint the crossing from rest in 2.9 seconds")
	movement_key(KEY_SHIFT,false)
	movement_key(KEY_W,false)
	# Push into the actual stationary sedan at several angles. Its face must
	# preserve the requested fraction of tangential speed on both sides.
	car.position = Vector3(88.7, .035, -31.6)
	car.rotation.y = PI
	await physics_frame
	await physics_frame
	var side: Vector3 = car.global_basis.x
	var along: Vector3 = car.global_basis.z
	var speeds: Array[float] = []
	for degrees in [0, 5, 20, 45, -20]:
		walker.global_position = car.global_position + side * 1.24 + Vector3.UP * .13
		walker.velocity = Vector3.ZERO
		var angle := deg_to_rad(degrees)
		var heading := -side * cos(angle) + along * sin(angle)
		for tick in 38:
			scene.walk(heading, false, 1.0/60)
		var before: Vector3 = walker.position
		var phase: float = scene.stride.phase
		for tick in 8:
			scene.walk(heading, false, 1.0/60)
		var actual := (walker.position-before).dot(along)*7.5
		check(absf((walker.position-before).dot(side))<.002, "sedan blocks inward movement")
		speeds.append(actual)
		var expected: float = scene.stride.WALK_SPEED * sin(angle)
		check(absf(actual-expected)<.10, "proportional tangent at %d degrees: %.3f" % [degrees,actual])
		if degrees == 0:
			check(is_equal_approx(phase, scene.stride.phase) and scene.stride.activity == 0, "no steps or bob pushing into sedan")
	check(speeds[1]<speeds[2] and speeds[2]<speeds[3], "gradual movement along sedan")
	scene.stride.reset()
	check(not scene.stride.blur.visible and scene.camera.h_offset==0 and scene.camera.v_offset==0,"reset camera on leaving foot mode")
	var waited := false
	var yielded := false
	var turned := false
	var crossed := false
	var first_walker: Vector3 = block.walkers[0].node.position
	block.batch_walkers()
	var expected_parts := 0
	var drawn_parts := 0
	for person in block.walkers:
		expected_parts += person.node.get_child_count()
	for batch in block.get_node("Crowd").get_children():
		drawn_parts += batch.multimesh.instance_count
	check(drawn_parts == expected_parts and block.get_node("Crowd").get_child_count() < block.walkers.size(), "every pedestrian part is included in the shared draws")
	for frame in 3600:
		block._physics_process(1.0/60)
		waited = waited or (absf(block.distance-block.cross_stop)<.15 and block.vehicle_signal(true)==0)
		yielded = yielded or (absf(block.distance-block.yield_point)<.15 and block.crossing_busy())
		turned = turned or (block.taxi.position.x<62 and absf(block.taxi.position.z+49.6)<.8)
		crossed = crossed or block.walkers[0].node.position.distance_to(first_walker)>20
	check(waited,"taxi stops at red")
	check(yielded,"taxi yields to pedestrians")
	check(turned,"taxi exits turn in the westbound lane")
	check(crossed,"pedestrian completes crossing")
	if DisplayServer.get_name() != "headless":
		var person: Dictionary = block.walkers[0]
		var posed := true
		for draw in person.draw_parts:
			var transform: Transform3D = draw[0].get_instance_transform(draw[1])
			posed = posed and transform.is_equal_approx(person.node.transform * draw[2].transform)
		check(posed, "shared draws follow the moving pedestrian and its limbs")
	scene.queue_free()
	await process_frame
	await winter_stride_checks()
	await process_frame
	await process_frame
	print(checks," Midtown checks, ",failures," failures")
	quit(1 if failures else 0)

func movement_key(code: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func winter_stride_checks() -> void:
	var scene = load("res://winter/night.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	var parked_spawn: Transform3D = scene.block.parked.transform
	var start: Vector3 = scene.walker.position
	var heading: Vector3 = Basis(Vector3.UP, scene.yaw) * Vector3.FORWARD
	for i in 360:
		scene.walk(heading, false, 1.0/60)
	var displacement: Vector3 = scene.walker.position - start
	check(displacement.dot(heading)>12.5 and displacement.cross(heading).length()<.02, "first six seconds of walking clear the parked car")
	var winter = scene.get_node("Winter")
	for tick in 24: scene.walk(Vector3.ZERO,false,1./60)
	var takeoff: float = scene.walker.position.y
	movement_key(KEY_SPACE,true)
	movement_key(KEY_SPACE,false)
	var apex := 0.
	for tick in 60:
		scene.walk(Vector3.ZERO,false,1./60)
		apex = maxf(apex, scene.walker.position.y - takeoff)
		if tick == 15:
			movement_key(KEY_SPACE,true)
			movement_key(KEY_SPACE,false)
	check(apex > .53 and apex < .60 and not scene.airborne and absf(scene.walker.position.y-takeoff)<.01,
		"Space jumps about 22 inches, ignores an airborne second press and lands on snow")
	var hood: MeshInstance3D = winter.chassis.find_child("Object_11", true, false)
	var paint := hood.get_surface_override_material(0) as StandardMaterial3D
	check(paint.albedo_color == Color("#f5f5f2"), "sedan body has white paint")
	check(not winter.headlight_beams.visible and not winter.headlight_lenses.get_shader_parameter("headlights_on"),
		"headlights stay off while parked")
	var frontage=scene.block.get_node("EmpireFrontage")
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	for probe in [
		[Vector3(70,1.25,-.72),Vector3(64,1.25,-.72),"center entry"],
		[Vector3(70,1.25,1.94),Vector3(64,1.25,1.94),"revolving door"],
		[Vector3(42.29,1.5,33),Vector3(42.29,1.5,28),"side-street loading door"]]:
		var query:=PhysicsRayQueryParameters3D.create(scene.block.to_global(probe[0]),scene.block.to_global(probe[1]),1)
		var hit:=space.intersect_ray(query)
		check(not hit.is_empty() and frontage.is_ancestor_of(hit.collider),probe[2]+" meets the new frontage")
	# Approach both exposed ground-floor faces from the public sidewalk.
	var demarest := scene.block.get_node("Demarest") as Node3D
	for probe in [
		[Vector3(93,1.2,13.225), Vector3(97,1.2,13.225), "339 numbered entrance"],
		[Vector3(93,1.2,24), Vector3(97,1.2,24), "Fifth retail glazing"],
		[Vector3(119,1.2,33), Vector3(119,1.2,28), "33rd Street storefront"]]:
		var query:=PhysicsRayQueryParameters3D.create(scene.block.to_global(probe[0]),scene.block.to_global(probe[1]),1)
		var hit:=space.intersect_ray(query)
		check(not hit.is_empty() and demarest.is_ancestor_of(hit.collider),probe[2]+" meets its modeled surface")
	var road: Vector3 = scene.block.to_global(Vector3(81, 0, -45.8))
	var bank: Vector3 = scene.block.to_global(Vector3(90.45,0,6))
	check(scene.stride.ROADS.get_bitv(Vector2i(floori(road.x)+1350, floori(road.z)+1500)), "road mask matches the Fifth Avenue intersection")
	check(winter.snow_underfoot(bank,false)==1.0 and winter.snow_underfoot(road,true)<.5, "snow bank and plowed asphalt sound different")
	check(scene.stride.snow_steps.size()==5 and scene.stride.hard_steps.size()==5, "load varied clips for both surfaces")
	scene.stride.play_step(bank,0,2)
	check(scene.stride.snow.stream in scene.stride.snow_steps,"snow footfall uses snow audio")
	scene.stride.play_step(road,1,7)
	check(scene.stride.pavement.stream in scene.stride.hard_steps,"road footfall uses pavement audio")
	for i in 60:
		scene.walk(heading, true, 1.0/60)
	check(scene.stride.blur.visible and scene.camera.fov>scene.stride.base_fov,"peripheral blur and FOV respond at sprint speed")
	var previous: float = scene.camera.fov
	var smooth_return := true
	for tick in 96:
		scene.walk(heading, false, 1.0/60)
		var drop: float = previous - scene.camera.fov
		smooth_return = smooth_return and drop >= -0.001 and drop < 0.13
		previous = scene.camera.fov
		if tick == 14:
			check(scene.camera.fov > scene.stride.base_fov + 3.0 and scene.walker.velocity.length() < 2.2, "camera eases back independently of braking")
	check(smooth_return and absf(scene.camera.fov-scene.stride.base_fov)<0.04,"sprint FOV settles gently without overshoot")
	for tick in 36:
		scene.walk(heading,true,1.0/60)
	scene.set_motion_level(0)
	scene.walk(heading,true,1.0/60)
	check(not scene.stride.blur.visible and scene.camera.v_offset==0 and scene.camera.h_offset==0 and scene.camera.fov==scene.stride.base_fov,"camera motion off leaves footsteps independent")
	scene.toggle_body()
	check(not scene.stride.blur.visible and not scene.stride.snow.playing and not scene.stride.pavement.playing,"freecam clears the walking effects")
	scene.toggle_body()
	var block=scene.block
	block.set_physics_process(false)
	block.parked.rotation.y=PI
	block.parked.position=Vector3(83,.035,-27)
	scene.walker.position=block.parked.global_position+Vector3.RIGHT*3
	scene.interact()
	check(scene.driving and winter.wheel_pivots.size()==4 and null not in winter.wheel_pivots,"winter sedan has four independent wheel pivots")
	scene.look(Vector2(200,-28))
	var orbit: float=scene.orbit_yaw
	scene.chase_view(1./60)
	check(absf(angle_difference(orbit,block.parked.global_rotation.y))>.4,"orbit works while parked")
	var ground_position: Vector3 = block.parked.position
	scene.look(Vector2(0,-2200))
	scene.chase_view(1./60)
	check(scene.camera.global_position.y > .20, "pavement limits the downward camera orbit")
	block.parked.position.y = 1000
	scene.chase_view(1./60)
	check(scene.camera.global_basis.z.y < -.9999, "an elevated sedan can be inspected from directly underneath")
	scene.look(Vector2(0,2200))
	for i in 150: scene.chase_view(1./60)
	check(scene.camera.global_basis.z.y > .9999 and scene.camera.global_basis.determinant() > .999,
		"overhead orbit stays upright and parked inspection holds")
	scene.orbit_pitch = scene.CHASE_PITCH
	scene.orbit_yaw = block.parked.rotation.y
	block.driver_speed = block.CAR_MAX_FORWARD_SPEED
	scene.chase_view(1./60)
	var camera_height: float = scene.camera.position.y
	var vertical_drift := 0.
	for tick in 90:
		scene.chase_view(1./60)
		vertical_drift = maxf(vertical_drift,absf(scene.camera.position.y-camera_height))
	check(vertical_drift < .001, "steady highway speed introduces no synthetic camera bounce")
	block.driver_speed = 0.
	block.parked.position = ground_position
	scene.orbit_pitch = scene.CHASE_PITCH
	for i in 150:
		block.drive(1./60,1,0)
	check(block.driver_speed>11.2,"electric sedan accelerates beyond prototype speed cap")
	block.drive(1./60,0,.6)
	winter._physics_process(1./60)
	check(absf(block.steer)>.005 and absf(winter.wheel_roll)>.1,"front wheels steer while axles roll")
	for i in 90:
		block.drive(1./60,-1,0)
	check(block.driver_speed<=.02 and block.driver_speed>-.6,"service brake arrests forward motion before reverse builds")
	for i in 90:
		block.drive(1./60,-1,0)
	check(block.backing and block.driver_speed<-1,"hold brake at rest to reverse")
	var drive_sound = scene.drive_audio
	for source in [drive_sound.chirp, drive_sound.tires, drive_sound.skid, drive_sound.turn_signal]:
		check(source is AudioStreamPlayer3D and source.is_inside_tree() and source.max_distance > 0.,
			"each driving sound has a world position and distance attenuation")
	check(drive_sound.skid.position.z > 1. and drive_sound.tires.position.z < -1.,
		"rolling and rear slip originate at distinct axle positions")
	for tick in 120:
		drive_sound.update(-4.0, 0.0, 1.0 / 60.0)
	check(drive_sound.tires.playing, "driving activates rolling audio")
	check(drive_sound.reverse_warning.playing and drive_sound.reverse_warning.volume_db > -10.0
		and drive_sound.forward_warning.volume_db < -60.0, "reverse plays the Model 3 warning from the rear speaker")
	for tick in 120:
		drive_sound.update(4.0, 0.0, 1.0 / 60.0)
	check(drive_sound.forward_warning.playing and drive_sound.forward_warning is AudioStreamPlayer3D and drive_sound.get_parent() == block.parked
		and drive_sound.forward_warning.volume_db > -30. and drive_sound.forward_warning.volume_db < drive_sound.tires.volume_db - 8.
		and drive_sound.reverse_warning.volume_db < -60.0, "low-speed forward driving plays the Model 3 forward warning")
	for tick in 60:
		drive_sound.update(13.4, 0., 1./60.)
	check(drive_sound.forward_warning.volume_db < -60. and drive_sound.tires.volume_db > -18.,
		"rolling sound carries through the low-speed warning fade")
	for tick in 20: drive_sound.update(14., 6., 1./60., .6)
	check(drive_sound.skid.playing and drive_sound.chirp.playing and not drive_sound.chirp_armed,
		"hard breakaway adds a single short rubber chirp over the rear scuff")
	drive_sound.chirp.stop()
	for tick in 120: drive_sound.update(14., 6., 1./60., .6)
	check(drive_sound.skid.playing and not drive_sound.chirp.playing, "sustaining a slide cannot retrigger squeal")
	for tick in 120: drive_sound.update(14., 0., 1./60.)
	check(drive_sound.chirp_armed and not drive_sound.skid.playing, "regaining traction fades the scuff and rearms the chirp")
	for tick in 20: drive_sound.update(14., 6., 1./60., .6, 1.)
	check(drive_sound.skid.playing and not drive_sound.chirp.playing, "a packed-snow slide has scuff without pavement squeal")
	movement_key(KEY_LEFT, true)
	movement_key(KEY_LEFT, false)
	winter.update_sedan_lights(0.0)
	block.driver_speed=0
	scene.interact()
	check(not scene.driving and not drive_sound.chirp.playing and not drive_sound.skid.playing and not drive_sound.tires.playing
		and not drive_sound.forward_warning.playing and not drive_sound.reverse_warning.playing
		and not drive_sound.turn_signal.playing and scene.turn_signal_direction == 0,
		"parking clears the turn signal and stops all driving sounds")
	movement_key(KEY_LEFT, true)
	movement_key(KEY_LEFT, false)
	check(scene.turn_signal_direction == 0, "arrow keys cannot select a turn signal on foot")
	block.street_user=Vector3.INF
	block.cross_distance=block.south_stop-12
	block.cross_speed=3.5
	block.cycle=5
	for i in 600: block.update_cross_taxi(1./60)
	check(absf(block.cross_distance-block.south_stop)<.15,"33rd Street traffic holds at the red signal")
	block.cycle=26
	for i in 360: block.update_cross_taxi(1./60)
	check(block.cross_taxi.position.x<80 and block.cross_taxi.position.z>36,"33rd Street traffic crosses west on green")
	snow_contact_checks(scene,winter)
	street_fixture_checks(scene.block,winter.pack)
	await reserve_visit(scene)
	var sedan: CharacterBody3D = block.parked
	sedan.transform = parked_spawn
	scene.walker.position = sedan.global_position + Vector3.RIGHT * 3
	movement_key(KEY_E, true)
	movement_key(KEY_E, false)
	check(scene.driving, "E enters the sedan for keyboard driving")
	winter.update_sedan_lights(0.0)
	check(winter.headlight_beams.visible and winter.headlight_beams.get_child_count() == 2
		and winter.headlight_lenses.get_shader_parameter("headlights_on"),
		"both headlights and their beams turn on while driving")
	movement_key(KEY_S, true)
	movement_key(KEY_D, true)
	scene._physics_process(1.0 / 60.0)
	winter.update_sedan_lights(1.0 / 60.0)
	check(winter.brake_lenses.emission_energy_multiplier > 0, "S lights the brake lenses")
	check(winter.signal_lenses.get_shader_parameter("flashing_side") == 0 and block.steer > 0.0,
		"D steers right without activating a signal")
	movement_key(KEY_D, false)
	block.reset_steering()
	movement_key(KEY_RIGHT, true)
	scene._physics_process(1.0 / 60.0)
	winter.update_sedan_lights(1.0 / 60.0)
	check(winter.signal_lenses.get_shader_parameter("flashing_side") == 1 and is_zero_approx(block.steer),
		"Right arrow flashes the right indicators without steering")
	var signal_sound: AudioStreamPlayer3D = drive_sound.turn_signal
	check(signal_sound.playing and signal_sound.stream == preload("res://audio/turn_signal.wav"),
		"the signal clicks when the indicator turns on")
	movement_key(KEY_RIGHT, true, true)
	check(scene.turn_signal_direction == 1, "holding Right arrow ignores keyboard repeat")
	movement_key(KEY_RIGHT, false)
	signal_sound.stop()
	winter.update_sedan_lights(1.0 / 60.0)
	check(not signal_sound.playing, "the signal stays quiet between blink transitions")
	winter.update_sedan_lights(0.4)
	check(winter.signal_lenses.get_shader_parameter("flashing_side") == 0, "the indicator blinks off after releasing Right arrow")
	check(signal_sound.playing and signal_sound.stream == preload("res://audio/turn_signal_off.wav"),
		"the indicator uses the recorded relay release on its off stroke")
	signal_sound.stop()
	winter.update_sedan_lights(0.4)
	check(winter.signal_lenses.get_shader_parameter("flashing_side") == 1, "the indicator keeps blinking after releasing Right arrow")
	check(signal_sound.playing and signal_sound.stream == preload("res://audio/turn_signal.wav"),
		"the signal click repeats with the next blink")
	movement_key(KEY_S, false)
	movement_key(KEY_A, true)
	scene._physics_process(1.0 / 60.0)
	winter.update_sedan_lights(1.0 / 60.0)
	check(is_zero_approx(winter.brake_lenses.emission_energy_multiplier), "releasing S turns off the brake emission")
	check(winter.signal_lenses.get_shader_parameter("flashing_side") == 1 and block.steer < 0.0,
		"steering left keeps the selected right signal")
	movement_key(KEY_A, false)
	movement_key(KEY_LEFT, true)
	movement_key(KEY_LEFT, false)
	winter.update_sedan_lights(1.0 / 60.0)
	check(winter.signal_lenses.get_shader_parameter("flashing_side") == -1,
		"Left arrow switches directly to the left indicators")
	signal_sound.stop()
	movement_key(KEY_LEFT, true)
	movement_key(KEY_LEFT, false)
	winter.update_sedan_lights(1.0 / 60.0)
	check(winter.signal_lenses.get_shader_parameter("flashing_side") == 0, "pressing Left arrow again cancels the signal")
	winter.update_sedan_lights(0.4)
	check(not signal_sound.playing, "cancelling stops new signal clicks")
	movement_key(KEY_Q,true)
	movement_key(KEY_Q,false)
	check(scene.turn_signal_direction == 0, "Q leaves the indicators alone")
	movement_key(KEY_E,true)
	movement_key(KEY_E,false)
	check(not scene.driving and scene.turn_signal_direction == 0, "E at rest parks without flashing a signal")
	movement_key(KEY_E,true)
	movement_key(KEY_E,false)
	for turn_key: Key in [KEY_D, KEY_A]:
		sedan.transform = parked_spawn
		if turn_key == KEY_A:
			sedan.position.x = 81.0 # Leave room for a left turn away from the curb.
		block.driver_speed = 0.0
		block.reset_steering()
		var start_yaw := sedan.global_rotation.y
		var parking_start := sedan.position
		movement_key(turn_key, true)
		for tick in 12:
			scene._physics_process(1.0 / 60.0)
		check(is_equal_approx(sedan.global_rotation.y, start_yaw) and sedan.position.is_equal_approx(parking_start),
			"%s steers the front wheels without pivoting the parked sedan" % OS.get_keycode_string(turn_key))
		block.reset_steering()
		var travel_distance := 0.0
		movement_key(KEY_W, true)
		for tick in 66:
			var prior_position := sedan.position
			scene._physics_process(1.0 / 60.0)
			travel_distance += sedan.position.distance_to(prior_position)
		movement_key(turn_key, false)
		movement_key(KEY_W, false)
		var direction := 1.0 if turn_key == KEY_A else -1.0
		var turn_degrees := rad_to_deg(angle_difference(start_yaw, sedan.global_rotation.y)) * direction
		check(turn_degrees > 29.0 and turn_degrees < 41.0 and travel_distance > 3.0,
			"W+%s turns %.1f degrees over %.2f m from rest" % [OS.get_keycode_string(turn_key), turn_degrees, travel_distance])
		# Start on Fifth Avenue and turn onto 33rd Street at city driving speed.
		sedan.position = Vector3(81.0 - direction * 2.0, .035, 32.3)
		sedan.rotation.y = PI
		block.driver_speed = 30.0 * scene.METRES_PER_SECOND_PER_MPH
		block.reset_steering()
		start_yaw = sedan.global_rotation.y
		movement_key(KEY_W, true)
		movement_key(turn_key, true)
		for tick in 55:
			scene._physics_process(1.0 / 60.0)
		movement_key(turn_key, false)
		movement_key(KEY_W, false)
		turn_degrees = rad_to_deg(angle_difference(start_yaw, sedan.global_rotation.y)) * direction
		check(turn_degrees >= 90.0 and turn_degrees < 105.0 and absf(sedan.position.z - 40.0) < 2.0,
			"W+%s turns %.1f degrees onto 33rd Street from 30 mph" % [OS.get_keycode_string(turn_key), turn_degrees])
	# Check left and right steering on open Fifth Avenue pavement.
	for config in [[65, KEY_W, KEY_A, -1.0], [100, KEY_W, KEY_D, 1.0],
			[130, KEY_W, KEY_A, -1.0], [130, KEY_W, KEY_D, 1.0], [130, KEY_UP, KEY_D, 1.0]]:
		var mph: int = config[0]
		var accelerator: Key = config[1]
		var steering_key: Key = config[2]
		scene._physics_process(1.0 / 60.0) # Sample key-up between independent runs.
		var turn_direction: float = config[3]
		sedan.position = Vector3(81, .035, -31)
		sedan.rotation.y = PI
		var start_yaw := sedan.global_rotation.y
		var start_position := sedan.position
		var right := sedan.basis.x
		block.driver_speed = mph * scene.METRES_PER_SECOND_PER_MPH
		block.reset_steering()
		scene.manual_look = 0.0
		scene.orbit_yaw = start_yaw
		movement_key(accelerator, true)
		movement_key(steering_key, true)
		scene._physics_process(1.0 / 60.0)
		var initial_yaw := absf(angle_difference(start_yaw, sedan.global_rotation.y))
		for tick in 5:
			scene._physics_process(1.0 / 60.0)
		var settled_yaw := sedan.global_rotation.y
		scene._physics_process(1.0 / 60.0)
		var settled_yaw_step := absf(angle_difference(settled_yaw, sedan.global_rotation.y))
		check(initial_yaw > 0 and initial_yaw < deg_to_rad(.15) and settled_yaw_step > initial_yaw * 3.0,
			"%d mph steering starts gently and builds through the first seven frames" % mph)
		for tick in 23:
			scene._physics_process(1.0 / 60.0)
		movement_key(steering_key, false)
		movement_key(accelerator, false)
		var heading_change := absf(angle_difference(start_yaw, sedan.global_rotation.y))
		var camera_change := absf(angle_difference(start_yaw, scene.orbit_yaw))
		var lateral_distance := (sedan.position - start_position).dot(right) * turn_direction
		check(lateral_distance > 1.1 and lateral_distance < 1.85, "%d mph keyboard turn shifts %.2f m in half a second" % [mph, lateral_distance])
		check(camera_change > heading_change * .17 and camera_change < heading_change * .70, "%d mph camera follows a sustained turn while showing chassis rotation" % mph)

	# A digital tap should provide a lane trim, including the residual wheel
	# motion after key-up. Test both directions on a clear stretch of Fifth.
	for key: Key in [KEY_A, KEY_D]:
		for ticks in [3, 6]:
			scene._physics_process(1./60.)
			sedan.position = Vector3(81, .035, -50)
			sedan.rotation.y = PI
			block.driver_speed = block.CAR_MAX_FORWARD_SPEED
			block.reset_steering()
			var trim_heading := sedan.global_rotation.y
			var lateral := sedan.global_basis.x
			movement_key(key, true)
			for tick in ticks: scene._physics_process(1./60.)
			movement_key(key, false)
			var release_position := sedan.global_position
			for tick in 60: scene._physics_process(1./60.)
			var degrees := absf(rad_to_deg(angle_difference(trim_heading, sedan.global_rotation.y)))
			var feet := absf((sedan.global_position-release_position).dot(lateral)) * 3.28084
			var expected_degrees := .14 if ticks==3 else .29
			check(absf(degrees-expected_degrees)<.15 and feet<1.8, "130 mph %d-tick trim: %.2f degrees, %.2f ft" % [ticks,degrees,feet])

	# Switch directions at speed and let the wheels return to center.
	sedan.position = Vector3(81, 1000, -31)
	sedan.rotation.y = PI
	block.driver_speed = 100.0 * scene.METRES_PER_SECOND_PER_MPH
	block.reset_steering()
	movement_key(KEY_W, true)
	movement_key(KEY_D, true)
	for tick in 12:
		scene._physics_process(1.0 / 60.0)
	var right_lock: float = block.steer
	movement_key(KEY_D, false)
	movement_key(KEY_A, true)
	scene._physics_process(1.0 / 60.0)
	check(block.steer > right_lock * .55 and block.steer < right_lock * .90,
		"switching to A eases the wheels out of right lock")
	for tick in 11:
		scene._physics_process(1.0 / 60.0)
	var left_lock: float = block.steer
	check(left_lock < -right_lock * .90, "equal-duration A and D holds give comparable wheel angles")
	movement_key(KEY_A, false)
	scene._physics_process(1.0 / 60.0)
	check(block.steer < left_lock * .7 and block.steer > left_lock,
		"releasing A starts a gradual return to center")
	for tick in 16:
		scene._physics_process(1.0 / 60.0)
	check(absf(block.steer) < .001, "steering returns to center without leaving an offset")
	movement_key(KEY_W, false)

	# Clear of obstacles so deceleration comes from the brake.
	movement_key(KEY_W, true)
	movement_key(KEY_S, true)
	for config in [[65, 2.6, 36.0], [100, 3.55, 71.0], [130, 4.35, 112.0]]:
		var mph: int = config[0]
		var time_limit: float = config[1]
		var distance_limit: float = config[2]
		var start_position := Vector3(81, 1000, -31)
		sedan.position = start_position
		sedan.rotation.y = PI
		block.driver_speed = mph * scene.METRES_PER_SECOND_PER_MPH
		block.reset_steering()
		var stop_ticks := 0
		for tick in 420:
			scene._physics_process(1.0 / 60.0)
			stop_ticks = tick + 1
			if is_zero_approx(block.driver_speed):
				break
		var stop_time := stop_ticks / 60.0
		var stop_distance := sedan.position.distance_to(start_position)
		print("%d mph braking: %.2f s, %.1f m" % [mph, stop_time, stop_distance])
		check(is_zero_approx(block.driver_speed) and stop_time <= time_limit and stop_distance <= distance_limit,
			"%d mph straight-line stopping time and distance" % mph)
	# Check full steering with the service brake overriding the accelerator.
	sedan.position = Vector3(81, 1000, -31)
	var brake_start_yaw := sedan.rotation.y
	block.driver_speed = 130.0 * scene.METRES_PER_SECOND_PER_MPH
	scene.look(Vector2(90, 0))
	var manual_heading: float = scene.orbit_yaw
	movement_key(KEY_D, true)
	for tick in 60:
		scene._physics_process(1.0 / 60.0)
	movement_key(KEY_D, false)
	check(absf(block.driver_speed / scene.METRES_PER_SECOND_PER_MPH - 92.0) < .2, "S slows from 130 to 92 mph in one second with W held")
	var braking_turn := -rad_to_deg(angle_difference(brake_start_yaw, sedan.rotation.y))
	check(braking_turn > 20. and braking_turn < 43., "a held turn under braking at 130 mph changes heading %.1f degrees" % braking_turn)
	check(absf(angle_difference(manual_heading, scene.orbit_yaw)) < .002, "after mouse look the view holds its world heading while the car turns")
	for tick in 360:
		scene._physics_process(1.0 / 60.0)
	check(is_zero_approx(block.driver_speed) and not block.backing, "holding both pedals stops without shifting into reverse")
	movement_key(KEY_W, false)
	for tick in 48:
		scene._physics_process(1.0 / 60.0)
	check(block.backing and block.driver_speed < -1.0, "holding S alone at rest selects reverse")
	movement_key(KEY_S, false)

	movement_key(KEY_W, true)
	for tick in 60:
		scene._physics_process(1.0 / 60.0)
		if is_zero_approx(block.driver_speed):
			break
	check(block.backing and is_zero_approx(block.driver_speed), "W brakes to a stop while still in reverse")
	for tick in 12:
		scene._physics_process(1.0 / 60.0)
	check(block.backing and is_zero_approx(block.driver_speed), "the direction change pauses at rest")
	for tick in 12:
		scene._physics_process(1.0 / 60.0)
	check(not block.backing and block.driver_speed > 0, "holding W selects Drive after the pause")
	movement_key(KEY_W, false)

	# Compare chassis heading to actual motion while using the handbrake.
	for config in [[30, KEY_A, -1.0], [30, KEY_D, 1.0], [130, KEY_D, 1.0]]:
		var mph: int = config[0]
		var turn_key: Key = config[1]
		var direction: float = config[2]
		sedan.position = Vector3(81, 1000.0 if mph == 130 else .035, -31)
		sedan.rotation.y = PI
		var start_speed: float = mph * scene.METRES_PER_SECOND_PER_MPH
		block.driver_speed = start_speed
		block.reset_steering()
		movement_key(KEY_W, true)
		movement_key(KEY_SHIFT, true)
		movement_key(turn_key, true)
		for tick in 23:
			scene._physics_process(1.0 / 60.0)
		var previous_position := sedan.global_position
		scene._physics_process(1.0 / 60.0)
		var motion := (sedan.global_position - previous_position).normalized()
		var slip := (-sedan.global_basis.z).signed_angle_to(motion, Vector3.UP) * direction
		check(rad_to_deg(slip) > 13.0 and rad_to_deg(slip) < 45.0,
			"Shift+%s produces a %.1f-degree slide at %d mph" % [OS.get_keycode_string(turn_key), rad_to_deg(slip), mph])
		check(block.driver_speed < start_speed - .95 and block.driver_speed > start_speed - 1.8 and scene.brake_pressed,
			"the handbrake slows the sedan and lights the brake lamps while W is held")
		movement_key(KEY_SHIFT, false)
		movement_key(turn_key, false)
		scene._physics_process(1.0 / 60.0)
		check(absf(block.drift_angle) > .1 and drive_sound.skid.playing, "slip and tire scrub persist into grip recovery")
		for tick in 180:
			scene._physics_process(1.0 / 60.0)
		check(is_zero_approx(block.drift_angle) and sedan.velocity.normalized().dot(-sedan.global_basis.z) > .999
			and not scene.brake_pressed, "releasing Shift progressively restores grip")
		movement_key(KEY_W, false)

	sedan.position = Vector3(81, 1000, -31)
	block.driver_speed = 8.0
	var straight_yaw := sedan.rotation.y
	movement_key(KEY_SHIFT, true)
	for tick in 24:
		scene._physics_process(1.0 / 60.0)
	check(absf(block.driver_speed - 5.8) < .05 and is_zero_approx(block.drift_angle)
		and is_equal_approx(sedan.rotation.y, straight_yaw), "Shift alone brakes in a straight line")
	movement_key(KEY_SHIFT, false)
	# Isolate grip recovery at the same speed and starting slide angle.
	var residual := []
	for cover in [0.,1.]:
		block.reset_steering()
		sedan.position = Vector3(81,1000,-31)
		block.driver_speed = 15.
		block.drift_angle = .4
		block.rear_snow_cover = cover
		for tick in 12: block.drive(1./60,0.,0.)
		residual.append(block.drift_angle)
	check(residual[1] > residual[0]+.04, "rear tires regain sideways grip more slowly on packed snow (dry %.3f, packed %.3f)" % residual)
	# Measure the exit path in world space because the block is rotated.
	for direction: float in [-1., 1.]:
		sedan.position = Vector3(81, 1000, -31)
		sedan.rotation.y = 0.
		block.reset_steering()
		block.drift_angle = 0.
		block.driver_speed = 30. * scene.METRES_PER_SECOND_PER_MPH
		block.rear_snow_cover = 0.
		var initial_heading := -sedan.global_basis.z
		for tick in 60: block.drive(1./60., 1., direction, true, true)
		var release_speed: float = block.driver_speed / scene.METRES_PER_SECOND_PER_MPH
		for tick in 90: block.drive(1./60., 1., 0.)
		var exit_angle := -direction * rad_to_deg(initial_heading.signed_angle_to(sedan.velocity.normalized(), Vector3.UP))
		check(exit_angle > 80. and exit_angle < 100. and release_speed > 17. and release_speed < 27.
			and absf(block.drift_angle) < .02,
			"30 mph handbrake corner exits at %.1f degrees, carrying %.1f mph at release" % [exit_angle, release_speed])
	# Reverse the demanded steer while sliding. Both the body rotation and
	# the world velocity must survive input frames, including a neutral frame.
	for direction in [-1., 1.]:
		for hz: int in [30,60,120]:
			var dt := 1./hz
			sedan.position = Vector3(81,1000,-31)
			sedan.rotation.y = 0.
			block.reset_steering()
			block.drift_angle = 0.
			block.driver_speed = 40.*scene.METRES_PER_SECOND_PER_MPH
			block.rear_snow_cover = 0.
			for tick in roundi(.6*hz): block.drive(dt,0.,direction,true,true)
			var reverse_time := 0.
			var max_lateral_accel := 0.
			for tick in hz:
				var before := sedan.velocity
				block.drive(dt,0.,0. if tick==0 else -direction,true,true)
				var bend := absf(before.signed_angle_to(sedan.velocity,Vector3.UP))
				max_lateral_accel = maxf(max_lateral_accel, bend*absf(block.driver_speed)/dt)
				if reverse_time == 0. and block.yaw_velocity*direction > 0.:
					reverse_time = (tick+1)*dt
			check(reverse_time > .20 and reverse_time < .8 and max_lateral_accel <= block.CAR_LATERAL_GRIP*.80,
				"%d Hz countersteer takes %.2f s and respects tire grip" % [hz,reverse_time])
	block.reset_steering()
	block.drift_angle = 0.
	curb_suspension_checks(scene, winter)
	await bumper_contact_checks(scene)
	scene.queue_free()

func bumper_contact_checks(scene) -> void:
	var car: CharacterBody3D = scene.block.parked
	var wall := StaticBody3D.new()
	var solid := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,5,.4)
	solid.shape = box
	wall.add_child(solid)
	scene.add_child(wall)
	wall.global_position = Vector3(0,1000,0)
	await physics_frame
	# Mesh support distances measured from the sedan GLB in its driving orientation.
	for sample in [[0.,2.359],[35.,2.161],[180.,2.360]]:
		car.global_transform = Transform3D(Basis(Vector3.UP,deg_to_rad(sample[0])),Vector3(0,1000,5))
		var hit := car.move_and_collide(Vector3.FORWARD*5.)
		var bumper_gap: float = car.global_position.z - box.size.z*.5 - sample[1]
		check(hit != null and hit.get_collider() == wall and absf(bumper_gap)<.04,
			"visible body meets a wall within 1.6 inches at %d degrees" % sample[0])
	wall.queue_free()

func curb_suspension_checks(scene, winter) -> void:
	var block = scene.block
	var car: CharacterBody3D = block.parked
	var road_y: float = winter.road_ride_height
	var curb_y: float = winter.sidewalks.CURB_TOP
	var query := PhysicsRayQueryParameters3D.create(block.to_global(Vector3(91, .7, 16)),
		block.to_global(Vector3(91, -.2, 16)), winter.sidewalks.CURB_SUPPORT_LAYER)
	var hit := scene.get_world_3d().direct_space_state.intersect_ray(query) as Dictionary
	check(curb_y >= .23 and not hit.is_empty() and absf(hit.position.y - curb_y) < .005,
		"raised curb has a physical support surface at the stone height")

	car.position = Vector3(86.5, road_y, 16)
	car.rotation.y = -PI / 2.0
	block.driver_speed = 2.5
	block.reset_steering()
	var front_climbed_first := false
	var nose_lifted := false
	movement_key(KEY_W, true)
	for tick in 120:
		scene._physics_process(1.0 / 60.0)
		winter.update_sedan_suspension(1.0 / 60.0)
		front_climbed_first = front_climbed_first or (winter.wheel_lift[0] > .17 and winter.wheel_lift[2] < .01)
		nose_lifted = nose_lifted or winter.body_pitch > .035
		if car.position.x >= 92.3:
			break
	movement_key(KEY_W, false)
	check(car.position.x >= 92.3 and front_climbed_first and nose_lifted,
		"front tires climb the curb first and the sedan pitches up")
	block.driver_speed = 0.0
	block.long_accel = 0.0
	for tick in 60:
		winter.update_sedan_suspension(1.0 / 60.0)
	check(absf(car.position.y - curb_y) < .02 and absf(winter.heave_velocity) < .01
		and absf(winter.body_pitch) < .01, "the car settles on the curb height after all four wheels climb")

	var rut := false
	for i in 48:
		var tire := Vector2(89.6+i*.0625,16.+winter.wheel_mounts[0].x)
		var surface: Vector2 = winter.pack.surface_at(tire)
		if surface.y > .04 and winter.pack.remaining(tire,surface) < surface.y*.5:
			rut = true
	check(rut,"driving over the bank leaves a compressed tire track in the physical snow")

	movement_key(KEY_S, true)
	for tick in 230:
		scene._physics_process(1.0 / 60.0)
		winter.update_sedan_suspension(1.0 / 60.0)
		if car.position.x <= 86.5:
			break
	movement_key(KEY_S, false)
	block.driver_speed = 0.0
	block.long_accel = 0.0
	for tick in 60:
		winter.update_sedan_suspension(1.0 / 60.0)
	check(car.position.x <= 86.5 and absf(car.position.y - road_y) < .013
		and absf(winter.body_pitch) < .01, "reversing over the curb returns the sedan to road height")

	car.position = Vector3(89.55, road_y, 16)
	car.rotation.y = PI
	for tick in 60:
		winter.update_sedan_suspension(1.0 / 60.0)
	check(winter.wheel_lift[0] > .08 and winter.wheel_lift[1] < .01 and winter.body_roll < -.045,
		"wheels on one side lift independently and the body leans across the curb")

func snow_contact_checks(scene, winter) -> void:
	var pack= winter.pack
	var paving: Mesh = winter.sidewalks.get_node("PavingAndCurb").mesh
	var arrays:=paving.surface_get_arrays(0)
	var flat:=true
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		if is_equal_approx(arrays[Mesh.ARRAY_TEX_UV2][i].x,1.):
			flat=flat and is_equal_approx(arrays[Mesh.ARRAY_VERTEX][i].y,winter.sidewalks.CURB_TOP)
	check(flat,"every top vertex of the paving stays at curb height")
	scene.walker.global_position=scene.block.to_global(Vector3(90.48,winter.sidewalks.CURB_TOP,-2))
	scene.walker.velocity=Vector3.ZERO
	scene.stride.reset()
	for i in 190: scene.walk(scene.block.global_basis.z,false,1./60.)
	var left:=false
	var right:=false
	for x in [90.377,90.583]:
		for i in 280:
			var p:=Vector2(x,-1.8+i*.02)
			var surface:Vector2=pack.surface_at(p)
			if surface.y-pack.remaining(p,surface)>.020:
				if x<90.48: left=true
				else: right=true
	check(left and right,"ordinary walking compresses the snow under alternating feet")
	var p:=Vector2(90.48,0.)
	pack.stamp(p,Vector2.DOWN,true,.5)
	var toe:=p+Vector2(.103,.065)
	var heel:=p+Vector2(.103,-.095)
	var original:Vector2=pack.surface_at(toe)
	var depth:float=pack.remaining(toe,original)
	check(depth<original.y-.02 and depth>=0 and pack.remaining(heel,pack.surface_at(heel))<pack.surface_at(heel).y-.02,"one boot compresses both sides of a snow tile seam without penetrating paving")
	var west=pack.tile_at(toe,int(original.x))
	winter.city.camera.position+=Vector3.UP*100
	pack._process(1.)
	check(not pack.visible_tracks.has(west),"distant prints release their detailed render meshes")
	winter.city.camera.position=scene.block.to_global(Vector3(toe.x,1.7,toe.y))
	pack._process(1.)
	check(pack.visible_tracks.has(west) and is_equal_approx(pack.remaining(toe,original),depth),"the same depression returns when revisiting the tile")
	var count:int=pack.tracks.size()
	var dry:=Vector2(81.,-45.8)
	check(pack.surface_at(dry).y<.003,"plowed road test point is bare")
	pack.stamp(dry,Vector2.RIGHT,true,1.)
	check(pack.tracks.size()==count,"bare pavement takes no imprint")

func street_fixture_checks(block, pack) -> void:
	var lamps:=get_nodes_in_group(&"streetlight_posts")
	var posts:=get_nodes_in_group(&"traffic_posts")
	check(lamps.size()==22 and get_nodes_in_group(&"streetlight_heads").size()==lamps.size() and posts.size()==8,"winter renders one set of streetlights and four traffic posts per junction")
	var supported:=true
	for post: Node3D in lamps+posts:
		var base:=Vector2(post.position.x,post.position.z)
		for offset in [Vector2.ZERO,Vector2(.25,.25),Vector2(-.25,.25),Vector2(.25,-.25),Vector2(-.25,-.25)]:
			var level:int=int(pack.surface_at(base+offset).x)
			supported=supported and level in [1,3]
	check(supported,"every pole footprint sits on the sidewalk")
	var directions:={}
	var lanes:={}
	for child in block.get_children():
		if child is MeshInstance3D and child.material_override in [block.signal_materials[Vector2i(0,0)],block.signal_materials[Vector2i(1,0)]]:
			var normal:Vector3=child.basis.z.normalized()
			var approach:=Vector3i(roundi(normal.x),int(child.position.z>0),roundi(normal.z))
			lanes[approach]=lanes.get(approach,0)+1
		if child is MeshInstance3D and child.material_override in block.pedestrian_materials.values():
			var facing:Vector3=child.basis.z
			var across:bool=child.material_override==block.pedestrian_materials[true]
			var direction:=Vector3i(roundi(facing.x),int(child.position.z>0),roundi(facing.z))
			check((absf(facing.x)>.99)==across,"pedestrian icon faces its own crossing")
			directions[direction]=directions.get(direction,0)+1
	check(lanes=={Vector3i(0,0,-1):2,Vector3i(0,1,-1):2,Vector3i(1,0,0):1,Vector3i(-1,0,0):1,Vector3i(1,1,0):1},"vehicle heads serve southbound Fifth, two-way 34th and westbound 33rd")
	check(directions.size()==8 and directions.values().count(2)==8,"both ends of every marked crossing have an opposing pedestrian face")
	var saved:float=block.cycle
	for across:bool in [false,true]:
		var mat:StandardMaterial3D=block.pedestrian_materials[across]
		var start:=23. if across else 0.
		for sample in [[4.,block.WALK_ICON,1.],[10.1,block.HAND_ICON,1.],[10.7,block.HAND_ICON,0.],[21.7,block.HAND_ICON,1.]]:
			block.cycle=start+sample[0]
			block.update_lights()
			check(mat.albedo_texture==sample[1] and is_equal_approx(mat.albedo_color.a,sample[2]),"pedestrian display follows walk, flashing clearance and steady stop")
	block.cycle=saved
	block.update_lights()

func check_revolving_entry(city, shop) -> void:
	var drum = shop.get_node("ReserveRevolvingDoor")
	var walker: CharacterBody3D = city.walker
	var saved_yaw: float = drum.rotor.rotation.y
	drum.set_physics_process(false)
	var outermost: float = drum.position.z + drum.RADIUS
	check(outermost < shop.FRONT_Z, "Reserve rotor clears the storefront throughout a full turn")
	# Follow one compartment from Fifth into the shop, then the next half turn back.
	var orbit_radius := .73
	var clear := true
	for pass_index in 2:
		var start_angle := pass_index * PI
		var facing := Vector3(sin(start_angle), 0, cos(start_angle))
		drum.rotor.rotation.y = PI*.25 + start_angle
		await physics_frame
		var axle: Vector3 = drum.global_position
		axle.y = shop.to_global(Vector3(0, shop.FLOOR_Y+.01, 0)).y
		var radial: Vector3 = drum.global_basis * facing
		var outside := axle + radial * 1.95
		if pass_index == 0:
			walker.global_position = outside
		var entry := axle + radial * orbit_radius
		clear = walker.move_and_collide(entry-walker.global_position) == null and clear
		for step in range(1, 37):
			var angle := start_angle + step*PI/36.
			drum.rotor.rotation.y = PI*.25 + angle
			await physics_frame
			var target: Vector3 = axle + drum.global_basis * Vector3(sin(angle),0,cos(angle)) * orbit_radius
			clear = walker.move_and_collide(target-walker.global_position) == null and clear
		var exit_point := axle - radial * 1.95
		clear = walker.move_and_collide(exit_point-walker.global_position) == null and clear
	check(clear, "walking capsule can enter and exit through the rotating Reserve door")
	drum.rotor.rotation.y = saved_yaw
	drum.set_physics_process(true)

func reserve_visit(city) -> void:
	var shop=city.block.reserve
	var walker:CharacterBody3D=city.walker
	var inward:Vector3=-shop.global_basis.z
	var x:float=shop.DOOR_X
	await check_revolving_entry(city,shop)
	walker.global_position=shop.to_global(Vector3(x,.16,1.65))
	walker.velocity=Vector3.ZERO
	for i in 90: city.walk(inward,false,1./60.)
	check(shop.to_local(walker.global_position).z>.24,"closed Reserve door stops the walking capsule")
	city.interact()
	for i in 60: shop._physics_process(1./60.)
	await physics_frame
	check(shop.opened and shop.door.rotation.y>1.5,"E swings the Reserve door clear")
	for i in 95: city.walk(inward,false,1./60.)
	check(shop.inside(shop.to_local(walker.global_position)),"walk through the cut in the original survey wall")
	for local_target in [Vector3(x,.16,-5.75),Vector3(6.5,.16,-5.75),Vector3(6.3,.16,-9.)]:
		await walk_to_shop_point(city,shop,local_target)
	city.interact()
	check(shop.order==shop.Order.BREWING,"order a coffee at the staffed counter")
	city.interact()
	for i in 165: shop._physics_process(1./60.)
	check(shop.order==shop.Order.READY and shop.cup.visible and shop.cup.get_parent()==shop,"barista presents one brewed cup")
	city.interact()
	check(shop.order==shop.Order.CARRIED and shop.cup.get_parent()==city.camera,"pick up the cup with the same interaction key")
	for local_target in [Vector3(6.5,.16,-5.75),Vector3(x,.16,-5.75),Vector3(x,.16,1.8)]:
		await walk_to_shop_point(city,shop,local_target)
	check(not shop.inside(shop.to_local(walker.global_position)) and shop.cup.visible,"carry the same coffee back out onto Fifth")
	city.toggle_body()
	shop._physics_process(1./60.)
	check(not shop.cup.visible,"leaving the body detaches the first-person cup from view")
	city.toggle_body()

func walk_to_shop_point(city,shop,point:Vector3) -> void:
	var goal:Vector3=shop.to_global(point)
	for i in 480:
		var delta:Vector3=goal-city.walker.global_position
		delta.y=0
		if delta.length()<.10: break
		city.walk(delta.normalized(),false,1./60.)
	check(Vector2(shop.to_local(city.walker.global_position).x,shop.to_local(city.walker.global_position).z).distance_to(Vector2(point.x,point.z))<.18,"Reserve walking route reaches "+str(point))
