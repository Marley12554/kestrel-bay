shader_type spatial;
render_mode cull_disabled;

// Hanging cloth in a light breeze. The hoist stays on the slanted staff;
// most of the fly length is taken up by gravity and the gathered folds.
vec3 cloth(vec2 uv, float t) {
    float u = uv.x;
    float v = uv.y;
    float ripple = 9.5*u + 1.3*v - t*1.55;
    float spread = 1.92*u - .54*u*u + .09*u*sin(ripple);
    float sag = -1.35*u - 1.23*u*u;
    float folds = sin(13.0*u + 1.15*v + .35*sin(t*1.25));
    return vec3(-1.71 + spread, .90 - 1.80*v + sag + .07*u*cos(ripple),
        -.082*v + .24*u + .27*sin(1.57*u)*folds + .09*u*sin(ripple));
}
void vertex() {
    VERTEX = cloth(UV, TIME);
    vec3 along = cloth(UV+vec2(.001,0.),TIME)-VERTEX;
    vec3 down = cloth(UV+vec2(0.,.001),TIME)-VERTEX;
    NORMAL = normalize(cross(down,along));
}

void fragment(){
	vec3 white=vec3(.88,.86,.80);
	float stripe=UV.y*13.;
	float aa=max(fwidth(stripe),.001);
	float white_band=smoothstep(.5-aa*.5,.5+aa*.5,abs(mod(stripe+.5,2.)-1.));
	vec3 color=mix(vec3(.46,.018,.036),white,white_band);
	if(UV.x<.4 && UV.y<7./13.){
		color=vec3(.018,.041,.13);
		vec2 unit=vec2(.4/12.,(7./13.)/10.);
		vec2 grid=UV/unit;
		float row=clamp(floor(grid.y+.5),1.,9.);
		float first=1.+mod(row+1.,2.);
		float col=clamp(first+2.*floor((grid.x-first)*.5+.5),first,12.-first);
		vec2 d=(grid-vec2(col,row))*unit*vec2(1.9,1.);
		float angle=atan(d.x,-d.y);
		float wedge=abs(mod(angle+.628319,1.256637)-.628319);
		float radius=.022*cos(1.256637)/cos(1.256637-wedge);
		float dist=length(d)-radius;
		float edge=max(fwidth(dist),.0004);
		color=mix(color,white,1.-smoothstep(-edge,edge,dist));
	}
	ALBEDO=color;
	ROUGHNESS=.92;
	EMISSION=color*.14;
}
