extends StaticBody3D
var world
var key=""
func take_damage(_amount,_by_player=true):
	if collision_layer==0:return
	world.broken_glass[key]=true
	collision_layer=0
	hide()
	world.ops.audio.effect("glass",global_position,-8)
