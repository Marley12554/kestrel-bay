extends SceneTree

# Bake only the walkable winter block and its connecting streets. The channels
# keep snow on separate support planes so filtering never bends it up a curb.
const Sidewalk = preload("res://winter/sidewalk_snow.gd")
const ORIGIN := Vector2(-240,-136)
const SIZE := Vector2i(400,208)
const SCALE := 4
var size := SIZE*SCALE
var occupied := {}
var support := Image.create_empty(size.x,size.y,false,Image.FORMAT_R8)

func _initialize() -> void:
	var survey:=preload("res://meshes/midtown.scn").instantiate()
	var block:=Transform3D(Basis(Vector3.UP,-atan2(.488,.873)),Vector3(-208.099,0,573.891))
	for tile: MeshInstance3D in survey.find_children("*","MeshInstance3D",true,false):
		var local: Transform3D=block.affine_inverse()*tile.transform
		var bounds:=local*tile.get_aabb()
		if not Rect2(ORIGIN,SIZE).intersects(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))): continue
		var arrays:=tile.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var a:=local*vertices[indices[i]]
			var b:=local*vertices[indices[i+1]]
			var c:=local*vertices[indices[i+2]]
			var color := colors[indices[i]]
			var channel := 0
			if color.a < .9:
				if color.a > .73: continue # Vertical curb face.
				var at := block*((a+b+c)/3.)
				var grade_y := preload("res://survey/grade.gd").height(at)
				if at.y < grade_y-.32: continue # Buried foundation.
				channel = 0 if color.a < .45 else 1
			else:
				if a.y<-.015 or a.y>.23 or absf(b.y-a.y)>.002 or absf(c.y-a.y)>.002: continue
				# Packed tile vertices are quantized across the full tower height.
				channel = 0 if color.r<.26 and a.y<.09 else (1 if absf(a.y-.1524)<.015 else 2)
				if channel==2 and absf(a.y-.2124)>.015: continue
			fill_triangle(Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z),channel)
	survey.free()
	var snow:=Sidewalk.new()
	var cover:=preload("res://winter/snow_depth.png").get_image()
	var field:=Image.create_empty(size.x,size.y,false,Image.FORMAT_RGBA8)
	field.fill(Color(0,0,0,0))
	for y in size.y:
		for x in size.x:
			var channel:=support.get_pixel(x,y).r8-1
			if channel>=0:
				var p:=ORIGIN+(Vector2(x,y)+Vector2(.5,.5))/SCALE
				var drift:=sample_cover(cover,p)
				var depth:=.083*smoothstep(.22,.60,drift)
				if channel==0:
					var lateral:=p.x if absf(p.x-81.)<9. else p.y+45.8
					var wheel:=absf(fposmod(lateral+.12*sin(p.y*.07+p.x*.09),3.85)-1.925)
					var tracks:=1.-smoothstep(.14,.53,absf(wheel-.78))
					depth=.055*smoothstep(.57,.83,drift-tracks*.27)
				put(field,x,y,channel,depth)
	for section in Sidewalk.CURBS:
		var start: Vector2=section[0]
		var edge: Vector2=section[1]-start
		var across: Vector2=section[2]
		var width: float=section[3]
		var box:=Rect2(start,Vector2.ZERO).expand(start+edge).expand(start+across*width).expand(start+edge+across*width)
		var begin:=Vector2i(((box.position-ORIGIN)*SCALE).floor())
		var end:=Vector2i(((box.end-ORIGIN)*SCALE).ceil())
		for y in range(begin.y,end.y):
			for x in range(begin.x,end.x):
				var p:=ORIGIN+(Vector2(x,y)+Vector2(.5,.5))/SCALE
				var t: float=(p.x-start.x)/edge.x if across.x==0 else (p.y-start.y)/edge.y
				var inset:float=(p-start-edge*t).dot(across)
				if t<0 or t>1 or inset<0 or inset>width: continue
				var acc:=snow.accumulation(p,inset,section,t*edge.length())
				var loose:=smoothstep(.22,.58,sample_cover(cover,p)+acc.y)
				put(field,x,y,3,(.065*loose+acc.x)*smoothstep(0.,.23,inset))
	snow.free()
	field.set_meta("tiles",PackedVector3Array(occupied.keys()))
	var err:=ResourceSaver.save(field,"res://winter/snowpack.res",ResourceSaver.FLAG_COMPRESS)
	print("Snow depth field ",size," saved: ",error_string(err))
	quit(0 if err==OK else 1)

func sample_cover(img: Image,p: Vector2) -> float:
	var s:=img.get_width()
	var uv:=p*(s/64.)-Vector2(.5,.5)
	var cell:=Vector2i(uv.floor())
	var f:=uv-uv.floor()
	var x:=posmod(cell.x,s)
	var y:=posmod(cell.y,s)
	return lerpf(lerpf(img.get_pixel(x,y).r,img.get_pixel((x+1)%s,y).r,f.x),
		lerpf(img.get_pixel(x,(y+1)%s).r,img.get_pixel((x+1)%s,(y+1)%s).r,f.x),f.y)

func put(img: Image,x: int,y: int,channel: int,depth: float) -> void:
	# One byte reserves zero for absent support, even on cleared pavement.
	var color:=Color(0,0,0,0)
	color[channel]=(1.+round(clampf(depth/.36,0.,1.)*254.))/255.
	img.set_pixel(x,y,color)
	if depth>.001:
		occupied[Vector3(floori((ORIGIN.x+(x+.5)/SCALE)/8.),channel,floori((ORIGIN.y+(y+.5)/SCALE)/8.))]=true

func fill_triangle(a: Vector2,b: Vector2,c: Vector2,channel: int) -> void:
	var v: Array[Vector2]=[(a-ORIGIN)*SCALE,(b-ORIGIN)*SCALE,(c-ORIGIN)*SCALE]
	for y in range(maxi(0,ceili(minf(v[0].y,minf(v[1].y,v[2].y))-.5)),mini(size.y,ceili(maxf(v[0].y,maxf(v[1].y,v[2].y))-.5))):
		var lo:=INF
		var hi:=-INF
		for i in 3:
			var p:=v[i]
			var q:=v[(i+1)%3]
			if (p.y>y+.5)==(q.y>y+.5): continue
			var cut:=lerpf(p.x,q.x,(y+.5-p.y)/(q.y-p.y))
			lo=minf(lo,cut)
			hi=maxf(hi,cut)
		if lo>=hi: continue
		var x0:=maxi(0,ceili(lo-.5))
		var x1:=mini(size.x,ceili(hi-.5))
		if x1>x0: support.fill_rect(Rect2i(x0,y,x1-x0,1),Color8(channel+1,0,0))
