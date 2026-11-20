extends RefCounted
# Used only by deterministic test scenarios. Drives with the same steering,
# accelerator and brake inputs available to the player.
var w
var route=PackedVector3Array()
var final_position=Vector3.ZERO
var elapsed=0.
var underway=false
var cruise=13.5
var progress=0.
var previous=Vector3.ZERO
var segment=0
var stall=0.
var limit=740.
var passing_side=0.
var passing_until=0.
var finished=false
var hotel_walk=false
var footpath=PackedVector3Array()
var timer=0.
var label=""
func configure(world,car,line,pace,scenario):
	w=world;route=line;cruise=pace;label=scenario
	var start=line[0];var f=(line[1]-start).normalized()
	car.position=start+f*4+f.cross(Vector3.UP)*2.8+Vector3.UP*.16
	car.rotation=Vector3(0,atan2(-f.x,-f.z),0);car.velocity=Vector3.ZERO;car.speed=0
	w.player.reset_player(car.position+Vector3.UP)
	w.player.board(car);previous=car.position;elapsed=0.;progress=0.;segment=0;stall=0.;underway=true;finished=false;hotel_walk=false
	final_position=line[-1]
func update(dt):
	if not underway:return
	var p=w.player
	if hotel_walk:
		timer+=dt
		var to=footpath[0]-p.position
		to.y=0
		if to.length()<.70:
			footpath.remove_at(0)
			if footpath.is_empty():p.analog=Vector2.ZERO;underway=false;finished=true
			return
		p.yaw=atan2(-to.x,-to.z);p.analog=Vector2(0,-1)
		if timer>22:underway=false;p.analog=Vector2.ZERO
		return
	if not p.vehicle:underway=false;p.analog=Vector2.ZERO;return
	var v=p.vehicle
	elapsed+=dt
	var delta=v.position.distance_to(previous)
	progress+=delta
	previous=v.position
	if v.speed<1 and elapsed>4:stall+=dt
	else:stall=0
	if elapsed>limit or stall>18:
		underway=false;p.analog=Vector2.ZERO;return
	var a=route[segment]
	var b=route[segment+1]
	var f=(b-a).normalized()
	var along=(v.position-a).dot(f)
	var remain=a.distance_to(b)-along
	if remain<3.2 or v.position.distance_to(b)<4.:
		if segment>=route.size()-2:
			p.analog=Vector2.ZERO;p.mobile_brake=true
			if v.speed<.7:
				if label=="bridge":
					p.interact()
					if not p.vehicle:
						p.mobile_brake=false;hotel_walk=true;timer=0.
						final_position=w.atlas.plots["Battery House Hotel"].at+Vector3(0,0,9)
						var door=w.atlas.marks["Battery House Hotel"]
						var bumper=p.position-v.global_basis.z*4.2
						footpath=PackedVector3Array([bumper,Vector3(bumper.x,door.y,door.z+2),door+Vector3.BACK*2,final_position])
				else:
					underway=false;finished=true;p.mobile_brake=false
			return
		segment+=1
		a=b;b=route[segment+1];f=(b-a).normalized()
		along=(v.position-a).dot(f);remain=a.distance_to(b)-along
	var desired=cruise
	var preview=clampf(v.speed*.56+3.,3.8,14.)
	var point=a+f*clampf(along+preview,0,a.distance_to(b))+f.cross(Vector3.UP)*2.75
	if segment+2<route.size():
		var following=(route[segment+2]-b).normalized()
		var bend=acos(clampf(following.dot(f),-1,1))
		if bend>.33:
			desired=minf(desired,sqrt(maxf(0,remain-4)*5.8+23.))
		if remain<preview:
			point=b+following*(preview-remain)+following.cross(Vector3.UP)*2.75
	elif remain<27:
		desired=minf(cruise,sqrt(maxf(1,remain-1)*4.))
	if elapsed<passing_until:point+=f.cross(Vector3.UP)*passing_side*3.95
	var to=point-v.position
	var delta_yaw=wrapf(atan2(-to.x,-to.z)-v.rotation.y,-PI,PI)
	var steer=clampf(delta_yaw*2.85,-1.,1.)
	# Obey a slower car immediately ahead, with room to pass a stationary wreck.
	var start=v.position+Vector3.UP*.85
	var ray=PhysicsRayQueryParameters3D.create(start,start-v.global_basis.z*maxf(7,v.speed*1.04),2,[v.get_rid()])
	var hit=w.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.collider!=p and not hit.collider.police and hit.collider.speed<desired and absf(delta_yaw)<.35:
		if hit.collider.speed>2.:desired=maxf(2.,hit.collider.speed-1.)
		else:
			# Steer toward an actual bypass corridor until the rear axle clears.
			if elapsed>=passing_until:
				var side=f.cross(Vector3.UP)
				for s in [-1,1]:
					var off=side*s*4.0
					var q=PhysicsRayQueryParameters3D.create(start+off,start+off+f*15,3,[v.get_rid()])
					if w.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
						passing_side=s;passing_until=elapsed+3.5;break
			desired=minf(desired,6.)
	p.analog=Vector2(-steer,-desired/v.max_speed)
	p.mobile_brake=v.speed>desired+1.2
