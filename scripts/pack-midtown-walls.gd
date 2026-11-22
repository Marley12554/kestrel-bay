extends SceneTree

func _initialize() -> void:
	var walls := ResourceLoader.load(ProjectSettings.globalize_path("res://../dist/midtown-source/walls.tres")) as ConcavePolygonShape3D
	if not walls:
		quit(1)
		return
	# The survey contains continuous walls. Split only the Fifth Avenue face
	# at the Reserve's working entrance, retaining both adjoining wall segments.
	var frame:=Transform3D(Basis(Vector3.UP,-atan2(.488,.873)),Vector3(-208.099,0,573.891))
	var faces:=walls.get_faces()
	var clipped:=PackedVector3Array()
	var cut:=false
	for i in range(0,faces.size(),6):
		var a:=faces[i]
		var b:=faces[i+5]
		var p:=frame.affine_inverse()*a
		var q:=frame.affine_inverse()*b
		if absf(p.x-64.8)<.5 and absf(q.x-64.8)<.5 and maxf(p.z,q.z)>-23.24 and minf(p.z,q.z)<-19.03 and absf(p.z-q.z)>.001:
			var t1:=(-23.24-p.z)/(q.z-p.z)
			var t2:=(-19.03-p.z)/(q.z-p.z)
			var start:=clampf(minf(t1,t2),0.,1.)
			var end:=clampf(maxf(t1,t2),0.,1.)
			if start>0.: append_wall(clipped,a,a.lerp(b,start))
			if end<1.: append_wall(clipped,a.lerp(b,end),b)
			cut=true
		else:
			for j in 6: clipped.append(faces[i+j])
	if not cut:
		push_error("Reserve entrance did not intersect the street survey")
		quit(1)
		return
	walls.set_faces(clipped)
	quit(ResourceSaver.save(walls, "res://meshes/footprints.res", ResourceSaver.FLAG_COMPRESS))

func append_wall(out:PackedVector3Array,a:Vector3,b:Vector3) -> void:
	var up:=Vector3.UP*3.
	out.append_array(PackedVector3Array([a,a+up,b+up,a,b+up,b]))
