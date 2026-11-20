extends SceneTree

var failures: Array = []
var count = 0
var w: Node3D

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func check(ok: bool,text: String) -> void:
	count += 1
	if not ok:
		failures.append(text)
		push_error(text)

func run() -> void:
	w = load("res://main.tscn").instantiate()
	root.add_child(w)
	await frames(4)
	w.start_test()
	var o = w.ops
	var p = w.player
	check(o.stage=="available","operation never auto-accepts")
	p.reset_player(o.cabinet+Vector3(0,0,1.7))
	o.interact()
	check(o.puzzle==null and o.stage=="available","mission cabinet cannot be searched early")
	p.reset_player(o.job_board+Vector3(0,0,2))
	o.interact()
	check(o.stage=="enter","accept operation at physical job board")
	p.reset_player(Vector3(-45,2.8,38))
	await frames(2)
	check(o.stage=="lift","arriving at reception advances without pressing E")
	p.reset_player(Vector3(-52,2.8,20))
	o.interact()
	check(o.visitor_card,"reception provides a guest keycard")
	p.reset_player(Vector3(-34.5,2.85,18))
	await frames(25)
	o.lift.use()
	await frames(175)
	print("LIFT_RIDER ",p.position," cabin ",o.lift.position)
	check(p.position.y>6.5,"physical lift carries player to actual upper floor")
	check(o.stage=="archive","guest floor arrival advances operation")
	Input.action_press("back")
	await frames(45)
	Input.action_release("back")
	print("LIFT_EXIT ",p.position)
	for i in p.get_slide_collision_count():
		var body = p.get_slide_collision(i).get_collider()
		print("LIFT_CONTACT ",body.get_parent().global_position)
	check(p.position.z>20.5,"lift exit apron is clear of furniture")
	p.reset_player(Vector3(-54.5,6.9,28))
	o.interact()
	var door = o.passages[0]
	await frames(40)
	check(door.opened and not door.locked,"keycard opens physical suite door")
	Input.action_press("forward")
	await frames(55)
	Input.action_release("forward")
	print("SUITE_ENTRY ",p.position)
	check(p.position.z<25.5,"player walks through opened suite doorway")
	p.reset_player(o.cabinet+Vector3(0,0,1.7))
	o.interact()
	check(o.puzzle!=null,"cabinet opens interactive circuit only during its mission stage")
	check(not o.circuit_connected(),"scrambled circuit cannot immediately complete")
	o.test_circuit()
	check(o.stage=="archive","failed circuit keeps operation active")
	var solved = [10,10,12,6,10,9,3,10,10]
	for i in 9:
		for rotation in 4:
			if o.pipes[i]==solved[i]:
				break
			o.rotate_pipe(i)
	check(o.circuit_connected(),"rotating tiles connects the actual circuit graph")
	o.test_circuit()
	check(o.stage=="escape" and not o.ledger_mesh.visible,"successful circuit retrieves ledger and clears its world marker")
	check(o.wanted==3,"ledger theft creates a bounded real pursuit")
	check(o.target()==o.pier,"escape waypoint points to the physical dock rather than ocean")
	var window = o.passages.filter(func(x): return x.title=="Fire-escape window")[0]
	window.take_damage(28)
	check(window.broken and window.panel.collision_layer==0,"shot glass removes its physical obstruction")
	p.reset_player(Vector3(-56.5,6.85,25))
	p.yaw = PI/2
	Input.action_press("forward")
	Input.action_press("jump")
	await frames(65)
	Input.action_release("forward")
	Input.action_release("jump")
	print("WINDOW_EXIT ",p.position)
	check(p.position.x<-59.5,"jump passes through broken window onto actual exterior route")
	# Use real route graph across floors instead of straight pursuit through a wall.
	var path = o.foot_path(Vector3(-75,2.65,65),Vector3(-54.5,6.8,22))
	check(path.size()>3 and Array(path).any(func(v): return v.y>6),"police foot route connects exterior stairs and guest floor")
	# Follow the actual exterior stair/window route, not just the graph points.
	var pursuer = o.officers[0]
	for v in w.vehicles:
		v.set_physics_process(false)
	p.reset_player(Vector3(-52,6.85,17))
	pursuer.position = Vector3(-75,2.7,65)
	pursuer.set_boarded(false)
	o.last_fix = p.position
	o.fix_at = w.clock
	await frames(1080)
	print("STAIR_PURSUER ",pursuer.position," path ",pursuer.path," wanted ",o.wanted)
	check(pursuer.position.y>6.4 and pursuer.position.x>-58 and pursuer.position.distance_to(Vector3(-59,6.8,25))<12,"officer physically follows the stairs into the building")
	for v in w.vehicles:
		v.set_physics_process(true)
	o.hp = 100
	pursuer.set_boarded(true)
	var police = w.vehicles[1]
	p.reset_player(Vector3(-75,2.8,63))
	police.position = Vector3(-75,2.7,55)
	police.velocity = Vector3.ZERO
	await frames(3)
	for n in police.crew:
		n.deploy()
	check(police.crew.any(func(n): return not n.boarded),"cruiser crew physically deploys beside its car")
	check(o.officers.filter(func(n): return not n.boarded).size()<=4,"bounded crews instead of spawning an officer swarm")
	var before_hp = o.hp
	o.hurt(7)
	o.hurt(7)
	check(o.hp==before_hp-7,"damage is rate-limited rather than instantly stacked")
	o.armed = true
	o.ammo = 4
	o.reload()
	await frames(72)
	check(o.ammo==12 and o.reserve==64,"reload transfers actual reserve ammunition")
	o.toggle_map()
	var before_clock = w.clock
	var before_car = police.position
	await frames(20)
	check(is_equal_approx(w.clock,before_clock) and police.position==before_car,"map pauses simulation")
	check(o.audio.paused,"map pauses engine/siren audio rather than holding a tone")
	o.toggle_map()
	p.reset_player(o.pier)
	await frames(3)
	check(o.stage=="board","landing on physical dock advances automatically")
	p.reset_player(w.vehicles[3].position+Vector3(2,-.5,0))
	await frames(1)
	p.interact()
	await frames(3)
	check(o.stage=="depart" and p.vehicle==w.vehicles[3],"actual launch boarding starts departure stage")
	check(o.target()==o.departure,"water waypoint only appears after boarding")
	p.vehicle.position = o.departure
	o.wanted = 0
	w.chase = false
	await frames(3)
	check(o.stage=="complete" and o.cash==2450,"delivering ledger safely completes operation and pays once")
	await frames(10)
	check(o.cash==2450,"completed job does not pay repeatedly or auto-start another")
	w.reset_test()
	await frames(3)
	check(o.hp==100 and o.wanted==0,"reset restores a playable state")
	print("PLAYABLE_SLICE_CHECKS ",count," passed=",count-failures.size()," failed=",failures.size())
	w.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
