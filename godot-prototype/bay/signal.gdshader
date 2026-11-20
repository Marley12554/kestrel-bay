shader_type spatial;
render_mode unshaded, cull_disabled;
global uniform float kb_traffic_clock;
uniform sampler2D stop_face : source_color, filter_linear_mipmap;
void fragment(){
	if(UV2.y<0.0){
		vec4 sign_color=texture(stop_face,UV);
		if(sign_color.a<0.5) discard;
		ALBEDO=sign_color.rgb;
	}else{
		float phase=mod(kb_traffic_clock+UV2.x,24.0);
		float active=phase<9.0?2.0:(phase<11.0?1.0:0.0);
		if(distance(UV,vec2(.5))>.48) discard;
		ALBEDO=abs(active-UV2.y)<.1?COLOR.rgb:COLOR.rgb*.09;
	}
}
