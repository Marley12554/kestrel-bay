extends Node3D

const MUTED_DB := -72.0

const SCUFF := preload("res://audio/tire_scuff.wav")
const SCUFF_CROSSFADE := .55
const MAX_SCUFF_PITCH := 1.35

var scuff_voices: Array[AudioStreamPlayer3D] = [AudioStreamPlayer3D.new(), AudioStreamPlayer3D.new()]
var scuff_rng := RandomNumberGenerator.new()
var scuff_pitch_offsets: Array[float] = [1., 1.]
var active_voice := 0
var segment_age := 0.
var segment_duration := 0.
var scuff_gain := 0.
var tires := AudioStreamPlayer3D.new()
var forward_warning := AudioStreamPlayer3D.new()
var reverse_warning := AudioStreamPlayer3D.new()
var turn_signal := AudioStreamPlayer3D.new()

func _ready() -> void:
	for voice in scuff_voices:
		voice.stream = SCUFF
		voice.position = Vector3(0., .12, 1.34)
		voice.volume_db = MUTED_DB
		add_child(voice)
	setup_loop(tires, preload("res://audio/sedan_road.wav"))
	setup_loop(forward_warning, preload("res://audio/tesla_forward.wav"))
	setup_loop(reverse_warning, preload("res://audio/tesla_reverse.wav"))
	turn_signal.stream = preload("res://audio/turn_signal.wav")
	# Mono emitters are transformed with the sedan. Let the active camera be
	# the listener, including during manual orbit and camera obstruction.
	tires.position = Vector3(0.,.12,-1.30)
	turn_signal.position = Vector3(-.36,.94,-.55)
	for source in [scuff_voices[0], scuff_voices[1], tires]:
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

	update_scuff(road_speed * absf(sin(slip_angle)), cornering, snow_cover, dt)

	# Model 3 exterior speaker spectrum, fading out at about 25 mph.
	var forward_gain := .045 * smoothstep(.02, .8, speed) * (1.0 - smoothstep(4.0, 11.18, speed))
	var reverse_gain := .32 * smoothstep(.02, .8, -speed)
	forward_warning.volume_db = lerpf(forward_warning.volume_db, linear_to_db(maxf(.00025, forward_gain)), blend)
	reverse_warning.volume_db = lerpf(reverse_warning.volume_db, linear_to_db(maxf(.00025, reverse_gain)), blend)

func update_scuff(slip_speed: float, cornering: float, snow: float, dt: float) -> void:
	var intensity := slip_speed / (4. + slip_speed)
	var load_factor := clampf(absf(cornering) / 10., 0., 1.)
	var target_gain := intensity * smoothstep(.15, 1.5, slip_speed) * lerpf(.48, .25, snow) * lerpf(.82, 1., load_factor)
	var blend := 1. - exp(-dt * (12. if target_gain > scuff_gain else 7.))
	scuff_gain = lerpf(scuff_gain, target_gain, blend)
	if scuff_gain < .0005 and target_gain < .0005:
		if segment_duration > 0.:
			stop_scuff()
		return

	segment_age += dt
	if segment_age >= segment_duration:
		# Crossfade into a different part of the recording before either
		# voice reaches the end, even if pitch climbs during the overlap.
		active_voice = 1 - active_voice
		segment_duration = scuff_rng.randf_range(1.7, 3.4)
		scuff_pitch_offsets[active_voice] = scuff_rng.randf_range(.965, 1.035)
		var last_start := SCUFF.get_length() - (segment_duration + SCUFF_CROSSFADE + .1) * MAX_SCUFF_PITCH
		scuff_voices[active_voice].volume_db = MUTED_DB
		scuff_voices[active_voice].play(scuff_rng.randf_range(0., last_start))
		segment_age = 0.
	var fade := clampf(segment_age / SCUFF_CROSSFADE, 0., 1.)
	var pitch := lerpf(.73, .51, snow) + .57 * intensity
	for index in scuff_voices.size():
		var voice := scuff_voices[index]
		voice.position.x = lerpf(voice.position.x, clampf(cornering / 5., -1., 1.) * .65, blend)
		voice.pitch_scale = lerpf(voice.pitch_scale, pitch * scuff_pitch_offsets[index], blend)
		var weight := sin(fade * PI / 2.) if index == active_voice else cos(fade * PI / 2.)
		# At initial breakaway there is no outgoing voice to crossfade.
		if index == active_voice and not scuff_voices[1 - index].playing:
			weight = 1.
		voice.volume_db = linear_to_db(maxf(.00025, weight * scuff_gain))
		if index != active_voice and fade >= 1. and voice.playing:
			voice.stop()

func stop_scuff() -> void:
	for voice in scuff_voices:
		voice.stop()
		voice.volume_db = MUTED_DB
	scuff_gain = 0.
	segment_duration = 0.
	segment_age = 0.

func play_turn_signal(lit: bool) -> void:
	turn_signal.stream = preload("res://audio/turn_signal.wav") if lit else preload("res://audio/turn_signal_off.wav")
	turn_signal.play()

func park() -> void:
	turn_signal.stop()
	stop_scuff()
	for player in [tires, forward_warning, reverse_warning]:
		player.stop()
		player.volume_db = MUTED_DB
