extends CharacterBody3D

var world: Node3D
var camera: Camera3D
var capsule: CollisionShape3D
var vehicle: CharacterBody3D
var yaw = 0.0
var pitch = -.08
var breath = 100.0
var swimming = false
var submerged = false
var sprint = false

func configure(owner_world: Node3D) -> void:
	world = owner_world
	collision_layer = 4
	collision_mask = 3
	floor_snap_length = .4
	safe_margin = .02
	capsule = CollisionShape3D.new()
	var body = CapsuleShape3D.new()
	body.radius = .32
	body.height = 1.8
	capsule.shape = body
	capsule.position.y = .9
	add_child(capsule)
	camera = Camera3D.new()
	camera.near = .08
	camera.far = 1400
	camera.fov = 78
	add_child(camera)
	camera.current = true
	reset_player()

func reset_player(at = Vector3(0,2.85,95)) -> void:
	if vehicle:
		vehicle.occupied = false
	vehicle = null
	capsule.set_deferred("disabled",false)
	collision_layer = 4
	collision_mask = 3
	global_position = at
	velocity = Vector3.ZERO
	yaw = 0
	pitch = -.08
	breath = 100

func _unhandled_input(event: InputEvent) -> void:
	if not world.started or world.ops.map_open or world.ops.puzzle:
		return
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x*.0023
		pitch = clampf(pitch-event.relative.y*.0023,-1.35,1.25)
	if event.is_action_pressed("interact"):
		if not world.ops.interact():
			interact()
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("reset"):
		world.reset_test()
	if event.is_action_pressed("night"):
		world.set_night(not world.night)
	if event.is_action_pressed("chase"):
		world.chase = not world.chase
	if event.is_action_pressed("dock"):
		reset_player(Vector3(4,1.95,159))

func interact() -> void:
	if vehicle:
		var v = vehicle
		if v.boat:
			reset_player(v.global_position + v.global_basis.z*2.6 + Vector3.UP*.78)
		else:
			for side in [-1,1]:
				var at = v.global_position+v.global_basis.x*side*1.8+Vector3.UP*.1
				var test = PhysicsShapeQueryParameters3D.new()
				test.shape = capsule.shape
				test.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*.9)
				test.collision_mask = 3
				if get_world_3d().direct_space_state.intersect_shape(test,1).is_empty():
					reset_player(at)
					break
		return
	var nearest: CharacterBody3D
	var best = 4.0
	for v in world.vehicles:
		var d = global_position.distance_to(v.global_position)
		if d<best and v.speed<2:
			nearest = v
			best = d
	if nearest:
		vehicle = nearest
		vehicle.occupied = true
		capsule.set_deferred("disabled",true)
		collision_layer = 0
		collision_mask = 0
		yaw = 0
		pitch = -.12

func _physics_process(dt: float) -> void:
	if vehicle:
		global_position = vehicle.global_position
		velocity = vehicle.velocity
		return
	if world.ops and (world.ops.puzzle or world.ops.hp<=0):
		velocity = Vector3.ZERO
		return
	var move_input = movement_input()
	var ix = move_input.x
	var iz = move_input.y
	var input = Vector2(ix,iz).limit_length()
	var wave = world.wave_height(global_position.x,global_position.z)
	swimming = global_position.y<wave+.16 and not is_on_floor()
	submerged = camera.global_position.y<wave-.1
	sprint = wants_sprint() and not world.ops.exhausted
	var travel_speed = (3.8 if sprint else 2.7) if swimming else (8.5 if sprint else 4.4)
	var direction = Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y)
	travel_speed *= foot_speed_factor()
	velocity.x = direction.x*travel_speed
	velocity.z = direction.z*travel_speed
	if swimming:
		velocity.y = -input.y*sin(pitch)*travel_speed-.25
		if Input.is_action_pressed("jump"):
			velocity.y = 3.2
			if global_position.y>wave-1.8 and Input.is_action_just_pressed("jump"):
				velocity.y = 6
	else:
		velocity.y -= 24*dt
		if is_on_floor():
			velocity.y = 6 if Input.is_action_just_pressed("jump") else -1
	if not swimming and velocity.y<=0:
		_assist_broken_window(Vector3(velocity.x,0,velocity.z)*dt)
	move_and_slide()
	breath = clampf(breath+dt*(-10 if submerged else 30),0,100)
	if global_position.y < -18 or breath<=0:
		drown()

func drown():
	reset_player(Vector3(4,1.95,159))

func movement_input()->Vector2:
	return Input.get_vector("left","right","forward","back")

func wants_sprint()->bool:
	return Input.is_action_pressed("sprint")

func foot_speed_factor()->float:
	return 1.

func _process(_dt: float) -> void:
	if not vehicle:
		camera.position = Vector3(0,1.65,0)
		camera.rotation = Vector3(pitch,yaw,0)
	else:
		var focus = vehicle.global_position+Vector3.UP*(1.0 if vehicle.boat else 1.1)
		var angle = vehicle.rotation.y+yaw
		var back = Vector3(sin(angle),0,cos(angle))*vehicle.camera_distance
		var desired = focus+back+Vector3.UP*(4-pitch*5)
		var ray = PhysicsRayQueryParameters3D.create(focus,desired,1)
		var hit = get_world_3d().direct_space_state.intersect_ray(ray)
		camera.global_position = hit.position+(focus-hit.position).normalized()*.3 if not hit.is_empty() else desired
		camera.look_at(focus)

func _assist_broken_window(motion: Vector3) -> void:
	if motion.length_squared()<.00001 or not is_on_floor():
		return
	for passage in world.ops.passages:
		if passage.kind!="window" or not passage.broken:
			continue
		var local = passage.to_local(global_position)
		var width = passage.visual.mesh.size.x
		var rise = passage.global_position.y+.02-global_position.y
		if absf(local.z)>1.0 or local.x<.35 or local.x>width-.35 or rise<=0 or rise>.55:
			continue
		var up = Vector3.UP*rise
		var raised = global_transform
		raised.origin += up
		if test_move(global_transform,motion) and not test_move(global_transform,up) and not test_move(raised,motion):
			move_and_collide(up)
			return
