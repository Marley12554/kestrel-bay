shader_type spatial;
uniform sampler2D stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D polish : filter_linear_mipmap, repeat_enable;
uniform bool marble=false;
varying vec3 p;
varying vec3 normal_world;
float h(vec2 sample_pos){return fract(sin(dot(mod(sample_pos,237.),vec2(41.23,73.18)))*4328.7);}
float cloud(vec2 sample_pos){vec2 i=floor(sample_pos),f=fract(sample_pos);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+1.),f.x),f.y);}
void vertex(){
 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 vec2 uv=abs(normal_world.y)>.7?p.xz:vec2(dot(p.xz,normalize(vec2(.873,.488)))+dot(p.xz,normalize(vec2(-.488,.873))),p.y);
 uv*=marble?.52:.53;
 vec3 tex=texture(stone,uv).rgb;
 float l=dot(tex,vec3(.21,.72,.07));
 if(marble){
  float fold=cloud(uv*2.9)+.27*cloud(uv*9.)+.075*cloud(uv*23.);
  float vein=abs(sin(17.*fold+2.*l+uv.x*4.+uv.y*2.5));
  ALBEDO=mix(vec3(.039,.033,.029)*(0.60+1.6*l),vec3(.30,.25,.218),.15*fold+.62*(1.-smoothstep(.025,.21,vein)));
 }else{
  ALBEDO=mix(tex,vec3(l),.74)*vec3(1.65,1.61,1.53)+vec3(.075,.067,.06);
 }
 ROUGHNESS=(marble?.19:.24)+.24*texture(polish,uv).r;
}
