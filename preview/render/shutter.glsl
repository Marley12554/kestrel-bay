#[compute]
#version 450

layout(local_size_x=8, local_size_y=8) in;
layout(set=0, binding=0, rgba16f) uniform readonly image2D source_color;
layout(set=0, binding=1, rgba16f) uniform writeonly image2D destination;
layout(set=0, binding=2) uniform sampler2D velocity_buffer;
layout(set=0, binding=3) uniform sampler2D depth_buffer;
layout(push_constant, std430) uniform Settings {
	float shutter;
	float copy_only;
	vec2 depth_w;
	mat4 previous_from_current;
	vec4 vehicle_rows[3];
} settings;

vec2 pixel_motion(ivec2 pixel, ivec2 size) {
	vec2 velocity = texelFetch(velocity_buffer, pixel, 0).rg;
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	float depth = texelFetch(depth_buffer, pixel, 0).r;
	vec4 clip = vec4(uv*2.0-1.0, depth, 1.0);
	float w = dot(settings.depth_w, vec2(depth, 1.0));
	if (w > 0.0) {
		vec3 p = vec3(dot(settings.vehicle_rows[0], clip), dot(settings.vehicle_rows[1], clip),
			dot(settings.vehicle_rows[2], clip)) / w;
		if (abs(p.x)<1.13 && p.y>-.13 && p.y<1.59 && abs(p.z)<2.43) return vec2(0.0);
	}
	// Some renderer passes omit static geometry from the velocity target.
	// Reproject its actual depth between the two camera transforms.
	if (length(velocity) < 0.00001 || all(lessThanEqual(velocity, vec2(-0.99)))) {
		vec4 previous = settings.previous_from_current * clip;
		if (previous.w > 0.0001) velocity = previous.xy / previous.w * 0.5 + 0.5 - uv;
	}
	return velocity * vec2(size);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(source_color);
	if (any(greaterThanEqual(pixel, size))) return;
	vec4 center = imageLoad(source_color, pixel);
	if (settings.copy_only > 0.5) { imageStore(destination, pixel, center); return; }
	vec2 motion = pixel_motion(pixel, size);
	float speed = length(motion);
	if (speed * settings.shutter < 1.0 || speed > size.x * 0.18) {
		imageStore(destination, pixel, center);
		return;
	}
	// A short, centered shutter. Reject unrelated foreground/background
	// velocities so a passing cab doesn't drag the shop window along with it.
	vec2 trail = motion * min(settings.shutter, 18.0 / speed);
	float depth = texelFetch(depth_buffer, pixel, 0).r;
	vec4 sum = center;
	float total = 1.0;
	for (int i = -3; i <= 3; i++) {
		if (i == 0) continue;
		ivec2 q = clamp(ivec2(round(vec2(pixel) + trail * (float(i)/6.0))), ivec2(0), size-1);
		vec2 local_motion = pixel_motion(q, size);
		float sample_depth = texelFetch(depth_buffer, q, 0).r;
		if (abs(sample_depth-depth) > 0.05 * max(depth, 0.00001)) continue;
		float weight = 1.0 - smoothstep(1.0, 2.0 + 0.35*speed, length(local_motion-motion));
		sum += imageLoad(source_color, q) * weight;
		total += weight;
	}
	imageStore(destination, pixel, sum/total);
}
