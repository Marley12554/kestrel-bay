extends CharacterBody3D

var world: Node3D
var ops: Node3D
var cruiser: CharacterBody3D
var seat = 0
var hp = 80.0
var boarded = true
var path = PackedVector3Array()
var route_at = -100.0
var seen_at = -100.0
var aim_time = 0.0
var shot_at = 0.0
var burst = 0
var reload_until = 0.0
var torso: Node3D
var flashlight: SpotLight3D
var weapon: Node3D
var walking = 0.0
var role = "approach"

func configure(owner_world: Node3D, director: Node3D, car: CharacterBody3D, index: int) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	world = owner_world
	ops = director
	cruiser = car
	seat = index
	collision_layer = 8
	collision_mask = 1|2|4|8
	floor_snap_length = .4
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = .9
	add_child(shape)
	torso = Node3D.new()
	add_child(torso)
	world.box(torso,Vector3(0,1.03,0),Vector3(.53,.66,.3),Color("253d59"))
	world.box(torso,Vector3(0,1.55,0),Vector3(.31,.35,.29),Color("cba17d"))
	world.box(torso,Vector3(0,1.76,0),Vector3(.37,.1,.35),Color("162c46"))
	for side in [-1,1]:
		world.box(torso,Vector3(side*.15,.4,0),Vector3(.21,.8,.25),Color("192a3c"))
		world.box(torso,Vector3(side*.32,1.0,-.1),Vector3(.15,.5,.18),Color("253d59"))
	world.box(torso,Vector3(-.14,1.15,-.17),Vector3(.09,.12,.025),Color("e3bf75"))
	weapon = Node3D.new()
	torso.add_child(weapon)
	world.box(weapon,Vector3(.25,1.14,-.45),Vector3(.10,.12,.35),Color("172028"))
	flashlight = SpotLight3D.new()
	torso.add_child(flashlight)
	flashlight.position = Vector3(.25,1.14,-.5)
	flashlight.spot_range = 32
	flashlight.spot_angle = 22
	flashlight.light_energy = 1.1
	flashlight.shadow_enabled = false
	set_boarded(true)

func set_boarded(value: bool) -> void:
	boarded = value
	visible = not boarded and hp>0
	collision_layer = 0 if boarded or hp<=0 else 8
	collision_mask = 0 if boarded or hp<=0 else 1|2|4|8
	if value:
		velocity = Vector3.ZERO

func deploy() -> bool:
	if hp<=0 or not boarded:
		return false
	for side in [-1,1]:
		var at = cruiser.position+cruiser.global_basis.x*(1.65*side)+cruiser.global_basis.z*(seat*1.4-.7)
		if ops.walk_clear(at):
			position = at
			set_boarded(false)
			aim_time = 0
			return true
	return false

func take_damage(amount: float) -> void:
	if hp<=0:
		return
	hp -= amount
	ops.alert(position,3)
	if hp<=0:
		collision_layer = 0
		collision_mask = 0
		torso.rotation.z = PI/2
		torso.position.y = -.5
		flashlight.visible = false
		if world.diagnostics_enabled() and not ops.has_method("interior_step"):ops.message("Officer down")

func _physics_process(dt: float) -> void:
	if not world.started or hp<=0:
		return
	if boarded:
		position = cruiser.position
		return
	var p = world.player
	var distance = position.distance_to(p.position)
	var visible_target = distance<58 and ops.sees_player(position+Vector3.UP*1.6,[get_rid()]) and not p.submerged
	flashlight.visible = world.night and world.chase
	weapon.visible = world.chase
	if visible_target and world.chase:
		seen_at = world.clock
		ops.observe(p.position)
		var facing = p.position-position
		if facing.length()>.1:
			rotation.y = lerp_angle(rotation.y,atan2(-facing.x,-facing.z),minf(1,dt*8))
	if not world.chase:
		if position.distance_to(cruiser.position)<3:
			set_boarded(true)
		else:
			_move_to(cruiser.position,dt,3.2)
		return
	if p.vehicle and ops.has_method("vehicle_door") and p.vehicle.speed<2.5 and not p.vehicle.boat and visible_target and distance<25:
		var door=ops.vehicle_door(self,p.vehicle)
		if door!=Vector3.INF:
			role="extract"
			if position.distance_to(door)>1.3:
				var local=p.vehicle.to_local(position)
				var door_local=p.vehicle.to_local(door)
				if local.x*door_local.x<0 and absf(local.z)<3.1:
					door=p.vehicle.to_global(Vector3(local.x,0,3.25 if local.z>0 else -3.25))
				_move_to(door,dt,4.6)
			else:
				velocity=Vector3.ZERO
				ops.door_contact_at=world.clock
				ops.extract_timer+=dt
				if ops.extract_timer>=1.75:
					p.interact()
					ops.extract_timer=0.
			return
	if not ops.has_method("vehicle_door") and p.vehicle and p.vehicle.speed<2 and distance<3.3:
		role = "extract"
		ops.extract_timer += dt
		if ops.extract_timer>2:
			p.interact()
			ops.extract_timer = 0
		return
	if p.vehicle and distance>32 and cruiser.health>0:
		role = "reboard"
		if position.distance_to(cruiser.position)<3:
			set_boarded(true)
		else:
			_move_to(cruiser.position,dt,4.2)
		return
	var target = ops.last_fix
	role = "flank" if seat==1 else "approach"
	if visible_target:
		if distance<6:
			target = position
		elif seat==1 and distance>12 and p.position.y<5:
			target += Vector3(6 if cruiser.slot==0 else -6,0,2)
		if ops.wanted>=2 and distance<48:
			aim_time += dt
			if aim_time>.8 and world.clock>shot_at and world.clock>reload_until and ops.shooter_slot(self):
				var target_eye = p.position+Vector3.UP*1.2
				var spread = .12+distance*.009
				target_eye += Vector3(sin(world.clock*7+seat)*spread,cos(world.clock*4)*spread*.4,0)
				ops.officer_shot(self,position+Vector3.UP*1.3,target_eye)
				burst += 1
				shot_at = world.clock+.25
				if burst>=2:
					burst = 0
					reload_until = world.clock+1.65
			if distance<18 and seat==0 and p.position.y<5:
				role = "cover"
				target = ops.cover_point(self,p.position)
	else:
		aim_time = 0
	_move_to(target,dt,4.5 if visible_target else 3.8)
	if visible_target and ops.wanted==1 and distance<1.7:
		ops.arrest += dt*.45

func _move_to(target: Vector3,dt: float,speed: float) -> void:
	var transit=ops.interior_step(self,target) if ops.has_method("interior_step") else Vector3.INF
	if transit!=Vector3.INF:
		path=PackedVector3Array([transit])
	elif world.clock-route_at>.9 and not (position.x>-67 and position.x<-62 and position.z>28 and position.z<48 and position.y>2.9 and position.y<6.6):
		path = ops.foot_path(position,target)
		route_at = world.clock
	while path.size()>1 and position.distance_to(path[0])<.9:
		path.remove_at(0)
	var next = path[0] if not path.is_empty() else target
	var direction = next-position
	direction.y = 0
	if direction.length()>.5:
		direction = direction.normalized()
		velocity.x = direction.x*speed
		velocity.z = direction.z*speed
		if world.clock-seen_at>.2:
			rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),dt*6)
	else:
		velocity.x = move_toward(velocity.x,0,dt*12)
		velocity.z = move_toward(velocity.z,0,dt*12)
	velocity.y = -1 if is_on_floor() else velocity.y-24*dt
	if is_on_floor() and position.y>6.4 and position.y<7.25 and absf(position.x+59)<2 and absf(position.z-25)<1.5:
		velocity.y = 5.2
	move_and_slide()
	for i in get_slide_collision_count():
		var body = get_slide_collision(i).get_collider()
		if body and body.has_meta("target"):
			var passage = body.get_meta("target")
			if passage.kind=="door":
				if passage.locked:
					passage.take_damage(dt*30,false)
				else:
					passage.opened = true
			elif passage.kind=="window" and not passage.broken:
				passage.take_damage(dt*35,false)
	walking += Vector2(velocity.x,velocity.z).length()*dt
	torso.position.y = sin(walking*6)*.025
