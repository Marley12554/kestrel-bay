shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount : hint_range(0.0, 1.0);
void fragment() {
	vec2 radial = SCREEN_UV * 2.0 - 1.0;
	float edge = smoothstep(0.38, 1.0, length(radial));
	vec2 shift = normalize(radial + vec2(0.00001)) * SCREEN_PIXEL_SIZE * (1.25 * edge * amount);
	vec3 center = texture(scene, SCREEN_UV).rgb;
	COLOR = vec4(center * 0.70 + 0.15 * (texture(scene, SCREEN_UV + shift).rgb + texture(scene, SCREEN_UV - shift).rgb), 1.0);
}
