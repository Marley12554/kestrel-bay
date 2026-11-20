extends SceneTree
var w: Node3D
var failures: Array = []
var count = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,text: String) -> void:
	count += 1
	if not ok:
		failures.append(text)
		push_error(text)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func run() -> void:
	w = load("res://main.tscn").instantiate()
	root.add_child(w)
	await frames(5)
	w.start_test()
	var o = w.ops
	var p = w.player
	p.reset_player(Vector3(0,2.8,96))
	o.alert(p.position,3)
	var nearest = [INF,INF]
	var harm = 0.0
	for i in 1800:
		await frames(1)
		for j in 2:
			nearest[j] = minf(nearest[j],w.vehicles[j+1].position.distance_to(p.position))
		if o.hp<100:
			harm += 100-o.hp
			o.hp = 100
	print("NATURAL_RESPONSE nearest=",nearest," damage=",harm)
	for v in [w.vehicles[1],w.vehicles[2]]:
		print("CRUISER ",v.position," speed=",v.speed," crew=",v.crew.map(func(n): return [n.boarded,n.role,n.position]))
	check(nearest.max()<35,"an existing cruiser reaches an idle wanted suspect naturally")
	check(o.officers.any(func(n): return not n.boarded),"cruiser automatically deploys a real crew")
	check(harm>0,"officers can damage a stationary exposed suspect")
	check(o.officers.size()==4,"response stays bounded to its real existing crews")
	# Vehicle concealment isn't accidental immunity: target hulls count as sightings.
	p.reset_player(Vector3(-3,2.8,108))
	p.interact()
	await frames(2)
	check(o.sees_player(Vector3(-5,4,120)),"a visible suspect vehicle counts as a sighting")
	var car = p.vehicle
	car.position = Vector3(-75,2.8,64)
	car.velocity = Vector3.ZERO
	p.position = car.position
	var extractor = o.officers[0]
	extractor.position = car.position+Vector3(2,0,0)
	extractor.set_boarded(false)
	await frames(155)
	check(p.vehicle==null,"officer can force an idle driver out rather than merely stand beside the car")
	check(o.extract_timer<2,"vehicle extraction state clears after completion")
	print("RESPONSE_CHECKS ",count," passed=",count-failures.size()," failed=",failures.size())
	w.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
