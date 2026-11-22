shader_type spatial;
uniform mat4 store_inverse;
varying vec3 in_store;
void vertex(){
 in_store=(store_inverse*MODEL_MATRIX*vec4(0.,0.,0.,1.)).xyz;
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
 MODELVIEW_MATRIX[0].xyz*=length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX[1].xyz*=length(MODEL_MATRIX[1].xyz);
}
void fragment(){
 if(in_store.x>0. && in_store.x<23.25 && in_store.z<.22 && in_store.z> -18. && in_store.y<4.99) discard;
 ALBEDO=vec3(.68,.73,.79);
}
