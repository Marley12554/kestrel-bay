extends Node3D
const Atlas=preload("res://bay/atlas.gd")
var w
var parcel
var lift
var interiors={}
var size_at_floor=Vector2.ZERO
var shaft=Vector2.ZERO
var last_floor=-999
var floors=0
var decor
func configure(world,p):
	w=world
	parcel=p
	position=p.at
	floors=int(p.floors)
	decor=preload("res://bay/buildings.gd").new(w)
	var smallest=Atlas.tier(p,floors-1)
	shaft=Vector2(-minf(4,smallest.x*.5-2.2),-minf(4,smallest.y*.5-2.2))
	if floors>1:
		lift=preload("res://bay/parcel_lift.gd").new()
		lift.position=Vector3(shaft.x,0,shaft.y)
		add_child(lift)
		lift.configure(w,Vector3(shaft.x,0,shaft.y),floors)
	var title=p.title
	if title.is_empty():title=w.business(p)
	var front=Vector3(0,3.61,p.face*(p.d*.5+.62))
	w.make_sign(self,front,title.to_upper(),minf(.023,p.w/(title.length()*27.)),0 if p.face>0 else PI)
	refresh(w.player.position if w.player else p.at)
func refresh(eye):
	var f=clampi(floori((eye.y-position.y+.55)/3.8),0,floors)
	if f==last_floor:return
	last_floor=f
	for number in interiors.keys():
		if absi(number-f)>1:
			interiors[number].queue_free()
			interiors.erase(number)
	for number in range(maxi(0,f-1),mini(floors,f+1)+1):
		if not interiors.has(number):_floor(number)
func slab(n,p,s,col,solid=true):
	return w.box(n,p,s,col,solid)
func rect_slab(n,x1,x2,z1,z2,height,color):
	if x2-x1>.035 and z2-z1>.035:
		slab(n,Vector3((x1+x2)*.5,-.115,(z1+z2)*.5),Vector3(x2-x1,height,z2-z1),color)
func _floor(i):
	var n=Node3D.new()
	add_child(n)
	n.position.y=i*3.8
	interiors[i]=n
	var sz=Atlas.tier(parcel,mini(i,floors-1))
	var half=sz*.5
	var floor_color=Color("b9a991") if parcel.style!="garage" else Color("879398")
	if i>0 and floors>1:
		rect_slab(n,-half.x,shaft.x-2,-half.y,half.y,.23,floor_color)
		rect_slab(n,shaft.x+2,half.x,-half.y,half.y,.23,floor_color)
		rect_slab(n,shaft.x-2,shaft.x+2,-half.y,shaft.y-2,.23,floor_color)
		rect_slab(n,shaft.x-2,shaft.x+2,shaft.y+2,half.y,.23,floor_color)
	else:
		slab(n,Vector3(0,-.115,0),Vector3(sz.x,.23,sz.y),floor_color)
	var escape=parcel.floors<=9 and parcel.floors>1 and (int(parcel.seed)%5==0 or parcel.title in ["Voss Development","Harrow House","Copper Kettle","Battery House Hotel"])
	if escape:_escape(n,i,half)
	if i==floors:
		for side in [-1,1]:
			slab(n,Vector3(side*half.x,.49,0),Vector3(.22,.98,sz.y),Color("899799"))
			slab(n,Vector3(0,.49,side*half.y),Vector3(sz.x,.98,.22),Color("899799"))
		_pack(n)
		return
	# Thin inner walls have real openings, resolved in the same metres as
	# the baked exterior. Slots in front of the lift and entrance stay clear.
	var wall=Color("bdbaac")
	for side in [-1,1]:
		var x=side*(half.x-.115)
		var length=half.y-1.68
		for s in [-1,1]:slab(n,Vector3(x,1.9,s*(half.y-length*.5)),Vector3(.19,3.8,length),wall)
		slab(n,Vector3(x,.21,0),Vector3(.19,.42,3.36),wall)
		slab(n,Vector3(x,3.425,0),Vector3(.19,.75,3.36),wall)
		_window(n,Vector3(x,1.74,0),3.35,PI*.5,"%d/%d/x%d"%[int(parcel.id),i,side])
		var z=side*(half.y-.115)
		for sign_x in [-1,1]:
			var width=half.x-1.68
			slab(n,Vector3(sign_x*(half.x-width*.5),1.9,z),Vector3(width,3.8,.19),wall)
		slab(n,Vector3(0,3.425,z),Vector3(3.36,.75,.19),wall)
		if side!=parcel.face or i>0:
			slab(n,Vector3(0,.21,z),Vector3(3.36,.42,.19),wall)
			var key="%d/%d/%d"%[int(parcel.id),i,side]
			_window(n,Vector3(0,1.74,z),3.35,0,key)
	decor.furnish(n,Vector3.ZERO,sz.x,sz.y,parcel.style,i,shaft)
	if parcel.style=="cells":
		for side in [-1,1]:
			for row in range(-2,3):
				for bar in 6:
					slab(n,Vector3(side*half.x*.49,1.45,row*6+bar*.53),Vector3(.08,2.9,.08),Color("455459"))
				slab(n,Vector3(side*half.x*.75,1.42,row*6-1.2),Vector3(half.x*.5,2.84,.16),wall)
	if parcel.tier=="empire" and i==0:
		var brass=Color("b99859")
		for x in [-1,1]:
			for z in [-1,0,1]:
				var at=Vector3(x*half.x*.71,1.65,z*half.y*.61)
				slab(n,at,Vector3(.75,3.3,.75),Color("554e48"))
				slab(n,at+Vector3(0,1.62,0),Vector3(1.02,.16,1.02),brass)
		w.make_sign(n,Vector3(0,2.25,-half.y+.22),"EMPIRE STATE\nOBSERVATORY  •  86",.017)

	_pack(n)

func _window(n,at,span,rotate,key):
	if w.broken_glass.has(key):return
	var pane=preload("res://bay/glazing.gd").new()
	n.add_child(pane);pane.position=at;pane.rotation.y=rotate
	pane.world=w;pane.key=key
	w.collision_box(pane,Vector3.ZERO,Vector3(span,2.62,.08))
	w.box(pane,Vector3.ZERO,Vector3(span,2.62,.08),Color.WHITE).material_override=w.glass

func _escape(n,i,half):
	var rear=-int(parcel.face)
	var y=0.
	var z=rear*half.y
	var metal=Color("526062")
	var end_x=minf(7.9,half.x-1.15)
	var inner=z+rear*1.23
	var outer=z+rear*3.08
	# Last and first tread terminate on the same surface as the landing.
	var landing=Vector3(-.28,y-.09,z+rear*2.05)
	slab(n,landing,Vector3(2.38,.18,4.10),metal)
	slab(n,landing+Vector3(-1.15,.56,0),Vector3(.085,1.12,4.1),metal)
	slab(n,landing+Vector3(.06,.56,rear*1.99),Vector3(2.15,1.12,.085),metal)
	if i==floors:return
	var mid=Vector3(end_x+.56,y+1.81,(inner+outer)*.5)
	slab(n,mid,Vector3(1.4,.18,3.45),metal)
	slab(n,mid+Vector3(.64,.57,0),Vector3(.08,1.14,3.45),metal)
	var first=Vector3(.80,y,outer)
	var pivot=Vector3(end_x,y+1.9,outer)
	var second=Vector3(end_x,y+1.9,inner)
	var top=Vector3(.80,y+3.8,inner)
	for flight in [[first,pivot],[second,top]]:
		var a=flight[0];var b=flight[1]
		var slope=slab(n,(a+b)*.5-Vector3.UP*.085,Vector3(a.distance_to(b),.17,1.72),metal)
		slope.rotation.z=atan((b.y-a.y)/(b.x-a.x))
		for s in [-1,1]:
			var rail=slab(n,(a+b)*.5+Vector3(0,.51,s*.84),Vector3(a.distance_to(b),1.03,.065),Color("737f7e"))
			rail.rotation.z=slope.rotation.z
		for j in 12:
			var foot=a.lerp(b,(j+.5)/12.)
			slab(n,foot+Vector3.UP*.055,Vector3(absf(a.x-b.x)/12.,.10,1.67),Color("7c8583"),false)

func _pack(n):
	# Batch each streamed floor into two draw calls. Colliders retain the exact
	# transforms of the visible elements, including sloped exterior flights.
	var body=StaticBody3D.new()
	n.add_child(body)
	var batches=[[],[]]
	for child in n.get_children():
		if not child is MeshInstance3D or not child.material_override is StandardMaterial3D:continue
		var primitive=child.mesh
		var cylinder=primitive is CylinderMesh
		if not cylinder and not primitive is BoxMesh:continue
		var scale3=Vector3(primitive.top_radius*2,primitive.height,primitive.top_radius*2) if cylinder else primitive.size
		var transform3=child.transform
		transform3.basis=transform3.basis.scaled_local(scale3)
		batches[int(cylinder)].append([transform3,child.material_override.albedo_color])
		for source in child.get_children():
			if source is StaticBody3D:
				for c in source.get_children():
					if c is CollisionShape3D:
						var local_pose=child.transform*source.transform*c.transform
						c.reparent(body,false);c.transform=local_pose
		child.free()
	for type_id in 2:
		if batches[type_id].is_empty():continue
		var mm=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.use_colors=true
		mm.mesh=w.room_units[type_id]
		mm.instance_count=batches[type_id].size()
		for j in mm.instance_count:
			mm.set_instance_transform(j,batches[type_id][j][0]);mm.set_instance_color(j,batches[type_id][j][1])
		var render=MultiMeshInstance3D.new()
		render.multimesh=mm;n.add_child(render)
