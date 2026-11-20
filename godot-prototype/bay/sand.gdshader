shader_type spatial;
varying vec3 shore;
void vertex(){shore=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
float noise2d(vec2 p){
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.-2.*f);
	vec4 n=fract(sin(dot(i,vec2(37.1,79.3))+vec4(0.,37.1,79.3,116.4))*4375.4);
	return mix(mix(n.x,n.y,f.x),mix(n.z,n.w,f.x),f.y);
}
void fragment(){
	float grain=noise2d(shore.xz*3.5);
	float mottling=noise2d(shore.xz*.52)*.55+grain*.45;
	float dry=smoothstep(.14,.92,shore.y+.20*noise2d(shore.xz*.33));
	ALBEDO=mix(vec3(.18,.14,.092),vec3(.47,.36,.22),dry)*(.78+.34*mottling);
	if(shore.y < -3.1){
		float ribs=sin(shore.x*2.7+sin(shore.z*.72)*1.5+grain*.64);
		float caustic=pow(max(0.,sin(shore.z*1.3+TIME*.65+sin(shore.x*1.7-TIME*.41))),8.);
		ALBEDO=vec3(.14,.24,.21)*(.65+.38*mottling+.2*ribs)+vec3(.055,.16,.14)*caustic;
	}
	ROUGHNESS=mix(.53,.96,dry);
}
