shader_type spatial;
uniform sampler2D grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool raised_face = false;
varying vec3 block_pos;
varying vec3 face_normal;
void vertex(){
	vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz-vec3(-208.099,0.,573.891);
	vec2 axis=normalize(vec2(.873,.488));
	block_pos=vec3(dot(p.xz,axis),p.y,dot(p.xz,vec2(-axis.y,axis.x)));
	face_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
	vec2 axis=normalize(vec2(.873,.488));
	bool fifth=abs(dot(normalize(face_normal).xz,axis))>.7;
	float along=fifth?block_pos.z-11.5:block_pos.x-96.23;
	vec2 wall=vec2(along,block_pos.y);
	vec2 grid=wall/vec2(.21,.064);
	grid.x+=.5*mod(floor(grid.y),2.);
	vec2 cell=floor(grid);
	float seed=fract(sin(dot(mod(cell,256.),vec2(12.98,37.31)))*4375.1);
	vec2 edge=min(fract(grid),1.-fract(grid));
	vec2 aa=max(fwidth(wall)/vec2(.21,.064),vec2(.001));
	vec2 bond=smoothstep(vec2(.004)/vec2(.21,.064)-aa,vec2(.004)/vec2(.21,.064)+aa,edge);
	float clay=raised_face?1.:bond.x*bond.y;
	float pore=texture(grain,wall*2.4).r;
	float dust=texture(grain,wall*.22).g;
	vec3 fired=mix(vec3(.36,.219,.133),vec3(.57,.395,.249),seed);
	float detail=1.-smoothstep(.35,1.1,max(aa.x,aa.y));
	ALBEDO=mix(vec3(.425,.31,.227),mix(vec3(.29,.252,.209),fired,clay),detail)*(.81+.24*pore+.10*dust);
	ROUGHNESS=clamp(.91-.13*clay+.14*(.5-pore),.65,.98);
}
