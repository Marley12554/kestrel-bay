extends Node

const ROADS: BitMap = preload("res://meshes/road_mask.res")
const WALK_SPEED := 4.8 * 0.44704
const SPRINT_SPEED := 16.0 * 0.44704
const TAKES := 5
const FOV_RELEASE_RATE := 4.8

@onready var camera: Camera3D = $"../Camera"
@onready var blur: ColorRect = $"../Overlay/SprintBlur"
@onready var winter = get_node_or_null("../Winter")
var pavement := AudioStreamPlayer.new()
var snow := AudioStreamPlayer.new()
var hard_steps: Array[AudioStream] = []
var snow_steps: Array[AudioStream] = []
var last_take := -1
var left_foot := false
var phase := 0.5
var strength := 1.0
var activity := 0.0
var run_mix := 0.0
var fov_target := 0.0
var fov_mix := 0.0
var base_fov := 0.0

func _ready() -> void:
	for player in [pavement, snow]:
		add_child(player)
	for i in TAKES:
		hard_steps.append(load("res://audio/footstep_concrete_%03d.ogg" % i))
		snow_steps.append(load("res://audio/footstep_snow_%03d.ogg" % i))

func advance(at: Vector3, distance: float, dt: float, heading:=Vector2.ZERO) -> void:
	if base_fov == 0.0:
		base_fov = camera.fov
	var speed := distance / dt
	var effort := smoothstep(WALK_SPEED, SPRINT_SPEED, speed)
	run_mix = move_toward(run_mix, effort, dt * 5.0)
	activity = move_toward(activity, smoothstep(0.10, WALK_SPEED, speed), dt * 8.0)
	if speed > 0.10:
		# Each integer phase is a footfall. Full sprint covers more ground per step.
		var previous := floori(phase)
		phase = fmod(phase + distance / lerpf(0.98, 2.12, effort), 2.0)
		if floori(phase) != previous:
			var side := Vector2(-heading.y,heading.x)*(-.103 if left_foot else .103)
			play_step(at+Vector3(side.x,0.,side.y), effort, speed)
			if winter and not heading.is_zero_approx():
				winter.plant_foot(at,heading,left_foot,effort)
			left_foot=not left_foot
	elif activity == 0.0:
		phase = 0.5
	var amplitude := activity * strength
	camera.h_offset = sin(phase * PI) * lerpf(0.009, 0.022, run_mix) * amplitude
	camera.v_offset = -cos(phase * TAU) * lerpf(0.017, 0.034, run_mix) * amplitude
	# Two easing stages let the lens begin and end its return gently.
	# The rising sprint cue still follows the player's acceleration directly.
	var release := 1.0 - exp(-FOV_RELEASE_RATE * dt)
	fov_target = maxf(run_mix, lerpf(fov_target, run_mix, release))
	fov_mix = maxf(run_mix, lerpf(fov_mix, fov_target, release))
	camera.fov = base_fov + 4.0 * fov_mix * strength
	var smear := run_mix * strength
	if OS.has_feature("web"):
		# Soften peripheral ground detail in its existing pass; avoid copying
		# the Retina-sized framebuffer to a texture whenever a sprint starts.
		if winter and winter.street_material:
			winter.street_material.set_shader_parameter("sprint_softness", smear * 0.55)
	else:
		blur.visible = smear > 0.02
		if blur.visible:
			blur.material.set_shader_parameter("amount", smear)

func play_step(at: Vector3, effort: float, speed: float) -> void:
	var take := randi_range(0, TAKES - 1) if last_take < 0 else (last_take + randi_range(1, TAKES - 1)) % TAKES
	last_take = take
	var pixel := Vector2i(floori(at.x) + 1350, floori(at.z) + 1500)
	var road := Rect2i(Vector2i.ZERO, ROADS.get_size()).has_point(pixel) and ROADS.get_bitv(pixel)
	var cover: float = winter.snow_underfoot(at, road) if winter else 0.0
	var gain := lerpf(-10.0, -4.0, effort) + linear_to_db(clampf(speed / WALK_SPEED, 0.22, 1.0))
	var pitch_scale := randf_range(0.96, 1.04)
	layer(pavement, hard_steps[take], sqrt(1.0 - cover), gain, pitch_scale)
	layer(snow, snow_steps[take], sqrt(cover), gain, pitch_scale)

func layer(player: AudioStreamPlayer, clip: AudioStream, weight: float, gain: float, pitch_scale: float) -> void:
	if weight < 0.04:
		player.stop()
		return
	player.stream = clip
	player.volume_db = gain + linear_to_db(weight)
	player.pitch_scale = pitch_scale
	player.play()

func reset() -> void:
	phase = 0.5
	activity = 0.0
	run_mix = 0.0
	fov_target = 0.0
	fov_mix = 0.0
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	if base_fov > 0.0:
		camera.fov = base_fov
	blur.hide()
	if OS.has_feature("web") and winter and winter.street_material:
		winter.street_material.set_shader_parameter("sprint_softness", 0.0)
	pavement.stop()
	snow.stop()
