shader_type spatial;
varying float height;
void vertex(){
	height=(MODEL_MATRIX*vec4(VERTEX,1.)).y;
}
void fragment(){
	float y=height*17.;
	float slat=cos(y*6.283185)*(1.-smoothstep(.12,.5,fwidth(y)));
	ALBEDO=vec3(.45,.40,.31)*(1.+.16*slat);
	EMISSION=vec3(.23,.16,.086)*(1.+.22*slat);
	ROUGHNESS=.88;
}
