shader_type spatial;
render_mode cull_disabled;
global uniform vec3 kb_eye;
global uniform float kb_dark;
varying vec3 place;
void vertex() {
	place=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(17.13,47.7)))*4375.4); }
void fragment() {
	float floor_no=floor((UV.y+.002)/3.8);
	float level=mod(UV.y+.002,3.8);
	bool entrance=UV2.y>.5 && UV2.y<1.5;
	bool bay=UV2.y>.5 && abs(UV.x)<1.68;
	float d=distance(place,kb_eye);
	if (bay && (d<17.0 || !FRONT_FACING) && ((entrance && floor_no<.5 && level<3.05) || (level>.42 && level<3.05))) {discard;}
	float architecture=floor(UV2.x/1000.0);
	float seed=mod(UV2.x,1000.);
	bool curtain=architecture==1.0;
	bool deco=architecture==2.0;
	bool workshop=architecture==3.0;
	float span=curtain?2.12:(workshop?4.6:2.55+fract(seed*.013)*.7);
	float bay_x=fract((UV.x+span*.5)/span);
	float aa=max(.004,fwidth(UV.x/span));
	float edge=smoothstep(.12-aa,.12+aa,bay_x)*(1.-smoothstep(.88-aa,.88+aa,bay_x));
	float pane=edge*smoothstep(.72,.85,level)*(1.-smoothstep(2.94,3.07,level));
	if(curtain){pane=smoothstep(.025-aa,.05+aa,bay_x)*(1.-smoothstep(.95-aa,.975+aa,bay_x))*smoothstep(.23,.34,level)*(1.-smoothstep(3.48,3.62,level));}
	if(workshop){pane=edge*smoothstep(1.12,1.25,level)*(1.-smoothstep(2.95,3.06,level));}
	if(entrance && floor_no<.5){pane=max(pane,edge*smoothstep(.31,.39,level)*(1.-smoothstep(2.55,2.67,level)));}
	float brick=mod(floor(UV.y/.31),2.0)*.39;
	float mortar=smoothstep(.025,.055,mod(UV.y,.31))*smoothstep(.025,.06,mod(UV.x+brick,.78));
	vec3 stone=COLOR.rgb*mix(.85,1.0,mix(1.,mortar,1.-smoothstep(18.,100.,d)));
	if(deco) stone*=.84+.22*smoothstep(.16,.25,abs(bay_x-.5));
	if(!curtain && !workshop) stone*=1.+.22*(1.-smoothstep(.09,.19,abs(level-.68)))*edge;
	float noise=hash(vec2(floor(UV.x/span+.5)+UV2.x,floor_no));
	float sky=.5+.5*sin(UV.x*.026+place.z*.009+VIEW.x*.6);
	vec3 glass=mix(vec3(.055,.105,.135),vec3(.24,.36,.4),sky*.6+noise*.23);
	if(curtain){
		float horizon=smoothstep(-.4,.6,VIEW.y);
		glass=mix(vec3(.057,.13,.17),vec3(.31,.51,.59),horizon);
		glass*=.82+.18*smoothstep(.04,.89,fract(UV.x*.019+place.z*.011));
	}
	float lit=step(.72,noise)*kb_dark;
	glass=mix(glass,vec3(.99,.89,.52),lit*.85);
	float mullion=1.-smoothstep(.018,.038,abs(bay_x-.5));
	float sash=1.-smoothstep(.025,.07,abs(level-2.46));
	glass=mix(glass,stone*.64,max(mullion,sash)*.84);
	ALBEDO=mix(stone,glass,pane);
	ROUGHNESS=mix(.86,curtain?.21:.39,pane);
	EMISSION=pane*lit*vec3(3.8,2.65,.64)*(1.-.76*max(mullion,sash));
}
