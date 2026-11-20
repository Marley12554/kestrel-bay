extends "res://player.gd"
var mobile_brake=false
var mobile_sprint=false
var mobile_lean=false
var crouched=false
var drawn_sidearm
var exposure
var analog=Vector2.ZERO
func configure(w:Node3D):
	super(w)
	exposure=Node3D.new()
	add_child(exposure)
	w.box(exposure,Vector3(0,.1,0),Vector3(.44,.47,.28),Color("405461"))
	w.box(exposure,Vector3(0,.46,0),Vector3(.29,.32,.27),Color("c19a7a"))
	w.box(exposure,Vector3(-.19,.14,-.17),Vector3(.14,.17,.36),Color("a88670"))
	drawn_sidearm=Node3D.new();exposure.add_child(drawn_sidearm)
	drawn_sidearm.position=Vector3(-.23,.14,-.36)
	w.box(drawn_sidearm,Vector3(0,.05,-.045),Vector3(.039,.06,.19),Color("344047"))
	w.box(drawn_sidearm,Vector3(0,-.035,.007),Vector3(.042,.102,.05),Color("263239"))
	exposure.hide()
func leaning()->bool:
	return vehicle!=null and not vehicle.aircraft and not vehicle.boat and (mobile_lean or Input.is_action_pressed("lean"))
func wants_sprint()->bool:return (mobile_sprint or Input.is_action_pressed("sprint")) and not crouched
func foot_speed_factor()->float:return .52 if crouched else 1.
func movement_input()->Vector2:return (super()+analog).limit_length()
func drown():world.ops.hurt(100)
func _unhandled_input(event):
	if not world.started or world.ops.map_open or world.ops.puzzle or world.ops.modal or world.ops.hp<=0:return
	if world.ops.lock_target:
		if event.is_action_pressed("pause"):world.ops.cancel_theft()
		elif event.is_action_pressed("interact") or event.is_action_pressed("jump") or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT):
			world.ops.theft_hit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and not world.mobile and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		yaw-=event.relative.x*.0023
		pitch=clampf(pitch-event.relative.y*.0023,-1.30,1.18)
	if event.is_action_pressed("interact") and not (vehicle and vehicle.aircraft):
		press_interact()
	if event.is_action_pressed("board_air"):
		if vehicle and vehicle.aircraft:interact()
		elif not vehicle:press_interact()
	if event.is_action_pressed("pause"):Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("honkh") and vehicle and not vehicle.aircraft and world.clock-vehicle.horn_at>.5:
		vehicle.horn_at=world.clock
		world.ops.audio.effect("horn",position,-3)
	if event.is_action_pressed("crouch") and not vehicle:crouched=not crouched
func press_interact():
	if not world.ops.interact():interact()
func board(v):
	if v.wreck or v.flooded or v.occupied:return false
	vehicle=v;v.occupied=true;v.driving_npc=false
	capsule.set_deferred("disabled",true);collision_layer=0;collision_mask=0
	mobile_sprint=false;mobile_brake=false;crouched=false;submerged=false;swimming=false
	yaw=v.rotation.y if v.aircraft else 0.;pitch=-.10
	return true
func interact():
	if vehicle:
		var prev=vehicle
		super()
		mobile_brake=false;mobile_lean=false
		if not vehicle:yaw=prev.rotation.y
		return
	var near=world.ops.nearest_vehicle()
	if near:world.ops.request_vehicle(near)
func _physics_process(dt):
	if not world.started:return
	if world.ops.modal or world.ops.puzzle or world.ops.lock_target:
		if not vehicle:velocity=Vector3.ZERO
		return
	if not vehicle and swimming and Input.is_action_just_pressed("jump") and position.y>world.wave_height(position.x,position.z)-1.55 and try_mantle():return
	if not vehicle:
		var shape=capsule.shape as CapsuleShape3D
		shape.height=1.14 if crouched else 1.8
		capsule.position.y=shape.height*.5
	super(dt)
func _process(dt):
	if not world.started:return
	if vehicle and vehicle.aircraft:
		var focus=vehicle.position+Vector3.UP*1.6
		var behind=Vector3(sin(yaw),.28,cos(yaw))*vehicle.camera_distance
		camera.global_position=focus+behind
		camera.look_at(focus+Vector3.UP*pitch*2)
	elif leaning():
		var angle=vehicle.rotation.y+PI*.5+clampf(yaw,-1.42,1.42)
		var look=Vector3(-sin(angle)*cos(pitch),sin(pitch),-cos(angle)*cos(pitch))
		var anchor=vehicle.to_global(Vector3(-.93,1.47,-.12))
		camera.global_position=anchor-look*2.55+Vector3.UP*.65+vehicle.global_basis.z*.48
		camera.look_at(anchor+look*35.)
		exposure.global_transform=vehicle.global_transform
		exposure.global_position=vehicle.to_global(Vector3(-.85,1.08,-.15))
		exposure.rotate_object_local(Vector3.BACK,.48)
	else:
		super(dt)
		if not vehicle and crouched:camera.position.y=1.03
	exposure.visible=leaning()
	drawn_sidearm.visible=world.ops.weapon_slot==1

func _assist_broken_window(motion:Vector3):
	super(motion)
	if motion.length_squared()<.000005 or not is_on_floor() or not test_move(global_transform,motion):return
	var up=Vector3.UP*.46
	var raised=global_transform;raised.origin+=up
	if not test_move(global_transform,up) and not test_move(raised,motion):move_and_collide(up)

func try_mantle()->bool:
	var ahead=Basis(Vector3.UP,yaw)*Vector3.FORWARD
	var start=position+ahead*.98+Vector3.UP*3.1
	var query=PhysicsRayQueryParameters3D.create(start,start-Vector3.UP*3.12,3,[get_rid()])
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y<.75:return false
	var top=hit.position+Vector3.UP*.065
	if top.y<position.y+.24 or top.y>position.y+2.92:return false
	var shape_query=PhysicsShapeQueryParameters3D.new()
	shape_query.shape=capsule.shape
	shape_query.transform=Transform3D(Basis.IDENTITY,top+Vector3.UP*.92)
	shape_query.collision_mask=3
	if not get_world_3d().direct_space_state.intersect_shape(shape_query,1).is_empty():return false
	position=top;velocity=Vector3.ZERO;swimming=false
	return true
