extends Node3D

# Each arm has a shoulder, a bent elbow and a wrist pinned to the hardware.
# The glove frame's X axis runs along the bar, across the four knuckles.
var arms: Array[Node3D] = []
var round_mesh := SphereMesh.new()
var sleeve := StandardMaterial3D.new()
var glove := StandardMaterial3D.new()
var cuff := StandardMaterial3D.new()

func _ready() -> void:
	round_mesh.radial_segments = 12
	round_mesh.rings = 6
	sleeve.albedo_color = Color("#985637")
	glove.albedo_color = Color("#594637")
	cuff.albedo_color = Color("#393532")
	for index in 2:
		var arm := Node3D.new()
		add_child(arm)
		arms.append(arm)
		for fabric in [sleeve, sleeve, cuff]:
			oval(arm, Vector3.ZERO, Vector3.ONE, fabric)
		var hand := Node3D.new()
		arm.add_child(hand)
		oval(hand, Vector3(0,.02,.038), Vector3(.095,.05,.105), glove)
		for finger in 4:
			var x := (finger-1.5)*.022
			oval(hand, Vector3(x,.023,-.006),Vector3(.023,.030,.07),glove)
			oval(hand, Vector3(x,.002,-.031),Vector3(.022,.050,.026),glove)
		var thumb := oval(hand, Vector3(.046 if index else -.046,-.001,.02),Vector3(.028,.040,.065),glove)
		thumb.rotation.z = .48 if index else -.48
	hide()

func oval(parent: Node3D, at: Vector3, size: Vector3, fabric: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = round_mesh
	part.material_override = fabric
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	part.position = at
	part.scale = size
	return part

func segment(part: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	var axis := b-a
	part.global_transform = Transform3D(Basis(Quaternion(Vector3.UP,axis.normalized())).scaled_local(
		Vector3(width,axis.length()+width*.32,width)),(a+b)*.5)

func pose(feet: Vector3, yaw: float, bar: Transform3D, amount: float, two_hands: bool, carrying: bool) -> void:
	visible = amount > .001
	if not visible: return
	var facing := Basis(Vector3.UP,yaw)
	for i in 2:
		var arm := arms[i]
		arm.visible = (i == 0 if carrying else (two_hands or i == 1))
		if not arm.visible: continue
		var side := -1. if i == 0 else 1.
		var shoulder := feet + facing * Vector3(.19*side,1.44,.025)
		var rest := shoulder + facing * Vector3(.045*side,-.55,-.13)
		var axis := bar.basis.x
		var spread := .135*side*signf(axis.dot(facing.x)) if two_hands and not carrying else 0.
		var wrist := rest.lerp(bar.origin + axis*spread, smoothstep(0.,1.,amount))
		var line := wrist-shoulder
		var bend := (facing.x*side*.45 + Vector3.DOWN).slide(line.normalized()).normalized()
		var elbow := (shoulder+wrist)*.5 + bend*sqrt(maxf(.002,.39*.39-line.length_squared()*.25))
		segment(arm.get_child(0),shoulder,elbow,.124)
		segment(arm.get_child(1),elbow,wrist,.105)
		segment(arm.get_child(2),elbow.lerp(wrist,.80),elbow.lerp(wrist,.96),.096)
		var hand: Node3D = arm.get_child(3)
		hand.global_transform = Transform3D(bar.basis,wrist)
		var curl := smoothstep(.5, .98, amount)
		for finger in 4:
			var tip: Node3D = hand.get_child(2+finger*2)
			tip.rotation.x = (1.-curl)*1.15
			tip.position.z = lerpf(-.06,-.031,curl)
			tip.position.y = lerpf(.018,.002,curl)
