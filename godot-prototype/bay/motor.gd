extends "res://vehicle.gd"
# Speeds in m/s. All control sources share the integrator and tire limits.
const CARS={"starter":[22.,4.2],"sedan":[34.,6.2],"taxi":[33.,5.9],"van":[28.,4.8],"muscle":[36.,6.7],
	"sport":[39.,7.8],"striped":[47.,8.3],"cruiser":[41.4,7.4],"security":[32.,6.1],"army":[33.,6.],"tank":[13.,2.9]}
var model="sedan"
var aircraft=false
var rotorcraft=false
var air_throttle=0.
var body_parts=[]
var wreck_loss=[]
var rubbers=[]
var rims=[]
var wheel_pivots=[]
var wheel_rolls=[]
var door
var door_glass
var door_open=0.
var axle_span=2.62
func driver_door()->Vector3:
	return to_global(Vector3(-1.35,.04,-.12))

var engine_mesh
var driver
var crew_head
var helix
var propeller:Node3D
var tail_helix
var flaps=[]
var owned=false
var driving_npc=false
var mission_driver=false
var traffic_route=PackedVector3Array()
var threat_until=0.
var junction_id=-1
var junction_kind=0
var stopped_since=-1.
var entered_junction=false
var blocked_since=-1.
var traffic_lane=0
var lane_width=13.
var turning_path=PackedVector3Array()
var lane_origin=Vector3.INF
var pass_offset=0.
var pass_until=0.
var pass_side=0.
var following_gap=5.0
var obstacle_distance=100.
var horn_at=-100.
var wreck=false
var burning=0.
var flooded=false
var flood_time=0.
var fire_objects=[]
var spike=false
var flat_count=0
var skid_at=0.
var safety_boot=0.
var target_steer=0.
var last_cabin_shot=-100.
var speed_before=0.
var body_color=Color("536b73")
var overboard=false
var gunner_hp=65.
var captain_hp=75.
var seat_bodies=[]
var course=Vector3.ZERO
var assignment=""
var skid_prev=[]
var next_scan=0.
var avoid_turn=0.
var avoid_throttle=1.
var driver_yield=false
var cruise_target=0.
var gear_extended=true
var tires_grounded=false
var beam
var landing_aid=false
func configure(w:Node3D,at:Vector3,is_boat:bool,is_police:bool,index:int)->void:
	aircraft=model in ["helicopter","plane","spotter"]
	rotorcraft=model in ["helicopter","spotter"]
	body_color=Color(["607b80","9e5c50","b8a988","607389","7f8e75","a7adb0"][w.vehicles.size()%6])
	if model=="taxi":body_color=Color("d8a22f")
	if model=="striped":body_color=Color("c59d3f")
	if model in ["army","tank"]:body_color=Color("68705b")
	super(w,at,is_boat,is_police,index)
	owned=model in ["starter","launch"]
	if CARS.has(model):
		max_speed=CARS[model][0]
		acceleration=CARS[model][1]
	elif aircraft:
		max_speed=48. if rotorcraft else 82.
		acceleration=11.
		camera_distance=19. if rotorcraft else 16.
	else:
		max_speed=20.
		acceleration=3.7
	floor_snap_length=0.
	floor_stop_on_slope=false
	if is_boat and police:_marine_crew()
	if searchlight and (is_boat or model=="spotter"):_mount_beam()
func _mount_beam():
	var length=88. if rotorcraft else 37.
	var cone=CylinderMesh.new()
	cone.top_radius=.07;cone.bottom_radius=length*.17;cone.height=length;cone.radial_segments=24;cone.rings=1
	var mat=ShaderMaterial.new()
	mat.shader=preload("res://bay/beam.gdshader")
	var mesh=MeshInstance3D.new()
	mesh.mesh=cone;mesh.material_override=mat;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	searchlight.add_child(mesh)
	mesh.rotation.x=PI/2;mesh.position.z=-length*.5
	beam=mesh
func loft(rings:Array,color:Color):
	var verts=PackedVector3Array()
	for i in range(rings.size()-1):
		var lo=rings[i]
		var hi=rings[i+1]
		for j in lo.size():
			var k=(j+1)%lo.size()
			for p in [lo[j],hi[j],hi[k],lo[j],hi[k],lo[k]]:verts.append(p)
	for index in [0,rings.size()-1]:
		var ring=rings[index]
		for j in range(1,ring.size()-1):
			for p in [ring[0],ring[j],ring[j+1]]:verts.append(p)
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,verts.size(),3):
		var normal=(verts[i+1]-verts[i]).cross(verts[i+2]-verts[i]).normalized()
		for j in 3:
			st.set_normal(normal)
			st.add_vertex(verts[i+j])
	var mesh=MeshInstance3D.new()
	mesh.mesh=st.commit()
	var m=world.material(color).duplicate()
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	m.metallic=.32
	m.roughness=.36
	mesh.material_override=m
	visual.add_child(mesh)
	body_parts.append(mesh)
	return mesh
func ring(y,w,front,rear):
	var cut=minf(.28,w*.34)
	return [Vector3(-w+cut,y,-front),Vector3(w-cut,y,-front),Vector3(w,y,-front+.38),Vector3(w,y,rear-.24),
			Vector3(w-cut,y,rear),Vector3(-w+cut,y,rear),Vector3(-w,y,rear-.24),Vector3(-w,y,-front+.38)]
func part(p,s,c):
	var mesh=world.box(visual,p,s,c)
	body_parts.append(mesh)
	return mesh
func cabin_panel(surface:SurfaceTool,corners:Array,frame:Color,origin=Vector3.ZERO):
	var center=(corners[0]+corners[1]+corners[2]+corners[3])*.25
	var inset=[]
	for point in corners:inset.append(point.lerp(center,.09))
	var normal=(center-Vector3(0,center.y-.12,0)).normalized()
	for j in 5:
		var k=(j+1)%4
		var quad=inset if j==4 else [corners[j],corners[k],inset[k],inset[j]]
		for index in [0,1,2,0,2,3]:
			surface.set_normal(normal)
			surface.set_color(Color("465f6d") if j==4 else frame)
			surface.add_vertex(quad[index]-origin)

func mount_glass(surface:SurfaceTool,parent:Node3D):
	var face=MeshInstance3D.new()
	face.mesh=surface.commit()
	face.material_override=preload("res://bay/cabin.tres")
	parent.add_child(face)
	body_parts.append(face)
	return face
func build_car():
	if aircraft:
		build_aircraft()
		return
	var long_model=model in ["van","tank","army"]
	var sports=model in ["sport","striped"]
	var patrol=model in ["cruiser","security"]
	var col=Color("dadbd2") if patrol else body_color
	var length=5.5 if long_model else (4.06 if model=="starter" else 4.6)
	var half=length*.5
	shape(Vector3(0,.65,0),Vector3(1.94,1.12,length))
	shape(Vector3(0,1.31,.14),Vector3(1.52,.57,2.02))
	engine_mesh=loft([ring(.29,.81,half-.13,half-.14),ring(.50,.98,half,half),ring(.84,.99,half-.04,half-.03),
		ring(.99,.91,half-.31,half-.22)],col)
	var roof_y=1.44 if sports else (1.95 if long_model else 1.61)
	# Cabin and roof share their perimeter. Each pane fits the sloped opening.
	var sill=ring(.985,.90,1.20,1.42)
	var crown=ring(roof_y-.01,.71,.63,1.0)
	door=Node3D.new();visual.add_child(door);door.position=sill[7]
	world.box(door,Vector3(-.035,-.19,.49),Vector3(.065,.38,1.02),col)
	var stationary=SurfaceTool.new()
	stationary.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hinged=SurfaceTool.new()
	hinged.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 8:
		var k=(j+1)%8
		if j==6:
			var bottom=sill[j].lerp(sill[k],.48)
			var top=crown[j].lerp(crown[k],.48)
			cabin_panel(stationary,[sill[j],bottom,top,crown[j]],col)
			cabin_panel(hinged,[bottom,sill[k],crown[k],top],col,door.position)
		else:cabin_panel(stationary,[sill[j],sill[k],crown[k],crown[j]],col)
	mount_glass(stationary,visual)
	door_glass=mount_glass(hinged,door)
	axle_span=half*1.26
	loft([ring(roof_y-.01,.71,.63,1.0),ring(roof_y+.08,.67,.55,.9)],col)
	for x in [-1,1]:
		wreck_loss.append(part(Vector3(x*.96,1.02,-.65),Vector3(.25,.14,.23),col))
		part(Vector3(x*.95,.82,.45),Vector3(.075,.063,.24),Color("c0c3bb"))
		for z in [-half*.63,half*.63]:
			var wheel=world.cylinder(visual,Vector3(x*.93,.36,z),.36,.24,Color("1b2428"))
			wheel.rotation.z=PI/2
			rubbers.append(wheel)
			var rim=world.cylinder(visual,Vector3(x*.98,.36,z),.235,.20,Color("9da7a5"))
			rim.rotation.z=PI/2
			rims.append(rim)
			var pivot=Node3D.new()
			visual.add_child(pivot);pivot.position=wheel.position
			var roll=Node3D.new();pivot.add_child(roll)
			wheel.reparent(roll);rim.reparent(roll)
			world.box(roll,Vector3(x*.145,0,0),Vector3(.012,.34,.054),Color("53616a"))
			wheel_pivots.append(pivot);wheel_rolls.append(roll)
		part(Vector3(x*.66,.76,-half+.01),Vector3(.47,.14,.09),Color("ebdfbb"))
		part(Vector3(x*.65,.76,half-.02),Vector3(.42,.15,.09),Color("aa4543"))
	wreck_loss.append(part(Vector3(0,.54,-half-.01),Vector3(.78,.16,.05),Color("303b3c")))
	part(Vector3(0,.65,half+.012),Vector3(.36,.14,.035),Color("ddb970"))
	add_headlight(Vector3(0,.85,-half))
	if model=="striped":
		for x in [-.21,.21]:
			for p in [Vector3(x,1.,-1.63),Vector3(x,roof_y+.085,.19),Vector3(x,1.,1.73)]:
				part(p,Vector3(.18,.014,.68 if absf(p.z)>1 else 1.3),Color("263a43"))
	if patrol or model in ["army","tank"]:
		for side in [-1,1]:
			part(Vector3(side*.996,.72,0),Vector3(.016,.27,3.25),Color("315273") if model=="cruiser" else Color("424e4d"))
			world.make_sign(visual,Vector3(side*1.012,.75,0),("NYPD" if model=="cruiser" else "SECURITY"),.005,side*PI/2)
			flash_lenses.append(part(Vector3(side*.34,roof_y+.2,0),Vector3(.57,.15,.31),Color("c23b44") if side<0 else Color("356bba")))
	if model=="taxi":part(Vector3(0,roof_y+.22,.2),Vector3(.76,.27,.38),Color("e4cc86"))
	if model=="tank":
		part(Vector3(0,1.94,0),Vector3(1.45,.7,1.9),Color("565e4a"))
		part(Vector3(0,2.02,-1.85),Vector3(.18,.18,2.6),Color("56644f"))
		for x in [-1,1]:part(Vector3(x,.44,0),Vector3(.46,.66,length),Color("444c41"))
	driver=Node3D.new()
	visual.add_child(driver)
	driver.position=Vector3(-.44,.9,-.15)
	world.box(driver,Vector3.ZERO,Vector3(.40,.5,.31),Color("566570"))
	world.box(driver,Vector3(0,.37,0),Vector3(.28,.3,.25),Color("bd977a"))
	driver.hide()
func build_boat():
	shape(Vector3(0,.02,0),Vector3(2.74,1.05,8.32))
	shape(Vector3(0,.96,.25),Vector3(1.72,1.12,2.08))
	engine_mesh=loft([ring(-.53,.67,3.7,4.06),ring(.34,1.36,4.12,4.15),ring(.56,1.35,4.05,4.15)],Color("35596c") if police else Color("c4b596"))
	part(Vector3(0,.6,.18),Vector3(2.6,.12,7.9),Color("9a9381"))
	loft([ring(.63,.9,1.16,1.4),ring(1.55,.78,.76,1.13)],Color("46616b"))
	part(Vector3(0,1.64,.15),Vector3(1.9,.18,2.45),Color("dbd8c8"))
	for side in [-1,1]:
		for k in 4:part(Vector3(side*1.28,.90,-3.4+k*.95),Vector3(.048,.63,.05),Color("9ba9a7"))
		part(Vector3(side*1.28,1.2,-2),Vector3(.055,.06,3.0),Color("9ba9a7"))
		shape(Vector3(side*1.28,.92,-2),Vector3(.06,.7,3.0))
	part(Vector3(0,.19,4.28),Vector3(.76,.96,.48),Color("323b3f"))
	shape(Vector3(0,.19,4.28),Vector3(.76,.96,.48))
	add_headlight(Vector3(0,1.75,-1.))
	if police:
		searchlight=SpotLight3D.new()
		visual.add_child(searchlight)
		searchlight.position=Vector3(0,2.05,-.3)
		searchlight.spot_range=110
		searchlight.spot_angle=19
		searchlight.light_energy=3.5
		for s in [-1,1]:
			flash_lenses.append(part(Vector3(s*.61,1.82,0),Vector3(.37,.14,.2),Color("505e6b")))
func _marine_crew():
	for index in 2:
		var sailor=StaticBody3D.new()
		visual.add_child(sailor)
		sailor.position=Vector3(-.49 if index==0 else .55,1.58 if index==0 else .66,.8 if index==0 else 2.7)
		sailor.collision_layer=8
		sailor.set_script(preload("res://bay/deckhand.gd"))
		sailor.boat=self
		sailor.index=index
		world.collision_box(sailor,Vector3.UP*.64,Vector3(.47,1.28,.44))
		world.box(sailor,Vector3.UP*.63,Vector3(.45,.88,.34),Color("34465b"))
		world.box(sailor,Vector3.UP*1.24,Vector3(.29,.34,.29),Color("b78e70"))
		world.box(sailor,Vector3.UP*1.42,Vector3(.34,.09,.34),Color("283c4d"))
		seat_bodies.append(sailor)
# Cross sections follow the longitudinal axis from spinner to rudder.
func fuselage_station(z:float,y:float,rx:float,ry:float)->Array:
	var points=[]
	for i in 12:
		var angle=i*TAU/12.
		points.append(Vector3(rx*cos(angle),y+ry*sin(angle),z))
	return points

func wing_section(x:float,y:float,leading:float,chord:float,depth:float)->Array:
	return [Vector3(x,y,leading),Vector3(x,y+depth,leading+chord*.24),
		Vector3(x,y+.02,leading+chord),Vector3(x,y-depth*.45,leading+chord*.27)]

func build_trainer():
	var alloy=Color("b7c1c4")
	var orange=Color("d85b32")
	var ink=Color("263943")
	shape(Vector3(0,1.20,0),Vector3(1.38,1.46,7.4))
	shape(Vector3(0,1.08,.14),Vector3(9.8,.23,1.28))
	engine_mesh=loft([fuselage_station(-4.4,1.35,.38,.40),fuselage_station(-3.4,1.33,.67,.60),
		fuselage_station(-1.30,1.33,.81,.79),fuselage_station(.90,1.34,.72,.74),
		fuselage_station(3.9,1.44,.32,.38),fuselage_station(5.16,1.46,.11,.19)],alloy)
	loft([fuselage_station(-2.05,1.85,.32,.12),fuselage_station(-1.02,1.91,.64,.65),
		fuselage_station(.47,1.93,.57,.61),fuselage_station(1.50,1.89,.22,.11)],Color("354e60"))
	loft([fuselage_station(-.31,1.93,.63,.65),fuselage_station(-.21,1.93,.63,.65)],alloy)
	for side in [-1,1]:
		var root_section=wing_section(.35*side,1.01,-1.26,2.64,.23)
		var band=wing_section(4.65*side,1.28,-.72,1.58,.12)
		var tip=wing_section(5.64*side,1.39,-.42,1.0,.07)
		loft([root_section,band],alloy)
		wreck_loss.append(loft([band,tip],orange))
		var marker=part(Vector3(side*5.55,1.43,-.19),Vector3(.15,.14,.22),alloy)
		marker.material_override=world.material(Color("e74b3e") if side<0 else Color("49ce88"),true)
		wreck_loss.append(marker)
		loft([wing_section(.12*side,1.50,3.16,1.55,.12),
			wing_section(side*2.25,1.69,4.03,.83,.06)],alloy)
	# Swept fin and rudder, with a high-visibility cap.
	var fin_base=[Vector3(-.11,1.54,2.92),Vector3(.11,1.54,2.92),Vector3(.11,1.54,5.14),Vector3(-.11,1.54,5.14)]
	var fin_band=[Vector3(-.06,2.99,4.17),Vector3(.06,2.99,4.17),Vector3(.06,2.99,5.06),Vector3(-.06,2.99,5.06)]
	loft([fin_base,fin_band],alloy)
	loft([fin_band,[Vector3(-.04,3.36,4.47),Vector3(.04,3.36,4.47),Vector3(.04,3.36,5.03),Vector3(-.04,3.36,5.03)]],orange)
	loft([fuselage_station(-4.93,1.35,.04,.04),fuselage_station(-4.40,1.35,.39,.39)],orange)
	propeller=Node3D.new()
	visual.add_child(propeller)
	propeller.position=Vector3(0,1.35,-4.43)
	for i in 3:
		var blade=Node3D.new()
		propeller.add_child(blade);blade.rotation.z=i*TAU/3.
		world.box(blade,Vector3(0,.70,0),Vector3(.16,1.03,.06),ink)
		world.box(blade,Vector3(0,1.25,0),Vector3(.15,.12,.06),orange)
	for mount in [Vector3(0,0,-2.9),Vector3(-1.35,0,.55),Vector3(1.35,0,.55)]:
		var gear=Node3D.new();visual.add_child(gear);gear.position=mount
		world.box(gear,Vector3(0,.67,0),Vector3(.09,.82,.09),alloy)
		world.cylinder(gear,Vector3(0,.27,0),.27,.17,ink).rotation.z=PI/2
		flaps.append(gear)

func build_aircraft():
	if not rotorcraft:
		build_trainer()
		return
	var col=Color("374e55")
	shape(Vector3(0,1.0,0),Vector3(2.3,1.95,5.3))
	engine_mesh=loft([ring(.55,.81,2.35,2.35),ring(1.33,1.12,2.84,2.45),ring(2.19,.64,1.65,1.7)],col)
	loft([ring(1.33,1.13,2.86,.38),ring(2.15,.63,1.73,.3)],Color("476676"))
	part(Vector3(0,1.5,4.15),Vector3(.38,.51,4.5),col)
	helix=Node3D.new()
	visual.add_child(helix)
	helix.position.y=2.91
	for angle in [0.,PI/2]:
		world.box(helix,Vector3.ZERO,Vector3(10,.075,.22),Color("333c3c")).rotation.y=angle
	part(Vector3(0,2.48,0),Vector3(.34,.88,.34),col)
	tail_helix=Node3D.new()
	visual.add_child(tail_helix)
	tail_helix.position=Vector3(.26,1.91,6.19)
	for a in [0.,PI/2]:
		world.box(tail_helix,Vector3.ZERO,Vector3(.09,2.1,.17),Color("424b49")).rotation.x=a
	for side in [-1,1]:
		part(Vector3(side*1.12,.2,0),Vector3(.16,.21,4.6),col)
		part(Vector3(side*.99,.45,.45),Vector3(.16,.64,.18),col)
	searchlight=SpotLight3D.new()
	visual.add_child(searchlight)
	searchlight.position=Vector3(0,.54,-1.66)
	searchlight.spot_range=225
	searchlight.spot_angle=17
	searchlight.light_energy=6
func reset_vehicle():
	super()
	wreck=false
	burning=0
	flooded=false
	flood_time=0.
	spike=false;flat_count=0
	air_throttle=0
	for item in fire_objects:
		if is_instance_valid(item):item.queue_free()
	fire_objects.clear()
	for part_mesh in body_parts:
		part_mesh.show()
		if part_mesh.has_meta("initial_mat"):part_mesh.material_override=part_mesh.get_meta("initial_mat")
	if engine_mesh.has_meta("undamaged"):engine_mesh.mesh=engine_mesh.get_meta("undamaged")
	visual.rotation.x=0.
	for tire in rubbers:tire.show()
	for lens in flash_lenses:lens.show()
	if helix:helix.show()
	if tail_helix:tail_helix.show()
	if propeller:
		propeller.show()
		for gear in flaps:gear.show()
	captain_hp=75
	gunner_hp=65
	landing_aid=false
	if seat_bodies.size()==2:
		seat_bodies[0].position=Vector3(-.49,1.58,.8)
		for s in seat_bodies:s.rotation=Vector3.ZERO
	for s in seat_bodies:
		s.show()
		s.collision_layer=8
func take_damage(amount:float):
	if wreck:return
	health=maxf(0,health-amount)
	if police and world.started and world.ops:world.ops.investigate(position)
	if health<=12 and burning<=0:
		world.ops.audio.effect("pressure",position,-4)
		burning=7.
		if occupied:world.ops.message("Engine fire · exit vehicle",3)
func puncture(index:int=-1):
	if boat or aircraft:return
	if index<0:
		for i in rubbers.size():puncture(i)
		return
	if not rubbers[index].visible:return
	rubbers[index].hide();flat_count+=1
	if not spike:
		world.ops.audio.effect("air",position,1)
		if occupied:world.ops.message("Tire punctured · running on rim",4)
	spike=true
func _effects(dt):
	if health<53 and not wreck and not flooded:
		if fire_objects.is_empty():
			fire_objects.append(world.ops.fx.plume(visual,Vector3(0,1.05,-1.2),false))
	if burning>0:
		burning=maxf(0,burning-dt)
		while fire_objects.size()<1+ceili((7.1-burning)*.6):
			var i=fire_objects.size()
			fire_objects.append(world.ops.fx.plume(visual,Vector3(sin(i*4)*.6,1,cos(i*2)*1.4),true))
		if engine_mesh and sin(world.clock*(7+(7-burning)*2))>.1:
			engine_mesh.material_override=world.material(Color("ed4e34"),true)
		elif engine_mesh and engine_mesh.has_meta("initial_mat"):engine_mesh.material_override=engine_mesh.get_meta("initial_mat")
		if burning<=0 and (not aircraft or position.y<4 or is_on_floor()):detonate()
		elif burning<=0:burning=.03
func detonate():
	if wreck:return
	wreck=true
	health=0
	burning=0
	velocity=Vector3.ZERO
	speed=0
	for puff in fire_objects:
		if is_instance_valid(puff):puff.queue_free()
	fire_objects.clear()
	for part_mesh in body_parts:
		if not part_mesh.has_meta("initial_mat"):part_mesh.set_meta("initial_mat",part_mesh.material_override)
		part_mesh.material_override=world.material(Color("272b2a"))
	for detail in wreck_loss:detail.hide()
	for i in rubbers.size():
		if i%2==0:rubbers[i].hide()
	for s in seat_bodies:
		s.hide()
		s.collision_layer=0
	if helix:helix.hide()
	if tail_helix:tail_helix.hide()
	if propeller:propeller.hide()
	for lens in flash_lenses:lens.hide()
	for member in crew:
		if member.boarded:member.hp=0
	if occupied:
		world.player.reset_player(position+global_basis.x*2.3)
	world.ops.fx.blast(position+Vector3.UP,self)
func _physics_process(dt):
	if not world.started:return
	if not engine_mesh.has_meta("initial_mat"):engine_mesh.set_meta("initial_mat",engine_mesh.material_override)
	if door:door.rotation.y=move_toward(door.rotation.y,-door_open*1.12,dt*3.4)
	_effects(dt)
	if wreck or flooded:
		if flooded:
			flood_time+=dt
			position.y=maxf(-11.2,position.y-dt*1.6)
			visual.rotation.x=move_toward(visual.rotation.x,-.24,dt*.12)
			if occupied and flood_time>=1.:
				var exit_at=position+Vector3.UP*2.15
				for side in [-1.,1.]:
					var at=position+global_basis.x*side*2.1+Vector3.UP*.55
					var ray=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.55,at+global_basis.x*side*.45,3,[get_rid()])
					if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
						exit_at=at
						break
				var heading=world.player.yaw
				world.player.reset_player(exit_at)
				world.player.yaw=heading
		if searchlight:searchlight.hide()
		for light in headlights:light.hide()
		return
	if aircraft:
		_fly(dt)
		_lights()
		return
	if boat and seat_bodies.size()==2 and gunner_hp<=0 and captain_hp>0 and not occupied:
		landing_aid=world.clock<threat_until
		var post=Vector3(.38,.66,2.05) if landing_aid else Vector3(-.49,1.58,.8)
		seat_bodies[0].position=seat_bodies[0].position.move_toward(post,dt*1.25)
		seat_bodies[0].rotation.x=move_toward(seat_bodies[0].rotation.x,-.45 if landing_aid else 0.,dt)
	var throttle=0.
	var turn=0.
	var brake=false
	var pedal=false
	var active_police=police and world.chase and not occupied and world.ops.dispatched(self)
	if occupied:
		throttle=clampf(Input.get_axis("back","forward")-world.player.analog.y,-1,1)
		turn=clampf(Input.get_axis("right","left")-world.player.analog.x,-1,1)
		brake=not boat and Input.is_action_pressed("handbrake")
		pedal=world.player.mobile_brake
		if driver:driver.visible=not world.player.leaning()
	elif active_police or driving_npc:
		responding=active_police
		var goal=world.ops.drive_goal(self) if active_police else world.ops.traffic_goal(self)
		var offset=goal-position
		offset.y=0
		var delta_angle=wrapf(atan2(-offset.x,-offset.z)-rotation.y,-PI,PI)
		turn=clampf(delta_angle*1.65,-1.,1.)
		var cruise=max_speed if active_police else (max_speed*.87 if threat_until>world.clock else 12.4+slot*1.5)
		var desired=minf(cruise,lerpf(cruise,4.0,smoothstep(.12,1.25,absf(delta_angle))))
		if (active_police and (boat or not world.player.vehicle or world.player.vehicle.speed<2)) or driving_npc:
			desired=minf(desired,sqrt(maxf(0.,offset.length()-2.2)*12.))
		if offset.length()<3.6 or (active_police and not boat and crew.any(func(n):return n.hp>0 and not n.boarded)):
			desired=0
		if boat and police and (captain_hp<=0 or landing_aid):desired=0
		if driving_npc and junction_id>=0 and not entered_junction and not traffic_route.is_empty():
			var dst=traffic_route[0]
			var left=(dst-position).dot((dst-lane_origin).normalized())-14.
			var phase=fposmod(world.clock+junction_id%7+(12 if junction_kind==3 else 0),24.)
			var must_wait=junction_kind>=2 and phase>=9.
			if junction_kind==1:
				if left<1.8 and speed<.6 and stopped_since<0:stopped_since=world.clock
				must_wait=stopped_since<0 or world.clock-stopped_since<1.1
				if not must_wait and left<5.:
					for cross_car in world.ops.traffic:
						if cross_car!=self and cross_car.speed>2. and cross_car.position.distance_to(dst)<16.:
							must_wait=true;break
			if left>=0 and left<8 and not must_wait:
				var lane=(dst-lane_origin).normalized()
				for other in world.ops.traffic:
					if other==self or other.speed>2. or other.global_basis.z.dot(global_basis.z)<.7:continue
					var beyond=other.position-dst
					if beyond.dot(lane)>0 and beyond.dot(lane)<9 and absf(beyond.dot(lane.cross(Vector3.UP))-world.atlas.lane_center(lane_width,traffic_lane))<2.:
						must_wait=true;break
			if left<.5 and not must_wait:entered_junction=true
			if must_wait:desired=minf(desired,sqrt(maxf(0.,left)*9.))
		if driver_yield and world.ops.lock_target==self and world.player.position.distance_to(position)<3.:desired=0
		if world.clock>=next_scan:
			next_scan=world.clock+.16
			_obstacle(active_police)
		if avoid_throttle<.2:desired=minf(desired,sqrt(maxf(0.,obstacle_distance-following_gap)*12.))
		if pass_until>world.clock:desired=minf(desired,10.)
		pass_offset=move_toward(pass_offset,pass_side if pass_until>world.clock else 0.,dt*2.8)
		turn=clampf(turn+avoid_turn,-1.,1.)
		throttle=desired/max_speed
		pedal=speed>desired+1.8
		if driver:driver.visible=driving_npc or (police and crew.any(func(n):return n.boarded and n.hp>0))
	else:
		responding=false
		pedal=true
		if driver:driver.visible=police and crew.any(func(n):return n.boarded and n.hp>0)
	steer=move_toward(steer,turn,dt*(4.9 if not boat else 1.9))
	var forward=-global_basis.z
	var along=velocity.dot(forward)
	var vertical=velocity.y
	var lateral=Vector3(velocity.x,0,velocity.z)-forward*along
	var effective=max_speed*(maxf(.28,1.-flat_count*.23) if spike else 1.)
	var desired_speed=throttle*effective if throttle>=0 else throttle*effective*.22
	var rate=acceleration if throttle!=0 else 1.6
	if pedal:desired_speed=0;rate=15.
	if brake and not pedal:
		desired_speed*=.88
		rate*=.82 if throttle!=0 else 1.25
	along=move_toward(along,desired_speed,dt*rate)
	if boat:rotation.y+=steer*.63*clampf(along/6.,-1.,1.)*dt
	else:
		var steering_angle=lerpf(31.0 if model!="striped" else 35.0,7.6,smoothstep(7.,36.,absf(along)))
		var curvature=steer*tan(deg_to_rad(steering_angle))/axle_span
		rotation.y+=along*curvature*dt*(1.45 if brake else 1.)
		for i in wheel_pivots.size():
			var pivot=wheel_pivots[i]
			pivot.rotation.y=atan2(axle_span*curvature,1.+pivot.position.x*curvature) if pivot.position.z<0 else 0.
			wheel_rolls[i].rotate_x(-along*(1.+pivot.position.x*curvature)*dt/.36)
	# Tires redirect longitudinal velocity. Only a braked rear axle retains
	# appreciable side-slip, giving ordinary cars grip around intersections.
	var new_f=-global_basis.z
	if brake:lateral+=(forward-new_f)*along
	var grip=2.5 if boat else (1.5 if brake else 12.)
	lateral*=exp(-grip*dt)
	velocity=new_f*along+lateral
	if boat:
		velocity.y=(world.wave_height(position.x,position.z)+.06-position.y)*4.
	else:
		var ride_height=wheel_ground()
		tires_grounded=is_finite(ride_height) and position.y-ride_height<.55
		if tires_grounded:
			# Support the tires independently of the bumper and cabin. A chassis
			# riding directly on its collision margin can catch a flat deck seam.
			position.y=ride_height+.018
			velocity.y=0.
		else:velocity.y=vertical-24.*dt
	if boat:
		visual.rotation.x=lerpf(visual.rotation.x,(world.wave_height(position.x,position.z-3)-world.wave_height(position.x,position.z+3))/6,dt*4)
		visual.rotation.z=lerpf(visual.rotation.z,(world.wave_height(position.x-1,position.z)-world.wave_height(position.x+1,position.z))/2,dt*4)
	if not boat:collision_mask=7 if not occupied else 3
	var incoming=velocity
	move_and_slide()
	var ground_only=is_on_floor()
	for i in get_slide_collision_count():
		var hit=get_slide_collision(i)
		if hit.get_normal().y<.72:ground_only=false
		var impulse=-incoming.dot(hit.get_normal())
		if hit.get_collider()==world.player and impulse>4.5 and world.clock>=world.player.traffic_hit_at:
			world.player.traffic_hit_at=world.clock+1.
			world.ops.hurt(minf(90.,(impulse-4.)*3.2))
		var obstacle=hit.get_collider()
		if obstacle.has_method("knock_down") and impulse>3. and not obstacle.fallen:
			obstacle.knock_down(incoming)
			velocity=incoming*.86
			world.ops.audio.effect("crash",hit.get_position(),-12.)
			continue
		if world.clock>damage_cooldown and impulse>5.5 and absf(hit.get_normal().y)<.67:
			damage_cooldown=world.clock+.65
			velocity+=hit.get_normal()*minf(4.,impulse*.20)
			dent(hit.get_position(),hit.get_normal(),impulse)
			world.ops.fx.crash(hit.get_position(),hit.get_normal(),impulse,obstacle.has_meta("masonry"))
			world.ops.audio.effect("crash",hit.get_position(),clampf(-15.+impulse*.40,-13.,-3.))
			if impulse<=10.:continue
			take_damage((impulse-10)*1.35)
			damage_cooldown=world.clock+.85
			if hit.get_collider().has_method("take_damage"):hit.get_collider().take_damage((impulse-9)*.9)
	if ground_only and not boat:
		velocity.x=incoming.x;velocity.z=incoming.z
	speed=Vector2(velocity.x,velocity.z).length()
	if not boat and position.y+.9<world.wave_height(position.x,position.z):
		flooded=true
		speed=0.
		velocity=Vector3.ZERO
	if occupied and brake and absf(steer)*speed>2 and tires_grounded and world.clock>skid_at and not spike:
		skid_at=world.clock+.085
		world.ops.fx.skid(self,clampf((absf(steer)*speed)/15,.25,1.))
	elif not brake:skid_prev.clear()
	if (spike or boat) and speed>3 and world.clock>skid_at and position.distance_squared_to(world.player.position)<40000:
		skid_at=world.clock+.2
		if boat:world.ops.fx.wake(position+global_basis.z*4)
		elif tires_grounded:
			for i in rubbers.size():
				if not rubbers[i].visible:world.ops.fx.rim_sparks(wheel_pivots[i].global_position+Vector3.DOWN*.31,velocity)
	_lights()
func dent(contact:Vector3,normal:Vector3,intensity:float):
	if boat or aircraft:return
	if not engine_mesh.has_meta("undamaged"):engine_mesh.set_meta("undamaged",engine_mesh.mesh)
	var arrays=engine_mesh.mesh.surface_get_arrays(0)
	var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var inward=global_basis.inverse()*normal
	var local=to_local(contact)
	for i in points.size():
		var influence=1.-smoothstep(.4,2.,points[i].distance_to(local))
		points[i]+=inward*minf(.26,intensity*.012)*influence
	arrays[Mesh.ARRAY_VERTEX]=points
	var dented=ArrayMesh.new()
	dented.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	engine_mesh.mesh=dented
func wheel_ground()->float:
	var height=-INF
	var space=get_world_3d().direct_space_state
	for axle in [-1.55,1.55]:
		var at=position+global_basis.z*axle
		var q=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.5,at-Vector3.UP*.9,1)
		var hit=space.intersect_ray(q)
		if not hit.is_empty() and hit.normal.y>.76:height=maxf(height,hit.position.y)
	return height
func _obstacle(pursuit):
	var start=position+Vector3.UP*.83
	var forward=-global_basis.z
	var side=global_basis.x
	avoid_throttle=1.
	avoid_turn=0.
	obstacle_distance=100.
	var obstruction
	for width in [0.,-.82,.82]:
		var ray=PhysicsRayQueryParameters3D.create(start+side*width,start+side*width+forward*maxf(20.,10.+speed*.55+speed*speed/22.),15,[get_rid()])
		var hit=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and start.distance_to(hit.position)<obstacle_distance:
			obstruction=hit.collider;obstacle_distance=start.distance_to(hit.position)
	if not obstruction:
		blocked_since=-1.
		return
	if blocked_since<0:blocked_since=world.clock
	var person=obstruction==world.player or obstruction.collision_layer==8
	following_gap=10. if person or (obstruction.has_method("puncture") and obstruction.speed<1.) else 5.
	var near_junction=not traffic_route.is_empty() and position.distance_to(traffic_route[0])<16.
	if person or (obstruction.has_method("puncture") and (near_junction or world.clock-blocked_since<1.2)):
		avoid_throttle=0.
		if driving_npc and person and world.clock-horn_at>12 and (speed>6 or world.clock-blocked_since>1.):
			world.ops.audio.effect("horn",position,-10);horn_at=world.clock
		if near_junction or world.clock-blocked_since<1.4:return
	if pursuit and obstruction==world.player.vehicle and world.player.vehicle!=null and world.player.vehicle.speed>3:return
	if obstruction.has_method("puncture"):
		var along=obstruction.velocity.dot(forward)
		if along>2.5 and obstruction.global_basis.z.dot(global_basis.z)>.6:
			avoid_throttle=0. if obstacle_distance<maxf(4.,speed*.55) else 1.
			return
	if pass_until>world.clock:
		if person and not near_junction and obstacle_distance>2.4:avoid_throttle=1.
		if pursuit or boat:avoid_turn=-signf(pass_side)*.64
		if obstacle_distance<2.:avoid_throttle=0.
		return
	if driving_npc and near_junction:return
	var choices=[-1.,1.]
	var step=4.05 if not boat else 5.7
	if driving_npc and lane_width>=16.:
		choices=[1. if traffic_lane==0 else -1.]
		step=lane_width*.25
	for choice in choices:
		var off=side*choice*step
		var corridor=start+off
		var blocked=false
		for margin in [-.85,.85]:
			var origin=corridor+side*margin
			var q=PhysicsRayQueryParameters3D.create(origin-forward*5.,origin+forward*maxf(28.,speed*2.6),15,[get_rid()])
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():blocked=true;break
		if blocked:continue
		if person and obstacle_distance>2.4:avoid_throttle=1.
		pass_side=choice*step
		pass_until=world.clock+3.4
		if pursuit or boat:avoid_turn=-choice*.7
		return
	avoid_throttle=0
	if driving_npc and world.clock-horn_at>16 and position.distance_to(world.player.position)<24:
		world.ops.audio.effect("horn",position,-14);horn_at=world.clock
func _lights():
	for light in headlights:light.visible=world.night and not wreck and (occupied or responding or driving_npc) and position.distance_squared_to(world.player.position)<19600
	for i in flash_lenses.size():
		var lit=world.chase and world.ops.dispatched(self) and ((fmod(world.clock+slot*.12,.62)<.31)==(i==0))
		flash_lenses[i].material_override=world.material((Color("fa2446") if i==0 else Color("1589ff")) if lit else Color("415463"),lit)
	if searchlight:
		searchlight.visible=world.night and world.chase and not occupied and not wreck
		var at=world.ops.last_fix+Vector3(sin(world.clock*.76)*6,.8,cos(world.clock*.6)*4)
		if at.distance_to(searchlight.global_position)>1.:searchlight.look_at(at)
func _fly(dt):
	var p=world.player
	var vy=velocity.y
	if burning>0:
		rotation.y+=dt*(1.1+(7-burning)*.57)
		visual.rotation.z=sin(world.clock*2)*.42+.34
		velocity.y=maxf(-27,vy-8*dt)
	elif occupied:
		if rotorcraft:
			var vec=p.movement_input()
			rotation.y=lerp_angle(rotation.y,p.yaw,dt*1.9)
			var desired=global_basis*Vector3(vec.x,0,vec.y)*max_speed
			velocity=velocity.move_toward(desired+Vector3.UP*(Input.get_action_strength("interact")-Input.get_action_strength("lean"))*12,dt*acceleration)
		else:
			air_throttle=clampf(air_throttle+-p.movement_input().y*dt*.28,0,1)
			rotation.y+=-p.movement_input().x*dt*.65
			rotation.y=lerp_angle(rotation.y,p.yaw,dt*.4)
			var tilt=clampf(p.pitch,-.7,.6)
			var f=-global_basis.z
			var horizontal=move_toward(speed,max_speed*air_throttle,dt*acceleration)
			velocity=f*horizontal
			velocity.y=lerpf(vy,(sin(tilt)*horizontal if horizontal>23 else -5.),dt*1.8)
			visual.rotation.x=tilt
			visual.rotation.z=lerpf(visual.rotation.z,-p.movement_input().x*.35,dt*2)
			gear_extended=position.y<15.
			for wheel in flaps:wheel.visible=gear_extended
	elif model=="spotter" and world.chase:
		var focus=world.ops.last_fix
		var angle=world.clock*.13
		var orbit=focus+Vector3(cos(angle)*69,85+sin(angle*.4)*9,sin(angle)*69)
		velocity=velocity.move_toward((orbit-position).limit_length(max_speed),dt*9.)
		if velocity.length()>1:rotation.y=lerp_angle(rotation.y,atan2(-velocity.x,-velocity.z),dt*1.5)
	else:
		velocity=velocity.move_toward(Vector3(0,-2.3,0),dt*5)
	move_and_slide()
	if burning>0 and (get_slide_collision_count()>0 or position.y<.7):detonate()
	speed=Vector2(velocity.x,velocity.z).length()
	if propeller and occupied and not wreck:propeller.rotation.z+=dt*(19.+air_throttle*51.)
	if helix and not wreck:
		var multiplier=1. if occupied or model=="spotter" else .0
		helix.rotation.y+=dt*34*multiplier
		tail_helix.rotation.x+=dt*54*multiplier
