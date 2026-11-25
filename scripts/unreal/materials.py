"""Build the street's lit materials using project-authored and recorded surface maps."""
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
bool road=C.r<.30;
float cover=road?smoothstep(.57,.83,drift-tracks*.27):smoothstep(.17,.47,drift);
float water=(1-smoothstep(.21,.65,drift))*.74+tracks*.23;
float2 powderUV=uv*.65+float2(.32,-.21)*Texture2DSample(DepthMap,DepthMapSampler,street/18.).r;
"""
inputs={"P":p,"N":n,"C":c,"DepthMap":texture(m,"snow_depth")}
surface=glass+snow+"""
if(abs(N.z)>.68){
    if(P.z>1400) return lerp(C,float3(.64,.71,.81),.7);
    float3 grit=Texture2DSample(Road,RoadSampler,uv).rgb;
    float3 powder=Texture2DSample(Snow,SnowSampler,powderUV).rgb;
    float3 base=road?grit*.26:lerp(grit*.67,float3(.21,.20,.19),.44);
    float2 seam=abs(frac(street/1.63)-.5);
    if(!road) base*=1-.6*smoothstep(.486,.5,max(seam.x,seam.y));
    return lerp(base*(1-.40*water),powder*float3(.91,.94,.99),cover);
}
float3 stone=Texture2DSample(Stone,StoneSampler,wallUV).rgb;
float joints=smoothstep(.014,.045,abs(frac(P.z*.01/.83)-.5));
float3 wall=C*(.56+.48*dot(stone,float3(.30,.52,.18)))*(.79+.21*joints);
float2 inside=q-float2(dot(V.xy,horizontal),V.z)*(.09/max(.22,abs(dot(V,N))));
float back=smoothstep(.17,.26,inside.x)*(1-smoothstep(.74,.83,inside.x));
float3 glassColor=lerp(float3(.026,.045,.059),float3(.075,.10,.11),smoothstep(.25,.65,inside.y)*back);
glassColor=lerp(glassColor,float3(.16,.155,.139),shade*.79);
return lerp(wall,glassColor*lerp(.37,1.,rail),pane)*(1-.30*lip);
"""
prop(m,snip(m,surface,dict(inputs,Road=texture(m,"asphalt_snow_Diffuse"),Snow=texture(m,"snow_02_Diffuse"),
                         Stone=texture(m,"white_sandstone_blocks_02_diffuse"),V=node(m,u.MaterialExpressionCameraVectorWS)),v3),mp.MP_BASE_COLOR)
night=node(m,u.MaterialExpressionScalarParameter)
night.set_editor_property("parameter_name","NightWindows")
lit=glass+"""
float3 lamp=lerp(float3(.62,.36,.16),float3(.45,.53,.57),variation);
return abs(N.z)<.7?Night*lamp*pane*rail*smoothstep(.56,.75,variation)*(.29+.55*q.y)*(1-.75*shade):0;
"""
prop(m,snip(m,lit,{"P":p,"N":n,"Night":night},v3),mp.MP_EMISSIVE_COLOR)
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
