extends Node3D

const SEDAN := preload("res://winter/assets/sedan.glb")
const CAB := preload("res://winter/assets/yellow-taxi.glb")
var wheels: Array[Node3D] = []
var is_cab := false
var model: Node3D
var driver: Node3D

func build(cab: bool, traffic: bool) -> void:
	is_cab = cab
	model = (CAB if cab else SEDAN).instantiate()
	add_child(model)
	if cab:
		model.rotation.y = PI
		for corner in ["FL", "FR", "RL", "RR"]:
			wheels.append(model.find_child("wheel_" + corner, true, false))
	else:
		model.rotation.y = PI / 2
		model.scale = Vector3.ONE * (4.72 / 17.52)
		model.position = -(model.basis * Vector3(-5.265, 0, 9.93))
		for axle in ["Front", "Rear"]:
			for side in ["Left", "Right"]:
				wheels.append(model.find_child("Wheel" + axle + side, true, false))
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color("#384957") if traffic else Color("#d8dad9")
	coat.metallic = .22
	coat.roughness = .24
	coat.clearcoat_enabled = true
	coat.clearcoat = 1.0
	coat.clearcoat_roughness = .11
	for panel: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		panel.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		if not cab:
			for surface in panel.mesh.get_surface_count():
				var mat := panel.mesh.surface_get_material(surface) as StandardMaterial3D
				if mat and mat.resource_name.to_lower() in ["geohoodsub00021mtl", "geodoorl2sub11mtl"]:
					panel.set_surface_override_material(surface, coat)

	driver = preload("res://body.tscn").instantiate()
	driver.variant = 3 if cab else 0
	driver.position = Vector3(-.39, -.10, -.29)
	driver.casts_shadows = traffic
	driver.visible = traffic
	add_child(driver)
	if is_inside_tree(): driver.sit()
	else: driver.ready.connect(driver.sit, CONNECT_ONE_SHOT)

func roll(distance: float) -> void:
	var angle := distance / .335
	for wheel in wheels:
		if is_cab: wheel.rotate_object_local(Vector3.RIGHT, angle)
		else: wheel.rotate_object_local(Vector3.UP, angle)
