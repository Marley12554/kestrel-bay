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
n=node(m,u.MaterialExpressionPixelNormalWS)
c=node(m,u.MaterialExpressionVertexColor)
# The same grid transform used by the surveyed scene tracks the oblique avenues.
glass="""
float2 avenue=float2(dot(P.xy,float2(.873,.488)),dot(P.xy,float2(-.488,.873)))*.01;
float along=abs(dot(N.xy,float2(.873,.488)))>.7?avenue.y:avenue.x;
float2 bay=float2(along/2.66,(P.z*.01-.52)/3.55);
float2 q=abs(frac(bay)-.5),aa=clamp(fwidth(bay),.001,.22);
float2 edges=1-smoothstep(float2(.31,.33)-aa,float2(.31,.33)+aa,q);
float pane=edges.x*edges.y;
float variation=frac(sin(dot(floor(bay),float2(12.9898,78.233)))*43758.5453);
"""
inputs={"P":p,"N":n,"C":c,"Road":texture(m,"asphalt_snow_Diffuse"),"Snow":texture(m,"snow_02_Diffuse"),"Brick":texture(m,"buff-running-bond")}
code=glass+"""
if(abs(N.z)>.7){
    if(P.z>1400) return C*.72;
    float2 uv=P.xy*.0054;
    float3 grit=Texture2DSample(Road,RoadSampler,uv).rgb;
    float3 snow=Texture2DSample(Snow,SnowSampler,uv*.65).rgb;
    float sidewalk=step(.42,C.r);
    float pattern=Texture2DSample(Road,RoadSampler,uv*.037).r;
    float coverage=smoothstep(.20,.64,pattern+sidewalk*.19);
    return lerp(grit*lerp(.21,.53,sidewalk),snow*.68,coverage);
}
float2 wall=float2(along,P.z*.01);
float3 grain=Texture2DSample(Brick,BrickSampler,wall/2.6).rgb;
float3 stone=C*(.82+.32*grain.r);
return lerp(stone,lerp(float3(.022,.032,.044),float3(.095,.13,.16),variation),pane);
"""
prop(m,snip(m,code,inputs,v3),mp.MP_BASE_COLOR)
prop(m,snip(m,glass+"return abs(N.z)>.7?.69:lerp(.83,.27,pane);",{"P":p,"N":n},v1),mp.MP_ROUGHNESS)
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
m=material("M_Moon")
m.set_editor_property("shading_model",u.MaterialShadingModel.MSM_UNLIT)
sample=node(m,u.MaterialExpressionTextureSample)
sample.set_editor_property("texture",assets.load_asset(folder+"/lroc_color_poles_1k"))
prop(m,sample,mp.MP_EMISSIVE_COLOR)
finish(m)
u.log("FIFTH MATERIALS COMPLETE")

for path in assets.list_assets("/Game/Manhattan/Parts",recursive=True):
    if "/Materials/" not in path:continue
    stock=assets.load_asset(path)
    if isinstance(stock,u.Material):
        stock.set_editor_property("used_with_instanced_static_meshes",True)
        finish(stock)
    elif isinstance(stock,u.MaterialInstanceConstant):
        parent=stock.get_editor_property("parent")
        if isinstance(parent,u.Material) and parent.get_path_name().startswith("/Game/"):
            parent.set_editor_property("used_with_instanced_static_meshes",True)
            finish(parent)
