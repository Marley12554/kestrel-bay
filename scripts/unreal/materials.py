"""Build the street's lit materials using project-authored and recorded surface maps."""
import json
import os
from pathlib import Path
import unreal as u

mel=u.MaterialEditingLibrary
assets=u.get_editor_subsystem(u.EditorAssetSubsystem)
folder="/Game/Manhattan/Surface"
mp=u.MaterialProperty

def material(name):
    path=folder+"/"+name
    m=assets.load_asset(path) if assets.does_asset_exist(path) else u.AssetToolsHelpers.get_asset_tools().create_asset(name,folder,u.Material,u.MaterialFactoryNew())
    mel.delete_all_material_expressions(m)
    m.set_editor_property("two_sided",True)
    return m

def node(m,cls): return mel.create_material_expression(m,cls,0,0)

def prop(m,n,p,out=""): mel.connect_material_property(n,out,p)

def snip(m,code,inputs,kind):
    n=node(m,u.MaterialExpressionCustom)
    n.set_editor_property("output_type",kind)
    args=[]
    for name in inputs:
        arg=u.CustomInput()
        arg.set_editor_property("input_name",name)
        args.append(arg)
    n.set_editor_property("inputs",args)
    n.set_editor_property("code",code)
    for name,other in inputs.items():
        expr,output=other if isinstance(other,tuple) else (other,"")
        if not mel.connect_material_expressions(expr,output,n,name): raise ValueError("Material input "+name)
    return n

def texture(m,name):
    expr=node(m,u.MaterialExpressionTextureObject)
    expr.set_editor_property("texture",assets.load_asset(folder+"/"+name))
    return expr

def finish(m):
    mel.recompile_material(m)
    assets.save_loaded_asset(m,False)

def param(m,name,default=0.):
    value=node(m,u.MaterialExpressionScalarParameter)
    value.set_editor_property("parameter_name",name)
    value.set_editor_property("default_value",default)
    return value

def vector_param(m,name):
    value=node(m,u.MaterialExpressionVectorParameter)
    value.set_editor_property("parameter_name",name)
    return value

v3=u.CustomMaterialOutputType.CMOT_FLOAT3
v1=u.CustomMaterialOutputType.CMOT_FLOAT1
m=material("M_Midtown")
p=node(m,u.MaterialExpressionWorldPosition)
n=node(m,u.MaterialExpressionVertexInterpolator)
mel.connect_material_expressions(node(m,u.MaterialExpressionVertexNormalWS),"",n,"")
c=node(m,u.MaterialExpressionVertexColor)
# The same grid transform used by the surveyed scene tracks the oblique avenues.
glass="""
float2 offset=P.xy*.01-float2(-208.099,573.891);
float2 street=float2(dot(offset,float2(.873,.488)),dot(offset,float2(-.488,.873)));
float along=abs(dot(N.xy,float2(.873,.488)))>.7?street.y:street.x;
float2 bay=float2(along/2.66,(P.z*.01-.52)/3.55), cell=floor(bay), q=frac(bay);
float2 edges=abs(q-.5),aa=clamp(fwidth(bay),.001,.22);
float fade=1-smoothstep(.08,.28,max(aa.x,aa.y));
float2 aperture=1-smoothstep(float2(.315,.313)-aa,float2(.315,.313)+aa,edges);
float pane=aperture.x*aperture.y*fade;
float rail=smoothstep(.012,.037,edges.x)*smoothstep(.012,.033,abs(q.y-.58));
float variation=frac(sin(fmod(dot(cell+floor(street*.009),float2(57.13,97.37)),6.28318))*4375.13);
float shade=step(.60,variation)*smoothstep(variation*.79,variation*.79+.045,q.y);
float reveal=max(edges.x/.315,edges.y/.313);
float lip=(1-smoothstep(.99,1.13,reveal))*smoothstep(.90,.99,reveal)*fade;
float2 horizontal=normalize(float2(N.y,-N.x)+.00001);
float2 wallUV=float2(dot(P.xy*.01,horizontal),P.z*.01)*.49;
"""
snow="""
float2 uv=street*.54;
float drift=Texture2DSample(DepthMap,DepthMapSampler,street/64.).r;
float lat=abs(street.x-81.)<9?street.x:street.y+45.8;
float wheel=abs(frac((lat+.12*sin(street.y*.07+street.x*.09))/3.85)*3.85-1.925);
float tracks=1-smoothstep(.14,.53,abs(wheel-.78));
float2 mapUV=(P.xy*.01+float2(1350,1500))/float2(2700,3000);
bool mappedRoad=all(mapUV>=0) && all(mapUV<1) && Texture2DSample(RoadMask,RoadMaskSampler,mapUV).r>.5;
bool road=ClassId<.45 || (ClassId>.85 && (mappedRoad || C.r<.30));
float cover=road?smoothstep(.57,.83,drift-tracks*.27):smoothstep(.17,.47,drift);
float water=(1-smoothstep(.21,.65,drift))*.74+tracks*.23;
float2 powderUV=uv*.65+float2(.32,-.21)*Texture2DSample(DepthMap,DepthMapSampler,street/18.).r;
float2 snowUV=(street+float2(240,136))/float2(400,208);
float4 banks=Texture2DSample(Field,FieldSampler,saturate(snowUV));
float depth=max(0.,(max(max(banks.r,banks.g),max(banks.b,banks.a))*255.-1.)*(.36/254.));
float packed=0.;
if (all(snowUV>=0) && all(snowUV<1)) {
    if (all(street>=Origin.xy) && all(street<Origin.xy+64))
        packed=min(.94*depth,Texture2DSample(Pressure,PressureSampler,frac(street/64.)).r*.36);
    cover=smoothstep(.0015,.033,depth-packed);
}
"""
pressure=node(m,u.MaterialExpressionTextureObjectParameter)
pressure.set_editor_property("parameter_name","Pressure")
pressure.set_editor_property("texture",assets.load_asset("/Engine/EngineResources/Black"))
track_origin=vector_param(m,"TrackOrigin")
inputs={"P":p,"N":n,"C":c,"ClassId":(c,"A"),"DepthMap":texture(m,"snow_depth"),"Field":texture(m,"FifthSnow"),"Pressure":pressure,"Origin":track_origin,"RoadMask":texture(m,"FifthRoads")}
car_contact="""
float3 gap=P-Car.xyz;
float2 footprint=abs(float2(dot(gap.xy,Heading.xy),dot(gap.xy,float2(-Heading.y,Heading.x))))*.01;
float body=1-smoothstep(-.28,.55,length(max(footprint-float2(1.8,.75),0)));
float tires=1-smoothstep(.2,1.,length((footprint-float2(1.44,.81))/float2(.45,.36)));
float occlusion=.67*body*(1-smoothstep(14.,96.,abs(gap.z)))+.24*tires*(1-smoothstep(7.,29.,abs(gap.z)));
"""
contact_inputs={"P":p,"Car":vector_param(m,"CarFoot"),"Heading":vector_param(m,"CarHeading")}
surface=glass+snow+car_contact+"""
if(abs(N.z)>.68){
    if(P.z>1400) return lerp(C,float3(.64,.71,.81),.7);
    float3 grit=Texture2DSample(Road,RoadSampler,uv).rgb;
    float3 powder=Texture2DSample(Snow,SnowSampler,powderUV).rgb;
    float3 base=road?grit*.26:lerp(grit*.67,float3(.21,.20,.19),.44);
    float2 seam=abs(frac(street/1.63)-.5);
    if(!road) base*=1-.6*smoothstep(.486,.5,max(seam.x,seam.y));
    float firm=smoothstep(.002,.048,packed);
    return lerp(base*(1-.40*water),powder*lerp(float3(.91,.94,.99),float3(.48,.61,.70),firm),cover)*(1-.30*occlusion);
}
if (ClassId>.74 && ClassId<.84) return float3(.15,.155,.16)*(.75+.5*Texture2DSample(Road,RoadSampler,float2(street.x+street.y,P.z*.01)*.82).r);
float3 stone=Texture2DSample(Stone,StoneSampler,wallUV).rgb;
float joints=smoothstep(.014,.045,abs(frac(P.z*.01/.83)-.5));
float3 wall=C*(.56+.48*dot(stone,float3(.30,.52,.18)))*(.79+.21*joints);
float2 inside=q-float2(dot(V.xy,horizontal),V.z)*(.09/max(.22,abs(dot(V,N))));
float back=smoothstep(.17,.26,inside.x)*(1-smoothstep(.74,.83,inside.x));
float3 glassColor=lerp(float3(.026,.045,.059),float3(.075,.10,.11),smoothstep(.25,.65,inside.y)*back);
glassColor=lerp(glassColor,float3(.16,.155,.139),shade*.79);
return lerp(wall,glassColor*lerp(.37,1.,rail),pane)*(1-.30*lip);
"""
prop(m,snip(m,surface,dict(inputs,**{k:v for k,v in contact_inputs.items() if k!="P"},Road=texture(m,"asphalt_snow_Diffuse"),Snow=texture(m,"snow_02_Diffuse"),
                         Stone=texture(m,"white_sandstone_blocks_02_diffuse"),V=node(m,u.MaterialExpressionCameraVectorWS)),v3),mp.MP_BASE_COLOR)
night=node(m,u.MaterialExpressionScalarParameter)
night.set_editor_property("parameter_name","NightWindows")
lit=glass+"""
float3 lamp=lerp(float3(.62,.36,.16),float3(.45,.53,.57),variation);
return abs(N.z)<.7?Night*lamp*pane*rail*smoothstep(.56,.75,variation)*(.29+.55*q.y)*(1-.75*shade):0;
"""
prop(m,snip(m,lit,{"P":p,"N":n,"Night":night},v3),mp.MP_EMISSIVE_COLOR)
prop(m,snip(m,car_contact+"return 1-occlusion;",contact_inputs,v1),mp.MP_AMBIENT_OCCLUSION)
prop(m,snip(m,glass+snow+"""
if(abs(N.z)>.68 && P.z<1400) return lerp(lerp(Texture2DSample(Rough,RoughSampler,uv).r*.67+.1,.13,water),.84,cover);
return lerp(.80,lerp(.14,.26,shade),pane);
""",dict(inputs,Rough=texture(m,"asphalt_snow_Rough")),v1),mp.MP_ROUGHNESS)
prop(m,snip(m,glass+"return abs(N.z)<.7?.38*pane*rail:0;",{"P":p,"N":n},v1),mp.MP_METALLIC)
# Use the geometric normal for projection. The normal output cannot depend on its own result.
normal=n
m.set_editor_property("tangent_space_normal",False)
relief=glass+snow+"""
if(abs(N.z)>.68) {
    if(P.z>1400) return N;
    float2 bump=lerp(Texture2DSample(AsphaltN,AsphaltNSampler,uv).rg,Texture2DSample(SnowN,SnowNSampler,powderUV).rg,cover)*2-1;
    return normalize(N+.35*(float3(.873,.488,0)*bump.x+float3(-.488,.873,0)*bump.y));
}
float2 grit=Texture2DSample(StoneN,StoneNSampler,wallUV).rg*2-1;
float3 alongBay=abs(dot(N.xy,float2(.873,.488)))>.7?float3(-.488,.873,0):float3(.873,.488,0);
float3 bevel=edges.x/.315>edges.y/.313?alongBay*sign(.5-q.x):float3(0,0,sign(.5-q.y));
return normalize(N+float3(horizontal*grit.x,grit.y)*.21*(1-pane)+bevel*lip*.88);
"""
prop(m,snip(m,relief,dict(inputs,N=normal,AsphaltN=texture(m,"asphalt_snow_nor_gl"),SnowN=texture(m,"snow_02_nor_gl"),
                          StoneN=texture(m,"white_sandstone_blocks_02_nor_gl")),v3),mp.MP_NORMAL)
finish(m)
m=material("M_StreetLampGlass")
lamp_color=snip(m,"return float3(1,.49,.17);",{},v3)
prop(m,lamp_color,mp.MP_BASE_COLOR)
prop(m,snip(m,"return float3(18,7.4,2.1)*Night;",{"Night":param(m,"Night",1)},v3),mp.MP_EMISSIVE_COLOR)
finish(m)
for paint,tint in (("TeslaPaint",".687,.701,.694"),("TrafficPaint",".040,.067,.095")):
    m=material("M_"+paint)
    m.set_editor_property("shading_model",u.MaterialShadingModel.MSM_CLEAR_COAT)
    prop(m,snip(m,"return float3("+tint+");",{},v3),mp.MP_BASE_COLOR)
    # The native clear-coat model defaults to full coverage and 0.1 coat roughness.
    for target,value in ((mp.MP_METALLIC,.22),(mp.MP_ROUGHNESS,.24)):
        prop(m,snip(m,f"return {value:.2f};",{},v1),target)
    finish(m)
m=material("M_FallingSnow")
m.set_editor_property("used_with_instanced_static_meshes",True)
m.set_editor_property("blend_mode",u.BlendMode.BLEND_MASKED)
uv=node(m,u.MaterialExpressionTextureCoordinate)
pos=node(m,u.MaterialExpressionWorldPosition)
eye=node(m,u.MaterialExpressionCameraPositionWS)
rand=node(m,u.MaterialExpressionPerInstanceRandom)
flake="""
float3 span=float3(3000,3000,1500), wind=float3(19+9*R,11+7*R,-(105+95*R));
float3 original=P-Local;
float3 center=Eye+(frac((original-Eye+Clock*wind)/span+.5)-.5)*span;
float3 right=normalize(float3(-(Eye-center).y,(Eye-center).x,.001));
float3 bill=(right*(UV.x-.5)*2.1+float3(0,0,(.5-UV.y)*2.9))*(.38+.77*R);
return center-P+bill;
"""
prop(m,snip(m,flake,{"P":pos,"Local":node(m,u.MaterialExpressionLocalPosition),"Eye":eye,"R":rand,"Clock":node(m,u.MaterialExpressionTime),"UV":uv},v3),mp.MP_WORLD_POSITION_OFFSET)
prop(m,snip(m,"""
float3 local=P-float3(-14795.03,59958.58,0);
float x=dot(local.xy,float2(.487933,-.872881)),z=dot(local.xy,float2(.872881,.487933));
if(x>0 && x<2325 && z> -1800 && z<22 && P.z<499) return 0.;
return R<Density && distance(Eye,P)>65 ? 1-smoothstep(.32,1.,length(2*UV-1)) : 0.;
""",{"P":pos,"Eye":eye,"R":rand,"UV":uv,"Density":param(m,"Density",1)},v1),mp.MP_OPACITY_MASK)
prop(m,snip(m,"return float3(.68,.73,.79);",{},v3),mp.MP_BASE_COLOR)
finish(m)

def wheel_powder():
    m=material("M_WheelPowder")
    m.set_editor_property("used_with_instanced_static_meshes",True)
    m.set_editor_property("blend_mode",u.BlendMode.BLEND_TRANSLUCENT)
    uv=node(m,u.MaterialExpressionTextureCoordinate)
    args={"P":node(m,u.MaterialExpressionWorldPosition),"Local":node(m,u.MaterialExpressionLocalPosition),
          "Eye":node(m,u.MaterialExpressionCameraPositionWS),"Rand":node(m,u.MaterialExpressionPerInstanceRandom),
          "Clock":node(m,u.MaterialExpressionTime),"UV":uv}
    for i,key in enumerate(("Born","Vx","Vy","Vz")):
        args[key]=node(m,u.MaterialExpressionPerInstanceCustomData)
        args[key].set_editor_property("data_index",i)
    offset="""
float t=max(0.,Clock-Born), life=saturate(t/.46);
float3 center=P-Local+float3(Vx,Vy,Vz)*min(t,.46);
center.z-=340.*min(t,.46)*min(t,.46);
float3 toEye=normalize(Eye-center);
float3 right=normalize(float3(-toEye.y,toEye.x,.001));
float3 up=normalize(cross(toEye,right));
float size=(.25+.75*Rand)*(1.+.6*life)*(1.-life);
return center-P+size*(right*(UV.x-.5)*19.+up*(.5-UV.y)*16.);
"""
    prop(m,snip(m,offset,args,v3),mp.MP_WORLD_POSITION_OFFSET)
    prop(m,snip(m,"return .62*pow(saturate(1.-length(UV*2.-1.)),1.65);",{"UV":uv},v1),mp.MP_OPACITY)
    prop(m,snip(m,"return float3(.61,.71,.84);",{},v3),mp.MP_BASE_COLOR)
    finish(m)

wheel_powder()
for name,base,glow in (("TeslaHeadlamp",".62,.70,.76",".84,.93,1"),("Ln12Mtl",".32,.012,.014","1,.016,.008"),("TeslaIndicator",".46,.14,.015","1,.35,.012")):
    m=material("M_"+name)
    prop(m,snip(m,"return float3("+base+");",{},v3),mp.MP_BASE_COLOR)
    args={"Pos":node(m,u.MaterialExpressionLocalPosition)}
    if name=="TeslaIndicator":
        args["Side"]=param(m,"SignalSide")
        factor="(Side!=0 && sign(Pos.x)==Side ? 4.0 : 0.0)"
    else:
        args["Level"]=param(m,"Level")
        # Hull local -Y points at the nose. White trim inside shares this slot.
        factor="(Pos.y < -100 ? Level : 0.)" if name=="TeslaHeadlamp" else "Level"
    prop(m,snip(m,"return float3("+glow+")*"+factor+";",args,v3),mp.MP_EMISSIVE_COLOR)
    prop(m,snip(m,"return .22;",{},v1),mp.MP_ROUGHNESS)
    finish(m)

colors=("1,.071,.033","1,.46,.085",".089,.69,.32")
for avenue in (0,1):
    phase="fmod(Clock,46.)" if avenue else "fmod(Clock+23.,46.)"
    for aspect in range(3):
        m=material(f"M_Traffic{avenue}{aspect}")
        code="float t="+phase+"; return ("+("t>=20.","t>=17. && t<20.","t<17.")[aspect]+") ? float3("+colors[aspect]+") : 0;"
        bulb=snip(m,code,{"Clock":node(m,u.MaterialExpressionTime)},v3)
        prop(m,snip(m,"return .025+.88*Bulb;",{"Bulb":bulb},v3),mp.MP_BASE_COLOR)
        prop(m,snip(m,"return 6*Bulb;",{"Bulb":bulb},v3),mp.MP_EMISSIVE_COLOR)
        finish(m)
for across in (0,1):
    m=material(f"M_Pedestrian{across}")
    m.set_editor_property("blend_mode",u.BlendMode.BLEND_MASKED)
    phase="fmod(Clock+23.,46.)" if across else "fmod(Clock,46.)"
    code="float t="+phase+"; float4 w=Texture2DSample(Walk,WalkSampler,UV),h=Texture2DSample(Hand,HandSampler,UV); return t<9. ? w : (t<20. && frac(t)>=.5 ? 0 : h);"
    icon=snip(m,code,{"Clock":node(m,u.MaterialExpressionTime),"Walk":texture(m,"CrossingWalk"),"Hand":texture(m,"CrossingHand"),"UV":node(m,u.MaterialExpressionTextureCoordinate)},u.CustomMaterialOutputType.CMOT_FLOAT4)
    prop(m,snip(m,"return Icon.a;",{"Icon":icon},v1),mp.MP_OPACITY_MASK)
    prop(m,snip(m,"return Icon.rgb;",{"Icon":icon},v3),mp.MP_BASE_COLOR)
    prop(m,snip(m,"return 4*Icon.rgb;",{"Icon":icon},v3),mp.MP_EMISSIVE_COLOR)
    finish(m)

state=json.loads((Path(os.environ["FIFTH_ROOT"])/"dist/unreal-staging/block_state.json").read_text())
def world_dir(key):
    x,y,z=state[key]
    return f"float3({x:.7f},{z:.7f},{y:.7f})"
m=material("M_AvenueFlagCloth")
uv=node(m,u.MaterialExpressionTextureCoordinate)
cloth="""
float u=UV.x,v=UV.y,r=9.5*u+1.3*v-Clock*1.55;
float x=1.92*u-.54*u*u+.09*u*sin(r)-3.42*u;
float y=-1.35*u-1.23*u*u+.07*u*cos(r);
float z=-.082*v+.24*u+.27*sin(1.57*u)*sin(13*u+1.15*v+.35*sin(Clock*1.25))+.09*u*sin(r);
return 100*(x*ACROSS+z*OUT+float3(0,0,y));
""".replace("ACROSS",world_dir("flag_across")).replace("OUT",world_dir("flag_out"))
prop(m,snip(m,cloth,{"UV":uv,"Clock":node(m,u.MaterialExpressionTime)},v3),mp.MP_WORLD_POSITION_OFFSET)
fabric=snip(m,"""
float3 white=float3(.88,.86,.80);
float stripe=13*UV.y, aa=max(fwidth(stripe),.001);
float band=smoothstep(.5-aa*.5,.5+aa*.5,abs(fmod(stripe+.5,2)-1));
float3 color=lerp(float3(.46,.018,.036),white,band);
if(UV.x<.4 && UV.y<7./13.) {
    float2 cell=float2(.4/12.,7./130.), grid=UV/cell;
    float row=clamp(floor(grid.y+.5),1.,9.), first=1+fmod(row+1,2);
    float col=clamp(first+2*floor((grid.x-first)*.5+.5),first,12-first);
    float2 d=(grid-float2(col,row))*cell*float2(1.9,1.);
    float wedge=abs(frac((atan2(d.x,-d.y)+.628319)/1.256637)*1.256637-.628319);
    float dist=length(d)-.022*cos(1.256637)/cos(1.256637-wedge);
    float edge=max(fwidth(dist),.0004);
    color=lerp(white,float3(.018,.041,.13),smoothstep(-edge,edge,dist));
}
return color;
""",{"UV":uv},v3)
prop(m,fabric,mp.MP_BASE_COLOR)
prop(m,snip(m,"return .92;",{},v1),mp.MP_ROUGHNESS)
finish(m)
for name,stock in [("M_Buff","BuffBrick"),("M_OfficePanel","OfficePanel"),("M_Limestone","IndianaStone")]:
    m=material(name)
    p=node(m,u.MaterialExpressionWorldPosition)
    n=node(m,u.MaterialExpressionPixelNormalWS)
    grain=texture(m,"white_sandstone_blocks_02_diffuse")
    uv_code="float2 uv=float2(dot(P.xy,normalize(float2(-N.y,N.x)+.00001)),P.z)*.01;\n"
    if stock=="BuffBrick":
        # The source is a packed data map. R is firing variation, GB encode relief.
        bond=texture(m,"buff-running-bond")
        inputs={"P":p,"N":n,"Bond":bond,"Grain":grain}
        code=uv_code+"""
float fired=pow(saturate(Texture2DSample(Bond,BondSampler,uv/float2(2.496,1.296)).r),1./2.2);
float mineral=Texture2DSample(Grain,GrainSampler,uv*.32).g;
float patch=Texture2DSample(Grain,GrainSampler,uv*.071).r;
return lerp(float3(.17,.129,.087),float3(.63,.445,.265),fired)*(.78+.28*mineral+.23*patch);
"""
        prop(m,snip(m,code,inputs,v3),mp.MP_BASE_COLOR)
        vertex_normal=node(m,u.MaterialExpressionVertexNormalWS)
        interpolated=node(m,u.MaterialExpressionVertexInterpolator)
        mel.connect_material_expressions(vertex_normal,"",interpolated,"")
        m.set_editor_property("tangent_space_normal",False)
        normal=uv_code+"""
float2 slope=pow(saturate(Texture2DSample(Bond,BondSampler,uv/float2(2.496,1.296)).gb),1./2.2)*2.-1.;
float3 along=normalize(float3(-N.y,N.x,.00001));
return normalize(N+along*slope.x+float3(0,0,slope.y));
"""
        prop(m,snip(m,normal,{"P":p,"N":interpolated,"Bond":bond},v3),mp.MP_NORMAL)
    else:
        code=uv_code+"return Texture2DSample(Grain,GrainSampler,uv/1.85).rgb*TINT;"
        code=code.replace("TINT","float3(.59,.54,.46)" if stock=="OfficePanel" else "float3(.95,.91,.81)")
        prop(m,snip(m,code,{"P":p,"N":n,"Grain":grain},v3),mp.MP_BASE_COLOR)
    rough=node(m,u.MaterialExpressionConstant)
    rough.set_editor_property("r",.87 if stock=="BuffBrick" else .74)
    prop(m,rough,mp.MP_ROUGHNESS)
    finish(m)
for name,tint in [("Window",".10,.15,.18"),("BrightGlass",".18,.23,.27"),("WarmWindow",".32,.20,.10"),("CoolWindow",".14,.21,.24")]:
    m=material("M_"+name)
    inputs={"P":node(m,u.MaterialExpressionWorldPosition),"N":node(m,u.MaterialExpressionPixelNormalWS),"V":node(m,u.MaterialExpressionCameraVectorWS)}
    code="""
float2 xy=float2(dot(P.xy,normalize(float2(-N.y,N.x)+.00001)),P.z)*.01;
float2 uv=frac(xy/float2(1.85,2.25));
float2 ray=float2(dot(V.xy,normalize(float2(-N.y,N.x)+.00001)),V.z)/max(.12,abs(dot(N,V)));
float2 limits=lerp(uv,1-uv,step(ray,0))/max(abs(ray),.001);
float depth=min(.68,min(limits.x,limits.y));float2 back=uv-depth*ray;
float panel=smoothstep(.09,.13,back.x)*(1-smoothstep(.39,.43,back.x))*smoothstep(.27,.31,back.y)*(1-smoothstep(.65,.68,back.y));
float trim=1-smoothstep(.008,.04,abs(back.y-.16));
float curtain=smoothstep(.73,.82,back.x)*(.4+.25*cos(back.x*56));
return float3(TINT)*(.31+.65*depth+.26*panel+.14*trim+curtain);
""".replace("TINT",tint)
    room=snip(m,code,inputs,v3)
    prop(m,room,mp.MP_BASE_COLOR)
    if name in ("WarmWindow","CoolWindow"):prop(m,room,mp.MP_EMISSIVE_COLOR)
    rough=node(m,u.MaterialExpressionConstant)
    rough.set_editor_property("r",.33)
    prop(m,rough,mp.MP_ROUGHNESS)
    finish(m)
m=material("M_RetailGlazing")
m.set_editor_property("blend_mode",u.BlendMode.BLEND_TRANSLUCENT)
base_color=node(m,u.MaterialExpressionConstant3Vector)
base_color.set_editor_property("constant",u.LinearColor(.17,.22,.24,1))
prop(m,base_color,mp.MP_BASE_COLOR)
edge=node(m,u.MaterialExpressionFresnel)
edge.set_editor_property("base_reflect_fraction",.045)
prop(m,edge,mp.MP_OPACITY)
finish(m)
m=material("M_FixtureColor")
m.set_editor_property("used_with_instanced_static_meshes",True)
parts=[]
for k in range(3):
    expr=node(m,u.MaterialExpressionPerInstanceCustomData)
    expr.set_editor_property("data_index",k)
    expr.set_editor_property("const_default_value",.5)
    parts.append(expr)
prop(m,snip(m,"return float3(R,G,B);",dict(zip("RGB",parts)),v3),mp.MP_BASE_COLOR)
finish(m)
for finish_name,file_name in (("Marble","marble_01"),("Terrazzo","terrazzo_tiles")):
    m=material("M_Reserve"+finish_name)
    m.set_editor_property("used_with_instanced_static_meshes",True)
    color=node(m,u.MaterialExpressionTextureObject)
    color.set_editor_property("texture",assets.load_asset("/Game/Manhattan/Authored/FixtureFinishes/Textures/"+file_name+"_diff"))
    rough=texture(m,file_name+"_rough")
    inputs={"P":node(m,u.MaterialExpressionWorldPosition),"N":node(m,u.MaterialExpressionPixelNormalWS)}
    plane="float2 uv=abs(N.z)>.7?P.xy:float2(dot(P.xy,float2(.385,1.361)),P.z); uv*=.0053;"
    detail="float3 t=Texture2DSample(Stone,StoneSampler,uv).rgb; float l=dot(t,float3(.21,.72,.07));"
    if finish_name=="Terrazzo": detail+="return lerp(t,l.xxx,.74)*float3(1.65,1.61,1.53)+float3(.075,.067,.06);"
    else: detail+="float vein=1-smoothstep(.08,.28,abs(sin(9*l+uv.x*4.+uv.y*2.5)));return lerp(float3(.039,.033,.029)*(.6+1.6*l),float3(.30,.25,.218),.62*vein);"
    prop(m,snip(m,plane+detail,dict(inputs,Stone=color),v3),mp.MP_BASE_COLOR)
    prop(m,snip(m,plane+"return .20+.24*Texture2DSample(Rough,RoughSampler,uv).r;",dict(inputs,Rough=rough),v1),mp.MP_ROUGHNESS)
    finish(m)
m=material("M_Enamel")
prop(m,node(m,u.MaterialExpressionVertexColor),mp.MP_BASE_COLOR)
rough=node(m,u.MaterialExpressionConstant)
rough.set_editor_property("r",.32)
prop(m,rough,mp.MP_ROUGHNESS)
finish(m)
m=material("M_Moon")
m.set_editor_property("shading_model",u.MaterialShadingModel.MSM_UNLIT)
sample=node(m,u.MaterialExpressionTextureSample)
sample.set_editor_property("texture",assets.load_asset(folder+"/lroc_color_poles_1k"))
# Orient the near hemisphere toward the street and keep the maria legible as the eye adapts.
n=node(m,u.MaterialExpressionPixelNormalWS)
uv=snip(m,"float3 right=normalize(cross(float3(0,0,1),D)); float3 up=cross(D,right); return float2(.5+atan2(dot(N,right),dot(N,-D))/6.283185,.5-asin(clamp(dot(N,up),-1.,1.))/3.14159);",
        {"N":n,"D":snip(m,"return normalize(float3(-191.,77.,329.));",{},v3)},u.CustomMaterialOutputType.CMOT_FLOAT2)
mel.connect_material_expressions(uv,"",sample,"UVs")
lunar=snip(m,"return 3.1*Rock;",{"Rock":(sample,"RGB")},v3)
adapt=node(m,u.MaterialExpressionEyeAdaptationInverse)
if not mel.connect_material_expressions(lunar,"",adapt,mel.get_material_expression_input_names(adapt)[0]): raise RuntimeError("Lunar exposure input")
prop(m,adapt,mp.MP_EMISSIVE_COLOR)
finish(m)
u.log("FIFTH MATERIALS COMPLETE")

# The glTF importer uses engine/plugin material parents. Their packaged permutations
# omit instancing. Preserve the parameter hierarchy in project-owned parents.
parents={}
def instance_parent(source):
    key=source.get_path_name()
    if key in parents: return parents[key]
    path=folder+"/Instanced/"+source.get_name()
    dest=assets.load_asset(path) if assets.does_asset_exist(path) else assets.duplicate_asset(key.split(".")[0],path)
    if isinstance(dest,u.MaterialInstanceConstant):
        mel.set_material_instance_parent(dest,instance_parent(source.get_editor_property("parent")))
        mel.update_material_instance(dest)
    else:
        dest.set_editor_property("used_with_instanced_static_meshes",True)
        mel.recompile_material(dest)
    assets.save_loaded_asset(dest,False)
    parents[key]=dest
    return dest

for tree in ("Parts","Authored/FixtureFinishes"):
    for path in assets.list_assets("/Game/Manhattan/"+tree,recursive=True):
        if "/Materials/" not in path:continue
        stock=assets.load_asset(path)
        if isinstance(stock,u.Material):
            if not stock.get_editor_property("used_with_instanced_static_meshes"):
                stock.set_editor_property("used_with_instanced_static_meshes",True)
                finish(stock)
        elif isinstance(stock,u.MaterialInstanceConstant):
            parent=stock.get_editor_property("parent")
            if not parent.get_path_name().startswith(folder+"/Instanced/"):
                mel.set_material_instance_parent(stock,instance_parent(parent))
                mel.update_material_instance(stock)
                assets.save_loaded_asset(stock,False)
