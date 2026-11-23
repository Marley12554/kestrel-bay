extends Node3D

const GRADE := preload("res://survey/grade.gd")

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
# Use the sedan wheelbase with arcade steering angles and speed-dependent yaw.
const CAR_WHEELBASE := 2.875
const CAR_MAX_STEER := 1.0
const CAR_PARKING_MAX_STEER := 0.51
const CAR_MAX_FORWARD_SPEED := 58.1152 # 130 mph in metres per second.
const CAR_MAX_REVERSE_SPEED := 5.0
const CAR_STEER_SMOOTH_TIME := 0.021
const CAR_PARKING_STEER_SMOOTH_TIME := 0.058
const CAR_MAX_YAW_RATE := 3.3
const CAR_STEERING_FALLOFF_SPEED := 20.0
const CAR_BRAKE_DECELERATION := 10.5
const CAR_HIGH_SPEED_BRAKE_DECELERATION := 17.0
const CAR_HANDBRAKE_DECELERATION := 5.5
const CAR_SLIDE_YAW_ACCEL := 5.8 # radians per second squared
const CAR_LATERAL_GRIP := 10.5
var reserve: Node3D
var shapes: Dictionary = {}
var batches: Dictionary = {}
var context := FRONT
var signal_materials := {}
var pedestrian_materials := {}
var rear_snow_cover := 0.0
var night_lamps: Array[Transform3D] = []
var lit_lamp_sites := {}
const SIDEWALK_Y := .1524
const HERO_LAMP := Vector2(91.05,6.35)
const WALK_ICON := preload("res://signals/walk.svg")
const HAND_ICON := preload("res://signals/hand.svg")
var last_light_state := -1
var walkers: Array = []
var walker_support: Callable
var cross_taxi: AnimatableBody3D
var cross_route := Curve3D.new()
var cross_distance := 0.0
var cross_speed := 0.0
var south_stop := 0.0
var north_return_stop := 0.0
var taxi: Node3D
var parked: CharacterBody3D
var route := Curve3D.new()
var distance := 0.0
var cab_speed := 0.0
var cycle := 0.0
var cross_stop := 0.0
var yield_point := 0.0
var day_on_grade := false
var tires_airborne := false
var driven := false
var driver_speed := 0.0
var steer := 0.0
var steering_velocity := 0.0
var drift_angle := 0.0
var yaw_velocity := 0.0
var sliding := false
var long_accel := 0.0
var side_accel := 0.0
var shift_wait := 0.0
var backing := false
var street_user := Vector3.INF
const TOWN_CAR := preload("res://town_car.gd")
var parked_visual: TOWN_CAR
var cab_visual: TOWN_CAR
var cross_visual: TOWN_CAR
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
	make_east_frontage()
	make_streets()
	finish_sidewalks()
	flush_static()
	make_traffic()

func part(at: Vector3, size: Vector3, color: Color, kind: String="box", rot: Vector3=Vector3.ZERO) -> void:
	if not batches.has(kind):
		batches[kind]=[]
	batches[kind].append([context*Transform3D(Basis.from_euler(rot).scaled_local(size),at),color])

func flush_static(street_fixtures: bool=false) -> void:
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
		if street_fixtures: node.add_to_group(&"street_fixtures")
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
	if decorated and not get_parent().has_node("Winter"):
		for i in 3:
			var t:=x+(i-1)*width*.23
			part(Vector3(t,1.6,.54),Vector3(.82,1.85,.23),PINE,"cone")
			part(Vector3(t,2.58,.57),Vector3.ONE*.13,BRASS,"ball")
			part(Vector3(t+.27,.81,.56),Vector3(.38,.37,.23),Color("#9a3639"))
		for i in 9:
			part(Vector3(x-width*.43+i*width*.107,3.46+.08*cos(i*.78),.57),Vector3.ONE*.095,Color("#ffcf73"),"ball")

func make_facades() -> void:
	var empire:=preload("res://empire_frontage.gd").new()
	empire.name="EmpireFrontage"
	add_child(empire)
	reserve=preload("res://reserve/store.gd").new()
	reserve.name="StarbucksReserve"
	reserve.transform=Transform3D(Basis(Vector3.UP,PI/2),Vector3(65.04,0,-6.92))
	add_child(reserve)
	facade_frame(Vector3(-9,0,-30.08),PI)
	# The last 18 metres of this return are the Reserve's glazed 34th Street wall.
	part(Vector3(9,3.5,0),Vector3(130,7,.32),STONE)
	for i in range(-14,15):
		if i<=-11 or i in [4,5,6]: continue
		shop(i*5.0,4.85,i%3!=0)

	part(Vector3(25,3.6,.35),Vector3(14.6,7.2,.42),BASE)
	for i in range(-2,3):
		part(Vector3(25+i*2.6,2.34,.65),Vector3(2.34,4.48,.16),GLASS)
		part(Vector3(25+i*2.6,2.2,.76),Vector3(.095,4.2,.10),BRASS)
	part(Vector3(25,4.9,1.65),Vector3(15,.48,3.0),BASE)
	label("EMPIRE STATE BUILDING",Vector3(25,4.9,3.19),.46,Color("#f4d18b"))
	label("O B S E R V A T O R Y",Vector3(25,6.2,.64),.63,BRASS)
	context=FRONT

# Each bay is assembled from the sidewalk face inward. The deep jambs and
# raised stone sills leave room behind the closed doors for future shops.
func east_bay(x: float, width: float, door: bool) -> void:
	var trim := Color("#887466")
	part(Vector3(x,2.05,.12),Vector3(width,4.1,.24),BASE)
	part(Vector3(x,2.0,.30),Vector3(width-.48,3.45,.08),GLASS)
	for side in [-1,1]:
		var edge: float=x+side*(width*.5-.13)
		part(Vector3(edge,2.24,.45),Vector3(.26,4.48,.82),trim)
		part(Vector3(edge,.45,.49),Vector3(.36,.9,.86),STONE)
	part(Vector3(x,4.18,.49),Vector3(width,.42,.92),TRIM)
	if door:
		for side in [-1,1]:
			part(Vector3(x+side*width*.23,1.45,.42),Vector3(width*.42,2.86,.14),BASE)
			part(Vector3(x+side*width*.23,1.87,.51),Vector3(width*.35,1.76,.045),GLASS)
			part(Vector3(x+side*.17,1.17,.56),Vector3(.05,.42,.11),BRASS)
		part(Vector3(x,.10,.57),Vector3(width-.36,.20,1.0),STONE)
	else:
		part(Vector3(x,.48,.5),Vector3(width-.24,.58,.82),trim)
		part(Vector3(x,2.26,.43),Vector3(.08,2.98,.18),BRASS)

func make_east_frontage() -> void:
	facade_frame(Vector3(96.34,0,0),-PI/2)
	for i in range(-6,3):
		var x := i*4.45
		east_bay(x,4.45,i in [-5,-2,1])
		for level in 4:
			var y := 6.0+level*3.05
			part(Vector3(x,y,.13),Vector3(3.75,2.38,.25),BASE)
			for side in [-1,1]:
				part(Vector3(x+side*.87,y,.29),Vector3(1.61,2.12,.09),GLASS)
			part(Vector3(x,y-1.22,.4),Vector3(4.25,.17,.64),TRIM)
	context=FRONT
	var demarest := preload("res://demarest.gd").new()
	demarest.name="Demarest"
	add_child(demarest)

func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	body.add_child(collision)
	body.position=at
	add_child(body)
	return body

func finish_sidewalks() -> void:
	# Frontages extend beyond the survey wall. Collide with the dressed base
	# while retaining space to step between projecting piers at doorways.
	solid(Vector3(96.34,2.1,-8.9),Vector3(.52,4.2,40.05))
	for i in range(-6,4):
		solid(Vector3(95.84,1.9,i*4.45-2.225),Vector3(.8,3.8,.28))
	# Ribbed steel baskets and salt-stained granite planters mark the corners.
	for pos in [Vector3(93.4,0,-33.3),Vector3(69.4,0,29.6),Vector3(93.55,0,47.55)]:
		part(pos+Vector3.UP*.57,Vector3(.53,.90,.53),BASE)
		for i in 12:
			var a:=i*TAU/12
			part(pos+Vector3(.32*cos(a),.62,.32*sin(a)),Vector3(.045,.91,.045),STEEL)
		part(pos+Vector3.UP*1.08,Vector3(.77,.10,.77),BASE,"ball")
		solid(pos+Vector3.UP*.58,Vector3(.65,1.16,.65))
	for z in [-19.4,2.0]:
		var loc:=Vector3(95.35,0,z)
		part(loc+Vector3.UP*.37,Vector3(.94,.64,1.08),Color("#514c48"))
		part(loc+Vector3.UP*.71,Vector3(.96,.10,1.10),SNOW)
		for j in 3:
			part(loc+Vector3(.13*sin(j*2.1),1.02+j*.23,.15*cos(j*2.1)),Vector3(.79-j*.14,.90-j*.10,.79-j*.14),PINE,"cone")
		solid(loc+Vector3.UP*.42,Vector3(.94,.84,1.08))
	for z in [-17.]:
		# Bronze storefront canopy rods, gate guides, and door kick plates.
		facade_frame(Vector3(96.25,0,z),-PI/2)
		part(Vector3(0,3.4,1.04),Vector3(3.75,.16,1.65),Color("#343b39"))
		for side in [-1,1]:
			part(Vector3(side*1.65,3.92,.90),Vector3(.045,1.52,.045),BRASS,"box",Vector3(-.85,0,0))
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
		if abs(z+45.8)>13 and abs(z-39)>9:
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
	# 33rd is a narrower one-way cross street.
	for side in [-1,1]:
		for i in 10:
			stripe(Vector3(73.4+i*1.66,.07,39+side*7.6),Vector3(.67,.036,2.8))
		for i in 6:
			stripe(Vector3(81+side*11.2,.07,34.9+i*1.52),Vector3(2.9,.036,.63))
	stripe(Vector3(81,.07,28.9),Vector3(16,.04,.43))
	stripe(Vector3(95.1,.07,39),Vector3(.43,.04,9.3))
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
	flush_static()
	# Each basis points local +Z from the surveyed sidewalk into the adjacent lane.
	for x in [-70.,-36.,-4.,30.,59.,111.]:
		add_lamp_site(Vector2(x,-55.15),0.,x<70.)
		add_lamp_site(Vector2(x,-35.6),PI)
	for z in [-100.,-70.,-16.,17.,65.]:
		add_lamp_site(Vector2(71.15,z),PI/2)
	for z in [-94.,-64.,-22.,60.]:
		add_lamp_site(Vector2(90.85,z),-PI/2,true)
	add_lamp_site(HERO_LAMP,-PI/2,true)
	# Two far-side avenue heads per junction. Cross-street mast arms extend
	# over approaching lanes on 34th and the single westbound approach on 33rd.
	build_signal(Vector2(67.6,-58.4),true,true,34)
	build_signal(Vector2(91.,-58.6),false,true,34)
	build_signal(Vector2(67.3,-32.7),true,false,34)
	build_signal(Vector2(90.8,-32.8),false,false,34)
	build_signal(Vector2(71.25,28.8),true,true,33)
	build_signal(Vector2(90.8,28.8),false,true,33)
	build_signal(Vector2(71.3,49.5),true,false,33)
	build_signal(Vector2(90.8,49.5),false,false,33)
	flush_static(true)

func snow(x: float,z: float,i: int) -> void:
	if get_parent().has_node("Winter"): return
	var length:=3.75+.42*cos(i*1.4)
	var along_fifth:=is_equal_approx(x,71.5) or is_equal_approx(x,90.5)
	var size:=Vector3(length,.28+.14*sin(i*.7),.95+.24*cos(i))
	if along_fifth: size=Vector3(size.z,size.y,size.x)
	part(Vector3(x,.17,z),size,SNOW,"ball")

func add_lamp_site(site: Vector2, yaw: float, illuminate: bool=false) -> void:
	var foot := Vector3(site.x,SIDEWALK_Y,site.y)
	var frame := Transform3D(Basis(Vector3.UP,yaw),foot)
	solid(foot+Vector3.UP*3.1,Vector3(.29,6.2,.29)).add_to_group(&"streetlight_posts")
	if get_parent().has_node("Winter"):
		night_lamps.append(frame)
		if illuminate: lit_lamp_sites[site] = true
		return
	context=frame
	part(Vector3.UP*3.1,Vector3(.13,6.2,.13),BASE)
	part(Vector3(0,6.08,1.05),Vector3(.12,.10,2.22),STEEL)
	part(Vector3(0,6.03,2.1),Vector3(.28,.14,.55),TRIM)
	context=FRONT

func build_signal(site: Vector2, west: bool, north: bool, street: int) -> void:
	var foot := Vector3(site.x,SIDEWALK_Y,site.y)
	var toward_x := 1. if west else -1.
	var toward_z := 1. if north else -1.
	part(foot+Vector3.UP*.15,Vector3(.32,.30,.32),STEEL)
	part(foot+Vector3.UP*2.7,Vector3(.16,5.4,.16),STEEL)
	solid(foot+Vector3.UP*2.7,Vector3(.24,5.4,.24)).add_to_group(&"traffic_posts")
	var sign_yaw:=0.0 if north else PI
	for j in 2:
		context=Transform3D(Basis(Vector3.UP,sign_yaw+j*PI/2),foot)
		part(Vector3(.79,3.75+j*.31,0),Vector3(1.72,.31,.075),Color("#23574b"))
		for rot in [0.0,PI]:
			label((("W " if west else "E ")+str(street)+" St") if j==0 else "5 Av",Vector3(.79,3.75+j*.31,.055*cos(rot)),.237,Color.WHITE,rot)
	context=FRONT
	if not north:
		var arm := (75.5 if west else 86.5)-foot.x
		part(foot+Vector3(arm*.5,5.31,0),Vector3(absf(arm),.14,.14),STEEL)
		vehicle_head(foot+Vector3(arm,4.84,0),PI,true)
	if (west and north) or (street==34 and not west and not north):
		var lane_z := 39. if street==33 else (-49.8 if west else -41.6)
		var reach := lane_z-foot.z
		part(foot+Vector3(0,5.25,reach*.5),Vector3(.14,.14,absf(reach)),STEEL)
		vehicle_head(foot+Vector3(0,4.78,reach),toward_x*PI/2,false)
	# Brackets on adjacent sides of the pole give each crossing its own face.
	for across_avenue in [true,false]:
		var yaw := toward_x*PI/2 if across_avenue else (0. if north else PI)
		var forward := Basis(Vector3.UP,yaw).z
		context=Transform3D(Basis(Vector3.UP,yaw),foot+Vector3.UP*2.72)
		part(Vector3(0,0,.13),Vector3(.12,.12,.26),STEEL)
		pedestrian_head(foot+Vector3.UP*2.72+forward*.34,yaw,across_avenue)
	if street==33 and north and not west:
		# The Demarest corner photographs show two pendant lamps above the signs.
		part(foot+Vector3.UP*5.85,Vector3(.15,1.1,.15),BASE)
		for side in [-1.,1.]:
			var last := foot+Vector3.UP*6.1
			for i in range(1,11):
				var t:=PI*i/10.
				var tip:=foot+Vector3(side*.57*(1.-cos(t)),6.1+.5*sin(t),0)
				var delta:=tip-last
				part((tip+last)*.5,Vector3(.062,delta.length()+.025,.062),BASE,"box",Vector3(0,0,-atan2(delta.x,delta.y)))
				last=tip
			part(last-Vector3.UP*.09,Vector3(.35,.24,.35),BASE,"ball")
			part(last-Vector3.UP*.17,Vector3(.26,.19,.26),TRIM,"ball")

func vehicle_head(at: Vector3,angle: float,avenue: bool) -> void:
	context=Transform3D(Basis(Vector3.UP,angle),at)
	part(Vector3.ZERO,Vector3(.38,.94,.30),Color("#c38e31"))
	part(Vector3(0,0,.16),Vector3(.34,.86,.055),BASE)
	for i in 3:
		var key := Vector2i(int(avenue),i)
		if not signal_materials.has(key):
			var mat := StandardMaterial3D.new()
			mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			signal_materials[key]=mat
		var n:=MeshInstance3D.new()
		n.mesh=shapes["ball"]
		n.transform=context*Transform3D(Basis.IDENTITY.scaled(Vector3(.22,.22,.077)),Vector3(0,.28-i*.28,.21))
		n.material_override=signal_materials[key]
		add_child(n)
	context=FRONT

func pedestrian_head(at: Vector3,yaw: float,across_avenue: bool) -> void:
	context=Transform3D(Basis(Vector3.UP,yaw),at)
	part(Vector3.ZERO,Vector3(.52,.56,.21),Color("#b88833"))
	part(Vector3(0,0,.109),Vector3(.48,.51,.024),Color("#111518"))
	part(Vector3(0,.257,.169),Vector3(.52,.028,.16),BASE)
	if not pedestrian_materials.has(across_avenue):
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pedestrian_materials[across_avenue]=mat
	var face:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(.445,.445)
	face.mesh=quad
	face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.material_override=pedestrian_materials[across_avenue]
	face.transform=context.translated_local(Vector3(0,0,.126))
	add_child(face)
	context=FRONT

func car_visual(cab: bool, traffic := true) -> TOWN_CAR:
	var car := TOWN_CAR.new()
	car.build(cab, traffic)
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
	parked_visual = car_visual(false, false)
	parked.add_child(parked_visual)
	var cab_body := AnimatableBody3D.new()
	cab_body.sync_to_physics = false
	cab_body.collision_layer = 2
	cab_body.collision_mask = 0
	taxi = cab_body
	add_child(taxi)
	var cab_collider := collider.duplicate() as CollisionShape3D
	var cab_hull := hull.duplicate() as BoxShape3D
	cab_hull.size = Vector3(1.87, 1.46, 5.05)
	cab_collider.shape = cab_hull
	taxi.add_child(cab_collider)
	cab_visual = car_visual(true)
	taxi.add_child(cab_visual)
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
			add_walker(Vector3(93.3+i*.15,0,-33),Vector3(93.3+i*.15,0,31),i+10,2)
		else:
			add_walker(Vector3(-75,0,-32-i*.27),Vector3(68,0,-32-i*.27),i+10,2)
	cross_taxi=AnimatableBody3D.new()
	cross_taxi.sync_to_physics=false
	cross_taxi.collision_layer=2
	cross_taxi.collision_mask=0
	add_child(cross_taxi)
	var sedan_collider := CollisionShape3D.new()
	sedan_collider.shape = preload("res://winter/sedan_hull.tres")
	cross_taxi.add_child(sedan_collider)
	cross_visual = car_visual(false)
	cross_taxi.add_child(cross_visual)
	# Return on the next block, rather than popping back into view.
	var loop := [Vector3(750,0,40),Vector3(-225,0,40),Vector3(-225,0,-42),Vector3(750,0,-42)]
	for i in loop.size():
		var corner: Vector3=loop[i]
		var entry:=corner.move_toward(loop[posmod(i-1,4)],7)
		var exit:=corner.move_toward(loop[(i+1)%4],7)
		for j in 9:
			var t:=j/8.0
			cross_route.add_point(entry.lerp(corner,t).lerp(corner.lerp(exit,t),t))
	cross_route.add_point(cross_route.get_point_position(0))
	south_stop=cross_route.get_closest_offset(Vector3(97.5,0,40))
	north_return_stop=cross_route.get_closest_offset(Vector3(63.0,0,-42))
	cross_distance=south_stop-22
	for i in 4:
		add_walker(Vector3(68.5,0,31.2+i*.21),Vector3(93.7,0,31.2+i*.21),16+i,1)
	add_walker(Vector3(92.25,0,29),Vector3(92.25,0,49),20,0)
	for i in 3:
		add_walker(Vector3(68.3+i*.32,0,-30),Vector3(68.3+i*.32,0,29),21+i,2)
	update_cross_taxi(0)
	update_lights()
	update_taxi(0)

func add_walker(a: Vector3,b: Vector3,i: int,group: int) -> void:
	var n:=BODY.instantiate() as Node3D
	n.variant = (i + floori(i / 4.0)) % n.MODELS.size()
	add_child(n)
	n.animator.seek(fmod(i * .71, n.animator.current_animation_length), true)
	n.scale*=.93+(i%4)*.033
	if i%4>=2:
		var temp:=a
		a=b
		b=temp
	n.position=a.lerp(b,float(i%5)/5.0) if group==2 else a
	n.rotation.y=atan2(a.x-b.x,a.z-b.z)
	walkers.append({"node":n,"last_support":Vector3.INF,"start":a,"end":b,"group":group,"moving":group==2,"pace":1.39+(i%3)*.13,"delay":fmod(i*.62,2.0)})

func ground_walker(w: Dictionary) -> void:
	var actor: Node3D = w.node
	if walker_support.is_valid() and actor.position.distance_squared_to(w.last_support) > .015:
		var ground: float = walker_support.call(actor.global_position)
		actor.model.global_position.y = ground
		w.last_support = actor.position

func vehicle_signal(avenue: bool) -> int:
	if avenue:
		return 2 if cycle<17 else (1 if cycle<20 else 0)
	return 2 if cycle>=23 and cycle<40 else (1 if cycle>=40 and cycle<43 else 0)

func walk_sign(across_avenue: bool) -> bool:
	return (cycle>=23 and cycle<32) if across_avenue else cycle<9

enum PedSignal { HAND, WALK, DARK }

func pedestrian_signal(across_avenue: bool) -> PedSignal:
	if walk_sign(across_avenue): return PedSignal.WALK
	var elapsed := cycle-(23. if across_avenue else 0.)
	if elapsed>=9. and elapsed<20. and fmod(elapsed,1.)>=.5:
		return PedSignal.DARK
	return PedSignal.HAND

func update_lights() -> void:
	var state := vehicle_signal(true) + 3*vehicle_signal(false) + 9*pedestrian_signal(true) + 27*pedestrian_signal(false)
	if state==last_light_state: return
	last_light_state=state
	for key: Vector2i in signal_materials:
		var active := key.y==vehicle_signal(bool(key.x))
		signal_materials[key].albedo_color=[Color("#ff4b32"),Color("#ffc055"),Color("#54d598")][key.y] if active else Color("#302e29")
	for across: bool in pedestrian_materials:
		var aspect:=pedestrian_signal(across)
		var mat: StandardMaterial3D=pedestrian_materials[across]
		mat.albedo_texture=WALK_ICON if aspect==PedSignal.WALK else HAND_ICON
		mat.albedo_color=Color.TRANSPARENT if aspect==PedSignal.DARK else Color.WHITE

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
			# Stay at the kerb if the sedan will reach the same spot first.
			if driven and absf(driver_speed)>1.0:
				var travel: Vector3=-parked.basis.z*signf(driver_speed)
				var relative:=n.position+d.normalized()*1.4-parked.position
				var ahead:=relative.dot(travel)
				if ahead>2.7 and ahead<minf(22,absf(driver_speed)*1.6+2.5) and absf(relative.dot(parked.basis.x))<1.65:
					n.set_pace(0.)
					continue
			n.set_pace(w.pace)
			n.rotation.y=atan2(-d.x,-d.z)
			n.position=n.position.move_toward(goal,float(w.pace)*dt)
			ground_walker(w)
			if n.position==goal:
				w.end=w.start
				w.start=goal
				w.moving=w.group==2
				if not w.moving: n.set_pace(0.)

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
	cab_visual.roll(advance)
	distance=fposmod(distance+advance,route.get_baked_length())
	var p:=route.sample_baked(distance)
	var next:=route.sample_baked(fposmod(distance+.45,route.get_baked_length()))
	taxi.position=p+Vector3.UP*(.025+GRADE.height(to_global(p)))
	taxi.rotation.y=atan2(p.x-next.x,p.z-next.z)

func update_cross_taxi(dt: float) -> void:
	var gap := INF
	if vehicle_signal(false)!=2:
		for stop_offset: float in [south_stop,north_return_stop]:
			var until_stop:=fposmod(stop_offset-cross_distance,cross_route.get_baked_length())
			if until_stop<24: gap=minf(gap,until_stop)
	var front := -cross_taxi.basis.z
	var obstacles: Array[Vector3]=[parked.position,street_user]
	for w in walkers:
		if absf(w.node.position.z-40)<4:
			obstacles.append(w.node.position)
	for p in obstacles:
		if not p.is_finite(): continue
		var offset := p-cross_taxi.position
		var ahead := offset.dot(front)
		if ahead>0 and ahead<22 and absf(offset.dot(cross_taxi.basis.x))<1.8:
			gap=minf(gap,maxf(0,ahead-3.8))
	var target:=minf(7.3,sqrt(6.5*gap))
	cross_speed=move_toward(cross_speed,target,(2.2 if target>cross_speed else 4.8)*dt)
	var length:=cross_route.get_baked_length()
	var advance := minf(cross_speed*dt,gap)
	cross_visual.roll(advance)
	cross_distance=fposmod(cross_distance+advance,length)
	var pos:=cross_route.sample_baked(cross_distance)
	var nose:=cross_route.sample_baked(fposmod(cross_distance+.45,length))
	cross_taxi.position=pos+Vector3.UP*(.025+GRADE.height(to_global(pos)))
	cross_taxi.rotation.y=atan2(pos.x-nose.x,pos.z-nose.z)

func _physics_process(dt: float) -> void:
	cycle=fposmod(cycle+dt,46)
	update_lights()
	update_walkers(dt)
	update_taxi(dt)
	update_cross_taxi(dt)

func reset_steering() -> void:
	sliding = false
	yaw_velocity = 0.0
	steer = 0.0
	steering_velocity = 0.0

func drive(dt: float, throttle: float, turn: float, allow_shift: bool = true, handbrake: bool = false) -> void:
	var previous := driver_speed
	var speed := absf(previous)
	var steering_input := clampf(turn, -1.0, 1.0)
	var opposite := (throttle > 0 and backing) or (throttle < 0 and not backing)
	var service_braking := opposite or (throttle < 0 and not allow_shift)
	if opposite and allow_shift and not handbrake and speed < .001:
		shift_wait += dt
		if shift_wait >= .30:
			backing = throttle < 0
			shift_wait = 0.
			service_braking = false
	else:
		shift_wait = 0.
	if service_braking:
		# Fade out the high-speed braking assist as the sedan approaches city speeds.
		var brake_strength := lerpf(CAR_BRAKE_DECELERATION, CAR_HIGH_SPEED_BRAKE_DECELERATION,
			smoothstep(12.0, 38.0, speed))
		driver_speed = move_toward(previous, 0.0, brake_strength * absf(throttle) * dt)
	elif handbrake:
		# A powered turning slide can carry speed while the rear tires scrub.
		var pull := 3.0 * maxf(throttle, 0.) * absf(steering_input) * smoothstep(2., 6., previous)
		var drag := CAR_HANDBRAKE_DECELERATION + 2.7 * absf(sin(drift_angle))
		driver_speed = move_toward(previous, 0.0, (drag - pull) * dt)
	elif absf(throttle)>.001:
		var limit := CAR_MAX_FORWARD_SPEED if throttle>0 else CAR_MAX_REVERSE_SPEED
		var force := (5.1 if throttle>0 else 2.7)*absf(throttle)
		driver_speed=move_toward(previous,signf(throttle)*limit,dt*force*maxf(.10,1.0-pow(speed/limit,1.6)))
	else:
		driver_speed=move_toward(previous,0,(1.12+.001*speed*speed)*dt)
	if tires_airborne: driver_speed = previous
	var steering_speed := absf(driver_speed)
	# Use a parking-speed steering arc, then blend into the arcade response.
	var road_speed_weight := smoothstep(4.5, 12.0, steering_speed)
	var max_steer := lerpf(CAR_PARKING_MAX_STEER, CAR_MAX_STEER, road_speed_weight)
	var smooth_time := lerpf(CAR_PARKING_STEER_SMOOTH_TIME, CAR_STEER_SMOOTH_TIME, road_speed_weight)
	var yaw_limit := CAR_MAX_YAW_RATE / (1.0 + steering_speed / CAR_STEERING_FALLOFF_SPEED)
	var steering_limit := minf(max_steer, atan(yaw_limit * CAR_WHEELBASE / maxf(1.0, steering_speed)))
	var target := steering_input * steering_limit
	# A critically damped spring eases the wheels into the turn and back to center.
	var offset := steer - target
	var velocity_step := (steering_velocity + offset / smooth_time) * dt
	var decay := exp(-dt / smooth_time)
	var next_steer := target + (offset + velocity_step) * decay
	steering_velocity = (steering_velocity - velocity_step / smooth_time) * decay
	steer = clampf(next_steer, -steering_limit, steering_limit)
	if steer != next_steer:
		steering_velocity = 0.0
	var drift_amount := smoothstep(3.5, 8.0, driver_speed) * absf(steering_input) if handbrake else 0.0
	var previous_yaw := parked.rotation.y
	var travel_yaw := previous_yaw + drift_angle
	var target_yaw_rate := -driver_speed * tan(steer) / CAR_WHEELBASE * (1.0 + .64 * drift_amount)
	sliding = sliding or drift_amount > 0.0 or not is_zero_approx(drift_angle)
	var grip := CAR_LATERAL_GRIP * lerpf(1., .57, rear_snow_cover)
	# With the rear tires sliding, the rolling front axle can still bend the path.
	var sliding_grip := grip * lerpf(.4, .79, absf(steer) / steering_limit) if handbrake else grip
	var path_turn_limit := sliding_grip / maxf(3., steering_speed)
	if tires_airborne:
		# Preserve yaw momentum and the world travel direction until touchdown.
		sliding = true
		path_turn_limit = 0.
	elif sliding:
		if drift_amount > 0. and target_yaw_rate * drift_angle < 0.:
			# At large slip the nose can keep turning, but front tire force
			# saturates. Countersteer still has to arrest existing rotation.
			var saturation := smoothstep(.48, .93, absf(drift_angle))
			target_yaw_rate = lerpf(target_yaw_rate, signf(target_yaw_rate)*path_turn_limit, saturation)
		elif not handbrake:
			target_yaw_rate += clampf(drift_angle * .85, -.75, .75)
		yaw_velocity = move_toward(yaw_velocity, target_yaw_rate, CAR_SLIDE_YAW_ACCEL*lerpf(1.,.7,rear_snow_cover)*dt)
	else:
		yaw_velocity = target_yaw_rate
	parked.rotation.y += yaw_velocity*dt
	if parked.test_move(parked.global_transform,Vector3.UP*.002):
		parked.rotation.y = previous_yaw
		yaw_velocity = 0.
	var body_turn := angle_difference(previous_yaw, parked.rotation.y)
	if sliding:
		# Preserve the previous world travel direction. A bounded lateral
		# tire force can bend that path, even when the wheel changes sides.
		var slip_before_grip := angle_difference(parked.rotation.y, travel_yaw)
		var path_turn := path_turn_limit * dt
		drift_angle = move_toward(slip_before_grip, 0., path_turn)
		if drift_amount == 0. and is_zero_approx(drift_angle) and is_equal_approx(target_yaw_rate,yaw_velocity):
			sliding = false
		if steering_speed < .1:
			sliding = false
			drift_angle = 0.
			yaw_velocity = 0.
	side_accel = driver_speed * angle_difference(travel_yaw,previous_yaw+body_turn+drift_angle)/dt
	var heading := (-parked.global_basis.z).rotated(Vector3.UP, drift_angle)
	var travel := heading*driver_speed*dt
	var hit:=parked.move_and_collide(travel)
	if hit:
		var remainder:=hit.get_remainder().slide(hit.get_normal())
		parked.move_and_collide(remainder)
		var impact := clampf(absf(heading.dot(hit.get_normal())), 0.0, 1.0)
		driver_speed *= 1.0 - impact
		drift_angle *= 1.0 - impact
		yaw_velocity *= 1.0 - impact
	long_accel=clampf((driver_speed-previous)/dt,-15,8)
	parked.velocity=heading*driver_speed
	if not get_parent().has_node("Winter"):
		var graded := GRADE.contains(parked.global_position)
		if graded or day_on_grade:
			parked.position.y = GRADE.physical_height(parked.get_world_3d().direct_space_state,parked.global_position)+.035
		day_on_grade = graded
