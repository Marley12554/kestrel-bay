shader_type spatial;
render_mode cull_disabled;
uniform bool brick = true;
uniform sampler2D bond : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 surface;
varying vec3 normal_world;
void vertex() {
	surface = VERTEX;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 n = normalize(normal_world);
	bool horizontal = abs(n.y) > .82;
	vec3 along = horizontal ? vec3(1.,0.,0.) : normalize(vec3(n.z,0.,-n.x));
	vec3 up = horizontal ? vec3(0.,0.,1.) : vec3(0.,1.,0.);
	vec2 p = vec2(dot(surface,along), dot(surface,up));
	float mineral = texture(grain,p*.32).g;
	vec2 bump = texture(relief,p*.43).xy * 2. - 1.;
	if (brick) {
		// Both tone and joint relief are integrated over the same pixel footprint.
		vec3 fired = texture(bond, p / vec2(2.496,1.296)).rgb;
		float patch = texture(grain,p*.071).r;
		ALBEDO = mix(vec3(.17,.129,.087),vec3(.63,.445,.265),fired.r)
			* (.78 + .28 * mineral + .23 * patch);
		bump = fired.gb * 2. - 1. + bump * .10;
		ROUGHNESS = .87;
	} else {
		vec2 cell = p / vec2(1.52,.91);
		vec2 footprint = max(fwidth(cell),vec2(.001));
		cell.x += .5 * mod(floor(cell.y),2.);
		vec2 edge = .5 - abs(fract(cell)-.5);
		vec2 seam = (1.-smoothstep(vec2(.003)-.5*footprint,vec2(.006)+.5*footprint,edge))
			* (1.-smoothstep(vec2(.06),vec2(.4),footprint));
		ALBEDO = vec3(.65,.55,.405) * (.76 + .42*mineral) * (1.-.24*max(seam.x,seam.y));
		bump *= .055;
		ROUGHNESS = .74;
	}
	NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * (along*bump.x + up*bump.y));
}
