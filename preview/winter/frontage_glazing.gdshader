shader_type spatial;
render_mode cull_disabled,shadows_disabled;
varying vec3 pos;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	vec3 n=normalize(NORMAL);
	float grazing=pow(1.-abs(dot(n,normalize(VIEW))),3.);
	float pane_wave=sin(pos.y*1.3+pos.x*.7)*sin(pos.z*.59+pos.x*.61);
	vec2 edge=min(UV,1.-UV);
	float rim=1.-smoothstep(.001,.024,min(edge.x,edge.y));
	ALBEDO=mix(vec3(.095,.155,.165),vec3(.22,.25,.245),rim*.35);
	NORMAL=normalize(n+mat3(VIEW_MATRIX)*vec3(.003*pane_wave, .002*sin(pos.y*.7+pos.z),0.));
	ROUGHNESS=.068+.025*pane_wave+.075*rim;
	SPECULAR=.75;
	METALLIC=.13+.36*grazing;
	ALPHA=.14+.57*grazing+.06*rim;
}
