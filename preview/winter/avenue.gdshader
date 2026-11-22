shader_type spatial;
render_mode cull_disabled;
uniform sampler2D snow_depth : filter_linear, repeat_enable;
uniform sampler2D asphalt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_rough : filter_linear_mipmap, repeat_enable;
uniform sampler2D snow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float sprint_softness = 0.0;
varying vec3 street;
varying vec3 direction;
float hash(vec2 p) { return fract(sin(mod(dot(p,vec2(57.13,97.37)),6.28318))*4375.13); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);
}
void vertex() {
	vec3 p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz-vec3(-208.099,0,573.891);
	street=vec3(dot(p.xz,vec2(.873,.488)),p.y,dot(p.xz,vec2(-.488,.873)));
	direction=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 p=street; vec3 base=COLOR.rgb;
	if(abs(direction.y)>.68 && p.y<1.0){
		vec2 uv=p.xz*.54;
		float bias=sprint_softness*smoothstep(.38,1.,length(SCREEN_UV*2.-1.));
		float drift=texture(snow_depth,p.xz/64.0).r;
		bool road=p.y<.09 && base.r<.3;
		float lateral=abs(p.x-81.)<9.0?p.x:p.z+45.8;
		float wheel=abs(mod(lateral+.12*sin(p.z*.07+p.x*.09),3.85)-1.925);
		float tracks=1.-smoothstep(.14,.53,abs(wheel-.78));
		float cover=road?smoothstep(.57,.83,drift-tracks*.27):smoothstep(.17,.47,drift);
		vec3 grit=texture(asphalt,uv,bias).rgb;
		vec3 powder=texture(snow,uv*.65,bias).rgb;
		float water=(1.-smoothstep(.21,.65,drift))*.74+tracks*.23;
		vec3 substrate=road?grit*.26:mix(grit*.67,vec3(.21,.20,.19),.44);
		vec2 seam=abs(fract(p.xz/1.63)-.5);
		if(!road) substrate*=1.-.6*smoothstep(.486,.5,max(seam.x,seam.y));
		ALBEDO=mix(substrate*(1.-.40*water),powder*vec3(.91,.94,.99),cover);
		ROUGHNESS=mix(mix(texture(asphalt_rough,uv,bias).r*.67+.10,.13,water),.84,cover);
		vec3 bump=mix(texture(asphalt_normal,uv,bias).rgb,texture(snow_normal,uv*.65,bias).rgb,cover)*2.-1.;
		vec3 wx=vec3(.873,0,.488),wz=vec3(-.488,0,.873);
		NORMAL=normalize((VIEW_MATRIX*vec4(normalize(vec3(0,1,0)+(wx*bump.x+wz*bump.y)*.45),0)).xyz);
	} else if(abs(direction.y)<.70) {
		float along=abs(dot(direction.xz,vec2(.873,.488)))>.7?p.z:p.x;
		vec2 bay=vec2(along/2.66,(p.y-.52)/3.55), cell=floor(bay), q=fract(bay);
		vec2 aa=clamp(fwidth(bay),.001,.22);
		float fade=1.-smoothstep(.08,.28,max(aa.x,aa.y));
		vec2 edge=abs(q-.5); vec2 opening=1.-smoothstep(vec2(.315,.313)-aa,vec2(.315,.313)+aa,edge);
		float pane=opening.x*opening.y*fade;
		float rail=smoothstep(.012,.037,abs(q.x-.5))*smoothstep(.012,.033,abs(q.y-.58));
		float lit=smoothstep(.56,.75,hash(cell+floor(p.xz*.009)));
		float blinds=step(.73,hash(cell+1.71))*step(.57,q.y);
		vec3 room=mix(vec3(.62,.36,.16),vec3(.45,.53,.57),hash(cell+.8));
		float joints=smoothstep(.014,.045,abs(fract(p.y/.83)-.5));
		ALBEDO=mix(base*(.63+.13*noise(vec2(along,p.y)*1.65))*(.74+.26*joints),vec3(.055,.081,.092),pane);
		EMISSION=room*pane*rail*lit*(.29+.55*q.y)*(1.-.75*blinds);
		ROUGHNESS=mix(.8,.23,pane);
	} else { ALBEDO=mix(base,vec3(.64,.71,.81),.7); ROUGHNESS=.83; }
}
