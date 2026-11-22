extends Node

const MUTED_DB := -72.0

var motor := AudioStreamPlayer.new()
var tires := AudioStreamPlayer.new()
var forward_warning := AudioStreamPlayer.new()
var reverse_warning := AudioStreamPlayer.new()
var turn_signal := AudioStreamPlayer.new()

func _ready() -> void:
	setup_loop(motor, preload("res://audio/sedan_drive.wav"))
	setup_loop(tires, preload("res://audio/sedan_road.wav"))
	setup_loop(forward_warning, preload("res://audio/tesla_forward.wav"))
	setup_loop(reverse_warning, preload("res://audio/tesla_reverse.wav"))
	turn_signal.stream = preload("res://audio/turn_signal.wav")
	turn_signal.volume_db = -8.0
	add_child(turn_signal)

func setup_loop(player: AudioStreamPlayer, clip: AudioStreamWAV) -> void:
	var loop := clip.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	player.stream = loop
	player.volume_db = MUTED_DB
	add_child(player)

func update(speed: float, load_amount: float, cornering: float, dt: float) -> void:
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
	var motor_gain_db := lerpf(-48.0, -13.0, smoothstep(0.0, 12.0, road_speed)) + 5.0 * motor_load
	motor.pitch_scale = lerpf(motor.pitch_scale, motor_pitch, blend)
	motor.volume_db = lerpf(motor.volume_db, motor_gain_db, blend)

	# The measured pass-by supplies the rolling sound under the drivetrain.
	var scrub := clampf(absf(cornering) / 24.0, 0.0, 1.0)
	var road_gain := smoothstep(0.0, 25.0, road_speed) * lerpf(.045, .095, scrub)
	tires.pitch_scale = lerpf(tires.pitch_scale, .72 + .5 * pace, blend)
	tires.volume_db = lerpf(tires.volume_db, linear_to_db(maxf(.00025, road_gain)), blend)

	# The forward warning fades near 19 mph. Reverse has its own recorded whine.
	var forward_gain := .32 * smoothstep(.05, 1.0, speed) * (1.0 - smoothstep(6.0, 8.9, speed))
	var reverse_gain := .40 * smoothstep(.05, 1.0, -speed)
	forward_warning.pitch_scale = lerpf(forward_warning.pitch_scale, 1.04 + .26 * clampf(speed / 8.9, 0.0, 1.0), blend)
	reverse_warning.pitch_scale = lerpf(reverse_warning.pitch_scale, .96 + .34 * clampf(-speed / 6.0, 0.0, 1.0), blend)
	forward_warning.volume_db = lerpf(forward_warning.volume_db, linear_to_db(maxf(.00025, forward_gain)), blend)
	reverse_warning.volume_db = lerpf(reverse_warning.volume_db, linear_to_db(maxf(.00025, reverse_gain)), blend)

func play_turn_signal(lit: bool) -> void:
	turn_signal.pitch_scale = 1.0 if lit else .86
	turn_signal.play()

func park() -> void:
	turn_signal.stop()
	for player: AudioStreamPlayer in [motor, tires, forward_warning, reverse_warning]:
		player.stop()
		player.volume_db = MUTED_DB
