extends Node3D

const ASSET := "res://winter/assets/"
const CAR := preload("res://winter/assets/sedan.glb")
const EXTERIOR := preload("res://winter/assets/urban_street_04_hdri.exr")
const DISPLAY := preload("res://winter/assets/christmas_photo_studio_01_hdri.exr")
@onready var city = get_parent()
@onready var block = get_node("../Block")
var lamp_metal := StandardMaterial3D.new()
var hot_glass := StandardMaterial3D.new()
var hint: Label
const SNOW_DEPTH := preload("res://winter/snow_depth.png")
var depth_samples: Image
var banks: Array[Dictionary] = []

func _ready() -> void:
	city.ready.connect(dress_street)

func dress_street() -> void:
	transform = block.transform
	Engine.max_fps = 60
	if not OS.has_feature("web"):
		city._resize()
		get_window().size_changed.connect(city._resize)
	block.parked.position.z = 8.0
	var carved := ShaderMaterial.new()
	carved.shader = preload("res://winter/stonework.gdshader")
	for batch in block.get_children():
		if batch is MultiMeshInstance3D: batch.material_override = carved
	# Night sky supplies the cool fill; the warm key is a local lamp.
	var env: Environment = city.get_node("Environment").environment.duplicate()
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = EXTERIOR
	sky.sky_material = panorama
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#273347")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#99a8c2")
	env.ambient_light_energy = .25
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.background_energy_multiplier = .34
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = not OS.has_feature("web")
	env.glow_intensity = .49
	env.glow_hdr_threshold = 1.6
	var high_quality := RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_enabled = high_quality
	env.ssao_radius = .9
	env.ssao_intensity = 1.3
	env.ssr_enabled = high_quality
	env.ssr_max_steps = 32
	env.fog_sky_affect = 0.0
	env.fog_light_color = Color("#28364f")
	env.fog_density = .004
	city.get_node("Environment").environment = env
	var moon: DirectionalLight3D = city.get_node("Afternoon")
	moon.light_color = Color("#a7bee4")
	moon.light_energy = .17
	moon.rotation_degrees = Vector3(-58,-68,0)
	moon.directional_shadow_max_distance = 85
	var survey := ShaderMaterial.new()
	survey.shader = preload("res://winter/avenue.gdshader")
	depth_samples = SNOW_DEPTH.get_image()
	survey.set_shader_parameter("snow_depth", SNOW_DEPTH)
	survey.set_shader_parameter("asphalt", preload("res://winter/assets/asphalt_snow_Diffuse.jpg"))
	survey.set_shader_parameter("asphalt_normal", preload("res://winter/assets/asphalt_snow_nor_gl.jpg"))
	survey.set_shader_parameter("asphalt_rough", preload("res://winter/assets/asphalt_snow_Rough.jpg"))
	survey.set_shader_parameter("snow", preload("res://winter/assets/snow_02_Diffuse.jpg"))
	survey.set_shader_parameter("snow_normal", preload("res://winter/assets/snow_02_nor_gl.jpg"))
	for tile: MeshInstance3D in city.get_node("Survey").find_children("*","MeshInstance3D",true,false):
		tile.material_override = survey
		# Native detail is concentrated in the playable neighborhood.
		tile.visibility_range_end = 780
	lamp_metal.albedo_color = Color("#53595a")
	lamp_metal.metallic = .75
	lamp_metal.roughness = .43
	hot_glass.emission_enabled = true
	hot_glass.emission = Color("#ffbd75")
	hot_glass.emission_energy_multiplier = 5
	hot_glass.albedo_color = Color("#ffd39a")
	furnish()
	var old: Node3D = block.parked.get_child(1)
	old.hide()
	var model := CAR.instantiate() as Node3D
	block.parked.add_child(model)
	# Original mesh uses +X for its nose and is offset from its authoring origin.
	model.rotation.y = PI/2
	model.scale = Vector3.ONE * (4.72/17.52)
	model.position = -(model.basis * Vector3(-5.265,0,9.93))
	for panel: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in panel.mesh.get_surface_count():
			var source := panel.mesh.surface_get_material(surface) as StandardMaterial3D
			if not source: continue
			var paint := source.resource_name.to_lower()
			if "geohoodsub00021" in paint or "geodoorl2sub11" in paint:
				var coat := source.duplicate() as StandardMaterial3D
				coat.albedo_texture = null
				coat.albedo_color = Color("#566a70")
				coat.metallic = .72
				coat.roughness = .245
				coat.clearcoat_enabled = true
				coat.clearcoat = .84
				panel.set_surface_override_material(surface,coat)
	# Capture the actual lit shopfronts and skyline in the parked car's paint.
	if not OS.has_feature("web"):
		var probe := ReflectionProbe.new()
		probe.size = Vector3(48,18,62)
		probe.origin_offset = Vector3(0,-3,0)
		probe.max_distance = 95
		probe.intensity = .88
		probe.box_projection = true
		add_child(probe)
		probe.position = Vector3(85,5,7)
	city.walker.position = to_global(Vector3(94.0,.15,23.5))
	city.camera.position = city.walker.position + Vector3.UP * 1.68
	city.camera.fov = 62
	city.camera.look_at(to_global(Vector3(90.2,1.55,-9.0)))
	city.yaw = city.camera.rotation.y
	city.pitch = city.camera.rotation.x
	snowfall()
	if not OS.has_feature("web"):
		add_controls()

func rod(a: Vector3, b: Vector3, bottom: float, top: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	mesh.rings = 1
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = lamp_metal
	add_child(n)
	n.position = (a+b)*.5
	n.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func lamp(x: float,z: float,arm: float, hero: bool) -> void:
	var foot := Vector3(x,.13,z)
	rod(foot,foot+Vector3.UP*.32,.24,.19)
	rod(foot+Vector3.UP*.32,foot+Vector3.UP*6.28,.117,.075)
	var elbow := foot+Vector3(arm*.26,6.91,0)
	var tip := foot+Vector3(arm,7.04,0)
	rod(foot+Vector3.UP*5.84,elbow,.077,.063)
	rod(elbow,tip,.063,.052)
	rod(foot+Vector3.UP*5.24,foot+Vector3(arm*.68,7.,0),.037,.032)
	var shade := MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius=.54
	shell.height=.36
	shade.mesh=shell
	shade.material_override=lamp_metal
	add_child(shade)
	shade.position=tip
	shade.scale.z=.53
	var lens:=MeshInstance3D.new()
	lens.mesh=shell
	lens.material_override=hot_glass
	shade.add_child(lens)
	lens.scale=Vector3(.83,.35,.78)
	lens.position.y=-.105
	var light := SpotLight3D.new()
	add_child(light)
	light.position=tip-Vector3.UP*.24
	light.rotation_degrees.x=-90
	light.spot_range=22
	light.spot_angle=63
	light.spot_angle_attenuation=.68
	light.spot_attenuation=1.12
	light.light_color=Color("#ffad64") if hero else Color("#ffcf9b")
	light.light_energy=15 if hero else 8.0
	light.shadow_enabled=hero
	light.light_size=.38

func furnish() -> void:
	lamp(91.05,6.35,-2.25,true)
	for z in [-94.,-64.,-30.,35.]:
		lamp(91.05,z,-2.15,false)
	for x in [-70.,-36.,-4.,30.,64.]:
		lamp(x,-55.9,1.65,false)
	curb_furniture()
	# Full-height window glass sits inside the original bronze display frames.
	for i in range(-9,10):
		if absi(i)>2:
			display_window(Vector3(65.80,2.1,-i*3.04), PI/2,2.8,i)
	for i in range(-14,15):
		if i not in [4,5,6]:
			display_window(Vector3(-9-i*5.,2.08,-30.58),PI,4.52,i+21)
	for x in [64.2,65.5]:
		var glow := OmniLight3D.new()
		add_child(glow)
		glow.position=Vector3(x,5.8,0)
		glow.light_color=Color("#ffda99")
		glow.light_energy=3
		glow.omni_range=12
	for side in [71.6,90.45]:
		bank(Vector2(side,-125),Vector2(side,-62),.73)
		bank(Vector2(side,-32),Vector2(side,29),.63)
	for z in [-55.1,-36.5]:
		bank(Vector2(-96,z),Vector2(65,z),.73)

func display_window(at: Vector3, angle: float, width: float, index: int) -> void:
	var pane:=MeshInstance3D.new()
	var mesh:=QuadMesh.new()
	mesh.size=Vector2(width,3.17)
	pane.mesh=mesh
	var material:=ShaderMaterial.new()
	material.shader=preload("res://winter/shop_glass.gdshader")
	material.set_shader_parameter("interior",DISPLAY)
	material.set_shader_parameter("variation",floorf(index/3.0))
	pane.material_override=material
	add_child(pane)
	pane.position=at
	pane.rotation.y=angle

func bank(a: Vector2,b: Vector2,width: float) -> void:
	banks.append({"a":a,"b":b,"width":width})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise:=FastNoiseLite.new()
	noise.seed=417
	noise.frequency=.75
	var axis:=(b-a).normalized()
	var across:=Vector2(-axis.y,axis.x)
	var rows:Array[PackedVector3Array]=[]
	var count:=ceili(a.distance_to(b)/.43)
	for i in count+1:
		var center:=a.lerp(b,float(i)/count)
		var n:=noise.get_noise_2dv(center)
		var taper:=clampf(minf(i,count-i)*.25,0,1)
		var row:=PackedVector3Array()
		for j in 7:
			var s:=(j-3.)/3.
			var pos:=center+across*(s*width*(1.+.56*n)+.14*n)
			var crest:=pow(maxf(0,1.-s*s),1.35)*(.30+.20*n+.09*noise.get_noise_2dv(pos*3.1))
			row.append(Vector3(pos.x,.071+taper*crest,pos.y))
		rows.append(row)
	for i in count:
		for j in 6:
			for v:Vector3 in [rows[i][j],rows[i+1][j],rows[i][j+1],rows[i][j+1],rows[i+1][j],rows[i+1][j+1]]:
				st.set_uv(Vector2(v.x,v.z)*.72)
				st.add_vertex(v)
	st.generate_normals()
	st.generate_tangents()
	var berm:=MeshInstance3D.new()
	berm.mesh=st.commit()
	var powder:=StandardMaterial3D.new()
	powder.cull_mode=BaseMaterial3D.CULL_DISABLED
	powder.albedo_texture=preload("res://winter/assets/snow_02_Diffuse.jpg")
	powder.normal_enabled=true
	powder.normal_texture=preload("res://winter/assets/snow_02_nor_gl.jpg")
	powder.roughness=.86
	berm.material_override=powder
	add_child(berm)

func snowfall() -> void:
	var flakes:=GPUParticles3D.new()
	city.camera.add_child(flakes)
	flakes.amount = 220 if OS.has_feature("web") else 900
	flakes.lifetime=5.5
	flakes.preprocess = 0 if OS.has_feature("web") else 3
	flakes.local_coords=false
	flakes.visibility_aabb=AABB(Vector3(-27,-16,-35),Vector3(54,37,60))
	var motion:=ParticleProcessMaterial.new()
	motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents=Vector3(15,6,15)
	motion.direction=Vector3(.19,-1,.11)
	motion.spread=13
	motion.initial_velocity_min=1
	motion.initial_velocity_max=2
	motion.gravity=Vector3(.02,-.09,.015)
	motion.scale_min=.38
	motion.scale_max=1.15
	flakes.process_material=motion
	var mesh:=QuadMesh.new()
	mesh.size=Vector2(.021,.029)
	var ice:=StandardMaterial3D.new()
	ice.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	ice.albedo_color=Color("#d1d8e1")
	mesh.material=ice
	flakes.draw_pass_1=mesh
	flakes.position=Vector3(0,4,-6)
	flakes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func add_controls() -> void:
	var hud:=CanvasLayer.new()
	add_child(hud)
	hint=Label.new()
	hud.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position=Vector2(18,get_viewport().get_visible_rect().size.y-39)
	hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_constant_override("outline_size",4)
	hint.text="WASD  Move      Shift  Sprint      V  Unlock mouse  /  Click to capture      E  Drive / exit      F  Freecam      B  Camera motion      H  Hide"
	get_viewport().size_changed.connect(func(): hint.position.y=get_viewport().get_visible_rect().size.y-39)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H and hint:
		hint.visible=not hint.visible
		city.hud_visible=hint.visible

func fitting(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var item:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	item.mesh=mesh
	item.material_override=material
	add_child(item)
	item.position=at
	return item

func curb_furniture() -> void:
	# Machined steel cover, slotted gutter drains, and stone joints near the parked sedan.
	for z in [-24.,3.,28.]:
		fitting(Vector3(89.8,.063,z),Vector3(.54,.04,.94),lamp_metal)
		var slots:=StandardMaterial3D.new()
		slots.albedo_color=Color("#161b20")
		for j in 9:
			fitting(Vector3(89.8,.09,z-.37+j*.092),Vector3(.43,.012,.035),slots)
	for side in [-1,1]:
		var z:float=side*5.25
		var bracket:=Vector3(66.45,3.27,z)
		rod(bracket,bracket+Vector3(.43,0,0),.06,.05)
		fitting(bracket+Vector3(.48,.12,0),Vector3(.23,.49,.30),hot_glass)
		for yy in [-.14,.38]:
			fitting(bracket+Vector3(.48,yy,0),Vector3(.35,.07,.39),lamp_metal)
		var lantern:=OmniLight3D.new()
		add_child(lantern)
		lantern.position=bracket+Vector3(.68,.17,0)
		lantern.light_color=Color("#ffcb8b")
		lantern.omni_range=7.5
		lantern.light_energy=4.2
	# Small evergreen boughs in the marquee, each tipped with warm bulbs.
	var branch:=PrismMesh.new()
	branch.size=Vector3(.34,.17,.31)
	var green:=StandardMaterial3D.new()
	green.albedo_color=Color("#19392e")
	green.roughness=.89
	branch.material=green
	var needles:=MultiMesh.new()
	needles.transform_format=MultiMesh.TRANSFORM_3D
	needles.mesh=branch
	needles.instance_count=220
	for i in needles.instance_count:
		var z:float=-27.+i*.25
		var y:float=4.07+.17*cos(z*1.02)
		needles.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(.35*sin(i*5.),i*.86,.4*cos(i))),Vector3(65.95,y,z)))
	var garland:=MultiMeshInstance3D.new()
	garland.multimesh=needles
	add_child(garland)
	var bulbs:=MultiMesh.new()
	bulbs.transform_format=MultiMesh.TRANSFORM_3D
	var bulb:=SphereMesh.new()
	bulb.radius=.038
	bulb.height=.084
	bulb.radial_segments=8
	bulb.rings=3
	bulb.material=hot_glass
	bulbs.mesh=bulb
	bulbs.instance_count=104
	for i in bulbs.instance_count:
		var z:float=-27.+i*.52
		bulbs.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(66.09,4.+.17*cos(z*1.02),z)))
	var strand:=MultiMeshInstance3D.new()
	strand.multimesh=bulbs
	add_child(strand)

# Sample the same tiled depth field, plowing pattern, and curb banks as the winter material.
func snow_underfoot(world: Vector3, road: bool) -> float:
	var local := to_local(world)
	var foot := Vector2(local.x, local.z)
	for bank_data in banks:
		var closest := Geometry2D.get_closest_point_to_segment(foot, bank_data.a, bank_data.b)
		if foot.distance_squared_to(closest) < bank_data.width * bank_data.width:
			return 1.0
	var delta := Vector2(world.x + 208.099, world.z - 573.891)
	var p := Vector2(delta.dot(Vector2(.873,.488)), delta.dot(Vector2(-.488,.873)))
	var size := depth_samples.get_width()
	var texel := p * (size / 64.0) - Vector2(0.5, 0.5)
	var cell := texel.floor()
	var f := texel - cell
	var x := posmod(int(cell.x), size)
	var y := posmod(int(cell.y), size)
	var xn := (x + 1) % size
	var yn := (y + 1) % size
	var top := lerpf(depth_samples.get_pixel(x,y).r, depth_samples.get_pixel(xn,y).r, f.x)
	var bottom := lerpf(depth_samples.get_pixel(x,yn).r, depth_samples.get_pixel(xn,yn).r, f.x)
	var drift := lerpf(top, bottom, f.y)
	if not road:
		return smoothstep(.17, .47, drift)
	var lateral := p.x if absf(p.x-81.0)<9.0 else p.y+45.8
	var wheel := absf(fposmod(lateral+.12*sin(p.y*.07+p.x*.09),3.85)-1.925)
	var tracks := 1.0-smoothstep(.14,.53,absf(wheel-.78))
	return smoothstep(.57,.83,drift-tracks*.27)
