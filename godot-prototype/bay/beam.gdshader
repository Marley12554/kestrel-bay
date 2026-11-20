shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	ALBEDO = vec3(.84, .87, .73);
	ALPHA = .024 * (1.0 - smoothstep(.45, 1.0, UV.y)) * (.18 + .82 * rim);
}
