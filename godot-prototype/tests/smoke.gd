extends SceneTree

var failures: Array = []
var checks = 0
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_test()
	check(not world.started,"entry cannot bypass lighting warm-up")
	await frames(3)
	check(world.warmup_ready,"headless startup explicitly completes without claiming GPU warm-up")
	check(world.warmup_rendered_views==0,"headless checks do not claim to draw GPU views")
	check(world.lighting_warmup_views().size()>=8,"warm-up covers city, interior, headlights, waterfront and underwater views")
	check(not world.night and not world.environment.fog_enabled,"warm-up restores day and above-water environment")
	check(not world.start_button.disabled and not world.warmup_cover.visible,"warm-up releases loading cover and enables entry")
	check(not world.player.is_physics_processing() and world.vehicles.all(func(v): return not v.is_physics_processing()),"simulation stays frozen behind welcome screen")
	world.start_test()
	check(world.player.is_physics_processing() and world.vehicles.all(func(v): return v.is_physics_processing()),"entry activates player and vehicles")
	var p = world.player
	check(world.vehicles.size()==6,"six prototype vehicles created")
	check(p.camera.near<.1,"human camera uses a close near plane")
	var launches = world.vehicles.filter(func(v): return v.boat)
	for v in launches:
		check(is_equal_approx(v.max_speed,launches[0].max_speed),"same boat has identical player/AI speed")
		check(is_equal_approx(v.acceleration,launches[0].acceleration),"same boat has identical acceleration")
	# Test the shipped movement functions, with fixed frame durations.
	await frames(15)
	var start_z = p.position.z
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	check(p.position.z<start_z-1.5,"first-person walking moves at human scale")
	check(p.position.y>2.4,"player supported by real island geometry")
	# Walk through the actual hotel opening to its lobby.
	p.reset_player(Vector3(-45,2.9,44))
	Input.action_press("forward")
	await frames(160)
	Input.action_release("forward")
	print("HOTEL_POSITION ",p.position)
	check(p.position.z<35 and p.position.z>25,"hotel interior reached through physical doorway")
	check(p.position.y>2.4 and p.position.y<3.2,"hotel remains at its real world location")
	# Walk up the actual exterior stair without jumping.
	p.reset_player(Vector3(-64.5,2.8,47))
	Input.action_press("forward")
	await frames(290)
	Input.action_release("forward")
	print("STAIR_POSITION ",p.position)
	check(p.position.z<30.5 and p.position.y>6.4,"exterior stairs reach the upper landing smoothly")
	# Vehicle access and physical travel across both bridge ramps.
	p.reset_player(Vector3(-3,2.9,108))
	await frames(2)
	p.interact()
	check(p.vehicle==world.vehicles[0],"nearby starter car can be entered")
	var car = world.vehicles[0]
	car.position = Vector3(158,3.0,65)
	car.rotation.y = -PI/2
	car.velocity = Vector3.ZERO
	Input.action_press("forward")
	await frames(660)
	Input.action_release("forward")
	print("BRIDGE_POSITION ",car.position," velocity ",car.velocity," slides ",car.get_slide_collision_count())
	check(car.position.x>385,"car traverses full bridge without a ramp blocking its junction")
	check(car.position.y>2.3,"car stays physically supported across bridge")
	p.interact()
	check(p.vehicle==null,"car exit finds a clear physical position")
	# Sweep a full hull toward another hull at much more than a frame's travel.
	for v in world.vehicles:
		v.set_physics_process(false)
	p.set_physics_process(false)
	var a = launches[0]
	var b = launches[1]
	a.position = Vector3(0,0,225)
	b.position = Vector3(0,0,210)
	a.rotation = Vector3.ZERO
	b.rotation = Vector3.ZERO
	await frames(2)
	var contact = a.move_and_collide(Vector3(0,0,-35))
	check(contact!=null,"swept boat motion hits another hull rather than tunneling")
	check(a.position.z-b.position.z>=8.4,"bow and stern remain separated")
	# Swim into the cabin side, then verify passive sinking and breath loss.
	p.reset_player(Vector3(4,-.5,a.position.z))
	p.yaw = PI/2
	p.set_physics_process(true)
	Input.action_press("forward")
	await frames(120)
	Input.action_release("forward")
	check(p.position.x>1.3,"swimmer cannot pass through a boat hull")
	p.reset_player(Vector3(-25,-2.1,225))
	var before = p.position.y
	await frames(120)
	check(p.position.y<before-.35,"idle swimmer slowly sinks")
	check(p.breath<90,"submerged head consumes oxygen")
	Input.action_press("jump")
	await frames(45)
	Input.action_release("jump")
	check(p.position.y>before,"upward strokes regain the surface")
	world.set_night(true)
	check(world.night and world.lamps.all(func(l): return l.visible),"night activates the street lighting")
	world.set_night(false)
	check(world.lamps.all(func(l): return not l.visible),"daytime disables street lighting")
	print("GODOT_PROTOTYPE_CHECKS ",checks," passed=",checks-failures.size()," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
