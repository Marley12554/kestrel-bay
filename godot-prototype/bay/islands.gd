extends "res://main.gd"
const Atlas=preload("res://bay/atlas.gd")
const Interior=preload("res://bay/interior.gd")
var atlas=Atlas.new()
var glass=StandardMaterial3D.new()
var shells=[]
var nearby_rooms={}
var broken_glass={}
var street_fixtures=PackedVector3Array()
var street_lights=[]
var room_units=[]
var dusk=-1.
var next_stream=0.
var stream_at=Vector3.INF
var day_time=98.
var night_lock=false
var gates=[]
var towers=[]
var security_cars=[]
var residents=[]
var smoke_clouds=[]
var effects=[]
var marks_on_road=[]
var fleet={}
var labels3=[]
var ui_root
var state_before_reset=""
var low_graphics=false
var mobile=false
var qa=false
var next_light=0.
var deck_shapes=[]
var building_shapes={}
const BASE=2.6

func loading_stage(phase:String):
	if qa and OS.has_feature("web"):JavaScriptBridge.eval("window.kbBootStages.push("+JSON.stringify(phase)+")")
func _ready():
	qa=OS.get_cmdline_user_args().has("--qa") or (OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa')")))
	mobile=OS.has_feature("mobile") or (OS.has_feature("web") and bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 1")))
	if qa and OS.has_feature("web"):JavaScriptBridge.eval("window.kbBootStages=window.kbBootStages||[]")
	low_graphics=OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('graphics') === 'low'"))
	if OS.has_feature("web"):
		update_render_budget()
		get_window().size_changed.connect(update_render_budget)
	loading_stage("city scene")
	var vertex_material=StandardMaterial3D.new()
	vertex_material.vertex_color_use_as_albedo=true
	vertex_material.roughness=.82
	var unit=BoxMesh.new();unit.material=vertex_material
	var drum=CylinderMesh.new();drum.radial_segments=10;drum.rings=1;drum.material=vertex_material
	room_units=[unit,drum]
	glass.albedo_color=Color(.30,.55,.60,.19)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	glass.roughness=.2
	super()
	environment.glow_enabled=not low_graphics
	if low_graphics:sun.shadow_enabled=false
	environment.glow_intensity=0.
	environment.glow_hdr_threshold=.86
	environment.glow_blend_mode=Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.glow_bloom=.04
	player.camera.far=5600
	player.camera.near=.16
	update_rooms(true)
func update_render_budget():
	var pixels=get_window().size
	var budget=960.*540. if low_graphics else (1280.*720. if mobile else 1920.*1080.)
	get_viewport().scaling_3d_scale=minf(.68 if low_graphics else (.72 if mobile else 1.),sqrt(budget/maxf(1.,float(pixels.x)*pixels.y)))

func lighting_warmup_views()->Array:
	var views=super()
	# Four distinct material paths, each exercised in daylight and at night.
	return [views[0],views[5],views[7],views[8]]
func diagnostics_enabled()->bool:return qa
func make_player()->CharacterBody3D:return preload("res://bay/rider.gd").new()
func make_director()->Node3D:return preload("res://bay/director.gd").new()
func _bind_controls():
	super()
	for pair in [["lean",KEY_Q],["crouch",KEY_C],["shotgun",KEY_3],["carbine",KEY_4],["tools",KEY_5],["board_air",KEY_F],["honkh",KEY_H],["shoot",KEY_J]]:
		InputMap.add_action(pair[0])
		var key=InputEventKey.new()
		key.physical_keycode=pair[1]
		InputMap.action_add_event(pair[0],key)
func _build_shore():
	# The near ocean follows the camera on a snapped grid; world-space wave
	# coordinates keep the surface attached to the coast and to the hulls.
	var sea=get_children().back()
	sea.name="TidalWater"
	var distant_sea=MeshInstance3D.new()
	var plane=PlaneMesh.new()
	plane.size=Vector2(30000,30000)
	distant_sea.mesh=plane
	distant_sea.material_override=material(Color("376678"))
	distant_sea.set_meta("dynamic",true)
	distant_sea.name="HorizonWater"
	distant_sea.position.y=-1.2
	var bottom=MeshInstance3D.new()
	bottom.mesh=plane
	var sand=ShaderMaterial.new()
	sand.shader=preload("res://bay/sand.gdshader")
	bottom.material_override=sand
	bottom.position.y=-11.4
	add_child(bottom)
	add_child(distant_sea)
	for index in atlas.outlines.size():
		var outline=atlas.outlines[index]
		build_shoreline(outline,atlas.shore_toes[index],index<2)
		# Extruded convex coast sections give a stable ground plane at each
		# street. A single giant, double-sided triangle soup snagged wheels.
		var body=StaticBody3D.new()
		add_child(body)
		for polygon in Geometry2D.decompose_polygon_in_convex(outline):
			var center=Vector2.ZERO
			for corner in polygon:center+=corner
			center/=polygon.size()
			var verts=PackedVector3Array()
			for corner in polygon:
				for height in [0.,-11.]:verts.append(Vector3(corner.x-center.x,height,corner.y-center.y))
			var hull=ConvexPolygonShape3D.new();hull.points=verts
			var shape=CollisionShape3D.new();shape.position=Vector3(center.x,BASE,center.y);shape.shape=hull
			body.add_child(shape)
# Use the same shoreline triangles for the camera and the swimmer.
func build_shoreline(outline:PackedVector2Array,toes:PackedVector3Array,sloped:bool):
	var faces=PackedVector3Array()
	for i in outline.size():
		var j=(i+1)%outline.size()
		var a=Vector3(outline[i].x,BASE,outline[i].y)
		var b=Vector3(outline[j].x,BASE,outline[j].y)
		faces.append_array(PackedVector3Array([a,toes[j],b,a,toes[i],toes[j]]))
	var surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if sloped:
		var sand=ShaderMaterial.new()
		sand.shader=preload("res://bay/sand.gdshader")
		surface.set_material(sand)
	else:surface.set_material(material(Color("847867")))
	for v in faces:surface.add_vertex(v)
	surface.generate_normals()
	var shore=MeshInstance3D.new()
	shore.mesh=surface.commit()
	add_child(shore)
	face_body(faces)
func face_body(faces:PackedVector3Array):
	var shape=ConcavePolygonShape3D.new()
	shape.backface_collision=true
	shape.set_faces(faces)
	var body=StaticBody3D.new()
	add_child(body)
	var coll=CollisionShape3D.new()
	coll.shape=shape
	body.add_child(coll)
	return body
func collision_box(body,at:Vector3,size:Vector3):
	var coll=CollisionShape3D.new()
	if not building_shapes.has(size):
		var bounds=BoxShape3D.new()
		bounds.size=size
		building_shapes[size]=bounds
	coll.shape=building_shapes[size]
	coll.position=at
	body.add_child(coll)
	return coll
func _build_district():
	add_child(preload("res://bay/data/city.scn").instantiate())
	for p in atlas.data.parcels:
		var body=StaticBody3D.new()
		add_child(body)
		body.set_meta("masonry",true)
		body.position=p.at
		var first=0
		while first<int(p.floors):
			var sz=Atlas.tier(p,first)
			var end=first+1
			while end<int(p.floors) and Atlas.tier(p,end)==sz:end+=1
			collision_box(body,Vector3(0,(first+end)*1.9,0),Vector3(sz.x,(end-first)*3.8,sz.y))
			first=end
		shells.append(body)
		footprints.append([p.at,Vector3(p.w,p.floors*3.8,p.d)])
	# The square and theater marquees are intentional breaks in the street grid.
	box(self,Vector3(20,2.65,96),Vector3(52,.11,44),Color("af9780"))
	for k in 3:cylinder(self,Vector3(24,2.8+k*.17,96),4.5-k*.65,.26,Color("897e6a"))
	var sculpture=box(self,Vector3(24,6.3,96),Vector3(.8,6,1.6),Color("ab844a"),true)
	sculpture.rotation.z=-.18
	for x in [-1,1]:
		for z in [-1,1]:
			var bench=Vector3(24+x*12,3.02,96+z*12)
			box(self,bench,Vector3(3,.19,.86),Color("755744"),true)
			for dx in [-1,1]:box(self,bench+Vector3(dx,-.2,0),Vector3(.12,.4,.76),Color("475451"))
	_build_theater_district()
	var circle=atlas.marks["Columbus Circle"]
	cylinder(self,circle+Vector3.UP*.10,9.45,.20,Color("9b9381"))
	for i in 3:cylinder(self,circle+Vector3.UP*(.32+i*.28),3.5-i*.58,.30,Color("a59d87"))
	cylinder(self,circle+Vector3.UP*5.1,.78,8.5,Color("a39c89"))
	cylinder(self,circle+Vector3.UP*9.4,1.18,.54,Color("9e987e"))
	var figure=box(self,circle+Vector3.UP*10.7,Vector3(1.15,2.38,.81),Color("595e53"),true)
	figure.rotation.y=.56
	_build_facilities()
	# Fixture positions correspond to the baked poles; the dynamic pool stays bounded.
	for e in atlas.data.roads:
		if e[4]=="bridge":continue
		var a=atlas.points[int(e[0])]
		var b=atlas.points[int(e[1])]
		var f=(b-a).normalized()
		for k in range(22,int(a.distance_to(b))-10,52):
			street_fixtures.append(a+f*k+f.cross(Vector3.UP)*(e[2]*.5+1.)+Vector3.UP*6.8)
	for i in 8:
		var light=OmniLight3D.new()
		add_child(light)
		light.omni_range=22
		light.light_energy=1.7
		light.light_color=Color("ffc589")
		street_lights.append(light)
func _build_theater_district():
	var atlas_art=load("res://bay/data/broadway.jpg")
	# All six faces sit on masonry. The eastern side of the corner tower
	# wraps onto Seventh Avenue, where the boards can be seen from Broadway.
	var square=atlas.marks["Times Square"]
	var arrangements=[
		[Vector2(-31,-32),false,17.,31.,0],[Vector2(-31,-32),false,33.,29.,1],
		[Vector2(-31,-32),true,19.,37.,2],[Vector2(-41,33),true,17.,36.,3],
		[Vector2(-70,-32),false,15.,31.,4],[Vector2(-31,-32),true,38.,30.,5]]
	for ad in arrangements:
		var wanted=square+Vector3(ad[0].x,0,ad[0].y)
		var nearest=null;var distance=INF
		for lot in atlas.neighbors(wanted,atlas.by_cell):
			var d=lot.at.distance_squared_to(wanted)
			if d<distance:distance=d;nearest=lot
		var panel=Node3D.new()
		add_child(panel)
		var east=ad[1];var width=float(ad[3]);var height=width*4./9.
		panel.position=nearest.at+Vector3(nearest.w*.5+.38 if east else 0.,ad[2],0. if east else nearest.d*.5+.38)
		panel.rotation.y=PI/2 if east else 0.
		box(panel,Vector3.ZERO,Vector3(width+.55,height+.52,.34),Color("26323a"))
		var material_ad=StandardMaterial3D.new()
		material_ad.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material_ad.albedo_texture=atlas_art
		material_ad.uv1_scale=Vector3(.498,.331,1)
		material_ad.uv1_offset=Vector3((ad[4]%2)*.5+.001,floori(ad[4]/2.)/3.+.001,0)
		var art=MeshInstance3D.new();art.mesh=QuadMesh.new();art.mesh.size=Vector2(width,height)
		art.material_override=material_ad;panel.add_child(art);art.position.z=.185
		for x in [-.36,.36]:box(panel,Vector3(width*x,-height*.5-.8,-.07),Vector3(.26,1.7,.44),Color("38404a"))
	var plaza=square+Vector3(32,0,30)
	box(self,plaza,Vector3(24,.18,25),Color("95897a"))
	for i in 7:
		box(self,plaza+Vector3(0,.15+i*.14,1+i*.85),Vector3(13,.25+i*.28,1.),Color("ae423a"),true)
	for x in [-9,9]:
		for z in [-8,6]:cylinder(self,plaza+Vector3(x,.45,z),1.05,.85,Color("4e6467"))
	make_sign(self,square+Vector3(5,4.1,4),"BROADWAY  /  TIMES SQUARE",.026)
func _build_waterfront():
	super()
	# Fixed piers and a sloped gangway meet the same exterior yard as the gate.
	box(self,Vector3(-410,1.5,603),Vector3(7,.38,38),Color("867865"),true)
	box(self,Vector3(-410,1.5,587),Vector3(22,.38,5),Color("867865"),true)
	var ramp=box(self,Vector3(-410,2.06,620),Vector3(7,.25,12),Color("827763"),true)
	ramp.rotation.x=-.088
	for x in [-420,-400]:
		for z in [588,601]:cylinder(self,Vector3(x,.15,z),.36,3.8,Color("655844"))
	make_sign(self,Vector3(-410,4.1,622),"BLACKWATER  /  SERVICE LANDING",.023,PI)
	for j in range(6):
		box(self,Vector3(154,3.8+j%2*2.6,55+j*9),Vector3(12,2.5,3),[Color("8c5343"),Color("536c72"),Color("958552")][j%3],true)
func _build_bridge():
	var bridges={}
	for edge in atlas.data.roads:
		if edge[4]=="bridge":
			if not bridges.has(edge[3]):bridges[edge[3]]=[]
			bridges[edge[3]].append(edge)
	for crossing in bridges:
		var edges=bridges[crossing]
		var corners=[]
		var faces=PackedVector3Array()
		for i in range(edges.size()+1):
			var edge=edges[mini(i,edges.size()-1)]
			var a=atlas.points[int(edge[0])]
			var b=atlas.points[int(edge[1])]
			var center=b if i==edges.size() else a
			var right=(b-a).cross(Vector3.UP).normalized()
			if i>0 and i<edges.size():
				var prev=atlas.points[int(edges[i-1][0])]
				right=(right+(a-prev).cross(Vector3.UP).normalized()).normalized()
			var half_width=float(edge[2])*.5+1.85
			corners.append([center-right*half_width,center+right*half_width])
		for i in edges.size():
			var left=corners[i][0];var right=corners[i][1]
			var end_left=corners[i+1][0];var end_right=corners[i+1][1]
			var down=Vector3.DOWN*.6
			bridge_quad(faces,left,right,end_right,end_left)
			bridge_quad(faces,end_left+down,end_right+down,right+down,left+down)
			bridge_quad(faces,left,end_left,end_left+down,left+down)
			bridge_quad(faces,end_right,right,right+down,end_right+down)
			for side in 2:
				var start=corners[i][side];var end=corners[i+1][side]
				var forward=(end-start).normalized()
				# Leave the first intersection open for turning traffic.
				if i==0:start+=forward*14
				if i==edges.size()-1:end-=forward*14
				var rail=box(self,(start+end)*.5+Vector3.UP*.62,Vector3(.13,1.22,start.distance_to(end)),Color("78878a"),true)
				rail.look_at(end+Vector3.UP*.62)
			var center=(left+right)*.5
			if center.y>12.:
				box(self,Vector3(center.x,(center.y-1)*.5,center.z),Vector3(2.5,center.y-1,3.5),Color("817e73"),true)
		for end in [corners.front(),corners.back()]:
			bridge_quad(faces,end[0],end[1],end[1]+Vector3.DOWN*.6,end[0]+Vector3.DOWN*.6)
		var deck=face_body(faces)
		deck.name=String(crossing).replace(" ","")+"Deck"
		deck_shapes.append(deck)
func bridge_quad(target:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
	for vertex in [a,b,c,a,c,d]:target.append(vertex)
func _build_facilities():
	# North sally port is outside the compound. The intake house has the alternate card.
	for s in [-1,1]:
		box(self,Vector3(-412+s*91,6.2,764),Vector3(1.6,7.2,211),Color("8c9186"),true)
		box(self,Vector3(-412+s*48.5,6.2,659),Vector3(85,7.2,1.7),Color("8c9186"),true)
	box(self,Vector3(-412,6.2,869),Vector3(184,7.2,1.7),Color("8c9186"),true)
	var gate=box(self,Vector3(-412,5.75,659),Vector3(12,6.3,.62),Color("506164"),true)
	gate.set_meta("dynamic",true)
	gates.append(gate)
	for p in [Vector3(-431,2.6,645),Vector3(-395,2.6,645)]:
		box(self,p+Vector3.UP*1.7,Vector3(6,3.4,6),Color("a5a18f"),true)
		box(self,p+Vector3(0,2.2,-3.04),Vector3(4.8,1.1,.12),Color("476670"))
	box(self,atlas.marks["Substation"]+Vector3.UP,Vector3(2.6,2,1.3),Color("62797a"),true)
	make_sign(self,atlas.marks["Substation"]+Vector3(0,1.65,-.78),"POWER  07",.012,PI)
	for p in [Vector3(-503,2.6,659),Vector3(-321,2.6,659),Vector3(-503,2.6,867),Vector3(-321,2.6,867)]:
		for dx in [-1.8,1.8]:
			for dz in [-1.8,1.8]:box(self,p+Vector3(dx,5,dz),Vector3(.48,10,.48),Color("5a6a68"),true)
		box(self,p+Vector3.UP*10,Vector3(6,1,6),Color("9c9d8c"),true)
		box(self,p+Vector3.UP*11.5,Vector3(4.5,2.4,4.5),Color("536c72"),true)
		box(self,p+Vector3.UP*13,Vector3(6,.45,6),Color("6e7774"))
		var spot=SpotLight3D.new()
		add_child(spot)
		spot.position=p+Vector3.UP*12
		spot.spot_range=155
		spot.spot_angle=15
		spot.light_energy=4
		towers.append(spot)
	box(self,Vector3(987,2.68,400),Vector3(498,.12,32),Color("495052"))
	for x in range(755,1220,18):box(self,Vector3(x,2.78,400),Vector3(9,.035,.3),Color("dfd6b5"))
	for s in [-1,1]:
		box(self,Vector3(830,4.1,259+s*4),Vector3(348,3,.35),Color("728172"),true)
	cylinder(self,atlas.marks["Fort radar"]+Vector3.UP*3,1,6,Color("7c837b"))
	var radar=cylinder(self,atlas.marks["Fort radar"]+Vector3.UP*6.7,3,.42,Color("adaca0"))
	radar.rotation.z=.44
func business(p):
	var names=["MORROW","BAXTER","SALT & STEM","ORCHARD","CRESCENT","FULTON","HART","EASTLINE","LEXINGTON","UNION"]
	return names[int(p.seed)%names.size()]+" "+str(p.style).to_upper()
func update_rooms(force=false):
	if not player:return
	var pos=player.position
	if not force and clock<next_stream:return
	next_stream=clock+.10
	var wanted_rooms={}
	var pending_room=null
	var nearest_pending=INF
	for p in atlas.neighbors(pos,atlas.by_cell):
		var delta=Vector2(maxf(0,absf(p.x-pos.x)-p.w*.5),maxf(0,absf(p.z-pos.z)-p.d*.5))
		var id=int(p.id)
		var range_m=20. if nearby_rooms.has(id) else 15.
		if delta.length()>range_m or pos.y>p.at.y+p.floors*3.8+range_m:continue
		wanted_rooms[id]=true
		if not nearby_rooms.has(id):
			if not force and delta.length_squared()>9.:
				if delta.length_squared()<nearest_pending:
					nearest_pending=delta.length_squared()
					pending_room=p
				continue
			open_parcel(p)
		nearby_rooms[id].refresh(pos)
	# A street corner can expose four frontages in a single frame. Build the
	# closest approaching one first while keeping door thresholds synchronous.
	if pending_room!=null:
		open_parcel(pending_room)
		next_stream=clock+.025
	for id in nearby_rooms.keys():
		if not wanted_rooms.has(id):
			shells[id].collision_layer=1
			nearby_rooms[id].queue_free()
			nearby_rooms.erase(id)
func open_parcel(p):
	var room=Interior.new()
	add_child(room)
	room.configure(self,p)
	nearby_rooms[int(p.id)]=room
	shells[int(p.id)].collision_layer=0
func nearby_lift():
	if not player or player.vehicle:return null
	for room in nearby_rooms.values():
		if not room.lift:continue
		var base=room.position+Vector3(room.shaft.x,0,room.shaft.y)
		var p=player.position-base
		if absf(p.x)<2.55 and p.z>-2.1 and p.z<3.9 and p.y>=-.35 and p.y<room.floors*3.8+.5:return room
	return null
func _build_vehicles():
	for spec in [["starter",Vector3(-5,2.85,108)],["cruiser",Vector3(-73,2.8,55)],["cruiser",Vector3(58,2.8,-5)],
			["launch",Vector3(10,.1,168)],["marine",Vector3(-75,0,202)],["marine",Vector3(-380,0,538)]]:
		var v=spawn_vehicle(spec[0],spec[1])
		if v.boat or v.police:v.rotation.y=PI
		v.home_heading=v.rotation.y
	for spec in [["cruiser","Lower Manhattan"],["cruiser","Midtown"],["cruiser","Astoria"],["security","Blackwater Administration"],["army","Fort Halcyon"],["tank","Fort radar"]]:
		var v=spawn_vehicle(spec[0],atlas.marks[spec[1]]+Vector3(4,.3,-7))
		if v.model in ["security","army","tank"]:security_cars.append(v)
	spawn_vehicle("helicopter",Vector3(757,2.85,383))
	var plane=spawn_vehicle("plane",Vector3(920,2.9,400))
	plane.home_heading=-PI/2
	plane.rotation.y=plane.home_heading
func spawn_vehicle(model:String,pos:Vector3):
	var v=preload("res://bay/motor.gd").new()
	v.model=model
	v.name=model.capitalize()+str(vehicles.size())
	add_child(v)
	v.configure(self,pos,model in ["launch","marine"],model in ["cruiser","security","army","tank","marine"],vehicles.size()%3)
	vehicles.append(v)
	if not fleet.has(model):fleet[model]=[]
	fleet[model].append(v)
	return v
func _build_ui():
	super()
	ui_root=start_panel.get_parent()
	for c in ui_root.get_children():
		if c is Label:c.hide()
	var column=start_panel.get_child(0)
	column.get_child(0).text="KESTREL BAY"
	column.get_child(0).add_theme_font_size_override("font_size",36)
	column.get_child(1).text="NEW YORK HARBOR\n\nWalk, drive or take a boat across the bay.\nOpen the map to choose an operation.\n\nWASD move   ·   Mouse look   ·   E interact\nShift sprint / handbrake   ·   M map   ·   1–5 equipment"
	if mobile:column.get_child(1).text="NEW YORK HARBOR\n\nUse the left stick to move and drag the view to look.\nOpen the map to choose an operation."
	start_button.text="ENTER THE CITY"
func start_test():
	super()
	if started:
		player.reset_player(Vector3(5,2.91,134))
		player.yaw=1.36
		if mobile:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func _process(dt):
	RenderingServer.global_shader_parameter_set("kb_traffic_clock",clock)
	super(dt)
	if not player or not started:return
	if not night_lock:day_time=fmod(day_time+dt,600.)
	var dark=night_lock or day_time>=300.
	if dark!=night:set_night(dark)
	# Continuous dawn and dusk exposures span the 06:00 and 18:00 thresholds.
	var blend=1. if night_lock else smoothstep(-.15,.15,-sin(day_time*TAU/600.))
	if absf(blend-dusk)>.002 or dark!=night:
		dusk=blend
		sun.light_energy=lerpf(.95,.085,blend)
		sun.light_color=Color("fff1d3").lerp(Color("98b3dd"),blend)
		environment.ambient_light_energy=lerpf(.35,.17,blend)
		var sky=environment.sky.sky_material
		sky.sky_top_color=Color("385d75").lerp(Color("081522"),blend)
		sky.sky_horizon_color=Color("c1d2d3").lerp(Color("243e51"),blend)
		sky.ground_horizon_color=sky.sky_horizon_color
		sky.ground_bottom_color=Color("394b52").lerp(Color("0b1823"),blend)
	RenderingServer.global_shader_parameter_set("kb_eye",player.camera.global_position)
	var lamp_power=1. if night_lock else smoothstep(316.,341.,day_time)*(1.-smoothstep(578.,598.,day_time))
	RenderingServer.global_shader_parameter_set("kb_dark",lamp_power)
	environment.glow_intensity=.78*lamp_power
	get_node("HorizonWater").visible=not environment.fog_enabled
	for lamp in lamps:lamp.visible=lamp_power>.05
	var sea=get_node_or_null("TidalWater")
	if sea:sea.position=Vector3(round(player.position.x/4)*4,0,round(player.position.z/4)*4)
	update_rooms()
	if clock>=next_light:
		next_light=clock+.45
		var near=[]
		if lamp_power>.02:
			for pt in street_fixtures:
				if pt.distance_squared_to(player.position)<6400:near.append(pt)
			near.sort_custom(func(a,b):return a.distance_squared_to(player.position)<b.distance_squared_to(player.position))
		for i in street_lights.size():
			var light=street_lights[i]
			light.visible=i<near.size()
			if light.visible:
				light.position=near[i]
				light.light_energy=1.7*lamp_power
	for i in towers.size():
		var t=towers[i]
		t.visible=night and not ops.campaign.power_off
		t.rotation=Vector3(-.23,PI+sin(clock*.14+i*1.55)*.88,0)
	if not gates.is_empty():gates[0].position.x=move_toward(gates[0].position.x,-398. if ops.campaign.gate_open else -412.,dt*3.8)

var rehearsal
func begin_drive(mode):
	var graph=atlas.graph
	var path=PackedVector3Array()
	var car=vehicles[0]
	if mode=="route":
		path=graph.get_point_path(graph.get_closest_point(atlas.marks["Astoria"]),graph.get_closest_point(atlas.marks["Uptown"]))
		car=spawn_vehicle("sedan",path[0]);car.owned=true
	else:
		var first=graph.get_closest_point(Vector3(-135,2.6,65))
		var last=graph.get_closest_point(atlas.marks["Battery House Hotel"])
		path=graph.get_point_path(first,last)
		var hotel=atlas.marks["Battery House Hotel"]
		path.append(Vector3(hotel.x,2.65,path[-1].z))
		day_time=434.;set_night(true)
	rehearsal=preload("res://bay/qa_drive.gd").new()
	rehearsal.configure(self,car,path,13.8 if mode=="route" else 19.,mode)
	if mode=="bridge":ops.alert(car.position,5);ops.observe(car.position)
func _physics_process(dt):
	if rehearsal and rehearsal.underway:rehearsal.update(dt)
func snapshot()->Dictionary:
	var info=super()
	info["job"]=ops.campaign.job
	info["job_step"]=ops.campaign.step
	info["room_count"]=nearby_rooms.size()
	info["region"]=atlas.region(player.position)
	info["slot"]=ops.weapon_slot
	info["yaw"]=player.yaw
	info["mobile"]=mobile
	info["low_graphics"]=low_graphics
	info["hands_visible"]=ops.hands.visible
	info["sounding_cruisers"]=ops.audio.sirens.filter(func(s):return s.player.playing).size()
	info["boat_engine"]=player.vehicle!=null and player.vehicle.boat and ops.audio.engine.stream==ops.audio.marine_engine
	info["touch_sprint"]=player.mobile_sprint
	var dimensions=get_viewport().get_visible_rect().size
	var button_center=start_button.get_global_transform_with_canvas()*(start_button.size*.5)/dimensions
	info["enter_uv"]=[button_center.x,button_center.y]
	info["touch_uv"]={}
	for id in ops.hud.mobile_buttons:
		var uv=ops.hud.get_global_transform_with_canvas()*Vector2(ops.hud.mobile_buttons[id])/dimensions
		info.touch_uv[id]=[uv.x,uv.y]
	info["buttons"]={}
	if ops.map_open:
		for btn in ops.hud.map_buttons+[ops.hud.accept_button]:
			info.buttons[btn.text]=[btn.global_position.x,btn.global_position.y,btn.size.x,btn.size.y]
	if rehearsal:
		info["drive"]={"elapsed":rehearsal.elapsed,"distance":rehearsal.progress,"leg":rehearsal.segment,"active":rehearsal.underway,"finished":rehearsal.finished,"hotel":rehearsal.hotel_walk}
	return info
func _browser_command(args:Array):
	if not qa or args.is_empty():return
	var id=String(args[0])
	match id:
		"flyover":
			player.reset_player(Vector3(-465,123,-670))
			var plane=fleet.plane[0]
			plane.position=player.position;plane.rotation=Vector3(0,1.71,0)
			plane.speed=51.;plane.velocity=-plane.global_basis.z*51.;plane.air_throttle=.66
			player.board(plane);player.yaw=plane.rotation.y;player.pitch=-.06
			day_time=434.;set_night(true)
		"riverbank":
			var line=atlas.outlines[1]
			var mid=(line[2]+line[3])*.5
			var f=(line[3]-line[2]).normalized()
			var n=Vector3(f.y,0,-f.x)
			player.reset_player(Vector3(mid.x,-.60,mid.y)+n*12.)
			player.yaw=atan2(n.x,n.z);player.pitch=.06
			update_rooms(true)
		"bridge_run","route_run":begin_drive("bridge" if id=="bridge_run" else "route")
		"square","park","observatory","blackwater","skyline","battery","fort","billboards":
			var places={"square":["Times Square",Vector3(0,.3,-4),PI*.73,.18],"park":["Central Park",Vector3(3,.3,-8),-.24,.08],"observatory":["Empire State Building",Vector3(2,326.96,-19),-PI*.62,-.30],"blackwater":["Blackwater Service Dock",Vector3(0,.16,0),PI,.02],"skyline":["Brooklyn Bridge",Vector3(8,.18,-3),PI*.48,.16],"battery":["Battery House Hotel",Vector3(0,.14,2),0.,.07],"fort":["Fort Halcyon",Vector3(0,.14,2),-2.2,.1],"billboards":["Times Square",Vector3(4,.3,49),.38,.23]}
			var spot=places[id]
			player.reset_player(atlas.marks[spot[0]]+spot[1]);player.yaw=spot[2];player.pitch=spot[3]
			update_rooms(true)
		"night":day_time=450 if not night else 150;set_night(day_time>=300)
		"map":ops.toggle_map()
		_:super(args)
