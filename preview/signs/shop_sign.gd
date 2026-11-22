extends RefCounted

# Use the artwork's aspect ratio on each storefront, including cropped lockups.
static func mount(parent: Node3D, texture: Texture2D, pose: Transform3D, height: float, tint := Color.WHITE, region := Rect2()) -> Sprite3D:
	var panel := Sprite3D.new()
	panel.texture = texture
	panel.transform = pose
	panel.double_sided = false
	panel.modulate = tint
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if region.has_area():
		panel.region_enabled = true
		panel.region_rect = region
	panel.pixel_size = height / (region.size.y if region.has_area() else float(texture.get_height()))
	parent.add_child(panel)
	return panel
