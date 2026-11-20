extends Node3D

const Vehicle = preload("res://vehicle.gd")
const Player = preload("res://player.gd")
var player: CharacterBody3D
var vehicles: Array = []
var materials = {}
var ops: Node3D
var footprints: Array = []
var clock = 0.0
var night = false
var chase = false
var sun: DirectionalLight3D
var environment: Environment
var water: ShaderMaterial
var lamps: Array = []
var hud: Label
var hint: Label
var speed_label: Label
var start_panel: Control
var stat_clock = 0.0
var started = false
var test_callback: JavaScriptObject
var warmup_ready = false
var warmup_rendered_views = 0
var warmup_duration_ms = 0
var warmup_cover: ColorRect
var warmup_label: Label
var start_button: Button
var warmup_active = true
var night_switches: Array = []

func loading_stage(_phase:String) -> void:
	pass

func _ready() -> void:
	loading_stage("controls")
	_bind_controls()
	_build_environment()
	loading_stage("city")
	_build_district()
	_build_hotel()
	_build_waterfront()
	_build_bridge()
	loading_stage("fleet")
	_build_vehicles()
	player = make_player()
	add_child(player)
	player.name = "Player"
	player.configure(self)
	player.camera.current = true
	player.camera.fov = 78
	player.camera.far = 1400
	player.reset_player(Vector3(0,2.9,96))
	loading_stage("interface")
	_build_ui()
	ops = make_director()
	add_child(ops)
	loading_stage("operations")
	ops.configure(self)
	loading_stage("batching")
	_batch_static_visuals()
	player.set_process(false)
	for v in vehicles:
		v.set_physics_process(false)
	if OS.has_feature("web") and diagnostics_enabled():
		test_callback = JavaScriptBridge.create_callback(_browser_command)
		JavaScriptBridge.get_interface("window").kbGodotCommand = test_callback
		JavaScriptBridge.eval("window.kbGodotReady=true")
	set_night(false)
	_prepare_lighting.call_deferred()
	print("GODOT_PROTOTYPE_READY vehicles=",vehicles.size()," renderer=Compatibility; units=meters")

func make_player() -> CharacterBody3D:
	return Player.new()

func make_director() -> Node3D:
	return preload("res://operations.gd").new()

func lighting_warmup_views() -> Array:
	# Render real world surfaces with both local-light types and material paths.
	return [
		[Vector3(0,4.4,96),Vector3(0,5,-20),false],
		[Vector3(0,4.4,96),Vector3(-85,6,30),false],
		[Vector3(0,4.4,96),Vector3(95,12,30),false],
		[Vector3(-5,5,116),Vector3(-5,3,86),false],
		[Vector3(-45,4.25,33),Vector3(-45,4.25,16),false],
		[Vector3(4,3.5,163),Vector3(25,1,190),false],
		[Vector3(10,3,158),Vector3(10,0,193),false],
		[Vector3(10,-2,193),Vector3(10,-2,215),true],
		[Vector3(-54.5,8.45,28),Vector3(-53,8.2,18),false],
		[Vector3(-75,4,63),Vector3(-75,4,53),false]
	]

func _prepare_lighting() -> void:
	var begin = Time.get_ticks_msec()
	# Headless checks cannot compile GPU shaders or await actual rendered frames.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var views = lighting_warmup_views()
		ops.gun.visible = true
		for dark in [false,true]:
			set_night(dark)
			for view in views:
				player.camera.global_position = view[0]
				player.camera.look_at(view[1])
				set_underwater_fog(view[2])
				warmup_label.text = "Preparing lighting… %d%%" % roundi(100.0*warmup_rendered_views/(views.size()*2))
				# Resource preload alone doesn't compile Compatibility/WebGL variants.
				# Keep the actual 3D view drawing beneath the opaque loading screen.
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				warmup_rendered_views += 1
	ops.gun.visible = false
	set_night(false)
	set_underwater_fog(false)
	player.camera.position = Vector3(0,1.65,0)
	player.camera.rotation = Vector3(player.pitch,player.yaw,0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	while not ops.routes_ready:
		await get_tree().process_frame
	warmup_duration_ms = Time.get_ticks_msec()-begin
	warmup_active = false
	warmup_ready = true
	warmup_cover.hide()
	start_button.disabled = false
	player.set_process(true)
	print("LIGHTING_WARMUP_COMPLETE views=",warmup_rendered_views," duration_ms=",warmup_duration_ms)

func set_underwater_fog(underwater: bool) -> void:
	environment.fog_enabled = underwater
	if underwater:
		environment.fog_light_color = Color("126479")
		environment.fog_density = .13

func _bind_controls() -> void:
	var actions = {
		"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],
		"jump":[KEY_SPACE],"sprint":[KEY_SHIFT],"handbrake":[KEY_SHIFT,KEY_SPACE,KEY_X],
		"interact":[KEY_E],"pause":[KEY_ESCAPE],"reset":[KEY_BACKSPACE],"night":[KEY_N],"chase":[KEY_P],"dock":[KEY_B],
		"unarmed":[KEY_1,KEY_H],"pistol":[KEY_2],"reload":[KEY_R],"map":[KEY_M]
	}
	for action in actions:
		InputMap.add_action(action)
		for key in actions[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func material(color: Color, emissive: bool=false) -> StandardMaterial3D:
	var key = color.to_html()+str(emissive)
	if not materials.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = .76
		if emissive:
			m.emission_enabled = true
			m.emission = color
		materials[key] = m
	return materials[key]

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool=false) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = at
	if solid:
		var body = StaticBody3D.new()
		mesh.add_child(body)
		var collider = CollisionShape3D.new()
		var bounds = BoxShape3D.new()
		bounds.size = size
		collider.shape = bounds
		body.add_child(collider)
	return mesh

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = at
	return mesh

func make_sign(parent: Node3D, at: Vector3, text: String, pixel_size: float, angle: float=0) -> Label3D:
	var label = Label3D.new()
	parent.add_child(label)
	label.text = text
	label.position = at
	label.pixel_size = pixel_size
	label.font_size = 40
	label.double_sided = false
	label.outline_size = 4
	label.modulate = Color("fff0cd")
	label.rotation.y = angle
	return label

func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var atmosphere = ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("385d75")
	atmosphere.sky_horizon_color = Color("c1d2d3")
	atmosphere.ground_horizon_color = Color("b3c4c5")
	atmosphere.ground_bottom_color = Color("394b52")
	sky.sky_material = atmosphere
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a5bccb")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8eabb4")
	environment.ambient_light_energy = .35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("fff1d3")
	sun.light_energy = .95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	sun.shadow_bias = .06
	var sea = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(1200,1200)
	plane.subdivide_width = 220
	plane.subdivide_depth = 220
	sea.mesh = plane
	water = ShaderMaterial.new()
	water.shader = preload("res://water.gdshader")
	sea.material_override = water
	sea.position = Vector3(80,0,100)
	add_child(sea)
	_build_shore()

func _build_shore() -> void:
	box(self,Vector3(0,0,-8),Vector3(350,5.2,296),Color("7d8072"),true)
	box(self,Vector3(0,2.64,0),Vector3(345,.08,283),Color("b9b2a0"))

func _build_district() -> void:
	# A connected street network, a civic square, a waterfront and a tower cluster.
	for x in [-135,-75,-15,55,125]:
		box(self,Vector3(x,2.70,-4),Vector3(13,.06,280),Color("35434b"))
		for z in range(-138,130,10):
			box(self,Vector3(x,2.74,z),Vector3(.16,.02,3.6),Color("d6c39b"))
	for z in [-125,-65,-5,65,125]:
		box(self,Vector3(-4,2.71,z),Vector3(328,.06,13),Color("35434b"))
		for x in range(-160,155,10):
			box(self,Vector3(x,2.75,z),Vector3(3.6,.02,.16),Color("d6c39b"))
	var specs = [
		[-106,-95,29,33,22],[-46,-95,29,30,41],[20,-95,37,32,74],[90,-95,35,34,92],
		[-106,-35,30,30,18],[-46,-35,30,28,30],[20,-35,34,30,65],[90,-35,33,29,78],
		[-106,28,29,34,17],[20,28,27,30,37],[90,28,31,32,55],
		[-106,96,28,28,12],[-46,96,27,28,15],[90,96,29,28,18]
	]
	for i in specs.size():
		var s = specs[i]
		_build_tower(Vector3(s[0],2.8,s[1]),Vector3(s[2],s[4],s[3]),i)
	# Monument square: occupied public space rather than leftover lawn.
	box(self,Vector3(20,2.80,96),Vector3(48,.18,40),Color("aa947b"))
	cylinder(self,Vector3(20,3,96),9,.35,Color("656f74"))
	cylinder(self,Vector3(20,3.3,96),7,.3,Color("345d67"))
	box(self,Vector3(20,7.2,96),Vector3(1.6,7.5,1.6),Color("977e4f"),true)
	var monument = box(self,Vector3(20,12.5,96),Vector3(2,4,2),Color("cab179"))
	monument.rotation.z = .4
	make_sign(self,Vector3(20,3.9,104),"FOUNDER'S SQUARE",.025)
	for p in [Vector3(3,2.8,84),Vector3(38,2.8,84),Vector3(3,2.8,110),Vector3(38,2.8,110)]:
		_tree(p)
		box(self,p+Vector3(2,.5,0),Vector3(2,.4,.7),Color("68513b"),true)
	for x in [-145,-66,-6,64,134]:
		for z in [-112,-50,12,80,122]:
			_lamp(Vector3(x,2.8,z))

func _build_tower(at: Vector3, size: Vector3, variant: int) -> void:
	footprints.append([at,size])
	var palette = [Color("b6ad98"),Color("876951"),Color("89979b"),Color("617780")]
	box(self,at+Vector3.UP*size.y*.5,size,palette[variant%4],true)
	# Recessed glazing is instanced once per building, not thousands of scene nodes.
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var window_mesh = BoxMesh.new()
	window_mesh.size = Vector3(1.6,1.95,.1)
	mm.mesh = window_mesh
	var panes: Array = []
	for level in range(1,int(size.y/3.5)):
		for side in [-1,1]:
			for x in range(2,int(size.x)-1,3):
				panes.append(Transform3D(Basis.IDENTITY,at+Vector3(x-size.x/2,level*3.5,side*(size.z/2+.06))))
			for z in range(2,int(size.z)-1,3):
				panes.append(Transform3D(Basis(Vector3.UP,PI/2),at+Vector3(side*(size.x/2+.06),level*3.5,z-size.z/2)))
	mm.instance_count = panes.size()
	for i in panes.size():
		mm.set_instance_transform(i,panes[i])
		mm.set_instance_color(i,Color("a2bdc8") if i%9 else Color("ddc497"))
	var facade = MultiMeshInstance3D.new()
	facade.multimesh = mm
	var glass = StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.roughness = .25
	glass.metallic = .5
	facade.material_override = glass
	add_child(facade)
	box(self,at+Vector3(0,size.y+.2,0),Vector3(size.x+1,.4,size.z+1),Color("344550"))
	if size.y>50:
		box(self,at+Vector3(0,size.y+3,0),Vector3(size.x*.6,6,size.z*.65),palette[(variant+1)%4],true)
	# Street-level storefronts and doors connect to the sidewalk, not enclosed lots.
	box(self,at+Vector3(0,1.8,size.z/2+.08),Vector3(size.x*.85,2.4,.1),Color("304f5b"))
	make_sign(self,at+Vector3(0,3.2,size.z/2+.18),["NORTHLINE","COPPER & CO.","ATLAS HOUSE","BAY EXCHANGE"][variant%4],.033)

func _build_hotel() -> void:
	var x = -45.0
	var z = 27.0
	footprints.append([Vector3(-45,2.6,27),Vector3(28,8.4,26)])
	var floor_y = 2.6
	for floor_index in 2:
		var y = floor_y+floor_index*4.2
		if floor_index==0:
			box(self,Vector3(x,y-.12,z),Vector3(28,.24,26),Color("aa9f87"),true)
		else:
			box(self,Vector3(-48.5,y-.12,z),Vector3(21,.24,26),Color("aa9f87"),true)
			box(self,Vector3(-34.5,y-.12,30),Vector3(7,.24,20),Color("aa9f87"),true)
			box(self,Vector3(-34.5,y-.12,19.7),Vector3(3.8,.24,.8),Color("818b87"),true)
		# South entrance is a real 3.6 m gap through the facade.
		for side in [-1,1]:
			box(self,Vector3(x+side*7.9,y+1.9,z+13),Vector3(12.2,3.8,.35),Color("d0bea0"),true)
		box(self,Vector3(x,y+3.65,z+13),Vector3(3.6,.5,.35),Color("d0bea0"),true)
		box(self,Vector3(x+14,y+1.9,z),Vector3(.35,3.8,26),Color("c8b89d"),true)
		box(self,Vector3(x,y+.4,z-13),Vector3(28,.8,.35),Color("c8b89d"),true)
		box(self,Vector3(x,y+3.45,z-13),Vector3(28,.7,.35),Color("c8b89d"),true)
		for wx in [-58.5,-51.75,-45.0,-38.25,-31.5]:
			box(self,Vector3(wx,y+1.9,z-13),Vector3(.55,2.2,.35),Color("c8b89d"),true)
		# West opening leads to the actual upper landing; no teleport/interior pocket.
		for offset in [-8.25,6.25]:
			box(self,Vector3(x-14,y+1.9,z+offset),Vector3(.35,3.8,9.5 if offset<0 else 13.5),Color("c8b89d"),true)
		box(self,Vector3(x-14,y+3.65,z-1),Vector3(.35,.5,3),Color("c8b89d"),true)
		# Clear central circulation, furniture pushed to edges.
		if floor_index==0:
			box(self,Vector3(-52,y+.6,20),Vector3(6,1.2,1.7),Color("5e4939"),true)
		box(self,Vector3(x-8,y+.45,z+6),Vector3(2.8,.9,1),Color("3b6969"),true)
		box(self,Vector3(x+5,y+.3,z+4),Vector3(2,.6,1.2),Color("76694e"),true)
		for sx in [-8,0,8]:
			box(self,Vector3(x+sx,y+3.6,z),Vector3(1.4,.08,.6),Color("fff0bb"))
	box(self,Vector3(x,11.25,z),Vector3(29,.35,27),Color("344550"),true)
	make_sign(self,Vector3(x,6.3,z+13.3),"THE BREAKWATER",.048)
	make_sign(self,Vector3(x,4.6,z-12.7),"RECEPTION  /  WATERFRONT LOUNGE",.019)
	# Exterior stair uses a continuous physical slope under visible treads.
	var steps = 24
	var top = 6.8
	var bottom = 2.6
	var ramp_mesh = ArrayMesh.new()
	var verts = PackedVector3Array([
		Vector3(-63,bottom,46),Vector3(-66,top,29),Vector3(-66,bottom,46),
		Vector3(-63,bottom,46),Vector3(-63,top,29),Vector3(-66,top,29)])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	ramp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ramp = StaticBody3D.new()
	var collider = CollisionShape3D.new()
	collider.shape = ramp_mesh.create_trimesh_shape()
	collider.shape.backface_collision = true
	ramp.add_child(collider)
	add_child(ramp)
	for i in steps:
		var t = float(i+1)/steps
		box(self,Vector3(-64.5,lerpf(bottom,top,t)-.12,46-t*17+.35),Vector3(3,.15,17.0/steps),Color("727f80"))
	box(self,Vector3(-62,6.67,27),Vector3(7,.26,4),Color("727f80"),true)
	for side_x in [-63.0,-66.0]:
		var rail = box(self,Vector3(side_x,5.7,37.5),Vector3(.10,.1,17.52),Color("a4b3ad"))
		rail.rotation.x = atan2(4.2,17)
		# A matching continuous collision rail prevents walking through the handrail.
		var barrier = box(self,Vector3(side_x,4.75,37.5),Vector3(.1,1.05,17.52),Color("70817e"),true)
		barrier.rotation.x = atan2(4.2,17)

func _tree(at: Vector3) -> void:
	cylinder(self,at+Vector3.UP*2.5,.24,5,Color("645346"))
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var trunk = CylinderShape3D.new()
	trunk.radius = .26
	trunk.height = 5
	shape.shape = trunk
	body.add_child(shape)
	add_child(body)
	body.position = at+Vector3.UP*2.5
	var canopy = cylinder(self,at+Vector3.UP*5.4,2.2,4.5,Color("426356"))
	(canopy.mesh as CylinderMesh).top_radius = .5

func _lamp(at: Vector3) -> void:
	cylinder(self,at+Vector3.UP*3.4,.09,6.8,Color("3e525b"))
	box(self,at+Vector3(.8,6.8,0),Vector3(1.8,.12,.5),Color("efe2bb"))
	var light = OmniLight3D.new()
	add_child(light)
	light.position = at+Vector3(.8,6.5,0)
	light.omni_range = 17
	light.light_energy = 1.5
	light.light_color = Color("ffddaa")
	light.shadow_enabled = false
	lamps.append(light)

func _build_waterfront() -> void:
	box(self,Vector3(0,2.4,139),Vector3(350,.8,5),Color("63777a"),true)
	box(self,Vector3(4,1.7,161),Vector3(5,.4,42),Color("8c7861"),true)
	box(self,Vector3(16,1.7,176),Vector3(29,.4,5),Color("8c7861"),true)
	for x in [2,6,16,28]:
		cylinder(self,Vector3(x,.5,176),.25,3.7,Color("594e44"))
	# Sloped access onto the dock instead of a sudden ledge.
	var approach = box(self,Vector3(4,2.13,142),Vector3(5,.25,7),Color("8c7861"),true)
	approach.rotation.x = .13
	make_sign(self,Vector3(4,4,138),"HARBOR / PIER 04",.033,PI)
	for x in range(-155,160,22):
		_tree(Vector3(x,2.8,145))

func _build_bridge() -> void:
	# Flat shared junction until x=184, then a gradual climb over open water.
	var count = 44
	var surface_vertices = PackedVector3Array()
	for i in count:
		var x = 165+i*5.0
		var a = bridge_height(x)
		var b = bridge_height(x+5)
		surface_vertices.append_array(PackedVector3Array([Vector3(x,a,58.5),Vector3(x,a,71.5),Vector3(x+5,b,71.5),Vector3(x,a,58.5),Vector3(x+5,b,71.5),Vector3(x+5,b,58.5)]))
		var deck = box(self,Vector3(x+2.5,(a+b)*.5-.3,65),Vector3(sqrt(25+(b-a)*(b-a))+.03,.6,13),Color("56646a"))
		deck.rotation.z = atan2(b-a,5)
		for side in [-1,1]:
			var rail = box(self,Vector3(x+2.5,(a+b)*.5+.7,65+side*6.5),Vector3(sqrt(25+(b-a)*(b-a))+.03,1.4,.2),Color("8c9e9c"),true)
			rail.rotation.z = atan2(b-a,5)
		if i%6==0 and x>190:
			box(self,Vector3(x,(a-.7)*.5,65),Vector3(1.8,a-.7,8),Color("7e8f91"),true)
	var surface_mesh = ArrayMesh.new()
	var surface_arrays = []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	surface_arrays[Mesh.ARRAY_VERTEX] = surface_vertices
	surface_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface_arrays)
	var surface_body = StaticBody3D.new()
	var surface_shape = CollisionShape3D.new()
	surface_shape.shape = surface_mesh.create_trimesh_shape()
	surface_shape.shape.backface_collision = true
	surface_body.add_child(surface_shape)
	add_child(surface_body)
	box(self,Vector3(425,0,65),Vector3(90,5.2,110),Color("8e9383"),true)
	box(self,Vector3(425,2.69,65),Vector3(90,.08,13),Color("35434b"))
	make_sign(self,Vector3(416,5,55),"EAST BANK / TURN AROUND",.04,PI/2)

func bridge_height(x: float) -> float:
	return 2.6+9.0*clampf(minf((x-185)/65,(375-x)/65),0,1)

func _build_vehicles() -> void:
	for spec in [
		[Vector3(-5,2.9,108),false,false,0],
		[Vector3(-75,2.9,55),false,true,0],
		[Vector3(55,2.9,-5),false,true,1],
		[Vector3(10,.1,168),true,false,0],
		[Vector3(25,.1,190),true,true,0],
		[Vector3(55,.1,205),true,true,1]]:
		var v = Vehicle.new()
		add_child(v)
		v.name = ("Launch" if spec[1] else "Car")+str(vehicles.size())
		v.configure(self,spec[0],spec[1],spec[2],spec[3])
		v.spawn_point = spec[0]
		v.global_position = spec[0]
		if v.police and not v.boat:
			v.rotation.y = PI
			v.home_heading = PI
		if v.boat and not v.police:
			v.rotation.y = PI
			v.home_heading = PI
		v.boat = spec[1]
		v.police = spec[2]
		vehicles.append(v)

func _batch_static_visuals() -> void:
	# Keep all collision bodies, but submit static street/building detail by material.
	# The test district is small; a full island would batch separately per city block.
	var groups = {}
	for node in get_children():
		if not node is MeshInstance3D or node.has_meta("dynamic") or not node.material_override is StandardMaterial3D:
			continue
		var m = node.material_override
		var key = str(m.get_instance_id())+":"+str(Vector2i(floori(node.position.x/48),floori(node.position.z/48)))
		if not groups.has(key):
			var surface = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(m)
			groups[key] = surface
		groups[key].append_from(node.mesh,0,node.transform)
		node.visible = false
	for surface in groups.values():
		var batch = MeshInstance3D.new()
		batch.mesh = surface.commit()
		add_child(batch)

func wave_height(x: float,z: float) -> float:
	var t = clampf((z-155)/105,0,1)
	t = t*t*(3-2*t)
	var shelter = lerpf(.12,.48,t)
	return shelter*(sin(x*.13+z*.09+clock*1.1)+.38*sin(x*-.31+z*.21+clock*1.8))

func set_night(value: bool) -> void:
	if warmup_ready and started and value!=night:
		night_switches.append({"night":value,"at_ms":Time.get_ticks_msec(),"peak_frame_ms":0.0,"frames":0})
		if night_switches.size()>8:
			night_switches.pop_front()
		if night_switches.size()>4:
			night_switches.pop_front()
	night = value
	sun.light_energy = .08 if night else .95
	environment.ambient_light_energy = .16 if night else .35
	var sky = environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color("081522") if night else Color("385d75")
	sky.sky_horizon_color = Color("243e51") if night else Color("c1d2d3")
	for lamp in lamps:
		lamp.visible = night
	for v in vehicles:
		for light in v.headlights:
			light.visible = night

func reset_test() -> void:
	chase = false
	if ops:
		ops.reset_run()
	player.reset_player(Vector3(0,2.9,96))
	for v in vehicles:
		v.reset_vehicle()

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	var root = Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title = Label.new()
	root.add_child(title)
	title.position = Vector2(28,20)
	title.text = "KESTREL BAY  /  WATERFRONT"
	title.add_theme_font_size_override("font_size",21)
	title.modulate = Color("f1d29a")
	var subtitle = Label.new()
	root.add_child(subtitle)
	subtitle.position = Vector2(29,51)
	subtitle.text = "GODOT ENGINE STUDY     •     NOT THE FULL GAME"
	subtitle.add_theme_font_size_override("font_size",12)
	hud = Label.new()
	root.add_child(hud)
	hud.position = Vector2(28,79)
	hud.add_theme_font_size_override("font_size",14)
	hint = Label.new()
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 28
	hint.offset_top = -93
	hint.offset_right = 1050
	hint.offset_bottom = -16
	hint.add_theme_font_size_override("font_size",15)
	speed_label = Label.new()
	root.add_child(speed_label)
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.offset_left = -220
	speed_label.offset_top = -95
	speed_label.offset_right = -20
	speed_label.offset_bottom = -40
	speed_label.add_theme_font_size_override("font_size",32)
	var crosshair = Label.new()
	root.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.text = "+"
	crosshair.offset_left = -5
	crosshair.offset_top = -12
	crosshair.offset_right = 20
	crosshair.offset_bottom = 20
	crosshair.modulate = Color(1,1,1,.65)
	start_panel = PanelContainer.new()
	root.add_child(start_panel)
	start_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	start_panel.offset_left = -275
	start_panel.offset_top = -175
	start_panel.offset_right = 275
	start_panel.offset_bottom = 175
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color("142a36f5")
	panel.border_color = Color("bc9c61")
	panel.set_border_width_all(1)
	panel.content_margin_left = 28
	panel.content_margin_right = 28
	panel.content_margin_top = 25
	panel.content_margin_bottom = 25
	start_panel.add_theme_stylebox_override("panel",panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation",15)
	start_panel.add_child(content)
	var heading = Label.new()
	heading.text = "THE NIGHT LEDGER"
	heading.add_theme_font_size_override("font_size",24)
	heading.modulate = Color("f1d29a")
	content.add_child(heading)
	var body = Label.new()
	body.text = "Accept the job at the square’s board. Recover the ledger\nfrom Suite 201, then make your escape by sea.\n\nWASD move / drive   •   Mouse look   •   E enter / exit\nShift sprint / handbrake   •   Space jump / swim up\n1 / 2 holster / pistol   •   R reload   •   M map\nN day / night   •   P pursuit test   •   Backspace reset\n\nA complete hotel escape job. No full island port yet."
	body.add_theme_font_size_override("font_size",15)
	content.add_child(body)
	start_button = Button.new()
	start_button.text = "ENTER WATERFRONT"
	start_button.custom_minimum_size.y = 43
	start_button.disabled = true
	start_button.pressed.connect(start_test)
	content.add_child(start_button)
	warmup_cover = ColorRect.new()
	root.add_child(warmup_cover)
	warmup_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warmup_cover.color = Color("142a36")
	warmup_label = Label.new()
	warmup_cover.add_child(warmup_label)
	warmup_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warmup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warmup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warmup_label.add_theme_font_size_override("font_size",23)
	warmup_label.modulate = Color("f1d29a")
	warmup_label.text = "Preparing lighting…"
	# The paused start screen doesn't move the world or capture the pointer.
	player.set_physics_process(false)

func start_test() -> void:
	if not warmup_ready or started:
		return
	started = true
	ops.set_physics_process(true)
	start_panel.get_parent().hide()
	hud.hide()
	hint.hide()
	speed_label.hide()
	player.set_physics_process(true)
	for v in vehicles:
		v.set_physics_process(true)
	restore_pointer()

func restore_pointer():
	# HTML pointer lock is granted to a focused canvas in a user gesture.
	# A programmatic scene/menu change can complete after that gesture expires.
	if not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(dt: float) -> void:
	if warmup_active:
		_publish_browser_state(dt)
		return
	if started:
		clock += dt
	water.set_shader_parameter("clock",clock)
	if not is_instance_valid(player):
		return
	player.sprint = player.wants_sprint() and not ops.exhausted if ops else false
	var v = player.vehicle
	hud.text = ("NIGHT" if night else "DAY")+"   /   "+("PURSUIT TEST ACTIVE" if chase else "FREE EXPLORATION")
	hint.text = ("E · Exit vehicle    Shift / Space · Handbrake" if v and not v.boat else "E · Exit onto deck" if v else "E · Enter nearby vehicle    Shift · Sprint    Space · Jump / Surface")+"\nN · Lighting    P · Pursuit    B · Dock    R · Reset    Esc · Release mouse"
	speed_label.text = "%02d MPH" % roundi(v.speed*2.23694) if v else ("OXYGEN %d%%" % roundi(player.breath) if player.swimming else "ON FOOT")
	set_underwater_fog(player.submerged)
	if not night_switches.is_empty():
		var latest = night_switches.back()
		if Time.get_ticks_msec()-latest.at_ms<3000:
			latest.peak_frame_ms = maxf(latest.peak_frame_ms,dt*1000)
			latest.frames += 1
	_publish_browser_state(dt)

func diagnostics_enabled() -> bool:
	return true

func _publish_browser_state(dt: float) -> void:
	stat_clock += dt
	if OS.has_feature("web") and diagnostics_enabled() and stat_clock>.25:
		stat_clock = 0
		JavaScriptBridge.eval("window.kbGodotState="+JSON.stringify(snapshot()))

func snapshot() -> Dictionary:
	var state = {"started":started,"night":night,"chase":chase,"fps":Engine.get_frames_per_second(),"start_rect":[start_panel.position.x,start_panel.position.y,start_panel.size.x,start_panel.size.y],"position":[player.position.x,player.position.y,player.position.z],"swimming":player.swimming,"submerged":player.submerged,"breath":player.breath,"vehicle":player.vehicle.name if player.vehicle else "","vehicles":[]}
	state["warmup"] = {"ready":warmup_ready,"views":warmup_rendered_views,"duration_ms":warmup_duration_ms,"active":warmup_active,"button_enabled":not start_button.disabled}
	state["night_switches"] = night_switches
	state["operation"] = ops.stage if ops else ""
	state["health"] = ops.hp if ops else 100
	state["wanted"] = ops.wanted if ops else 0
	state["armed"] = ops.armed if ops else false
	state["clock"] = clock
	if ops:
		state["ammo"] = ops.ammo
		state["visitor_card"] = ops.visitor_card
		state["notice"] = ops.notice
		state["doors"] = []
		for passage in ops.passages:
			if passage.kind=="door":
				state.doors.append({"open":passage.opened,"locked":passage.locked,"rotation":passage.panel.rotation.y})
		state["map_open"] = ops.map_open
		state["audio_paused"] = ops.audio.paused
		state["puzzle_open"] = ops.puzzle!=null
		state["pipes"] = ops.pipes
		state["lift_y"] = ops.lift.position.y
		state["officers"] = []
		for n in ops.officers:
			state.officers.append({"boarded":n.boarded,"hp":n.hp,"role":n.role,"position":[n.position.x,n.position.y,n.position.z]})
		state["windows_broken"] = ops.passages.filter(func(p): return p.kind=="window" and p.broken).size()
		if ops.puzzle:
			state["puzzle_buttons"] = []
			for b in ops.puzzle_buttons:
				state.puzzle_buttons.append([b.global_position.x,b.global_position.y,b.size.x,b.size.y])
			state["puzzle_check"] = [ops.puzzle_check.global_position.x,ops.puzzle_check.global_position.y,ops.puzzle_check.size.x,ops.puzzle_check.size.y]
	state["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	state["process_ms"] = Performance.get_monitor(Performance.TIME_PROCESS)*1000
	state["physics_ms"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
	for v in vehicles:
		state.vehicles.append({"name":v.name,"boat":v.boat,"police":v.police,"max_speed":v.max_speed,"speed":v.speed,"position":[v.position.x,v.position.y,v.position.z]})
	return state

func _browser_command(args: Array) -> void:
	# Explicit prototype-only inspection hooks; no network/file access.
	if args.is_empty():
		return
	match str(args[0]):
		"start": start_test()
		"reset": reset_test()
		"dock": player.reset_player(Vector3(4,1.95,159))
		"hotel": player.reset_player(Vector3(-45,2.9,44))
		"car": player.reset_player(Vector3(-3,2.9,108))
		"boat": player.reset_player(vehicles[3].position+Vector3(2,-.6,0))
		"night": set_night(not night)
		"chase": chase = not chase
		"job":
			player.reset_player(ops.job_board+Vector3(0,0,2))
		"suite": player.reset_player(Vector3(-54.5,6.9,28))
		"panel": player.reset_player(ops.cabinet+Vector3(0,0,1.6))
		"lift": player.reset_player(Vector3(-34.5,2.85,18))
		"reception": player.reset_player(Vector3(-52,2.8,22.5))
		"window":
			player.reset_player(Vector3(-56.5,6.85,25))
			player.yaw = PI/2
		"pier": player.reset_player(ops.pier)
		"circuit_preview":
			player.reset_player(ops.cabinet+Vector3(0,0,1.6))
			ops.stage = "archive"
			ops.open_puzzle()
		"profile_empty":
			if has_meta("profile_visibility"):
				var saved = get_meta("profile_visibility")
				for node in saved:
					node.visible = saved[node]
				remove_meta("profile_visibility")
			else:
				var saved = {}
				for node in find_children("*","GeometryInstance3D",true,false):
					saved[node] = node.visible
					node.visible = false
				set_meta("profile_visibility",saved)
