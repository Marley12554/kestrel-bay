shader_type spatial;
render_mode cull_disabled;
#include "res://frontage_mask.gdshaderinc"
#include "res://winter/ground_contact.gdshaderinc"
uniform sampler2D snow_depth : filter_linear, repeat_enable;
uniform sampler2D asphalt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_rough : filter_linear_mipmap, repeat_enable;
uniform sampler2D snow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float night_windows = 1.0;
uniform float sprint_softness = 0.0;
uniform vec4 backing_extent;
varying vec2 world_xz;
varying vec3 street;
varying vec3 direction;
float hash(vec2 p) { return fract(sin(mod(dot(p,vec2(57.13,97.37)),6.28318))*4375.13); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);
}
void vertex() {
	contact_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	vec3 p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz-vec3(-208.099,0,573.891);
	world_xz=p.xz+vec2(-208.099,573.891);
	street=vec3(dot(p.xz,vec2(.873,.488)),p.y,dot(p.xz,vec2(-.488,.873)));
	direction=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	if(all(greaterThanEqual(world_xz,backing_extent.xy)) && all(lessThan(world_xz,backing_extent.zw))) discard;
	// The city mesh carries a surface class on surveyed, draped pavement.
	bool graded_road=COLOR.a<.45, graded_walk=COLOR.a>.58 && COLOR.a<.73;
	bool graded_curb=COLOR.a>.74 && COLOR.a<.84;
	bool pavement=UV2.x>.99 || graded_road || graded_walk || graded_curb;
	if(!pavement && (modeled_empire_base(street,direction) || demarest_wall(street,direction))) discard;
	vec3 p=street; vec3 base=COLOR.rgb;
	if(pavement || (abs(direction.y)>.68 && p.y<1.0)){
		vec2 uv=p.xz*.54;
		float bias=sprint_softness*smoothstep(.38,1.,length(SCREEN_UV*2.-1.));
		float drift=texture(snow_depth,p.xz/64.0).r;
		bool road=graded_road || UV2.x>2.5 || (!pavement && p.y<.09 && base.r<.3);
		float lateral=abs(p.x-81.)<9.0?p.x:p.z+45.8;
		float wheel=abs(mod(lateral+.12*sin(p.z*.07+p.x*.09),3.85)-1.925);
		float tracks=1.-smoothstep(.14,.53,abs(wheel-.78));
		float cover=road?smoothstep(.57,.83,drift-tracks*.27):smoothstep(.17,.47,drift+(pavement?UV2.y:0.));
		// The modeled block has an independent snow surface above this substrate.
		if(all(greaterThanEqual(p.xz,vec2(-240.,-136.))) && all(lessThan(p.xz,vec2(160.,72.)))) cover=0.;
		vec3 grit=texture(asphalt,uv,bias).rgb;
		vec2 powder_uv=uv*.65+vec2(.32,-.21)*texture(snow_depth,p.xz/18.).r;
		vec3 powder=texture(snow,powder_uv,bias).rgb;
		float water=(1.-smoothstep(.21,.65,drift))*.74+tracks*.23;
		vec3 substrate=road?grit*.26:mix(grit*.67,vec3(.21,.20,.19),.44);
		vec2 seam=abs(fract(p.xz/1.63)-.5);
		if(!road) substrate*=1.-.6*smoothstep(.486,.5,max(seam.x,seam.y));
		ALBEDO=mix(substrate*(1.-.40*water),powder*vec3(.91,.94,.99),cover);
		ROUGHNESS=mix(mix(texture(asphalt_rough,uv,bias).r*.67+.10,.13,water),.84,cover);
		vec3 bump=mix(texture(asphalt_normal,uv,bias).rgb,texture(snow_normal,powder_uv,bias).rgb,cover)*2.-1.;
		vec3 wx=vec3(.873,0,.488),wz=vec3(-.488,0,.873);
		if(graded_curb || (UV2.x>1.5 && UV2.x<2.5)){
			vec2 face_uv=vec2((p.x+p.z)*.82,p.y*.82);
			ALBEDO=vec3(.15,.155,.16)*(.75+.5*texture(asphalt,face_uv,bias).r);
			ROUGHNESS=.79;
		} else {
			vec3 surface=pavement?direction:vec3(0.,1.,0.);
			NORMAL=normalize(mat3(VIEW_MATRIX)*(surface+(wx*bump.x+wz*bump.y)*.35));
			float contact=ground_occlusion();
			AO=1.0-contact;
			ALBEDO*=1.0-0.30*contact;
		}
	} else if(empire_shaft(p,direction)) {
		float glass,lit;
		ALBEDO=shaft_surface(p,direction,glass,lit);
		EMISSION=vec3(.37,.26,.16)*lit*night_windows;
		ROUGHNESS=mix(.73,.21,glass);
	} else if(abs(direction.y)<.70) {
		float along=abs(dot(direction.xz,vec2(.873,.488)))>.7?p.z:p.x;
		vec2 bay=vec2(along/2.66,(p.y-.52)/3.55), cell=floor(bay), q=fract(bay);
		vec2 aa=clamp(fwidth(bay),.001,.22);
		float fade=1.-smoothstep(.08,.28,max(aa.x,aa.y));
		vec2 edge=abs(q-.5); vec2 opening=1.-smoothstep(vec2(.315,.313)-aa,vec2(.315,.313)+aa,edge);
		float pane=opening.x*opening.y*fade;
		float rail=smoothstep(.012,.037,abs(q.x-.5))*smoothstep(.012,.033,abs(q.y-.58));
		float lit=smoothstep(.56,.75,hash(cell+floor(p.xz*.009)));
		float blinds=step(.73,hash(cell+1.71))*step(.57,q.y);
		vec3 room=mix(vec3(.62,.36,.16),vec3(.45,.53,.57),hash(cell+.8));
		float joints=smoothstep(.014,.045,abs(fract(p.y/.83)-.5));
		vec3 horizontal=normalize(vec3(direction.z,0.,-direction.x));
		vec2 surface_uv=vec2(dot(world_xz,horizontal.xz),p.y)*.49;
		vec3 stone=texture(wall_stone,surface_uv).rgb;
		vec2 grit=texture(wall_normal,surface_uv).rg*2.-1.;
		float reveal=max(abs(q.x-.5)/.315,abs(q.y-.5)/.313);
		float lip=(1.-smoothstep(.99,1.13,reveal))*smoothstep(.90,.99,reveal)*fade;
		vec3 wall=base*(.56+.48*dot(stone,vec3(.30,.52,.18)))*(.79+.21*joints);
		vec3 eye=mat3(INV_VIEW_MATRIX)*VIEW;
		vec2 inside=q-vec2(dot(eye,horizontal),eye.y)*(.09/max(.22,abs(dot(eye,direction))));
		float back=smoothstep(.17,.26,inside.x)*(1.-smoothstep(.74,.83,inside.x));
		float floor_glow=smoothstep(.25,.65,inside.y)*back;
		float shade_height=hash(vec2(cell.x*.27,floor(cell.y)+.7))*.79;
		float shade=smoothstep(shade_height,shade_height+.045,q.y)*step(.42,hash(vec2(floor(cell.x/3.),cell.y)));
		vec3 glass=mix(vec3(.026,.045,.059),vec3(.075,.10,.11),floor_glow);
		glass=mix(glass,vec3(.16,.155,.139),shade*.79);
		ALBEDO=mix(wall,glass*mix(.37,1.,rail),pane)*(1.-.30*lip);
		// Tilt the four sides of the recessed opening toward its center so
		// the sill catches daylight and the lintel faces down into shadow.
		vec3 along_bay = abs(dot(direction.xz,vec2(.873,.488)))>.7 ? vec3(-.488,0.,.873) : vec3(.873,0.,.488);
		vec3 bevel = edge.x/.315 > edge.y/.313 ? along_bay*sign(.5-q.x) : vec3(0.,sign(.5-q.y),0.);
		vec3 relief = (horizontal*grit.x+vec3(0.,grit.y,0.))*.21*(1.-pane) + bevel*lip*.88;
		NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX)*relief);
		AO=1.-lip*.50;
		METALLIC=.38*pane*rail;
		SPECULAR=mix(.35,.77,pane);
		EMISSION=night_windows*room*pane*rail*lit*(.29+.55*q.y)*(1.-.75*blinds);
		ROUGHNESS=mix(.79+.11*grit.x,mix(.14,.26,shade),pane);
	} else { ALBEDO=mix(base,vec3(.64,.71,.81),.7); ROUGHNESS=.83; }
}
