extends SceneTree
var w
var failures=[]
func _initialize():call_deferred("run")
func check(ok,label):
	if not ok:failures.append(label);push_error(label)
func frames(count):
	for i in count:
		await physics_frame
		await process_frame
func run():
	w=load("res://bay/islands.tscn").instantiate()
	root.add_child(w);await frames(6);w.start_test();await frames(12)
	var p=w.player
	var o=w.ops
	# Approach public banks from the river, disembark, and use normal swim/walk controls.
	for ix in [0,1]:
		var poly=w.atlas.outlines[ix]
		var a=poly[2];var b=poly[3]
		var f=(b-a).normalized()
		var outward=Vector3(f.y,0,-f.x)
		var mid=(a+b)*.5
		var crest=Vector3(mid.x,2.6,mid.y)
		var boat=w.fleet.launch[0]
		boat.position=crest+outward*23;boat.position.y=0
		p.board(boat);p.interact()
		check(p.vehicle==null,"Leave the boat at bank %d"%ix)
		p.reset_player(crest+outward*16.-Vector3.UP*3.1)
		p.yaw=atan2(outward.x,outward.z);p.pitch=.15;p.analog=Vector2(0,-1)
		Input.action_press("jump");await frames(45);Input.action_release("jump")
		await frames(430);p.analog=Vector2.ZERO
		check(p.position.y>2.45 and (p.position-crest).dot(outward)<0,"Swim and walk ashore at bank %d, ended %s"%[ix,p.position])
	var car=w.spawn_vehicle("sedan",Vector3(80,2.63,102))
	p.reset_player(car.driver_door());o.request_vehicle(car)
	check(o.lock_target==car and p.vehicle==null,"Parked car starts a visible entry")
	o.tick_entry(.46)
	check(not car.door_glass.visible,"Broken glass remains broken")
	o.hurt(2);check(o.lock_target==null and p.vehicle==null,"Damage interrupts entry")
	o.request_vehicle(car);o.tick_entry(1.06)
	check(car.door_open>0 and p.vehicle==null,"Door opens before seating")
	o.tick_entry(1.20)
	check(p.vehicle==car and car.owned,"Seated after the door closes")
	p.reset_player(car.driver_door());car.owned=false;car.driving_npc=true
	o.request_vehicle(car);o.tick_entry(.16)
	check(o.lock_target==null and car.driving_npc,"Releasing a moving driver's door cancels")
	Input.action_press("interact");o.request_vehicle(car);o.tick_entry(.8);o.tick_entry(1.06)
	check(not car.driving_npc and not car.driver.visible and not p.vehicle,"Driver physically exits before control changes")
	o.tick_entry(1.20);Input.action_release("interact")
	check(p.vehicle==car,"Occupied entry completes")
	var cruiser=w.fleet.cruiser[0]
	var cop=cruiser.crew[0]
	p.reset_player(cruiser.position+Vector3.RIGHT*8)
	cop.deploy();o.alert(p.position,3);o.extract_timer=1.;o.arrest=.6
	cop.react_to_fire(p.position);cop._physics_process(.02)
	check(cop.role=="take cover" and o.arrest==0 and o.extract_timer==0,"Incoming fire interrupts arrest and extraction")
	o.clear_strip();o.strip_unit=cruiser;o.strip_officer=cop;o.strip_goal=cop.position
	o.strip_deadline=w.clock+30;cop.under_fire_until=-1
	o.update_strip(.6);check(not o.spikes.visible,"Strip cannot arm before deployment")
	o.update_strip(.7);check(o.spikes.visible,"Officer completes strip placement")
	car.position=o.strip_goal;car.rotation.y=0
	p.board(car);o.update_strip(.016)
	check(not car.spike,"Between axles is not a tire crossing")
	car.position.z+=car.axle_span*.5;o.update_strip(.016)
	check(car.spike and car.flat_count==2,"Only wheels crossing the strip puncture")
	o.clear_strip();o.wanted=0;w.chase=false
	p.reset_player(Vector3(18,2.65,67.5))
	for other in w.vehicles:
		if other.position.distance_to(p.position)<60:other.position.z+=100
	car.position=Vector3(-2,2.62,67.5);car.rotation.y=-PI/2
	car.owned=false;car.spike=false;car.flat_count=0;car.speed=8;car.velocity=Vector3.RIGHT*8
	car.driving_npc=true;car.mission_driver=true;car.threat_until=0
	car.traffic_route=PackedVector3Array([Vector3(55,2.65,65)])
	car.lane_origin=Vector3(-15,2.65,65);car.junction_id=-1
	var hp=o.hp;var shifted=false
	for i in 510:
		await physics_frame;await process_frame
		if car.pass_until>w.clock:shifted=true
	check(o.hp>=hp and absf(p.position.x-18.)<.5,"Civilian brakes without pushing the pedestrian")
	check(shifted and car.position.x>22.,"Civilian passes a persistent obstruction when clear, ended %s"%car.position)
	print("WATERFRONT_CHECKS failures=",failures)
	quit(0 if failures.is_empty() else 1)
