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
			block.drive(1.0/60, .55, clampf(-angle*2.4,-1,1))
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
	walker.velocity = -block.global_basis.x * (3.0 * scene.METRES_PER_SECOND_PER_MPH)
	for tick in 850:
		walker.move_and_slide()
	check(absf(walker.position.distance_to(origin)-19.0)<.12, "walk the measured crossing at 3 mph")
	var waited := false
	var yielded := false
	var turned := false
	var crossed := false
	var first_walker: Vector3 = block.walkers[0].node.position
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
	print(checks," Midtown checks, ",failures," failures")
	quit(1 if failures else 0)
