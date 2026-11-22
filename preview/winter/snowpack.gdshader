shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D pack_depth : filter_linear, repeat_disable;
uniform sampler2D pressure : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D grain_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D powder_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform int support;
varying vec2 ground;

float fresh_depth(vec2 p) {
	vec2 uv=(p-vec2(-240.,-136.))/vec2(400.,208.);
	return max(0.,(textureLod(pack_depth,uv,0.)[support]*255.-1.)*(.36/254.));
}
float depth_at(vec2 p,vec2 uv){
	float fresh=fresh_depth(p);
	return fresh-min(fresh*.94,textureLod(pressure,uv,0.).r*.36);
}
void vertex(){
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	vec2 east=normalize(vec2(.873,.488));
	vec2 offset=world.xz-vec2(-208.099,573.891);
	ground=vec2(dot(offset,east),dot(offset,vec2(-east.y,east.x)));
	VERTEX.y+=depth_at(ground,UV);
}
void fragment(){
	float depth=depth_at(ground,UV);
	if(depth<.0018) discard;
	float packed=min(texture(pressure,UV).r*.36,fresh_depth(ground)*.94);
	float firmness=smoothstep(.002,.048,packed);
	// The undisturbed field is sampled every ten inches. Filter its slope
	// over a cell, but keep the higher-frequency edge of the boot imprint.
	float e=.022;
	vec2 slope=vec2(fresh_depth(ground+vec2(.16,0.))-fresh_depth(ground-vec2(.16,0.)),
		fresh_depth(ground+vec2(0.,.16))-fresh_depth(ground-vec2(0.,.16)))/.32;
	float fresh=fresh_depth(ground);
	vec2 du=vec2(e/8.,0.);
	slope-=vec2(min(fresh*.94,texture(pressure,UV+du).r*.36)-min(fresh*.94,texture(pressure,UV-du).r*.36),
		min(fresh*.94,texture(pressure,UV+du.yx).r*.36)-min(fresh*.94,texture(pressure,UV-du.yx).r*.36))/(2.*e);
	vec2 grain=texture(grain_map,ground*.73).rg*2.-1.;
	vec3 n=normalize(vec3(-slope.x+grain.x*.24,1.,-slope.y+grain.y*.24));
	NORMAL=normalize(mat3(VIEW_MATRIX)*mat3(MODEL_MATRIX)*n);
	vec3 powder=texture(powder_map,ground*.73).rgb;
	float crystal=dot(texture(powder_map,ground*3.7).rgb,vec3(.333));
	float snow=smoothstep(.0015,.033,depth+(crystal-.52)*.012);
	vec3 snow_color=mix(powder,vec3(.78,.82,.86),.35)*mix(vec3(.94,.97,1.),vec3(.53,.64,.72),firmness);
	ALBEDO=snow_color;
	ALPHA=snow;
	ROUGHNESS=mix(.34,mix(.89,.60,firmness),snow);
}
