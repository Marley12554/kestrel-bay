shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// The exterior reads in reflection at a shallow angle. A cooler transmitted
// tint and two small rows of frosted safety dots also identify a closed pane
// when the bright shop interior dominates the view from the sidewalk.
uniform float floor_y = 0.;
varying float height;
void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - floor_y;
}
void fragment() {
	float angle = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float reflectance = pow(clamp(angle, 0., 1.), 2.2);
	vec2 edge = min(UV, 1.0 - UV);
	float gasket = 1.0 - smoothstep(.002, .015, min(edge.x, edge.y));
	float stripe = min(abs(height - 1.26), abs(height - 1.31));
	vec2 p = vec2((fract(UV.x * 10.) - .5) * .12, stripe);
	float d = length(p);
	float aa = max(.0005, fwidth(d));
	float dots = 1.0 - smoothstep(.011-aa, .011+aa, d);
	float band = 1.0 - smoothstep(.009, .012, abs(height - 1.285));
	float frit = max(dots, .65 * band);
	ALBEDO = mix(vec3(.14,.24,.265), vec3(.69,.73,.71), frit);
	ROUGHNESS = .16 + .16*gasket + .34*frit;
	SPECULAR = .65;
	METALLIC = .18 + .36*reflectance;
	EMISSION = vec3(.018,.039,.047) * (.38 + reflectance) + vec3(.19)*frit;
	ALPHA = mix(.43 + .32*reflectance + .07*gasket, .78, frit);
}
