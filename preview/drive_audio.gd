extends Node

var motor := AudioStreamPlayer.new()
var tires := AudioStreamPlayer.new()

func _ready() -> void:
	for pair in [[motor,preload("res://audio/sedan_drive.wav")],[tires,preload("res://audio/sedan_road.wav")]]:
		var player: AudioStreamPlayer=pair[0]
		var loop: AudioStreamWAV=pair[1].duplicate()
		loop.loop_mode=AudioStreamWAV.LOOP_FORWARD
		loop.loop_end=loop.get_length()*loop.mix_rate
		player.stream=loop
		player.volume_db=-62
		add_child(player)

func update(speed: float, load_amount: float, cornering: float, dt: float) -> void:
	if not motor.playing:
		motor.play()
		tires.play()
	var blend := 1.0 - exp(-8.0 * dt)
	var road_speed := absf(speed)
	var pace := clampf(road_speed / 58.0, 0.0, 1.0)
	var motor_load := clampf(load_amount * signf(speed), 0.0, 1.0)
	var motor_pitch := .72 + 1.36 * pow(pace, .72) + .08 * motor_load
	var motor_gain_db := lerpf(-39.0, -15.0, smoothstep(0.0, 12.0, road_speed)) + 5.0 * motor_load
	motor.pitch_scale = lerpf(motor.pitch_scale, motor_pitch, blend)
	motor.volume_db = lerpf(motor.volume_db, motor_gain_db, blend)

	# Keep the road hiss under the motor tone, even when the tires scrub.
	var scrub := clampf(absf(cornering) / 24.0, 0.0, 1.0)
	var road_gain := smoothstep(0.0, 25.0, road_speed) * lerpf(.045, .095, scrub)
	tires.pitch_scale = lerpf(tires.pitch_scale, .72 + .5 * pace, blend)
	tires.volume_db = lerpf(tires.volume_db, linear_to_db(maxf(.0006, road_gain)), blend)

func park() -> void:
	for player: AudioStreamPlayer in [motor,tires]:
		player.stop()
		player.volume_db=-62
