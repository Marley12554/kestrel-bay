extends "res://frontage_geometry.gd"

# Local +Z faces Fifth. X increases toward 34th. Floor dimensions fit the
# surveyed corner shell. Fit-out proportions follow the designer's entry photo.
const WIDTH:=23.25
const DEPTH:=18.
const REVOLVING_DOOR := preload("res://revolving_door.gd")
const DRUM_X := 13.42
const FRONT_Z := .22
const FLOOR_Y := .155
const DOOR_X:=15.55
const DOOR_WIDTH:=1.39
const COUNTER:=Vector3(4.6,0,-9.)
const WORDMARK := preload("res://signs/reserve-wordmark.svg")
const RESERVE_STAR := preload("res://signs/reserve-star.svg")
const CUP:=preload("res://reserve/coffee_cup.tscn")
enum Order { AVAILABLE, BREWING, READY, CARRIED }
var order:=Order.AVAILABLE
var brew_time:=0.
var opened:=false
var door:=StaticBody3D.new()
var open_angle:=1.63
var cup:Node3D
var grip:=Node3D.new()
var server:Node3D
var serving_arm := preload("res://people/serve.gd").new()
var chime:=AudioStreamPlayer3D.new()
var pour:=AudioStreamPlayer3D.new()
var cue:=Label.new()
@onready var city=get_parent().get_parent()

func _ready() -> void:
	prepare_geometry()
	for spec in [["bronze","#9c7447",.41,.50],["walnut","#61432e",.59,0.],["oak","#bc9266",.51,0.],["ivory","#d3c3a6",.53,0.],["cream","#f2e9d8",.35,0.],["black","#2a2521",.43,.20],["sage","#748e60",.66,0.],["leaf","#3c6241",.63,0.],["cobalt","#384886",.46,.08],["rust","#a94328",.64,0.],["pastry","#c88946",.77,0.]]:
		material(spec[0],spec[1],spec[2],spec[3])
	var oval:=SphereMesh.new()
	oval.radial_segments=16
	oval.rings=8
	meshes["oval"]=oval
	pipe.radial_segments=48
	for key in ["terrazzo","marble"]:
		var stone:=ShaderMaterial.new()
		stone.shader=preload("res://reserve/finish.gdshader")
		stone.set_shader_parameter("marble",key=="marble")
		var stem: String="res://reserve/"+("marble_01" if key=="marble" else "terrazzo_tiles")
		stone.set_shader_parameter("stone",load(stem+"_diff.jpg"))
		stone.set_shader_parameter("polish",load(stem+"_rough.jpg"))
		finishes[key]=stone
	shell()
	coffee_bar()
	retail()
	assemble()
	entrance_leaf()
	staff()
	cup=CUP.instantiate()
	add_child(cup)
	cup.hide()
	cup.add_child(grip)
	grip.add_child(preload("res://people/cup-hand.glb").instantiate())
	grip.rotation.y = -.35
	grip.hide()
	add_child(chime)
	chime.stream=preload("res://reserve/door_chime.wav")
	chime.position=Vector3(DOOR_X,2.5,0)
	chime.unit_size=3.
	add_child(pour)
	pour.stream=preload("res://reserve/brew.wav")
	pour.position=COUNTER+Vector3(-.6,1.,0)
	pour.unit_size=4.
	city.get_node("Overlay").add_child(cue)
	cue.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cue.offset_left=-200
	cue.offset_right=200
	cue.offset_top=-108
	cue.offset_bottom=-68
	cue.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	cue.add_theme_constant_override("outline_size",5)
	cue.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cue.hide()

func partition(key:String, at:Vector3, size:Vector3) -> void:
	piece(key,at,size)
	collider(at,size)

func shell() -> void:
	piece("terrazzo",Vector3(WIDTH*.5,.095,-DEPTH*.5+.40),Vector3(WIDTH,.12,DEPTH+.8))
	piece("ivory",Vector3(WIDTH*.5,4.93,-DEPTH*.5),Vector3(WIDTH,.16,DEPTH))
	partition("ivory",Vector3(.04,2.44,-9),Vector3(.14,4.9,18.))
	partition("walnut",Vector3(WIDTH*.5,2.44,-DEPTH),Vector3(WIDTH,4.9,.18))
	for i in 8:
		var x:=1.1+i*3.
		piece("ivory",Vector3(x,4.62,-9),Vector3(.32,.48,18))
		piece("black",Vector3(x+.30,4.62,-9),Vector3(.035,.05,17.4))
		for j in 5:
			piece("black",Vector3(x+.30,4.49,-1.4-3.6*j),Vector3(.15,.22,.15),Vector3(.38,0,0),"round")
			piece("opal",Vector3(x+.30,4.398,-1.44-3.6*j),Vector3(.12,.025,.12),Vector3(.38,0,0),"round")
	for i in 3:
		piece("ivory",Vector3(WIDTH*.5,4.37,-3.-6.*i),Vector3(WIDTH,.32,.36))
	for x in [5.5,17.5]:
		for z in [-4.3,-13.6]:
			var light:=OmniLight3D.new()
			add_child(light)
			light.position=Vector3(x,3.65,z)
			light.omni_range=10.
			light.omni_attenuation=1.5
			light.light_color=Color("#ffdfad")
			light.light_energy=1.55
			light.light_bake_mode = Light3D.BAKE_STATIC
			light.light_size=.42
			light.shadow_enabled=(x>15. and z> -6.) or (x<10. and z< -10.)
	# Glazing on both street frontages, including a full-height opening for the door.
	install_revolving_entrance()
	window_span(DOOR_X+DOOR_WIDTH*.5,WIDTH)
	piece("bronze",Vector3(DOOR_X,3.23,.26),Vector3(DOOR_WIDTH,.09,.19))
	pane(DOOR_X,3.65,.25,DOOR_WIDTH,.76)
	piece("black",Vector3(WIDTH*.5,4.44,.25),Vector3(WIDTH,.8,.55))
	shop_sign(WORDMARK,Vector3(15.1,4.42,.55),.30,Color("#e8dfcc"))
	shop_sign(WORDMARK,Vector3(4.6,2.46,.33),.31,Color("#fff1d0"),Rect2(12,0,568,55))
	shop_sign(WORDMARK,Vector3(4.6,2.04,.33),.31,Color("#fff1d0"),Rect2(653,0,480,55))
	frame=Transform3D(Basis(Vector3.UP,PI/2),Vector3(WIDTH,0,0))
	window_span(0.,DEPTH)
	piece("black",Vector3(DEPTH*.5,4.43,.24),Vector3(DEPTH,.85,.55))
	frame=Transform3D.IDENTITY

func install_revolving_entrance() -> void:
	var revolving := REVOLVING_DOOR.new()
	var radius := revolving.RADIUS
	var opening_half := sin(revolving.HALF_ARC) * radius
	var drum_z := FRONT_Z - radius - .09
	var mouth_z := drum_z + cos(revolving.HALF_ARC) * radius
	var reveal := FRONT_Z - mouth_z
	var head_y := FLOOR_Y + revolving.HEAD - revolving.SILL
	var center_y := (FLOOR_Y + head_y) * .5
	var height := head_y - FLOOR_Y
	window_span(0., DRUM_X - opening_half)
	window_span(DRUM_X + opening_half, DOOR_X - DOOR_WIDTH * .5)
	revolving.name = "ReserveRevolvingDoor"
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://reserve/entrance_glass.gdshader")
	finishes["entry_glass"] = glass
	revolving.finishes["rail"] = finishes["bronze"]
	revolving.finishes["door_glass"] = glass
	# Place the entry mat just above the terrazzo so the threshold is visible.
	revolving.position = Vector3(DRUM_X, FLOOR_Y + .004 - revolving.SILL, drum_z)
	add_child(revolving)
	for side in [-1., 1.]:
		var x: float = DRUM_X + side * opening_half
		var at := Vector3(x, center_y, mouth_z + reveal * .5)
		piece("glass", at, Vector3(reveal, height, 1), Vector3(0, PI * .5, 0), "pane")
		collider(at, Vector3(.045, height, reveal))
		piece("bronze", Vector3(x, center_y, FRONT_Z), Vector3(.052, height, .07))
		for y in [FLOOR_Y + .035, head_y - .035]:
			piece("bronze", Vector3(x, y, at.z), Vector3(.05, .07, reveal))
	# The circular operator housing meets a rectangular glazed transom at the street.
	piece("bronze", Vector3(DRUM_X, head_y + .065, drum_z), Vector3(2.*radius+.04, .13, 2.*radius+.04), Vector3.ZERO, "round")
	piece("bronze", Vector3(DRUM_X, head_y + .065, mouth_z + reveal*.5), Vector3(2.*opening_half+.06, .13, reveal+.07))
	var transom_bottom := head_y + .13
	pane(DRUM_X, (transom_bottom+4.05)*.5, FRONT_Z, 2.*opening_half, 4.05-transom_bottom)
	for side in [-1., 1.]:
		piece("bronze", Vector3(DRUM_X + side*opening_half, (transom_bottom+4.05)*.5, FRONT_Z),
			Vector3(.052, 4.05-transom_bottom, .07))

func window_span(begin:float,end:float) -> void:
	var width:=end-begin
	var count:=ceili(width/3.3)
	for i in count:
		var w:=width/count
		var x:=begin+(i+.5)*w
		pane(x,2.19,.22,w-.07,3.82)
		piece("black",Vector3(x,.28,.20),Vector3(w,.27,.19))
		piece("bronze",Vector3(x-w*.5,2.15,.22),Vector3(.08,3.99,.18))
		collider(Vector3(x,1.65,.22),Vector3(w,3.1,.12))

func entrance_leaf() -> void:
	add_child(door)
	door.name="FifthAvenueDoor"
	door.position=Vector3(DOOR_X-DOOR_WIDTH*.5,0,.22)
	var w:=DOOR_WIDTH-.06
	piece("entry_glass", Vector3(w*.5,1.69,0), Vector3(w-.095,2.87,1), Vector3.ZERO, "pane")
	for x in [.025,w-.025]:
		piece("bronze",Vector3(x,1.67,0),Vector3(.055,3.01,.08))
	for y in [.24,3.11]:
		piece("bronze",Vector3(w*.5,y,0),Vector3(w,.13,.09))
	for sign_z in [-1.,1.]:
		for y in [1.00,1.48]:
			bar(Vector3(w-.14,y,0),Vector3(w-.14,y,.135*sign_z),.029,"brass")
		bar(Vector3(w-.14,1.,.135*sign_z),Vector3(w-.14,1.48,.135*sign_z),.035,"brass")
	assemble(door)
	# The ceramic lettering is printed onto the moving leaf at the handle.
	var mark := Label3D.new()
	mark.text = "PUSH"
	mark.double_sided = false
	mark.font_size = 64
	mark.pixel_size = .00068
	mark.outline_size = 0
	mark.modulate = Color(.83,.87,.85,.85)
	mark.position = Vector3(w-.22,1.56,.008)
	door.add_child(mark)
	var box:=BoxShape3D.new()
	box.size=Vector3(w,3.,.08)
	var shape:=CollisionShape3D.new()
	shape.shape=box
	shape.position=Vector3(w*.5,1.66,0)
	door.add_child(shape)

func coffee_bar() -> void:
	frame=Transform3D(Basis(Vector3.UP,PI/2),COUNTER)
	partition("marble",Vector3(0,.66,0),Vector3(10.6,1.0,.94))
	piece("marble",Vector3(0,1.17,0),Vector3(10.75,.095,1.10))
	piece("brass",Vector3(0,.24,.485),Vector3(10.5,.09,.025))
	# Rear work line and the suspended rectangular brass canopy.
	piece("bronze",Vector3(0,1.05,-2.1),Vector3(10.7,.32,.78))
	piece("walnut",Vector3(0,.64,-2.1),Vector3(10.5,.75,.74))
	for z in [-2.45,.56]:
		piece("bronze",Vector3(0,3.48,z),Vector3(11.,.18,.09))
		piece("opal",Vector3(0,3.375,z),Vector3(10.9,.022,.04))
		for x in [-4.9,4.9]: bar(Vector3(x,3.57,z),Vector3(x,4.64,z),.025,"black")
	for x in [-5.48,5.48]:
		piece("bronze",Vector3(x,3.48,-.94),Vector3(.09,.18,3.10))
	for x in [-4.,4.]:
		piece("limestone",Vector3(x,2.56,-3.45),Vector3(.92,4.8,.62))
	piece("cobalt",Vector3(0,2.72,-3.46),Vector3(6.8,.97,.11))
	shop_sign(WORDMARK,Vector3(0,2.84,-3.39),.26)
	lettering("E M P I R E   S T A T E   B U I L D I N G",Vector3(0,2.52,-3.39),.125,Color.WHITE)
	# Glass pastry case, metal trays and individually split, browned rolls.
	pane(2.95,1.50,.43,4.,.55)
	for x in [1.,4.9]:
		for z in [-.30,.43]:
			bar(Vector3(x,1.2,z),Vector3(x,1.8,z),.032,"brass")
	piece("glass",Vector3(2.95,1.78,.06),Vector3(3.98,.76,1),Vector3(-PI/2,0,0),"pane")
	for tray in 4:
		var x:=1.5+tray*.94
		piece("steel",Vector3(x,1.245,.04),Vector3(.84,.034,.62))
		for j in 6:
			var p:=Vector3(x+(j%3-1)*.245,1.32,-.08+floori(j/3.)*.24)
			for k in 3:
				piece("pastry",p+Vector3((k-1)*.055,-absf(k-1)*.016,absf(k-1)*.033),Vector3(.12,.102,.128),Vector3(0,(k-1)*.32,0),"oval")
	# Chilled bottles in tilted compartments, short stacks of boxed food and prices.
	for i in 3:
		var bx:float=-4.6+i*.97
		piece("steel",Vector3(bx,1.24,.14),Vector3(.87,.065,.51),Vector3(.12,0,0))
		for j in 5:
			var bp:=Vector3(bx+(j-2)*.143,1.32,.13)
			piece("bottle",bp,Vector3(.102,.22,.102),Vector3(.4,0,0),"round")
			piece("cream",bp+Vector3(0,.075,.036),Vector3(.101,.068,.101),Vector3(.4,0,0),"round")
			piece("brass",bp+Vector3(0,.130,.055),Vector3(.057,.038,.057),Vector3(.4,0,0),"round")
	for j in 4:
		piece("black",Vector3(1.5+.94*j,1.29,.42),Vector3(.20,.079,.02))
		lettering(["BUTTER","ALMOND","BRIOCHE","PRINCI"][j],Vector3(1.5+.94*j,1.29,.44),.031,Color.WHITE)
	# Espresso groups, portafilters, steam wands, grinder hoppers and stacked cups.
	for i in 2:
		var x:float=-2.9+2.15*i
		piece("steel",Vector3(x,1.26,-2.0),Vector3(1.38,.09,.67))
		piece("black",Vector3(x,1.51,-2.23),Vector3(1.3,.45,.21))
		piece("steel",Vector3(x,1.71,-2.03),Vector3(1.42,.26,.53))
		for j in 3:
			var dx:=x+(j-1)*.39
			piece("brass",Vector3(dx,1.54,-1.87),Vector3(.095,.12,.095),Vector3.ZERO,"round")
			bar(Vector3(dx,1.52,-1.87),Vector3(dx+.05,1.49,-1.70),.035,"black")
			for k in 3:
				piece("cream",Vector3(dx,1.88+k*.033,-2.08),Vector3(.14,.08,.14),Vector3.ZERO,"round")
		piece("black",Vector3(x+.83,1.38,-2.04),Vector3(.23,.35,.23))
		piece("bottle",Vector3(x+.83,1.67,-2.04),Vector3(.23,.28,.23),Vector3.ZERO,"round")
	piece("black",Vector3(-1.25,1.36,.10),Vector3(.37,.23,.07),Vector3(-.27,0,0))
	for x in [-4.45,-2.5,.35]:
		piece("bronze",Vector3(x,.20,1.52),Vector3(.31,.06,.31),Vector3.ZERO,"round")
		bar(Vector3(x,.22,1.52),Vector3(x,1.04,1.52),.049,"steel")
	bar(Vector3(-4.45,1.,1.52),Vector3(-2.50,1.,1.52),.036,"black")
	frame=Transform3D.IDENTITY

func retail() -> void:
	for x in [9.65,19.95]:
		partition("bronze",Vector3(x,2.18,-3.75),Vector3(1.02,4.06,.69))
		piece("black",Vector3(x,2.33,-3.384),Vector3(.78,2.58,.045))
		piece("cobalt",Vector3(x,2.38,-3.35),Vector3(.69,2.25,.04))
		for j in 5:
			var span:=.59-j*.093
			var y:=2.28+j*.114
			piece("brass",Vector3(x,y,-3.322),Vector3(span,.011,.01))
			for side in [-1.,1.]:
				piece("brass",Vector3(x+side*span*.5,y-.054,-3.322),Vector3(.011,.117,.01))
		piece("brass",Vector3(x,2.88,-3.322),Vector3(.011,.22,.01))
		lettering("E M P I R E",Vector3(x,1.80,-3.32),.070,Color("#f4cc83"))
		lettering("STATE BUILDING",Vector3(x,1.69,-3.32),.045,Color.WHITE)
		shop_sign(RESERVE_STAR,Vector3(x,3.10,-3.32),.44,Color("#efcf95"))
		piece("opal",Vector3(x,4.14,-3.37),Vector3(.94,.033,.04))
	# Entry shop tables sit between the sidewalk and the two bronze columns.
	for loc in [Vector3(8.,0,-1.65),Vector3(20.7,0,-2.2)]:
		piece("oak",loc+Vector3.UP*1.10,Vector3(2.09,.08,.84))
		piece("walnut",loc+Vector3.UP*.39,Vector3(2.02,.075,.78))
		for dx in [-.94,.94]:
			for dz in [-.32,.32]: bar(loc+Vector3(dx,.17,dz),loc+Vector3(dx,1.10,dz),.045,"bronze")
		collider(loc+Vector3.UP*.68,Vector3(1.98,1.0,.79))
		for j in 6:
			var item:Vector3=loc+Vector3((j%3-1)*.43,1.145,(floori(j/3.)-.5)*.37)
			if j%2==0: mug(item)
			else: bag(item,"rust")
	for spec in [[8.3,-4.1,1.3],[20.7,-6.2,1.5],[18.4,-11.3,1.25],[8.3,-13.8,1.4]]:
		var center:=Vector3(spec[0],0,spec[1])
		var r:float=spec[2]
		piece("ivory",center+Vector3.UP*.70,Vector3(r*2,1.07,r*1.32),Vector3.ZERO,"round")
		collider(center+Vector3.UP*.69,Vector3(r*1.77,1.07,r*1.16))
		for j in 60:
			var t:=TAU*j/60.
			piece("oak",center+Vector3(r*cos(t),.70,r*.66*sin(t)),Vector3(.023,1.03,.023),Vector3.ZERO,"round")
		piece("bronze",center+Vector3.UP*1.25,Vector3(r*2+.05,.046,r*1.32+.05),Vector3.ZERO,"round")
		for j in 8:
			var pos:=center+Vector3((j%4-1.5)*r*.39,1.28,(floori(j/4.)-.5)*.44)
			if j%3==0: mug(pos)
			else: bag(pos,"cream" if j%2==0 else "cobalt")
	# An original New York and coffee-growing landscape fills the rear overlook.
	var artwork:=StandardMaterial3D.new()
	artwork.albedo_texture=preload("res://reserve/harvest.svg")
	artwork.roughness=.72
	finishes["artwork"]=artwork
	piece("artwork",Vector3(13.2,2.89,-17.34),Vector3(11.55,3.58,1),Vector3.ZERO,"pane")
	for j in 6:
		var x:=1.7+j*3.8
		if j in [2,3,4]:
			piece("bronze",Vector3(x,.45,-17.42),Vector3(3.8,.60,.45))
			continue
		piece("bronze",Vector3(x,2.12,-17.72),Vector3(3.46,3.68,.12))
		piece("walnut",Vector3(x,2.12,-17.58),Vector3(3.35,3.54,.12))
		for row in 3:
			var y:=.70+row*.88
			piece("oak",Vector3(x,y,-17.25),Vector3(3.23,.075,.60))
			piece("opal",Vector3(x,y-.05,-17.0),Vector3(3.11,.019,.023))
			for k in 6:
				var p:=Vector3(x+(k-2.5)*.44,y+.042,-17.21)
				if (row+j)%3==0: mug(p)
				else: bag(p,["cream","cobalt","rust"][(k+j)%3])
	for spec in [[8.65,-3.65],[20.9,-3.7],[18.65,-14.7],[5.8,-15.8]]:
		plant(Vector3(spec[0],.15,spec[1]))
	var art:=preload("res://reserve/siren.gd").new()
	add_child(art)
	art.position=Vector3(14.8,.25,-8.6)
	for sign_side in [-1.,1.]:
		piece("bronze",Vector3(14.8+sign_side*1.87,4.08,-8.6),Vector3(.10,.12,3.18))
		piece("bronze",Vector3(14.8,4.08,-8.6+sign_side*1.54),Vector3(3.80,.12,.10))
		for sx in [-1.,1.]:
			bar(Vector3(14.8+sx*1.84,4.12,-8.6+sign_side*1.52),Vector3(14.8+sx*1.84,4.85,-8.6+sign_side*1.52),.032,"black")
	for rib in 11:
		piece("black",Vector3(13.15+rib*.33,4.11,-8.6),Vector3(.025,.047,3.06))
	var focal:=SpotLight3D.new()
	add_child(focal)
	focal.position=Vector3(14.8,3.99,-6.9)
	focal.look_at_from_position(focal.global_position,to_global(Vector3(14.8,1.32,-8.6)),Vector3.UP)
	focal.spot_range=6.
	focal.spot_angle=40.
	focal.light_color=Color("#fff1c9")
	focal.light_energy=2.4
	focal.light_bake_mode = Light3D.BAKE_STATIC
	piece("bronze",Vector3(14.8,.19,-8.6),Vector3(3.36,.09,2.24))
	piece("cobalt",Vector3(14.8,.247,-8.6),Vector3(3.25,.026,2.13))
	collider(Vector3(14.8,.64,-8.6),Vector3(2.95,.98,1.65))

func mug(base:Vector3) -> void:
	piece("cobalt",base+Vector3.UP*.093,Vector3(.18,.18,.18),Vector3.ZERO,"round")
	piece("black",base+Vector3.UP*.184,Vector3(.147,.006,.147),Vector3.ZERO,"round")
	for j in 8:
		var a:=j*TAU/8.
		var b:=(j+1)*TAU/8.
		bar(base+Vector3(.105+.049*cos(a),.098+.057*sin(a),0),base+Vector3(.105+.049*cos(b),.098+.057*sin(b),0),.019,"cobalt")

func bag(base:Vector3,key:String) -> void:
	piece(key,base+Vector3.UP*.143,Vector3(.183,.285,.108))
	piece(key,base+Vector3.UP*.29,Vector3(.185,.035,.085),Vector3(.22,0,.035))
	piece("paper",base+Vector3(0,.14,.056),Vector3(.133,.143,.008))
	piece("bronze",base+Vector3(0,.155,.063),Vector3(.078,.015,.006))

func plant(base:Vector3) -> void:
	piece("oak",base+Vector3.UP*.305,Vector3(.65,.61,.65),Vector3.ZERO,"round")
	piece("walnut",base+Vector3.UP*.62,Vector3(.59,.025,.59),Vector3.ZERO,"round")
	for i in 19:
		var a:=i*2.39996
		var h:=.32+.39*absf(sin(i*3.12+1.))
		var radial:=Vector3(cos(a),0,sin(a))
		var tip:=base+Vector3.UP*(.75+h)+radial*(.24+.13*cos(i))
		var start:=base+Vector3.UP*.59
		bar(start,tip,.016,"leaf")
		var axis:=(tip-start).normalized()
		piece("sage" if i%4==0 else "leaf",tip,Vector3(.16,h*.86,.05),Quaternion(Vector3.UP,axis).get_euler(),"oval")

func staff() -> void:
	server=preload("res://body.tscn").instantiate()
	server.position=COUNTER+Vector3(-.93,.155,-.2)
	server.rotation.y=-PI/2
	add_child(server)
	server.skeleton.add_child(serving_arm)

func inside(p:Vector3) -> bool:
	return p.x>0 and p.x<WIDTH and p.z<.18 and p.z> -DEPTH and p.y<4.9 and p.y>-.2

func action_at(p:Vector3) -> String:
	if absf(p.x-DOOR_X)<1.35 and absf(p.z-.22)<2.0:
		var hinge:=Vector2(DOOR_X-DOOR_WIDTH*.5,.22)
		var offset:=Vector2(p.x,p.z)-hinge
		if opened and offset.x>-.28 and offset.y*signf(open_angle)<.28 and offset.length()<DOOR_WIDTH+.28:
			return ""
		return "Close door" if opened else "Open door"
	if p.distance_to(COUNTER+Vector3(1.5,.16,0))<2.1 and p.x>COUNTER.x+.48 and inside(p):
		match order:
			Order.AVAILABLE: return "Order coffee"
			Order.BREWING: return "Brewing coffee…"
			Order.READY: return "Take coffee"
	return ""

func interact() -> bool:
	var p:=to_local(city.walker.global_position)
	var action:=action_at(p)
	match action:
		"Open door","Close door":
			if not opened: open_angle=1.63 if p.z>=.22 else -1.63
			opened=not opened
			chime.play()
		"Order coffee":
			order=Order.BREWING
			brew_time=2.6
			pour.play()
		"Take coffee":
			order=Order.CARRIED
			grip.show()
			cup.reparent(city.camera,false)
			cup.position=Vector3(.18,-.19,-.47)
			cup.rotation=Vector3(-.06,-.22,-.09)
		"Brewing coffee…": pass
		_: return false
	return true

func _physics_process(dt:float) -> void:
	door.rotation.y=move_toward(door.rotation.y,open_angle if opened else 0.,dt*2.8)
	if order==Order.BREWING:
		brew_time-=dt
		if brew_time<=.7:
			var reach:=clampf(1.-brew_time/.7,0.,1.)
			serving_arm.reach=reach
			cup.position=COUNTER+Vector3(lerpf(-.47,.33,reach),1.23+.11*sin(reach*PI),-.14)
			serving_arm.target=cup.global_position+Vector3.UP*.08
			cup.show()
		if brew_time<=0: order=Order.READY
	elif order==Order.CARRIED:
		serving_arm.reach=move_toward(serving_arm.reach,0.,dt*2.)
		cup.visible=not city.driving and not city.freecam
	var action:="" if city.driving or city.freecam else action_at(to_local(city.walker.global_position))
	cue.visible=city.hud_visible and (not city.web or not bool(city.web.midtownHudHidden)) and action!=""
	if cue.visible: cue.text=action if order==Order.BREWING and action.begins_with("Brewing") else "E   "+action
