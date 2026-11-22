shader_type spatial;
render_mode cull_disabled;
#include "res://frontage_mask.gdshaderinc"
varying vec3 street;
varying vec3 face;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz - vec3(-208.099,0.0,573.891);
	street = vec3(dot(world.xz, vec2(.8729,.4879)),world.y,dot(world.xz, vec2(-.4879,.8729)));
	face = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	if(modeled_empire_base(street,face) || demarest_wall(street,face)) discard;
	vec3 base = COLOR.rgb;
	float near_block = 1.0-smoothstep(180.0,360.0,length(street.xz));
	if(COLOR.a<.9){
		base=COLOR.rgb;
	} else if(empire_shaft(street,face)){
		float glass,lit;
		base=shaft_surface(street,face,glass,lit);
	} else if (near_block > .001 && abs(face.y) < .65 && street.y > .24) {
		float along = abs(dot(face.xz,vec2(.873,.488)))>.65 ? street.z : street.x;
		vec2 bay=vec2(along/2.65,street.y/3.75);
		vec2 p=abs(fract(bay)-.5);
		vec2 aa=max(fwidth(bay),vec2(.001));
		float glass=(1.0-smoothstep(.285-aa.x,.285+aa.x,p.x))*(1.0-smoothstep(.317-aa.y,.317+aa.y,p.y));
		float detail=near_block*(1.0-smoothstep(.08,.4,max(aa.x,aa.y)));
		float rib=smoothstep(.39,.48,p.x);
		vec3 stone=mix(base,vec3(.48,.43,.345),.45)*(.93+.12*rib);
		float blinds=step(.82,fract(sin(dot(floor(bay),vec2(12.37,7.63)))*2374.51));
		vec3 window=mix(vec3(.083,.15,.185),vec3(.38,.33,.234),blinds);
		float bar=1.0-smoothstep(.006,.029,abs(fract(bay.y)-.55));
		base=mix(base,mix(stone,mix(window,vec3(.18,.14,.12),bar),glass),detail);
	} else if(near_block>.001 && face.y>.7 && street.y>4.0) {
		base=mix(base,vec3(.79,.84,.85),.69*near_block);
	}
	ALBEDO=base;
	ROUGHNESS=.88;
}
