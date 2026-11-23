shader_type spatial;
render_mode cull_disabled;

// Quad UVs span each moving wing. The fixed screens have no door marking.
void fragment() {
	float grazing = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	ALBEDO = mix(vec3(0.15, 0.28, 0.32), vec3(0.46, 0.61, 0.65), grazing);
	METALLIC = 0.18;
	ROUGHNESS = 0.15;
	ALPHA = mix(0.22, 0.54, grazing);
	// A small etched tower medallion at eye level reads on either face.
	vec2 p = (UV - vec2(0.60, 0.40)) * vec2(1.05, 2.37);
	float aa = max(0.0005, fwidth(length(p)));
	float ring = 1.0 - smoothstep(0.002, 0.002 + aa, abs(length(p) - 0.064));
	float half_width = p.y > 0.020 ? 0.032 : (p.y > -0.019 ? 0.018 : (p.y > -0.037 ? 0.009 : 0.003));
	float tower = (1.0 - smoothstep(half_width, half_width + aa, abs(p.x))) *
		smoothstep(-0.054-aa, -0.054, p.y) * (1.0-smoothstep(0.038, 0.038+aa, p.y));
	float etch = max(ring, tower);
	ALBEDO = mix(ALBEDO, vec3(0.73, 0.78, 0.78), etch);
	EMISSION = vec3(0.018, 0.035, 0.046) * (0.55 + grazing);
	ALPHA = mix(ALPHA, 0.76, etch);
}
