extends Node3D
var w
var rng=RandomNumberGenerator.new()
var clouds=[]
var short_lived=[]
var skid_marks=[]
var cache={}
func configure(world):
	w=world
	process_mode=Node.PROCESS_MODE_PAUSABLE
	rng.seed=610
func plume(parent:Node3D,at:Vector3,flame:bool):
	var n=CPUParticles3D.new()
	n.amount=9 if flame else 12
	n.lifetime=.72 if flame else 2.3
	n.local_coords=false
	n.direction=Vector3.UP
	n.spread=19
	n.initial_velocity_min=1.5
	n.initial_velocity_max=3.1
	n.gravity=Vector3(.36,2.2,.2)
	n.scale_amount_min=.23 if flame else .49
	n.scale_amount_max=.63 if flame else 1.18
	var mesh=SphereMesh.new()
	mesh.radial_segments=5;mesh.rings=2;mesh.radius=.55;mesh.height=1.1
	var mat=w.material(Color("ef8639") if flame else Color("555758"),flame)
	mesh.material=mat
	n.mesh=mesh
	parent.add_child(n);n.position=at
	return n
func blast(at:Vector3,source):
	var radius=19.
	var p=w.player
	var distance=p.position.distance_to(at)
	var ignore:Array=[source.get_rid()]
	if p.vehicle:ignore.append(p.vehicle.get_rid())
	if distance<radius and w.ops.sight(at+Vector3.UP,p.position+Vector3.UP,ignore):
		w.ops.hurt(155.*pow(1-distance/radius,1.35))
	for v in w.vehicles:
		if v==source or v.wreck:continue
		var d=v.position.distance_to(at)
		if d<radius and w.ops.sight(at+Vector3.UP,v.position+Vector3.UP,[v.get_rid(),source.get_rid()]):v.take_damage(105.*(1.-d/radius))
	for n in w.ops.officers+w.residents:
		if is_instance_valid(n) and n.hp>0 and n.position.distance_to(at)<radius and w.ops.sight(at,n.position+Vector3.UP,[source.get_rid(),n.get_rid()]):
			n.take_damage(118.*(1.-at.distance_to(n.position)/radius))
	for i in 18:
		var angle=i*TAU/18
		var end=at+Vector3(cos(angle)*radius*rng.randf_range(.66,1.),rng.randf_range(2,10),sin(angle)*radius*rng.randf_range(.66,1.))
		var ember=plume(self,at,true)
		var tween=create_tween()
		tween.tween_property(ember,"position",end,.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		short_lived.append([ember,w.clock+1.1])
	for i in 9:
		var place=at+Vector3(rng.randf_range(-6,6),0,rng.randf_range(-6,6))
		var smoke=plume(self,place,false)
		smoke.scale_amount_min=1.5;smoke.scale_amount_max=3.4
		smoke.lifetime=3.4
		short_lived.append([smoke,w.clock+7.8])
	clouds.append([at+Vector3.UP*4,10.,w.clock+7.3])
	w.ops.audio.effect("blast",at,2)
func obscures(a:Vector3,b:Vector3)->bool:
	for cloud in clouds:
		if Geometry3D.get_closest_point_to_segment(cloud[0],a,b).distance_to(cloud[0])<cloud[1]:return true
	return false
func skid(car,strength):
	var now=[]
	for side in [-1,1]:now.append(car.position+car.global_basis*Vector3(side*.89,.105,1.35))
	if car.skid_prev.size()==2 and w.ops.on_pavement(car.position):
		for i in 2:
			var a=car.skid_prev[i]
			var b=now[i]
			if a.distance_to(b)<.1 or a.distance_to(b)>6:continue
			var mark=w.box(self,(a+b)*.5,Vector3(.12+.11*strength,.009,a.distance_to(b)),Color("4a4a46").lerp(Color("272b2b"),strength))
			mark.rotation.y=atan2(b.x-a.x,b.z-a.z)
			skid_marks.append([mark,w.clock+32])
	car.skid_prev=now
	while skid_marks.size()>110:skid_marks.pop_front()[0].queue_free()
func spray(at,water):
	var n=w.box(self,at+Vector3.UP*.28,Vector3(.8,.055,1.58 if water else .18),Color("c2d7cd") if water else Color("ffba57"))
	n.rotation.y=rng.randf()*PI
	short_lived.append([n,w.clock+.38])
func _process(_dt):
	if not w or not w.started:return
	for group in [short_lived,skid_marks]:
		for i in range(group.size()-1,-1,-1):
			if w.clock>group[i][1]:group[i][0].queue_free();group.remove_at(i)
	while clouds.size() and clouds[0][2]<w.clock:clouds.pop_front()
