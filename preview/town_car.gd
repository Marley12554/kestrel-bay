extends Node3D

func piece(mesh: PrimitiveMesh, at: Vector3, color: Color) -> MeshInstance3D:
	var n:=MeshInstance3D.new()
	var m:=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=.58
	n.mesh=mesh
	n.material_override=m
	n.position=at
	add_child(n)
	return n

func box(at: Vector3,size: Vector3,color: Color) -> void:
	var mesh:=BoxMesh.new()
	mesh.size=size
	piece(mesh,at,color)

func shell(rows: Array,color: Color) -> void:
	# Each row describes one horizontal outline, chamfered at all four corners.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:Array=[]
	for r in rows:
		var w:float=r[0]
		var front:float=r[1]
		var rear:float=r[2]
		var y:float=r[3]
		var c:=.14
		rings.append([Vector3(-w+c,y,front),Vector3(w-c,y,front),Vector3(w,y,front+c),Vector3(w,y,rear-c),Vector3(w-c,y,rear),Vector3(-w+c,y,rear),Vector3(-w,y,rear-c),Vector3(-w,y,front+c)])
	for i in range(rings.size()-1):
		for j in 8:
			var k:=(j+1)%8
			for v in [rings[i][j],rings[i][k],rings[i+1][k],rings[i][j],rings[i+1][k],rings[i+1][j]]:
				st.add_vertex(v)
	for i in range(1,7):
		for v in [rings.back()[0],rings.back()[i],rings.back()[i+1]]:
			st.add_vertex(v)
	st.generate_normals()
	var n:=MeshInstance3D.new()
	n.mesh=st.commit()
	var mat:=StandardMaterial3D.new()
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.albedo_color=color
	mat.roughness=.38
	n.material_override=mat
	add_child(n)

func build(cab: bool) -> void:
	var paint:=Color("#eeb731") if cab else Color("#365d68")
	shell([[.85,-2.18,2.19,.34],[.97,-2.25,2.27,.63],[.94,-2.18,2.17,.89],[.86,-2.02,1.96,1.00]],paint)
	shell([[.87,-1.32,1.48,1.0],[.69,-.74,.90,1.57]],Color("#324653"))
	shell([[.69,-.75,.91,1.55],[.65,-.70,.86,1.62]],paint)
	for side in [-1,1]:
		box(Vector3(side*.805,1.27,.04),Vector3(.045,.56,.12),paint)
		box(Vector3(side*.98,1.1,-.87),Vector3(.21,.15,.23),paint)
		for z in [-1.42,1.45]:
			var tire:=CylinderMesh.new()
			tire.top_radius=.335
			tire.bottom_radius=.335
			tire.height=.19
			tire.radial_segments=16
			piece(tire,Vector3(side*.89,.35,z),Color("#27282a")).rotation.z=PI/2
			var rim:=CylinderMesh.new()
			rim.top_radius=.21
			rim.bottom_radius=.21
			rim.height=.023
			rim.radial_segments=12
			piece(rim,Vector3(side*.994,.35,z),Color("#abb1ad")).rotation.z=PI/2
		box(Vector3(side*.67,.76,-2.21),Vector3(.36,.15,.08),Color("#ffe7af"))
		box(Vector3(side*.70,.78,2.21),Vector3(.35,.17,.08),Color("#b43f36"))
	box(Vector3(0,.64,-2.24),Vector3(.84,.19,.06),Color("#374044"))
	if cab:
		box(Vector3(0,1.75,.12),Vector3(.30,.28,.76),Color("#ffdf8c"))
