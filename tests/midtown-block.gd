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

func movement_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func winter_stride_checks() -> void:
	var scene = load("res://winter/night.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	var start: Vector3 = scene.walker.position
	var heading: Vector3 = Basis(Vector3.UP, scene.yaw) * Vector3.FORWARD
	for i in 360:
		scene.walk(heading, false, 1.0/60)
	var displacement: Vector3 = scene.walker.position - start
	check(displacement.dot(heading)>12.5 and displacement.cross(heading).length()<.02, "first six seconds of walking clear the parked car")
	var winter = scene.get_node("Winter")
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
	scene.drive_audio.update(block.driver_speed,1,0,1./60)
	check(scene.drive_audio.motor.playing and scene.drive_audio.tires.playing,"driving activates rolling and motor audio")
	block.driver_speed=0
	scene.interact()
	check(not scene.driving and not scene.drive_audio.motor.playing,"parking stops the drive loops")
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
	scene.queue_free()

func snow_contact_checks(scene, winter) -> void:
	var pack= winter.pack
	var paving: Mesh = winter.sidewalks.get_node("PavingAndCurb").mesh
	var arrays:=paving.surface_get_arrays(0)
	var flat:=true
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		if is_equal_approx(arrays[Mesh.ARRAY_TEX_UV2][i].x,1.):
			flat=flat and is_equal_approx(arrays[Mesh.ARRAY_VERTEX][i].y,winter.sidewalks.CURB_TOP)
	check(flat,"every top vertex of the paving stays at curb height")
	scene.walker.global_position=scene.block.to_global(Vector3(90.48,.159,-2))
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
	check(lamps.size()==22 and posts.size()==8,"winter renders one set of streetlights and four traffic posts per junction")
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

func reserve_visit(city) -> void:
	var shop=city.block.reserve
	var walker:CharacterBody3D=city.walker
	var inward:Vector3=-shop.global_basis.z
	var x:float=shop.DOOR_X
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
