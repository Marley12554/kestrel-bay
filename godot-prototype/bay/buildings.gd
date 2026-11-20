extends RefCounted
var w
func _init(world):
	w=world

func furnish(parent: Node3D,at: Vector3,width: float,depth: float,use: String,level: int,shaft: Vector2) -> void:
	var timber=Color("795a47")
	var brass=Color("af9466")
	var teal=Color("38636a")
	var clear=Rect2(shaft-Vector2(2.15,2.1),Vector2(4.3,6.1))
	var aisle=Rect2(-1.3,-depth*.5,2.6,depth)
	var wall=func(x,y,z,sx,sy,sz,col):
		var footprint=Rect2(x-sx*.5,z-sz*.5,sx,sz)
		if clear.intersects(footprint) or aisle.intersects(footprint):return null
		return w.box(parent,at+Vector3(x,y,z),Vector3(sx,sy,sz),col,true)
	var x = width*.28
	if use in ["coffee","union","florist"]:
		wall.call(x, .54,-depth*.21,2.2,1.08,4.8,timber)
		for z in [-.16,.16]:
			if not clear.grow(1.0).has_point(Vector2(-x,depth*z)):w.cylinder(parent,at+Vector3(-x,.79,depth*z),1,.13,brass)
			wall.call(-x,.39,depth*z,.3,.78,.3,teal)
			wall.call(-x-1.45,.33,depth*z,.7,.66,.75,teal)
	elif use in ["apartments","hotel","infirmary","cells"]:
		for side in [-1,1]:
			wall.call(side*x,.35,-depth*.22,2.3,.7,3.2,timber)
			wall.call(side*x,.78,-depth*.22,2.26,.16,2.95,teal)
			wall.call(side*x,.91,-depth*.22-.98,1.7,.14,.62,Color("ece1c9"))
			wall.call(side*x,1.45,-depth*.04,3.8,2.9,.18,Color("b5a68d"))
	elif use in ["bookshop","archive","stores"]:
		for side in [-1,1]:
			for z in [-.22,.05,.27]:
				wall.call(side*x,1.0,depth*z,3.7,2,.5,timber)
				for shelf in [1.0,1.75]:
					wall.call(side*x,shelf,depth*z+.28,3.3,.38,.1,teal if z>0 else brass)
	elif use in ["theatre","chapel","arcade"]:
		for row in 3:
			for side in [-1,1]:
				wall.call(side*x,.42,-depth*.2+row*2.3,3.5,.84,.8,Color("93584d"))
		wall.call(0,1.6,-depth*.40,width*.58,2.5,.22,teal)
	else:
		for side in [-1,1]:
			wall.call(side*x,.72,-depth*.16,3.5,.14,1.5,timber)
			for leg in [-1,1]:
				wall.call(side*x+leg*1.45,.35,-depth*.16,.14,.7,1.2,brass)
			wall.call(side*x,1.18,-depth*.16,1.0,.65,.12,Color("2f4249"))
			wall.call(side*x,.45,-depth*.16+1.35,.85,.90,.8,teal)
	# Pendant and runner help the rooms read at human scale.
	w.box(parent,at+Vector3(0,.019,0),Vector3(2.2,.025,depth*.7),Color("765344"))
	w.box(parent,at+Vector3(0,3.55,0),Vector3(2.8,.12,.65),Color("f3dbab"))
