extends AnimatableBody3D

var target_y = 2.6
var world: Node3D
var riding = false

func configure(owner_world: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	world = owner_world
	position = Vector3(-34.5,2.6,17.5)
	var shape = CollisionShape3D.new()
	var bounds = BoxShape3D.new()
	bounds.size = Vector3(3.8,.22,3.8)
	shape.shape = bounds
	shape.position.y = -.11
	add_child(shape)
	world.box(self,Vector3(0,-.11,0),bounds.size,Color("59686c"))
	for x in [-1.9,1.9]:
		world.box(self,Vector3(x,1.5,0),Vector3(.12,3,3.8),Color("6c7b7b"),true)
	world.box(self,Vector3(0,1.5,-1.9),Vector3(3.8,3,.12),Color("6c7b7b"),true)
	world.box(self,Vector3(0,3.0,0),Vector3(3.9,.1,3.9),Color("82958f"))
	world.box(self,Vector3(0,2.93,0),Vector3(1,.03,1),Color("f4db9c"))
	world.make_sign(self,Vector3(0,1.9,-1.80),"BREAKWATER\nLOBBY  /  SUITES",.0045)

func use() -> void:
	if absf(position.y-target_y)<.05:
		target_y = 6.8 if position.y<4 else 2.6

func _physics_process(dt: float) -> void:
	if not world.started:
		return
	var p = world.player
	riding = not p.vehicle and absf(p.position.x-position.x)<1.8 and absf(p.position.z-position.z)<1.8 and absf(p.position.y-position.y)<.35
	position.y = move_toward(position.y,target_y,dt*1.65)
