extends StaticBody3D
var boat
var index=0
func take_damage(amount,_by_player=true):
	if index==0:boat.captain_hp=maxf(0,boat.captain_hp-amount)
	else:boat.gunner_hp=maxf(0,boat.gunner_hp-amount)
	if (boat.captain_hp if index==0 else boat.gunner_hp)<=0:
		collision_layer=0
		rotation.z=PI*.5
		if index==1:boat.threat_until=boat.world.clock+9
	boat.world.ops.investigate(global_position)
