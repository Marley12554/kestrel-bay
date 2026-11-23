extends CompositorEffect

const BUFFER_CONTEXT := &"camera_shutter"
var strength := .45
var device: RenderingDevice
var shader: RID
var pipeline: RID
var sampler: RID
var previous_projection := Projection()
var previous_frame := -2
var focusing_vehicle := false
var vehicle_pose := Transform3D.IDENTITY

func set_vehicle_focus(active: bool, pose: Transform3D) -> void:
	RenderingServer.call_on_render_thread(func():
		focusing_vehicle = active
		vehicle_pose = pose
	)

func _init() -> void:
	# Glass does not carry the velocity of its frame in the opaque buffer.
	# Composite windows over the exposed street after the shutter pass.
	effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT
	needs_motion_vectors = true
	access_resolved_color = true
	access_resolved_depth = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and device:
		if shader.is_valid(): device.free_rid(shader)
		if sampler.is_valid(): device.free_rid(sampler)

func binding(rid: RID, index: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.binding = index
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.add_id(rid)
	return uniform

func _render_callback(_stage: int, data: RenderData) -> void:
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if not buffers: return
	if not device:
		device = RenderingServer.get_rendering_device()
		shader = device.shader_create_from_spirv(preload("res://render/shutter.glsl").get_spirv())
		if shader.is_valid():
			pipeline = device.compute_pipeline_create(shader)
			sampler = device.sampler_create(RDSamplerState.new())
	if not pipeline.is_valid(): return
	var size := buffers.get_internal_size()
	if size.x < 1 or size.y < 1: return
	var views := buffers.get_view_count()
	buffers.create_texture(BUFFER_CONTEXT, &"color", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT, RenderingDevice.TEXTURE_SAMPLES_1, size, views, 1, true, false)
	var scene := data.get_render_scene_data()
	var camera_projection := scene.get_cam_projection() * Projection(scene.get_cam_transform().affine_inverse())
	# Reconstruct a visible pixel in vehicle coordinates. Behind the glass
	# or beyond the silhouette the sampled depth still belongs to the street.
	var local_from_clip := Projection()
	var depth_w := Vector2.ZERO
	if focusing_vehicle:
		local_from_clip = Projection(vehicle_pose.affine_inverse() * scene.get_cam_transform()) * scene.get_cam_projection().inverse()
		depth_w = Vector2(local_from_clip.z.w, local_from_clip.w.w)
	var reprojection := Projection()
	var frame := Engine.get_frames_drawn()
	if frame == previous_frame + 1:
		reprojection = previous_projection * camera_projection.inverse()
	previous_projection = camera_projection
	previous_frame = frame
	for view in views:
		var color := buffers.get_color_layer(view)
		var scratch := buffers.get_texture_slice(BUFFER_CONTEXT, &"color", view, 0, 1, 1)
		var velocity := RDUniform.new()
		velocity.binding = 2
		velocity.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		velocity.add_id(sampler)
		velocity.add_id(buffers.get_velocity_layer(view))
		var depth := RDUniform.new()
		depth.binding = 3
		depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		depth.add_id(sampler)
		depth.add_id(buffers.get_depth_layer(view))
		var blur_set := UniformSetCacheRD.get_cache(shader, 0, [binding(color, 0), binding(scratch, 1), velocity, depth])
		var copy_set := UniformSetCacheRD.get_cache(shader, 0, [binding(scratch, 0), binding(color, 1), velocity, depth])
		var list := device.compute_list_begin()
		device.compute_list_bind_compute_pipeline(list, pipeline)
		for pass_index in 2:
			device.compute_list_bind_uniform_set(list, blur_set if pass_index == 0 else copy_set, 0)
			var values := PackedFloat32Array([strength, float(pass_index), depth_w.x, depth_w.y])
			for col in 4:
				var v: Vector4 = reprojection[col]
				values.append_array(PackedFloat32Array([v.x,v.y,v.z,v.w]))
			for row in 3:
				for col in 4:
					values.append(local_from_clip[col][row])
			var params := values.to_byte_array()
			device.compute_list_set_push_constant(list, params, params.size())
			device.compute_list_dispatch(list, ceili(size.x / 8.), ceili(size.y / 8.), 1)
			if pass_index == 0: device.compute_list_add_barrier(list)
		device.compute_list_end()
