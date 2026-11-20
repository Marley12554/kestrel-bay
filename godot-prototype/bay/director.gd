extends "res://operations.gd"
var campaign=preload("res://bay/campaign.gd").new()
var fx=preload("res://bay/fx.gd").new()
var modal
var lock_target
var entry_occupied=false
var entry_latched=false
var entry_ejected=false
var use_touch=false
var lock_time=0.
var entry_glass=false
var weapon_slot=0
var magazines=[0,12,6,24,0]
var reserves=[0,72,24,96,0]
var capacities=[0,12,6,24,0]
var barrel
var traffic=[]
var civilians=[]
var sentries=[]
var reports=[]
var report_history=[]
var active_units=[]
var dispatch_at=0.
var known_velocity=Vector3.ZERO
var hotline_at=-100.
var last_noise=Vector3.INF
var last_noise_time=-99.
var next_guard_shot=0.
var marine_shot=0.
var spikes
var strip_unit
var strip_officer
var strip_goal=Vector3.INF
var strip_angle=0.
var strip_setup=0.
var strip_deadline=0.
var last_tires=[]
var strip_vehicle
var surrendered=false
var recent_threat=-100.
var spike_pos=Vector3.INF
var air_unit
var board_time=0.
var door_contact_at=-100.
var first_seeing=0.
var ai_tick=0.
var rng=RandomNumberGenerator.new()
var routes={}
var road_node_offset=0
var prison_nodes=[]
var water_graph=AStar3D.new()
var water_paths={}
var guide_route=PackedVector3Array()
var guide_dest=Vector3.INF
var guide_at=0.
var trigger_down=false
var paid_vehicle=""
var shop_items=["Ammunition  ·  $80","Armor  ·  $200","Shotgun  ·  $340","Carbine  ·  $600","Bypass tools  ·  $180","Repair last vehicle  ·  $140","Striped Interceptor  ·  $1900"]
var last_vehicle
var pressure_last=0.
var next_audio=0.
var refreshed_hud=0.
var ownership={}
func configure(w:Node3D):
	rng.seed=982707
	super(w)
	add_child(fx);fx.configure(w)
	add_child(campaign);campaign.configure(w,self)
	barrel=w.box(gun,Vector3(0,0,-.33),Vector3(.09,.1,.5),Color("27383b"))
	barrel.hide()
	_create_population()
	spikes=Node3D.new();add_child(spikes)
	for i in 12:
		var needle=w.box(spikes,Vector3(i*.55-3,.14,0),Vector3(.16,.28,.18),Color("b0af9c"))
		needle.rotation.z=.37
	w.box(spikes,Vector3(0,.055,0),Vector3(6.7,.11,.28),Color("403f39"))
	spikes.hide()
func warm_effects(value):fx.warm_up(world.player.camera,value)
func make_hud()->Control:return preload("res://bay/dispatch_hud.gd").new()
func _create_population():
	for i in 32:
		var model=traffic_model(rng.randi_range(0,31))
		var road=world.atlas.data.roads[(i*17+1)%world.atlas.data.roads.size() if i>=12 else (i*3+1)%40]
		var a=world.atlas.points[int(road[0])]
		var b=world.atlas.points[int(road[1])]
		var f=(b-a).normalized()
		var v=world.spawn_vehicle(model,a.lerp(b,.31+.023*i)+f.cross(Vector3.UP)*world.atlas.lane_center(road[2],i)+Vector3.UP*.2)
		v.driving_npc=true
		v.lane_origin=a;v.lane_width=road[2];v.traffic_lane=i%2
		v.traffic_route=PackedVector3Array([b])
		v.rotation.y=atan2(-f.x,-f.z);v.home_heading=v.rotation.y
		traffic.append(v)
	for i in 21:
		var edge=world.atlas.data.roads[(i*7+3)%36]
		var pair=sidewalk(edge,(1 if i%2 else -1))
		var n=person("civilian",pair[0].lerp(pair[1],float(i%6)/6),Color(["7c8e82","a76e55","586c88","aa965a"][i%4]),pair)
		civilians.append(n)
	for i in 8:
		var x=-488+(i%3)*65
		var z=671+floori(i/3.)*66
		if i==2:x=-414
		var patrol=PackedVector3Array([Vector3(x,2.65,z),Vector3(x+12,2.65,z+2),Vector3(x+12,2.65,z+22),Vector3(x,2.65,z+22)])
		sentries.append(person("guard",patrol[0],Color("455d63"),patrol))
	for i in 6:
		var at=Vector3(595+i*46,2.65,293+i%2*72)
		sentries.append(person("soldier",at,Color("667052"),PackedVector3Array([at,at+Vector3(18,0,0),at+Vector3(18,0,31)])))
	person("guest",Vector3(-39,6.85,36),Color("846c5d"))
func person(kind,pos,color,path=PackedVector3Array()):
	var n=preload("res://bay/resident.gd").new()
	world.add_child(n)
	if path.is_empty():path=PackedVector3Array([pos,pos+Vector3(1.2,0,.42)])
	n.configure(world,kind,path,color);n.position=pos
	world.residents.append(n)
	return n
func sidewalk(e,s):
	var a=world.atlas.points[int(e[0])]
	var b=world.atlas.points[int(e[1])]
	var f=(b-a).normalized()
	var offset=f.cross(Vector3.UP)*(float(e[2])*.5+1.5)*s
	return PackedVector3Array([a+offset+f*7,b+offset-f*7])
func traffic_model(roll):
	if roll==0:return "striped"
	if roll==1:return "sport"
	return ["sedan","sedan","taxi","van","muscle","sedan"][roll%6]
func _build_routes():
	super()
	road_graph=world.atlas.graph
	map_edges.clear()
	for e in world.atlas.data.roads:
		map_edges.append([world.atlas.points[int(e[0])],world.atlas.points[int(e[1])]])
	var offset=foot_graph.get_available_point_id()
	road_node_offset=offset
	for id in road_graph.get_point_ids():
		var pt=road_graph.get_point_position(id)
		foot_graph.add_point(offset+id,pt)
		for old in range(25):
			if foot_graph.get_point_position(old).distance_to(pt)<1.5:foot_graph.connect_points(old,offset+id)
	for e in world.atlas.data.roads:foot_graph.connect_points(offset+int(e[0]),offset+int(e[1]))
	# Perimeter and center aisle provide actual routable access to the prison.
	var pr=[Vector3(-410,1.8,596),Vector3(-410,2.65,634),Vector3(-412,2.65,668),Vector3(-411,2.65,746),Vector3(-357,2.65,746),Vector3(-357,2.65,762),Vector3(-358,2.65,782)]
	var prev=-1
	for pt in pr:
		var id=foot_graph.get_available_point_id();foot_graph.add_point(id,pt)
		prison_nodes.append(id)
		if prev>=0:foot_graph.connect_points(prev,id)
		prev=id
	# Marine routing uses only adjacent water samples. Hull clearance rejects
	# coastline crossings, even when both end points happen to be offshore.
	var samples={}
	for z in range(-4550,1300,95):
		for x in range(-1800,1650,95):
			var at=Vector3(x,0,z)
			if water_at(at):
				var key=Vector2i(x,z)
				var id=water_graph.get_available_point_id()
				water_graph.add_point(id,at);samples[key]=id
				for delta in [Vector2i(-95,0),Vector2i(0,-95),Vector2i(-95,-95),Vector2i(95,-95)]:
					if samples.has(key+delta):
						var other=samples[key+delta]
						if water_at(at.lerp(water_graph.get_point_position(other),.5)):water_graph.connect_points(id,other)
func water_at(p):
	for poly in world.atlas.tide_lines:
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),poly):return false
	return true
func on_pavement(pos):
	for i in world.atlas.neighbors(pos,world.atlas.road_cells):
		var e=world.atlas.data.roads[i]
		var a=world.atlas.points[int(e[0])];var b=world.atlas.points[int(e[1])]
		if Geometry3D.get_closest_point_to_segment(pos,a,b).distance_to(pos)<e[2]*.5+1:return true
	return false
func sees_point(a,b,ignored=[]):
	if fx.obscures(a,b):return false
	return sight(a,b,ignored)
func sees_player(a:Vector3,exclude:Array=[])->bool:
	return not fx.obscures(a,world.player.position+Vector3.UP) and super(a,exclude)
func _nearest_visible(graph:AStar3D,at:Vector3)->int:
	if graph!=foot_graph:return super(graph,at)
	var local=foot_graph.get_closest_point(at)
	if local>=0 and navigation_clear(at,graph.get_point_position(local)):return local
	var nearby=world.atlas.neighbors(at,world.atlas.road_cells)
	var candidates=[]
	for edge in nearby:
		var e=world.atlas.data.roads[edge]
		for id in [e[0],e[1]]:
			var n=road_node_offset+int(id)
			if not candidates.has(n):candidates.append(n)
	if at.distance_to(Vector3(-45,5,26))<105:
		for id in range(road_node_offset):candidates.append(id)
	for id in prison_nodes:candidates.append(id)
	candidates.sort_custom(func(a,b):return graph.get_point_position(a).distance_squared_to(at)<graph.get_point_position(b).distance_squared_to(at))
	for id in candidates.slice(0,16):
		if navigation_clear(at,graph.get_point_position(id)):return id
	return local
func observe(at:Vector3):
	super(at)
	known_velocity=world.player.velocity
func report_shot(at:Vector3):
	recent_threat=world.clock;surrendered=false;arrest=0;extract_timer=0
	investigate(at)
	incident(at,2)
func investigate(at):
	last_noise=at;last_noise_time=world.clock
	if wanted>0:
		last_fix=at+Vector3(sin(at.z)*8,0,cos(at.x)*8)
		fix_at=world.clock
	for n in civilians:
		if n.position.distance_to(at)<72:
			n.frightened=world.clock+12;n.danger=at
func incident(at:Vector3,severity:int):
	var now=world.clock
	for event in report_history:
		if event[0].distance_to(at)<15 and now-event[1]<4 and event[2]>=severity:return
	var witness=false
	var vehicle_ignore=[]
	if world.player.vehicle:vehicle_ignore.append(world.player.vehicle.get_rid())
	for n in civilians:
		if n.hp>0 and n.position.distance_to(at)<65 and sees_point(n.position+Vector3.UP*1.5,at+Vector3.UP,[n.get_rid()]+vehicle_ignore):
			n.frightened=now+12;n.danger=at;witness=true
	for v in traffic:
		if v.driving_npc and v.position.distance_to(at)<72 and sees_point(v.position+Vector3.UP*1.7,at+Vector3.UP,[v.get_rid()]+vehicle_ignore):
			v.threat_until=now+7;witness=true
	for car in world.vehicles:
		if car.police and car.health>0 and car.position.distance_to(at)<78 and sees_player(car.position+Vector3.UP*1.7,[car.get_rid()]):
			alert(at,severity);witness=true;break
	# Junction cameras cover major avenues and both bridge approaches.
	if not witness and road_graph.get_point_count()>0:
		var pt=road_graph.get_point_position(road_graph.get_closest_point(at))
		witness=pt.distance_to(at)<28 and sees_point(pt+Vector3(0,6,2),at+Vector3.UP)
	if witness:
		reports.append([now+2.8,at,severity])
		report_history.append([at,now,severity])
func alert(at:Vector3,level:int=2):
	var old=wanted
	super(at,level)
	if old==0:dispatch_at=world.clock+.75
	if old>=level and world.clock-hotline_at>6 and level>=2:wanted=mini(5,wanted+1)
	hotline_at=world.clock
func search_duration()->float:return 34.+wanted*5.5
func allow_guard_shot():
	if next_guard_shot>world.clock:return false
	next_guard_shot=world.clock+.34
	return true
func vehicle_on_call(car)->bool:return dispatched(car)
func shelter(unit,source):
	var fallback=unit.position+(unit.position-source).slide(Vector3.UP).normalized()*6.
	var best=Vector3.INF
	var dist=INF
	var spots=[]
	for v in world.vehicles:
		if v.speed>2 or v.boat or v.aircraft or v.position.distance_squared_to(unit.position)>500:continue
		var away=(v.position-source).slide(Vector3.UP).normalized()
		spots.append(v.position+away*3.2)
	for side in 8:spots.append(unit.position+Vector3(sin(side*PI/4),0,cos(side*PI/4))*7.)
	for at in spots:
		var ds=at.distance_squared_to(unit.position)
		if ds>=dist or not walk_clear(at):continue
		if not sight(source+Vector3.UP,at+Vector3.UP,[unit.get_rid(),world.player.get_rid()]):
			best=at;dist=ds
	return fallback if best==Vector3.INF else best

func can_surrender()->bool:
	return wanted>0 and not armed and not world.player.vehicle and world.clock-recent_threat>2 and officers.any(func(n):return n.hp>0 and not n.boarded and n.position.distance_to(world.player.position)<15 and sees_player(n.position+Vector3.UP*1.5,[n.get_rid()]))

func vehicle_door(officer,v)->Vector3:
	var closest=null
	var best=INF
	for unit in officers:
		if unit.boarded or unit.hp<=0:continue
		var d=unit.position.distance_squared_to(v.position)
		if d<best and sees_player(unit.position+Vector3.UP*1.45,[unit.get_rid()]):
			best=d;closest=unit
	if closest!=officer:return Vector3.INF
	var side=signf(v.to_local(officer.position).x)
	return v.to_global(Vector3(1.61*(side if side!=0 else -1.),0,-.46))
func dispatched(v)->bool:
	return v==strip_unit or v in active_units or (v.model=="marine" and v.position.distance_to(last_fix)<900) or (v in world.security_cars and v.position.distance_to(last_fix)<200)
func dispatch():
	var p=world.player
	active_units.clear()
	if wanted==0:return
	var available=[]
	for v in world.fleet.get("cruiser",[]):
		if not v.occupied and not v.wreck and not v.flooded and v.crew.any(func(n):return n.hp>0):available.append(v)
	available.sort_custom(func(a,b):return a.position.distance_to(last_fix)<b.position.distance_to(last_fix))
	var count=mini(available.size(),1+wanted)
	for i in count:
		var v=available[i]
		v.assignment=["tail","intercept","flank","contain","reserve"][i%5]
		# Bring a remote reserve into a valid unseen street well before contact.
		# Nearby units always drive from their actual positions.
		if v.position.distance_to(last_fix)>650 and v.position.distance_to(p.position)>600 and v.crew.all(func(n):return n.boarded) and not visible_spawn(v.position):
			var predicted=last_fix+known_velocity*(5+i*2)
			var candidates=world.atlas.neighbors(predicted,world.atlas.road_cells,3)
			for edge_id in candidates:
				var e=world.atlas.data.roads[edge_id]
				var candidate=world.atlas.points[int(e[0])].lerp(world.atlas.points[int(e[1])],.5)
				var range_m=candidate.distance_to(p.position)
				if range_m>maxf(155,p.velocity.length()*5.) and range_m<430 and not visible_spawn(candidate) and active_units.all(func(c):return c.position.distance_to(candidate)>48):
					v.position=candidate+Vector3.UP*.25;v.velocity=Vector3.ZERO
					var f=world.atlas.points[int(e[1])]-candidate
					v.rotation.y=atan2(-f.x,-f.z)
					routes.erase(v.get_instance_id())
					break
		active_units.append(v)
	if wanted>=3 and (not is_instance_valid(air_unit) or (air_unit.wreck and world.clock-air_unit.safety_boot>120)):
		var side=p.camera.global_basis.z
		air_unit=world.spawn_vehicle("spotter",p.position+side*280+Vector3.UP*95)
		air_unit.safety_boot=world.clock
	if wanted>=3 and p.vehicle and not p.vehicle.boat and not p.vehicle.aircraft:
		var goal=last_fix+known_velocity*6.2
		var is_bridge=absf(last_fix.z-65)<17 and last_fix.x<-200 and last_fix.x>-900
		if is_bridge:goal=Vector3(-145 if known_velocity.x>0 else -919,2.65,65)
		if is_bridge or wanted>=4:
			var near=road_graph.get_closest_point(goal)
			var q=road_graph.get_point_position(near)
			if q.distance_to(p.position)>50 and strip_unit==null:
				var links=road_graph.get_point_connections(near)
				if links.is_empty():return
				var approach=road_graph.get_point_position(links[0])-q
				approach.y=0;approach=approach.normalized()
				var site=q+approach*11.
				for unit in available:
					if unit.crew[0].hp<=0 or unit.position.distance_to(site)>195 or unit.crew.any(func(n):return not n.boarded):continue
					strip_unit=unit;strip_officer=unit.crew[0];strip_goal=site
					strip_angle=atan2(approach.x,approach.z)
					strip_setup=0.;strip_deadline=world.clock+32
					break
func clear_strip():
	if strip_officer and strip_officer.hp>0:strip_officer.torso.rotation.x=0
	strip_unit=null;strip_officer=null;strip_goal=Vector3.INF
	spike_pos=Vector3.INF;spikes.hide();last_tires.clear();strip_vehicle=null

func update_strip(dt):
	if not strip_unit:return
	if wanted<3 or strip_unit.occupied or strip_unit.wreck or strip_officer.hp<=0 or world.clock>strip_deadline or strip_officer.under_fire_until>world.clock:
		clear_strip();return
	if not spikes.visible:
		if strip_officer.boarded:
			if strip_unit.position.distance_to(strip_goal)<8 and strip_unit.speed<3:strip_officer.deploy()
		elif strip_officer.position.distance_to(strip_goal)<2.2:
			strip_setup+=dt
			strip_officer.torso.rotation.x=.48
			if strip_setup>=1.2:
				strip_officer.torso.rotation.x=0
				spike_pos=strip_goal+Vector3.UP*.12;spikes.position=spike_pos;spikes.rotation.y=strip_angle
				spikes.show();strip_deadline=world.clock+50.
		return
	var car=world.player.vehicle
	if not car or car.boat or car.aircraft:
		last_tires.clear();strip_vehicle=null;return
	if car!=strip_vehicle:last_tires.clear();strip_vehicle=car
	for i in car.wheel_pivots.size():
		var at=spikes.to_local(car.wheel_pivots[i].global_position)
		if last_tires.size()<=i:last_tires.append(at)
		var prev=last_tires[i]
		var delta=at-prev
		var t=clampf(-prev.z/delta.z,0,1) if absf(delta.z)>.001 else 1.
		var contact=prev.lerp(at,t)
		if absf(contact.z)<.29 and absf(contact.x)<3.45 and absf(contact.y)<.63:car.puncture(i)
		last_tires[i]=at

func visible_spawn(at):
	var cam=world.player.camera
	for offset in [Vector3.ZERO,Vector3(3,2,3),Vector3(-3,2,-3)]:
		if cam.is_position_in_frustum(at+offset) and sees_point(cam.global_position,at+offset+Vector3.UP):return true
	return false
func drive_goal(v:CharacterBody3D)->Vector3:
	if v.boat:
		if v.captain_hp<=0 or (v.gunner_hp<=0 and world.clock<v.threat_until):return v.position
		var dest=last_fix+known_velocity*(2.4 if v.slot else 1.)+Vector3((v.slot+1)*7,0,0)
		var key=v.get_instance_id()
		if not water_at(dest):dest=water_graph.get_point_position(water_graph.get_closest_point(dest))
		if not water_paths.has(key) or world.clock>water_paths[key][0]:
			var path=water_graph.get_point_path(water_graph.get_closest_point(v.position),water_graph.get_closest_point(dest))
			if water_at(v.position.lerp(dest,.5)) and v.position.distance_to(dest)<130:path=PackedVector3Array([dest])
			water_paths[key]=[world.clock+3,path]
		return path_goal(water_paths[key][1],v.position,10)
	if v==strip_unit:
		return v.position if not strip_officer.boarded else strip_goal+Basis(Vector3.UP,strip_angle)*Vector3(4.8,0,0)
	if v.crew.any(func(n):return not n.boarded and n.hp>0):return v.position
	var desired=last_fix
	var ahead=known_velocity
	if ahead.length()>6:
		match v.assignment:
			"tail":desired+=ahead*.9
			"intercept":desired+=ahead*5.6
			"flank":desired+=ahead*2.5+ahead.normalized().cross(Vector3.UP)*9
			"contain":desired+=ahead*7.
		if v.assignment in ["contain","intercept"] and absf(last_fix.z-65)<16 and last_fix.x<-185 and last_fix.x>-894:
			desired=Vector3(-145 if ahead.x>0 else -921,2.7,65)
	elif v.assignment=="flank":desired+=Vector3(7,0,4)
	elif v.assignment=="contain":desired-=Vector3(6,0,3)
	var dist=v.position.distance_to(desired)
	if v in world.security_cars or (dist<115 and absf(v.position.y-desired.y)<3 and not water_at(desired) and not water_at(v.position.lerp(desired,.5)) and sees_point(v.position+Vector3.UP*1.6,desired+Vector3.UP*1.6,[v.get_rid()])):
		if not world.player.vehicle and dist<32:
			var away=v.position-desired;away.y=0
			if away.length()<10:return v.position
			return desired+away.normalized()*9.
		return desired
	var key=v.get_instance_id()
	var target_id=road_graph.get_closest_point(desired)
	if not routes.has(key) or (world.clock>=routes[key][0] and routes[key][2]!=target_id) or world.clock>routes[key][0]+4:
		var path=road_graph.get_point_path(road_graph.get_closest_point(v.position),target_id)
		if path.size()>1 and v.position.distance_to(path[1])<v.position.distance_to(path[0])+path[0].distance_to(path[1])*.9:path.remove_at(0)
		routes[key]=[world.clock+1.7,path,target_id]
	var path=routes[key][1]
	var at=path_goal(path,v.position,7.+v.speed*.13)
	return at
func path_goal(path,position3,tolerance):
	while path.size()>1 and position3.distance_to(path[0])<tolerance:path.remove_at(0)
	return path[0] if path.size()>0 else position3
func traffic_goal(car)->Vector3:
	var route=car.traffic_route
	# Follow the selected lane through a corner before tracking the outbound edge.
	while not car.turning_path.is_empty():
		if flat_distance(car.position,car.turning_path[0])>4.2:return car.turning_path[0]
		car.turning_path.remove_at(0)
	var incoming=-car.global_basis.z
	if not route.is_empty() and car.lane_origin!=Vector3.INF:
		incoming=(route[0]-car.lane_origin).slide(Vector3.UP).normalized()
	var at_junction=not route.is_empty() and (route[0]-car.position).dot(incoming)<6.5
	if at_junction:
		car.junction_id=-1;car.entered_junction=false;car.stopped_since=-1.
		car.lane_origin=route[0]
		route.remove_at(0)
	if route.is_empty():
		if car.mission_driver:
			car.driving_npc=false
			return car.position
		var node=road_graph.get_closest_point(car.lane_origin if car.lane_origin!=Vector3.INF else car.position)
		var junction=road_graph.get_point_position(node)
		var links=road_graph.get_point_connections(node)
		if links.is_empty():return car.position
		var options=[]
		for link in links:
			var delta=road_graph.get_point_position(link)-junction
			if delta.normalized().dot(incoming)>-.65:options.append(link)
		var link=links[0] if options.is_empty() else options[rng.randi()%options.size()]
		car.lane_origin=junction
		route.append(road_graph.get_point_position(link))
	if at_junction:
		var junction=car.lane_origin
		var node=road_graph.get_closest_point(junction)
		var link=road_graph.get_closest_point(route[0])
		var outgoing=(route[0]-junction).slide(Vector3.UP).normalized()
		var previous_offset=world.atlas.lane_center(car.lane_width,car.traffic_lane)
		car.lane_width=world.atlas.edge_widths.get(Vector2i(mini(node,link),maxi(node,link)),13.)
		car.pass_until=0.;car.pass_offset=0.
		if absf(incoming.dot(outgoing))<.82:
			var start=junction-incoming*6.5+incoming.cross(Vector3.UP)*previous_offset
			var finish=junction+outgoing*8.+outgoing.cross(Vector3.UP)*world.atlas.lane_center(car.lane_width,car.traffic_lane)
			var center=start+incoming*((finish-start).cross(outgoing).y/incoming.cross(outgoing).y)
			for t in [.5,1.]:car.turning_path.append(start.lerp(center,t).lerp(center.lerp(finish,t),t))
			return car.turning_path[0]
	var dest=route[0]
	if car.lane_origin==Vector3.INF:car.lane_origin=car.position
	var edge=dest-car.lane_origin
	if edge.length()<.12:return dest
	var dir=edge.normalized()
	if car.junction_id<0:
		car.junction_id=world.atlas.graph.get_closest_point(dest)
		car.junction_kind=world.atlas.junction_control(car.junction_id,car.lane_origin)

	var side=dir.cross(Vector3.UP).normalized()
	var offset=world.atlas.lane_center(car.lane_width,car.traffic_lane)
	if wanted>0 and active_units.any(func(c):return c.responding and c.position.distance_squared_to(car.position)<500):offset=minf(car.lane_width*.5-1.45,offset+1.5)
	var lookahead=maxf(4.0,car.speed*.65) if car.pass_until>world.clock else maxf(13,car.speed*.95)
	var lead=clampf((car.position-car.lane_origin).dot(dir)+lookahead,0,edge.length())
	return car.lane_origin+dir*lead+side*(offset+car.pass_offset)
func flat_distance(a,b):return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
func nearest_vehicle():
	var closest=null
	var d=4.4
	for v in world.vehicles:
		if v.wreck or v.flooded or v.occupied or ((v.boat or v.aircraft) and v.speed>3.4):continue
		var dist=world.player.position.distance_to(v.position if v.boat or v.aircraft or v.owned else v.driver_door())
		if v.boat:dist-=1.
		if v.aircraft:dist-=.8
		if dist<d:closest=v;d=dist
	return closest
func request_vehicle(v):
	if (v.boat or v.aircraft) and v.owned:
		world.player.board(v);return
	if v.police and v.boat and (v.gunner_hp>0 or v.captain_hp>0) and not v.overboard:
		incident(v.position,2)
		v.threat_until=world.clock+4
		if v.gunner_hp>0:message("Marine crew bars the helm");return
		v.overboard=true;v.captain_hp=0
		var captain=person("guard",v.position+v.global_basis.z*3+Vector3.UP*.6,Color("3c5668"))
		sentries.append(captain)
		v.seat_bodies[0].hide();v.seat_bodies[0].collision_layer=0
	if v.boat or v.aircraft:
		v.owned=true;incident(v.position,2);world.player.board(v);return
	if world.player.position.distance_to(v.driver_door())>1.85:
		message("Move to the driver’s door");return
	lock_target=v
	lock_time=.58 if v.owned else 0.
	entry_occupied=v.driving_npc or v.crew.any(func(n):return n.boarded and n.hp>0)
	entry_latched=not entry_occupied
	entry_ejected=false
	entry_glass=not v.owned and not entry_occupied and v.door_glass.visible
	if entry_occupied:v.threat_until=world.clock+6

func tick_entry(dt):
	var car=lock_target
	var p=world.player
	var door_at=car.driver_door()
	if car.wreck or car.flooded or p.position.distance_to(door_at)>2.05:
		cancel_theft();return
	lock_time+=dt
	if not entry_latched:
		if not (Input.is_action_pressed("interact") or use_touch):
			cancel_theft();return
		if lock_time<.78:return
		entry_latched=true;lock_time=0.;car.driver_yield=true
	if entry_glass and lock_time>=.38:
		car.door_glass.hide();entry_glass=false;audio.effect("glass",door_at,-4)
	if lock_time>.58:car.door_open=1.
	if entry_occupied and car.driving_npc and lock_time>.58:
		var pull=smoothstep(.60,1.02,lock_time)
		car.driver.position=Vector3(-.44,.9,-.15).lerp(Vector3(-1.78,.83,.93),pull)
		car.driver.rotation.z=pull*.58
	if lock_time>=1.02 and not entry_ejected:
		if car.driving_npc:
			var driver_npc=person("civilian",car.to_global(Vector3(-1.78,.1,.93)),Color("7e7869"))
			driver_npc.danger=p.position;driver_npc.frightened=world.clock+12
			civilians.append(driver_npc)
			car.driving_npc=false;car.driver.hide()
		for n in car.crew:
			if n.boarded and n.hp>0:n.deploy()
		if car.crew.any(func(n):return n.boarded and n.hp>0):
			cancel_theft();return
		entry_ejected=true
		if not car.owned:incident(car.position,2 if car.police else 1)
	if lock_time>=1.86:car.door_open=0.
	if lock_time>=2.22:
		cancel_theft();car.owned=true;p.board(car)

func cancel_theft():
	if lock_target:
		lock_target.driver_yield=false
		lock_target.door_open=0.
		lock_target.driver.position=Vector3(-.44,.9,-.15)
		lock_target.driver.rotation.z=0.
	lock_target=null;lock_time=0.;entry_latched=false
func hurt(amount:float):
	if lock_target:cancel_theft()
	if campaign.armor>0:
		var absorbed=minf(campaign.armor,amount*.56);campaign.armor-=absorbed;amount-=absorbed
	super(amount)
func mag_size()->int:return capacities[weapon_slot] if weapon_slot in [1,2,3] else 12
func weapon_damage()->float:return 57. if weapon_slot==2 else (34. if weapon_slot==3 else 28.)
func fire_interval()->float:return .67 if weapon_slot==2 else (.115 if weapon_slot==3 else .25)
func can_fire_from_vehicle()->bool:return weapon_slot==1 and world.player.leaning()
func select_slot(slot):
	if slot<0 or slot>4 or not campaign.shop_owned[slot]:return
	if weapon_slot in [1,2,3]:magazines[weapon_slot]=ammo;reserves[weapon_slot]=reserve
	weapon_slot=slot;armed=slot in [1,2,3];reload_until=0
	if armed:ammo=magazines[slot];reserve=reserves[slot]
	if barrel:barrel.visible=slot in [2,3];barrel.scale.z=1.65 if slot==3 else 1.
	if armed and world.started:
		for car in world.fleet.get("cruiser",[]):
			if car.position.distance_to(world.player.position)<23 and sees_player(car.position+Vector3.UP*1.55,[car.get_rid()]):incident(world.player.position,1);break
func fire():
	if not armed or hp<=0 or world.clock<next_shot or world.clock<reload_until or map_open or modal or puzzle or lock_target:return
	if world.player.vehicle and not can_fire_from_vehicle():return
	if ammo<=0:reload();return
	var p=world.player
	var aim=aim_points()
	ammo-=1;next_shot=world.clock+fire_interval();recoil=.068
	audio.player_report(["","shot","shotgun","carbine"][weapon_slot])
	var pellets=5 if weapon_slot==2 else 1
	var excluded:Array[RID]=[p.get_rid()]
	if p.vehicle:excluded.append(p.vehicle.get_rid())
	for i in pellets:
		var muzzle=aim[0]
		var point=aim[1]
		if i>0:point+=Vector3(rng.randf_range(-1.7,1.7),rng.randf_range(-1.2,1.2),rng.randf_range(-1.7,1.7))
		var q=PhysicsRayQueryParameters3D.create(muzzle,point+(point-muzzle).normalized()*.25,1|2|8,excluded)
		var hit=get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			point=hit.position
			var victim=hit.collider.get_meta("target",hit.collider)
			if victim.has_method("take_damage"):victim.take_damage(17. if pellets>1 else weapon_damage())
		for cop in officers:
			if cop.hp<=0 or cop.boarded:continue
			var eye=cop.position+Vector3.UP*1.2
			if Geometry3D.get_closest_point_to_segment(eye,muzzle,point).distance_squared_to(eye)<8.:
				cop.react_to_fire(muzzle)
		fx.shot(muzzle,point,not hit.is_empty())
	report_shot(p.position)
func _trace(a:Vector3,b:Vector3,_color:Color):
	fx.shot(a,b,false)
func aim_points()->Array:
	var p=world.player
	var start=p.camera.global_position
	var end=start-p.camera.global_basis.z*(180 if weapon_slot==3 else 125)
	var excluded:Array[RID]=[p.get_rid()]
	var muzzle=p.camera.to_global(Vector3(.26,-.23,-.71))
	if p.vehicle:
		excluded.append(p.vehicle.get_rid())
		muzzle=p.vehicle.to_global(Vector3(-1.16,1.43,-.30))
	var ray=PhysicsRayQueryParameters3D.create(start,end,1|2|8,excluded)
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():end=hit.position
	return [muzzle,end]
func target()->Vector3:
	if campaign.job=="ledger":return super()
	return campaign.goal if campaign.goal!=Vector3.INF else campaign.map_waypoint
func objective_text()->String:
	if campaign.job=="ledger":return super()
	if campaign.job.is_empty():return ""
	return campaign.instruction+("  ·  %ds"%ceili(campaign.countdown) if campaign.countdown>0 else "")
func reset_ledger():
	visitor_card=false;ledger_mesh.show();keycard_mesh.show()
	pipes=[5,10,3,12,5,9,12,5,10]
	for p in passages:
		p.opened=false;p.broken=false;p.locked=p.kind=="door";p.hp=15 if p.kind=="window" else 45
		p.visual.show();p.panel.collision_layer=1
func interact()->bool:
	if map_open or modal or puzzle or hp<=0:return true
	if world.player.vehicle:return false
	if can_surrender():surrendered=true;return true
	if campaign.interact():return true
	var pos=world.player.position
	var room=world.nearby_lift()
	if room:
		if absf(pos.y-room.lift.global_position.y)>1.3:
			room.lift.destination=clampi(roundi((pos.y-room.position.y)/3.8),0,room.floors)
			message("Lift called")
		else:
			var choices=[]
			var ids=[]
			for i in room.floors+1:
				ids.append(i);choices.append("Lobby" if i==0 else ("Observation deck" if room.parcel.tier=="empire" and i==room.floors else ("Roof" if i==room.floors else "Floor %d"%(i+1))))
			choice_menu("Lift  /  "+world.business(room.parcel) if room.parcel.title.is_empty() else "Lift  /  "+room.parcel.title,choices,func(i):room.lift.destination=ids[i])
		return true
	if pos.distance_to(world.atlas.marks["Copper Kettle"])<4.3 or pos.distance_to(world.atlas.marks["Southbank Garage"])<4.3:
		choice_menu("Supplies  /  $%d"%cash,shop_items,purchase);return true
	if pos.distance_to(job_board)<3.9:
		toggle_map();return true
	if campaign.job=="ledger" or pos.distance_to(Vector3(-45,2.6,27))<22:
		if weapon_slot==4:
			for door in passages:
				if door.kind=="door" and pos.distance_to(door.position)<3:door.locked=false;door.opened=true;return true
		return super()
	return false
func purchase(index):
	var prices=[80,200,340,600,180,140,1900]
	var price=prices[index]
	if cash<price:message("Insufficient cash");return
	if index in [2,3,4] and campaign.shop_owned[index]:message("Already owned");return
	if index==0:
		for i in range(1,4):reserves[i]+=capacities[i]*3
		if armed:reserve=reserves[weapon_slot]
	elif index==1:campaign.armor=80
	elif index in [2,3,4]:campaign.shop_owned[index]=true
	elif index==5:
		if not is_instance_valid(last_vehicle) or last_vehicle.wreck:message("Bring a repairable vehicle to the shop");return
		last_vehicle.health=100;last_vehicle.spike=false;last_vehicle.flat_count=0;last_vehicle.burning=0
		for mesh in last_vehicle.rubbers:mesh.show()
		for puff in last_vehicle.fire_objects:puff.queue_free()
		last_vehicle.fire_objects.clear()
	elif index==6:
		var car=world.spawn_vehicle("striped",world.atlas.marks["Southbank Garage"]+Vector3(6,.3,4))
		car.owned=true;campaign.map_waypoint=car.position;paid_vehicle="striped"
	cash-=price;campaign.save_progress();message("Purchased · $%d"%cash)
func choice_menu(title,choices,callback):
	if modal:return
	modal=hud.menu(title,choices,func(i):close_modal();callback.call(i))
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func close_modal():
	if modal:modal.queue_free();modal=null
	if not map_open and not world.mobile:world.restore_pointer()
func close_puzzle():
	if campaign and not campaign.circuit_kind.is_empty():campaign.circuit_states[campaign.circuit_kind]=pipes.duplicate()
	super()
	if world.mobile:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func open_puzzle():
	super()
	if puzzle and not campaign.circuit_kind.is_empty():
		puzzle.get_child(0).get_child(0).text=campaign.circuit_kind.to_upper()+"  /  SERVICE CIRCUIT\nConnect the inlet on the left to the outlet on the right."
func test_circuit():
	if campaign.circuit_kind.is_empty():super()
	elif circuit_connected():campaign.panel_solved()
	else:puzzle_check.text="OPEN CIRCUIT · ROTATE AND RETEST"
func toggle_map():
	if modal:close_modal()
	if puzzle:close_puzzle()
	cancel_theft()
	world.player.mobile_sprint=false;world.player.mobile_brake=false
	super()
	hud.map_changed(map_open)
	if world.mobile:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func _unhandled_input(event):
	if not world.started:return
	if event.is_action_pressed("map"):
		toggle_map();get_viewport().set_input_as_handled();return
	if event.is_action_pressed("pause"):
		if modal:close_modal()
		elif puzzle:close_puzzle()
		elif map_open:toggle_map()
		elif lock_target:cancel_theft()
		return
	if map_open or modal or puzzle or lock_target:return
	if event.is_action_pressed("unarmed") and not (world.player.vehicle and event.is_action_pressed("honkh")):select_slot(0)
	for i in range(1,5):
		if event.is_action_pressed(["","pistol","shotgun","carbine","tools"][i]):select_slot(i)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var step=1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1
			var i=posmod(weapon_slot+step,5)
			while not campaign.shop_owned[i]:i=posmod(i+step,5)
			select_slot(i)
		if event.button_index==MOUSE_BUTTON_LEFT:fire()
	if event.is_action_pressed("reload"):reload()
	if event.is_action_pressed("shoot"):fire()
func interaction_hint()->String:
	if lock_target:return "Hold to take the driver’s seat" if not entry_latched else ""
	if puzzle:return ""
	if can_surrender():return "E · Surrender"
	if world.player.vehicle:
		return "F · Exit aircraft" if world.player.vehicle.aircraft else ("Q · Left window    E · Exit" if not world.player.vehicle.boat else "E · Step onto deck")
	if world.nearby_lift():return "E · Elevator"
	var p=world.player.position
	if campaign.goal!=Vector3.INF and p.distance_to(campaign.goal)<4.2 and campaign.step in ["card","manifest","cargo","files","accounts","gate","breach","release","choose","publish"]:return "E · "+campaign.instruction
	if campaign.step=="breach" and p.distance_to(Vector3(-394,3,640))<4:return "E · Collect intake card"
	if campaign.step=="steal_air" and p.distance_to(world.atlas.marks["Fort radar"])<4:return "E · Disable radar"
	if p.distance_to(job_board)<3.9:return "E · Operations"
	if p.distance_to(world.atlas.marks["Copper Kettle"])<4.3 or p.distance_to(world.atlas.marks["Southbank Garage"])<4.3:return "E · Supplies and repairs"
	if p.distance_to(Vector3(-45,3,27))<20:return super()
	var v=nearest_vehicle()
	if v:return ("F · Enter aircraft" if v.aircraft else "E · Board launch" if v.boat else "E · Enter vehicle" if v.owned else "Hold · Take driver’s seat" if v.driving_npc or v.crew.any(func(n):return n.boarded and n.hp>0) else "E · Open driver’s door")
	return ""
func issue_spawn_ammo():
	if magazines[1]==0 and reserves[1]==0:
		magazines[1]=capacities[1]
		reserves[1]=capacities[1]*3
	elif magazines[1]==0:
		magazines[1]=mini(capacities[1],reserves[1])
		reserves[1]-=magazines[1]
	if weapon_slot==1:
		ammo=magazines[1]
		reserve=reserves[1]
func reset_run():
	if modal:close_modal()
	if lock_target:cancel_theft()
	campaign.cleanup()
	cash=maxi(0,cash-mini(300,roundi(cash*.1)))
	super()
	clear_strip();surrendered=false;recent_threat=-100.;weapon_slot=0;active_units.clear();reports.clear();world.night_lock=false
	issue_spawn_ammo()
	campaign.save_progress()
func _physics_process(dt):
	if not world.started or get_tree().paused:return
	if hp<=0:
		super(dt);return
	if lock_target:tick_entry(dt)
	if armed or world.player.velocity.length()>1. or wanted==0:surrendered=false
	if world.player.vehicle:
		last_vehicle=world.player.vehicle;arrest=0
	if world.clock-door_contact_at>.35:extract_timer=maxf(0.,extract_timer-dt*2)
	if world.clock>=dispatch_at:dispatch_at=world.clock+3.7;dispatch()
	if wanted==0:
		active_units.clear()
		if spikes.visible:spikes.hide();spike_pos=Vector3.INF
	var p=world.player
	update_strip(dt)
	while not reports.is_empty() and reports[0][0]<=world.clock:
		var report=reports.pop_front();alert(report[1],report[2])
	while not report_history.is_empty() and world.clock-report_history[0][1]>6:report_history.pop_front()
	if Input.is_action_pressed("shoot") or trigger_down:fire()
	if world.clock>=ai_tick:
		ai_tick=world.clock+.55
		_repopulate()
		if wanted>0:_marine_air()
	super(dt)
	campaign.tick(dt)
	if armed:magazines[weapon_slot]=ammo;reserves[weapon_slot]=reserve
func _marine_air():
	var p=world.player
	if world.night and not campaign.power_off and not p.submerged and p.position.distance_squared_to(Vector3(-410,3,705))<330.*330.:
		for tower in world.towers:
			var v=p.position+Vector3.UP-tower.position
			if v.length()<tower.spot_range and v.normalized().dot(-tower.global_basis.z)>cos(deg_to_rad(tower.spot_angle)) and sees_player(tower.position):
				campaign.lockdown=true;alert(p.position,3);break
	if is_instance_valid(air_unit) and not air_unit.wreck and air_unit.burning<=0 and p.position.distance_to(air_unit.position)<185 and not p.submerged:
		var target=last_fix+Vector3(sin(world.clock*.76)*6,.8,cos(world.clock*.6)*4)
		if (target-air_unit.position).normalized().dot((p.position-air_unit.position).normalized())>cos(deg_to_rad(17)) and sees_player(air_unit.position-Vector3.UP,[air_unit.get_rid()]):observe(p.position)
	if p.position.distance_to(world.atlas.marks["Fort radar"])<160 and world.security_cars.size() and not campaign.power_off:
		for car in world.security_cars:
			if car.model=="tank" and car.position.distance_to(p.position)<70 and sees_player(car.position+Vector3.UP*2,[car.get_rid()]) and world.clock>marine_shot:
				_trace(car.position+Vector3.UP*2,p.position+Vector3.UP,Color("dca562"));hurt(17);marine_shot=world.clock+3.2
	for v in world.fleet.get("marine",[]):
		if v.wreck or v.occupied or v.captain_hp<=0:continue
		var d=v.position.distance_to(p.position)
		if d<7 and p.vehicle and p.vehicle.boat and p.vehicle.speed<2:
			board_time+=.55
			if board_time>2.4:
				p.interact();board_time=0;message("Boarded by harbor patrol")
		elif wanted>=4 and v.gunner_hp>0 and d<53 and world.clock>=marine_shot and sees_player(v.position+Vector3.UP*1.8,[v.get_rid()]):
			var start=v.position+v.global_basis.z*2.6+Vector3.UP*1.8
			var to=p.position+Vector3.UP
			_trace(start,to,Color("d7bb82"))
			if p.vehicle:p.vehicle.take_damage(3)
			elif not p.submerged:hurt(5)
			marine_shot=world.clock+2.
func _repopulate():
	var p=world.player
	if water_at(p.position) or p.position.z>200:return
	var edges=world.atlas.neighbors(p.position,world.atlas.road_cells,2)
	if edges.size()<2:return
	for pool in [traffic,civilians]:
		var moved=0
		for item in pool:
			if item.position.distance_to(p.position)<320 or item==world.player.vehicle or item==lock_target:continue
			if pool==traffic and (item.owned or item.wreck or item.mission_driver or not item.driving_npc):continue
			if pool==civilians and (item.hp<=0 or item.follow):continue
			var e=world.atlas.data.roads[edges[rng.randi()%edges.size()]]
			if e[4]=="bridge":continue
			var pair=sidewalk(e,1)
			var d=(pair[1]-pair[0]).normalized()
			var at=pair[0].lerp(pair[1],rng.randf_range(.1,.9))
			var reverse=pool==traffic and (rng.randi()%2==0)
			if pool==traffic:
				at-=d.cross(Vector3.UP)*(e[2]*.5+1.5)
				if reverse:d=-d
				at+=d.cross(Vector3.UP)*world.atlas.lane_center(e[2],item.traffic_lane)
				if world.vehicles.any(func(v):return v!=item and v.position.distance_squared_to(at)<25.*25.):continue
			if at.distance_to(p.position)<55 or visible_spawn(at):continue
			if pool==traffic:
				item.position=at+Vector3.UP*.2;item.velocity=Vector3.ZERO;item.rotation.y=atan2(-d.x,-d.z)
				item.junction_id=-1;item.stopped_since=-1.;item.entered_junction=false;item.blocked_since=-1.
				item.turning_path.clear();item.lane_width=e[2]
				item.speed=0;item.pass_until=0;item.pass_offset=0;item.lane_origin=world.atlas.points[int(e[1] if reverse else e[0])]
				item.traffic_route=PackedVector3Array([world.atlas.points[int(e[0] if reverse else e[1])]])
			else:item.position=at;item.route=pair;item.index=1
			moved+=1
			if moved>=3:break
func _process(dt):
	if not world.started:return
	hud.queue_redraw()
	if get_tree().paused:
		world._publish_browser_state(dt)
		return
	recoil=move_toward(recoil,0,dt*.52)
	gun.visible=armed and not world.player.vehicle and hp>0
	gun.position.z=-.55+recoil
	for i in range(traces.size()-1,-1,-1):
		if world.clock>traces[i].until:traces[i].mesh.queue_free();traces.remove_at(i)
	if world.clock>guide_at:
		guide_at=world.clock+1.0
		var dst=target()
		guide_route.clear()
		if dst!=Vector3.INF and not water_at(dst) and not water_at(world.player.position) and world.player.position.distance_to(dst)>40:
			var a=road_graph.get_closest_point(world.player.position);var b=road_graph.get_closest_point(dst)
			guide_route=road_graph.get_point_path(a,b)

func room_containing(at):
	for room in world.nearby_rooms.values():
		var d=at-room.position
		if d.y<-.8 or d.y>room.floors*3.8+2:continue
		var dims=world.atlas.tier(room.parcel,clampi(floori(d.y/3.8),0,room.floors-1))
		if absf(d.x)<dims.x*.5 and absf(d.z)<dims.y*.5:return room
	return null
func interior_step(officer,target_pos)->Vector3:
	var room=room_containing(target_pos)
	var current=room_containing(officer.position)
	if not room:room=current
	if not room or not room.lift:return Vector3.INF
	var from_level=clampi(roundi((officer.position.y-room.position.y)/3.8),0,room.floors)
	var to_level=clampi(roundi((target_pos.y-room.position.y)/3.8),0,room.floors)
	if from_level==to_level:return Vector3.INF
	var shaft=room.position+Vector3(room.shaft.x,from_level*3.8,room.shaft.y)
	if current!=room:
		var gate=room.position+Vector3(0,0,room.parcel.face*room.parcel.d*.5)
		if flat_distance(officer.position,gate)>2:return gate+Vector3(0,0,room.parcel.face*.65)
		return gate-Vector3(0,0,room.parcel.face*2.4)
	if flat_distance(officer.position,shaft)>2.8:
		return shaft+Vector3.BACK*2.25
	if absf(room.lift.global_position.y-shaft.y)>.52:
		if absf(room.lift.global_position.y-room.position.y-room.lift.destination*3.8)<.1:
			room.lift.destination=from_level
		return shaft+Vector3.BACK*2.25
	if flat_distance(officer.position,shaft)<1.2:room.lift.destination=to_level
	return shaft
