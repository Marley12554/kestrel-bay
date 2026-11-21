shader_type spatial;
varying vec3 site;
varying vec3 tint;
void vertex(){
	vec3 p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz-vec3(-208.099,0.,573.891);
	site=vec3(dot(p.xz,vec2(.873,.488)),p.y,dot(p.xz,vec2(-.488,.873)));
	tint=COLOR.rgb;
}
float grain(vec2 p){return fract(sin(dot(mod(p,781.),vec2(17.17,93.72)))*4293.32);}
void fragment(){
	vec2 p=vec2(site.x+site.z,site.y);
	float y=site.y/.76;
	float x=(p.x+.79*mod(floor(y),2.)) / 1.61;
	vec2 edges=abs(fract(vec2(x,y))-.5);
	float line=smoothstep(.482,.499,max(edges.x,edges.y));
	float stone=step(.30,min(tint.r,min(tint.g,tint.b)));
	float block=grain(floor(vec2(x,y)));
	float texture_weight=1.-smoothstep(.015,.08,length(fwidth(p)));
	float fleck=(grain(floor(p*175.))-.5)*texture_weight;
	ALBEDO=tint*mix(1.,(.94+.08*block+.09*fleck)*(1.-.24*line),stone);
	ROUGHNESS=mix(.49,.76,stone);
	if(tint.b>tint.r*1.25 && site.y>4.0){
		float lit=step(.62,grain(floor(vec2(p.x/3.04,site.y/3.3))));
		EMISSION=lit*vec3(.26,.163,.092);
		ROUGHNESS=.22;
	}
}
