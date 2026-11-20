extends Node

var world: Node3D
var sounds = {"swing":preload("res://audio/swing.wav"),"thud":preload("res://audio/thud.wav"),"crash":preload("res://audio/crash.wav"),"horn":preload("res://audio/horn.wav"),"air":preload("res://audio/air.wav"),"blast":preload("res://audio/blast.wav"),"pressure":preload("res://audio/pressure.wav"),"shotgun":preload("res://audio/shotgun.wav"),"carbine":preload("res://audio/carbine.wav"),"shot":preload("res://audio/shot.wav"),"reload":preload("res://audio/reload.wav"),"click":preload("res://audio/click.wav"),"glass":preload("res://audio/glass.wav")}
var road_engine
var marine_engine
var voices=[]
var local_shots={}
var engine: AudioStreamPlayer
var sirens: Array = []
var paused = false
var headless = false

func configure(owner_world: Node3D) -> void:
	world = owner_world
	headless = DisplayServer.get_name()=="headless"
	engine = AudioStreamPlayer.new()
	road_engine = _loop(preload("res://audio/engine.wav"))
	marine_engine = _loop(preload("res://audio/marine-engine.wav"))
	engine.stream = road_engine
	engine.volume_db = -80
	add_child(engine)
	if not headless:
		engine.play()
	for id in ["shot","shotgun","carbine"]:
		var voice=AudioStreamPlayer.new()
		voice.stream=sounds[id]
		voice.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		voice.max_polyphony=5;voice.volume_db=-3
		add_child(voice)
		local_shots[id]=voice
	for i in 18:
		var voice=AudioStreamPlayer3D.new()
		voice.unit_size=5
		voice.max_distance=140
		add_child(voice)
		voices.append(voice)
	for car in world.vehicles:
		if car.police and not car.boat and (not "model" in car or car.model in ["cruiser","security"]):
			var player = AudioStreamPlayer3D.new()
			car.add_child(player)
			player.stream = _loop(preload("res://audio/siren.wav"))
			player.volume_db = -80
			player.unit_size = 14
			player.max_distance = 150
			player.position.y = 1.5
			player.max_db=-8.
			player.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
			sirens.append({"car":car,"player":player})

func _loop(source: AudioStreamWAV) -> AudioStreamWAV:
	var sound = source.duplicate() as AudioStreamWAV
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_begin = 0
	sound.loop_end = int(sound.get_length()*sound.mix_rate)
	return sound

func effect(id: String,at: Vector3,db: float) -> void:
	if not sounds.has(id) or paused or headless:
		return
	for voice in voices:
		if not voice.playing:
			voice.global_position=at+Vector3.UP
			voice.stream=sounds[id]
			voice.volume_db=db
			voice.play()
			return

func player_report(id:String):
	if paused or headless:return
	local_shots[id].play()

func set_paused(value: bool) -> void:
	paused = value
	engine.stream_paused = value
	for s in sirens:
		s.player.stream_paused = value
	for voice in local_shots.values():voice.stream_paused=value
	for child in voices:
		if child is AudioStreamPlayer3D:
			child.stream_paused = value

func _process(dt: float) -> void:
	if not world.started or paused:
		return
	var car = world.player.vehicle
	var volume = -80.0
	if car and car.health>0 and not ("flooded" in car and car.flooded):
		var motor_sound=marine_engine if car.boat else road_engine
		if engine.stream!=motor_sound:
			engine.stream=motor_sound
			if not headless:engine.play()
		volume = -12 if car.boat else -7
		engine.pitch_scale = lerpf(engine.pitch_scale,.65+clampf(car.speed/car.max_speed,0,1)*.65,dt*3)
	engine.volume_db = move_toward(engine.volume_db,volume,dt*90)
	for s in sirens:
		var responding=world.chase and not s.car.occupied and s.car.health>0
		if responding and world.ops.has_method("dispatched"):
			responding=world.ops.dispatched(s.car)
		if responding and not headless:
			if not s.player.playing:
				s.player.volume_db=-36
				s.player.play(fmod(world.clock+s.car.get_instance_id()%7,8.))
			s.player.volume_db=move_toward(s.player.volume_db,-9.,65.*dt)
		elif s.player.playing:
			s.player.volume_db=move_toward(s.player.volume_db,-65.,240.*dt)
			if s.player.volume_db<=-60.:s.player.stop()

func _exit_tree() -> void:
	if is_instance_valid(engine):
		engine.stop()
	for s in sirens:
		if is_instance_valid(s.player):
			s.player.stop()
