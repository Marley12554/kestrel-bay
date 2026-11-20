extends Node3D

var world: Node3D
var kind = "door"
var locked = false
var opened = false
var broken = false
var hp = 45.0
var panel: AnimatableBody3D
var visual: MeshInstance3D
var title = "Door"
var angle_open = PI/2

func configure(owner_world: Node3D, at: Vector3, width: float, height: float, mode: String, label: String, angle: float=0, secured: bool=false) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	world = owner_world
	kind = mode
	title = label
	locked = secured
	hp = 20.0 if mode=="window" else 45.0
	position = at
	rotation.y = angle
	panel = AnimatableBody3D.new()
	add_child(panel)
	panel.set_meta("target",self)
	var size = Vector3(width,height,.12)
	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = Vector3(width*.5,height*.5,0)
	panel.add_child(shape)
	visual = world.box(panel,shape.position,size,Color("527985") if kind=="window" else Color("68513d"))
	if kind=="window":
		hp = 15
		var glass = StandardMaterial3D.new()
		glass.albedo_color = Color(.26,.55,.63,.23)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.roughness = .15
		visual.material_override = glass
	else:
		world.box(panel,Vector3(width*.5,height*.75,-.075),Vector3(width*.68,height*.24,.04),Color("a4a38a"))
		world.box(panel,Vector3(width*.82,1.05,.11),Vector3(.09,.07,.18),Color("d4b172"))
		world.make_sign(panel,Vector3(width*.5,height*.85,.09),label,.008)

func take_damage(amount: float,by_player: bool=true) -> void:
	if broken:
		return
	hp -= amount
	if by_player:
		world.ops.alert(world.player.position,2)
	if hp<=0:
		locked = false
		if kind=="window":
			broken = true
			panel.collision_layer = 0
			panel.collision_mask = 0
			visual.hide()
			world.ops.audio.effect("glass",global_position,-8)
		else:
			opened = true

func _physics_process(dt: float) -> void:
	if kind=="door":
		panel.rotation.y = move_toward(panel.rotation.y,angle_open if opened else 0,dt*3.5)
