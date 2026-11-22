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
	var blend:=1.0-exp(-8.0*dt)
	var pace:=clampf(absf(speed)/28,0,1)
	motor.pitch_scale=lerpf(motor.pitch_scale,.64+1.73*pace,blend)
	motor.volume_db=lerpf(motor.volume_db,-46.0+21*minf(absf(speed)/4,1.)+7*absf(load_amount),blend)
	tires.pitch_scale=.74+pace*.61
	tires.volume_db=lerpf(tires.volume_db,linear_to_db(maxf(.0006,minf(absf(speed)/15.,1.)*(.36+.20*clampf(absf(cornering)/6,0.,1.)))),blend)

func park() -> void:
	for player: AudioStreamPlayer in [motor,tires]:
		player.stop()
		player.volume_db=-62
