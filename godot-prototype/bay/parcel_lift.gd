extends AnimatableBody3D
var world
var base: Vector3
var floors=1
var destination=0
func configure(w,origin,count):
	world=w
	base=origin
	position=base
	floors=count
	w.collision_box(self,Vector3(0,-.1,0),Vector3(3.85,.2,3.85))
	w.box(self,Vector3(0,-.1,0),Vector3(3.85,.2,3.85),Color("736755"))
	for side in [-1,1]:
		w.box(self,Vector3(side*1.91,1.45,-.05),Vector3(.08,2.9,3.72),Color("657476"),true)
	w.box(self,Vector3(0,1.45,-1.91),Vector3(3.85,2.9,.08),Color("657476"),true)
	w.box(self,Vector3(0,2.92,0),Vector3(3.88,.12,3.88),Color("bac3ad"))
	w.make_sign(self,Vector3(0,1.7,-1.84),"LIFT",.015)
func _physics_process(dt):
	if world.started:
		var next_y=move_toward(position.y,base.y+destination*3.8,dt*minf(12,2.5+absf(base.y+destination*3.8-position.y)*.22))
		position=Vector3(base.x,next_y,base.z)
