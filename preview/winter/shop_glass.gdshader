shader_type spatial;
// Street-facing dark glass reflects the environment. Condensation is strongest
// near the gasket and thin enough to leave the central glass readable.
uniform float variation = 0.0;
void fragment(){
	vec2 edge = min(UV,1.0-UV);
	float rim = 1.0 - smoothstep(.005,.055,min(edge.x,edge.y));
	float streak = .5+.5*sin(UV.x*63.+variation+sin(UV.x*137.));
	ALBEDO = mix(vec3(.032,.053,.065),vec3(.17,.19,.19),rim*streak);
	METALLIC = .64;
	ROUGHNESS = .13+.22*rim;
	SPECULAR = .92;
}
