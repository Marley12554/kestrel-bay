extends "res://frontage_geometry.gd"

# A fixed pair of curved screens encloses a four-wing rotor. Local +Z faces
# the sidewalk. The drum sits behind the rectangular street-facing jambs.
const RADIUS := 1.19
const HALF_ARC := PI / 4.0
const SILL := .12
const HEAD := 2.69
var rotor := Node3D.new()
var speed := 0.0

func _ready() -> void:
	# Both doors reuse the entrance's metal and glazing resources.
	meshes={"box":cube}
	var rail: Material=finishes["rail"]
	var mat:=material("mat","#333332",.93)
	var disk:=CylinderMesh.new()
	disk.radial_segments=64
	disk.rings=0
	disk.top_radius=RADIUS+.03
	disk.bottom_radius=disk.top_radius
	disk.height=.018
	var threshold:=MeshInstance3D.new()
	threshold.mesh=disk
	threshold.material_override=mat
	threshold.position.y=SILL-.01
	add_child(threshold)
	for side in [-1,1]:
		fixed_screen(side)
	# Separate meshes give Godot a sorting origin per glass surface.
	# Keep the center of the mechanism grounded and the floor flush.
	var hub:=CylinderMesh.new()
	hub.top_radius=.055
	hub.bottom_radius=.055
	hub.height=HEAD-SILL
	var spindle:=MeshInstance3D.new()
	spindle.mesh=hub
	spindle.material_override=rail
	spindle.position.y=(HEAD+SILL)*.5
	rotor.add_child(spindle)
	rotor.rotation.y=.42
	add_child(rotor)
	var outer:=RADIUS-.048
	var inner:=.052
	var width:=outer-inner
	var mid_x:=(outer+inner)*.5
	for index in 4:
		var wing:=Node3D.new()
		wing.rotation.y=index*PI/2
		rotor.add_child(wing)
		var glass:=QuadMesh.new()
		glass.size=Vector2(width-.045,HEAD-SILL-.20)
		add_glass(wing,glass,Vector3(mid_x,(HEAD+SILL)*.5+.045,0))
		# Broad kick plate, slim glazing stiles and a projecting push bar.
		frame=wing.transform
		piece("rail",Vector3(mid_x,SILL+.092,0),Vector3(width,.164,.041))
		piece("rail",Vector3(mid_x,HEAD-.032,0),Vector3(width,.06,.041))
		piece("rail",Vector3(outer-.014,(SILL+HEAD)*.5,0),Vector3(.028,HEAD-SILL,.041))
		for pos_x in [inner+.18,outer-.17]:
			piece("rail",Vector3(pos_x,1.13,.048),Vector3(.033,.041,.093))
		piece("rail",Vector3(mid_x,1.13,.10),Vector3(width-.27,.045,.035))
	# Only the hardware collected above belongs to the rotor.
	assemble(rotor)

func add_glass(parent: Node3D,mesh: Mesh,at: Vector3) -> void:
	var pane_view:=MeshInstance3D.new()
	pane_view.mesh=mesh
	pane_view.material_override=finishes["door_glass"]
	pane_view.position=at
	pane_view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pane_view)

func fixed_screen(side: int) -> void:
	# Build continuous cylindrical surfaces with radial normals, including the
	# sill and head bands. The open quarter-circles face the sidewalk and lobby.
	for band in [[SILL+.07,HEAD-.07,true],[SILL,SILL+.07,false],[HEAD-.07,HEAD,false]]:
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in 25:
			var a:=side*PI/2-HALF_ARC+2.*HALF_ARC*step/24.
			var outward:=Vector3(sin(a),0,cos(a))
			for y: float in [band[0],band[1]]:
				surface.set_normal(outward)
				surface.add_vertex(outward*RADIUS+Vector3.UP*y)
			if step<24:
				var k:=step*2
				for idx in [k,k+1,k+2,k+2,k+1,k+3]:
					surface.add_index(idx)
		var mesh:=surface.commit()
		if band[2]:
			add_glass(self,mesh,Vector3.ZERO)
		else:
			var trim:=MeshInstance3D.new()
			trim.mesh=mesh
			trim.material_override=finishes["rail"]
			add_child(trim)
	for end in [-1,1]:
		var a: float=side*PI/2+end*HALF_ARC
		var jamb:=MeshInstance3D.new()
		var post:=BoxMesh.new()
		post.size=Vector3(.045,HEAD-SILL,.058)
		jamb.mesh=post
		jamb.material_override=finishes["rail"]
		jamb.rotation.y=a
		jamb.position=Vector3(sin(a)*RADIUS,(HEAD+SILL)*.5,cos(a)*RADIUS)
		add_child(jamb)

func _process(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if not camera: return
	var near_door:=global_position.distance_squared_to(camera.global_position)<16.
	speed=move_toward(speed,.55 if near_door else 0.,delta*.7)
	rotor.rotate_y(speed*delta)
