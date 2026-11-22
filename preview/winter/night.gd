extends Node3D

const GRADE := preload("res://survey/grade.gd")

const ASSET := "res://winter/assets/"
const CAR := preload("res://winter/assets/sedan.glb")
const LENS_SHADER := preload("res://winter/sedan_lens.gdshader")
const SIGNAL_HALF_PERIOD := 0.38
const TIRE_RADIUS := .345
const TIRE_PROBE_HEIGHT := .30
const TIRE_PROBE_TRAVEL := .46
var wheel_pivots: Array[Node3D] = []
var wheel_mounts := PackedVector3Array()
var wheel_lift := PackedFloat32Array()
var tire_probe := PhysicsShapeQueryParameters3D.new()
var last_suspension_pose := Vector3.INF
var last_suspension_steer := INF
var last_pressure_revision := -1
var previous_contacts := PackedVector2Array()
var road_ride_height := 0.0
const DROOP := .12
const BUMP := .105
var last_support_height := INF
var wheel_grounded := [true,true,true,true]
var body_heave := 0.0
var heave_velocity := 0.0
var tire_spray: Array[GPUParticles3D] = []
var body_roll := 0.0
var body_pitch := 0.0
var headlight_beams := Node3D.new()
var headlight_lenses: ShaderMaterial
var brake_lenses: StandardMaterial3D
var signal_lenses: ShaderMaterial
var indicator_direction := 0
var indicator_phase := 0.0
var wheel_roll := 0.0
var chassis: Node3D
var chassis_rest := Transform3D.IDENTITY
@onready var city = get_parent()
@onready var block = get_node("../Block")
var lamp_metal := StandardMaterial3D.new()
var hot_glass := StandardMaterial3D.new()
var street_material: ShaderMaterial
var hint: Label
var daylight := false
var night_environment: Environment
var day_environment: Environment
var night_shadow_range: float
var street_probe: ReflectionProbe
var outdoor_lights: Array[Light3D] = []
const SNOW_DEPTH := preload("res://winter/snow_depth.png")
var depth_samples: Image
var pack := preload("res://winter/snowpack.gd").new()
var sidewalks := preload("res://winter/sidewalk_snow.gd").new()

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
		if batch is MultiMeshInstance3D and not batch.is_in_group(&"street_fixtures"):
			batch.material_override = carved
	# Night sky supplies the cool fill; the warm key is a local lamp.
	day_environment = city.get_node("Environment").environment.duplicate()
	day_environment.background_mode = Environment.BG_SKY
	day_environment.sky = Sky.new()
	var clear_sky := ProceduralSkyMaterial.new()
	clear_sky.sky_top_color = Color("#507db3")
	clear_sky.sky_horizon_color = Color("#aec6df")
	clear_sky.sun_angle_max = 3.5
	clear_sky.ground_horizon_color = Color("#999ba2")
	clear_sky.ground_bottom_color = Color("#525052")
	day_environment.sky.sky_material = clear_sky
	day_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	day_environment.ambient_light_energy = .48
	day_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var env: Environment = day_environment.duplicate()
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	var lighting_dir := "res://winter/web_lighting/" if OS.has_feature("web") else ASSET
	panorama.panorama = load(lighting_dir + "urban_street_04_hdri.exr")
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
	night_environment = env
	city.get_node("Environment").environment = env
	var moon: DirectionalLight3D = city.get_node("Afternoon")
	moon.light_color = Color("#a7bee4")
	moon.light_energy = .17
	moon.rotation_degrees = Vector3(-58,-68,0)
	moon.directional_shadow_max_distance = 85
	if OS.has_feature("web"):
		# Streetlamps still cast local shadows. One nearby moon cascade avoids
		# redrawing the entire street into four shadow maps as the camera moves.
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		moon.directional_shadow_max_distance = 48
	night_shadow_range = moon.directional_shadow_max_distance
	day_environment.ssao_enabled = high_quality
	day_environment.ssao_radius = 1.05
	day_environment.ssao_intensity = 1.7
	day_environment.ssr_enabled = high_quality
	day_environment.ssr_max_steps = 40
	day_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	day_environment.tonemap_white = 4.5
	day_environment.fog_light_color = Color("#b1becb")
	day_environment.fog_density = .00032
	street_material = ShaderMaterial.new()
	var survey := street_material
	survey.shader = preload("res://winter/avenue.gdshader")
	depth_samples = SNOW_DEPTH.get_image()
	survey.set_shader_parameter("snow_depth", SNOW_DEPTH)
	survey.set_shader_parameter("wall_stone",preload("res://winter/frontage/white_sandstone_blocks_02_diffuse.jpg"))
	survey.set_shader_parameter("wall_normal",preload("res://winter/frontage/white_sandstone_blocks_02_nor_gl.jpg"))
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
	dress_sedan()
	# Capture the actual lit shopfronts and skyline in the parked car's paint.
	if not OS.has_feature("web"):
		var probe := ReflectionProbe.new()
		street_probe = probe
		probe.size = Vector3(60,32,68)
		probe.cull_mask = 1
		probe.origin_offset = Vector3(0,-3,0)
		probe.max_distance = 95
		probe.intensity = .88
		probe.box_projection = true
		add_child(probe)
		probe.position = Vector3(85,5,7)
		# Capture the opposite curb from the Reserve entrance. The sedan's probe
		# is centered half a block away and has a different reflection origin.
		var entry_probe := ReflectionProbe.new()
		block.reserve.add_child(entry_probe)
		entry_probe.position = Vector3(block.reserve.DRUM_X,2.2,.8)
		entry_probe.size = Vector3(9.,6.,9.)
		entry_probe.max_distance = 75.
		entry_probe.box_projection = false
	city.walker.position = to_global(Vector3(94.0,.15,23.5))
	city.walker.position.y = walking_height(city.walker.global_position)
	city.camera.position = city.walker.position + Vector3.UP * 1.68
	city.camera.fov = 62
	city.camera.look_at(to_global(Vector3(90.2,1.55,-9.0)))
	city.yaw = city.camera.rotation.y
	city.pitch = city.camera.rotation.x
	snowfall()
	if not OS.has_feature("web"):
		add_controls()

func dress_sedan() -> void:
	var old: Node3D = block.parked.get_child(1)
	old.hide()
	var model := CAR.instantiate() as Node3D
	block.parked.add_child(model)
	# Original mesh uses +X for its nose and is offset from its authoring origin.
	model.rotation.y = PI / 2
	model.scale = Vector3.ONE * (4.72 / 17.52)
	model.position = -(model.basis * Vector3(-5.265, 0, 9.93))
	chassis = model
	chassis_rest = model.transform
	var car: CharacterBody3D = block.parked
	road_ride_height = car.position.y
	var shell := car.get_child(0) as CollisionShape3D
	shell.position = Vector3.ZERO
	shell.shape = preload("res://winter/sedan_hull.tres")
	var tire := CylinderShape3D.new()
	tire.radius = TIRE_RADIUS
	tire.height = .23
	tire_probe.shape = tire
	tire_probe.motion = Vector3.DOWN * TIRE_PROBE_TRAVEL
	tire_probe.collision_mask = sidewalks.CURB_SUPPORT_LAYER
	var powder_mesh := tire_powder_mesh()
	for axle in ["Front", "Rear"]:
		for side in ["Left", "Right"]:
			var pivot := model.find_child("Wheel" + axle + side, true, false) as Node3D
			wheel_pivots.append(pivot)
			var mount := car.to_local(pivot.global_position)
			wheel_mounts.append(mount)
			wheel_lift.append(0.0)
			add_tire_spray(car, mount, powder_mesh)

	headlight_beams.name = "HeadlightBeams"
	headlight_beams.hide()
	block.parked.add_child(headlight_beams)
	for side: float in [-1.0, 1.0]:
		var beam := SpotLight3D.new()
		beam.position = Vector3(side * .76, .68, -2.02)
		beam.rotation_degrees.x = -6.0
		beam.light_color = Color("#e4edff")
		beam.light_energy = 2.6
		beam.spot_angle = 28.0
		beam.spot_range = 38.0
		beam.spot_attenuation = 1.18
		headlight_beams.add_child(beam)

	for panel: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		panel.layers = 2 # Omit the car from its own reflection capture.
		for surface in panel.mesh.get_surface_count():
			var source := panel.mesh.surface_get_material(surface) as StandardMaterial3D
			if not source: continue
			match source.resource_name.to_lower():
				"geohoodsub00021mtl", "geodoorl2sub11mtl":
					var coat := source.duplicate() as StandardMaterial3D
					coat.albedo_texture = null
					coat.albedo_color = Color("#e1e3e1")
					coat.metallic = .20
					coat.roughness = .28
					coat.clearcoat_enabled = true
					coat.clearcoat = .84
					coat.clearcoat_roughness = .18
					panel.set_surface_override_material(surface, coat)
				"ln12mtl":
					brake_lenses = source.duplicate() as StandardMaterial3D
					brake_lenses.emission_enabled = true
					brake_lenses.emission = Color("#ff080d")
					brake_lenses.emission_energy_multiplier = 0.0
					panel.set_surface_override_material(surface, brake_lenses)
				"ln1mtl":
					signal_lenses = sedan_lens_material(source)
					signal_lenses.set_shader_parameter("amber_lens", true)
					panel.set_surface_override_material(surface, signal_lenses)
				"ln7mtl":
					headlight_lenses = sedan_lens_material(source)
					panel.set_surface_override_material(surface, headlight_lenses)
				"tire1mtl":
					var rubber := source.duplicate() as StandardMaterial3D
					rubber.albedo_color = Color("#26272a")
					rubber.emission_enabled = false
					rubber.metallic = 0.0
					rubber.metallic_texture = null
					rubber.roughness = .86
					rubber.roughness_texture = null
					panel.set_surface_override_material(surface, rubber)

	add_sedan_plate()

func tire_powder_mesh() -> QuadMesh:
	var falloff := Gradient.new()
	falloff.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	var puff := GradientTexture2D.new()
	puff.width = 32
	puff.height = 32
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(.5, .5)
	puff.fill_to = Vector2(.98, .5)
	puff.gradient = falloff

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(.79, .86, .94, .68)
	material.albedo_texture = puff
	var mesh := QuadMesh.new()
	mesh.size = Vector2(.19, .16)
	mesh.material = material
	return mesh

func add_tire_spray(car: CharacterBody3D, contact: Vector3, mesh: QuadMesh) -> void:
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(.09, .02, .10)
	motion.direction = Vector3(signf(contact.x) * .5, .72, .54)
	motion.spread = 22.0
	motion.initial_velocity_min = 1.2
	motion.initial_velocity_max = 3.0
	motion.gravity = Vector3(0.0, -6.8, 0.0)
	motion.scale_min = .25
	motion.scale_max = 1.0
	motion.color_ramp = fade_texture

	var spray := GPUParticles3D.new()
	spray.emitting = false
	spray.amount = 24
	spray.lifetime = .46
	spray.local_coords = false
	spray.visibility_aabb = AABB(Vector3(-3, -1, -30), Vector3(6, 4, 60))
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.process_material = motion
	spray.draw_pass_1 = mesh
	spray.position = Vector3(contact.x, .06, contact.z)
	car.add_child(spray)
	tire_spray.append(spray)

func update_tire_spray() -> void:
	var speed: float = block.driver_speed
	var movement := smoothstep(.65, 7.0, absf(speed)) if block.driven else 0.0
	for i in tire_spray.size():
		var spray := tire_spray[i]
		if movement <= 0.0 or not wheel_grounded[i]:
			spray.emitting = false
			continue
		var contact := spray.global_position
		var powder := snow_underfoot(contact, city.on_road(contact))
		var rate := movement * smoothstep(.015, .60, powder)
		spray.amount_ratio = rate
		spray.emitting = rate >= .06
		if spray.emitting:
			spray.position.y = maxf(.06, walking_height(contact) + .02) - block.parked.position.y
			var motion := spray.process_material as ParticleProcessMaterial
			if signf(motion.direction.z) != signf(speed):
				motion.direction = Vector3(motion.direction.x, motion.direction.y, .54 * signf(speed))

func add_sedan_plate() -> void:
	var backing := BoxMesh.new()
	backing.size = Vector3(.33, .16, .012)
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color("#e8eaf0")
	finish.roughness = .65
	finish.emission_enabled = true
	finish.emission = Color("#e8eaf0")
	finish.emission_energy_multiplier = .25
	backing.material = finish

	var plate := MeshInstance3D.new()
	plate.name = "LicensePlate"
	plate.mesh = backing
	chassis.add_child(plate)
	var mount := Transform3D(Basis(Vector3.RIGHT, -.30), Vector3(0.0, .697, 2.286))
	plate.transform = chassis_rest.affine_inverse() * mount

	var lettering := Label3D.new()
	lettering.text = "NYC"
	lettering.font_size = 112
	lettering.pixel_size = .0012
	lettering.outline_size = 0
	lettering.modulate = Color("#152743")
	lettering.position.z = .008
	plate.add_child(lettering)

func sedan_lens_material(source: StandardMaterial3D) -> ShaderMaterial:
	var lens := ShaderMaterial.new()
	lens.shader = LENS_SHADER
	lens.set_shader_parameter("lens_color", source.albedo_color)
	lens.set_shader_parameter("lens_roughness", source.roughness)
	lens.set_shader_parameter("lens_metallic", source.metallic)
	return lens

func update_sedan_lights(dt: float) -> void:
	var driving: bool = city.driving
	headlight_beams.visible = driving
	headlight_lenses.set_shader_parameter("headlights_on", driving)
	brake_lenses.emission_energy_multiplier = 3.0 if driving and city.brake_pressed else 0.0
	var direction: int = city.turn_signal_direction if driving else 0
	var previous_side := indicator_direction if indicator_phase < SIGNAL_HALF_PERIOD else 0
	if direction != indicator_direction or direction == 0:
		indicator_phase = 0.0
	else:
		indicator_phase = fposmod(indicator_phase + dt, SIGNAL_HALF_PERIOD * 2.0)
	indicator_direction = direction
	var flashing_side := direction if indicator_phase < SIGNAL_HALF_PERIOD else 0
	signal_lenses.set_shader_parameter("flashing_side", flashing_side)
	if direction != 0 and flashing_side != previous_side:
		city.drive_audio.play_turn_signal(flashing_side != 0)

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

func lamp(site: Transform3D, hero: bool) -> void:
	var foot := site.origin
	var out := site.basis.z*(2.25 if hero else 2.15)
	rod(foot,foot+Vector3.UP*.32,.24,.19)
	rod(foot+Vector3.UP*.32,foot+Vector3.UP*6.28,.117,.075)
	var elbow := foot+out*.26+Vector3.UP*6.91
	var tip := foot+out+Vector3.UP*7.04
	rod(foot+Vector3.UP*5.84,elbow,.077,.063)
	rod(elbow,tip,.063,.052)
	rod(foot+Vector3.UP*5.24,foot+out*.68+Vector3.UP*7.,.037,.032)
	var shade := MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius=.54
	shell.height=.36
	shade.mesh=shell
	shade.material_override=lamp_metal
	add_child(shade)
	shade.position=tip
	shade.basis=site.basis.scaled_local(Vector3(.53,1,1))
	var lens:=MeshInstance3D.new()
	lens.mesh=shell
	lens.material_override=hot_glass
	shade.add_child(lens)
	lens.scale=Vector3(.83,.35,.78)
	lens.position.y=-.105
	shade.add_to_group(&"streetlight_heads")
	if not block.lit_lamp_sites.has(Vector2(foot.x,foot.z)): return
	var light := SpotLight3D.new()
	add_child(light)
	light.position=tip-Vector3.UP*.24
	light.rotation_degrees.x=-90
	outdoor_lights.append(light)
	light.spot_range=22
	light.spot_angle=63
	light.spot_angle_attenuation=.68
	light.spot_attenuation=1.12
	light.light_color=Color("#ffad64") if hero else Color("#ffcf9b")
	light.light_energy=15 if hero else 8.0
	light.shadow_enabled=hero
	light.light_size=.38

func furnish() -> void:
	for site: Transform3D in block.night_lamps:
		var p:=Vector2(site.origin.x,site.origin.z)
		var hero:=p.is_equal_approx(block.HERO_LAMP)
		lamp(site,hero)
	curb_furniture()
	# Full-height window glass sits inside the original bronze display frames.
	for i in range(-14,15):
		if i> -11 and i not in [4,5,6]:
			display_window(Vector3(-9-i*5.,2.08,-30.58),PI,4.52,i+21)
	for i in range(-6,3):
		if i not in [-5,-2,1]:
			display_window(Vector3(95.98,2.16,i*4.45),-PI/2,3.94,i)
	# A broad wash from inside the closed display reaches the shelves and jambs.
	var display_light:=OmniLight3D.new()
	display_light.position=Vector3(64.75,2.95,14.7)
	display_light.light_color=Color("#f6dcab")
	display_light.light_energy=1.25
	display_light.omni_range=6.1
	add_child(display_light)
	for x in [64.2,66.75]:
		var glow := OmniLight3D.new()
		add_child(glow)
		glow.position=Vector3(x,5.8,0)
		glow.light_color=Color("#ffda99")
		glow.light_energy=2.5
		glow.omni_range=12
	add_child(sidewalks)
	sidewalks.build(street_material)
	add_child(pack)
	# Unsurveyed strips at property boundaries use the same winter pavement.
	var backing := street_material.duplicate() as ShaderMaterial
	GRADE.load_field()
	backing.set_shader_parameter("backing_extent",Vector4(GRADE.origin.x,GRADE.origin.y-GRADE.size+1,GRADE.origin.x+GRADE.size-1,GRADE.origin.y))
	city.get_node("Terrain").material_override=backing

func display_window(at: Vector3, angle: float, width: float, index: int) -> void:
	var pane:=MeshInstance3D.new()
	var mesh:=QuadMesh.new()
	mesh.size=Vector2(width,3.17)
	pane.mesh=mesh
	var material:=ShaderMaterial.new()
	material.shader=preload("res://winter/shop_glass.gdshader")
	material.set_shader_parameter("variation",floorf(index/3.0))
	pane.material_override=material
	add_child(pane)
	pane.position=at
	pane.rotation.y=angle

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
	var ice:=ShaderMaterial.new()
	ice.shader=preload("res://reserve/snow_shelter.gdshader")
	ice.set_shader_parameter("store_inverse",block.reserve.global_transform.affine_inverse())
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
	hint.text="T  Day / night     J  Herald Sq     WASD  Move / drive     ← / →  Signal     Space  Jump     Shift  Sprint / handbrake     V  Release mouse / click to capture     E  Interact / exit     F  Freecam     B  Camera motion     H  Hide"
	get_viewport().size_changed.connect(func(): hint.position.y=get_viewport().get_visible_rect().size.y-39)

func toggle_daylight() -> void:
	daylight = not daylight
	city.get_node("Environment").environment = day_environment if daylight else night_environment
	var sun: DirectionalLight3D = city.get_node("Afternoon")
	sun.rotation_degrees = Vector3(-39,-33,0) if daylight else Vector3(-58,-68,0)
	sun.light_color = Color("#fff2da") if daylight else Color("#a7bee4")
	sun.light_energy = 1.65 if daylight else .17
	sun.light_angular_distance = .5 if daylight and day_environment.ssr_enabled else 0.
	sun.directional_shadow_max_distance = 290. if daylight else night_shadow_range
	for lamp in outdoor_lights:
		lamp.visible = not daylight
	hot_glass.emission_enabled = not daylight
	street_material.set_shader_parameter("night_windows", 0.04 if daylight else 1.0)
	for probe: ReflectionProbe in city.find_children("*","ReflectionProbe",true,false):
		# Changing the capture origin invalidates a cached one-shot probe.
		probe.origin_offset.y += .01 if daylight else -.01

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_T:
		toggle_daylight()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H and hint:
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
		fitting(Vector3(89.29,.003,z),Vector3(.54,.012,.94),lamp_metal)
		var slots:=StandardMaterial3D.new()
		slots.albedo_color=Color("#161b20")
		for j in 9:
			fitting(Vector3(89.29,.011,z-.37+j*.092),Vector3(.43,.005,.035),slots)
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
		lantern.light_energy=2.35
		outdoor_lights.append(lantern)
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
		var z:float=(-28.5 if i<110 else 6.5)+float(i%110)*.20
		var y:float=4.06+.09*cos(z*1.02)
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
		var z:float=(-28.5 if i<52 else 6.5)+float(i%52)*.42
		bulbs.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(66.09,4.+.17*cos(z*1.02),z)))
	var strand:=MultiMeshInstance3D.new()
	strand.multimesh=bulbs
	add_child(strand)

# Sample the same tiled depth field, plowing pattern, and curb banks as the winter material.
func snow_underfoot(world: Vector3, road: bool) -> float:
	if block.reserve.inside(block.reserve.to_local(world)): return 0.
	var local := to_local(world)
	var foot := Vector2(local.x, local.z)
	var surface:=pack.surface_at(foot)
	if physical_block(foot):
		var depth: float = pack.remaining(foot,surface)
		if depth < .0018: return 0. # The snow mesh discards these fragments.
		var floor_y := GRADE.height(world,pack.SUPPORT_Y[int(surface.x)])
		if world.y > floor_y+depth+.24: return 0.
		return smoothstep(.003,.033,depth)
	if GRADE.contains(world):
		var ground: float = city.get_node("HeraldSquare").walking_height(world,0.)
		if world.y > ground+.24: return 0. # A raised prop or threshold.
		for entry in city.get_node("HeraldSquare").vestibules:
			var inside: Vector3 = entry.frame.to_local(world)
			if absf(inside.x)<float(entry.width)*.5 and inside.z < float(entry.mouth) and inside.z > float(entry.mouth)-float(entry.depth):
				return 0.
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

func physical_block(p: Vector2) -> bool:
	return Rect2(pack.ORIGIN,Vector2(pack.FIELD.get_size())/4.).has_point(p)

func walking_height(world: Vector3) -> float:
	if block.reserve.inside(block.reserve.to_local(world)): return .155
	var local:=to_local(world)
	var p:=Vector2(local.x,local.z)
	var surface:=pack.surface_at(p)
	var legacy: float = pack.SUPPORT_Y[int(surface.x)] if surface.x>=0 else (.0 if city.on_road(world) else .15)
	var floor_y: float = city.get_node("HeraldSquare").walking_height(world,legacy)
	return floor_y+pack.remaining(p,surface)

func plant_foot(world: Vector3, heading: Vector2, left: bool, effort: float) -> void:
	if block.reserve.inside(block.reserve.to_local(world)): return
	var foot:=to_local(world)
	var local_direction:=global_basis.inverse()*Vector3(heading.x,0,heading.y)
	pack.stamp(Vector2(foot.x,foot.z),Vector2(local_direction.x,local_direction.z).normalized(),left,effort)

func sample_wheel_support(car: CharacterBody3D) -> void:
	var space := get_world_3d().direct_space_state
	var upright_tire := Basis(Vector3.FORWARD, PI / 2.0)
	var base_y: float = block.global_position.y + road_ride_height
	var contacts := PackedVector2Array()
	for mount in wheel_mounts:
		var local := to_local(car.to_global(mount))
		contacts.append(Vector2(local.x,local.z))
	var dirty := {}
	var continuous := previous_contacts.size() == contacts.size() and contacts[0].distance_to(previous_contacts[0]) < 4.
	for i in contacts.size():
		if not wheel_grounded[i]: continue
		var start := previous_contacts[i] if continuous else contacts[i]
		var rolling := start.direction_to(contacts[i])
		if rolling.is_zero_approx():
			rolling = contacts[2].direction_to(contacts[0])
		pack.press_strip(start-rolling*.085,contacts[i]+rolling*.085,.119,0.,dirty)
	# A swept bumper clears deep snow between the tracks. On spawn or teleport
	# sweep the full footprint once, so existing banks cannot fill the cabin.
	var axle := 2 if block.driver_speed < 0 else 0
	var other_axle := 2-axle
	var nose := (contacts[axle]-contacts[other_axle]).normalized()*.78
	var underside_y := car.position.y + .135 - GRADE.height(car.global_position)
	for band in 9:
		var t := .5 + (band-4.)*.13
		var bumper := contacts[axle].lerp(contacts[axle+1],t) + nose
		var start := contacts[other_axle].lerp(contacts[other_axle+1],t) - nose
		if continuous:
			var previous_nose := (previous_contacts[axle]-previous_contacts[other_axle]).normalized()*.78
			start = previous_contacts[axle].lerp(previous_contacts[axle+1],t) + previous_nose
		pack.press_strip(start,bumper,.119,underside_y,dirty)
	pack.flush_pressure(dirty)
	previous_contacts = contacts
	block.rear_snow_cover = 0.0
	for i in wheel_mounts.size():
		var mount := wheel_mounts[i]
		var start := car.to_global(mount)
		var terrain := GRADE.physical_height(space,start)
		start.y = base_y + terrain + mount.y + TIRE_PROBE_HEIGHT
		var steering: float = -block.steer if i < 2 else 0.0
		tire_probe.transform = Transform3D(car.global_basis * Basis(Vector3.UP, steering) * upright_tire, start)
		# Sweep the tire profile so a curb corner can support it before the hub crosses.
		var contact := space.cast_motion(tire_probe)
		var hard_lift := maxf(0.0, TIRE_PROBE_HEIGHT - TIRE_PROBE_TRAVEL * contact[0])
		var surface := pack.surface_at(contacts[i])
		var packed_lift := -INF
		if surface.x >= 0 and surface.y > .001:
			var remaining := pack.remaining(contacts[i],surface)
			packed_lift = (terrain if GRADE.contains(start) else pack.SUPPORT_Y[int(surface.x)]) + remaining - road_ride_height
			if i >= 2: block.rear_snow_cover += .5 * smoothstep(.002,.045,remaining)
		wheel_lift[i] = maxf(hard_lift + terrain, packed_lift)

func update_sedan_suspension(dt: float) -> void:
	var car: CharacterBody3D = block.parked
	var pose := Vector3(car.position.x, car.rotation.y, car.position.z)
	if not last_suspension_pose.is_finite() or Vector2(pose.x-last_suspension_pose.x,pose.z-last_suspension_pose.z).length() > 4.:
		last_support_height = INF
		heave_velocity = 0.
		body_heave = car.position.y-road_ride_height
	if not pose.is_equal_approx(last_suspension_pose) or not is_equal_approx(block.steer, last_suspension_steer) or pack.pressure_revision != last_pressure_revision:
		sample_wheel_support(car)
		last_suspension_pose = pose
		last_suspension_steer = block.steer
		last_pressure_revision = pack.pressure_revision
	var front := (wheel_lift[0] + wheel_lift[1]) * .5
	var rear := (wheel_lift[2] + wheel_lift[3]) * .5
	var left := (wheel_lift[0] + wheel_lift[2]) * .5
	var right := (wheel_lift[1] + wheel_lift[3]) * .5

	# Model support as a spring that can push upward. Once unloaded the mass
	# retains its vertical launch speed and gravity takes over at the crest.
	var target_heave := (front + rear) * .5
	var support_speed := (target_heave-last_support_height)/dt if is_finite(last_support_height) else 0.
	last_support_height = target_heave
	var compression := target_heave-body_heave
	var acceleration := -9.81
	if compression >= -DROOP:
		acceleration = clampf(155.*compression + 20.*(support_speed-heave_velocity),-9.81,32.)
	var travel := heave_velocity*dt + .5*acceleration*dt*dt
	heave_velocity += acceleration*dt
	body_heave += travel
	if body_heave < target_heave-BUMP:
		body_heave = target_heave-BUMP
		heave_velocity = maxf(0.,heave_velocity)
	var lift := road_ride_height + body_heave - car.position.y
	if absf(lift) > .0001:
		var hit := car.move_and_collide(Vector3.UP * lift)
		if hit:
			body_heave = car.position.y-road_ride_height
			heave_velocity = 0.
	var terrain_roll := atan2(right - left, wheel_mounts[1].x - wheel_mounts[0].x)
	var terrain_pitch := atan2(front - rear, wheel_mounts[2].z - wheel_mounts[0].z)
	var corner_roll := clampf(-block.side_accel * .006, -.05, .05) if block.driven else 0.0
	var brake_pitch := clampf(-block.long_accel * .0035, -.038, .038) if block.driven else 0.0
	var weight := 1.0 - exp(-10.0 * dt)
	if not block.tires_airborne:
		body_roll = lerpf(body_roll, terrain_roll + corner_roll, weight)
		body_pitch = lerpf(body_pitch, terrain_pitch + brake_pitch, weight)
	var tilt := Basis(Vector3.BACK, body_roll) * Basis(Vector3.RIGHT, body_pitch)
	var body_center := Vector3.UP * .6
	chassis.transform = Transform3D(tilt, body_center - tilt * body_center) * chassis_rest

	if block.driven:
		wheel_roll = fmod(wheel_roll + block.driver_speed * dt / TIRE_RADIUS, TAU)
	for i in wheel_pivots.size():
		var pivot := wheel_pivots[i]
		var angle: float = -block.steer if i < 2 else 0.0
		pivot.basis = Basis(Vector3.BACK, angle) * Basis(Vector3.UP, wheel_roll)
		var mount := car.to_global(body_center + tilt*(wheel_mounts[i]-body_center))
		var ground_offset := wheel_lift[i]+road_ride_height+wheel_mounts[i].y-mount.y
		wheel_grounded[i] = ground_offset >= -DROOP
		pivot.global_position = mount + Vector3.UP * clampf(ground_offset,-DROOP,BUMP)
	block.tires_airborne = not wheel_grounded.has(true)

func _physics_process(dt: float) -> void:
	if not chassis: return
	if street_probe and street_probe.global_position.distance_squared_to(block.parked.global_position)>24.*24.:
		street_probe.global_position = block.parked.global_position+Vector3.UP*5.
	update_sedan_lights(dt)
	update_sedan_suspension(dt)
	update_tire_spray()
