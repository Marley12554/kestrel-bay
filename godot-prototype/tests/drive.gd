extends SceneTree
var w
func _initialize():call_deferred("run")
func run():
	w=load("res://bay/islands.tscn").instantiate();root.add_child(w)
	for i in 6:await physics_frame;await process_frame
	w.start_test()
	var mode="bridge" if OS.get_cmdline_user_args().has("--bridge") else "route"
	w.begin_drive(mode)
	for i in 45000:
		await physics_frame
		if not w.rehearsal.underway:break
	var d=w.rehearsal
	print("ROUTE DRIVE ",mode," seconds=",d.elapsed," meters=",d.progress," leg=",d.segment,"/",d.route.size()-1," position=",w.player.position," reached=",d.finished)
	var passed=d.finished and d.elapsed>=480 and d.elapsed<=720 and d.progress>6600
	if mode=="bridge":passed=d.finished and d.hotel_walk and not w.player.vehicle and w.player.position.distance_to(d.final_position)<2.
	if not passed:push_error("Five-star driver did not enter the downtown hotel" if mode=="bridge" else "Continuous sedan drive failed its route or 8–12 minute target")
	quit(0 if passed else 1)
