extends CharacterBody3D
var world
var role="civilian"
var home=Vector3.ZERO
var route=PackedVector3Array()
var index=0
var hp=66.
var frightened=0.
var danger=Vector3.ZERO
var follow=false
var riding=false
var rider_car
var legs=[]
var light
var since=0.
var aim=0.
var last_report=-99.
var next_choice=0.
var last_fire=0.
var path=PackedVector3Array()
var active=true
var upper=Node3D.new()
var last_impact=-10.
var notice_at=0.
var refuge=Vector3.INF
func configure(w,kind:String,points:PackedVector3Array,color:Color):
	world=w
	role=kind
	route=points
	position=points[0]
	home=position
	collision_layer=8
	collision_mask=1|2
	floor_snap_length=.5
	var cap=CollisionShape3D.new()
	var sh=CapsuleShape3D.new()
	sh.radius=.29
	sh.height=1.75
	cap.position.y=.88
	cap.shape=sh
	add_child(cap)
	add_child(upper)
	var jacket=world.box(upper,Vector3(0,1.06,0),Vector3(.43,.55,.26),color)
	var head=world.cylinder(upper,Vector3(0,1.55,0),.145,.30,Color(["b78d72","d4ac8a","916c59"][get_instance_id()%3]))
	head.mesh.radial_segments=8
	for side in [-1,1]:
		var leg=Node3D.new()
		add_child(leg);leg.position=Vector3(side*.12,.84,0)
		world.box(leg,Vector3(0,-.37,0),Vector3(.16,.69,.20),Color("3e474a"))
		world.box(leg,Vector3(0,-.77,-.05),Vector3(.19,.12,.31),Color("393b38"))
		legs.append(leg)
		world.box(upper,Vector3(side*.285,1.03,0),Vector3(.14,.50,.17),color)
	if role in ["guard","soldier","hostile"]:
		world.box(upper,Vector3(0,1.73,-.025),Vector3(.34,.09,.36),color.darkened(.32))
		light=SpotLight3D.new()
		add_child(light)
		light.position=Vector3(.25,1.2,-.25)
		light.spot_angle=19
		light.spot_range=35
		light.light_energy=1.5
	else:
		world.box(upper,Vector3(0,1.72,.015),Vector3(.285,.11,.27),Color("51443b"))
func receive_punch():
	if hp<=0:return
	danger=world.player.position
	frightened=world.clock+8.
	world.ops.incident(position,1 if role=="civilian" else 2)
	upper.rotation.x=.17
	upper.create_tween().tween_property(upper,"rotation:x",0.,.23)
	apply_injury(16.)

func take_damage(amount,_by_player=true):
	if hp<=0:return
	world.ops.investigate(position)
	if role=="civilian":world.ops.incident(position,3)
	apply_injury(amount)

func apply_injury(amount):
	hp=maxf(0.,hp-amount)
	if hp<=0:
		collision_layer=0
		rotation.z=PI/2
		position.y+=.23
		if light:light.hide()
func hide_in_car(v):
	riding=true
	rider_car=v
	collision_layer=0
	hide()
func disembark(v):
	riding=false
	rider_car=null
	position=v.position+v.global_basis.x*2.3+Vector3.UP*.16
	collision_layer=8
	show()
func _physics_process(dt):
	if not world.started or not active or hp<=0:return
	var p=world.player
	if riding:
		if not is_instance_valid(rider_car):riding=false;show();return
		position=rider_car.position
		if not p.vehicle:disembark(rider_car)
		return
	var distance=position.distance_to(p.position)
	if p.vehicle and not p.vehicle.boat and not p.vehicle.aircraft and p.vehicle.speed>4 and distance<4.5 and world.clock-last_impact>1.2:
		var contact=p.vehicle.to_local(position+Vector3.UP*.52)
		if absf(contact.x)<1.25 and absf(contact.z)<2.55 and contact.y>0 and contact.y<1.7:
			last_impact=world.clock
			take_damage(p.vehicle.speed*3.2)
			frightened=world.clock+12.;danger=p.position
			if hp<=0:return
	var guard=role in ["guard","soldier","hostile"]
	if distance>210 and not follow:
		if light:light.hide()
		return
	var target=route[index]
	var speed=1.5
	if role=="civilian" and not follow and world.clock>=notice_at:
		notice_at=world.clock+.65+(get_instance_id()%7)*.04
		if world.ops.armed and (not p.vehicle or p.leaning()) and distance<30 and (distance<8 or (p.position-position).normalized().dot(-global_basis.z)>-.15):
			if world.ops.sees_player(position+Vector3.UP*1.55,[get_rid()]):
				danger=p.position
				frightened=world.clock+6.
				refuge=world.ops.shelter(self,danger)
	if guard:
		var direction=p.position-position
		var looking=direction.normalized().dot(-global_basis.z)>.29
		var sees=distance<(38 if world.night and not world.ops.armed else 68) and (looking or distance<9 or world.ops.wanted>1) and world.ops.sees_player(position+Vector3.UP*1.5,[get_rid()])
		var intrusion=role=="hostile" or (role=="guard" and p.position.z>657 and p.position.z<875 and absf(p.position.x+412)<98) or (role=="soldier" and p.position.x>600 and p.position.z>255 and p.position.z<500)
		if light:light.visible=world.night and distance<110
		if role=="guard" and world.ops.campaign.lockdown and not sees:
			var stations=[world.atlas.marks["Custody gate"]+Vector3(0,0,9),world.atlas.marks["Cellblock B"]-Vector3(0,0,7),Vector3(-425,2.65,744)]
			target=stations[get_instance_id()%stations.size()];speed=3.4
			if position.distance_to(target)<3:target=position
		if intrusion and sees:
			aim+=dt
			if aim>.7:
				world.ops.alert(p.position,3)
				if role=="guard":world.ops.campaign.lockdown=true
				speed=3.8
				target=p.position if distance>18 else position
				rotation.y=atan2(-direction.x,-direction.z)
				if world.clock>last_fire and world.ops.allow_guard_shot():
					var end=p.position+Vector3.UP*1.1+p.velocity*clampf(distance/155.,.06,.28)
					world.ops.officer_shot(self,position+Vector3.UP*1.4,end)
					last_fire=world.clock+(.69 if role=="soldier" else .93)
		else:aim=maxf(0,aim-dt*1.8)
	elif follow:
		speed=6.5 if distance>6 else 3.4
		target=p.position+p.global_basis.z*1.3 if distance>2.1 else position
		if p.vehicle and distance<8:
			hide_in_car(p.vehicle)
			return
	elif frightened>world.clock:
		var away=(position-danger).normalized()
		target=refuge if refuge!=Vector3.INF else position+Vector3(away.x,0,away.z)*16
		speed=4.9
	elif p.vehicle and p.vehicle.speed>7 and distance<16:
		frightened=world.clock+5
		danger=p.position-p.vehicle.global_basis.z*2
	if frightened<=world.clock:refuge=Vector3.INF
	if not follow and target==route[index] and position.distance_to(target)<2.3:index=(index+1)%route.size()
	var motion=target-position
	motion.y=0
	if motion.length()>.55:
		motion=motion.normalized()
		if world.clock>=next_choice:
			next_choice=world.clock+.38
			var ray=PhysicsRayQueryParameters3D.create(position+Vector3.UP,position+Vector3.UP+motion*2.8,3)
			var hit=get_world_3d().direct_space_state.intersect_ray(ray)
			path.clear()
			if not hit.is_empty():
				var side=Vector3(-motion.z,0,motion.x)
				if follow and world.ops.routes_ready:path=world.ops.foot_path(position,target)
				if path.is_empty():path.append(position+side*(3 if get_instance_id()%2 else -3)+motion*.5)
		if path.size():
			while path.size()>1 and position.distance_to(path[0])<1.3:path.remove_at(0)
			motion=(path[0]-position);motion.y=0;motion=motion.normalized()
		velocity.x=motion.x*speed;velocity.z=motion.z*speed
		if not guard or aim<.7:rotation.y=lerp_angle(rotation.y,atan2(-motion.x,-motion.z),minf(1,dt*7))
	else:velocity.x=0;velocity.z=0
	velocity.y=-1 if is_on_floor() else velocity.y-dt*24
	var before=position
	move_and_slide()
	since+=position.distance_to(before)*4.5
	for i in legs.size():legs[i].rotation.x=sin(since+i*PI)*.47
