extends Node3D

# Section endpoints follow the road-facing edge of the six-inch survey sidewalks
# in the block's local frame. Width points inland, up to the shop sill on Fifth.
const CURBS = [
	[Vector2(89.55,-34), Vector2(89.65,30), Vector2.RIGHT, 6.85],
	[Vector2(72.45,-32), Vector2(72.78,29), Vector2.LEFT, 2.4],
	[Vector2(89.31,-113), Vector2(89.43,-63), Vector2.RIGHT, 2.4],
	[Vector2(72.39,-113), Vector2(72.53,-63), Vector2.LEFT, 2.4],
	[Vector2(-47,34.11), Vector2(65,33.60), Vector2.UP, 2.4],
	[Vector2(98,33.53), Vector2(146,33.23), Vector2.UP, 2.4],
	[Vector2(-47,43.64), Vector2(65,43.69), Vector2.DOWN, 2.4],
	[Vector2(98,44.18), Vector2(146,43.96), Vector2.DOWN, 2.4],
	[Vector2(-96,-53.20), Vector2(65,-53.67), Vector2.UP, 2.4],
	[Vector2(-96,-36.70), Vector2(65,-37.86), Vector2.DOWN, 2.4]
]
const CURB_TOP := .24
const CURB_BEVEL := .025
const CURB_SUPPORT_LAYER := 1 << 2
var noise := FastNoiseLite.new()

func _init() -> void:
	noise.seed=417
	noise.frequency=1.0

# X is snow thickness. Y is how much to favor accumulated snow over the
# existing depth texture (negative in the salted pedestrian path).
func accumulation(p: Vector2, inset: float, section: Array, along: float) -> Vector2:
	var slow:=noise.get_noise_2dv(p*.17)
	var broken:=noise.get_noise_2dv(p*.83)
	var end_fade:=smoothstep(0.,1.7,minf(along,section[0].distance_to(section[1])-along))
	var cross_fade:=1.-smoothstep(section[3]-.60,section[3],inset)
	var blend:=end_fade*cross_fade
	var ridge:=1.-smoothstep(.12,1.0+.35*broken,absf(inset-(.58+.38*slow)))
	var piles:=smoothstep(-.30,.35,slow+.32*broken)
	var deposit:=ridge*piles*smoothstep(0.,.30,inset)
	var path:=smoothstep(.55,2.35,inset+slow)*(.72+.28*broken)
	var depth:=.27*deposit+.026*maxf(0.,broken+.4)*(1.-path)
	return Vector2(depth,deposit*.60-path*.29)*blend

func build(material: Material) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cursor:=0
	# The tires climb this layer. The car's horizontal hull still hits walls and traffic.
	var support := StaticBody3D.new()
	support.name = "CurbSupport"
	support.collision_layer = CURB_SUPPORT_LAYER
	support.collision_mask = 0
	add_child(support)
	for section in CURBS:
		var start: Vector2=section[0]
		var finish: Vector2=section[1]
		var inward: Vector2=section[2]
		var width: float=section[3]
		add_curb_support(support, start, finish, inward, width)
		var rows:=1
		var cols:=1
		# The stone is a flat slab with independent normals for its curb face.
		var stride:=cols+5
		var triangles: Array[int]=[0,stride,1,1,stride,stride+1]
		if (finish-start).cross(inward)<0.: triangles.reverse()
		for i in rows+1:
			var t:=float(i)/rows
			var edge:=start.lerp(finish,t)
			for j in range(-4,cols+1):
				var inset:=maxf(0.,j*width/cols)
				if j==-4: inset=-.36
				if j in [-1, 0]: inset = CURB_BEVEL
				var p:=edge+inward*inset
				var y:=CURB_TOP if j>=-1 else .002
				var surface:=1 if j>=0 else (2 if j>=-2 else 3)
				st.set_smooth_group(surface)
				st.set_uv2(Vector2(surface,0.))
				st.add_vertex(Vector3(p.x,y,p.y))
				if i==rows or j==cols or j in [-3,-1]: continue
				var k:=cursor+i*stride+j+4
				for offset in triangles: st.add_index(k+offset)
		cursor+=(rows+1)*stride
		# Close both end cuts wherever the survey drops away at a corner.
		for end in [start,finish]:
			var other: Vector2=end+inward*width
			var top_edge: Vector2=end+inward*CURB_BEVEL
			st.set_smooth_group(4)
			st.set_uv2(Vector2(2.,0.))
			for corner: Vector3 in [Vector3(end.x,-.035,end.y),Vector3(top_edge.x,CURB_TOP,top_edge.y),
					Vector3(other.x,-.035,other.y),Vector3(other.x,CURB_TOP,other.y)]:
				st.add_vertex(corner)
			for offset in [0,1,2,2,1,3]: st.add_index(cursor+offset)
			cursor+=4
	st.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.name="PavingAndCurb"
	mesh.mesh=st.commit()
	mesh.material_override=material
	add_child(mesh)

func add_curb_support(body: StaticBody3D, start: Vector2, finish: Vector2, inward: Vector2, width: float) -> void:
	var points := PackedVector3Array()
	for edge: Vector2 in [start, finish]:
		var top := edge + inward * CURB_BEVEL
		var far := edge + inward * width
		points.append(Vector3(edge.x, -.035, edge.y))
		points.append(Vector3(top.x, CURB_TOP, top.y))
		points.append(Vector3(far.x, -.035, far.y))
		points.append(Vector3(far.x, CURB_TOP, far.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
