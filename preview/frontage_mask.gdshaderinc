// Survey coordinates in the block's Fifth Avenue frame. Only the old vertical
// surface inside the replacement base is clipped; roof and setback walls remain.
bool modeled_empire_base(vec3 p,vec3 n){
	if(abs(n.y)>.32 || p.y>26.29) return false;
	bool front=p.x>64.40 && p.x<65.25 && p.z>=-30.18 && p.z<=28.74;
	bool corner=p.z>28.41 && p.z<29.36 && p.x>=32.54 && p.x<65.25;
	return front||corner;
}

// The set-back office shaft carries paired sashes between continuous limestone
// piers. Its distant finish follows the same storey spacing all around the shaft.
bool empire_shaft(vec3 p,vec3 n){
	return p.x>-84. && p.x<65.3 && p.z>-30.3 && p.z<29.3 && p.y>=25.18 && abs(n.y)<.5;
}
vec3 shaft_surface(vec3 p,vec3 n,out float glazing,out float lit){
	float along=abs(dot(n.xz,vec2(.873,.488)))>.7?p.z:p.x;
	vec2 uv=vec2((along+.75)/5.85,(p.y-25.21)/3.72);
	vec2 q=fract(uv), fw=min(fwidth(uv),vec2(.18));
	float bay=abs(q.x-.5);
	float strip=1.-smoothstep(.293-fw.x,.293+fw.x,bay);
	float center=smoothstep(.020-fw.x,.020+fw.x,bay);
	float vent=step(.65,q.y);
	float rail=smoothstep(.013,.03,abs(q.y-.38));
	glazing=strip*center*(1.-vent)*rail;
	float recess=1.-smoothstep(.31-fw.x,.33+fw.x,bay);
	float groove=smoothstep(.465-fw.x,.48+fw.x,bay);
	vec3 limestone=vec3(.51,.46,.37)*(.86+.12*groove);
	vec3 backing=mix(vec3(.085,.093,.095),vec3(.20,.23,.24),vent*step(.45,fract(q.x*42.)));
	lit=glazing*step(.65,fract(sin(dot(floor(uv),vec2(12.31,37.1)))*1341.3));
	return mix(mix(limestone,backing,recess),vec3(.11,.15,.17),glazing);
}
