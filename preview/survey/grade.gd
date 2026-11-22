extends RefCounted

const RECORD := preload("res://survey/grade.json")
static var origin := Vector2.ZERO
static var size := 0
static var scale_px := 0
static var ground := PackedFloat32Array()
static var curb := PackedByteArray()

static func load_field() -> void:
	if size > 0: return
	var record: Dictionary = RECORD.data
	size = int(record.samples)
	scale_px = int(record.curb_pixels_per_metre)
	origin = Vector2(record.origin_en[0]-record.godot_origin_en[0], record.godot_origin_en[1]-record.origin_en[1])
	var extent := size-1
	var width := extent*scale_px
	var raw := Marshalls.base64_to_raw(record.navd88_cm).decompress(2*size*size, FileAccess.COMPRESSION_DEFLATE)
	curb = Marshalls.base64_to_raw(record.surface_cm).decompress(width*width, FileAccess.COMPRESSION_DEFLATE)
	ground.resize(size*size)
	for j in size:
		for i in size:
			var index := j*size+i
			var cm := raw.decode_s16(index*2) - curb[mini(j*scale_px,width-1)*width+mini(i*scale_px,width-1)]
			var distance := mini(mini(i,j),mini(extent-i,extent-j))
			ground[index] = (cm*.01-float(record.datum_navd88_m))*smoothstep(0.,float(record.collar),distance)

static func grid(at: Vector3) -> Vector2:
	load_field()
	return Vector2(at.x-origin.x,origin.y-at.z)

static func contains(at: Vector3) -> bool:
	var p := grid(at)
	return p.x >= 0. and p.y >= 0. and p.x < size-1 and p.y < size-1

static func height(at: Vector3, legacy: float = 0.0) -> float:
	var p := grid(at)
	var i := floori(p.x)
	var j := floori(p.y)
	if i<0 or j<0 or i>=size-1 or j>=size-1: return legacy
	var idx := j*size+i
	var a := ground[idx]
	var b := ground[idx+1]
	var c := ground[idx+size]
	var d := ground[idx+size+1]
	var u := p.x-i
	var v := p.y-j
	var surface_cm := curb[floori(p.y*scale_px)*(size-1)*scale_px+floori(p.x*scale_px)]
	return a + (b-a)*u + (d-b)*v + maxf(v-u,0.)*(c-a-d+b) + .01*surface_cm

static func physical_height(space: PhysicsDirectSpaceState3D, at: Vector3, legacy: float=0.) -> float:
	if not contains(at): return legacy
	var y := height(at)
	var centre := Vector3(at.x,y,at.z)
	var ray := PhysicsRayQueryParameters3D.create(centre+Vector3.UP*.5,centre-Vector3.UP*.5,8)
	var hit := space.intersect_ray(ray)
	return hit.position.y if not hit.is_empty() else y
