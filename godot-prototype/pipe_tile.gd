extends Control

var mask = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center = size*.5
	var gold = Color("d9b875")
	var ends = [Vector2(center.x,0),Vector2(size.x,center.y),Vector2(center.x,size.y),Vector2(0,center.y)]
	var bits = [1,2,4,8]
	for i in 4:
		if mask&bits[i]:
			draw_line(center,ends[i],Color("1a3039"),13,true)
			draw_line(center,ends[i],gold,7,true)
	draw_circle(center,6,gold)
	draw_circle(center,2.2,Color("f5e3ad"))
