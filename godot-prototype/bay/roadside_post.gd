extends StaticBody3D

var fallen=false

func knock_down(direction:Vector3):
	if fallen:return
	fallen=true
	collision_layer=0
	var pole=get_node(get_meta("signal_support")) if has_meta("signal_support") else self
	var support=pole.get_node_or_null("Span")
	if support and not support.has_meta("detached"):
		support.set_meta("detached",true)
		var drop=create_tween().set_parallel(true)
		drop.tween_property(support,"position:y",-3.8,.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var shaft=get_node("Post")
	var horizontal=direction.slide(Vector3.UP).normalized()
	if horizontal.length_squared()<.01:horizontal=Vector3.RIGHT
	var axis=Vector3.UP.cross(horizontal).normalized()
	var target=Quaternion(axis,PI*.485)
	create_tween().tween_property(shaft,"quaternion",target,.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
