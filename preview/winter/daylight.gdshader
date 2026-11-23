shader_type sky;

uniform vec4 zenith : source_color = vec4(0.28, 0.49, 0.76, 1.0);
uniform vec4 horizon : source_color = vec4(0.76, 0.83, 0.88, 1.0);
uniform vec4 ground : source_color = vec4(0.34, 0.34, 0.35, 1.0);

void sky() {
	float height = EYEDIR.y;
	COLOR = mix(horizon.rgb, height > 0.0 ? zenith.rgb : ground.rgb, sqrt(abs(height)));
	if (LIGHT0_ENABLED) {
		// Chord length stays precise at small angles.
		float separation = length(EYEDIR - LIGHT0_DIRECTION);
		float aureole = exp(-separation * 23.0);
		COLOR += LIGHT0_COLOR * (0.27 * aureole);
		if (!AT_CUBEMAP_PASS) {
			// Surfaces get the direct sun from the shadowed light. Baking the
			// disk into skylight as well would put a second sun in the shade.
			float edge = max(fwidth(separation), 0.0001) * 0.5;
			// Enlarge the apparent disk for the wide street camera. The light
			// itself still controls surface reflections and shadow softness.
			float radius = radians(1.45) * 0.5;
			float disk = 1.0 - smoothstep(radius - edge, radius + edge, separation);
			float glare = exp(-max(separation - radius, 0.0) * 105.0);
			COLOR += LIGHT0_COLOR * LIGHT0_ENERGY * (6.0 * disk + 1.1 * glare + 0.38 * aureole * aureole);
		}
	}
}
