extends "res://frontage_geometry.gd"

# A fixed pair of curved screens encloses a four-wing rotor. Local +Z faces
# the sidewalk. The drum sits behind the rectangular street-facing jambs.
const RADIUS := 1.19
const HALF_ARC := PI / 4.0
const SILL := .12
const HEAD := 2.69
var rotor := Node3D.new()
var speed := 0.0
var wings: Array[StaticBody3D] = []
const MAX_PUSH_SPEED := 3.2
const COAST_DECELERATION := 23.0
var last_pusher: CharacterBody3D
var pushed_this_step := false
var pushed_angle := 0.

func _ready() -> void:
	# Both doors reuse the entrance's metal and glazing resources.
	meshes={"box":cube}
	var rail: Material=finishes["rail"]
	var mat:=material("mat","#333332",.93)
	var disk:=CylinderMesh.new()
	disk.radial_segments=64
	disk.rings=0
	disk.top_radius=RADIUS+.03
	disk.bottom_radius=disk.top_radius
	disk.height=.018
	var threshold:=MeshInstance3D.new()
	threshold.mesh=disk
	threshold.material_override=mat
	threshold.position.y=SILL-.01
	add_child(threshold)
	for side in [-1,1]:
		fixed_screen(side)
	# Separate meshes give Godot a sorting origin per glass surface.
	# Keep the center of the mechanism grounded and the floor flush.
	var hub:=CylinderMesh.new()
	hub.top_radius=.055
	hub.bottom_radius=.055
	hub.height=HEAD-SILL
	var spindle:=MeshInstance3D.new()
	spindle.mesh=hub
	spindle.material_override=rail
	spindle.position.y=(HEAD+SILL)*.5
	rotor.add_child(spindle)
	rotor.rotation.y=.42
	add_child(rotor)
	var outer:=RADIUS-.048
	var inner:=.052
	var width:=outer-inner
	var mid_x:=(outer+inner)*.5
	for index in 4:
		var wing:=Node3D.new()
		wing.rotation.y=index*PI/2
		rotor.add_child(wing)
		var glass:=QuadMesh.new()
		glass.size=Vector2(width-.045,HEAD-SILL-.20)
		add_glass(wing,glass,Vector3(mid_x,(HEAD+SILL)*.5+.045,0))
		# Broad kick plate, slim glazing stiles and a projecting push bar.
		frame=wing.transform
		piece("rail",Vector3(mid_x,SILL+.092,0),Vector3(width,.164,.041))
		piece("rail",Vector3(mid_x,HEAD-.032,0),Vector3(width,.06,.041))
		piece("rail",Vector3(outer-.014,(SILL+HEAD)*.5,0),Vector3(.028,HEAD-SILL,.041))
		for pos_x in [inner+.18,outer-.17]:
			piece("rail",Vector3(pos_x,1.13,.048),Vector3(.033,.041,.093))
		piece("rail",Vector3(mid_x,1.13,.10),Vector3(width-.27,.045,.035))
	# Only the hardware collected above belongs to the rotor.
	assemble(rotor)
	add_to_group("revolving_doors")
	for side in [-1.,1.]:
		for i in 8:
			var a:float=side*PI*.5+lerpf(-HALF_ARC,HALF_ARC,(i+.5)/8.)
			var radius:=RADIUS+.03
			add_barrier(self,Vector3(sin(a)*radius,1.39,cos(a)*radius),Vector3(.24,2.50,.05),a)
	for i in 4:
		var a:=i*PI*.5
		var wing := add_barrier(rotor,Vector3(cos(a)*outer*.5,1.39,-sin(a)*outer*.5),Vector3(outer,2.50,.036),a)
		wing.set_meta("revolving_door", self)
		wings.append(wing)

func add_barrier(parent:Node3D,at:Vector3,size:Vector3,yaw:float) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.position=at
	body.rotation.y=yaw
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	parent.add_child(body)
	return body


func add_glass(parent: Node3D,mesh: Mesh,at: Vector3) -> void:
	var pane_view:=MeshInstance3D.new()
	pane_view.mesh=mesh
	pane_view.material_override=finishes["door_glass"]
	pane_view.position=at
	pane_view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pane_view)

func fixed_screen(side: int) -> void:
	# Build continuous cylindrical surfaces with radial normals, including the
	# sill and head bands. The open quarter-circles face the sidewalk and lobby.
	for band in [[SILL+.07,HEAD-.07,true],[SILL,SILL+.07,false],[HEAD-.07,HEAD,false]]:
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in 25:
			var a:=side*PI/2-HALF_ARC+2.*HALF_ARC*step/24.
			var outward:=Vector3(sin(a),0,cos(a))
			for y: float in [band[0],band[1]]:
				surface.set_uv(Vector2(step/24., (y-band[0])/(band[1]-band[0])))
				surface.set_normal(outward)
				surface.add_vertex(outward*RADIUS+Vector3.UP*y)
			if step<24:
				var k:=step*2
				for idx in [k,k+1,k+2,k+2,k+1,k+3]:
					surface.add_index(idx)
		var mesh:=surface.commit()
		if band[2]:
			add_glass(self,mesh,Vector3.ZERO)
		else:
			var trim:=MeshInstance3D.new()
			trim.mesh=mesh
			trim.material_override=finishes["rail"]
			add_child(trim)
	for end in [-1,1]:
		var a: float=side*PI/2+end*HALF_ARC
		var jamb:=MeshInstance3D.new()
		var post:=BoxMesh.new()
		post.size=Vector3(.045,HEAD-SILL,.058)
		jamb.mesh=post
		jamb.material_override=finishes["rail"]
		jamb.rotation.y=a
		jamb.position=Vector3(sin(a)*RADIUS,(HEAD+SILL)*.5,cos(a)*RADIUS)
		add_child(jamb)

# A straight walking input follows the open side of the spindle. The
# player can still sidestep or back out, and looking never moves the rotor.
func walking_velocity(world_feet: Vector3, velocity: Vector3) -> Vector3:
	var feet := to_local(world_feet)
	if absf(feet.y) > .45 or absf(feet.x) > .86 or absf(feet.z) > 1.62:
		return velocity
	var local := global_basis.inverse() * velocity
	if absf(feet.z) > RADIUS and feet.z * local.z > 0.: return velocity
	if absf(local.z) < .001 or absf(local.x) > absf(local.z) * .75:
		return velocity
	var lane := signf(feet.x) if absf(feet.x) > .12 else -signf(local.z)
	var offset := .31 + .40 * exp(-feet.z * feet.z / .35)
	var correction := clampf((lane * offset - feet.x) * 4., -1., 1.)
	local.x += correction * absf(local.z)
	return global_basis * local.normalized() * velocity.length()

func try_push(hit: KinematicCollision3D, walker: CharacterBody3D, motion: Vector3, dt: float) -> bool:
	var wing := hit.get_collider() as StaticBody3D
	var tangent := -wing.global_basis.z
	var pressure := motion.dot(tangent)
	if absf(pressure) < .0001 or motion.dot(hit.get_normal()) >= -.00001:
		return false
	var lever := maxf(.32, (hit.get_position() - global_position).dot(wing.global_basis.x))
	var limit := maxf(0., MAX_PUSH_SPEED * dt - absf(pushed_angle))
	var turn := clampf(pressure / lever, -limit, limit)
	if is_zero_approx(turn): return false
	rotate_wings(turn)
	pushed_angle += turn
	pushed_this_step = true
	speed = pushed_angle / dt
	last_pusher = walker
	return true

func rotate_wings(turn: float) -> void:
	rotor.rotate_y(turn)
	for wing in wings:
		wing.force_update_transform()

func _physics_process(dt: float) -> void:
	if pushed_this_step:
		pushed_this_step = false
		pushed_angle = 0.
		return
	if is_zero_approx(speed): return
	var slower := move_toward(speed, 0., COAST_DECELERATION * dt)
	var turn := (speed + slower) * .5 * dt
	# A free rotor runs out of momentum within a few inches. A following
	# wing must stop short of a player who pauses inside the compartment.
	if is_instance_valid(last_pusher):
		var p := to_local(last_pusher.global_position)
		var radius := Vector2(p.x,p.z).length()
		if radius < RADIUS + .27 and absf(p.y) < .5:
			var angle := atan2(-p.z,p.x) - rotor.rotation.y
			var gap := fposmod(angle * signf(turn), PI * .5)
			var clearance := asin(clampf(.295 / maxf(radius,.295), 0., 1.))
			turn = signf(turn) * minf(absf(turn), maxf(0., gap - clearance))
			if is_zero_approx(turn): slower = 0.
	rotate_wings(turn)
	speed = slower
