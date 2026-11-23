shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
#include "res://winter/ground_contact.gdshaderinc"

uniform sampler2D pack_depth : filter_linear, repeat_disable;
uniform sampler2D pressure : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D grain_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D powder_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_tracks = false;
uniform int support;
uniform float support_plane;
uniform sampler2D grade_base : filter_nearest, repeat_disable;
uniform sampler2D grade_curb : filter_nearest, repeat_disable;
uniform vec2 grade_origin;

float support_height(vec2 world, float legacy) {
	vec2 p=(world-grade_origin)*vec2(1.,-1.);
	ivec2 cell=ivec2(floor(p));
	ivec2 extent=textureSize(grade_base,0)-1;
	if(any(lessThan(cell,ivec2(0))) || any(greaterThanEqual(cell,extent))) return legacy;
	float a=texelFetch(grade_base,cell,0).r, b=texelFetch(grade_base,cell+ivec2(1,0),0).r;
	float c=texelFetch(grade_base,cell+ivec2(0,1),0).r, d=texelFetch(grade_base,cell+ivec2(1,1),0).r;
	vec2 f=fract(p);
	float curb=textureLod(grade_curb,p/vec2(extent),0.).r*2.55;
	return a+(b-a)*f.x+(d-b)*f.y+max(f.y-f.x,0.)*(c-a-d+b)+curb;
}
varying vec2 ground;

float fresh_depth(vec2 p) {
	vec2 uv=(p-vec2(-240.,-136.))/vec2(400.,208.);
	return max(0.,(textureLod(pack_depth,uv,0.)[support]*255.-1.)*(.36/254.));
}
float compression(float fresh, vec2 uv){
	return min(fresh*.94,textureLod(pressure,uv,0.).r*.36);
}
void vertex(){
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	vec2 east=normalize(vec2(.873,.488));
	vec2 offset=world.xz-vec2(-208.099,573.891);
	ground=vec2(dot(offset,east),dot(offset,vec2(-east.y,east.x)));
	float fresh=fresh_depth(ground);
	VERTEX.y+=support_height(world.xz,support_plane)-support_plane+fresh;
	if(has_tracks) VERTEX.y-=compression(fresh,UV);
	contact_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
}
void fragment(){
	float fresh=fresh_depth(ground);
	float packed=has_tracks ? compression(fresh,UV) : 0.;
	float depth=fresh-packed;
	if(depth<.0018) discard;
	float firmness=smoothstep(.002,.048,packed);
	// The undisturbed field is sampled every ten inches. Filter its slope
	// over a cell, but keep the higher-frequency edge of the boot imprint.
	vec2 slope=vec2(fresh_depth(ground+vec2(.16,0.))-fresh_depth(ground-vec2(.16,0.)),
		fresh_depth(ground+vec2(0.,.16))-fresh_depth(ground-vec2(0.,.16)))/.32;
	if(has_tracks){
		float e=.022;
		vec2 du=vec2(e/8.,0.);
		slope-=vec2(compression(fresh,UV+du)-compression(fresh,UV-du),
			compression(fresh,UV+du.yx)-compression(fresh,UV-du.yx))/(2.*e);
	}
	vec2 grain=texture(grain_map,ground*.73).rg*2.-1.;
	vec3 n=normalize(vec3(-slope.x+grain.x*.24,1.,-slope.y+grain.y*.24));
	NORMAL=normalize(mat3(VIEW_MATRIX)*mat3(MODEL_MATRIX)*n);
	vec3 powder=texture(powder_map,ground*.73).rgb;
	float crystal=dot(texture(powder_map,ground*3.7).rgb,vec3(.333));
	float snow=smoothstep(.0015,.033,depth+(crystal-.52)*.012);
	vec3 snow_color=mix(powder,vec3(.78,.82,.86),.35)*mix(vec3(.94,.97,1.),vec3(.53,.64,.72),firmness);
	float contact=ground_occlusion();
	AO=1.0-contact;
	ALBEDO=snow_color*(1.0-0.30*contact);
	ALPHA=snow;
	ROUGHNESS=mix(.34,mix(.89,.60,firmness),snow);
}
