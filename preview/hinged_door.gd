extends StaticBody3D

# The handle center and the two faces of its pull are in panel coordinates.
var handle := Vector3(1.19, 1.24, .135)
var angle := 0.
var closed_basis: Basis
signal moved

func _ready() -> void:
	closed_basis = basis
	add_to_group("manual_swing_doors")

func set_angle(value: float) -> void:
	angle = clampf(value, -1.63, 1.63)
	basis = closed_basis * Basis(Vector3.UP, angle)
	force_update_transform()
