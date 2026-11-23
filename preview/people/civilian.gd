extends Node3D

const MODELS := [preload("res://people/sam.glb"), preload("res://people/harper.glb"),
		preload("res://people/jordan.glb"), preload("res://people/maya.glb")]
const GAITS := [preload("res://people/sam-walks.res"), preload("res://people/harper-walks.res"),
		preload("res://people/jordan-walks.res"), preload("res://people/maya-walks.res")]
@export_range(0, 3) var variant := 0
var model: Node3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var walk_clip := &"street/Walk"
var stride_speed := 1.36
var walk_phase := 0.

func _ready() -> void:
	model = MODELS[variant].instantiate()
	model.rotation.y = PI # The imported characters face +Z. Street actors face -Z.
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	animator.add_animation_library(&"street", GAITS[variant])
	select_stride(1.36, 0.)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		mesh.visibility_range_end = 145.
	for clip in [&"Idle_Standing", walk_clip]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	set_pace(0.)

func select_stride(pace: float, phase: float) -> void:
	walk_clip = &"street/Stroll" if pace < 1.18 else (&"street/Brisk" if pace > 1.59 else &"street/Walk")
	var clip := animator.get_animation(walk_clip)
	var stature := skeleton.global_basis.get_scale().y
	# The captures are in metres. Scale cadence to the length of this rig's legs.
	var hip_height := skeleton.get_bone_global_rest(skeleton.find_bone("thigh_l")).origin.y * stature
	stride_speed = float(clip.get_meta("stride_speed")) * hip_height / .91
	walk_phase = phase

func set_pace(metres_per_second: float) -> void:
	var clip := walk_clip if metres_per_second > .05 else &"Idle_Standing"
	if metres_per_second > 3. and animator.has_animation(&"Run"): clip = &"Run"
	if animator.current_animation != clip:
		animator.play(clip, .2)
		if clip == walk_clip:
			animator.seek(walk_phase * animator.get_animation(clip).length, false)
	var clip_speed := 4.5 if clip == &"Run" else stride_speed
	animator.speed_scale = metres_per_second / clip_speed if metres_per_second > .05 else 1.

func sit() -> void:
	animator.play(&"Sit_Stand", 0.)
	animator.seek(3., true)
	animator.pause()
	# The chair clip puts the shins nearly vertical. In the driver's seat
	# they extend under the dash, with level shoes resting by the pedals.
	var pedal_direction := skeleton.global_basis.inverse() * (global_basis * Vector3(0., -.25, -.97))
	for side in ["_l", "_r"]:
		var calf := skeleton.find_bone("calf" + side)
		var foot := skeleton.find_bone("foot" + side)
		var shin := skeleton.get_bone_global_pose(calf)
		var shoe := skeleton.get_bone_global_pose(foot)
		var ankle := shoe.origin - shin.origin
		shin.basis = Basis(Quaternion(ankle.normalized(), pedal_direction.normalized())) * shin.basis
		skeleton.set_bone_global_pose(calf, shin)
		# The shoe is independently rigged, so moving the shin alone leaves
		# the shoe in its original position below the floor pan.
		shoe.origin = shin.origin + pedal_direction.normalized() * ankle.length()
		skeleton.set_bone_global_pose(foot, shoe)

func shadow_only(on: bool) -> void:
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
