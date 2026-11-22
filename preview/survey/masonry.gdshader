shader_type spatial;
render_mode cull_disabled;
uniform bool brick = true;
uniform sampler2D grain : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D relief : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 surface;
varying vec3 normal_world;
void vertex() {
	surface = VERTEX;
	normal_world = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 n = normalize(normal_world);
	vec3 tangent = normalize(vec3(n.z,0.0,-n.x) + vec3(0.0,0.0,.00001));
	vec2 p = abs(n.y)>.82 ? surface.xz : vec2(dot(surface,tangent),surface.y);
	vec3 texel = texture(grain,p*(brick?.6:.32)).rgb;
	float grain_value = clamp(dot(texel,vec3(.21,.72,.07))*1.9,.4,1.45);
	vec2 cell = p / (brick ? vec2(.208,.072) : vec2(1.52,.91));
	cell.x += .5*mod(floor(cell.y),2.);
	vec2 edge = abs(fract(cell)-.5);
	vec2 aa = max(fwidth(cell),vec2(.001));
	vec2 seams = smoothstep(vec2(.465)-aa*.45,vec2(.494)+aa*.45,edge);
	float joint=max(seams.x,seams.y)*(1.-smoothstep(.18,.7,max(aa.x,aa.y)));
	vec3 stock = brick?vec3(.51,.395,.275):vec3(.65,.55,.405);
	ALBEDO=stock*mix(.77,1.1,grain_value)*mix(1.,.68,joint);
	vec2 bump=texture(relief,p*.43).xy*2.-1.;
	vec3 micro=tangent*bump.x+vec3(0.,1.,0.)*bump.y;
	NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX)*micro*(brick?.11:.055));
	ROUGHNESS=brick?.84:.74;
}
