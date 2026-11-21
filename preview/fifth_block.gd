extends Node3D

# Coordinates follow the Manhattan grid: x points along 34th toward Madison,
# z points downtown along Fifth. The survey mesh stays in its original coordinates.
const STONE := Color("#c7bdaa")
const TRIM := Color("#d9cbb1")
const BASE := Color("#242b30")
const BRASS := Color("#c6964c")
const GLASS := Color("#355460")
const STEEL := Color("#718185")
const PAINT := Color("#e8dfca")
const SNOW := Color("#dfe9e9")
const PINE := Color("#204c3e")
const FRONT := Transform3D.IDENTITY
var shapes: Dictionary = {}
var batches: Dictionary = {}
var context := FRONT
var lights: Array = []
var last_light_state := -1
var walkers: Array = []
var taxi: Node3D
var parked: CharacterBody3D
var route := Curve3D.new()
var distance := 0.0
var cab_speed := 0.0
var cycle := 0.0
var cross_stop := 0.0
var yield_point := 0.0
var driven := false
var driver_speed := 0.0
var steer := 0.0
var street_user := Vector3.INF
const BODY := preload("res://body.tscn")

func _ready() -> void:
	rotation.y = -atan2(.488,.873)
	position = Vector3(-208.099,0,573.891)
	var cube := BoxMesh.new()
	var ball := SphereMesh.new()
	ball.radial_segments=10
	ball.rings=5
	var cone := CylinderMesh.new()
	cone.top_radius=0
	cone.bottom_radius=.5
	cone.height=1
	cone.radial_segments=10
	shapes={"box":cube,"ball":ball,"cone":cone}
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	for mesh in shapes.values():
		mesh.material=mat
	make_facades()
	make_streets()
	flush_static()
	make_traffic()

func part(at: Vector3, size: Vector3, color: Color, kind: String="box", rot: Vector3=Vector3.ZERO) -> void:
	if not batches.has(kind):
		batches[kind]=[]
	batches[kind].append([context*Transform3D(Basis.from_euler(rot).scaled_local(size),at),color])

func flush_static() -> void:
	for kind in batches:
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.use_colors=true
		multi.mesh=shapes[kind]
		multi.instance_count=batches[kind].size()
		for i in multi.instance_count:
			multi.set_instance_transform(i,batches[kind][i][0])
			multi.set_instance_color(i,batches[kind][i][1])
		var node:=MultiMeshInstance3D.new()
		node.multimesh=multi
		add_child(node)
	batches.clear()

func label(words: String, at: Vector3, height: float, color: Color, angle: float=0) -> void:
	var sign:=Label3D.new()
	sign.text=words
	sign.font_size=64
	sign.pixel_size=height/64.0
	sign.outline_size=0
	sign.modulate=color
	sign.double_sided=false
	sign.transform=context*Transform3D(Basis(Vector3.UP,angle),at)
	add_child(sign)

func facade_frame(at: Vector3, angle: float) -> void:
	context=Transform3D(Basis(Vector3.UP,angle),at)

func shop(x: float, width: float, decorated: bool) -> void:
	part(Vector3(x,2.27,.23),Vector3(width,4.5,.38),BASE)
	part(Vector3(x,2.08,.45),Vector3(width-.36,3.42,.08),GLASS)
	part(Vector3(x,3.85,.53),Vector3(width,.25,.3),TRIM)
	for side in [-1,1]:
		part(Vector3(x+side*width*.31,1.99,.53),Vector3(.065,3.36,.1),BRASS)
	part(Vector3(x,.48,.53),Vector3(width,.18,.2),STEEL)
	if decorated:
		for i in 3:
			var t:=x+(i-1)*width*.23
			part(Vector3(t,1.6,.54),Vector3(.82,1.85,.23),PINE,"cone")
			part(Vector3(t,2.58,.57),Vector3.ONE*.13,BRASS,"ball")
			part(Vector3(t+.27,.81,.56),Vector3(.38,.37,.23),Color("#9a3639"))
		for i in 9:
			part(Vector3(x-width*.43+i*width*.107,3.46+.08*cos(i*.78),.57),Vector3.ONE*.095,Color("#ffcf73"),"ball")

func make_facades() -> void:
	facade_frame(Vector3(65.30,0,0),PI/2)
	part(Vector3(0,8,-.18),Vector3(58.6,16,.57),STONE)
	for i in range(-9,10):
		var x:=i*3.04
		if abs(i)>2:
			shop(x,3.03,i%2==0)
			for floor_no in 3:
				var y:=6.15+floor_no*3.3
				part(Vector3(x,y,.17),Vector3(1.81,2.25,.12),Color("#643b39"))
				part(Vector3(x,y,.25),Vector3(1.61,2.03,.05),GLASS)
				part(Vector3(x,y+.39,.30),Vector3(1.64,.085,.06),BASE)
	# Fifth Avenue's limestone frame and three tall diamond-pattern metal bays.
	part(Vector3(0,6.8,.26),Vector3(12.5,13.6,.55),BASE)
	for i in [-1,0,1]:
		var x:float=i*2.63
		part(Vector3(x,7.0,.60),Vector3(2.52,7.3,.16),GLASS)
		for side in [-1,1]:
			part(Vector3(x+side*1.23,6.8,.74),Vector3(.12,7.8,.12),STEEL)
		for j in 3:
			for side in [-1,1]:
				part(Vector3(x,4.5+j*2.1,.79),Vector3(.073,3.17,.09),STEEL,"box",Vector3(0,0,side*.84))
		part(Vector3(x,1.53,.67),Vector3(2.32,2.98,.13),GLASS)
		part(Vector3(x,1.52,.78),Vector3(.11,2.98,.1),BRASS)
		part(Vector3(x,3.12,.85),Vector3(2.61,.23,.45),STEEL)
	for side in [-1,1]:
		var x:int=side*5
		part(Vector3(x,8.0,.65),Vector3(1.72,16,1.0),STONE)
		for j in 5:
			part(Vector3(x+(j-2)*.29,8.9,1.18),Vector3(.13,13.8,.20),TRIM)
		part(Vector3(x,1.8,1.0),Vector3(1.75,3.6,.55),BASE)
	part(Vector3(0,13.5,.66),Vector3(11.6,4.9,.76),STONE)
	label("E M P I R E   S T A T E",Vector3(0,14.7,1.07),.86,Color("#e4b45f"))
	for side in [-1,1]:
		part(Vector3(side*2.05,12.3,1.06),Vector3(1.92,1.64,.08),GLASS)
	label("350",Vector3(0,2.91,.91),.26,PAINT)
	facade_frame(Vector3(-9,0,-30.08),PI)
	part(Vector3(0,3.5,0),Vector3(148,7,.32),STONE)
	for i in range(-14,15):
		if i in [4,5,6]: continue
		shop(i*5.0,4.85,i%3!=0)
	label("S T A R B U C K S   R E S E R V E",Vector3(-55,4.75,.42),.48,BASE)
	part(Vector3(25,3.6,.35),Vector3(14.6,7.2,.42),BASE)
	for i in range(-2,3):
		part(Vector3(25+i*2.6,2.34,.65),Vector3(2.34,4.48,.16),GLASS)
		part(Vector3(25+i*2.6,2.2,.76),Vector3(.095,4.2,.10),BRASS)
	part(Vector3(25,4.9,1.65),Vector3(15,.48,3.0),BASE)
	label("EMPIRE STATE BUILDING",Vector3(25,4.9,3.19),.46,Color("#f4d18b"))
	label("O B S E R V A T O R Y",Vector3(25,6.2,.64),.63,BRASS)
	context=FRONT

func stripe(at: Vector3, size: Vector3) -> void:
	part(at,size,PAINT)
func make_streets() -> void:
	for side in [-1,1]:
		for i in 10:
			stripe(Vector3(73.4+i*1.66,.07,-45.8+side*10.3),Vector3(.67,.036,3.1))
			stripe(Vector3(81.0+side*10.9,.07,-53.1+i*1.62),Vector3(3.1,.036,.66))
	for i in range(-8,8):
		var z:float=-45.8+i*8.0
		if abs(z+45.8)>13:
			for x in [76.0,80.0,84.2]:
				stripe(Vector3(x,.064,z),Vector3(.095,.024,3))
	for i in range(-27,17):
		var x:float=81+i*8
		if abs(x-81)>15:
			for dz in [-.12,.12]:
				part(Vector3(x,.065,-45.8+dz),Vector3(8,.023,.095),Color("#d7ac43"))
			for dz in [-4.4,4.4]:
				stripe(Vector3(x,.064,-45.8+dz),Vector3(3,.024,.09))
	stripe(Vector3(81,.07,-60.2),Vector3(16.0,.04,.48))
	stripe(Vector3(65,.07,-41.5),Vector3(.48,.04,7.8))
	stripe(Vector3(97,.07,-50.1),Vector3(.48,.04,7.8))
	# Plowed curb snow is interrupted at crossings and entrances.
	for i in range(-38,40):
		var x:=i*3.8
		for z in [-55.25,-36.55]:
			if abs(x-81)>14:
				snow(x,z,i)
	for i in range(-37,34):
		var z:=i*3.9
		for x in [71.5,90.5]:
			if abs(z+45.8)>14 and abs(z-39)>9:
				snow(x,z,i)
	for x in [-58.0,-17.0,27.0,66.0,98.0]:
		for z in [-56.4,-35.1]:
			lamp(Vector3(x,0,z))
	for z in [-100.0,-78.0,-17.0,17.0]:
		lamp(Vector3(70.3,0,z))
	for x in [70.0,92.0]:
		for z in [-56.4,-35.1]:
			build_signal(Vector3(x,0,z),x<81,z < -45.8)

func snow(x: float,z: float,i: int) -> void:
	var length:=3.75+.42*cos(i*1.4)
	var along_fifth:=is_equal_approx(x,71.5) or is_equal_approx(x,90.5)
	var size:=Vector3(length,.28+.14*sin(i*.7),.95+.24*cos(i))
	if along_fifth: size=Vector3(size.z,size.y,size.x)
	part(Vector3(x,.17,z),size,SNOW,"ball")

func lamp(at: Vector3) -> void:
	part(at+Vector3.UP*3.1,Vector3(.13,6.2,.13),BASE)
	part(at+Vector3(.49,6.08,0),Vector3(1.08,.1,.12),STEEL)
	part(at+Vector3(.97,6.03,0),Vector3(.55,.14,.28),TRIM)
	part(at+Vector3(0,2.7,0),Vector3(.39,1.25,.34),PINE,"cone")
	for i in 4:
		part(at+Vector3(.15*sin(i*2),2.31+i*.2,.15*cos(i*2)),Vector3.ONE*.1,BRASS,"ball")

func build_signal(at: Vector3, west: bool, north: bool) -> void:
	part(at+Vector3.UP*2.6,Vector3(.14,5.2,.14),STEEL)
	var sign_yaw:=0.0 if north else PI
	for j in 2:
		context=Transform3D(Basis(Vector3.UP,sign_yaw+j*PI/2),at)
		part(Vector3(0,3.75+j*.31,0),Vector3(1.55,.31,.075),Color("#23574b"))
		for rot in [0.0,PI]:
			label("W 34 St" if j==0 else "5 Av",Vector3(0,3.75+j*.31,.042*cos(rot)),.237,Color.WHITE,rot)
	context=FRONT
	var arm:=5.2 if west else -5.2
	part(at+Vector3(arm/2,5.12,0),Vector3(abs(arm),.12,.13),STEEL)
	signal_head(at+Vector3(arm,4.58,0),PI,true)
	signal_head(at+Vector3(0,3.0,0),PI/2 if west else -PI/2,false)
	var face_rot:=PI/2 if west else -PI/2
	signal_head(at+Vector3(0,2.34,.32),face_rot,false,true)
	signal_head(at+Vector3(.32,2.34,0),0.0 if north else PI,true,true)

func signal_head(at: Vector3,angle: float,avenue: bool,ped: bool=false) -> void:
	context=Transform3D(Basis(Vector3.UP,angle),at)
	part(Vector3.ZERO,Vector3(.38,.45 if ped else .94,.30),Color("#c38e31"))
	part(Vector3(0,0,.16),Vector3(.34,.39 if ped else .86,.055),BASE)
	for i in (1 if ped else 3):
		var n:=MeshInstance3D.new()
		n.mesh=shapes["ball"]
		n.transform=context*Transform3D(Basis.IDENTITY.scaled(Vector3(.22,.22,.077)),Vector3(0,0 if ped else .28-i*.28,.21))
		add_child(n)
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		n.material_override=mat
		lights.append([mat,avenue,ped,i])
	context=FRONT

func car_visual(cab: bool) -> Node3D:
	var car:=Node3D.new()
	car.set_script(preload("res://town_car.gd"))
	car.build(cab)
	return car

func make_traffic() -> void:
	parked=CharacterBody3D.new()
	parked.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	parked.collision_layer=2
	parked.collision_mask=3
	add_child(parked)
	parked.position=Vector3(88.7,.035,-31.6)
	parked.rotation.y=PI
	var collider:=CollisionShape3D.new()
	var hull:=BoxShape3D.new()
	hull.size=Vector3(1.9,1.43,4.45)
	collider.shape=hull
	collider.position.y=.79
	parked.add_child(collider)
	parked.add_child(car_visual(false))
	var cab_body := AnimatableBody3D.new()
	cab_body.sync_to_physics = false
	cab_body.collision_layer = 2
	cab_body.collision_mask = 0
	taxi = cab_body
	add_child(taxi)
	taxi.add_child(collider.duplicate())
	taxi.add_child(car_visual(true))
	# Southbound Fifth, westbound in the north half of 34th, north on Sixth,
	# then east on 36th. Trim each corner and sample a quadratic turning arc.
	var corners:=[Vector3(74.5,0,-206),Vector3(74.5,0,-49.6),Vector3(-222.6,0,-48.3),Vector3(-224.1,0,-205.0)]
	for i in corners.size():
		var c:Vector3=corners[i]
		var a:Vector3=c.move_toward(corners[(i+3)%4],7)
		var b:Vector3=c.move_toward(corners[(i+1)%4],7)
		for j in 13:
			var t:=j/12.0
			route.add_point(a.lerp(c,t).lerp(c.lerp(b,t),t))
	route.add_point(route.get_point_position(0))
	cross_stop=route.get_closest_offset(Vector3(74.5,0,-62.8))
	yield_point=route.get_closest_offset(Vector3(74.5,0,-55.7))
	distance=cross_stop-13
	cycle=23.0
	for i in 10:
		var group:=i%2
		var shift:=float(i/2)*.43
		if group==0:
			add_walker(Vector3(69.1+shift,0,-58.3-i%3),Vector3(69.1+shift,0,-33+i%3),i,0)
		else:
			add_walker(Vector3(68.5-i%3,0,-56.7+shift),Vector3(93.4+i%3,0,-56.7+shift),i,1)
	for i in 6:
		if i%2==0:
			add_walker(Vector3(94+i*.3,0,-33),Vector3(94+i*.3,0,31),i+10,2)
		else:
			add_walker(Vector3(-75,0,-32-i*.27),Vector3(68,0,-32-i*.27),i+10,2)
	update_lights()
	update_taxi(0)

func add_walker(a: Vector3,b: Vector3,i: int,group: int) -> void:
	var n:=BODY.instantiate() as Node3D
	add_child(n)
	var coats:=[Color("#913c37"),Color("#365c60"),Color("#37404c"),Color("#bea572"),Color("#50705b")]
	var coat:StandardMaterial3D=n.get_node("Jacket").mesh.material.duplicate()
	coat.albedo_color=coats[i%coats.size()]
	for item in ["Jacket","Hem","RightSleeve","LeftSleeve"]:
		n.get_node(item).material_override=coat
	n.scale*=.93+(i%4)*.033
	if i%4>=2:
		var temp:=a
		a=b
		b=temp
	n.position=a.lerp(b,float(i%5)/5.0) if group==2 else a
	n.rotation.y=atan2(a.x-b.x,a.z-b.z)
	walkers.append({"node":n,"start":a,"end":b,"group":group,"moving":group==2,"pace":1.39+(i%3)*.13,"phase":float(i),"delay":fmod(i*.62,2.0),"limbs":[n.get_node("LeftLeg"),n.get_node("RightLeg"),n.get_node("LeftSleeve"),n.get_node("RightSleeve")]})

func vehicle_signal(avenue: bool) -> int:
	if avenue:
		return 2 if cycle<17 else (1 if cycle<20 else 0)
	return 2 if cycle>=23 and cycle<40 else (1 if cycle>=40 and cycle<43 else 0)

func walk_sign(across_avenue: bool) -> bool:
	return (cycle>=23 and cycle<32) if across_avenue else cycle<9

func update_lights() -> void:
	var state := vehicle_signal(true) + 3 * vehicle_signal(false) + 9 * int(walk_sign(true)) + 18 * int(walk_sign(false))
	if state == last_light_state: return
	last_light_state = state
	for l in lights:
		var color:=Color("#302e29")
		if l[2]:
			color=Color("#eeeacf") if walk_sign(not l[1]) else Color("#d77642")
		elif l[3]==vehicle_signal(l[1]):
			color=[Color("#ff4b32"),Color("#ffc055"),Color("#54d598")][l[3]]
		l[0].albedo_color=color

func update_walkers(dt: float) -> void:
	for w in walkers:
		var n:Node3D=w.node
		if not w.moving:
			var launch:float=23 if w.group==1 else 0
			if cycle>=launch+w.delay and cycle<launch+w.delay+2.0:
				w.moving=true
		if w.moving:
			var goal:Vector3=w.end
			var d:=goal-n.position
			n.rotation.y=atan2(-d.x,-d.z)
			n.position=n.position.move_toward(goal,float(w.pace)*dt)
			w.phase+=dt*6.0
			var swing:=sin(float(w.phase))*.32
			for i in 4:
				w.limbs[i].rotation.x=swing if i in [0,3] else -swing
			if n.position==goal:
				w.end=w.start
				w.start=goal
				w.moving=w.group==2
				for limb in w.limbs: limb.rotation.x=0

func crossing_busy() -> bool:
	for w in walkers:
		var p:Vector3=w.node.position
		if p.x>=68 and p.x<=73 and p.z>=-55.5 and p.z<=-45:
			return true
	return false

func update_taxi(dt: float) -> void:
	var target:=8.0
	var brake_at:=INF
	if distance<=cross_stop and vehicle_signal(true)!=2:
		brake_at=cross_stop
	if distance<=yield_point and crossing_busy():
		brake_at=minf(brake_at,yield_point)
	if brake_at!=INF:
		target=minf(target,sqrt(5.6*maxf(0,brake_at-distance)))
	if absf(distance-yield_point)<12:
		target=minf(target,4)
	var local_user:=street_user
	if driven: local_user=parked.position
	if local_user.is_finite():
		var delta:=local_user-taxi.position
		var fwd:Vector3=-taxi.basis.z
		if delta.dot(fwd)>0 and delta.dot(fwd)<9 and absf(delta.dot(taxi.basis.x))<1.85:
			target=minf(target,maxf(0,(delta.dot(fwd)-3.6)*.9))
	cab_speed=move_toward(cab_speed,target,(2.4 if target>cab_speed else 5.0)*dt)
	var advance:=cab_speed*dt
	if brake_at!=INF: advance=minf(advance,maxf(0,brake_at-distance))
	distance=fposmod(distance+advance,route.get_baked_length())
	var p:=route.sample_baked(distance)
	var next:=route.sample_baked(fposmod(distance+.45,route.get_baked_length()))
	taxi.position=p+Vector3.UP*.025
	taxi.rotation.y=atan2(p.x-next.x,p.z-next.z)

func _physics_process(dt: float) -> void:
	cycle=fposmod(cycle+dt,46)
	update_lights()
	update_walkers(dt)
	update_taxi(dt)

func drive(dt: float, throttle: float, turn: float) -> void:
	var goal:=throttle*(11.2 if throttle>0 else 3.8)
	var accel:=8.2 if driver_speed*throttle<0 else (3.8 if throttle!=0 else 2.8)
	driver_speed=move_toward(driver_speed,goal,accel*dt)
	steer=move_toward(steer,turn*.52,1.8*dt)
	var prev_yaw:=parked.rotation.y
	parked.rotation.y-=driver_speed*tan(steer)/2.65*dt
	if parked.test_move(parked.global_transform,Vector3.UP*.002):
		parked.rotation.y=prev_yaw
	parked.velocity=-parked.global_basis.z*driver_speed
	parked.move_and_slide()
	if parked.get_slide_collision_count()>0: driver_speed*=.65
