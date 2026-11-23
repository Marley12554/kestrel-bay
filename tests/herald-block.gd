extends SceneTree

const GRADE := preload("res://survey/grade.gd")
const ORIGIN := Vector2(301419,65177)
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func world(e: float, n: float) -> Vector3:
	return Vector3(e-ORIGIN.x,0.,ORIGIN.y-n)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var city = load("res://winter/night.tscn").instantiate()
	root.add_child(city)
	await physics_frame
	await physics_frame
	city.set_physics_process(false)
	city.set_process(false)
	var winter = city.get_node("Winter")
	winter.set_physics_process(false)
	var block = city.block
	block.set_physics_process(false)
	var space: PhysicsDirectSpaceState3D = city.get_world_3d().direct_space_state
	# Off-grid readings from the original one-foot DEM, in metres NAVD88.
	for point in [[301046.48,64852.83,14.953],[301064.52,64842.76,15.124],
			[301056.02,64913.12,15.248],[301094.20,64896.53,15.841],
			[301052.20,64894.60,15.058],[301085.04,64880.80,15.682],
			[301077.31,64904.35,15.725],[301054.20,64840.57,14.936]]:
		var at := world(point[0],point[1])
		var y := GRADE.height(at)
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*12.,at-Vector3.UP,8)
		var hit := space.intersect_ray(ray)
		check(absf(y+10.-point[2]) < .08,"game grade agrees with the source DEM at "+str(point))
		check(not hit.is_empty() and absf(hit.position.y+10.-point[2]) < .10,"physical pavement agrees with source at "+str(point))
	var original: Vector3 = city.walker.global_position
	# The old snow field used to pull the player several metres below these streets.
	var aligned := true
	for overlap in [Vector3(-300.61,0.,367.31),Vector3(-306.,0.,370.),Vector3(-315.,0.,380.)]:
		var pick := space.intersect_ray(PhysicsRayQueryParameters3D.create(overlap+Vector3.UP*12.,overlap-Vector3.UP*2.,8))
		if pick.is_empty():
			aligned = false
			continue
		city.walker.global_position = overlap
		city.walk(Vector3.ZERO,false,1./60.)
		aligned = aligned and city.walker.position.y>=pick.position.y-.01 and city.walker.position.y<=pick.position.y+.36
	check(aligned,"live walking controller stands on the visible graded surface throughout the snow overlap")
	city.walker.global_position = original
	var original_view: Transform3D = city.camera.global_transform
	var evening_env: Environment = city.get_node("Environment").environment
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	root.push_input(key)
	check(winter.daylight and city.get_node("Environment").environment != evening_env,"T selects the daylight sky")
	check(is_zero_approx(winter.day_environment.fog_sky_affect), "street haze preserves the daylight sky and sun disk")
	check(city.walker.position == original and city.camera.global_transform == original_view,"lighting toggle preserves position and view")
	root.push_input(key)
	check(not winter.daylight and city.get_node("Environment").environment == evening_env,"T restores the same evening sky")
	city.visit_pilot()
	check(city.walker.global_position.distance_to(original)>100 and absf(city.walker.position.y-4.64)<.12,"J reaches the plaza at walking height")
	city.visit_pilot()
	check(city.walker.global_position.is_equal_approx(original) and city.camera.global_transform.is_equal_approx(original_view),"J restores the original street view")
	var pilot = city.get_node("HeraldSquare")
	var mesh: MeshInstance3D = pilot.find_children("*","MeshInstance3D",true,false)[0]
	check(absf((mesh.global_transform*mesh.get_aabb()).end.y-105.5834)<.03,"survey roof keeps its common vertical datum")
	check(pilot.vestibules.size()==2,"both lobby thresholds follow the access plan")
	for entry: Dictionary in pilot.vestibules:
		var frame: Node3D = entry.frame
		var floor_at := frame.to_global(Vector3(0.,0.,-1.6))
		var floor_ray := PhysicsRayQueryParameters3D.create(floor_at+Vector3.UP*.75,floor_at-Vector3.UP*.75,8)
		var picked := space.intersect_ray(floor_ray)
		check(not picked.is_empty() and picked.collider==pilot.get_node("VestibuleFloors") and absf(picked.position.y-floor_at.y)<.025,
				"level vestibule floor replaces outdoor pavement behind its threshold")
	# Follow the Sixth Avenue sidewalk the same way the player does.
	var start := world(301069.6,64848.5)
	var heading := Vector3(.488,0.,-.873)
	start.y = GRADE.physical_height(space,start)
	city.walker.global_position = start
	for tick in 1350: city.walk(heading,false,1./60.)
	var end: Vector3 = city.walker.global_position
	check((end-start).dot(heading)>43. and end.y-start.y>.36,"walk uphill along the length of the block")
	check(absf(end.y-GRADE.physical_height(space,end))<.06,"walker's feet remain on the rendered pavement")
	# Cross the transition along West 35th, then probe across the curb face
	# at the south plaza. These casts require the shipped collision itself.
	var across := Vector3(.873,0.,.488)
	var crossing := world(301044.5,64845.8)
	for route in [[crossing-across*73.,across,115.], [world(301053.1,64822.4),Vector3(-.488,0.,-.873),23.]]:
		var complete := true
		var max_step := 0.
		var last_height := INF
		for i in range(ceili(float(route[2])/.19)):
			var pt: Vector3 = route[0] + route[1]*(i*.19)
			var ray := PhysicsRayQueryParameters3D.create(pt+Vector3.UP*12.,pt-Vector3.UP*3.,8)
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				complete = false
				break
			var ground: float = hit.position.y
			if is_finite(last_height): max_step = maxf(max_step,absf(ground-last_height))
			last_height = ground
		check(complete and max_step < .28,"continuous road and curb collision, maximum step "+str(max_step))
	start = crossing-across*59.
	start.y = GRADE.physical_height(space,start)
	city.walker.global_position = start
	city.walker.velocity = Vector3.ZERO
	for tick in 900: city.walk(across,false,1./60.)
	check((city.walker.position-start).dot(across)>29. and absf(city.walker.position.y-GRADE.physical_height(space,city.walker.position))<.075,"walk across the 35th Street terrain transition")
	# Drive from 35th toward 36th with the live four-wheel suspension.
	var car: CharacterBody3D = block.parked
	start = world(301075.4,64846.2)
	start.y = GRADE.physical_height(space,start)+winter.road_ride_height
	car.global_position = start
	car.global_rotation.y = atan2(-heading.x,-heading.z)
	block.driven = true
	block.driver_speed = 7.
	winter.body_heave = start.y-winter.road_ride_height
	for tick in 355:
		block.drive(1./60.,.25,0.)
		winter.update_sedan_suspension(1./60.)
	end = car.global_position
	check((end-start).dot(heading)>28. and end.y-start.y>.22,"drive uphill with live wheel support")
	check(absf(end.y-winter.road_ride_height-GRADE.physical_height(space,end))<.13,"suspension follows the road on grade")
	start = crossing-across*59.
	start.y = GRADE.physical_height(space,start)+winter.road_ride_height
	car.global_position = start
	car.global_rotation.y = atan2(-across.x,-across.z)
	block.driver_speed = 7.
	winter.body_heave = start.y-winter.road_ride_height
	for tick in 360:
		block.drive(1./60.,.27,0.)
		winter.update_sedan_suspension(1./60.)
	check((car.global_position-start).dot(across)>28. and absf(car.global_position.y-winter.road_ride_height-GRADE.physical_height(space,car.global_position))<.14,"drive across the 35th Street terrain transition")
	check(is_zero_approx(GRADE.height(original)),"legacy terrain outside the collar retains its placement")
	city.queue_free()
	await process_frame
	await process_frame
	print(checks," Herald Square checks, ",failures," failures")
	quit(1 if failures else 0)
