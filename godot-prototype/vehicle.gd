extends CharacterBody3D

var world: Node3D
var crew: Array = []
var health = 100.0
var damage_cooldown = 0.0
var searchlight: SpotLight3D
var boat = false
var police = false
var occupied = false
var responding = false
var max_speed = 28.0
var acceleration = 7.0
var speed = 0.0
var steer = 0.0
var spawn_point = Vector3.ZERO
var home_heading = 0.0
var slot = 0
var visual: Node3D
var camera_distance = 10.5
var headlights: Array = []
var flash_lenses: Array = []
var patrol_goal = Vector3.ZERO
var helm = Vector3.ZERO

func configure(owner_world: Node3D, at: Vector3, is_boat: bool, is_police: bool, index: int) -> void:
	world = owner_world
	boat = is_boat
	police = is_police
	slot = index
	position = at
	if police and not boat:
		max_speed = 32.2
	spawn_point = at
	if boat:
		max_speed = 19.0
		acceleration = 4.5
		camera_distance = 14.0
	add_to_group("vehicles")
	collision_layer = 2
	collision_mask = 3
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING if boat else CharacterBody3D.MOTION_MODE_GROUNDED
	safe_margin = 0.025
	max_slides = 8
	visual = Node3D.new()
	add_child(visual)
	if boat:
		build_boat()
	else:
		build_car()
	patrol_goal = at
	home_heading = rotation.y

func shape(at: Vector3, size: Vector3) -> void:
	var collider = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collider.shape = box_shape
	collider.position = at
	add_child(collider)

func build_car() -> void:
	shape(Vector3(0, 0.82, 0), Vector3(1.95, 1.6, 4.65))
	var color = Color("244651") if not police else Color("e0e0d5")
	world.box(visual, Vector3(0,.68,0), Vector3(1.92,.75,4.55), color)
	world.box(visual, Vector3(0,1.24,.05), Vector3(1.64,.7,2.2), Color("1d303b"))
	world.box(visual, Vector3(0,1.63,.08), Vector3(1.7,.12,2.28), color)
	for x in [-.97,.97]:
		for z in [-1.42,1.45]:
			var wheel = world.cylinder(visual, Vector3(x,.37,z), .37, .22, Color("172027"))
			wheel.rotation.z = PI/2
			var rim = world.cylinder(visual, Vector3(x*1.04,.37,z), .20, .24, Color("9da8a6"))
			rim.rotation.z = PI/2
	for side in [-1,1]:
		world.box(visual, Vector3(side*.66,.8,-2.29), Vector3(.4,.2,.035), Color("ffe6af"))
		world.box(visual, Vector3(side*.66,.8,2.29), Vector3(.4,.17,.035), Color("a13730"))
		add_headlight(Vector3(side*.66,.85,-2.3))
	if police:
		world.box(visual, Vector3(0,.88,0), Vector3(1.94,.34,3.3), Color("17252f"))
		for side in [-1,1]:
			var lens = world.box(visual, Vector3(side*.42,1.79,0), Vector3(.7,.16,.3), Color("b32b37") if side<0 else Color("3069c8"))
			flash_lenses.append(lens)
		world.make_sign(visual, Vector3(0,1.02,-2.35), "POLICE", .06, 0)

func build_boat() -> void:
	# Closed hull/deck plus a separate solid cabin; boarding leaves real walk space.
	shape(Vector3(0,.02,0), Vector3(2.75,1.1,8.4))
	shape(Vector3(0,1.13,.15), Vector3(1.8,1.2,2.1))
	world.box(visual, Vector3(0,.02,0), Vector3(2.72,1.08,8.35), Color("244b60") if police else Color("c1ccbd"))
	world.box(visual, Vector3(0,.6,0), Vector3(2.7,.12,8.3), Color("8e9c95"))
	world.box(visual, Vector3(0,1.05,.15), Vector3(1.75,1.0,2.05), Color("d3d6c6"))
	world.box(visual, Vector3(0,1.65,.15), Vector3(1.84,.18,2.14), Color("223640"))
	world.box(visual, Vector3(0,1.32,-.89), Vector3(1.55,.35,.04), Color("345e6b"))
	for side in [-1,1]:
		world.box(visual, Vector3(side*.89,1.27,.15), Vector3(.03,.4,1.75), Color("345e6b"))
		world.box(visual, Vector3(side*1.23,1.02,-2.15), Vector3(.06,.55,3.1), Color("7d939c"))
		shape(Vector3(side*1.23,1.02,-2.15), Vector3(.06,.55,3.1))
	world.box(visual, Vector3(0,.0,4.37), Vector3(.75,.9,.55), Color("263139"))
	add_headlight(Vector3(0,1.8,-.8))
	if police:
		world.make_sign(visual, Vector3(0,.25,-4.21), "MARINE", .085, 0)
		searchlight = SpotLight3D.new()
		visual.add_child(searchlight)
		searchlight.position = Vector3(0,2,-.3)
		searchlight.spot_angle = 24
		searchlight.spot_range = 80
		searchlight.light_color = Color("e9f3da")
		searchlight.light_energy = 2
		searchlight.shadow_enabled = false
		for side in [-1,1]:
			flash_lenses.append(world.box(visual, Vector3(side*.5,1.86,.15), Vector3(.5,.16,.25), Color("a72b3d") if side<0 else Color("315abb")))

func add_headlight(at: Vector3) -> void:
	var light = SpotLight3D.new()
	visual.add_child(light)
	light.position = at
	light.rotation.x = deg_to_rad(-8)
	light.spot_range = 55 if boat else 42
	light.spot_angle = 32
	light.light_color = Color("ffedc6")
	light.light_energy = 2.5
	# One stable shadowed sun; local lights remain inexpensive in the web test.
	light.shadow_enabled = false
	headlights.append(light)

func reset_vehicle() -> void:
	global_position = spawn_point
	rotation = Vector3(0,home_heading,0)
	velocity = Vector3.ZERO
	speed = 0
	health = 100

func take_damage(amount: float) -> void:
	health = maxf(0,health-amount)
	if police and world.ops and world.started:
		world.ops.alert(position,3)
	if health<=0 and occupied:
		world.ops.message("Engine disabled · E to get out",3)

func _physics_process(dt: float) -> void:
	var throttle = 0.0
	var turn = 0.0
	var brake = false
	if health<=0:
		velocity = Vector3.ZERO
		return
	if occupied:
		throttle = Input.get_action_strength("forward")-Input.get_action_strength("back")
		turn = Input.get_action_strength("left")-Input.get_action_strength("right")
		brake = Input.is_action_pressed("handbrake")
	elif police and world.chase:
		responding = true
		var target = world.ops.drive_goal(self)
		var delta = target-global_position
		delta.y = 0
		if delta.length()> (9 if slot else 6):
			var desired = atan2(-delta.x,-delta.z)
			var angle = wrapf(desired-rotation.y,-PI,PI)
			turn = clampf(angle*1.8,-1,1)
			throttle = 1.0 if absf(angle)<1.15 else .25
			if not boat and absf(angle)>1.8 and absf(speed)<3:
				throttle = -.3
				turn = -signf(angle)
			if not boat and (not world.player.vehicle or world.player.vehicle.speed<4):
				var remaining = maxf(0,delta.length()-6)
				var safe_speed = sqrt(2*7*remaining)
				throttle = minf(throttle,safe_speed/max_speed)
			# Predict a short obstacle corridor; don't accelerate through a blocked hull.
			var ray = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,global_position+Vector3.UP-global_basis.z*maxf(6,absf(speed)*.8),3,[get_rid()])
			var obstruction = get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstruction.is_empty():
				throttle = -.2 if absf(speed)>3 else .15
				turn = 1.0 if slot%2==0 else -1.0
	else:
		responding = false
	steer = move_toward(steer,turn,dt*3)
	var forward = -global_basis.z
	var longitudinal = velocity.dot(forward)
	var sideways = velocity - forward*longitudinal
	sideways.y = 0
	var turn_rate = .62 if boat else .55
	rotation.y += steer*turn_rate*clampf(longitudinal/7,-1,1)*dt
	forward = -global_basis.z
	if police and not boat and not occupied and crew.size()>0 and crew.all(func(n): return n.boarded) and world.chase and world.player.position.distance_to(position)<22 and (not world.player.vehicle or world.player.vehicle.speed<3):
		throttle = 0
		longitudinal = move_toward(longitudinal,0,dt*16)
	var desired_speed = throttle*(max_speed if throttle>=0 else max_speed*.3)
	longitudinal = move_toward(longitudinal,desired_speed,dt*(acceleration if absf(throttle)>.05 else 2.0))
	if brake:
		longitudinal = move_toward(longitudinal,0,dt*8)
	var grip = 1.7 if boat else (1.2 if brake else 10.0)
	sideways = sideways.move_toward(Vector3.ZERO,dt*grip*maxf(1,sideways.length()))
	var vy = velocity.y
	velocity = forward*longitudinal+sideways
	if boat:
		velocity.y = (world.wave_height(global_position.x,global_position.z)+.05-global_position.y)*4
		visual.rotation.x = lerpf(visual.rotation.x,(world.wave_height(global_position.x,global_position.z-3)-world.wave_height(global_position.x,global_position.z+3))/6,dt*3)
		visual.rotation.z = lerpf(visual.rotation.z,(world.wave_height(global_position.x-1,global_position.z)-world.wave_height(global_position.x+1,global_position.z))/2,dt*3)
	else:
		velocity.y = -1 if is_on_floor() else vy-24*dt
	var incoming = velocity
	move_and_slide()
	if world.clock>damage_cooldown and incoming.length()>12 and velocity.length()<incoming.length()*.35:
		take_damage((incoming.length()-10)*1.3)
		damage_cooldown = world.clock+.6
	speed = Vector2(velocity.x,velocity.z).length()
	if searchlight:
		searchlight.visible = world.night and world.chase
		var point = world.ops.last_fix+Vector3.UP*.8
		if searchlight.global_position.distance_to(point)>1:
			searchlight.look_at(point)
	for light in headlights:
		light.visible = world.night
	for i in flash_lenses.size():
		if not flash_lenses[i].has_meta("independent_lens"):
			flash_lenses[i].material_override = flash_lenses[i].material_override.duplicate()
			flash_lenses[i].set_meta("independent_lens",true)
		var active = police and world.chase and (fmod(world.clock+slot*.13,.8)<.4)==(i==0)
		var lens_material = flash_lenses[i].material_override as StandardMaterial3D
		lens_material.emission_enabled = true
		lens_material.emission = Color("ff203b") if i==0 else Color("248cff")
		lens_material.emission_energy_multiplier = 2.5 if active else 0.0
