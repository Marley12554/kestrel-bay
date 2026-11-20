extends SceneTree
# Offline geometry baking keeps tens of thousands of individual street details
# out of the runtime scene tree. Cells share just two surfaces/materials.
const Atlas=preload("res://bay/atlas.gd")
var atlas
var chunks={}
var root_node=Node3D.new()
var standard=StandardMaterial3D.new()
var signals=ShaderMaterial.new()
var facades=ShaderMaterial.new()
var rng=RandomNumberGenerator.new()
var trunks=PackedVector3Array()
const PALETTE=["b0a38a","8f6654","7b8b90","a18c7d","737e80","967361","bbb5a4","a3a49a","716e69","9d8376"]
const TRIM=Color("bbb2a0")
func _initialize():
	call_deferred("bake")
func buffer(p,mode):
	var key=Vector3i(floori(p.x/180),mode,floori(p.z/180))
	if not chunks.has(key):
		var st=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(signals if mode==2 else facades if mode==1 else standard)
		chunks[key]=st
	return chunks[key]
func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color,normal:Vector3,mode=0,uv=Rect2(0,0,1,1),tag=Vector2.ZERO):
	var s=buffer((a+c)*.5,mode)
	var vs=[a,b,c,d]
	var uvs=[uv.position,Vector2(uv.end.x,uv.position.y),uv.end,Vector2(uv.position.x,uv.end.y)]
	# Godot front faces use clockwise winding.
	var ix=[0,2,1,0,3,2] if (b-a).cross(c-a).dot(normal)>0 else [0,1,2,0,2,3]
	for n in ix:
		s.set_color(color)
		s.set_normal(normal)
		s.set_uv(uvs[n])
		s.set_uv2(tag)
		s.add_vertex(vs[n])
func box(p:Vector3,size:Vector3,col:Color):
	var a=p-size*.5
	var b=p+size*.5
	quad(Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),b,Vector3(a.x,b.y,b.z),col,Vector3.UP)
	for side in [-1,1]:
		var z=p.z+side*size.z*.5
		quad(Vector3(a.x,a.y,z),Vector3(b.x,a.y,z),Vector3(b.x,b.y,z),Vector3(a.x,b.y,z),col,Vector3(0,0,side))
		var x=p.x+side*size.x*.5
		quad(Vector3(x,a.y,a.z),Vector3(x,a.y,b.z),Vector3(x,b.y,b.z),Vector3(x,b.y,a.z),col,Vector3(side,0,0))
func strip(a:Vector3,b:Vector3,width:float,c:Color):
	var n=(b-a).cross(Vector3.UP).normalized()*width*.5
	quad(a-n,b-n,b+n,a+n,c,Vector3.UP)
func flat(raw,color,y):
	var poly=Atlas.polygon(raw)
	var triangles=Geometry2D.triangulate_polygon(poly)
	for i in range(0,triangles.size(),3):
		var vs=[]
		for j in 3:
			var q=poly[triangles[i+j]]
			vs.append(Vector3(q.x,y,q.y))
		quad(vs[0],vs[1],vs[2],vs[0],color,Vector3.UP)
func segment(a:Vector3,b:Vector3,r:float,col:Color,sides=6,top=1.0):
	var axis=(b-a).normalized()
	var u=axis.cross(Vector3.RIGHT if absf(axis.x)<.8 else Vector3.UP).normalized()
	var v=axis.cross(u)
	for i in sides:
		var p=(u*cos(i*TAU/sides)+v*sin(i*TAU/sides))*r
		var q=(u*cos((i+1)*TAU/sides)+v*sin((i+1)*TAU/sides))*r
		quad(a+p,a+q,b+q*top,b+p*top,col,(p+q).normalized())
func tree(p:Vector3,h:float):
	trunks.append(Vector3(p.x,h,p.z))
	segment(p,p+Vector3.UP*h*.72,h*.026,Color("605345"),5,.61)
	var base=p+Vector3.UP*h*.64
	var leaf=Color("41644d").lerp(Color("7c8250"),rng.randf()*.65)
	for i in 3:
		var center=base+Vector3(rng.randf_range(-1.1,1.1),i*.65,rng.randf_range(-1.1,1.1))
		var r=h*(.26-i*.035)
		segment(center-Vector3.UP*r*.7,center,r*.52,leaf,7,1.92)
		segment(center,center+Vector3.UP*r*1.4,r,leaf.lightened(.04),7,.09)
func shell(p):
	var base=p.at
	var seed_value=int(p.seed)
	var color=Color(PALETTE[seed_value%PALETTE.size()])
	if p.tier=="empire":color=Color("cbbca2")
	if p.tier=="needle":color=Color("6b9bab")
	var style=0
	if p.style in ["office","studio"] or p.tier=="needle":style=1
	if p.style in ["deco","hotel"] or p.tier=="empire":style=2
	if p.style in ["warehouse","garage","hangar","cells"]:style=3
	var tag=seed_value%997+1000*style
	var start=0
	while start<p.floors:
		var dims=Atlas.tier(p,start)
		var end=start+1
		while end<p.floors and Atlas.tier(p,end)==dims:end+=1
		var low=base.y+start*3.8
		var high=base.y+end*3.8
		for side in [-1,1]:
			var z=base.z+side*dims.y*.5
			quad(Vector3(base.x-dims.x*.5,low,z),Vector3(base.x+dims.x*.5,low,z),Vector3(base.x+dims.x*.5,high,z),Vector3(base.x-dims.x*.5,high,z),color,Vector3(0,0,side),1,Rect2(-dims.x*.5,start*3.8,dims.x,high-low),Vector2(tag,1 if side==p.face else 2))
			var x=base.x+side*dims.x*.5
			quad(Vector3(x,low,base.z-dims.y*.5),Vector3(x,low,base.z+dims.y*.5),Vector3(x,high,base.z+dims.y*.5),Vector3(x,high,base.z-dims.y*.5),color,Vector3(side,0,0),1,Rect2(-dims.y*.5,start*3.8,dims.y,high-low),Vector2(tag,3))
		box(Vector3(base.x,high-.12,base.z),Vector3(dims.x+.65,.24,dims.y+.65),color.lightened(.12))
		if p.floors>14:
			for side in [-1,1]:
				for split in [-.46,-.19,.19,.46]:
					box(Vector3(base.x+split*dims.x,(high+low)*.5,base.z+side*dims.y*.5),Vector3(.53,high-low,.54),color.lightened(.11))
		start=end
	var fh=p.floors*3.8
	var roof=base+Vector3.UP*fh
	if p.tier in ["empire","needle"]:
		for i in 4:
			box(roof+Vector3.UP*(i*4+2),Vector3(11-i*2,4,12-i*2),TRIM)
		segment(roof+Vector3.UP*16,roof+Vector3.UP*61,1.2,Color("abada9"),10,.025)
	elif seed_value%4==0:
		box(roof+Vector3(0,.72,0),Vector3(4.3,1.44,3.2),Color("697572"))
		if p.floors<12:
			segment(roof+Vector3(3,.1,2),roof+Vector3(3,2.6,2),.17,Color("68594d"))
			segment(roof+Vector3(3,2,2),roof+Vector3(3,5.1,2),1.8,Color("725e4b"),10)
			segment(roof+Vector3(3,5.1,2),roof+Vector3(3,6.1,2),1.95,Color("515755"),10,.08)
	var front=base+Vector3(0,0,p.face*(p.d*.5+.52))
	box(front+Vector3.UP*3.18,Vector3(minf(p.w*.65,16),.28,1.85),Color("42645f") if seed_value%2 else Color("946444"))
	for side in [-1,1]:
		box(front+Vector3(side*2.03,1.53,0),Vector3(.33,3.06,.42),TRIM)
	if p.style in ["stores","coffee","bookshop","studio","florist"]:
		for side in [-1,1]:
			var shop=front+Vector3(side*p.w*.25,0,0)
			var awning=Color("47766c") if seed_value%3 else Color("995948")
			box(shop+Vector3(0,2.90,p.face*.58),Vector3(p.w*.35,.19,2.05),awning)
			box(shop+Vector3(0,2.70,p.face*1.56),Vector3(p.w*.35,.35,.12),awning.darkened(.17))
	elif p.style in ["apartments","deco","hotel"] and p.floors<19:
		for floor_num in range(2,int(p.floors),3):
			box(base+Vector3.UP*(floor_num*3.8-.13),Vector3(p.w+.36,.24,p.d+.36),color.lerp(TRIM,.38))
	if p.tier=="empire":
		for side in [-1,1]:
			for i in 5:
				box(front+Vector3(side*(3+i*.4),3.5+i*.26,.7),Vector3(.20,6+i*.51,.48),Color("aa8850"))
func intersection(node:int, origin:Vector3, width:float):
	var control=atlas.junction_control(node,origin)
	if control==0:return
	var end=atlas.points[node]
	var f=(end-origin).normalized()
	var side=f.cross(Vector3.UP).normalized()
	var stop=end-f*12
	var pos=stop+side*(width*.5+.55)
	strip(stop+Vector3.UP*.16+side*.3,stop+Vector3.UP*.16+side*width*.49,.25,Color("e6e1c7"))
	segment(pos,pos+Vector3.UP*(2.4 if control==1 else 4.),.085,Color("535852"))
	if control==1:
		var face=pos+Vector3.UP*2.35
		quad(face-side*.45+Vector3.UP*.45,face+side*.45+Vector3.UP*.45,face+side*.45-Vector3.UP*.45,face-side*.45-Vector3.UP*.45,Color.WHITE,-f,2,Rect2(0,0,1,1),Vector2(0,-1))
		return
	var center=pos+Vector3.UP*4.
	box(center,Vector3(.5,1.25,.5),Color("343733"))
	for lamp in 3:
		var c=center-f*.37+Vector3.UP*(.37-lamp*.37)
		quad(c-side*.16+Vector3.UP*.16,c+side*.16+Vector3.UP*.16,c+side*.16-Vector3.UP*.16,c-side*.16-Vector3.UP*.16,[Color("ff4a39"),Color("ffc243"),Color("4ef486")][lamp],-f,2,Rect2(0,0,1,1),Vector2(node%7+(12 if control==3 else 0),lamp))
func street(e):
	var a=atlas.points[int(e[0])]
	var b=atlas.points[int(e[1])]
	var width=float(e[2])
	var bridge=e[4]=="bridge"
	intersection(int(e[0]),b,width)
	intersection(int(e[1]),a,width)
	var up=Vector3.UP
	var forward=(b-a).normalized()
	var right=forward.cross(up).normalized()
	var lift=.065 if bridge else .05
	if not bridge:strip(a+up*.023,b+up*.023,width+7,Color("92918a"))
	strip(a+up*lift-forward*width*.42,b+up*lift+forward*width*.42,width,Color("384148"))
	var dist=a.distance_to(b)
	for j in range(9,int(dist)-5,12):
		strip(a+forward*j+up*(lift+.06),a+forward*(j+4.2)+up*(lift+.06),.16,Color("ddbb79"))
	for side in [-1,1]:
		var off=right*side*(width*.5-.28)
		strip(a+off+up*(lift+.035),b+off+up*(lift+.035),.13,Color("d0cab8"))
	if bridge:
		for side in [-1,1]:
			var off=right*side*(width*.5+.8)
			strip(a+off+up*.12,b+off+up*.12,2.0,TRIM)
			var opening_start=14. if a.y<2.65 and atlas.graph.get_point_connections(int(e[0])).size()>1 else 0.
			var opening_end=14. if b.y<2.65 and atlas.graph.get_point_connections(int(e[1])).size()>1 else 0.
			segment(a+forward*opening_start+off+right*side+up*1.24,b-forward*opening_end+off+right*side+up*1.24,.105,Color("657777"),4)
			for j in range(ceili(opening_start),int(dist-opening_end),6):
				box(a+forward*j+off+right*side+up*.67,Vector3(.18,1.30,.18),Color("7a817d"))
	elif dist>30:
		for d in [8.,dist-8.]:
			for j in range(-int(width*.4),int(width*.4),2):
				strip(a+forward*(d-1.35)+right*j+up*.13,a+forward*(d+1.35)+right*j+up*.13,.64,Color("c3c1ad"))
func bake():
	atlas=Atlas.new()
	rng.seed=61899
	standard.vertex_color_use_as_albedo=true
	standard.vertex_color_is_srgb=true
	standard.roughness=.86
	signals.shader=preload("res://bay/signal.gdshader")
	signals.set_shader_parameter("stop_face",preload("res://bay/stop.svg"))
	facades.shader=load("res://bay/facade.gdshader")
	for area in atlas.data.land:
		flat(area[1],Color("928d83") if area[2]=="city" else Color("818877"),2.6)
		var poly=Atlas.polygon(area[1])
		for i in poly.size():
			var a=Vector3(poly[i].x,2.6,poly[i].y)
			var b=Vector3(poly[(i+1)%poly.size()].x,2.6,poly[(i+1)%poly.size()].y)
			quad(a,b,b-Vector3.UP*9,a-Vector3.UP*9,Color("756f61"),(b-a).cross(Vector3.UP).normalized())
	for e in atlas.data.roads:street(e)
	for p in atlas.data.parcels:shell(p)
	flat(atlas.data.parks[0][1],Color("768357"),2.69)
	for path in atlas.data.walks:
		for i in range(1,path.size()):
			var a=Vector3(path[i-1][0],2.73,path[i-1][1])
			var b=Vector3(path[i][0],2.73,path[i][1])
			strip(a,b,5.3,Color("b49f80"))
	var park=atlas.park_shape
	var bbox=Rect2(park[0],Vector2.ZERO)
	for pt in park:bbox=bbox.expand(pt)
	for i in 610:
		var p=bbox.position+Vector2(rng.randf(),rng.randf())*bbox.size
		if not Geometry2D.is_point_in_polygon(p,park):continue
		var on_path=false
		for path in atlas.data.walks:
			for k in range(1,path.size()):
				var a=Vector2(path[k-1][0],path[k-1][1])
				var b=Vector2(path[k][0],path[k][1])
				if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p)<4:on_path=true
		if not on_path:tree(Vector3(p.x,2.7,p.y),rng.randf_range(7,15))
	# Stone portals and cable fans give the bridge an identifiable silhouette.
	for tx in [-398.,-690.]:
		for side in [-1,1]:
			box(Vector3(tx,19,65+side*11),Vector3(9,48,4.5),Color("a59b85"))
			box(Vector3(tx,44,65+side*11),Vector3(10,2.2,5.4),TRIM)
			for k in range(-5,6):
				if k==0:continue
				var foot=Vector3(tx+k*22,19.5,65+side*9)
				segment(Vector3(tx,43,65+side*11),foot,.16,Color("555f61"),4)
		box(Vector3(tx,40.5,65),Vector3(8,4.8,22),Color("ab9e89"))
		for z in [59,71]:
			for sign_x in [-1,1]:
				segment(Vector3(tx,32,z+sign_x*4.2),Vector3(tx,38.5,z),1.5,TRIM,4)
	for e in atlas.data.roads:
		if e[4]=="bridge":continue
		var a=atlas.points[int(e[0])]
		var b=atlas.points[int(e[1])]
		var f=(b-a).normalized()
		var side=f.cross(Vector3.UP)
		for k in range(22,int(a.distance_to(b))-10,52):
			var at=a+f*k+side*(e[2]*.5+1.6)
			segment(at,at+Vector3.UP*7,.10,Color("586366"),5,.75)
			box(at+Vector3.UP*7-side*.6,Vector3(1.4,.14,.6),Color("d6c499"))
			if k%3==1:tree(at+f*6,7.5+rng.randf()*2.7)
	root_node.name="NewYork"
	var trees=StaticBody3D.new()
	trees.name="StreetAndParkTrees"
	root_node.add_child(trees)
	trees.owner=root_node
	var tree_shapes={}
	for trunk in trunks:
		var height=roundi(trunk.y)
		if not tree_shapes.has(height):
			var cyl=CylinderShape3D.new();cyl.height=height*.64;cyl.radius=height*.029;tree_shapes[height]=cyl
		var c=CollisionShape3D.new();c.shape=tree_shapes[height]
		c.position=Vector3(trunk.x,2.60+height*.32,trunk.z)
		trees.add_child(c);c.owner=root_node
	for key in chunks:
		var mesh=MeshInstance3D.new()
		mesh.mesh=chunks[key].commit()
		mesh.name="Tile_%s_%s_%s"%[key.x,key.y,key.z]
		root_node.add_child(mesh)
		mesh.owner=root_node
	var packed=PackedScene.new()
	packed.pack(root_node)
	var error=ResourceSaver.save(packed,"res://bay/data/city.scn",ResourceSaver.FLAG_COMPRESS)
	print("CITY BAKE: ",chunks.size()," surfaces, ",atlas.data.parcels.size()," parcels, error=",error)
	root_node.free()
	quit(error)
