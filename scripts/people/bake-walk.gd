extends SceneTree
# godot --headless --path preview --script ../scripts/people/bake-walk.gd -- /tmp/walks.json

func _initialize() -> void:
	call_deferred("bake")

func vector(frame: Dictionary, key: String) -> Vector3:
	var xyz: Array = frame[key]
	return Vector3(xyz[0], xyz[1], xyz[2])

func torso_axes(lateral: Vector3, vertical: Vector3) -> Basis:
	var x := lateral.normalized()
	var z := x.cross(vertical).normalized()
	return Basis(x, z.cross(x), z)

func bake() -> void:
	var takes: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	for name in ["sam", "harper", "jordan", "maya"]:
		var actor: Node3D = load("res://people/" + name + ".glb").instantiate()
		root.add_child(actor)
		var rig: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
		var animator: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		var path := String(animator.get_node(animator.root_node).get_path_to(rig)) + ":"
		var lib := AnimationLibrary.new()
		for i in takes.size():
			lib.add_animation(["Walk", "Stroll", "Brisk"][i], gait(rig, path, takes[i]))
		var err := ResourceSaver.save(lib, "res://people/" + name + "-walks.res")
		if err != OK:
			quit(1)
			return
		actor.free()
	quit()

func gait(rig: Skeleton3D, path: String, take: Dictionary) -> Animation:
	var clip := Animation.new()
	clip.length = take.duration
	clip.loop_mode = Animation.LOOP_LINEAR
	clip.set_meta("stride_speed", take.speed)
	var tracks := {}
	var tips := {}
	for side in ["_l", "_r"]:
		for pair in [["thigh","calf"], ["calf","foot"], ["foot","ball"], ["upperarm","lowerarm"], ["lowerarm","hand"]]:
			tips[pair[0] + side] = rig.find_bone(pair[1] + side)
	var ankles := {}
	for side in ["_l","_r"]:
		var key := "foot" + str(side)
		ankles[key] = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(ankles[key], NodePath(path+key))
	var frames: Array = take.frames
	var pelvis := rig.find_bone("pelvis")
	var translation := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(translation, NodePath(path + "pelvis"))
	for j in frames.size():
		var frame: Dictionary = frames[j]
		var t := clip.length * j / (frames.size()-1.)
		var hips := torso_axes(vector(frame,"pelvis_axis"), Vector3.UP)
		var shoulders := torso_axes(vector(frame,"shoulder_axis"), vector(frame,"torso"))
		var head := torso_axes(vector(frame,"head_axis"), Vector3.UP)
		var pose: Array[Transform3D] = []
		for idx in rig.get_bone_count():
			var parent := rig.get_bone_parent(idx)
			var inherited := pose[parent] if parent >= 0 else Transform3D.IDENTITY
			var bone := inherited * rig.get_bone_rest(idx)
			var rest := rig.get_bone_global_rest(idx)
			var key := String(rig.get_bone_name(idx))
			var rotation := bone.basis.orthonormalized()
			var tracked := true
			if key == "pelvis":
				rotation = hips * rest.basis
			elif key.begins_with("spine_"):
				rotation = hips.slerp(shoulders, float(key.right(2)) / 3.) * rest.basis
			elif key == "neck_01" or key == "head":
				rotation = (head if key == "head" else shoulders.slerp(head,.55)) * rest.basis
			elif tips.has(key):
				var rest_vector := rig.get_bone_global_rest(tips[key]).origin - rest.origin
				var target := vector(frame,key).normalized()
				if key.begins_with("foot"):
					# Heel-to-toe markers are level in stance. The rig's toe joint is below the ankle.
					rotation = Basis(Quaternion(Vector3.BACK, target)) * rest.basis
				else:
					var inherited_direction := rotation * (rest.basis.inverse() * rest_vector)
					rotation = Basis(Quaternion(inherited_direction.normalized(), target)) * rotation
			else:
				tracked = false
			if tracked:
				bone.basis = rotation.orthonormalized()
				if not tracks.has(idx):
					tracks[idx] = clip.add_track(Animation.TYPE_ROTATION_3D)
					clip.track_set_path(tracks[idx], NodePath(path + key))
				var local := inherited.basis.inverse() * bone.basis
				clip.rotation_track_insert_key(tracks[idx], t, local.orthonormalized().get_rotation_quaternion())
			pose.append(bone)
		var travel := vector(frame,"travel") / rig.global_basis.get_scale().y
		# Both feet are independent IK roots in the source rigs. Drive their
		# translations from the posed shins so shoes and trousers stay together.
		for side in ["_l","_r"]:
			var foot := rig.find_bone("foot"+str(side))
			var toe := rig.find_bone("ball"+str(side))
			var calf := rig.find_bone("calf"+str(side))
			var ankle_offset := rig.get_bone_global_rest(calf).affine_inverse()*rig.get_bone_global_rest(foot).origin
			pose[foot].origin = pose[calf]*ankle_offset
			pose[toe] = pose[foot]*rig.get_bone_rest(toe)
		var ground := INF
		for name in ["foot_l","ball_l","foot_r","ball_r"]:
			var idx := rig.find_bone(name)
			ground = minf(ground, pose[idx].origin.y-rig.get_bone_global_rest(idx).origin.y)
		travel.y = -ground
		for key: String in ankles:
			var foot := rig.find_bone(key)
			clip.position_track_insert_key(ankles[key], t, pose[foot].origin + travel)
		var parent_pose := pose[rig.get_bone_parent(pelvis)]
		clip.position_track_insert_key(translation, t, rig.get_bone_rest(pelvis).origin + parent_pose.basis.inverse()*travel)
	return clip
