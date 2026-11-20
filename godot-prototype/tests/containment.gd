extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var world=load("res://bay/islands.tscn").instantiate()
	root.add_child(world)
	for i in 6:
		await physics_frame
		await process_frame
	world.start_test()
	var car=world.vehicles[0]
	var player=world.player
	var ops=world.ops
	car.position=Vector3(-10,2.85,131)
	player.reset_player(car.position+Vector3.UP)
	player.board(car)
	ops.alert(car.position,5)
	ops.observe(car.position)
	var closest=INF
	var opened=false
	var elapsed=0.
	for frame in 6000:
		await physics_frame
		elapsed=frame/60.
		for unit in ops.officers:
			if not unit.boarded:
				closest=minf(closest,unit.position.distance_to(car.position))
				if unit.role=="extract" and ops.extract_timer>0.:opened=true
		if player.vehicle==null:break
	var ok=opened and player.vehicle==null and ops.hp>0 and not car.wreck
	print("CONTAINMENT_CHECKS extracted=",ok," seconds=",elapsed," nearest_officer=",closest," health=",ops.hp)
	if not ok:push_error("Existing patrols did not reach the parked dockside car and extract its driver alive")
	quit(0 if ok else 1)
