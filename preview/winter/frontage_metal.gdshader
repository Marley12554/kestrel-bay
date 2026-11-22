shader_type spatial;
uniform vec4 tint : source_color;
uniform float rough;
varying vec3 pos;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	float line=(pos.x+pos.z)*1250.+sin(pos.y*1.7)*.45;
	float brush=sin(line)*exp(-min(fwidth(line),14.));
	float patina=sin(pos.y*1.8+sin(pos.x*3.1))*sin(pos.z*3.2+pos.x*.77);
	ALBEDO=tint.rgb*(.97+.035*patina+.025*brush);
	METALLIC=.74;
	ROUGHNESS=clamp(rough+.055*patina+.08*brush,.19,.75);
}
