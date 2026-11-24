shader_type sky;

uniform sampler2D street_panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D lunar_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 sky_color : source_color = vec4(0.153, 0.20, 0.278, 1.0);

void sky() {
	if (AT_CUBEMAP_PASS) {
		// The street panorama supplies the city's existing specular environment.
		COLOR = texture(street_panorama, SKY_COORDS).rgb;
	} else {
		COLOR = sky_color.rgb;
		if (LIGHT0_ENABLED) {
			vec3 moon = LIGHT0_DIRECTION;
			float distance_to_moon = length(EYEDIR - moon);
			// Match the apparent diameter of the daytime sun in the wide street camera.
			float radius = radians(1.45) * 0.5;
			float feather = max(fwidth(distance_to_moon) * 0.5, 0.00001);
			if (distance_to_moon < radius + feather) {
				vec3 right = normalize(cross(moon, vec3(0.0, 1.0, 0.0)));
				vec3 up = cross(right, moon);
				vec2 face = vec2(dot(EYEDIR, right), dot(EYEDIR, up)) / sin(radius);
				float depth = sqrt(max(0.0, 1.0 - dot(face, face)));
				vec2 uv = vec2(0.5 + atan(face.x, max(depth, 0.00001)) / TAU,
				               0.5 - asin(clamp(face.y, -1.0, 1.0)) / PI);
				vec3 rock = texture(lunar_albedo, uv).rgb;
				float coverage = 1.0 - smoothstep(radius-feather, radius+feather, distance_to_moon);
				COLOR = mix(COLOR, rock * (2.8 + 0.7 * depth), coverage);
			}
		}
	}
}
