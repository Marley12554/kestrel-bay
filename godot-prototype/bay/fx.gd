extends Node3D
var w
var rng=RandomNumberGenerator.new()
var clouds=[]
var short_lived=[]
var skid_marks=[]
var free_sprites=[]
var live=[]
var textures={}
var smoke_fade=[]
var shots=0
func configure(world):
	w=world
	process_mode=Node.PROCESS_MODE_PAUSABLE
	rng.seed=610
	var quad=QuadMesh.new()
	var gradient=Gradient.new()
	gradient.offsets=PackedFloat32Array([0.,.44,.77,1.])
	gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.88),Color(1,1,1,.30),Color(1,1,1,0)])
	var stamp=GradientTexture2D.new()
	stamp.width=64;stamp.height=64;stamp.gradient=gradient
	stamp.fill=GradientTexture2D.FILL_RADIAL;stamp.fill_from=Vector2(.5,.5);stamp.fill_to=Vector2(1.,.5)
	for entry in [["flash",Color("fff1a6")],["flame",Color("ff8a27")],["spark",Color("ffd77c")],["smoke",Color("534e4e")],["dust",Color("a79883")]]:
		var mat=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.billboard_keep_scale=true
		mat.albedo_color=entry[1];mat.albedo_texture=stamp
		textures[entry[0]]=mat
	for i in 12:
		var smoke=textures["smoke"].duplicate()
		smoke.albedo_color=Color(.30,.29,.29,(i+1.)/12.)
		smoke_fade.append(smoke)
	for i in 96:
		var sprite=MeshInstance3D.new()
		sprite.mesh=quad;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.hide();add_child(sprite);free_sprites.append(sprite)

func warm_up(camera:Camera3D,visible_now:bool):
	# Exercise the alpha-blended effects pipeline while the loading cover is up.
	for i in textures.size():
		var sprite=free_sprites[i]
		sprite.visible=visible_now
		if visible_now:
			sprite.global_position=camera.to_global(Vector3((i-2)*.16,0,-1.4))
			sprite.material_override=textures[textures.keys()[i]]
			sprite.scale=Vector3.ONE*.14

func puff(kind:String,at:Vector3,motion:Vector3,size:float,growth:float,life:float):
	if free_sprites.is_empty():return
	var sprite=free_sprites.pop_back()
	sprite.position=at;sprite.scale=Vector3.ONE*size;sprite.material_override=textures[kind];sprite.show()
	live.append({"node":sprite,"v":motion,"size":size,"growth":growth,"life":life,"age":0.,"kind":kind})

func shot(a:Vector3,b:Vector3,impact:bool):
	var delta=b-a
	if delta.length_squared()<.001:return
	var f=delta.normalized()
	puff("flash",a+f*.12,Vector3.ZERO,.16,.35,.055)
	if impact:puff("dust",b-f*.045,Vector3.UP*.8,.13,1.6,.23)
	shots+=1
	if shots%3==0 and delta.length()>6:
		puff("spark",a+f*.7,f*180.,.115,0.,minf(.075,(delta.length()-.8)/180.))

var wall_scars=[]
func crash(at:Vector3,normal:Vector3,force:float,masonry:bool):
	for i in clampi(int(force*.4),2,10):
		puff("dust",at+normal*.09,normal*rng.randf_range(.5,2.)+Vector3.UP*rng.randf_range(.3,1.5),.14,1.8,.48)
	if not masonry:return
	var side=normal.cross(Vector3.UP).normalized()
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var start=at+normal*.038+side*rng.randf_range(-.51,.51)+Vector3.UP*rng.randf_range(-.17,.24)
		var end=start+side*rng.randf_range(-.25,.35)+Vector3.UP*rng.randf_range(.16,.43)
		for p in [start-side*.042,end,start+side*.04]:st.set_normal(normal);st.add_vertex(p-at)
	var scar=MeshInstance3D.new()
	scar.mesh=st.commit()
	var mat=w.material(Color("534c45")).duplicate()
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	scar.material_override=mat
	add_child(scar);scar.position=at
	wall_scars.append(scar)
	if wall_scars.size()>32:wall_scars.pop_front().queue_free()
func rim_sparks(at:Vector3,motion:Vector3):
	for i in 3:
		var offset=Vector3(rng.randf_range(-1.,1.),rng.randf_range(.6,2.1),rng.randf_range(-1.,1.))
		puff("spark",at,motion*.25+offset,.075,0.,rng.randf_range(.12,.34))
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
	var origin=at+Vector3.UP*.82
	puff("flash",origin,Vector3.UP,4.,28.,.22)
	for i in 17:
		var dir=Vector3(cos(i*2.4),rng.randf_range(.15,.8),sin(i*2.4)).normalized()
		puff("flame",origin+dir*.6,dir*rng.randf_range(10.,24.),2.5,10.,rng.randf_range(.50,.85))
		puff("spark",origin,dir*rng.randf_range(19.,30.),.17,0.,rng.randf_range(.44,.88))
		var drift=dir*rng.randf_range(.8,1.8)+Vector3(.40,.60,0)
		puff("smoke",origin+dir*rng.randf_range(1.,3.),drift,2.,2.4,rng.randf_range(5.8,7.8))
	clouds.append([origin+Vector3.UP*2.5,8.,w.clock+5.8])
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
func wake(at):
	var n=w.box(self,at+Vector3.UP*.28,Vector3(.8,.055,1.58),Color("c2d7cd"))
	n.rotation.y=rng.randf()*PI
	short_lived.append([n,w.clock+.38])
func _process(dt):
	if not w or not w.started:return
	for i in range(live.size()-1,-1,-1):
		var p=live[i]
		p.age+=dt
		if p.age>=p.life:
			p.node.hide();free_sprites.append(p.node);live.remove_at(i);continue
		var fade=1.-smoothstep(.60,1.,p.age/p.life)
		p.node.scale=Vector3.ONE*maxf(.001,(p.size+p.growth*p.age)*fade)
		if p.kind=="smoke":p.node.material_override=smoke_fade[clampi(ceili(fade*12.)-1,0,11)]
		p.node.position+=p.v*dt
		if p.kind=="spark":p.v.y-=dt*9.
		if p.kind=="flame":p.v*=exp(-dt*1.4)
	for group in [short_lived,skid_marks]:
		for i in range(group.size()-1,-1,-1):
			if w.clock>group[i][1]:group[i][0].queue_free();group.remove_at(i)
	while clouds.size() and clouds[0][2]<w.clock:clouds.pop_front()
