extends SceneTree
var w
var o
var p
var c
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(ok,what):
	checks+=1
	if not ok:failures.append(what);push_error(what)
func frames(n):
	for i in n:await physics_frame;await process_frame
func move_to(at):
	p.reset_player(at+Vector3.UP*.13);w.update_rooms(true)
func phase(at):
	move_to(at);c.tick(.05)
func checkpoint(name):
	check(c.step==name,"Expected "+name+" in "+c.job+", got "+c.step)
func solve():
	check(o.puzzle!=null,"Panel opened")
	if o.puzzle==null:return
	var solution=[10,10,12,6,10,9,3,10,10]
	for i in 9:
		for turns in 4:
			if o.pipes[i]==solution[i]:break
			o.rotate_pipe(i)
	check(o.circuit_connected(),"Circuit tiles can rotate into a connected circuit")
	o.test_circuit()
func accept(id):
	if p.vehicle:move_to(w.atlas.marks["Pier 04"])
	c.accept(id);check(c.job==id,"Accepted "+id)
func done(id):
	check(c.job.is_empty() and id in c.completed,"Paid completion "+id)
func run():
	w=load("res://bay/islands.tscn").instantiate();root.add_child(w)
	await frames(6);w.start_test();await frames(27)
	o=w.ops;p=w.player;c=o.campaign
	check(w.started and o.routes_ready and p.is_on_floor(),"City boots on real ground")
	check(w.atlas.data.parcels.size()>1300 and w.shells.size()==w.atlas.data.parcels.size(),"Solid exterior on every parcel")
	var graph=w.atlas.graph
	var nodes=graph.get_point_ids()
	var frontier=[nodes[0]];var visited={}
	while not frontier.is_empty():
		var at=frontier.pop_back()
		if visited.has(at):continue
		visited[at]=true
		for n in graph.get_point_connections(at):frontier.append(n)
	check(visited.size()==nodes.size(),"Every road junction connected (%d/%d)"%[visited.size(),nodes.size()])
	for i in 8:
		var direction=Vector3.FORWARD.rotated(Vector3.UP,i*PI*.25)
		check(o.hud.heading(i*PI*.25).distance_to(Vector2(direction.x,direction.z))<.0001,"Map compass eighth "+str(i))
	o.toggle_map()
	check(paused and o.audio.paused and o.hud.map_buttons.size()==11,"Map pauses simulation, audio and shows eleven contracts")
	o.hud.select_job(c.JOBS[4]);o.hud.accept_selected()
	check(not paused and not o.audio.paused and c.step=="marina","Accepted prison job through casebook")
	check(c.goal==w.atlas.marks["Pier 04"] and w.night_lock,"First waypoint is the mainland pier")
	phase(c.goal);checkpoint("boat")
	var launch=w.vehicles[3]
	p.board(launch);p.position=launch.position;c.tick(.1);checkpoint("land")
	phase(w.atlas.marks["Blackwater Service Dock"]);checkpoint("breach")
	check(c.earned_dock,"Exterior landing earned the checkpoint")
	c.fail_job("QA retry");c.accept("island");checkpoint("breach")
	check(p.position.distance_to(w.atlas.marks["Blackwater Service Dock"])<1.,"Retry remains outside")
	move_to(c.goal+Vector3(1.9,0,0));o.interact();solve();checkpoint("gate")
	move_to(c.goal+Vector3(0,0,-2));o.interact();solve();checkpoint("wing")
	c.lockdown=true;c.tick(.1);check(c.job=="island","Discovery keeps prison mission playable")
	phase(c.goal);checkpoint("release")
	move_to(c.goal+Vector3(0,0,1.2));o.interact();solve();checkpoint("escort_gate")
	move_to(c.goal);c.escort.position=p.position+Vector3.RIGHT*2;c.tick(.1);checkpoint("extract")
	launch.position=w.atlas.marks["Blackwater Service Dock"]+Vector3(4,-1.7,-6)
	p.board(launch);p.position=launch.position;c.escort.position=p.position+Vector3.RIGHT*3
	c.escort._physics_process(.016);c.tick(.1);checkpoint("return")
	launch.position=w.atlas.marks["Pier 04"]+Vector3(5,-1.7,-1);p.position=launch.position
	c.escort._physics_process(.016);c.tick(.1);done("island")
	check(not c.earned_dock and not w.night_lock,"Extraction clears checkpoint and restores time")
	for id in ["shipment","convoy","money"]:
		accept(id)
		c.van.take_damage(55);c.tick(.1)
		check(c.step in ["manifest","cargo"],"Disabling mission vehicle exposes cargo")
		move_to(c.goal+Vector3.RIGHT);o.interact()
		if id=="money":
			checkpoint("accounts");move_to(c.goal+Vector3.RIGHT);o.interact();solve()
		else:phase(c.goal)
		done(id)
	accept("office")
	move_to(c.goal+Vector3.RIGHT);o.interact();checkpoint("files")
	move_to(c.goal+Vector3.RIGHT);o.interact();solve();done("office")
	accept("witness");phase(c.goal);checkpoint("safe")
	move_to(c.goal);c.escort.position=p.position+Vector3.RIGHT*1.3;c.tick(.1);done("witness")
	accept("finale");move_to(c.goal);o.interact();check(o.modal!=null,"Ending choice has a menu");o.close_modal()
	c.choose_ending(0);move_to(c.goal);o.interact();solve();done("finale")
	accept("recovery")
	var recovery=c.van
	p.board(recovery);p.position=recovery.position;c.tick(.1);checkpoint("deliver_car")
	recovery.position=c.goal;p.position=c.goal;recovery.speed=0;c.tick(.1);done("recovery")
	accept("race")
	var starter=w.vehicles[0]
	p.board(starter)
	for op in ["race1","race2","race3",""]:
		starter.position=c.goal;p.position=starter.position;c.tick(.1)
		checkpoint(op)
	done("race")
	accept("base")
	var helicopter=w.fleet["helicopter"][0]
	p.board(helicopter);p.position=helicopter.position;c.tick(.1);checkpoint("land_air")
	p.position=c.goal;helicopter.position=c.goal;c.tick(.1);done("base")
	accept("ledger")
	phase(Vector3(-45,2.65,36));o._physics_process(.016)
	check(o.stage=="lift","Hotel reception triggers by entering")
	phase(Vector3(-54,6.8,28));o._physics_process(.016)
	move_to(o.cabinet+Vector3(0,0,1.4));o.interact();solve()
	check(o.stage=="escape","Hotel records recovered through puzzle")
	phase(o.pier);o._physics_process(.016);p.board(launch);o._physics_process(.016)
	o.wanted=0;w.chase=false;launch.position=o.departure;p.position=launch.position;o._physics_process(.016);c.tick(.016);done("ledger")
	check(c.completed.size()==11,"All eleven missions completed")
	for j in c.JOBS:accept(j[0]);c.abandon()
	move_to(w.atlas.marks["Empire State Building"])
	await frames(3)
	var room=w.nearby_rooms[int(w.atlas.plots["Empire State Building"].id)]
	check(room.floors==86 and room.lift.global_position.distance_to(room.position)<9.,"Landmark contains an 86-story lift in its real footprint")
	var base=room.lift.global_position
	move_to(base);await frames(8);room.lift.destination=2;await frames(260)
	check(p.position.y>9.6 and p.position.distance_to(room.lift.global_position)<2.1,"Landmark lift physically carries the player")
	var y=p.position.y;p.yaw=0;p.analog=Vector2(0,1);await frames(36);p.analog=Vector2.ZERO
	check(p.position.z>base.z+2.0 and absf(p.position.y-y)<.4,"Exit lift onto an unobstructed floor")
	check(room.interiors.has(2),"Lift reached streamed office floor")
	if not room.interiors.has(2):quit(1);return
	var test_glass=room.interiors[2].get_children().filter(func(n):return n.has_method("take_damage"))
	check(test_glass.size()>=3,"Real breakable exterior glazing at floor height")
	test_glass[0].take_damage(30);check(w.broken_glass.has(test_glass[0].key),"Broken windows persist across room streaming")
	var bridge=w.get_world_3d().direct_space_state
	var under=bridge.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-249,4,65),Vector3(-249,20,65),1))
	var road=bridge.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-249,4,65),Vector3(-249,-1,65),1))
	check(not under.is_empty() and not road.is_empty() and under.position.y-road.position.y>4.35,"Waterfront road passes physically below the bridge")
	var sea=bridge.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-550,1,65),Vector3(-550,30,65),1))
	check(not sea.is_empty() and sea.position.y>15,"Navigable river beneath solid bridge deck")
	move_to(Vector3(-201,0,245));p.position.y=-1.7;p.pitch=-.75;p.analog=Vector2(0,-1)
	await frames(42)
	check(p.position.y< -2.2 and p.submerged and p.breath<98,"Looking down dives below the actual waves")
	p.analog=Vector2.ZERO;var before=p.position.y;await frames(30)
	check(p.position.y<before,"An idle swimmer sinks")
	Input.action_press("jump");await frames(45);Input.action_release("jump")
	check(p.position.y>before+.75,"An upward stroke gains real altitude")
	# Clear the test junction without altering vehicle or road physics.
	for car in w.vehicles:
		if car!=starter and car.position.distance_to(Vector3(-15,2.6,65))<50:car.position+=Vector3(0,0,70)
	move_to(Vector3(-12.15,2.7,73.8));p.board(starter)
	starter.position=p.position;starter.rotation=Vector3.ZERO;starter.velocity=Vector3.FORWARD*5.25;starter.speed=5.25;starter.health=100
	p.analog=Vector2(1,-5.25/starter.max_speed);o.wanted=0;w.chase=false
	for frame in 200:
		await frames(1)
		if starter.rotation.y<=-PI*.486:break
	p.analog=Vector2.ZERO
	print("RIGHT TURN   ",starter.position," yaw=",rad_to_deg(starter.rotation.y)," health=",starter.health)
	check(starter.position.z>65.7 and starter.position.z<71.4 and starter.health==100 and starter.rotation.y< -1.46,"12 mph starter right turn lands in the near lane")
	check(is_equal_approx(w.fleet.cruiser[0].max_speed,36.*1.15) and recovery.max_speed>w.fleet.cruiser[0].max_speed,"Cruiser class and striped top speeds in physical units")
	var count=0
	for roll in 32:
		if o.traffic_model(roll) in ["striped","sport"]:count+=1
	check(count==2,"Traffic sports frequency is one quarter of HTML")
	check(w.fleet.marine[0].max_speed==launch.max_speed and w.fleet.marine[0].acceleration==launch.acceleration,"Same launch drive limits for player and patrol")
	move_to(Vector3(-100,2.8,101))
	o.alert(p.position,5);o.dispatch()
	check(o.active_units.size()>=3 and o.active_units[0].assignment=="tail" and o.active_units[1].assignment=="intercept" and o.air_unit!=null,"Distinct land responses and unarmed airborne spotter")
	var copter=o.air_unit;var first=copter.position;await frames(60)
	check(copter.position.distance_to(first)>1 and copter.position.y>48 and copter.tail_helix!=null,"Airborne orbit moves at altitude with tail rotor")
	copter.position=Vector3(-200,3,225);copter.take_damage(120);copter.detonate()
	check(copter.wreck and not copter.helix.visible and not copter.tail_helix.visible,"Wreck stays inert and blades stop")
	var sample={"cash":830,"finished":["convoy"],"equipment":{"owned":[true,true,true,false,true],"mags":[0,5,4,0,0]},"checkpoint":{"id":"island","stage":"cellblock"}}
	c.restore(sample);check(o.cash==830 and c.completed==["convoy"] and c.shop_owned[2] and c.earned_dock and o.magazines[1]==5,"Import HTML campaign, money, gear, ammo and exterior prison retry")
	move_to(Vector3(18,2.65,92));starter.position=p.position;p.board(starter)
	starter.speed=12;starter.rotation=Vector3.ZERO
	var bystander=o.civilians[0]
	bystander.hp=66;bystander.frightened=w.clock+12;bystander.position=starter.position+Vector3.FORWARD*1.75
	bystander._physics_process(1./60.)
	check(bystander.hp<66,"A fleeing pedestrian still registers contact with the front bumper")
	print("CITY_CHECKS ",checks," passed=",checks-failures.size()," failed=",failures.size())
	quit(1 if failures.size() else 0)
