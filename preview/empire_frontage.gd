extends "res://frontage_geometry.gd"

# The front faces local +Z; the short return uses exactly the same corner.
# Dimensions are metres. Bay widths and storey heights drive both openings and trim.
const HALF_FRONT := 29.45
const PORTAL := 6.2
const BASE_TOP := 25.21
const STORES_TOP := 5.0
const FLOORS := [5.0,10.8,15.35,19.9,25.21]
func _ready() -> void:
	prepare_geometry()
	# The portal is dressed in broad, smooth limestone ashlar. The eagle's
	# vertex tones retain the cut recesses in the diffuse nighttime light.
	material("portal_stone","#c3bbaa",.82)
	var carving:=material("carved_stone","#c3bbaa",.82)
	carving.vertex_color_use_as_albedo=true
	frame=Transform3D(Basis(Vector3.UP,PI/2),Vector3(65.04,0,-.72))
	for sign_side in [-1,1]:
		var width: float=(HALF_FRONT-PORTAL)/8.0
		for i in 8:
			var x: float=sign_side*(PORTAL+(i+.5)*width)
			office_stack(x,width,i)
		for i in 4:
			var x: float=sign_side*(PORTAL+(i*2+1)*width)
			retail(x,width*2, i==2, sign_side<0)
		var middle: float=sign_side*(PORTAL+HALF_FRONT)*.5
		lettering("PHARMACY" if sign_side<0 else "HEARTLAND BREWERY",Vector3(middle,4.48,1.00),.37)
	entry()
	frame=Transform3D(Basis.IDENTITY,Vector3(65.04,0,HALF_FRONT-.72))
	# Retail wraps the corner. The loading entrance occupies two upper window bays.
	for i in 10:
		var x: float=-(i+.5)*3.25
		office_stack(x,3.25,i)
	for i in 5:
		var x: float=-(i*2+1)*3.25
		if i==3:
			service_bay(x,6.5)
		else:
			retail(x,6.5,i==1,true)
	assemble()

func office_stack(x: float,width: float,index: int) -> void:
	var opening:=width*.64
	var pier:=(width-opening)*.5
	for i in 4:
		var lo: float=FLOORS[i]
		var hi: float=FLOORS[i+1]
		var bottom:=lo+.67
		var top:=hi-(.99 if i==3 else .8)
		var h:=top-bottom
		var mid:=(top+bottom)*.5
		for side in [-1,1]:
			piece("limestone",Vector3(x+side*(width-pier)*.5,(lo+hi)*.5,.30),Vector3(pier,hi-lo,.89))
		piece("limestone",Vector3(x,(bottom+lo)*.5,.22),Vector3(opening,bottom-lo,.68))
		piece("limestone",Vector3(x,(top+hi)*.5,.22),Vector3(opening,hi-top,.68))
		piece("steel",Vector3(x,bottom,.33),Vector3(opening+.12,.072,.65))
		# A recessed daylight opening with sash, a physical soffit and back wall.
		piece("slate",Vector3(x,mid,-1.24),Vector3(opening,h,.085))
		piece("reveal",Vector3(x,top-.04,-.53),Vector3(opening,.09,1.49))
		piece("reveal",Vector3(x,bottom+.04,-.53),Vector3(opening,.09,1.49))
		for side in [-1,1]:
			piece("reveal",Vector3(x+side*opening*.5,mid,-.53),Vector3(.10,h,1.5))
			piece("sash",Vector3(x+side*(opening-.10)*.5,mid,.085),Vector3(.10,h,.12))
		for y in [bottom+.06,bottom+h*.52,top-.06]:
			piece("sash",Vector3(x,y,.085),Vector3(opening,.115,.12))
		if (i==1 or i==2) and index==0:
			for blade in 14:
				piece("steel",Vector3(x,bottom+(blade+.5)*h/14,-.035),Vector3(opening-.2,.07,.15),Vector3(.4,0,0))
		else:
			pane(x,mid,.015,opening-.15,h-.1)
			if (index+i*2)%5 in [1,2]:
				piece("shade",Vector3(x,top-h*.16,-.31),Vector3(opening-.11,h*.32,.045))
				piece("opal",Vector3(x,top-.19,-.86),Vector3(opening*.6,.035,.14))
	if index%3==0:
		for side in [-1,1]:
			var rib_x: float=x+side*(width*.5-.14)
			piece("limestone",Vector3(rib_x,12.55,.75),Vector3(.22,14.9,.20),Vector3.ZERO,"round")
	for course in [STORES_TOP,24.53,BASE_TOP-.13]:
		piece("limestone",Vector3(x,course,.43),Vector3(width,.25,.94))

func retail(x: float,width: float,door: bool,pharmacy: bool) -> void:
	for side in [-1,1]:
		piece("granite",Vector3(x+side*(width*.5-.12),2.44,.38),Vector3(.24,4.88,.86))
	piece("granite",Vector3(x,4.43,.38),Vector3(width,.93,.71))
	piece("steel",Vector3(x,4.01,.64),Vector3(width,.08,.36))
	if door:
		for side in [-1,1]:
			var sill: float=(width-2.38)*.5
			piece("granite",Vector3(x+side*(width-sill)*.5,.27,.29),Vector3(sill,.54,.78))
	else:
		piece("granite",Vector3(x,.27,.29),Vector3(width,.54,.78))
	piece("reveal",Vector3(x,2.21,-1.45),Vector3(width,4.42,.10))
	piece("wood",Vector3(x,.58,-.48),Vector3(width,.09,1.83))
	piece("reveal",Vector3(x,3.92,-.43),Vector3(width,.12,1.91))
	if door:
		door_pair(x,2.28,.29)
		for side in [-1,1]:
			var w: float=(width-2.48)*.5
			display_bay(x+side*(1.2+w*.5),w,pharmacy)
	else:
		display_bay(x,width-.31,pharmacy)

func display_bay(x: float,width: float,pharmacy: bool) -> void:
	pane(x,2.23,.37,width,3.20)
	for i in 3:
		piece("steel",Vector3(x+(i-1)*width*.5,2.25,.42),Vector3(.057,3.36,.13))
	piece("steel",Vector3(x,3.30,.41),Vector3(width,.088,.14))
	if pharmacy:
		piece("opal",Vector3(x,3.67,-.65),Vector3(width*.65,.037,.12))
		for y in [1.06,1.68]:
			piece("wood",Vector3(x,y,-.60),Vector3(width*.84,.07,.57))
			for i in 8:
				var jar_x:=x+(i-3.5)*width*.104
				var h:=.25+.075*(i%3)
				if i%3!=0:
					piece("bottle",Vector3(jar_x,y+h*.5+.04,-.59),Vector3(.17,h,.17),Vector3.ZERO,"round")
					piece("brass",Vector3(jar_x,y+h+.055,-.59),Vector3(.13,.055,.13),Vector3.ZERO,"round")
					piece("paper",Vector3(jar_x,y+h*.47,-.508),Vector3(.092,.11,.012))
				else:
					piece("paper",Vector3(jar_x,y+.20,-.56),Vector3(.21,.32,.16))
					piece("bottle",Vector3(jar_x,y+.22,-.474),Vector3(.17,.031,.008))
	else:
		# The brewery's closed timber shutters sit inside the deep display bay.
		for i in 13:
			piece("wood",Vector3(x,.81+i*.21,-.56),Vector3(width*.94,.16,.12),Vector3(.30,0,0))
	collider(Vector3(x,1.45,.38),Vector3(width,2.9,.10))

func door_pair(x: float,width: float,z: float) -> void:
	var leaf:=width*.5
	for side in [-1,1]:
		var cx: float=x+side*leaf*.5
		for edge in [-1,1]:
			piece("steel",Vector3(cx+edge*(leaf-.08)*.5,1.38,z),Vector3(.08,2.76,.11))
		piece("steel",Vector3(cx,.19,z),Vector3(leaf,.36,.10))
		piece("steel",Vector3(cx,2.72,z),Vector3(leaf,.10,.11))
		pane(cx,1.52,z-.05,leaf-.14,2.31)
		var hx: float=x+side*.16
		for y in [.98,1.48]:
			bar(Vector3(hx,y,z+.04),Vector3(hx,y,z+.17),.035,"brass")
		bar(Vector3(hx,.975,z+.17),Vector3(hx,1.485,z+.17),.04,"brass")
	piece("steel",Vector3(x,.035,z+.06),Vector3(width,.07,.39))
	collider(Vector3(x,1.38,z),Vector3(width,2.76,.11))

func service_bay(x: float,width: float) -> void:
	piece("limestone",Vector3(x,2.5,.02),Vector3(width,5,.45))
	piece("granite",Vector3(x,2.05,.40),Vector3(4.05,4.1,.65))
	for i in 33:
		piece("steel",Vector3(x,.12+i*.114,.76),Vector3(3.65,.108,.065),Vector3(.09,0,0))
	collider(Vector3(x,1.9,.75),Vector3(3.7,3.8,.10))

func entry() -> void:
	# A deep black-granite portal frames the door bank and the three metal screens above.
	# The real shallow vestibule is visible through the doors; the future lobby
	# can attach at the inner threshold. Black marble and metal surround it.
	piece("wood",Vector3(0,1.75,-3.12),Vector3(8.45,3.5,.16))
	for side in [-1,1]:
		piece("granite",Vector3(side*4.15,1.77,-1.05),Vector3(.33,3.54,4.25))
	piece("stone_inlay",Vector3(0,.067,-1.42),Vector3(8.19,.09,3.40))
	for x in [-3.65,-1.30,1.30,3.65]:
		piece("granite",Vector3(x,1.70,-2.73),Vector3(.25,3.4,.40))
		piece("brass",Vector3(x,1.70,-2.47),Vector3(.040,3.30,.05))
	for j in 3:
		var x:float=(j-1)*2.48
		for side in [-1,1]:
			piece("slate",Vector3(x+side*.56,1.35,-2.70),Vector3(1.01,2.51,.10))
			piece("steel",Vector3(x+side*.56,1.00,-2.59),Vector3(.83,.056,.12))
		piece("opal",Vector3(x,2.94,-2.49),Vector3(1.50,.16,.10))
	piece("reveal",Vector3(0,3.45,-1.03),Vector3(8.26,.18,4.18))
	for i in 5:
		piece("brass",Vector3(0,.119,-2.41+i*.15),Vector3(7.8,.012,.023))
	piece("limestone",Vector3(0,.045,-.09),Vector3(12.4,.09,3.0))
	piece("granite",Vector3(0,3.62,.56),Vector3(8.2,.85,1.35))
	piece("steel",Vector3(0,3.08,.61),Vector3(8.23,.27,1.50))
	for side in [-1,1]:
		var x: float=side*5.12
		piece("granite",Vector3(x,2.52,.43),Vector3(2.18,5.04,1.5))
		collider(Vector3(x,2.52,.43),Vector3(2.18,5.04,1.50))
		entrance_pier(x)
		piece("brass",Vector3(x,1.62,1.21),Vector3(.34,.39,.055))
	var w:=2.40
	door_pair(0,w,.30)
	for x in [-2.66,2.66]:
		rotary(x)
	lettering("350",Vector3(0,3.08,1.38),.235)
	# Glass and dark backing are separated by the screen depth.
	for bay in [-1,0,1]:
		var x: float=bay*2.64
		piece("reveal",Vector3(x,12.40,-.96),Vector3(2.64,16.8,.24))
		pane(x,12.40,.14,2.62,16.8)
		for side in [-1,1]:
			piece("steel",Vector3(x+side*1.25,12.44,.45),Vector3(.105,16.85,.17))
		for side in [-1,1]:
			piece("steel",Vector3(x+side*.60,12.43,.33),Vector3(.036,16.49,.07))
		for j in 4:
			var y:=4.48+j*3.62
			var foot:=Vector3(x,y,.49)
			var head:=foot+Vector3.UP*3.62
			for side in [-1,1]:
				var elbow:=foot+Vector3(side*1.17,1.81,0)
				bar(foot,elbow,.084,"steel")
				bar(elbow,head,.084,"steel")
		for j in 5:
			piece("steel",Vector3(x+(j-2)*.43,19.65,.44),Vector3(.055,2.34,.13))
	# Two upper openings pierce the lintel beneath the gilt inscription.
	for span in [[20.70,21.68],[23.78,26.28]]:
		piece("portal_stone",Vector3(0,(span[0]+span[1])*.5,.25),Vector3(8.10,span[1]-span[0],1.26))
	for strip in [[-3.15,1.80],[0.,1.25],[3.15,1.80]]:
		piece("portal_stone",Vector3(strip[0],22.73,.25),Vector3(strip[1],2.1,1.26))
	for x in [-1.44,1.44]:
		piece("reveal",Vector3(x,22.73,-.63),Vector3(1.65,2.1,.1))
		pane(x,22.73,.11,1.68,2.1)
		piece("sash",Vector3(x,22.73,.21),Vector3(1.7,.12,.14))
	# Continuous fascia across both piers. Fit the actual glyph mesh between
	# the capitals, leaving clearance even when seen from directly below.
	piece("portal_stone",Vector3(0,25.49,.44),Vector3(PORTAL*2,1.58,1.30))
	var inscription:=TextMesh.new()
	inscription.text="EMPIRE STATE"
	inscription.font_size=96
	inscription.pixel_size=.011
	inscription.depth=.045
	var font:=FontVariation.new()
	font.base_font=ThemeDB.fallback_font
	font.spacing_glyph=8
	inscription.font=font
	var letters:=MeshInstance3D.new()
	letters.name="EntranceInscription"
	letters.mesh=inscription
	var gold:=material("gilt","#eec375",.32,.62)
	gold.emission_enabled=true
	gold.emission=Color("#dbaa57")
	gold.emission_energy_multiplier=.20
	letters.material_override=gold
	var fit:=7.13/inscription.get_aabb().size.x
	letters.transform=frame*Transform3D(Basis.IDENTITY.scaled(Vector3(fit,fit,1)),Vector3(0,25.18,1.15))
	add_child(letters)
	entrance_flag()

func entrance_pier(x: float) -> void:
	if not meshes.has("eagle"):
		meshes["eagle"]=preload("res://entrance_eagle.gd").carve()
	# Broad convex flutes continue directly into the folded feather carving.
	piece("portal_stone",Vector3(x,14.87,.26),Vector3(2.18,19.74,1.28))
	for flute in 5:
		var offset:float=(flute-2)*.405
		var depth:=1.07-.22*pow(absf(offset),2)
		piece("portal_stone",Vector3(x+offset,13.42,depth),Vector3(.46,16.78,.50),Vector3.ZERO,"round")
	piece("carved_stone",Vector3(x,21.80,.93),Vector3(1.04,1.02,1.),Vector3.ZERO,"eagle")

func entrance_flag() -> void:
	var socket:=Vector3(0,26.22,-.64)
	var top:=socket+Vector3(0,6.55,.30)
	piece("steel",socket,Vector3(.32,.18,.32),Vector3.ZERO,"round")
	bar(socket,top,.09,"steel")
	var ball:=SphereMesh.new()
	ball.radial_segments=12
	ball.rings=6
	meshes["finial"]=ball
	piece("brass",top,Vector3.ONE*.17,Vector3.ZERO,"finial")
	var flag:=MeshInstance3D.new()
	flag.name="AvenueFlag"
	var cloth:=QuadMesh.new()
	cloth.size=Vector2(3.42,1.80)
	cloth.subdivide_width=26
	cloth.subdivide_depth=10
	var fabric:=ShaderMaterial.new()
	fabric.shader=preload("res://winter/avenue_flag.gdshader")
	cloth.material=fabric
	flag.mesh=cloth
	var upper:=top-Vector3.UP*.16
	flag.transform=frame*Transform3D(Basis.IDENTITY,upper+Vector3(cloth.size.x*.5,-cloth.size.y*.5,.025))
	flag.extra_cull_margin=.55
	add_child(flag)
	bar(socket+Vector3(.15,.12,.08),upper+Vector3(.03,0,.03),.021,"steel")

func rotary(x: float) -> void:
	var axis:=Vector3(x,0,.14)
	var radius:=1.08
	piece("steel",axis+Vector3.UP*2.75,Vector3(2.27,.24,2.27),Vector3.ZERO,"round")
	piece("granite",axis+Vector3.UP*.05,Vector3(2.24,.10,2.24),Vector3.ZERO,"round")
	bar(axis,axis+Vector3.UP*2.66,.105,"steel")
	for leaf in 4:
		var a:=.54+leaf*PI*.5
		var end:=axis+Vector3(sin(a),0,cos(a))*radius
		bar(end+Vector3.UP*.12,end+Vector3.UP*2.62,.052,"steel")
		for y in [.18,1.12,2.56]:
			bar(axis+Vector3.UP*y,end+Vector3.UP*y,.053,"steel")
		piece("glass",(axis+end)*.5+Vector3.UP*1.39,Vector3(radius,2.38,1),Vector3(0,a-PI/2,0),"pane")
	for side in [-1,1]:
		for i in 7:
			var a: float=side*PI/2-.64+i*.183
			var b: float=a+.183
			var start:=axis+Vector3(sin(a),0,cos(a))*radius
			var end:=axis+Vector3(sin(b),0,cos(b))*radius
			bar(start+Vector3.UP*2.61,end+Vector3.UP*2.61,.074,"steel")
			piece("glass",(start+end)*.5+Vector3.UP*1.39,Vector3(start.distance_to(end),2.47,1),Vector3(0,(a+b)*.5,0),"pane")
	collider(axis+Vector3.UP*1.35,Vector3(2.15,2.70,1.16))
