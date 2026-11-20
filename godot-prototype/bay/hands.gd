extends Node3D

const CONTACT=.16
const DURATION=.41
const REACH=1.55
var ops
var wrists=[]
var arms=[]
var elapsed=-1.
var side=1
var queued=false
var landed=false
var rest=0.

func configure(director):
	ops=director
	var w=ops.world
	for sign_x in [-1,1]:
		var wrist=Node3D.new()
		add_child(wrist);wrists.append(wrist)
		var skin=Color("b58b6e")
		w.box(wrist,Vector3.ZERO,Vector3(.11,.096,.125),skin)
		for i in 4:
			w.box(wrist,Vector3((i-1.5)*.025,.019,-.060),Vector3(.026,.055,.042),skin.lightened(.05))
		var thumb=w.box(wrist,Vector3(-sign_x*.047,-.02,-.035),Vector3(.049,.049,.087),skin.darkened(.08))
		thumb.rotation.z=sign_x*.35
		arms.append(w.box(self,Vector3.ZERO,Vector3(.103,.107,1.),Color("3c5159")))
	hide()

func available()->bool:
	var p=ops.world.player
	return ops.weapon_slot==0 and ops.hp>0 and not p.vehicle and not ops.map_open and not ops.puzzle and not ops.modal and not ops.lock_target

func press():
	if not available():return
	if elapsed<0:begin()
	elif elapsed>=CONTACT:queued=true

func begin():
	side=1-side
	elapsed=0.
	queued=false
	landed=false
	rest=.48
	show()
	pose()

func cancel():
	elapsed=-1.;queued=false;rest=0.
	hide()

func tick(dt:float):
	if not visible:return
	if not available():cancel();return
	if elapsed>=0:
		elapsed+=dt
		if elapsed>=CONTACT and not landed:
			landed=true
			resolve_hit()
		if elapsed>=DURATION:
			if queued:begin()
			else:elapsed=-1.
	else:
		rest-=dt
		if rest<=0:hide();return
	pose()

func pose():
	for i in 2:
		var sign_x=-1. if i==0 else 1.
		var reach=0.
		var draw=0.
		if i==side and elapsed>=0:
			draw=sin(PI*clampf(elapsed/.06,0.,1.))
			reach=smoothstep(.045,CONTACT,elapsed)*(1.-smoothstep(CONTACT+.012,DURATION,elapsed))
		var guard=Vector3(sign_x*.235,-.195,-.49)
		var wrist=wrists[i]
		wrist.position=guard.lerp(Vector3(sign_x*.048,-.055,-.92),reach)+Vector3(sign_x*.025,-.025,.05)*draw
		wrist.rotation=Vector3(-.14+.28*reach,sign_x*.13,sign_x*(.32-.97*reach))
		var elbow=Vector3(sign_x*(.32-.095*reach),-.38+.13*reach,-.23-.22*reach)
		var end=wrist.position+Vector3(0,-.012,.048)
		var arm=arms[i]
		arm.position=(elbow+end)*.5
		arm.look_at(to_global(end))
		arm.scale.z=elbow.distance_to(end)

func resolve_hit():
	var camera=ops.world.player.camera
	var origin=camera.global_position
	var ray=PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*REACH,1|2|8,[ops.world.player.get_rid()])
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		ops.audio.effect("swing",origin,-9.)
		return
	var victim=hit.collider.get_meta("target",hit.collider)
	if victim.has_method("receive_punch"):victim.receive_punch()
	ops.audio.effect("thud",hit.position,-5.)
