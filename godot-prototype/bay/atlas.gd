extends RefCounted
const FILE="res://bay/data/new_york.json"
const BASE=2.6
var data: Dictionary
var points=PackedVector3Array()
var marks={}
var plots={}
var by_cell={}
var road_cells={}
var outlines=[]
var park_shape: PackedVector2Array
var graph=AStar3D.new()
func _init():
	data=JSON.parse_string(FileAccess.get_file_as_string(FILE))
	for m in data.marks:
		var v=data.marks[m]
		marks[m]=Vector3(v[0],v[1],v[2])
	for v in data.nodes:
		graph.add_point(points.size(),Vector3(v[0],v[1],v[2]))
		points.append(Vector3(v[0],v[1],v[2]))
	for i in data.roads.size():
		var e=data.roads[i]
		graph.connect_points(int(e[0]),int(e[1]))
		var a=points[int(e[0])]
		var b=points[int(e[1])]
		for k in range(1+ceili(a.distance_to(b)/65)):
			var key=cell(a.lerp(b,minf(1,k*65/maxf(1,a.distance_to(b)))))
			if not road_cells.has(key):road_cells[key]=[]
			if not road_cells[key].has(i):road_cells[key].append(i)
	for i in data.parcels.size():
		var p=data.parcels[i]
		p.id=i
		p.at=Vector3(p.x,BASE,p.z)
		if not p.title.is_empty():plots[p.title]=p
		var key=cell(p.at)
		if not by_cell.has(key):by_cell[key]=[]
		by_cell[key].append(p)
	for area in data.land:
		outlines.append(polygon(area[1]))
	park_shape=polygon(data.parks[0][1])
static func cell(p:Vector3)->Vector2i:
	return Vector2i(floori(p.x/100),floori(p.z/100))
static func polygon(raw:Array)->PackedVector2Array:
	var out=PackedVector2Array()
	for pt in raw:out.append(Vector2(pt[0],pt[1]))
	return out
static func tier(p:Dictionary,floor_at:int)->Vector2:
	var t=floor_at/float(p.floors)
	var size=Vector2(p.w,p.d)
	if p.tier=="empire":
		return size*(.42 if t>=.85 else .56 if t>=.56 else .69 if t>=.25 else .84 if t>=.12 else 1.)
	if p.tier=="needle":return size*(1.-floorf(t*6)*.075)
	if p.floors>13 and t>=.76:return size*.77
	return size
func neighbors(p:Vector3,grid:Dictionary,r=1)->Array:
	var result=[]
	var key=cell(p)
	for x in range(-r,r+1):
		for y in range(-r,r+1):
			var k=key+Vector2i(x,y)
			if grid.has(k):result.append_array(grid[k])
	return result
func region(p:Vector3)->String:
	if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),park_shape):return "Central Park"
	for i in outlines.size():
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),outlines[i]):
			if i==0:
				return "Upper Manhattan" if p.z<-3030 else "Midtown" if p.z<-1300 else "Lower Manhattan"
			if i==1:return "Queens" if p.z<-1800 else "Old Harbor · Brooklyn" if p.z>-160 else "Brooklyn"
			return data.land[i][0]
	return "East River" if p.z<150 else "New York Harbor"
