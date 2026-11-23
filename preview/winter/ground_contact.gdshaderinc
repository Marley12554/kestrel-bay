// Local sky occlusion remains visible when a building already blocks the sun.
global uniform vec3 sedan_ground_origin;
global uniform vec2 sedan_ground_right;
global uniform vec3 walker_ground_origin;
varying vec3 contact_world;

float ground_occlusion() {
	vec3 delta = contact_world - sedan_ground_origin;
	vec2 forward = vec2(-sedan_ground_right.y, sedan_ground_right.x);
	vec3 under_car = vec3(dot(delta.xz, sedan_ground_right), delta.y, dot(delta.xz, forward));
	vec3 under_walker = contact_world - walker_ground_origin;
	vec2 p = abs(under_car.xz);
	float obscured = 0.0;
	if (p.x < 1.65 && p.y < 2.8) {
		float gap = abs(under_car.y);
		float body = 1.0 - smoothstep(-0.28, 0.55, length(max(p - vec2(0.75, 1.80), 0.0)));
		vec2 tire = (p - vec2(0.81, 1.44)) / vec2(0.36, 0.45);
		float wheels = 1.0 - smoothstep(0.20, 1.0, length(tire));
		obscured = 0.67 * body * (1.0 - smoothstep(0.14, 0.96, gap))
			+ 0.24 * wheels * (1.0 - smoothstep(0.07, 0.29, gap));
	}
	float foot = (1.0 - smoothstep(0.04, 0.40, length(under_walker.xz)))
		* (1.0 - smoothstep(0.04, 0.38, abs(under_walker.y)));
	return max(obscured, 0.43 * foot);
}
