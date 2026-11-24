shader_type spatial;
render_mode cull_disabled;

uniform vec4 pane_tint : source_color;
uniform vec3 room_light;
varying vec3 facade_normal;
void vertex() {
	facade_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	// Trace from the sash into a shallow room. Side walls, ceiling and rear
	// wall move past one another as the player looks up or walks along the bay.
	vec3 eye = mat3(INV_VIEW_MATRIX) * VIEW;
	vec3 along = normalize(cross(vec3(0.,1.,0.), facade_normal));
	float facing = max(abs(dot(eye,facade_normal)), .06);
	vec2 ray = -vec2(dot(eye,along),eye.y) / facing;
	vec2 travel = mix(UV, 1.-UV, step(vec2(0.),ray)) / max(abs(ray),vec2(.001));
	float depth = min(.60,min(travel.x,travel.y));
	vec2 rear = clamp(UV + depth*ray,vec2(0.),vec2(1.));
	float ceiling = step(travel.y, min(.599,travel.x)) * step(0.,ray.y);
	float rear_wall = step(.599,depth);
	float shadow = .55+.42*depth;
	vec3 room = mix(vec3(.55,.48,.39),vec3(.72,.74,.69),ceiling) * shadow;
	float light_strip = ceiling * smoothstep(.018,.038,rear.x) * (1.-smoothstep(.05,.10,abs(rear.x-.48)));
	float edge = smoothstep(.0,.045,min(min(UV.x,1.-UV.x),min(UV.y,1.-UV.y)));
	ALBEDO = pane_tint.rgb * (.34+.40*room+.12*rear_wall) * mix(.70,1.,edge);
	ROUGHNESS = .30;
	METALLIC = 0.;
	SPECULAR = .48;
	EMISSION = room_light * (room + vec3(light_strip)*.8) * edge;
}
