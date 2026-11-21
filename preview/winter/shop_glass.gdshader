shader_type spatial;
uniform sampler2D interior : filter_linear_mipmap, repeat_enable;
uniform float variation = 0.0;
varying vec3 pane_pos;
void vertex(){ pane_pos=VERTEX; }
void fragment(){
	// A virtual room behind each display pane. Side walls and the back move with the view.
	vec3 local_eye=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1)).xyz;
	vec3 ray=normalize(pane_pos-local_eye);
	vec3 bounds=vec3(1.8,1.68,2.45);
	vec3 origin=vec3(pane_pos.xy,2.44);
	vec3 hit=(sign(ray)*bounds-origin)/(ray+vec3(.00001));
	vec3 point=origin+ray*min(hit.x,min(hit.y,hit.z));
	vec3 sample_ray=normalize(point+vec3(sin(variation)*.7,.18,-.8));
	vec2 room_uv=vec2(fract(.5+atan(sample_ray.x,sample_ray.z)/6.28318+variation*.11),acos(clamp(sample_ray.y,-1.,1.))/3.14159);
	vec3 room=texture(interior,room_uv).rgb;
	room=room/(1.+room*.67);
	ALBEDO=vec3(.08,.094,.10);
	EMISSION=room*vec3(.95,.65,.38)*1.48;
	ROUGHNESS=.145; SPECULAR=.85;
}
