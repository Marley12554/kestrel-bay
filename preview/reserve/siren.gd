extends Node3D
# Layered enamel shapes give the entry installation a silhouette and parallax.
# Each strip is a tapered ribbon with a raised rim around its silhouette.
var enamel_mesh:=SurfaceTool.new()

func ribbon(points: PackedVector2Array, widths: Array, depth: float, color: Color) -> void:
	var smooth:=PackedVector2Array()
	var sizes: Array[float]=[]
	for i in points.size()-1:
		for j in 7:
			var t:=j/7.
			smooth.append(points[i].cubic_interpolate(points[i+1],points[maxi(i-1,0)],points[mini(i+2,points.size()-1)],t))
			sizes.append(lerpf(widths[i],widths[i+1],t))
	smooth.append(points[-1])
	sizes.append(widths[-1])
	var contour:=PackedVector2Array()
	var back:=PackedVector2Array()
	for i in smooth.size():
		var tangent:=(smooth[mini(i+1,smooth.size()-1)]-smooth[maxi(i-1,0)]).normalized()
		var normal:=Vector2(-tangent.y,tangent.x)*sizes[i]*.5
		contour.append(smooth[i]+normal)
		back.append(smooth[i]-normal)
	for i in contour.size()-1:
		var l:=Vector3(contour[i].x,contour[i].y,depth)
		var r:=Vector3(back[i].x,back[i].y,depth)
		var ll:=Vector3(contour[i+1].x,contour[i+1].y,depth)
		var rr:=Vector3(back[i+1].x,back[i+1].y,depth)
		var dz:=Vector3.BACK*.055
		plate(l,r,rr,ll,color)
		plate(ll-dz,rr-dz,r-dz,l-dz,color)
		plate(l,ll,ll-dz,l-dz,color.darkened(.16))
		plate(rr,r,r-dz,rr-dz,color.darkened(.16))
		if i==0: plate(r,l,l-dz,r-dz,color)
		if i==contour.size()-2: plate(ll,rr,rr-dz,ll-dz,color)

func plate(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color) -> void:
	for vertex:Vector3 in [a,c,b,a,d,c]:
		enamel_mesh.set_color(color.srgb_to_linear())
		enamel_mesh.add_vertex(vertex)

func _ready() -> void:
	enamel_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blue:=Color("#305cc2")
	var aqua:=Color("#53c1d6")
	var flame:=Color("#f26538")
	# Flowing tail, two lower crests and a curl rising above the figure.
	for i in 5:
		var y:=i*.27
		var side:=1. if i%2==0 else -1.
		ribbon([Vector2(-1.45*side,y+.12),Vector2(-.99*side,y+.28),Vector2(-.42*side,y+.24),Vector2(.22*side,y+.03),Vector2(.82*side,y+.02),Vector2(1.38*side,y+.32)],[.05,.28,.37,.30,.23,.06],i*.045,blue if i%2==0 else aqua)
	ribbon([Vector2(-.03,1.04),Vector2(-.04,1.41),Vector2(.14,1.64),Vector2(.11,1.98),Vector2(.03,2.21)],[.65,.53,.42,.37,.24],.26,Color("#fff2bd"))
	for side in [-1.,1.]:
		ribbon([Vector2(side*.03,2.38),Vector2(side*.29,2.19),Vector2(side*.25,1.94),Vector2(side*.37,1.67),Vector2(side*.61,1.53),Vector2(side*.78,1.32)],[.14,.19,.24,.23,.18,.035],.29,flame)
		ribbon([Vector2(side*.14,2.37),Vector2(side*.35,2.20),Vector2(side*.39,1.88),Vector2(side*.55,1.72),Vector2(side*.76,1.65)],[.05,.075,.09,.095,.035],.26,Color("#e8a333"))
	ribbon([Vector2(-.67,1.48),Vector2(-1.02,1.6),Vector2(-1.06,1.84),Vector2(-.82,2.09),Vector2(-.84,2.34),Vector2(-1.15,2.49),Vector2(-1.28,2.75)],[.12,.16,.15,.16,.19,.25,.05],-.02,Color("#ffb023"))
	# A face, crown and the warm inner bands read separately from the blue waves.
	ribbon([Vector2(.01,1.96),Vector2(.025,2.09),Vector2(.02,2.23)],[.09,.21,.16],.34,Color("#eac6a3"))
	for side in [-1.,1.]:
		ribbon([Vector2(side*.019,2.13),Vector2(side*.057,2.15),Vector2(side*.084,2.135)],[.011,.018,.009],.40,Color("#33354c"))
		ribbon([Vector2(side*.04,2.28),Vector2(side*.10,2.42),Vector2(side*.16,2.36),Vector2(side*.24,2.46)],[.035,.072,.064,.018],.32,aqua)
		ribbon([Vector2(side*.10,1.32),Vector2(side*.27,1.20),Vector2(side*.40,1.15),Vector2(side*.52,1.18)],[.13,.15,.13,.033],.32,Color("#eab43e"))
	ribbon([Vector2(-1.1,.22),Vector2(-.72,.14),Vector2(-.31,.27),Vector2(.28,.36),Vector2(.65,.29)],[.035,.14,.19,.12,.03],.35,Color("#75bcec"))
	enamel_mesh.generate_normals()
	var enamel:=StandardMaterial3D.new()
	enamel.vertex_color_use_as_albedo=true
	enamel.cull_mode=BaseMaterial3D.CULL_DISABLED
	enamel.roughness=.32
	enamel_mesh.set_material(enamel)
	var view:=MeshInstance3D.new()
	view.mesh=enamel_mesh.commit()
	add_child(view)
