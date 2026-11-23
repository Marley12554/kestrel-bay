extends SkeletonModifier3D

var reach := 0.
var target := Vector3.ZERO

func _process_modification() -> void:
	if reach <= 0.: return
	var skeleton := get_skeleton()
	var local_target := skeleton.to_local(target)
	for pair in [["upperarm_r", "lowerarm_r"], ["lowerarm_r", "hand_r"]]:
		var joint := skeleton.find_bone(pair[0])
		var next := skeleton.find_bone(pair[1])
		var pose := skeleton.get_bone_global_pose(joint)
		var limb := skeleton.get_bone_global_pose(next).origin - pose.origin
		var direction := local_target - pose.origin
		if direction.length_squared() < .0001: continue
		var swing := Quaternion(limb.normalized(), direction.normalized())
		pose.basis = Basis(Quaternion.IDENTITY.slerp(swing, reach)) * pose.basis
		skeleton.set_bone_global_pose(joint, pose)
