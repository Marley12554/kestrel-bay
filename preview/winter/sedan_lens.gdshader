shader_type spatial;
render_mode cull_disabled;

uniform vec4 lens_color : source_color;
uniform float lens_roughness : hint_range(0.0, 1.0);
uniform float lens_metallic : hint_range(0.0, 1.0);
uniform bool amber_lens = false;
uniform bool headlights_on = false;
uniform int flashing_side = 0;
uniform vec4 headlight_color : source_color = vec4(0.89, 0.94, 1.0, 1.0);
uniform vec4 signal_color : source_color = vec4(1.0, 0.59, 0.045, 1.0);

varying vec2 model_position;

void vertex() {
	// The imported mesh uses +X for the nose and increasing Y toward the left.
	model_position = VERTEX.xy;
}

void fragment() {
	ALBEDO = lens_color.rgb;
	ROUGHNESS = lens_roughness;
	METALLIC = lens_metallic;

	if (amber_lens) {
		int side = model_position.y > -9.93 ? -1 : 1;
		if (side == flashing_side) {
			EMISSION = signal_color.rgb * 3.0;
		}
	} else if (headlights_on && model_position.x > 1.0) {
		// The same white material is also used on pieces of the interior.
		EMISSION = headlight_color.rgb * 2.5;
	}
}
