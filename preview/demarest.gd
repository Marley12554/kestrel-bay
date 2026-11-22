extends "res://frontage_geometry.gd"

# Exterior dimensions follow the 2014 survey. Each elevation has its own
# openings and shopfront schedule. Local +Z always points toward the street.
const FIFTH_WIDTH := 17.55
const SIDE_WIDTH := 29.16
const STORE_TOP := 5.35
const SPRING := 15.75
const ATTIC := 19.60
const COPING := 22.57
const COURSE := .064
const BOND := .21
const JOINT := .008
var brick_unit: ArrayMesh
var face_clay: ShaderMaterial

func _ready() -> void:
	prepare_geometry()
	var brick := ShaderMaterial.new()
	brick.shader=preload("res://winter/demarest_brick.gdshader")
	brick.set_shader_parameter("grain", preload("res://winter/frontage/white_sandstone_blocks_02_diffuse.jpg"))
	finishes["brick"]=brick
	face_clay = brick.duplicate()
	face_clay.set_shader_parameter("raised_face", true)
	brick_unit = bevel_block(.009, .035)
	material("clay","#b58e70",.81)
	material("keystone","#c4a389",.75)
	material("copper","#365752",.55,.47)
	material("iron","#383f40",.38,.55)
	material("shopmetal","#7b6c60",.34,.62)
	material("red","#983434",.72)
	material("blue","#194473",.68)
	material("office","#5b6666",.86)
	material("blind","#b4a78d",.91)
	var warm:=material("lit_office","#a39680",.88)
	warm.emission_enabled=true
	warm.emission=Color("#d5b992")
	warm.emission_energy_multiplier=.22
	var blind_shader:=ShaderMaterial.new()
	blind_shader.shader=preload("res://winter/demarest_shades.gdshader")
	finishes["lit_blind"]=blind_shader
	meshes["arch"]=arch_section(.91,1.,false)
	meshes["bead"]=arch_section(.978,1.,false)
	meshes["haunch"]=arch_section(1.,1.,true)
	meshes["fan"]=arch_section(0.,1.,false)
	frame=Transform3D(Basis(Vector3.UP,-PI/2),Vector3(96.23,0,11.50))
	upper_elevation(FIFTH_WIDTH,2,0.)
	fifth_shops()
	frame=Transform3D(Basis.IDENTITY,Vector3(96.23,0,29.05))
	# A narrow, separate vertical run of windows terminates the east elevation.
	upper_elevation(SIDE_WIDTH-2.05,3,2.05)
	side_shops()
	assemble()

# Extruded arch with a smooth opening. The haunch has a rectangular outer
# edge so the corners above the arch are solid brick, even at grazing angles.
func arch_section(inner: float, outer: float, square_top: bool) -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a:=PI*i/40.
		var b:=PI*(i+1)/40.
		var p:=Vector2(cos(a),sin(a))
		var q:=Vector2(cos(b),sin(b))
		var u:=Vector2(p.x,1.) if square_top else p*outer
		var v:=Vector2(q.x,1.) if square_top else q*outer
		var front: Array[Vector3]=[]
		for point: Vector2 in [p*inner,q*inner,v,u]:
			front.append(Vector3(point.x,point.y,.5))
		quad(surface,front[0],front[1],front[2],front[3])
		quad(surface,front[3]-Vector3.BACK,front[2]-Vector3.BACK,front[1]-Vector3.BACK,front[0]-Vector3.BACK)
		for j in [0,2]:
			var next: int=(j+1)%4
			quad(surface,front[next],front[j],front[j]-Vector3.BACK,front[next]-Vector3.BACK)
	return surface.commit()

func quad(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	# Godot uses clockwise faces. Skip degenerate triangles at fan centers.
	for triangle in [[a,b,c],[a,c,d]]:
		var normal: Vector3=(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0])
		if normal.length_squared()<.00000001: continue
		for point: Vector3 in triangle:
			s.set_normal(-normal.normalized())
			s.add_vertex(point)

func upper_elevation(width: float, count: int, end_strip: float) -> void:
	var pitch:=width/count
	var radius:=pitch*.415
	var full:=width+end_strip
	for bay in count:
		add_brick_courses(bay*pitch, (bay+1)*pitch, (bay+.5)*pitch, pitch*.415)
	if end_strip>0.:
		add_brick_courses(width, full, 0., 0.)
	for i in count:
		var x:=pitch*(i+.5)
		var pier:=pitch*.5-radius
		for side in [-1.,1.]:
			var edge: float=x+side*(radius+pier*.5)
			piece("brick",Vector3(edge,(ATTIC+STORE_TOP)*.5,.12),Vector3(pier,ATTIC-STORE_TOP,.65))
			for y in [SPRING-.16,SPRING+.01]:
				piece("keystone",Vector3(edge,y,.24),Vector3(pier+.08,.14,.88))
		piece("brick",Vector3(x,SPRING,.12),Vector3(radius,radius,.65),Vector3.ZERO,"haunch")
		var crown:=SPRING+radius
		piece("brick",Vector3(x,(ATTIC+crown)*.5,.12),Vector3(radius*2,ATTIC-crown,.65))
		piece("clay",Vector3(x,SPRING,.40),Vector3(radius,radius,.32),Vector3.ZERO,"arch")
		for scale_factor in [1.015,.935]:
			piece("keystone",Vector3(x,SPRING,.55),Vector3(radius*scale_factor,radius*scale_factor,.14),Vector3.ZERO,"bead")
		arch_windows(x,radius*.91,i)
		attic_pair(x,pitch)
		ornament(x-pitch*.5+.58,18.82)
	if end_strip>0:
		var x:=width+end_strip*.5
		piece("brick",Vector3(x,(COPING+STORE_TOP)*.5,.12),Vector3(end_strip,COPING-STORE_TOP,.65))
		for y in [8.1,12.8,17.3,20.55]:
			small_sash(x,y,.88,1.91,.505)
	# Crown including dentils and the individual dark green supporting brackets.
	for band in [[STORE_TOP,.25,.96],[STORE_TOP+.21,.14,1.12],[21.97,.18,.84],[22.28,.25,1.33],[22.53,.17,1.55]]:
		piece("copper" if band[0]>22.0 else "clay",Vector3(full*.5,band[0],.16),Vector3(full+.38,band[1],band[2]))
	for i in roundi(full/.24):
		piece("keystone",Vector3(.12+i*.24,21.86,.48),Vector3(.13,.13,.17))
	for i in roundi(full/1.36):
		for j in 3:
			piece("copper",Vector3((i+.5)*1.36,22.02+j*.075,.43+j*.07),Vector3(.25+j*.027,.09,.28+j*.10))

# One instanced skin per bay. All rows use the same bond across the piers,
# arch spandrels and attic. The masonry behind it is the recessed joint bed.
func add_brick_courses(left: float, right: float, center: float, radius: float) -> void:
	var units: Array[Transform3D] = []
	for row in range(floori(STORE_TOP/COURSE), ceili(COPING/COURSE)):
		var low := maxf(STORE_TOP, row*COURSE + JOINT*.5)
		var high := minf(COPING, (row+1)*COURSE - JOINT*.5)
		if high <= low: continue
		# Ends tuck behind the projecting arch trim. Above the crown the
		# same horizontal course continues through the entire bay.
		var rise := maxf(0.,high-SPRING)
		var cut := sqrt(maxf(0., radius*radius-rise*rise))
		if cut > 0.:
			add_brick_run(units,left,center-cut,low,high,row)
			add_brick_run(units,center+cut,right,low,high,row)
		else:
			add_brick_run(units,left,right,low,high,row)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = brick_unit
	batch.instance_count = units.size()
	for i in units.size(): batch.set_instance_transform(i,units[i])
	var view := MultiMeshInstance3D.new()
	view.name = "BondedBrickBay"
	view.multimesh = batch
	view.material_override = face_clay
	view.transform = frame
	view.visibility_range_end = 38.
	add_child(view,true)

func add_brick_run(units: Array[Transform3D], left: float, right: float, low: float, high: float, row: int) -> void:
	var shift := (row%2)*BOND*.5
	for col in range(floori((left+shift)/BOND),ceili((right+shift)/BOND)):
		var x0 := maxf(left,col*BOND-shift+JOINT*.5)
		var x1 := minf(right,(col+1)*BOND-shift-JOINT*.5)
		if x1-x0 < .001: continue
		var size := Vector3(x1-x0,high-low,.009)
		units.append(Transform3D(Basis.from_scale(size), Vector3((x1+x0)*.5,(low+high)*.5,.449)))

func arch_windows(x: float,r: float,index: int) -> void:
	var bottom:=STORE_TOP+.25
	var clear:=SPRING-bottom
	# Three stories share one metal frame. The back walls and floors remain
	# visible through the glass as the player moves across the opening.
	piece("office",Vector3(x,(SPRING+r+bottom)*.5,-1.65),Vector3(r*2,clear+r,.12))
	for side in [-1.,1.]:
		piece("reveal",Vector3(x+side*r,(SPRING+bottom)*.5,-.66),Vector3(.13,clear,1.86))
		piece("clay",Vector3(x+side*(r+.095),(SPRING+bottom)*.5,.32),Vector3(.20,clear,.51))
	var floor_height:=clear/3.
	for level in 3:
		var y:=bottom+level*floor_height
		var occupied:bool=(index+level*2)%4 in [1,2]
		if occupied:
			piece("lit_office",Vector3(x,y+floor_height*.52,-1.54),Vector3(2*r-.10,floor_height-.15,.10))
			piece("opal",Vector3(x,y+floor_height-.17,-1.18),Vector3(r*.92,.045,.15))
		piece("slate",Vector3(x,y+.09,-.70),Vector3(2*r,.18,1.86))
		piece("iron",Vector3(x,y+.18,.22),Vector3(2*r,.12,.12))
		for col in 4:
			var pane_x:=x+r*((col+.5)*.5-1.)
			if (col+index+level)%4!=0:
				var drop:=floor_height*(.32+.13*((col+level*2+index)%4))
				piece("lit_blind" if occupied else "blind",Vector3(pane_x,y+floor_height-drop*.5,-.54),Vector3(r*.48,drop,.055))
		pane(x,y+floor_height*.5,.18,r*2,floor_height-.11)
		piece("iron",Vector3(x,y+floor_height*.62,.24),Vector3(2*r,.058,.09))
	for col in range(-2,3):
		piece("iron",Vector3(x+col*r*.5,bottom+clear*.5,.25),Vector3(.082,clear,.14))
	piece("glass",Vector3(x,SPRING,.17),Vector3(r,r,.03),Vector3.ZERO,"fan")
	piece("iron",Vector3(x,SPRING,.27),Vector3(r*2,.08,.13))
	piece("iron",Vector3(x,SPRING,.27),Vector3(r*.41,r*.41,.12),Vector3.ZERO,"bead")
	for spoke in range(1,6):
		var dir:=Vector3(cos(spoke*PI/6.),sin(spoke*PI/6.),0)
		var center:=Vector3(x,SPRING,.28)
		bar(center+dir*r*.4,center+dir*r,.062,"iron")

func small_sash(x: float,y: float,w: float,h: float,z: float) -> void:
	piece("iron",Vector3(x,y,z),Vector3(w,h,.13))
	piece("office",Vector3(x,y,z+.07),Vector3(w-.14,h-.14,.045))
	piece("glass",Vector3(x,y,z+.11),Vector3(w-.16,h-.16,1.),Vector3.ZERO,"pane")
	piece("iron",Vector3(x,y+.16,z+.14),Vector3(w,.07,.10))
	piece("clay",Vector3(x,y-h*.5,z+.10),Vector3(w+.22,.14,.26))

func attic_pair(x: float,pitch: float) -> void:
	var h:=22.-ATTIC
	piece("brick",Vector3(x,ATTIC+h*.5,.12),Vector3(pitch,h,.65))
	for side in [-1.,1.]:
		small_sash(x+side*.85,20.75,1.41,2.08,.48)
	var panel_x:=x-pitch*.5+1.15
	piece("clay",Vector3(panel_x,20.78,.51),Vector3(2.10,.99,.18))
	piece("reveal",Vector3(panel_x,20.78,.61),Vector3(1.88,.78,.04))
	for i in 3:
		rosette(panel_x+(i-1)*.54,20.78,.22,.655)

func rosette(x: float,y: float,r: float,z: float) -> void:
	for j in 6:
		var a:=TAU*j/6.
		piece("clay",Vector3(x+cos(a)*r*.56,y+sin(a)*r*.56,z),Vector3(r*.83,.07,r*.53),Vector3(PI/2,0,a),"round")
	piece("keystone",Vector3(x,y,z+.03),Vector3(r*.55,.09,r*.55),Vector3(PI/2,0,0),"round")

func ornament(x: float,y: float) -> void:
	for layer in [[.94,.47],[.78,.54],[.63,.60]]:
		piece("clay" if layer[0]>.8 else "keystone",Vector3(x,y,layer[1]),Vector3(layer[0],.11,layer[0]),Vector3(PI/2,0,0),"round")

func fifth_shops() -> void:
	address_entry(0.,3.45)
	shop_bay(3.45,3.55,"CAFÉ",false,"iron")
	shop_bay(7.,3.25,"MONEY EXCHANGE",true,"blue")
	shop_bay(10.25,FIFTH_WIDTH-10.25,"Wendy’s",true,"shopmetal")
	# Sloping red fabric and its short vertical valance over the smaller shops.
	for span in [[4.92,2.85],[8.58,3.16],[11.75,2.9]]:
		var x:float=span[0]
		var w:float=span[1]
		piece("red",Vector3(x,3.52,.97),Vector3(w,.09,1.12),Vector3(.28,0,0))
		piece("red",Vector3(x,3.30,1.48),Vector3(w,.21,.07))
		for edge in [-1.,1.]:
			bar(Vector3(x+edge*w*.45,3.02,.43),Vector3(x+edge*w*.45,3.36,1.45),.031,"iron")

func side_shops() -> void:
	shop_bay(0.,8.1,"Wendy’s",false,"shopmetal")
	shop_bay(8.1,6.1,"",false,"red")
	shop_bay(14.2,6.6,"",false,"red")
	shop_bay(20.8,5.4,"",true,"red")
	shop_bay(26.2,SIDE_WIDTH-26.2,"",false,"shopmetal")
	for x in [9.45,24.90]:
		piece("iron",Vector3(x,4.37,.42),Vector3(1.18,.55,.12))
		for row in 6:
			piece("shopmetal",Vector3(x,4.16+row*.081,.51),Vector3(1.05,.036,.07))

func address_entry(start: float,w: float) -> void:
	var x:=start+w*.5
	var opening:=w-.74
	var radius:=opening*.5
	for side in [-1.,1.]:
		var edge:float=x+side*(w*.5-.15)
		piece("limestone",Vector3(edge,STORE_TOP*.5,.20),Vector3(.36,STORE_TOP,.88))
		collider(Vector3(edge,1.5,.20),Vector3(.36,3.,.88))
		piece("granite",Vector3(edge,.26,.27),Vector3(.44,.52,.91))
		rosette(edge,4.62,.14,.69)
	piece("limestone",Vector3(x,4.81,.20),Vector3(w-.60,1.08,.86))
	piece("limestone",Vector3(x,2.90,.20),Vector3(radius,radius,.86),Vector3.ZERO,"haunch")
	piece("iron",Vector3(x,2.90,.64),Vector3(radius,radius,.17),Vector3.ZERO,"arch")
	piece("clay",Vector3(x,2.90,.48),Vector3(radius*.92,radius*.92,.11),Vector3.ZERO,"fan")
	var number:=TextMesh.new()
	number.text="339"
	number.font_size=96
	number.pixel_size=.0067
	number.depth=.047
	var plate:=MeshInstance3D.new()
	plate.mesh=number
	plate.material_override=finishes["brass"]
	plate.transform=frame*Transform3D(Basis.IDENTITY,Vector3(x,3.36,.625))
	add_child(plate)
	piece("brass",Vector3(x+opening*.5+.17,1.28,.68),Vector3(.13,.22,.04))
	for i in 3:
		piece("iron",Vector3(x+opening*.5+.17,1.21+i*.05,.707),Vector3(.055,.023,.018))
	piece("iron",Vector3(x,2.89,.61),Vector3(opening+.18,.14,.35))
	piece("shopmetal",Vector3(x,2.795,.03),Vector3(opening,.21,.13))
	piece("wood",Vector3(x,2.82,-.52),Vector3(opening,.19,1.27))
	glass_doors(x,opening,.02)
	piece("granite",Vector3(x,.055,.35),Vector3(opening,.10,.93))
	practical(x,2.71,.36,Color("#ffda9f"),.90)

func glass_doors(x: float,w: float,z: float) -> void:
	# Outer doors, recessed threshold, and a separate set of inner doors.
	var inside:=z-1.15
	piece("slate",Vector3(x,1.39,inside-.12),Vector3(w,2.80,.13))
	for edge in [-1.,1.]:
		var dx:float=x+edge*w*.24
		piece("office",Vector3(dx,1.41,inside),Vector3(w*.45,2.48,.095))
		piece("wood",Vector3(dx,2.61,inside+.065),Vector3(w*.45,.08,.06))
		piece("reveal",Vector3(x+edge*(w*.5-.035),1.34,(z+inside)*.5),Vector3(.085,2.68,1.21))
	piece("limestone",Vector3(x,.035,(z+inside)*.5),Vector3(w,.065,1.25))
	piece("wood",Vector3(x,2.69,(z+inside)*.5),Vector3(w,.10,1.25))
	for side in [-1.,1.]:
		var center:float=x+side*w*.25
		pane(center,1.38,z,w*.5-.085,2.54)
		for edge in [-1.,1.]:
			piece("shopmetal",Vector3(center+edge*(w*.25-.024),1.36,z+.04),Vector3(.048,2.68,.085))
		for y in [.13,2.64]:
			piece("shopmetal",Vector3(center,y,z+.04),Vector3(w*.5,.14,.10))
		var handle_x:float=x+side*.15
		for y in [.91,1.32]:
			bar(Vector3(handle_x,y,z+.065),Vector3(handle_x,y,z+.18),.034,"brass")
		bar(Vector3(handle_x,.91,z+.18),Vector3(handle_x,1.32,z+.18),.039,"brass")
	collider(Vector3(x,1.34,z),Vector3(w,2.70,.10))

func shop_bay(start: float,w: float,sign_text: String,door: bool,metal: String) -> void:
	var x:=start+w*.5
	piece(metal,Vector3(x,4.52,.18),Vector3(w,.98,.61))
	piece("iron",Vector3(x,5.07,.30),Vector3(w,.13,.85))
	piece("slate",Vector3(x,2.0,-1.72),Vector3(w,4.1,.14))
	piece("wood",Vector3(x,3.94,-.64),Vector3(w,.14,2.26))
	piece("limestone",Vector3(x,.10,-.61),Vector3(w,.20,2.18))
	for edge in [-1.,1.]:
		var jamb:float=x+edge*(w*.5-.145)
		piece(metal,Vector3(jamb,2.03,.16),Vector3(.29,4.06,.68))
		piece("reveal",Vector3(jamb,2.03,-.83),Vector3(.29,4.06,1.75))
		collider(Vector3(jamb,1.5,.21),Vector3(.29,3.,.64))
	var span:=w-.30
	var door_w:=minf(1.95,span*.68) if door else 0.
	var display_w:=span-door_w
	var display_x:=x-door_w*.5
	pane(display_x,2.0,.14,display_w,3.64)
	collider(Vector3(display_x,1.65,.13),Vector3(display_w,3.30,.13))
	piece("granite",Vector3(display_x,.35,.19),Vector3(display_w,.65,.53))
	for post in range(1,ceili(display_w/1.47)):
		var px:=display_x+(float(post)/ceili(display_w/1.47)-.5)*display_w
		piece("iron",Vector3(px,2.16,.18),Vector3(.055,3.52,.095))
	piece("shopmetal",Vector3(display_x,3.12,.21),Vector3(display_w,.067,.09))
	# Nighttime window reveals, tables, and a lit ceiling set back from the sill.
	piece("opal",Vector3(display_x,3.78,-.86),Vector3(display_w*.63,.055,.18))
	piece("wood",Vector3(display_x,1.01,-.90),Vector3(display_w*.76,.09,.54))
	for edge in [-1.,1.]:
		piece("iron",Vector3(display_x+edge*display_w*.28,.59,-.91),Vector3(.09,.82,.38))
	if door:
		var dx:=x+(span-door_w)*.5
		glass_doors(dx,door_w,.035)
		pane(dx,3.34,.14,door_w,1.22)
	if sign_text!="":
		var color:=Color("#ee5349") if sign_text=="Wendy’s" else Color("#eee0c1")
		lettering(sign_text,Vector3(x,4.53,.52),.69 if sign_text=="Wendy’s" else .34,color)
	if sign_text=="Wendy’s":
		practical(x,4.02,.84,Color("#ffd2a3"),1.0)

func practical(x:float,y:float,z:float,color: Color,energy:float) -> void:
	piece("opal",Vector3(x,y,z),Vector3(.42,.06,.18))
	var light:=OmniLight3D.new()
	light.position=frame*Vector3(x,y-.14,z+.10)
	light.light_color=color
	light.omni_range=5.8
	light.light_energy=energy
	add_child(light)
