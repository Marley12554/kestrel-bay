extends Node3D

const MODELS := [preload("res://people/sam.glb"), preload("res://people/harper.glb"),
		preload("res://people/jordan.glb"), preload("res://people/maya.glb")]
@export_range(0, 3) var variant := 0
var model: Node3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var walk_clip: StringName

func _ready() -> void:
	model = MODELS[variant].instantiate()
	model.rotation.y = PI # The imported characters face +Z. Street actors face -Z.
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	walk_clip = &"Walk_Relaxed" if animator.has_animation(&"Walk_Relaxed") else &"Walk_Carry"
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		mesh.visibility_range_end = 145.
	for clip in [&"Idle_Standing", walk_clip]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	set_pace(0.)

func set_pace(metres_per_second: float) -> void:
	var clip := walk_clip if metres_per_second > .05 else &"Idle_Standing"
	if metres_per_second > 3. and animator.has_animation(&"Run"): clip = &"Run"
	if animator.current_animation != clip:
		animator.play(clip, .18)
	var clip_speed := 4.5 if clip == &"Run" else (1.2 if variant == 2 else 1.3)
	animator.speed_scale = metres_per_second / clip_speed if metres_per_second > .05 else 1.

func sit() -> void:
	animator.play(&"Sit_Stand", 0.)
	animator.seek(3., true)
	animator.pause()

func shadow_only(on: bool) -> void:
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
