extends Node

var world: Node3D
var sounds = {"horn":preload("res://audio/horn.wav"),"air":preload("res://audio/air.wav"),"blast":preload("res://audio/blast.wav"),"pressure":preload("res://audio/pressure.wav"),"shot":preload("res://audio/shot.wav"),"reload":preload("res://audio/reload.wav"),"click":preload("res://audio/click.wav"),"glass":preload("res://audio/glass.wav")}
var engine: AudioStreamPlayer
var sirens: Array = []
var paused = false
var headless = false

func configure(owner_world: Node3D) -> void:
	world = owner_world
	headless = DisplayServer.get_name()=="headless"
	engine = AudioStreamPlayer.new()
	engine.stream = _loop(preload("res://audio/engine.wav"))
	engine.volume_db = -80
	add_child(engine)
	if not headless:
		engine.play()
	for car in world.vehicles:
		if car.police and not car.boat:
			var player = AudioStreamPlayer3D.new()
			car.add_child(player)
			player.stream = _loop(preload("res://audio/siren.wav"))
			player.volume_db = -80
			player.unit_size = 14
			player.max_distance = 150
			player.position.y = 1.5
			if not headless:
				player.play()
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
	var player = AudioStreamPlayer3D.new()
	world.add_child(player)
	player.position = at+Vector3.UP
	player.stream = sounds[id]
	player.volume_db = db
	player.unit_size = 5
	player.max_distance = 120
	player.finished.connect(player.queue_free)
	player.play()

func set_paused(value: bool) -> void:
	paused = value
	engine.stream_paused = value
	for s in sirens:
		s.player.stream_paused = value
	for child in world.get_children():
		if child is AudioStreamPlayer3D:
			child.stream_paused = value

func _process(dt: float) -> void:
	if not world.started or paused:
		return
	var car = world.player.vehicle
	var volume = -80.0
	if car and car.health>0:
		volume = -10 if car.boat else -7
		engine.pitch_scale = lerpf(engine.pitch_scale,.65+clampf(car.speed/car.max_speed,0,1)*.65,dt*3)
	engine.volume_db = move_toward(engine.volume_db,volume,dt*90)
	for s in sirens:
		var active = world.chase and s.car.speed>1.5 and s.car.health>0
		s.player.volume_db = move_toward(s.player.volume_db,-17 if active else -80,dt*50)

func _exit_tree() -> void:
	if is_instance_valid(engine):
		engine.stop()
	for s in sirens:
		if is_instance_valid(s.player):
			s.player.stop()
