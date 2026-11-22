shader_type spatial;
varying vec3 local_pos;
varying vec3 face;
void vertex(){
	vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz-vec3(-208.099,0.,573.891);
	vec2 axis=normalize(vec2(.873,.488));
	local_pos=vec3(dot(p.xz,axis),p.y,dot(p.xz,vec2(-axis.y,axis.x)));
	face=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
	float horizontal=abs(dot(normalize(face.xz+vec2(.00001)),normalize(vec2(.873,.488))))>.7?local_pos.z:local_pos.x;
	vec2 grid=vec2(horizontal/.21,local_pos.y/.064);
	vec2 cell=vec2(grid.x+.5*mod(floor(grid.y),2.),grid.y);
	float seed=fract(sin(dot(floor(cell),vec2(12.98,37.31)))*4375.1);
	vec2 edge=min(fract(cell),1.-fract(cell));
	vec2 aa=max(fwidth(grid),vec2(.001));
	vec2 brick=smoothstep(-aa,aa,edge-vec2(.019,.050));
	float near_weight=1.-smoothstep(.14,.9,max(aa.x,aa.y));
	vec3 clay=mix(vec3(.47,.32,.222),vec3(.62,.465,.33),seed);
	vec3 base=mix(vec3(.37,.296,.224),clay,brick.x*brick.y);
	ALBEDO=mix(vec3(.535,.392,.277),base,near_weight);
	ROUGHNESS=.89;
}
