extends "res://hud.gd"

const CARTOGRAPHY=preload("res://bay/data/street_atlas.svg")
const EXTENT=Rect2(-1850,-4540,3740,5580)
const INK=Color("15282e")
const PAPER=Color("f1e8cc")
const GOLD=Color("e4ba77")
const SLOTS=["Hands","Pistol","Shotgun","Carbine","Tools"]
var board
var jobs_box
var selected_job=""
var selected_description
var accept_button
var veil
var touches={}
var look_positions={}
var stick_origin=Vector2.ZERO
var stick=Vector2.ZERO
var map_buttons=[]
var route_color=Color("ffe1a1")
var shown_region=""
var next_region=0.
var mobile_buttons={}
var touch_vehicle=""
static func heading(angle:float)->Vector2:return Vector2(-sin(angle),-cos(angle))
static func flat(at:Vector3)->Vector2:return Vector2(at.x,at.z)
func atlas_rect()->Rect2:
	var pane=Rect2(22,69,size.x*.61-34,size.y-100)
	var scale_factor=minf(pane.size.x/EXTENT.size.x,pane.size.y/EXTENT.size.y)
	return Rect2(pane.get_center()-EXTENT.size*scale_factor*.5,EXTENT.size*scale_factor)
func projected(at:Vector3,r:Rect2,region:Rect2)->Vector2:return r.position+(flat(at)-region.position)*r.size/region.size
func arrow(at:Vector2,v:Vector2):
	var side=v.orthogonal()
	var outline=PackedVector2Array([at+v*9,at-v*6+side*5.4,at-v*3,at-v*6-side*5.4])
	draw_colored_polygon(outline,Color("fff2c7"))
	for i in 4:draw_line(outline[i],outline[(i+1)%4],INK,1.4,true)
func dot(pos:Vector2,color:Color,radius:float):
	draw_circle(pos,radius+1.45,INK)
	draw_circle(pos,radius,color)
func map_view(r:Rect2,region:Rect2,detail:bool):
	draw_rect(r,Color("294858"))
	var src=Rect2((region.position-EXTENT.position)/EXTENT.size*Vector2(CARTOGRAPHY.get_size()),region.size/EXTENT.size*Vector2(CARTOGRAPHY.get_size()))
	draw_texture_rect_region(CARTOGRAPHY,r,src)
	var dst=ops.target()
	var prev=projected(world.player.position,r,region)
	for wp in ops.guide_route:
		var at=projected(wp,r,region)
		if r.has_point(prev) and r.has_point(at):draw_line(prev,at,route_color,2,true)
		prev=at
	if detail:
		for id in ["Uptown","Central Park","Times Square","Empire State Building","Lower Manhattan","Astoria","Pier 04","Blackwater Service Dock","Fort Halcyon"]:
			var mark=projected(world.atlas.marks[id],r,region)
			dot(mark,Color("e7c58a"),2.4)
			var text_pos=mark+Vector2(6,4)
			text_pos.x=clampf(text_pos.x,r.position.x,r.end.x-100)
			draw_string_outline(font,text_pos,id,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,INK)
			label_at(text_pos,id,PAPER,12)
	for v in world.vehicles:
		if not (v.police or v.model=="spotter") or v.occupied or v.wreck or ops.wanted==0:continue
		var q=projected(v.position,r,region)
		if r.grow(-4).has_point(q):dot(q,Color("80bce4"),3.)
	for n in ops.officers:
		if n.hp<=0 or n.boarded or not ops.wanted:continue
		var q=projected(n.position,r,region)
		if r.grow(-4).has_point(q):dot(q,Color("78add8"),2.)
	if dst!=Vector3.INF:
		var at=projected(dst,r,region).clamp(r.position+Vector2.ONE*6,r.end-Vector2.ONE*6)
		dot(at,GOLD,4.5)
	var car=world.player.vehicle
	arrow(projected(world.player.position,r,region).clamp(r.position+Vector2.ONE*8,r.end-Vector2.ONE*8),heading(car.rotation.y if car else world.player.yaw))
	draw_rect(r,Color("9e9e87"),false,1.3)
func centered(at:Vector2,txt:String,pt:int=16,tint=PAPER):
	var width=font.get_string_size(txt,HORIZONTAL_ALIGNMENT_LEFT,-1,pt).x
	draw_string_outline(font,at-Vector2(width*.5,0),txt,HORIZONTAL_ALIGNMENT_LEFT,-1,pt,4,INK)
	label_at(at-Vector2(width*.5,0),txt,tint,pt)
func _draw():
	if not world or not world.started:return
	var w=size.x
	var h=size.y
	if large_map:
		draw_rect(Rect2(Vector2.ZERO,size),Color("152a32"))
		label_at(Vector2(24,42),"New York Harbor",PAPER,29)
		map_view(atlas_rect(),EXTENT,true)
		label_at(Vector2(24,h-12),"Select a point to navigate",Color("c4c8b1"),13)
		return
	var p=world.player
	var v=p.vehicle
	var r=Rect2(22,20,149,149)
	var radius=155. if v else 105.
	map_view(r,Rect2(flat(p.position)-Vector2.ONE*radius,Vector2.ONE*radius*2),false)
	centered(Vector2(97,34),"N",13)
	if world.clock>next_region or shown_region.is_empty():
		shown_region=world.atlas.region(p.position)
		next_region=world.clock+.8
	label_at(Vector2(22,194),"$%d"%ops.cash,Color("afe4be"),23)
	var clock_minutes=roundi(fmod((world.day_time/600.)*1440+360,1440)) if not world.night_lock else 1320
	label_at(Vector2(22,214),"%02d:%02d   %s"%[clock_minutes/60,clock_minutes%60,shown_region],PAPER,13)
	if not world.mobile:label_at(Vector2(22,234),"M   Map & operations",Color("d1cbb4"),12)
	var center=Vector2(w*.5,h*.5)
	for i in 5:
		var at=Vector2(w-223+i*43,42)
		draw_circle(at,20.8,Color(.09,.11,.12,.78))
		_star(at,i<ops.wanted,i)
	var objective=ops.objective_text()
	if not objective.is_empty():
		centered(Vector2(w*.5,37),ops.campaign.label_for(ops.campaign.job).to_upper(),13,GOLD)
		centered(Vector2(w*.5,62),objective,17)
	var hud_y=h-(178 if world.mobile else 76)
	_bar(Vector2(22,hud_y),ops.hp/100,Color("bb4641"),"HP   %d / 100"%ceili(ops.hp))
	_bar(Vector2(22,hud_y+31),ops.stamina/100,Color("a77759") if ops.exhausted else Color("d9e1d9"),"EXHAUSTED" if ops.exhausted else "STAMINA   %d%%"%ceili(ops.stamina))
	if v:
		_bar(Vector2(22,hud_y-31),v.health/100,Color("c58039"),"HULL   %d%%"%ceili(v.health) if v.boat else "VEHICLE   %d%%"%ceili(v.health))
		centered(Vector2(w-107,hud_y-5),"%d MPH"%roundi(v.speed*2.236936),32)
	elif p.swimming:_bar(Vector2(22,hud_y-31),p.breath/100,Color("5da4ba"),"OXYGEN   %d%%"%ceili(p.breath))
	if not ops.puzzle and not ops.modal:
		var hint=ops.interaction_hint()
		if not hint.is_empty():centered(Vector2(w*.5,h-95),hint,15)
	if ops.notice_until>world.clock:centered(Vector2(w*.5,h-125),ops.notice,16,GOLD)
	if ops.arrest>.01:_bar(Vector2(w*.5-120,h-172),ops.arrest,Color("b86343"),"ARREST")
	var slot_width=minf(90.,(w-550)/5.)
	if world.mobile:slot_width=65
	for i in 5:
		var at=Vector2(w*.5+(i-2.5)*slot_width,h-43)
		draw_rect(Rect2(at,Vector2(slot_width-3,28)),Color(.07,.12,.14,.9))
		if i==ops.weapon_slot:draw_rect(Rect2(at,Vector2(slot_width-3,28)),GOLD,false,1.7)
		label_at(at+Vector2(5,19),"%d  %s"%[i+1,SLOTS[i]],PAPER if ops.campaign.shop_owned[i] else Color("81867d"),12)
	if ops.armed:
		centered(Vector2(w*.5,h-56),"%d / %d"%[ops.ammo,ops.reserve],15)
		if not v or p.leaning():
			draw_circle(center,3.2,INK)
			draw_circle(center,1.65,Color.WHITE)
			for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				var a=center+dir*5.5
				var b=center+dir*(13+ops.recoil*34)
				draw_line(a,b,INK,4.4,true)
				draw_line(a,b,Color.WHITE,2.1,true)
	if ops.lock_target and not ops.entry_latched:
		var ring_center=center+Vector2(0,34)
		draw_arc(ring_center,15,0,TAU,40,INK,5,true)
		draw_arc(ring_center,15,-PI/2,-PI/2+TAU*clampf(ops.lock_time/.78,.001,1.),40,GOLD,3.5,true)
	if world.mobile and not (ops.modal or ops.puzzle):
		draw_mobile()
func action_button(parent,txt,fn):
	var b=Button.new()
	parent.add_child(b)
	b.text=txt;b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y=39
	b.pressed.connect(fn)
	b.focus_mode=Control.FOCUS_NONE
	return b
func panel(rect:Rect2):
	var root=PanelContainer.new()
	add_child(root)
	root.process_mode=Node.PROCESS_MODE_ALWAYS
	root.position=rect.position;root.size=rect.size
	var style=StyleBoxFlat.new()
	style.bg_color=Color("1d343b");style.border_color=Color("9d9179")
	style.set_border_width_all(1);style.content_margin_left=17;style.content_margin_right=17;style.content_margin_top=14;style.content_margin_bottom=14
	root.add_theme_stylebox_override("panel",style)
	return root
func title_in(parent,txt,pt):
	var l=Label.new();parent.add_child(l)
	l.text=txt;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",pt)
	return l
func scroll_list(parent):
	var sc=ScrollContainer.new();parent.add_child(sc)
	sc.size_flags_vertical=Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var list=VBoxContainer.new();sc.add_child(list)
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return list
func menu(title,choices,callback):
	var rect=Rect2(size*.5-Vector2(210,210),Vector2(420,420))
	var root=panel(rect)
	var col=VBoxContainer.new();root.add_child(col)
	title_in(col,title,22)
	var list=scroll_list(col)
	for i in choices.size():action_button(list,choices[i],callback.bind(i))
	action_button(col,"Close",ops.close_modal)
	return root
func map_changed(value):
	release_touch()
	if is_instance_valid(board):
		board.queue_free();board=null
	if not value:return
	var rect=Rect2(size.x*.62,26,size.x*.38-24,size.y-52)
	board=panel(rect)
	var col=VBoxContainer.new();board.add_child(col)
	title_in(col,"Operations",27)
	var list=scroll_list(col)
	map_buttons.clear()
	for j in ops.campaign.JOBS:
		var id=String(j[0])
		var title=String(j[1])+("   ✓" if id in ops.campaign.completed else "")
		map_buttons.append(action_button(list,title,select_job.bind(j)))
	selected_description=title_in(col,"",15)
	accept_button=action_button(col,"Accept operation",accept_selected)
	if not ops.campaign.job.is_empty():action_button(col,"Abandon current operation",func():ops.campaign.abandon();map_changed(true))
	var options=HBoxContainer.new();col.add_child(options)
	var sound=action_button(options,"Sound off" if AudioServer.is_bus_mute(0) else "Sound on",func():
		AudioServer.set_bus_mute(0,not AudioServer.is_bus_mute(0))
		map_changed(true))
	sound.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	action_button(options,"Fullscreen",func():
		if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN))
	action_button(col,"Return to city",ops.toggle_map)
	var selected=ops.campaign.JOBS[0]
	for j in ops.campaign.JOBS:
		if j[0]==ops.campaign.job or j[0]==selected_job:selected=j
	select_job(selected)
	queue_redraw()
func select_job(j):
	selected_job=j[0]
	selected_description.text="%s  ·  $%s\n%s"%[j[1],j[3],j[2]]
	accept_button.disabled=j[0]==ops.campaign.job
	accept_button.text="In progress" if accept_button.disabled else ("Switch operation" if not ops.campaign.job.is_empty() else "Accept operation")
func accept_selected():
	ops.toggle_map()
	ops.campaign.accept(selected_job)
func fade_scene():
	if is_instance_valid(veil):veil.queue_free()
	veil=ColorRect.new();veil.color=Color.BLACK;veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(veil);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween=veil.create_tween()
	tween.tween_interval(.14);tween.tween_property(veil,"modulate:a",0.,.48);tween.tween_callback(veil.queue_free)
func draw_mobile():
	mobile_buttons.clear()
	var w=size.x;var h=size.y
	var car=world.player.vehicle
	var labels=["Use","Jump","Sprint","Punch" if ops.weapon_slot==0 else "Fire","Map"]
	if car:labels=["Exit","Up","Down","Fire","Map"] if car.aircraft else ["Exit","Brake","Drift" if not car.boat else "Horn","Lean" if not car.boat else "Horn","Map"]
	for i in labels.size():
		var pos=[Vector2(w-65,h-120),Vector2(w-155,h-100),Vector2(w-230,h-100),Vector2(w-66,h-206),Vector2(204,50)][i]
		var id=["use","jump","sprint","fire","map"][i]
		mobile_buttons[id]=pos
		draw_circle(pos,30,Color(.10,.15,.16,.77))
		draw_arc(pos,29,0,TAU,36,Color("b4b39b"),1.3,true)
		centered(pos+Vector2(0,5),labels[i],13,GOLD if world.player.mobile_sprint and id=="sprint" else PAPER)
	var o=stick_origin if touches.values().has("stick") else Vector2(107,h-85)
	draw_circle(o,57,Color(.10,.15,.16,.66))
	draw_arc(o,55,0,TAU,40,Color("969e91"),1.4,true)
	draw_circle(o+stick*36,20,Color(.73,.76,.66,.7))
func mobile_press(action,down):
	var p=world.player;var v=p.vehicle
	match action:
		"use":
			ops.use_touch=down
			if down and not ops.lock_target:p.press_interact()
		"map":
			if down:ops.toggle_map()
		"jump":
			if v and not v.aircraft:p.mobile_brake=down
			elif v:action_state("interact",down)
			else:action_state("jump",down)
		"sprint":
			if not v:
				if down:p.mobile_sprint=not p.mobile_sprint
			elif v.aircraft:action_state("lean",down)
			elif not v.boat:action_state("handbrake",down)
			elif down:ops.audio.effect("horn",v.position,-5)
		"fire":
			if v and not v.aircraft and not v.boat:p.mobile_lean=down
			if down and not v and ops.weapon_slot==0:ops.attack_press()
			ops.trigger_down=down and ops.armed
func action_state(action,down):
	if down:Input.action_press(action)
	else:Input.action_release(action)
func release_touch():
	if not world or not world.player:return
	for id in touches.values():
		if id in ["fire","jump","sprint","use"]:mobile_press(id,false)
	touches.clear();look_positions.clear();stick=Vector2.ZERO;world.player.analog=stick
func _input(event):
	if not is_instance_valid(ops) or not world.started:return
	if large_map:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var rect=atlas_rect()
			if rect.has_point(event.position):
				var wp=EXTENT.position+(event.position-rect.position)/rect.size*EXTENT.size
				ops.campaign.map_waypoint=Vector3(wp.x,2.65,wp.y)
				queue_redraw();get_viewport().set_input_as_handled()
		return
	if not world.mobile or ops.modal or ops.puzzle:return
	var p=world.player
	if event is InputEventScreenTouch:
		if event.pressed:
			var slot_span=325.
			var start=size.x*.5-slot_span*.5
			if event.position.y>size.y-46 and event.position.x>=start and event.position.x<start+slot_span:
				ops.select_slot(int((event.position.x-start)/65));get_viewport().set_input_as_handled();return
			var action="look"
			for id in mobile_buttons:
				if event.position.distance_to(mobile_buttons[id])<36:
					action=id;break
			if action=="look" and event.position.x<size.x*.45:
				action="stick"
			if touches.values().has(action):return
			if action=="stick":stick_origin=event.position;stick=Vector2.ZERO
			if action=="look":look_positions[event.index]=event.position
			touches[event.index]=action
			mobile_press(action,true)
		elif touches.has(event.index):
			var act=touches[event.index];touches.erase(event.index);look_positions.erase(event.index)
			if act=="stick":stick=Vector2.ZERO;p.analog=stick
			else:mobile_press(act,false)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touches.has(event.index):
		if touches[event.index]=="look":
			var delta=event.position-look_positions[event.index]
			look_positions[event.index]=event.position
			p.yaw-=delta.x*.0045;p.pitch=clampf(p.pitch-delta.y*.0045,-1.3,1.18)
		elif touches[event.index]=="stick":
			stick=((event.position-stick_origin)/45).limit_length();p.analog=stick
		get_viewport().set_input_as_handled()
