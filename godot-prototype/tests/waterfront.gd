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
	# Contact is evaluated at extension and respects intervening geometry.
	var actor=o.civilians[0]
	var home=actor.position
	actor.set_physics_process(false)
	p.reset_player(Vector3(0,2.65,92));p.yaw=0.;p.pitch=0.
	actor.position=p.position+Vector3.FORWARD*1.1
	await frames(2)
	var initial_health=actor.hp
	o.attack_press();await frames(3)
	check(o.hands.visible and actor.hp==initial_health,"Visible wind-up precedes contact")
	await frames(10)
	check(actor.hp==initial_health-16,"One punch lands on extension")
	var first_side=o.hands.side
	o.attack_press();await frames(27)
	check(o.hands.side!=first_side and actor.hp==initial_health-32,"Recovery buffers the opposite hand")
	await frames(21)
	var wall=w.box(w,p.position+Vector3(0,1.,-.61),Vector3(1.,2.2,.12),Color.GRAY,true)
	await frames(1);o.attack_press();await frames(20)
	check(actor.hp==initial_health-32,"Solid wall blocks melee")
	wall.queue_free();actor.position=home;actor.hp=initial_health;actor.set_physics_process(true)
	o.hands.cancel();o.wanted=0;w.chase=false;o.reports.clear()
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
	# A real officer shot animates a short moving tracer up to the first obstruction.
	var shot_origin=Vector3(0,600,0)
	var backstop=w.box(w,shot_origin+Vector3.RIGHT*8.,Vector3(1.,4.,4.),Color.GRAY,true)
	await frames(2)
	o.officer_shot(cop,shot_origin,shot_origin+Vector3.RIGHT*16.)
	check(o.fx.tracers.size()==1,"An officer shot always shows a tracer")
	if not o.fx.tracers.is_empty():
		var tracer=o.fx.tracers[0]
		var mesh=tracer.mesh
		check(is_equal_approx(tracer.distance,7.5),"Shot ray stops at the wall")
		var initial=mesh.position.x
		o.fx._process(.04)
		check(mesh.visible and mesh.position.x>initial and mesh.basis.y.length()<1.5,"Tracer advances as a short streak")
		o.fx._process(.048)
		check(mesh.visible and mesh.to_global(Vector3.UP*.5).x<=7.501,"Tracer does not extend through cover")
		o.fx._process(.15)
		check(not mesh.visible and o.fx.tracers.is_empty(),"Spent tracer returns to its pool")
	backstop.queue_free()
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
	# A right turn from Water Street must exit southbound in its west lane.
	car.position=Vector3(32,2.63,67.5);car.rotation.y=-PI/2
	car.velocity=Vector3.RIGHT*7.;car.speed=7.;car.traffic_lane=0;car.lane_width=13.
	car.lane_origin=Vector3(-15,2.6,65);car.junction_id=-1;car.pass_until=0;car.pass_offset=0
	car.turning_path.clear();car.driving_npc=true
	car.traffic_route=PackedVector3Array([Vector3(55,2.6,65),Vector3(55,2.6,125)])
	for i in 1900:
		await physics_frame;await process_frame
		if car.position.z>86.:break
	check(car.position.z>86. and car.position.x>48.5 and car.position.x<55.,"Right turn exits on the right, ended %s"%car.position)
	car.position=Vector3(-50,2.63,67.5);car.rotation.y=-PI/2
	car.velocity=Vector3.RIGHT*7;car.speed=7;car.steer=0.
	p.board(car);p.analog=Vector2(0,-1)
	Input.action_press("handbrake");await frames(100);Input.action_release("handbrake")
	check(car.speed>8.,"Throttle keeps pulling through held handbrake")
	p.analog=Vector2.ZERO;p.reset_player(car.driver_door())
	# A depleted older save gets the spawn loadout; switching weapons cannot refill it.
	o.campaign.restore({"cash":20,"magazines":[0,0,0,0,0],"reserves":[0,0,0,0,0]})
	check(o.magazines[1]==12 and o.reserves[1]>0,"Loaded pistol and spare ammunition on spawn")
	o.select_slot(1);o.ammo=0;o.reserve=0;o.select_slot(0);o.select_slot(1)
	check(o.ammo==0 and o.reserve==0,"Holstering does not issue more ammo")
	var post=w.get_node("NewYork").get_children().filter(func(n):return n.has_method("knock_down"))[0]
	post.knock_down(Vector3.RIGHT)
	await frames(40)
	check(post.collision_layer==0 and absf(post.get_node("Post").rotation.z)>1.,"Struck post falls clear")
	check(w.atlas.lane_center(18.,0)>0 and w.atlas.lane_center(18.,1)>w.atlas.lane_center(18.,0)+3.,"Distinct travel lanes on the right")
	car.driving_npc=false;car.owned=true;car.mission_driver=false
	var parcel=w.atlas.plots["Copper Kettle"]
	car.position=parcel.at+Vector3(parcel.w*.5+4.,.09,5.)
	car.rotation.y=PI*.5;car.velocity=Vector3.LEFT*19.;car.speed=19.
	p.board(car);p.position=car.position
	w.update_rooms(true)
	var initial_hp=car.health
	var marks=o.fx.wall_scars.size()
	await frames(26)
	check(car.health<initial_hp and car.engine_mesh.has_meta("undamaged") and o.fx.wall_scars.size()>marks,"Impact dents car and marks streamed building")
	p.reset_player(car.driver_door())
	car.position=Vector3(-500,0.,300);car.rotation=Vector3.ZERO
	car.speed=0.;car.velocity=Vector3.ZERO;car.spike=false;car.flat_count=0
	p.board(car)
	await frames(32)
	check(car.flooded and p.vehicle==car,"Submersion gives a brief interval before ejection")
	await frames(70)
	check(not p.vehicle and car.flooded and car.position.y<p.position.y+.2,"Swimmer and sinking car separate")
	print("WATERFRONT_CHECKS failures=",failures)
	quit(0 if failures.is_empty() else 1)
