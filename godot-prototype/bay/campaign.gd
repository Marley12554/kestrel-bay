extends Node
const JOBS=[
	["shipment","The Missing Shipment","Follow the freight van from Old Harbor or disable it to recover its manifest.",480],
	["office","After Hours","Get into Voss Development and trace its payments to the docks.",740],
	["convoy","Cut the Convoy","Stop the equipment carrier, recover its cargo and deliver it intact.",1100],
	["witness","Loose Ends","Bring a witness out of Harrow House and safely into Southbank Garage.",950],
	["island","The Island Run","Cross the harbor, breach Blackwater and bring Eli back alive.",1800],
	["money","Follow the Money","Track a payment courier through Manhattan to the concealed accounts.",1400],
	["finale","Public Record","Choose who gets the evidence and carry the decision through.",2200],
	["recovery","Harbor Recovery","Bring the marked striped car to Southbank. Its condition sets the fee.",500],
	["race","Coastal Circuit","Run the bridges and the Brooklyn waterfront before the clock expires.",650],
	["base","Borrowed Wings","Take an aircraft from Fort Halcyon and land at the mainland waterfront.",1500],
	["ledger","The Night Ledger","Recover a clerk’s ledger in Suite 201 of the Breakwater Hotel.",1800]]
var w
var o
var job=""
var step=""
var goal=Vector3.INF
var instruction=""
var completed=[]
var earned_dock=false
var gate_open=false
var power_off=false
var lockdown=false
var custody=false
var visitor=false
var manifest_time=0.
var countdown=0.
var delivered=0
var ending=""
var effects={"trust":0,"dock":0}
var actor
var escort
var van
var bodyguard
var marker
var service_card
var prior_stage=""
var notice_at=0.
var map_waypoint=Vector3.INF
var circuit_kind=""
var circuit_states={}
var shop_owned=[true,true,false,false,false]
var armor=0.
var death_cause=""
var replay_count=0
var destination_labels=[]
var accepted_at=0.
var qa_no_save=false
const SAVE_KEY="kestrel_godot_campaign_1"
func configure(world,director):
	w=world;o=director
	qa_no_save=w.qa or DisplayServer.get_name()=="headless"
	load_progress()
func label_for(id):
	for j in JOBS:
		if j[0]==id:return j[1]
	return ""
func loc(id):return w.atlas.marks[id]
func inside(title:String,floor_idx=0):
	var p=w.atlas.plots[title]
	return p.at+Vector3(2.,mini(floor_idx,int(p.floors)-1)*3.8,.0)
func objective(text:String,pos:Vector3,key:String):
	step=key;goal=pos;instruction=text
	if is_instance_valid(marker):
		marker.queue_free()
		marker=null
	if key in ["files","manifest","cargo","accounts","release","card","radar","custody","publish"]:
		marker=w.box(w,goal+Vector3.UP*.79,Vector3(.95,1.58,.57),Color("5b615c"),true)
		w.box(marker,Vector3(0,.37,.33),Vector3(.53,.37,.07),Color("a3956f"))
func cleanup():
	if o.puzzle:o.close_puzzle()
	circuit_kind=""
	for prop in [marker,service_card]:
		if is_instance_valid(prop):prop.queue_free()
	for n in [escort,bodyguard]:
		if is_instance_valid(n):
			w.residents.erase(n);n.queue_free()
	if is_instance_valid(van):
		van.mission_driver=false
		van.driving_npc=false
		if not van.owned and van!=w.player.vehicle:
			w.vehicles.erase(van);w.fleet[van.model].erase(van);van.queue_free()
	if is_instance_valid(actor) and actor!=van:
		actor.driving_npc=false
		if not actor.owned and actor!=w.player.vehicle:
			w.vehicles.erase(actor);w.fleet[actor.model].erase(actor);actor.queue_free()
	marker=null;service_card=null;escort=null;bodyguard=null;actor=null;van=null
	w.night_lock=false
	o.stage="available"
	job="";step="";goal=Vector3.INF;instruction=""
	manifest_time=0;countdown=0;delivered=0
	power_off=false;gate_open=false;lockdown=false;custody=false;visitor=false
	circuit_states.clear()
func abandon():
	if job=="island":earned_dock=false
	cleanup()
	save_progress()
func accept(id):
	if label_for(id).is_empty():return
	cleanup()
	job=id
	map_waypoint=Vector3.INF
	accepted_at=w.clock
	if id=="ledger":
		o.reset_ledger()
		o.stage="enter"
		step="ledger"
	elif id=="shipment":
		spawn_van("van","Drydock Six","Dockworkers Hall")
		objective("Find the freight van in Old Harbor",van.position,"tail")
	elif id=="office":
		if shop_owned[4]:
			objective("Use the service lift to reach Voss payment records",inside("Voss Development",3),"files")
			return
		objective("Get a visitor card at Voss reception or use bypass tools",inside("Voss Development"),"card")
	elif id=="convoy":
		spawn_van("van","Lower Manhattan","Public Archive")
		bodyguard=o.person("hostile",van.position+Vector3(4,0,-4),Color("4a514c"))
		actor=w.spawn_vehicle("sedan",van.position+van.global_basis.z*9)
		actor.driving_npc=true
		actor.mission_driver=true
		actor.traffic_route=van.traffic_route.duplicate()
		objective("Intercept the armored equipment van",van.position,"stop")
	elif id=="witness":
		escort=o.person("witness",inside("Harrow House"),Color("987844"))
		objective("Find the witness inside Harrow House",escort.position,"meet")
	elif id=="island":
		w.night_lock=true
		w.set_night(true)
		o.hud.fade_scene()
		if earned_dock:
			w.player.reset_player(loc("Blackwater Service Dock")+Vector3.UP*.2)
			# A dock checkpoint still needs a real boat for extraction.
			w.vehicles[3].position=Vector3(-396,.1,586)
			w.vehicles[3].velocity=Vector3.ZERO
			prison_breach()
		else:objective("Reach Pier 04 in Brooklyn",loc("Pier 04"),"marina")
	elif id=="money":
		spawn_van("taxi","Midtown","Voss Development")
		objective("Follow the Manhattan payment courier",van.position,"tail")
	elif id=="finale":objective("Choose what to do with the evidence at the Public Archive",inside("Public Archive"),"choose")
	elif id=="recovery":
		van=w.spawn_vehicle("striped",loc("Drydock Six")+Vector3(8,.3,9))
		objective("Recover the marked Interceptor",van.position,"recover")
	elif id=="race":objective("Bring a car to the Brooklyn start line",Vector3(-75,2.7,65),"start")
	elif id=="base":objective("Enter Fort Halcyon and take an aircraft",w.fleet["helicopter"][0].position,"steal_air")
	else:return
	if id!="island":w.night_lock=false
	save_progress()
func spawn_van(model,source,dest):
	var g=w.atlas.graph
	var a=g.get_closest_point(loc(source))
	var b=g.get_closest_point(loc(dest))
	var route=g.get_point_path(a,b)
	var start=route[0]+Vector3.UP*.23
	if route.size()>1:start+=(route[1]-route[0]).normalized()*7
	van=w.spawn_vehicle(model,start)
	van.driving_npc=true;van.mission_driver=true
	van.traffic_route=route
	if route.size()>1:
		van.rotation.y=atan2(route[0].x-route[1].x,route[0].z-route[1].z)
		van.traffic_route.remove_at(0)
func prison_breach():
	objective("Disable the perimeter circuit or collect the intake card",loc("Substation"),"breach")
	if not is_instance_valid(service_card):service_card=w.box(w,Vector3(-394,3.55,640),Vector3(.58,.16,.43),Color("caa765"))
func start_circuit(kind):
	circuit_kind=kind
	o.pipes=circuit_states.get(kind,[5,10,3,12,5,9,12,5,10]).duplicate()
	# Rotated start orientations differ by panel; every tile retains a solvable shape.
	if not circuit_states.has(kind):
		var offset=["power","gate","cell","records","publish","radar"].find(kind)+1
		for i in o.pipes.size():
			for j in (offset+i)%4:o.pipes[i]=((o.pipes[i]<<1)&15)|((o.pipes[i]>>3)&1)
	o.open_puzzle()
func panel_solved():
	var kind=circuit_kind
	circuit_kind=""
	o.close_puzzle()
	match kind:
		"power":
			power_off=true
			objective("Bypass the sally port at the custody gate",loc("Custody gate"),"gate")
		"gate":
			gate_open=true
			objective("Enter Cellblock B",loc("Cellblock B"),"wing")
		"cell":
			escort=o.person("prisoner",loc("Cell control")+Vector3(1.7,0,2),Color("be8456"))
			escort.follow=true
			objective("Escort Eli out through the custody gate",loc("Custody gate"),"escort_gate")
		"records":complete()
		"publish":complete()
		"radar":
			power_off=true
			o.message("Radar offline · take an aircraft")
func tick(dt):
	if job.is_empty():return
	var p=w.player
	if job=="ledger":
		if o.stage=="complete":
			complete(false)
		return
	if is_instance_valid(escort) and escort.hp<=0:
		fail_job("Your passenger was lost")
		return
	var near=p.position.distance_to(goal)
	match step:
		"tail","stop":
			goal=van.position
			var d=p.position.distance_to(van.position)
			if d<115 and d>9 and o.sees_point(p.position+Vector3.UP,van.position+Vector3.UP,[van.get_rid()]):manifest_time+=dt
			if van.health<55 or van.spike or van.wreck or (step=="tail" and manifest_time>6 and van.traffic_route.size()<=1):
				van.driving_npc=false
				objective("Collect the cargo" if job=="convoy" else "Recover the van’s manifest",van.position+van.global_basis.x*2.3,"cargo" if job=="convoy" else "manifest")
			elif step=="stop" and d<13 and van.speed<.75:
				manifest_time+=dt
				if manifest_time>=3:
					van.driving_npc=false
					objective("Recover the equipment from the stopped van",van.position+van.global_basis.x*2.3,"cargo")
			elif step=="tail":
				instruction="Keep the courier in sight or disable the vehicle" if job=="money" else "Trail the van to the depot or stop it"
		"meet":
			if near<3 and not p.vehicle:
				escort.follow=true
				o.alert(p.position,2)
				objective("Escort the witness to Southbank Garage",loc("Southbank Garage"),"safe")
		"safe":
			if near<8 and escort.position.distance_to(p.position)<12:complete()
		"deliver","handoff":
			if near<8:complete()
		"recover":
			if p.vehicle==van:objective("Deliver the Interceptor to Southbank Garage",loc("Southbank Garage"),"deliver_car")
		"deliver_car":
			if van.wreck:fail_job("Recovery vehicle lost")
			elif p.vehicle==van and near<9 and van.speed<3:complete()
		"marina":
			if near<14:
				objective("Board a launch at Pier 04",w.vehicles[3].position,"boat")
		"boat":
			if p.vehicle and p.vehicle.boat:
				objective("Land on the exterior Blackwater service dock",loc("Blackwater Service Dock"),"land")
		"land":
			if not p.vehicle and near<9 and p.position.y>1.1:
				earned_dock=true;save_progress();prison_breach()
		"wing":
			if near<5 and not p.vehicle:objective("Release Eli at the Cellblock B control panel",loc("Cell control"),"release")
		"escort_gate":
			if near<11 and escort.position.distance_to(p.position)<14:
				objective("Bring Eli to the launch at the service dock",loc("Blackwater Service Dock"),"extract")
		"extract":
			if p.vehicle and p.vehicle.boat and escort.riding:
				objective("Bring Eli home to Pier 04",loc("Pier 04"),"return")
		"return":
			if near<19 and escort.position.distance_to(p.position)<14 and (not p.vehicle or p.vehicle.boat):complete()
		"start":
			if near<11 and p.vehicle and not p.vehicle.boat and not p.vehicle.aircraft:
				countdown=215
				objective("Cross the Brooklyn Bridge to Lower Manhattan",loc("Lower Manhattan"),"race1")
		"race1","race2","race3":
			countdown-=dt
			if countdown<=0:fail_job("Time expired")
			elif near<18 and p.vehicle and not p.vehicle.boat and not p.vehicle.aircraft:
				if step=="race1":objective("Run north to the Williamsburg Bridge",w.atlas.points[w.atlas.graph.get_closest_point(Vector3(-880,2.6,-1375))],"race2")
				elif step=="race2":objective("Finish at the Brooklyn waterfront",Vector3(125,2.65,65),"race3")
				else:complete()
		"steal_air":
			if p.vehicle and p.vehicle.aircraft:
				o.alert(p.position,4)
				objective("Land the aircraft at the Brooklyn marina",loc("Marina landing"),"land_air")
		"land_air":
			if p.vehicle and p.vehicle.aircraft and p.position.distance_to(goal)<45 and p.position.y<5 and p.vehicle.speed<7:complete()
func interact()->bool:
	if job.is_empty() or job=="ledger" or w.player.vehicle:return false
	var pos=w.player.position
	if step=="steal_air" and pos.distance_to(loc("Fort radar"))<4 and not power_off:start_circuit("radar");return true
	if step=="breach" and pos.distance_to(Vector3(-394,3.,640))<4:
		custody=true
		if is_instance_valid(service_card):service_card.hide()
		objective("Use the custody card at the sally port",loc("Custody gate"),"gate");return true
	if pos.distance_to(goal)>4.2:return false
	match step:
		"card":
			visitor=true
			objective("Open the payment files on the Voss records floor",inside("Voss Development",3),"files")
		"manifest":
			if job=="money":objective("Recover the final accounts at Voss Development",inside("Voss Development",2),"accounts")
			else:objective("Deliver the manifest to Copper Kettle",loc("Copper Kettle"),"deliver")
		"cargo":objective("Deliver the equipment to Drydock Six",loc("Drydock Six"),"deliver")
		"files","accounts":start_circuit("records")
		"breach":start_circuit("power")
		"gate":
			if custody:
				gate_open=true
				objective("Enter Cellblock B",loc("Cellblock B"),"wing")
			else:start_circuit("gate")
		"release":start_circuit("cell")
		"choose":o.choice_menu("Public Record",["Publish the files","Accept a buyback","Demand leverage"],choose_ending)
		"publish":start_circuit("publish")
		_:return false
	return true
func choose_ending(index):
	ending=["publication","buyback","leverage"][index]
	if index==0:objective("Connect the archive transmission circuit",inside("Public Archive",1),"publish")
	else:objective("Reach the forest meeting" if index==1 else "Take the file to the waterfront exchange",loc("Forest meeting") if index==1 else loc("Drydock Six"),"handoff")
	var at=goal+Vector3(7,0,6)
	bodyguard=o.person("hostile",at,Color("474958"))
	o.alert(w.player.position,2)
func complete(pay=true):
	var reward=0
	for j in JOBS:
		if j[0]==job:reward=int(j[3])
	if is_instance_valid(van) and job in ["convoy","recovery"]:reward=roundi(reward*(.45+.55*van.health/100.))
	if job=="finale" and ending=="buyback":reward+=450
	if job=="witness" or job=="island":effects.trust+=1
	if job=="convoy":effects.dock+=1
	if pay:o.cash+=reward
	if not completed.has(job):completed.append(job)
	if job=="island":earned_dock=false
	var name_text=label_for(job)
	cleanup();save_progress()
	o.message("%s complete  ·  +$%d"%[name_text,reward],6)
func fail_job(reason):
	var title=label_for(job)
	cleanup();save_progress()
	o.message(title+" · "+reason+" · retry from Operations",5)
func save_progress():
	if qa_no_save:return
	var data={"version":1,"finished":completed,"cash":o.cash,"owned":shop_owned,"armor":armor,"dock":earned_dock,"effects":effects,"ending":ending,"magazines":o.magazines,"reserves":o.reserves}
	var encoded=JSON.stringify(data)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.setItem('%s',%s) } catch (_) {}"%[SAVE_KEY,JSON.stringify(encoded)])
	else:
		var cfg=ConfigFile.new()
		cfg.set_value("game","save",data);cfg.save("user://kestrel.cfg")
func load_progress():
	if qa_no_save:return
	var data
	if OS.has_feature("web"):
		var raw=JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('%s')||localStorage.getItem('kb_overhaul_v2')||''}catch(_){return ''}})()"%SAVE_KEY)
		if raw is String and not raw.is_empty():data=JSON.parse_string(raw)
	else:
		var cfg=ConfigFile.new()
		if cfg.load("user://kestrel.cfg")==OK:data=cfg.get_value("game","save",{})
	if data is Dictionary:restore(data)
func restore(data):
	if not data.get("cash") is float and not data.get("cash") is int:return
	o.cash=maxi(0,int(data.cash));completed=[]
	for j in JOBS:
		if j[0] in data.get("finished",[]):completed.append(j[0])
	var gear=data.get("equipment",{})
	var owned=data.get("owned",gear.get("owned",[]) if gear is Dictionary else [])
	if owned is Array and owned.size()==5:
		for i in 5:shop_owned[i]=bool(owned[i])
	var inv=data.get("inventory",{})
	if inv is Dictionary:
		shop_owned[4]=shop_owned[4] or bool(inv.get("tools",false))
		armor=float(data.get("armor",50 if inv.get("armor",false) else 0))
	var cp=data.get("checkpoint")
	earned_dock=bool(data.get("dock",false)) or (cp is Dictionary and cp.get("id")=="island" and cp.get("stage","") in ["power","gate","prisonGate","cell","release","escort","extract","escape","escapeBoat","return","cellblock"])
	var eff=data.get("effects",{})
	if eff is Dictionary:effects={"trust":int(eff.get("trust",eff.get("crewTrust",0))),"dock":int(eff.get("dock",eff.get("dockAlert",0)))}
	ending=str(data.get("ending",""))
	var mags=data.get("magazines",gear.get("mags",[]) if gear is Dictionary else [])
	var ammo=data.get("reserves",gear.get("ammo",[]) if gear is Dictionary else [])
	for i in range(1,4):
		if mags is Array and mags.size()>i:o.magazines[i]=clampi(int(mags[i]),0,o.capacities[i])
		if ammo is Array and ammo.size()>i:o.reserves[i]=maxi(0,int(ammo[i]))
	o.issue_spawn_ammo()
