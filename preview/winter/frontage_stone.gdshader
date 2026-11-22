shader_type spatial;
uniform sampler2D grain : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D relief : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform bool polished=false;
varying vec3 pos;
varying vec3 face;
void vertex(){
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz-vec3(-208.099,0,573.891);
	vec2 axis=normalize(vec2(.873,.488));
	pos=vec3(dot(world.xz,axis),world.y,dot(world.xz,vec2(-axis.y,axis.x)));
	vec3 n=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	face=vec3(dot(n.xz,axis),n.y,dot(n.xz,vec2(-axis.y,axis.x)));
}
void fragment(){
	vec3 n=abs(face);
	vec2 uv=n.y>.65?pos.xz:(n.x>n.z?vec2(pos.z,pos.y):pos.xy);
	vec2 st=uv*(polished?.78:.26);
	vec3 tex=texture(grain,st).rgb;
	float luma=dot(tex,vec3(.21,.72,.07));
	float vein=clamp(luma*2.25,.18,1.45);
	float runoff=.55+.45*sin(uv.x*2.3+sin(uv.x*5.8)+sin(uv.y*.4)*.12);
	float edge=abs(fract(uv.y/1.11)-.5);
	float joint=smoothstep(.482,.497,edge)*(1.-smoothstep(.02,.1,fwidth(uv.y)));
	ALBEDO=polished?vec3(.055,.061,.061)*(.54+vein*.63):vec3(.62,.55,.43)*(.69+.31*vein)*(.88+.12*runoff)*(1.-joint*.24);
	NORMAL_MAP=texture(relief,st).rgb;
	NORMAL_MAP_DEPTH=polished?.12:.39;
	ROUGHNESS=polished?.24+.08*vein:.75;
	SPECULAR=polished?.82:.37;
}
