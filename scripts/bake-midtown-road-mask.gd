extends SceneTree

# One bit per square metre. Use the same road triangles and world origin as the drawn survey.
func _initialize() -> void:
	var survey := preload("res://meshes/midtown.scn").instantiate()
	var mask := BitMap.new()
	mask.create(Vector2i(2700, 3000))
	for tile in survey.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = tile.mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				var j := indices[i]
				if colors[j].r > 0.26 or absf(vertices[j].y) > 0.08:
					continue
				var triangle := PackedVector2Array()
				for k in 3:
					var p: Vector3 = tile.transform * vertices[indices[i+k]]
					triangle.append(Vector2(p.x + 1350, p.z + 1500))
				var bounds := Rect2(triangle[0], Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
				for y in range(maxi(0, floori(bounds.position.y)), mini(3000, ceili(bounds.end.y))):
					for x in range(maxi(0, floori(bounds.position.x)), mini(2700, ceili(bounds.end.x))):
						if Geometry2D.is_point_in_polygon(Vector2(x + 0.5,y + 0.5), triangle):
							mask.set_bit(x,y,true)
	survey.free()
	if mask.get_true_bit_count() == 0:
		printerr("No surveyed road triangles")
		quit(1)
		return
	print("Road coverage in square metres: ", mask.get_true_bit_count())
	quit(ResourceSaver.save(mask, "res://meshes/road_mask.res", ResourceSaver.FLAG_COMPRESS))
