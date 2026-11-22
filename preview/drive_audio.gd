extends Node3D

const MUTED_DB := -72.0

var chirp := AudioStreamPlayer3D.new()
var chirp_armed := true
var skid := AudioStreamPlayer3D.new()
var tires := AudioStreamPlayer3D.new()
var forward_warning := AudioStreamPlayer3D.new()
var reverse_warning := AudioStreamPlayer3D.new()
var turn_signal := AudioStreamPlayer3D.new()

func _ready() -> void:
	chirp.stream = preload("res://audio/tire_scrub.wav")
	add_child(chirp)
	setup_loop(skid, preload("res://audio/tire_scuff.wav"))
	setup_loop(tires, preload("res://audio/sedan_road.wav"))
	setup_loop(forward_warning, preload("res://audio/tesla_forward.wav"))
	setup_loop(reverse_warning, preload("res://audio/tesla_reverse.wav"))
	turn_signal.stream = preload("res://audio/turn_signal.wav")
	# Mono emitters are transformed with the sedan. Let the active camera be
	# the listener, including during manual orbit and camera obstruction.
	chirp.position = Vector3(0.,.12,1.34)
	tires.position = Vector3(0.,.12,-1.30)
	skid.position = Vector3(0.,.12,1.34)
	turn_signal.position = Vector3(-.36,.94,-.55)
	for source in [chirp, tires, skid]:
		source.unit_size = 4.
		source.max_distance = 95.
		source.attenuation_filter_cutoff_hz = 6200.
	turn_signal.volume_db = -14.
	turn_signal.unit_size = 2.4
	turn_signal.max_distance = 18.
	turn_signal.attenuation_filter_cutoff_hz = 2400.
	for speaker in [forward_warning, reverse_warning]:
		speaker.unit_size = 3.5
		speaker.max_distance = 45.
		speaker.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	forward_warning.position = Vector3(0,.38,-1.9)
	reverse_warning.position = Vector3(0,.4,1.85)
	add_child(turn_signal)

func setup_loop(player: AudioStreamPlayer3D, clip: AudioStreamWAV) -> void:
	var loop := clip.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	player.stream = loop
	player.volume_db = MUTED_DB
	add_child(player)

func update(speed: float, cornering: float, dt: float, slip_angle: float = 0.0, snow_cover: float = 0.0) -> void:
	if not tires.playing:
		tires.play()
		forward_warning.play()
		reverse_warning.play()
	var blend := 1.0 - exp(-8.0 * dt)
	var road_speed := absf(speed)
	var pace := clampf(road_speed / 58.0, 0.0, 1.0)
	# Rolling sound starts with the first few feet of movement.
	var corner_load := clampf(absf(cornering) / 12., 0., 1.)
	var road_gain := (.15 * smoothstep(0., 3.5, road_speed) + .18 * smoothstep(3.5, 27., road_speed))
	road_gain *= (1. + .18 * corner_load) * lerpf(1., .70, snow_cover)
	tires.pitch_scale = lerpf(tires.pitch_scale, .72 + .5 * pace, blend)
	tires.volume_db = lerpf(tires.volume_db, linear_to_db(maxf(.00025, road_gain)), blend)

	var slip_speed := road_speed * absf(sin(slip_angle))
	var loaded_side := clampf(cornering / 5., -1., 1.)
	skid.position.x = lerpf(skid.position.x, loaded_side*.65, blend)
	var skid_gain := lerpf(.34, .18, snow_cover) * smoothstep(.45, 6., slip_speed)
	skid.volume_db = lerpf(skid.volume_db, linear_to_db(maxf(.00025, skid_gain)), blend)
	skid.pitch_scale = lerpf(.76,.51,snow_cover) + .36 * smoothstep(0., 12., slip_speed)
	if skid_gain > .001 and not skid.playing: skid.play()
	elif skid_gain <= .001 and skid.volume_db < -54.: skid.stop()

	# One short rubber chirp at hard breakaway on exposed pavement. Require
	# grip to recover before rearming, including during sustained countersteer.
	var chirp_gain := .105 * (1. - smoothstep(.1, .55, snow_cover)) * smoothstep(1., 5., slip_speed)
	chirp.volume_db = linear_to_db(maxf(.00025, chirp_gain))
	if slip_speed < 1.2:
		chirp_armed = true
	elif chirp_armed and slip_speed > 5.5:
		chirp_armed = false
		if chirp_gain > .01:
			chirp.position = skid.position
			chirp.play()

	# Model 3 exterior speaker spectrum, fading out at about 25 mph.
	var forward_gain := .045 * smoothstep(.02, .8, speed) * (1.0 - smoothstep(4.0, 11.18, speed))
	var reverse_gain := .32 * smoothstep(.02, .8, -speed)
	forward_warning.volume_db = lerpf(forward_warning.volume_db, linear_to_db(maxf(.00025, forward_gain)), blend)
	reverse_warning.volume_db = lerpf(reverse_warning.volume_db, linear_to_db(maxf(.00025, reverse_gain)), blend)

func play_turn_signal(lit: bool) -> void:
	turn_signal.stream = preload("res://audio/turn_signal.wav") if lit else preload("res://audio/turn_signal_off.wav")
	turn_signal.play()

func park() -> void:
	turn_signal.stop()
	chirp_armed = true
	for player in [chirp, tires, skid, forward_warning, reverse_warning]:
		player.stop()
		player.volume_db = MUTED_DB
