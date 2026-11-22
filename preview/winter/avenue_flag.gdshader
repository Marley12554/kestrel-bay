shader_type spatial;
render_mode cull_disabled;

void vertex(){
	float fly=UV.x;
	float phase=fly*8.4-TIME*2.35;
	float crosswave=fly*13.8+UV.y*1.6-TIME*3.6;
	VERTEX.z+=fly*(.29*sin(phase)+.10*sin(crosswave));
	VERTEX.y+=fly*(-.24+.075*sin(phase+UV.y));
	float dzdx=(.29*sin(phase)+.10*sin(crosswave)+fly*(2.436*cos(phase)+1.38*cos(crosswave)))/3.42;
	NORMAL=normalize(vec3(-dzdx,fly*.089*cos(crosswave),1.));
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
