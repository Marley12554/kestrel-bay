extends Node3D

const Officer = preload("res://officer.gd")
const Hud = preload("res://hud.gd")
const Passage = preload("res://passage.gd")
const Lift = preload("res://lift.gd")
const PipeTile = preload("res://pipe_tile.gd")
var routes_ready = false
var world: Node3D
var officers: Array = []
var passages: Array = []
var vision_ignore: Array[RID] = []
var lift: AnimatableBody3D
var hud: Control
var hp = 100.0
var stamina = 100.0
var exhausted = false
var cash = 650
var armed = false
var ammo = 12
var reserve = 72
var reload_until = 0.0
var next_shot = 0.0
var wanted = 0
var unseen = 0.0
var crime_at = -100.0
var last_fix = Vector3.ZERO
var fix_at = -100.0
var arrest = 0.0
var extract_timer = 0.0
var stage = "available"
var visitor_card = false
var notice = ""
var notice_until = 0.0
var job_board = Vector3(3,2.6,90)
var cabinet = Vector3(-53,6.8,18)
var pier = Vector3(4,1.9,171)
var departure = Vector3(16,0,270)
var foot_graph = AStar3D.new()
var road_graph = AStar3D.new()
var map_edges: Array = []
var road_routes = {}
var puzzle: Control
var puzzle_buttons: Array = []
var pipes = [5,10,3,12,5,9,12,5,10]
var gun: Node3D
var recoil = 0.0
var traces: Array = []
var map_open = false
var dead_until = 0.0
var lift_time = 0.0
var exit_time = 0.0
var current_shooters: Array = []
var tick_seen = false
var audio: Node
var keycard_mesh: MeshInstance3D
var ledger_mesh: MeshInstance3D
var puzzle_check: Button
var last_health_hit = -100.0

func configure(owner_world: Node3D) -> void:
	world = owner_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hotel_details()
	_prepare_routes.call_deferred()
	for car in world.vehicles:
		if car.police and not car.boat:
			car.crew = []
			for seat in 2:
				var n = Officer.new()
				add_child(n)
				n.configure(world,self,car,seat)
				officers.append(n)
				car.crew.append(n)
	var layer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	hud = make_hud()
	layer.add_child(hud)
	hud.configure(world,self)
	_build_gun()
	audio = preload("res://sound.gd").new()
	add_child(audio)
	audio.configure(world)
	set_physics_process(false)

func make_hud() -> Control:
	return Hud.new()

func _build_hotel_details() -> void:
	# Actual hotel rooms share the visible building footprint and floor elevations.
	lift = Lift.new()
	add_child(lift)
	lift.configure(world)
	for floor_y in [2.6,6.8]:
		for x in [-57.5,-39,-33]:
			world.box(self,Vector3(x,floor_y+.4,35),Vector3(1.5,.8,1.8),Color("3a6065"),true)
		world.box(self,Vector3(-48,floor_y+.35,35),Vector3(2.5,.7,1.3),Color("69543f"),true)
		for z in [19,30]:
			var light = OmniLight3D.new()
			add_child(light)
			light.position = Vector3(-46,floor_y+3.3,z)
			light.omni_range = 13
			light.light_color = Color("ffdfa4")
			light.light_energy = .6
		world.box(self,Vector3(-44,floor_y+.025,32),Vector3(8,.04,6),Color("735044"))
	# Guest room partitions, a corridor, and wide door openings.
	for x in [-50,-41]:
		world.box(self,Vector3(x,8.7,20),Vector3(.18,3.8,12),Color("c2b49e"),true)
	for room in [[-59.0,-50.0],[-50.0,-41.0]]:
		var mid = (room[0]+room[1])*.5
		for side in [-1,1]:
			var segment = (room[1]-room[0]-1.8)*.5
			world.box(self,Vector3(mid+side*(.9+segment*.5),8.7,26.0),Vector3(segment,3.8,.18),Color("c2b49e"),true)
		world.box(self,Vector3(mid,10.1,26),Vector3(1.8,1,.18),Color("c2b49e"),true)
		_add_passage(Vector3(mid-.9,6.8,26),1.8,2.8,"door","Suite %d" % int(201+passages.size()),0,true)
		world.box(self,Vector3(mid-1.4,7.15,20),Vector3(2.1,.7,3.6),Color("664b3b"),true)
		world.box(self,Vector3(mid-1.4,7.59,20),Vector3(2.0,.2,3.5),Color("ddd8bd"))
		world.box(self,Vector3(mid-1.4,7.75,18.8),Vector3(1.8,.12,.8),Color("f0ecdc"))
		world.box(self,Vector3(mid+2.6,7.2,16),Vector3(1.0,.8,1.0),Color("6e5740"),true)
		world.box(self,Vector3(mid+2.6,7.85,16),Vector3(.45,.5,.45),Color("e8c989"))
	# Transparent, solid north-facing panes sit in real facade openings.
	for y in [3.4,7.6]:
		for wx in [-58.2,-51.4,-44.65,-37.9]:
			_add_passage(Vector3(wx,y,14),6.15,2.2,"window","Hotel window",0,false)
			var glass = passages[-1].visual.material_override.duplicate() as StandardMaterial3D
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color = Color(.29,.52,.59,.28)
			glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			glass.roughness = .2
			passages[-1].visual.material_override = glass
	# Glass in an actual wall opening leading onto the west fire escape.
	_add_passage(Vector3(-59,7.25,23.6),2.7,2.45,"window","Fire-escape window",-PI/2,false)
	world.box(self,Vector3(-59,7.0,25),Vector3(.3,.4,2.8),Color("b1a78d"),true)
	world.make_sign(self,Vector3(-58.7,9.8,25),"FIRE EXIT",.012,PI/2)
	keycard_mesh = world.box(self,Vector3(-52,3.84,20.6),Vector3(.20,.012,.12),Color("e2bd75"))
	# Reception desk is off the circulation route and the elevator entrance is clear.
	world.make_sign(self,Vector3(-34.5,5.7,19.7),"LIFT / SUITES",.014)
	world.box(self,cabinet+Vector3(0,.75,0),Vector3(1.4,1.5,.8),Color("334c55"),true)
	world.box(self,cabinet+Vector3(0,1.35,.45),Vector3(.7,.35,.06),Color("65b5b8"))
	ledger_mesh = world.box(self,cabinet+Vector3(0,1.52,0),Vector3(.6,.05,.45),Color("dfc697"))
	world.box(self,job_board+Vector3(0,1.25,0),Vector3(1.8,2.2,.16),Color("3b555d"),true)
	world.make_sign(self,job_board+Vector3(0,1.65,.12),"HARBOR JOBS\nTHE NIGHT LEDGER",.0055)
	for p in [Vector3(-64.5,6.8,28),Vector3(-45,2.6,38)]:
		world.make_sign(self,p+Vector3.UP*2.5,"EXIT",.01)

func _add_passage(at: Vector3,width: float,height: float,kind: String,title: String,angle: float,locked: bool) -> void:
	var p = Passage.new()
	add_child(p)
	p.configure(world,at,width,height,kind,title,angle,locked)
	passages.append(p)
	if kind=="window":
		vision_ignore.append(p.panel.get_rid())

func _build_gun() -> void:
	gun = Node3D.new()
	world.player.camera.add_child(gun)
	gun.position = Vector3(.28,-.27,-.55)
	world.box(gun,Vector3.ZERO,Vector3(.075,.10,.29),Color("38464d"))
	world.box(gun,Vector3(0,-.095,.075),Vector3(.07,.15,.11),Color("252a2b"))
	world.box(gun,Vector3(0,-.07,-.015),Vector3(.065,.025,.11),Color("2c3438"))
	world.box(gun,Vector3(0,-.04,-.07),Vector3(.065,.05,.015),Color("2c3438"))
	world.box(gun,Vector3(0,.057,-.105),Vector3(.018,.025,.025),Color("131c23"))
	world.box(gun,Vector3(0,.057,.10),Vector3(.06,.02,.025),Color("131c23"))
	var barrel = world.cylinder(gun,Vector3(0,0,-.16),.026,.04,Color("131c23"))
	barrel.rotation.x = PI/2
	world.box(gun,Vector3(.015,-.16,.12),Vector3(.12,.13,.18),Color("b38e70"))
	gun.visible = false

func _prepare_routes() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	_build_routes()
	routes_ready = true

func navigation_clear(a: Vector3,b: Vector3) -> bool:
	var ignored: Array[RID] = []
	for p in passages:
		ignored.append(p.panel.get_rid())
	var query = PhysicsRayQueryParameters3D.create(a+Vector3.UP,b+Vector3.UP,1,ignored)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _build_routes() -> void:
	for z in [-125.0,-65.0,-5.0,65.0,125.0]:
		for x in [-135.0,-75.0,-15.0,55.0,125.0]:
			var id = road_graph.get_available_point_id()
			road_graph.add_point(id,Vector3(x,2.65,z))
			foot_graph.add_point(id,Vector3(x,2.65,z))
	for id in road_graph.get_point_ids():
		for other in road_graph.get_point_ids():
			if other<=id:
				continue
			var a = road_graph.get_point_position(id)
			var b = road_graph.get_point_position(other)
			if (is_equal_approx(a.x,b.x) and absf(a.z-b.z)<=70) or (is_equal_approx(a.z,b.z) and absf(a.x-b.x)<=70):
				road_graph.connect_points(id,other)
				foot_graph.connect_points(id,other)
				map_edges.append([a,b])
	var paths = [
		[Vector3(-45,2.65,65),Vector3(-45,2.65,43),Vector3(-45,2.65,33),Vector3(-45,2.65,28)],
		[Vector3(-75,2.65,65),Vector3(-64.5,2.65,48),Vector3(-64.5,6.8,28),Vector3(-60.5,6.8,26),Vector3(-56,6.8,25),Vector3(-54.5,6.8,23)],
		[Vector3(-45,2.65,28),Vector3(-45,2.65,21),Vector3(-34.5,2.65,21)]
	]
	for points in paths:
		var previous = -1
		for point in points:
			var id = foot_graph.get_available_point_id()
			foot_graph.add_point(id,point)
			if previous>=0:
				foot_graph.connect_points(previous,id)
			var nearest = -1
			var best = 20.0
			for old in foot_graph.get_point_ids():
				if old==id:
					continue
				var q = foot_graph.get_point_position(old)
				if absf(q.y-point.y)<1 and q.distance_to(point)<best:
					nearest = old
					best = q.distance_to(point)
			if nearest>=0 and navigation_clear(point,foot_graph.get_point_position(nearest)):
				foot_graph.connect_points(id,nearest)
			previous = id
	for x in [-54.5,-45.5,-36.5]:
		var hall = foot_graph.get_available_point_id()
		foot_graph.add_point(hall,Vector3(x,6.8,28))
		var old = foot_graph.get_closest_point(Vector3(x,6.8,28),false)
		for id in foot_graph.get_point_ids():
			if id!=hall and absf(foot_graph.get_point_position(id).y-6.8)<.1 and foot_graph.get_point_position(id).distance_to(Vector3(x,6.8,28))<12 and navigation_clear(foot_graph.get_point_position(id),Vector3(x,6.8,28)):
				foot_graph.connect_points(hall,id)
		var inside = foot_graph.get_available_point_id()
		foot_graph.add_point(inside,Vector3(x,6.8,23))
		foot_graph.connect_points(hall,inside)
	# Collision-checked indoor circulation around furniture, with real floor heights.
	var indoor: Array = []
	for y in [2.65,6.85]:
		for x in [-57.5,-54.5,-51.5,-48.5,-45.5,-42.5,-39.5,-36.5,-33.5]:
			for z in [16.0,19.0,22.0,25.0,28.0,31.0,34.0,37.0]:
				var at = Vector3(x,y,z)
				if (y>5 and x>-38 and z<20) or not walk_clear(at):
					continue
				var id = foot_graph.get_available_point_id()
				foot_graph.add_point(id,at)
				indoor.append(id)
	for id in indoor:
		var at = foot_graph.get_point_position(id)
		for other in foot_graph.get_point_ids():
			if other==id:
				continue
			var b = foot_graph.get_point_position(other)
			if absf(at.y-b.y)<.3 and at.distance_to(b)<4.4 and navigation_clear(at,b):
				foot_graph.connect_points(id,other)
	# Extend the road graph over the real ramp profile, retaining full bridge route.
	var prior = 19
	for x in [165.0,190.0,220.0,250.0,290.0,325.0,355.0,385.0,425.0]:
		var id = road_graph.get_available_point_id()
		var at = Vector3(x,world.bridge_height(x) if x<385 else 2.65,65)
		road_graph.add_point(id,at)
		road_graph.connect_points(prior,id)
		map_edges.append([road_graph.get_point_position(prior),at])
		prior = id

func sight(a: Vector3,b: Vector3,exclude: Array=[]) -> bool:
	var ignored: Array[RID] = []
	ignored.assign(exclude)
	ignored.append_array(vision_ignore)
	var query = PhysicsRayQueryParameters3D.create(a,b,1|2,ignored)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func sees_player(from: Vector3,exclude: Array=[]) -> bool:
	if world.player.submerged:
		return false
	var ignored: Array[RID] = []
	ignored.assign(exclude)
	ignored.append_array(vision_ignore)
	var target_eye = world.player.position+Vector3.UP*(1.0 if world.player.vehicle else 1.3)
	var query = PhysicsRayQueryParameters3D.create(from,target_eye,1|2|4,ignored)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider==world.player or hit.collider==world.player.vehicle

func walk_clear(at: Vector3) -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = .33
	shape.height = 1.8
	query.shape = shape
	query.transform.origin = at+Vector3.UP*.95
	query.collision_mask = 1|2|8
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func foot_path(a: Vector3,b: Vector3) -> PackedVector3Array:
	if absf(a.y-b.y)<1.2 and sight(a+Vector3.UP,b+Vector3.UP):
		return PackedVector3Array([b])
	var start = _nearest_visible(foot_graph,a)
	var end = _nearest_visible(foot_graph,b)
	if start<0 or end<0:
		return PackedVector3Array([a])
	var path = foot_graph.get_point_path(start,end)
	while path.size()>1 and (path[0].distance_to(path[1])<.2 or (absf(a.y-path[1].y)<1 and sight(a+Vector3.UP,path[1]+Vector3.UP))):
		path.remove_at(0)
	if not path.is_empty() and sight(path[-1]+Vector3.UP,b+Vector3.UP):
		path.append(b)
	return path

func _nearest_visible(graph: AStar3D,p: Vector3) -> int:
	var result = -1
	var best = INF
	for id in graph.get_point_ids():
		var q = graph.get_point_position(id)
		var score = p.distance_to(q)+absf(p.y-q.y)*5
		if score<best and absf(p.y-q.y)<1.2 and sight(p+Vector3.UP,q+Vector3.UP):
			best = score
			result = id
	return result

func drive_goal(car: CharacterBody3D) -> Vector3:
	var fix = last_fix if world.clock-fix_at<45 else world.player.position
	if car.boat:
		var p = fix+world.player.velocity*(2.5 if car.slot else .8)
		p.z = maxf(158,p.z)
		p.x = clampf(p.x,-160,440)
		return p+Vector3(12*car.slot,0,0)
	if car.crew.size()>0 and car.crew.any(func(n): return not n.boarded and n.hp>0):
		return car.position
	var goal = fix+world.player.velocity*(2.8 if car.slot else .5)
	if goal.z>140:
		goal.z = 124
	var key = car.get_instance_id()
	if not road_routes.has(key) or world.clock-road_routes[key].at>2:
		var path = PackedVector3Array()
		if (car.position.distance_to(goal)<40 or goal.y>5) and sight(car.position+Vector3.UP,goal+Vector3.UP,[car.get_rid()]):
			path.append(goal)
		else:
			var start = road_graph.get_closest_point(car.position)
			var end = road_graph.get_closest_point(goal)
			path = road_graph.get_point_path(start,end)
			if path.size()>1 and sight(car.position+Vector3.UP,path[1]+Vector3.UP,[car.get_rid()]):
				path.remove_at(0)
			if sight(road_graph.get_point_position(end)+Vector3.UP,goal+Vector3.UP,[car.get_rid()]):
				path.append(goal)
		road_routes[key] = {"at":world.clock,"path":path}
	var route = road_routes[key].path
	while route.size()>1 and car.position.distance_to(route[0])<6:
		route.remove_at(0)
	return route[0] if route.size() else car.position

func cover_point(n: CharacterBody3D,target_position: Vector3) -> Vector3:
	var car = n.cruiser
	if car.position.distance_to(n.position)<18 and car.position.distance_to(target_position)>8:
		var behind = car.position+(car.position-target_position).normalized()*3
		if walk_clear(behind):
			return behind
	return n.position

func shooter_slot(n: CharacterBody3D) -> bool:
	var candidates = officers.filter(func(o): return not o.boarded and o.hp>0 and world.clock-o.seen_at<.4)
	candidates.sort_custom(func(a,b): return a.position.distance_to(world.player.position)<b.position.distance_to(world.player.position))
	return n in candidates.slice(0,2)

func observe(at: Vector3) -> void:
	last_fix = at
	fix_at = world.clock
	tick_seen = true

func alert(at: Vector3,level: int=2) -> void:
	wanted = maxi(wanted,level)
	world.chase = wanted>0
	last_fix = at
	fix_at = world.clock
	crime_at = world.clock
	unseen = 0

func message(text: String,seconds: float=3) -> void:
	notice = text
	notice_until = world.clock+seconds

func hurt(amount: float) -> void:
	if hp<=0 or world.clock-last_health_hit<.12:
		return
	hp = maxf(0,hp-amount)
	last_health_hit = world.clock
	if hp<=0:
		dead_until = world.clock+1.6
		message("You were caught. Return to the board to retry.",4)

func officer_shot(n: CharacterBody3D,from: Vector3,to: Vector3) -> void:
	var end = from+(to-from).normalized()*75
	var query = PhysicsRayQueryParameters3D.create(from,end,1|2|4,[n.get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.position
		if hit.collider==world.player:
			hurt(7)
		elif hit.collider==world.player.vehicle:
			world.player.vehicle.take_damage(3)
		elif hit.collider.has_meta("target"):
			hit.collider.get_meta("target").take_damage(14,false)
	_trace(from,end,Color("ffcb81"))
	audio.effect("shot",n.position,-18)

func can_fire_from_vehicle() -> bool:
	return false

func fire() -> void:
	if not armed or hp<=0 or world.clock<next_shot or world.clock<reload_until or puzzle or map_open:
		return
	if world.player.vehicle and not can_fire_from_vehicle():
		return
	if ammo<=0:
		reload()
		return
	ammo -= 1
	next_shot = world.clock+fire_interval()
	recoil = .07
	var cam = world.player.camera
	var start = cam.global_position
	var end = start-cam.global_basis.z*130
	var query = PhysicsRayQueryParameters3D.create(start,end,1|2|8,[world.player.vehicle.get_rid()] if world.player.vehicle else [])
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.position
		var body = hit.collider
		var victim = body.get_meta("target",body)
		if victim.has_method("take_damage"):
			victim.take_damage(weapon_damage())
		elif body.has_method("take_damage"):
			body.take_damage(weapon_damage())
	_trace(cam.to_global(Vector3(.28,-.25,-.72)),end,Color("efdfa9"))
	audio.effect("shot",world.player.position,-10)
	report_shot(world.player.position)

func report_shot(at: Vector3) -> void:
	alert(at,2)

func _trace(a: Vector3,b: Vector3,color: Color) -> void:
	var length = a.distance_to(b)
	if length<.01:
		return
	var line = world.box(self,(a+b)*.5,Vector3(.012,.012,length),color)
	line.look_at(b)
	traces.append({"mesh":line,"until":world.clock+.065})

func weapon_damage() -> float:
	return 28

func fire_interval() -> float:
	return .24

func mag_size() -> int:
	return 12

func reload() -> void:
	if ammo>=mag_size() or reserve<=0 or world.clock<reload_until:
		return
	reload_until = world.clock+1.1
	message("Reloading",1.1)
	audio.effect("reload",world.player.position,-12)

func target() -> Vector3:
	match stage:
		"enter": return Vector3(-45,2.6,40)
		"lift": return Vector3(-34.5,2.6,21)
		"archive": return cabinet
		"escape": return pier
		"board": return world.vehicles[3].position
		"depart": return departure
	return Vector3.INF

func objective_text() -> String:
	match stage:
		"available": return "THE NIGHT LEDGER · Accept at the square's job board"
		"enter": return "Reach the Breakwater reception"
		"lift": return "Reach the guest floor · elevator or exterior stairs"
		"archive": return "Suite 201 · unlock the ledger cabinet"
		"escape": return "Ledger secured · escape the hotel and reach Pier 04"
		"board": return "Board the launch beside Pier 04"
		"depart": return "Lose the pursuit and leave the harbor with the ledger"
		"complete": return "LEDGER DELIVERED · Free exploration"
		"failed": return "JOB FAILED · Return to the board to retry"
	return "Explore the waterfront"

func interact() -> bool:
	var p = world.player
	if p.vehicle:
		return false
	if p.position.distance_to(job_board)<4 and stage in ["available","failed","complete"]:
		stage = "enter"
		message("A clerk hid the harbor's transfer ledger in Suite 201. Bring it out by sea.",6)
		return true
	if absf(p.position.x-lift.position.x)<3 and absf(p.position.z-lift.position.z)<4:
		lift.use()
		return true
	if p.position.distance_to(Vector3(-52,2.6,20))<3 and not visitor_card:
		visitor_card = true
		keycard_mesh.hide()
		message("Visitor keycard collected · guest suites unlocked")
		return true
	if stage=="archive" and p.position.distance_to(cabinet)<2.8:
		open_puzzle()
		return true
	for door in passages:
		if not door.broken and p.position.distance_to(door.global_position+door.global_basis.x)<3:
			if door.kind=="window":
				message("Shoot the glass, then move through the opening.")
			elif door.locked and not visitor_card:
				message("Locked · find the reception keycard or shoot the lock")
			else:
				door.locked = false
				door.opened = not door.opened
			return true
	# An occupied police vehicle is not an instant escape button.
	for v in world.vehicles:
		if v.police and p.position.distance_to(v.position)<4 and (v.boat or v.crew.any(func(n): return n.boarded and n.hp>0)):
			alert(p.position,2)
			for n in v.crew:
				n.deploy()
			message("The crew resists. Find an unattended vehicle.")
			return true
	return false

func open_puzzle() -> void:
	if puzzle:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	puzzle = PanelContainer.new()
	hud.get_parent().add_child(puzzle)
	puzzle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	puzzle.offset_left = -240
	puzzle.offset_top = -245
	puzzle.offset_right = 240
	puzzle.offset_bottom = 245
	var style = StyleBoxFlat.new()
	style.bg_color = Color("152b36f8")
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	puzzle.add_theme_stylebox_override("panel",style)
	var column = VBoxContainer.new()
	puzzle.add_child(column)
	var label = Label.new()
	label.text = "LEDGER CABINET / SERVICE CIRCUIT\nConnect IN (left) to OUT (right).\nClick a tile to rotate it. The world keeps moving."
	column.add_child(label)
	var grid = GridContainer.new()
	grid.columns = 3
	column.add_child(grid)
	puzzle_buttons = []
	for i in pipes.size():
		var button = Button.new()
		button.custom_minimum_size = Vector2(138,90)
		button.add_theme_font_size_override("font_size",42)
		button.pressed.connect(rotate_pipe.bind(i))
		grid.add_child(button)
		var drawing = PipeTile.new()
		button.add_child(drawing)
		drawing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.set_meta("pipe_visual",drawing)
		puzzle_buttons.append(button)
	var ends = Label.new()
	ends.text = "IN > top left                          bottom right > OUT"
	column.add_child(ends)
	puzzle_check = Button.new()
	puzzle_check.text = "TEST CIRCUIT"
	puzzle_check.custom_minimum_size.y = 38
	puzzle_check.pressed.connect(test_circuit)
	column.add_child(puzzle_check)
	var cancel = Button.new()
	cancel.text = "LEAVE PANEL [ESC]"
	cancel.pressed.connect(close_puzzle)
	column.add_child(cancel)
	_update_pipes()

func rotate_pipe(index: int) -> void:
	pipes[index] = ((pipes[index]<<1)&15)|(pipes[index]>>3)
	_update_pipes()

func _update_pipes() -> void:
	for i in puzzle_buttons.size():
		puzzle_buttons[i].text = ""
		var drawing = puzzle_buttons[i].get_meta("pipe_visual")
		drawing.mask = pipes[i]
		drawing.queue_redraw()

func circuit_connected() -> bool:
	if not pipes[0]&8 or not pipes[8]&2:
		return false
	var queue = [0]
	var seen = {0:true}
	var dirs = [[0,-1,1,4],[1,0,2,8],[0,1,4,1],[-1,0,8,2]]
	while not queue.is_empty():
		var i = queue.pop_front()
		if i==8:
			return true
		for d in dirs:
			var x = i%3+d[0]
			var y = int(i/3)+d[1]
			var next = y*3+x
			if x>=0 and x<3 and y>=0 and y<3 and not seen.has(next) and pipes[i]&d[2] and pipes[next]&d[3]:
				seen[next] = true
				queue.append(next)
	return false

func test_circuit() -> void:
	if circuit_connected():
		stage = "escape"
		ledger_mesh.visible = false
		close_puzzle()
		alert(cabinet,3)
		message("Ledger recovered. Reach Pier 04; the service launch is waiting.",5)
	else:
		puzzle_check.text = "NO CONNECTION · ROTATE AND RETRY"
		audio.effect("click",world.player.position,-16)

func close_puzzle() -> void:
	if puzzle:
		puzzle.queue_free()
		puzzle = null
		puzzle_buttons = []
	world.restore_pointer()

func toggle_map() -> void:
	map_open = not map_open
	hud.large_map = map_open
	get_tree().paused = map_open
	audio.set_paused(map_open)
	if map_open:Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:world.restore_pointer()

func _unhandled_input(event: InputEvent) -> void:
	if not world.started:
		return
	if event.is_action_pressed("map"):
		toggle_map()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause"):
		if puzzle:
			close_puzzle()
		elif map_open:
			toggle_map()
	if map_open or puzzle:
		return
	if event.is_action_pressed("unarmed"):
		armed = false
	if event.is_action_pressed("pistol"):
		armed = true
	if event.is_action_pressed("reload"):
		reload()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		fire()

func reset_run() -> void:
	close_puzzle()
	if map_open:
		toggle_map()
	hp = 100
	stamina = 100
	exhausted = false
	ammo = 12
	reserve = 72
	wanted = 0
	world.chase = false
	stage = "failed" if stage not in ["available","complete"] else stage
	visitor_card = false
	keycard_mesh.show()
	pipes = [5,10,3,12,5,9,12,5,10]
	arrest = 0
	extract_timer = 0
	armed = false
	ledger_mesh.visible = true
	for p in passages:
		p.opened = false
		p.locked = p.kind=="door"
		p.hp = 15 if p.kind=="window" else 45
		p.broken = false
		p.panel.collision_layer = 1
		p.panel.collision_mask = 1
		p.visual.show()
	for n in officers:
		n.hp = 80
		n.torso.rotation = Vector3.ZERO
		n.torso.position.y = 0
		n.set_boarded(true)

func vehicle_on_call(_car) -> bool:
	return true

func search_duration() -> float:
	return 18.0

func _physics_process(dt: float) -> void:
	if not world.started or get_tree().paused:
		return
	current_shooters.clear()
	if hp<=0:
		if world.clock>dead_until:
			world.reset_test()
		return
	var p = world.player
	if not p.vehicle and p.sprint and p.velocity.length()>1 and not p.swimming and not exhausted:
		stamina = maxf(0,stamina-dt*17)
		if stamina<=0:
			exhausted = true
	else:
		stamina = minf(100,stamina+dt*22)
		if stamina>=25:
			exhausted = false
	if reload_until>0 and world.clock>=reload_until:
		var count = mini(mag_size()-ammo,reserve)
		ammo += count
		reserve -= count
		reload_until = 0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		fire()
	if world.chase and wanted==0:
		alert(p.position,3)
	elif not world.chase and wanted>0:
		wanted = 0
	if wanted>0:
		if tick_seen:
			unseen = 0
		else:
			unseen += dt
		tick_seen = false
		if unseen>search_duration() and world.clock-crime_at>search_duration()+6:
			wanted = maxi(0,wanted-1)
			unseen = 8
			world.chase = wanted>0
		for v in world.vehicles:
			if not v.police or not vehicle_on_call(v):
				continue
			var dist = v.position.distance_to(p.position)
			if not v.boat and v.crew.all(func(n): return n.boarded) and dist<22 and (not p.vehicle or p.vehicle.speed<2) and v.speed<4:
				for n in v.crew:
					n.deploy()
			if dist<65 and (v.boat or v.crew.any(func(n): return n.hp>0)) and not p.submerged and sees_player(v.position+Vector3.UP*1.5,[v.get_rid()]):
				observe(p.position)
	arrest = maxf(0,arrest-dt*.12)
	if arrest>=1:
		hurt(100)
	if not p.vehicle or p.vehicle.speed>3:
		extract_timer = maxf(0,extract_timer-dt*2)
	if stage=="enter" and p.position.x>-58 and p.position.x<-32 and p.position.z>14 and p.position.z<39 and p.position.y<5:
		stage = "lift"
	elif stage=="lift" and p.position.y>6.4 and p.position.x>-60 and p.position.x<-30 and p.position.z<41:
		stage = "archive"
	elif stage=="escape" and not p.vehicle and p.position.distance_to(pier)<8:
		stage = "board"
	elif stage=="board" and p.vehicle and p.vehicle.boat:
		stage = "depart"
	elif stage=="depart" and p.vehicle and p.vehicle.boat and p.position.distance_to(departure)<30 and wanted==0:
		stage = "complete"
		cash += 1800
		message("Ledger delivered. The clerk has what they need. +$1800",7)

func _process(dt: float) -> void:
	if not world.started:
		return
	hud.queue_redraw()
	if get_tree().paused:
		world._publish_browser_state(dt)
		return
	recoil = move_toward(recoil,0,dt*.5)
	gun.visible = armed and not world.player.vehicle and hp>0
	gun.position.z = -.55+recoil
	for trace in traces.duplicate():
		if world.clock>trace.until:
			trace.mesh.queue_free()
			traces.erase(trace)

func interaction_hint() -> String:
	var p = world.player
	if puzzle:
		return "Rotate tiles · Test circuit · Esc to leave"
	if p.vehicle:
		return "E · Exit vehicle"
	if p.position.distance_to(job_board)<3.8:
		return "E · Accept The Night Ledger" if stage in ["available","complete","failed"] else "THE NIGHT LEDGER · Job in progress"
	if p.position.distance_to(lift.position+Vector3(0,0,1.2))<3:
		return "E · Ride lift to guest floor" if lift.position.y<4 else "E · Ride lift to lobby"
	if stage=="archive" and p.position.distance_to(cabinet)<3:
		return "E · Open cabinet service panel"
	if not visitor_card and p.position.distance_to(Vector3(-52,2.6,20))<3:
		return "E · Collect guest keycard"
	for door in passages:
		if not door.broken and p.position.distance_to(door.global_position+door.global_basis.x)<3:
			return ("Shoot glass · Move through" if door.kind=="window" else "E · "+door.title+(" · Locked" if door.locked and not visitor_card else ""))
	for v in world.vehicles:
		if v.position.distance_to(p.position)<4 and v.speed<2:
			return "E · Board launch" if v.boat else "E · Enter vehicle"
	return ""
