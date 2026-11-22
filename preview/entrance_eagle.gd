extends RefCounted

# Relief traced in frontal elevation: a hood of radiating feathers surrounds
# the head, with two long folded wings and a faceted breast above the flutes.
static func carve() -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for hand: float in [-1.,1.]:
		var outline: Array[Vector2]=[Vector2(.98,.03),Vector2(.98,1.35),Vector2(.93,1.94),
			Vector2(.78,2.36),Vector2(.57,2.64),Vector2(.37,2.81),Vector2(.16,2.86)]
		for i in outline.size()-1:
			var a:=outline[i]
			var b:=outline[i+1]
			var inner:=Vector3(hand*.23,1.84,.43)
			var va:=Vector3(hand*a.x,a.y,.10)
			var vb:=Vector3(hand*b.x,b.y,.10)
			var ridge:=(va+vb)*.5
			ridge.z+=.085
			facet(surface,inner,va,ridge)
			facet(surface,inner,ridge,vb)
		# Each feather is an extruded, beveled plane with a stepped lower tip.
		for i in 3:
			var x:float=.37+i*.213
			var bottom:float=.27-i*.13
			block_relief(surface,Vector2(hand*x,bottom),.245,1.54+i*.13,.48-i*.07,.19)
		block_relief(surface,Vector2(hand*.26,0),.255,1.40,.55,.19)
	block_relief(surface,Vector2(0,1.05),.94,.98,.74,.22)
	block_relief(surface,Vector2(0,2.02),.53,.40,.62,.19)
	# Angled brow and projecting beak.
	var tip:=Vector3(0,2.20,.91)
	var crown:=Vector3(0,2.72,.41)
	facet(surface,Vector3(-.22,2.34,.37),tip,crown)
	facet(surface,crown,tip,Vector3(.21,2.34,.37))
	facet(surface,Vector3(.21,2.34,.37),tip,Vector3(0,2.21,.43))
	facet(surface,Vector3(0,2.21,.43),tip,Vector3(-.22,2.34,.37))
	return surface.commit()

static func block_relief(surface: SurfaceTool,base: Vector2,w: float,h: float,z: float,bevel: float) -> void:
	var outline: Array[Vector2]=[Vector2(-.40,.02),Vector2(0,-.06),Vector2(.42,0),
		Vector2(.50,.88),Vector2(.44,1),Vector2(-.45,.99),Vector2(-.50,.88)]
	var peak:=Vector3(base.x,base.y+h*.74,z+.09)
	for i in outline.size():
		var a:Vector2=base+outline[i]*Vector2(w,h)
		var b:Vector2=base+outline[(i+1)%outline.size()]*Vector2(w,h)
		var va:=Vector3(a.x,a.y,z)
		var vb:=Vector3(b.x,b.y,z)
		facet(surface,va,vb,peak)
		var drop:=Vector3(0,0,bevel)
		facet(surface,va,va-drop,vb-drop)
		facet(surface,va,vb-drop,vb)

static func facet(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	var normal:=(b-a).cross(c-a).normalized()
	if normal.z<0:
		var swap:=b
		b=c
		c=swap
		normal=-normal
	for vertex: Vector3 in [a,c,b]:
		var cavity:=lerpf(.54,.99,smoothstep(.10,.74,vertex.z))
		var value:=clampf(cavity*(.89+.11*normal.y+.055*normal.x),.42,1.)
		surface.set_color(Color(value,value,value))
		surface.set_normal(normal)
		surface.add_vertex(vertex)
