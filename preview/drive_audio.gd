extends Node3D

const MUTED_DB := -72.0

var motor := AudioStreamPlayer.new()
var skid := AudioStreamPlayer.new()
var tires := AudioStreamPlayer.new()
var forward_warning := AudioStreamPlayer3D.new()
var reverse_warning := AudioStreamPlayer3D.new()
var turn_signal := AudioStreamPlayer.new()

func _ready() -> void:
	setup_loop(motor, preload("res://audio/sedan_drive.wav"))
	setup_loop(skid, preload("res://audio/tire_scrub.wav"))
	setup_loop(tires, preload("res://audio/sedan_road.wav"))
	setup_loop(forward_warning, preload("res://audio/tesla_forward.wav"))
	setup_loop(reverse_warning, preload("res://audio/tesla_reverse.wav"))
	turn_signal.stream = preload("res://audio/turn_signal.wav")
	turn_signal.volume_db = -16.0
	for speaker in [forward_warning, reverse_warning]:
		speaker.unit_size = 3.5
		speaker.max_distance = 45.
		speaker.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	forward_warning.position = Vector3(0,.38,-1.9)
	reverse_warning.position = Vector3(0,.4,1.85)
	add_child(turn_signal)

func setup_loop(player, clip: AudioStreamWAV) -> void:
	var loop := clip.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	player.stream = loop
	player.volume_db = MUTED_DB
	add_child(player)

func update(speed: float, load_amount: float, cornering: float, dt: float, slip_angle: float = 0.0, snow_cover: float = 0.0) -> void:
	if not motor.playing:
		motor.play()
		tires.play()
		forward_warning.play()
		reverse_warning.play()
	var blend := 1.0 - exp(-8.0 * dt)
	var road_speed := absf(speed)
	var pace := clampf(road_speed / 58.0, 0.0, 1.0)
	var motor_load := clampf(load_amount * signf(speed), 0.0, 1.0)
	var motor_pitch := .94 + 1.65 * pow(pace, .72) + .12 * motor_load
	var motor_gain_db := lerpf(-37.0, -17.0, smoothstep(0.0, 20.0, road_speed)) + 4.0 * motor_load
	motor.pitch_scale = lerpf(motor.pitch_scale, motor_pitch, blend)
	motor.volume_db = lerpf(motor.volume_db, motor_gain_db, blend)

	# A steady rolling bed stays distinct from the rear tires sliding sideways.
	var scrub := clampf(absf(cornering) / 24.0, 0.0, 1.0)
	var road_gain := smoothstep(0.0, 25.0, road_speed) * lerpf(.045, .095, scrub)
	tires.pitch_scale = lerpf(tires.pitch_scale, .72 + .5 * pace, blend)
	tires.volume_db = lerpf(tires.volume_db, linear_to_db(maxf(.00025, road_gain)), blend)

	var slip_speed := road_speed * absf(sin(slip_angle))
	var skid_gain := lerpf(.42,.095,snow_cover) * smoothstep(.5, 5.2, slip_speed)
	skid.volume_db = lerpf(skid.volume_db, linear_to_db(maxf(.00025, skid_gain)), blend)
	skid.pitch_scale = lerpf(.76,.51,snow_cover) + .36 * smoothstep(0., 12., slip_speed)
	if skid_gain > .001 and not skid.playing: skid.play()
	elif skid_gain <= .001 and skid.volume_db < -54.: skid.stop()

	# Model 3 exterior speaker spectrum, fading out at about 25 mph.
	var forward_gain := .22 * smoothstep(.02, .8, speed) * (1.0 - smoothstep(4.0, 11.18, speed))
	var reverse_gain := .32 * smoothstep(.02, .8, -speed)
	forward_warning.volume_db = lerpf(forward_warning.volume_db, linear_to_db(maxf(.00025, forward_gain)), blend)
	reverse_warning.volume_db = lerpf(reverse_warning.volume_db, linear_to_db(maxf(.00025, reverse_gain)), blend)

func play_turn_signal(lit: bool) -> void:
	turn_signal.stream = preload("res://audio/turn_signal.wav") if lit else preload("res://audio/turn_signal_off.wav")
	turn_signal.play()

func park() -> void:
	turn_signal.stop()
	for player in [motor, tires, skid, forward_warning, reverse_warning]:
		player.stop()
		player.volume_db = MUTED_DB
