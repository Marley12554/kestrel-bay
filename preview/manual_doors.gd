extends Node3D

const SwingDoor := preload("res://hinged_door.gd")
const Drum := preload("res://revolving_door.gd")
var arms := preload("res://door_arms.gd").new()
@onready var city = get_parent()
var drum: Drum
var wing: Node3D
var leaf: SwingDoor
var entry_side := 1.
var push_axis := Vector3.ZERO
var reach := 0.
var foot_offset := Vector3.ZERO
var contact := Vector3.ZERO
var last_bar := Transform3D.IDENTITY
var two_hands := false
var closing := false
var rang := false
var sweep := 0.

func _ready() -> void:
	add_child(arms)

func release(immediate := false) -> void:
	drum = null
	leaf = null
	wing = null
	if immediate:
		reach = 0.
		arms.hide()

func nearest_handle() -> SwingDoor:
	var best: SwingDoor
	var distance := .73
	var chest: Vector3 = city.walker.global_position + Vector3.UP*1.22
	var face := Basis(Vector3.UP,city.yaw)*Vector3.FORWARD
	for door: SwingDoor in get_tree().get_nodes_in_group("manual_swing_doors"):
		var p := door.to_local(chest)
		var handle := door.handle
		handle.z *= signf(p.z)
		var delta := door.to_global(handle)-chest
		if delta.length() < distance and face.dot(delta.normalized()) > .2:
			distance = delta.length()
			best = door
	return best

func hint() -> String:
	if leaf: return "Move forward to push · Back to pull · E to release"
	if drum: return "Move forward to push"
	return "Grip door handle" if nearest_handle() else ""

func interact() -> bool:
	if leaf or drum:
		release()
		return true
	var found := nearest_handle()
	if not found: return false
	leaf = found
	foot_offset = leaf.to_local(city.walker.global_position)
	foot_offset.x = signf(leaf.handle.x) * minf(absf(foot_offset.x), absf(leaf.handle.x)*.73)
	entry_side = signf(foot_offset.z)
	push_axis = -leaf.global_basis.z * entry_side
	contact = leaf.handle
	contact.z *= entry_side
	closing = absf(leaf.angle) > .04
	rang = false
	two_hands = false
	reach = 0.
	return true

func find_bar(direction: Vector3, dt: float) -> bool:
	var feet: Vector3 = city.walker.global_position
	var chest := feet + Vector3.UP*1.15
	for candidate: Drum in get_tree().get_nodes_in_group("manual_drums"):
		var p := candidate.to_local(feet)
		if absf(p.x) > .87 or absf(p.z) > 1.65 or absf(p.y) > .4: continue
		var side := signf(p.z)
		var inward := -candidate.global_basis.z * side
		if direction.dot(inward) < .55 or direction.dot(Basis(Vector3.UP,city.yaw)*Vector3.FORWARD) < .25: continue
		var best := .70
		var tip: Node3D
		for w in candidate.wings:
			var hand := w.to_local(chest)
			if hand.x > 1.12 and hand.x < 1.58 and hand.z >= -.64 and hand.z < .15:
				tip = w
			if hand.x < .24 or hand.z < .12: continue
			var handle := Vector3(clampf(hand.x,.42,.80),1.13,.10)
			var distance := w.to_global(handle).distance_to(chest)
			if distance >= best: continue
			best = distance
			drum = candidate
			wing = w
			contact = handle
			entry_side = side
			push_axis = inward
		if drum:
			sweep = 0.
			two_hands = true
			reach = 0.
			return true
		# A wing may stop pointing straight out of the entrance. Step around
		# its end to reach the bar on the push side, keeping the glass solid.
		if tip:
			var target := tip.to_global(Vector3(1.43,0.,.28))
			if absf(candidate.to_local(target).x) > .55: continue
			var move := (target-feet).slide(Vector3.UP).limit_length(1.55*dt*direction.length())
			city.walker.move_and_collide(move)
			return true
	return false

func animate_hands(dt: float) -> void:
	var panel := wing if drum else leaf as Node3D
	if panel:
		var normal := panel.global_basis.z * (1. if drum else entry_side)
		var axis := panel.global_basis.x if drum else Vector3.UP
		last_bar = Transform3D(Basis(axis,normal.cross(axis),normal),panel.to_global(contact))
	reach = move_toward(reach, 1. if panel else 0., dt * (5.5 if panel else 7.))
	var carrying: bool = city.block.reserve.order == city.block.reserve.Order.CARRIED
	arms.pose(city.walker.global_position, city.yaw, last_bar, reach, two_hands, carrying)

# The walk controller delegates horizontal movement while hands are attached.
# Walking the capsule and advancing the panel share one angular displacement.
func step(direction: Vector3, dt: float) -> bool:
	if city.airborne or city.jump_requested:
		release(true)
		return false
	if not leaf and not drum:
		if reach > 0.:
			animate_hands(dt)
			return false
		var approaching := find_bar(direction,dt)
		if not drum: return approaching
	var panel := wing if drum else leaf as Node3D
	var feet: Vector3 = city.walker.global_position
	var hand := panel.to_global(contact)
	if (hand-feet-Vector3.UP*1.2).length() > .93:
		release(true)
		return false
	var forward := Basis(Vector3.UP,city.yaw)*Vector3.FORWARD
	var effort := direction.dot(forward)
	if drum and effort < -.2:
		release()
		return false
	var old_angle := drum.rotor.rotation.y if drum else leaf.angle
	var turn := 0.
	var at_limit := false
	if reach >= .99 and absf(effort) > .001:
		if drum:
			turn = clampf(effort,0.,1.) * 1.46 * dt
			drum.turn_by(turn)
		else:
			var requested := old_angle + effort * entry_side * signf(contact.x) * 1.55 * dt
			var shut := not is_zero_approx(old_angle) and (is_zero_approx(requested) or requested*old_angle <= 0.)
			at_limit = absf(requested) >= 1.63 or shut
			leaf.set_angle(0. if shut else requested)
			turn = leaf.angle-old_angle
	var stance := Vector3(.555,0.,.385) if drum else foot_offset
	var move := (panel.to_global(stance) - feet).slide(Vector3.UP)
	move = move.limit_length(1.65 * direction.length() * dt)
	# The attached panel and player move together. The constrained foot
	# position keeps them on the same side while sweeping against the jambs,
	# casing, neighboring wings, and the rest of the world.
	var held_body: PhysicsBody3D = drum.wing_bodies[drum.wings.find(wing)] if drum else leaf
	city.walker.add_collision_exception_with(held_body)
	var hit: KinematicCollision3D = city.walker.move_and_collide(move) if move.length_squared() > .00000001 else null
	city.walker.remove_collision_exception_with(held_body)
	if hit and hit.get_remainder().length() > .004:
		if drum: drum.turn_by(-turn)
		else: leaf.set_angle(old_angle)
		turn = 0.
		at_limit = false
	sweep += turn
	if leaf and not rang and absf(turn) > .0001:
		leaf.moved.emit()
		rang = true
	animate_hands(dt)
	follow_contact(direction,effort,dt)
	if drum and sweep > 1.35 and drum.to_local(city.walker.global_position).z * entry_side < -.64:
		release()
	elif leaf and at_limit:
		release()
	return true

func follow_contact(direction: Vector3, effort: float, dt: float) -> void:
	# Follow the contact in the turn, as the player's shoulders come around.
	if direction.length_squared() > .01 or reach < 1.:
		var view: Vector3 = last_bar.origin - (city.walker.global_position + Vector3.UP*1.7)
		var ahead := view.slide(Vector3.UP)
		var aim_yaw := atan2(-ahead.x,-ahead.z)
		if drum:
			var towards_exit := -drum.to_local(city.walker.global_position).z * entry_side
			aim_yaw = lerp_angle(aim_yaw,atan2(-push_axis.x,-push_axis.z),smoothstep(.24,.64,towards_exit))
		elif not closing and effort > 0.:
			aim_yaw = lerp_angle(aim_yaw,atan2(-push_axis.x,-push_axis.z),smoothstep(1.02,1.63,absf(leaf.angle)))
		var aim_pitch := clampf(atan2(view.y,ahead.length())+.18,-.94,-.20)
		var follow := 1.-exp(-9.*dt)
		city.yaw = lerp_angle(city.yaw,aim_yaw,follow)
		city.pitch = lerpf(city.pitch,aim_pitch,follow)
		city.camera.rotation = Vector3(city.pitch,city.yaw,0)
