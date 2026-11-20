extends Control

var world: Node3D
var ops: Node3D
var font: Font
var large_map = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font

func configure(owner_world: Node3D,director: Node3D) -> void:
	world = owner_world
	ops = director
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func label_at(at: Vector2,text: String,color: Color=Color("ebeadf"),size: int=16) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	if not is_instance_valid(ops) or not world.started:
		return
	var w = size.x
	var h = size.y
	if large_map:
		draw_rect(Rect2(Vector2.ZERO,size),Color(.025,.06,.085,.97))
		_draw_map(Vector2(w*.5,h*.5),minf(w*.002,h*.002),minf(w,h)*.40)
		label_at(Vector2(30,38),"KESTREL BAY / WATERFRONT",Color("e4c58c"),24)
		label_at(Vector2(30,h-30),"M or Esc · Return to game",Color("d2dedb"))
		return
	_draw_map(Vector2(101,104),.48,78)
	label_at(Vector2(26,205),"$%d" % ops.cash,Color("a4ddc5"),23)
	label_at(Vector2(26,226),"BREAKWATER DISTRICT",Color("b6c7c6"),11)
	label_at(Vector2(26,244),"M map · N lighting · Backspace reset",Color("a9bbb7"),10)
	for i in 5:
		_star(Vector2(w-240+i*43,42),i<ops.wanted,i)
	var objective = ops.objective_text()
	var text_width = font.get_string_size(objective,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	draw_rect(Rect2(w*.5-text_width*.5-17,22,text_width+34,40),Color(.045,.09,.12,.94))
	label_at(Vector2(w*.5-text_width*.5,48),objective,Color("f0d7a3"),17)
	var hint = ops.interaction_hint()
	if not hint.is_empty():
		var hs = font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_rect(Rect2(w*.5-hs*.5-14,h-146,hs+28,35),Color(.045,.09,.12,.94))
		label_at(Vector2(w*.5-hs*.5,h-123),hint)
	_bar(Vector2(26,h-104),ops.hp/100,Color("ce4943"),"HP %d / 100" % ceili(ops.hp))
	var stamina_color = Color("f3f2e6") if ops.stamina>20 else Color("dbb28b")
	_bar(Vector2(26,h-70),ops.stamina/100,stamina_color,"EXHAUSTED" if ops.exhausted else "STAMINA %d%%" % ceili(ops.stamina))
	var v = world.player.vehicle
	if v:
		_bar(Vector2(26,h-138),v.health/100,Color("ce8c3f"),"VEHICLE %d%%" % ceili(v.health))
		label_at(Vector2(w-190,h-60),"%02d MPH" % roundi(v.speed*2.23694),Color("efdcba"),32)
		label_at(Vector2(w-240,h-33),"SHIFT · HANDBRAKE" if not v.boat else "E · EXIT ONTO DECK",Color("c4d0cd"),13)
	elif world.player.swimming:
		label_at(Vector2(w-225,h-64),"OXYGEN %d%%" % ceili(world.player.breath),Color("addef0"),20)
	for i in 2:
		var at = Vector2(w*.5-132+i*136,h-55)
		draw_rect(Rect2(at,Vector2(128,33)),Color("293e45") if ops.armed==(i==1) else Color(.08,.12,.14,.85))
		draw_rect(Rect2(at,Vector2(128,33)),Color("d7b67b") if ops.armed==(i==1) else Color("4d5b5b"),false,1)
		label_at(at+Vector2(10,22),"1 · UNARMED" if i==0 else "2 · PISTOL",Color("e2dfcc"),13)
	if ops.armed:
		label_at(Vector2(w-225,h-100),"%d / %d   R · RELOAD" % [ops.ammo,ops.reserve],Color("dcd8c7"),16)
	if ops.notice_until>world.clock:
		var ns = font.get_string_size(ops.notice,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		label_at(Vector2(w*.5-ns*.5,h-176),ops.notice,Color("f0d7a3"),15)
	if ops.arrest>.01:
		_bar(Vector2(w*.5-120,h-210),ops.arrest,Color("c79a55"),"ARREST")
	if ops.hp<25:
		draw_rect(Rect2(Vector2.ZERO,size),Color(.5,.02,.01,.08+.04*sin(world.clock*7)))
	if ops.armed and not v:
		var c = size*.5
		draw_line(c+Vector2(-7,0),c+Vector2(-2,0),Color.WHITE,1)
		draw_line(c+Vector2(2,0),c+Vector2(7,0),Color.WHITE,1)
		draw_line(c+Vector2(0,-7),c+Vector2(0,-2),Color.WHITE,1)
		draw_line(c+Vector2(0,2),c+Vector2(0,7),Color.WHITE,1)

func _bar(at: Vector2,value: float,color: Color,text: String) -> void:
	draw_rect(Rect2(at,Vector2(240,25)),Color(.045,.075,.09,.94))
	draw_rect(Rect2(at+Vector2(2,2),Vector2(236*clampf(value,0,1),21)),color)
	draw_rect(Rect2(at,Vector2(240,25)),Color("647474"),false,1)
	draw_string_outline(font,at+Vector2(9,18),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color("13202b"))
	label_at(at+Vector2(9,18),text,Color.WHITE,14)

func _star(center: Vector2,active: bool,index: int) -> void:
	var points = PackedVector2Array()
	for i in 10:
		var a = i*TAU/10-PI/2
		points.append(center+Vector2(cos(a),sin(a))*(19 if i%2==0 else 8.5))
	var pulse = .8+.2*sin(world.clock*2) if ops.unseen>4 else 1.0
	var color = Color("e6b85b")*pulse if active else Color("37474c")
	color.a = 1
	draw_colored_polygon(points,color)
	for i in 10:
		draw_line(points[i],points[(i+1)%10],Color("f9df9c") if active else Color("6a7470"),1.5,true)
		if i%2==0:
			draw_colored_polygon(PackedVector2Array([center,points[i],points[(i+1)%10]]),Color("ffe3a0") if active else Color("47565b"))
	draw_circle(center,2,Color("674b28") if active else Color("26373c"))

func _draw_map(center: Vector2,scale: float,radius: float) -> void:
	var origin = Vector2(0,0) if large_map else Vector2(world.player.position.x,world.player.position.z)
	draw_rect(Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),Color("142b39"))
	for building in world.footprints:
		var pos = center+(Vector2(building[0].x,building[0].z)-origin)*scale
		var extent = Vector2(building[1].x,building[1].z)*scale*.5
		var first = (pos-extent).clamp(center-Vector2.ONE*radius,center+Vector2.ONE*radius)
		var last = (pos+extent).clamp(center-Vector2.ONE*radius,center+Vector2.ONE*radius)
		if last.x>first.x and last.y>first.y:
			draw_rect(Rect2(first,last-first),Color("3d5358"))
	for edge in ops.map_edges:
		var a = center+(Vector2(edge[0].x,edge[0].z)-origin)*scale
		var b = center+(Vector2(edge[1].x,edge[1].z)-origin)*scale
		if _inside(a,center,radius) and _inside(b,center,radius):
			draw_line(a,b,Color("82918d"),3,true)
	for v in world.vehicles:
		if v.police and ops.wanted==0:
			continue
		var pos = center+(Vector2(v.position.x,v.position.z)-origin)*scale
		if _inside(pos,center,radius):
			draw_circle(pos,3,Color("82b9e8") if v.police else Color("a6b2a4"))
	if ops.target()!=Vector3.INF:
		var q = (Vector2(ops.target().x,ops.target().z)-origin)*scale
		q = q.clamp(Vector2.ONE*(-radius+6),Vector2.ONE*(radius-6))
		draw_circle(center+q,5,Color("eac282"))
	var here = center+(Vector2(world.player.position.x,world.player.position.z)-origin)*scale
	var angle = world.player.vehicle.rotation.y if world.player.vehicle else world.player.yaw
	var tip = Vector2(-sin(angle),-cos(angle))
	draw_colored_polygon(PackedVector2Array([here+tip*8,here-tip*4+tip.orthogonal()*4,here-tip*4-tip.orthogonal()*4]),Color("f6f2df"))
	draw_rect(Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),Color("acb5a5"),false,1.5)

func _inside(point: Vector2,center: Vector2,radius: float) -> bool:
	return absf(point.x-center.x)<radius and absf(point.y-center.y)<radius
