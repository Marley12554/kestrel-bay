"""Assemble native UE assets in the same surveyed frame as the Godot preview."""
import json
import math
import os
import random
from pathlib import Path
import unreal as u

root = Path(os.environ["FIFTH_ROOT"])
stage = root / "dist/unreal-staging"
placement = json.loads((stage/"placement.json").read_text())
state = json.loads((stage/"block_state.json").read_text())
street = json.loads((root/"preview/survey/1350-street.json").read_text())
editor = u.get_editor_subsystem(u.EditorActorSubsystem)
assets = u.get_editor_subsystem(u.EditorAssetSubsystem)
world = u.EditorLoadingAndSavingUtils.new_blank_map(False)
base = "/Game/Manhattan/"
vec = u.Vector

def point(g):
    return vec(100*g[0],100*g[2],100*g[1])

def spawn(cls,where,label,rotation=None):
    transform=u.Transform(location=where,rotation=rotation or u.Rotator())
    actor=u.AvenueGameMode.place_survey_actor(world,cls,transform)
    if not actor: raise RuntimeError("Cannot place "+label)
    actor.set_actor_label(label)
    return actor

def meshes(folder):
    for path in sorted(assets.list_assets(base+folder,recursive=True)):
        if "/StaticMeshes/" in path and " " not in path:
            mesh=assets.load_asset(path)
            if isinstance(mesh,u.StaticMesh): yield mesh

def full_geometry(mesh):
    settings=mesh.get_editor_property("nanite_settings")
    if settings.enabled:
        settings.set_editor_property("enabled",False)
        mesh.set_editor_property("nanite_settings",settings)
        assets.save_loaded_asset(mesh,False)
    return mesh

def collision(mesh):
    body=mesh.get_editor_property("body_setup")
    if body and (body.get_editor_property("collision_trace_flag")!=u.CollisionTraceFlag.CTF_USE_COMPLEX_AS_SIMPLE or not body.get_editor_property("double_sided_geometry")):
        body.set_editor_property("collision_trace_flag",u.CollisionTraceFlag.CTF_USE_COMPLEX_AS_SIMPLE)
        body.set_editor_property("double_sided_geometry",True)
        assets.save_loaded_asset(mesh,False)

def place_mesh(mesh,where,label):
    actor=spawn(u.StaticMeshActor,where,label)
    actor.static_mesh_component.set_static_mesh(mesh)
    actor.set_actor_label(label)
    actor.static_mesh_component.set_collision_profile_name("BlockAll")
    return actor

live_slots={"AvenueFlagCloth","StreetLampGlass","TeslaHeadlamp","TeslaIndicator","Ln12Mtl",
            *(f"Traffic{a}{i}" for a in (0,1) for i in range(3)), "Pedestrian0","Pedestrian1"}
def assign_lenses(component,mesh):
    for index,slot in enumerate(mesh.get_editor_property("static_materials")):
        name=str(slot.get_editor_property("material_slot_name"))
        if name in live_slots:
            target=assets.load_asset(base+"Surface/M_"+name)
            if not target: raise ValueError("Missing live finish "+name)
            component.set_material(index,target)

survey=list(meshes("Survey"))
assert len(survey)>=40, "Survey tiles missing"
for mesh in survey:
    full_geometry(mesh)
    collision(mesh)
    obj=place_mesh(mesh,vec(),mesh.get_name())
    mat=assets.load_asset(base+"Surface/M_Midtown") if assets.does_asset_exist(base+"Surface/M_Midtown") else None
    if mat: obj.static_mesh_component.set_material(0,mat)
    obj.set_editor_property("tags",["CitySkin"])
for folder,origin in [("Herald",point(street["world_origin"])),("Authored/AvenueStreet",vec()),("Street/HeraldDetails",vec()),("Authored/WinterStreet",vec()),("West36",vec())]:
    for mesh in meshes(folder):
        full_geometry(mesh)
        placed=place_mesh(mesh,origin,mesh.get_name())
        if folder in ("Herald","West36"):
            collision(mesh)
        else:
            placed.static_mesh_component.set_collision_profile_name("NoCollision")
        assign_lenses(placed.static_mesh_component,mesh)
        if folder=="Authored/WinterStreet": placed.set_editor_property("tags",["LampGlass"])
        if folder=="Authored/AvenueStreet":
            for i,mat in enumerate(placed.static_mesh_component.get_materials()):
                if mat and mat.get_name()=="EnamelVertex":
                    placed.static_mesh_component.set_material(i,assets.load_asset(base+"Surface/M_Enamel"))
        if folder in ("Herald","West36"):
            fixes={"RetailGlazing":"RetailGlazing","BuffBrick":"Buff","IndianaStone":"Limestone","OfficePanel":"OfficePanel","Window":"Window","BrightGlass":"BrightGlass","CoolWindow":"CoolWindow","WarmWindow":"WarmWindow"}
            for i,slot in enumerate(mesh.get_editor_property("static_materials")):
                stock=slot.get_editor_property("material_interface")
                if stock and stock.get_name() in fixes:
                    placed.static_mesh_component.set_material(i,assets.load_asset(base+"Surface/M_"+fixes[stock.get_name()]))
grade=full_geometry(next(meshes("Authored/GradedBase")))
collision(grade)
ground=place_mesh(grade,vec(),"Surveyed ground beneath pavement")
ground.static_mesh_component.set_material(0,assets.load_asset(base+"Surface/M_Midtown"))
ground.set_editor_property("tags",["CitySkin"])
shape=full_geometry(next(meshes("Authored/StreetCollision")))
collision(shape)
walls=place_mesh(shape,vec(),"Authored static surfaces")
walls.set_actor_hidden_in_game(True)
walls.static_mesh_component.set_editor_property("cast_shadow",False)
sun=spawn(u.DirectionalLight,vec(0,0,40000),"Winter sun",u.Rotator(roll=0,pitch=-31,yaw=135))
sun.light_component.set_mobility(u.ComponentMobility.MOVABLE)
sun.light_component.set_editor_property("atmosphere_sun_light",True)
sun.light_component.set_editor_property("intensity",6500.)
sun.light_component.set_editor_property("light_source_angle",1.65)
sun.light_component.set_editor_property("dynamic_shadow_distance_movable_light",16000)
sun.light_component.set_editor_property("dynamic_shadow_cascades",3)
spawn(u.SkyAtmosphere,vec(),"Manhattan sky")
sky=spawn(u.SkyLight,vec(0,0,20000),"Sky fill")
sky.light_component.set_mobility(u.ComponentMobility.MOVABLE)
sky.light_component.set_editor_property("source_type",u.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
sky.light_component.set_editor_property("cubemap",assets.load_asset(base+"Surface/StreetPanorama"))
# The linear street panorama has a median value near 0.09. Scale its diffuse fill
# for the 6500-lux sun so the shaded street stays readable at daylight exposure.
sky.light_component.set_editor_property("intensity",210.)
sky.light_component.set_editor_property("real_time_capture",False)
pp=spawn(u.PostProcessVolume,vec(),"Street exposure")
pp.set_editor_property("unbound",True)
settings=pp.get_editor_property("settings")
for key,value in {"auto_exposure_min_brightness":8.5,"auto_exposure_max_brightness":13.5,"auto_exposure_bias":-.6,"auto_exposure_low_percent":55.,"auto_exposure_high_percent":88.,"auto_exposure_speed_up":1.1,"auto_exposure_speed_down":.65,"motion_blur_amount":.12,"motion_blur_max":1.5,"bloom_intensity":.22}.items():
    settings.set_editor_property("override_"+key,True)
    settings.set_editor_property(key,value)
pp.set_editor_property("settings",settings)
player=point(placement["player"])
spawn(u.PlayerStart,player+vec(0,0,100),"East 33rd sidewalk",u.Rotator(yaw=-80))
car=spawn(u.load_class(None,"/Script/FifthAvenue.AvenueCar"),point(placement["car"])+vec(0,0,62),"Model 3",
    u.Rotator(yaw=math.degrees(math.atan2(placement["car_forward"][2],placement["car_forward"][0]))))
sedan=full_geometry(next(meshes("Street/SedanHull")))
exterior=next(c for c in car.get_components_by_class(u.StaticMeshComponent) if c.get_name()=="Sedan")
exterior.set_static_mesh(sedan)
assign_lenses(exterior,sedan)
def set_paint(component,mesh,material):
    # Godot's body override is shared by hood, fenders and doors. glTF drops its
    # clear coat on export. Identify the shared slot from the source primitive.
    paint_slot=mesh.get_name()+"_material_4"
    index=component.get_material_index(paint_slot)
    if index<0: raise ValueError("Missing Tesla body paint "+paint_slot)
    component.set_material(index,assets.load_asset(base+"Surface/M_"+material))
set_paint(exterior,sedan,"TeslaPaint")
for i,hub in enumerate(placement["wheel_centers"]):
    car.set_wheel(i,full_geometry(next(meshes("Street/SedanWheel"+str(i)))),point(hub))
for item in placement["labels"].values():
    name,location,normal,size=item
    obj=spawn(u.TextRenderActor,point(location),name,u.Rotator(yaw=math.degrees(math.atan2(normal[2],normal[0]))))
    comp=obj.get_component_by_class(u.TextRenderComponent)
    comp.set_text(name)
    comp.set_world_size(size*100)
    comp.set_horizontal_alignment(u.HorizTextAligment.EHTA_CENTER)
for shop in json.loads((stage/"west36-labels.json").read_text()):
    for location in shop["lamps"]:
        fixture=spawn(u.PointLight,point(location),"Fabric shop ceiling light")
        fixture.light_component.set_mobility(u.ComponentMobility.MOVABLE)
        fixture.light_component.set_editor_property("intensity",470.)
        fixture.light_component.set_editor_property("attenuation_radius",660.)
        fixture.light_component.set_editor_property("cast_shadows",False)
        fixture.light_component.set_editor_property("max_draw_distance",3400.)
        fixture.light_component.set_light_color(u.LinearColor(1.,.85,.70,1.))
    n=shop["normal"]
    sign=spawn(u.TextRenderActor,point(shop["position"]),shop["text"],u.Rotator(yaw=math.degrees(math.atan2(n[2],n[0]))))
    comp=sign.get_component_by_class(u.TextRenderComponent)
    comp.set_text(shop["text"])
    comp.set_world_size(25)
    comp.set_horizontal_alignment(u.HorizTextAligment.EHTA_CENTER)
for target,aim in street["bank_lamps"]:
    p=point(target)+point(street["world_origin"])
    lamp=spawn(u.SpotLight,p,"Vestibule downlight",u.MathLibrary.find_look_at_rotation(p,point(aim)+point(street["world_origin"])))
    lamp.light_component.set_mobility(u.ComponentMobility.MOVABLE)
    lamp.light_component.set_editor_property("attenuation_radius",470)
    lamp.light_component.set_editor_property("intensity",420)
    lamp.light_component.set_editor_property("cast_shadows",False)
    lamp.light_component.set_editor_property("max_draw_distance",2200)
def axes(raw):
    return vec(raw[0],raw[2],raw[1])

def transform(rows):
    x,y,z=axes(rows[1]),axes(rows[3]),axes(rows[2])
    rot=u.MathLibrary.make_rot_from_xz(x,z)
    sign=-1 if x.cross(y).dot(z)<0 else 1
    return u.Transform(location=point(rows[0]),rotation=rot,scale=vec(x.length(),sign*y.length(),z.length()))

barriers=spawn(u.AvenueFixtures,vec(),"Authored walls and posts")
barriers.install(assets.load_asset("/Engine/BasicShapes/Cube"),None,[transform(rows) for rows in placement["fixed_shapes"]],[],True)
barriers.set_actor_hidden_in_game(True)
barriers.get_component_by_class(u.HierarchicalInstancedStaticMeshComponent).set_editor_property("cast_shadow",False)
flakes=spawn(u.AvenueFixtures,vec(),"Windblown snow")
flakes.set_editor_property("tags",["Snowfall"])
rng=random.Random(1870)
cloud=[u.Transform(location=vec(rng.uniform(-1500,1500),rng.uniform(-1500,1500),rng.uniform(-750,750))) for _ in range(900)]
flakes.install(assets.load_asset("/Engine/BasicShapes/Plane"),assets.load_asset(base+"Surface/M_FallingSnow"),cloud,[],False)
cloud_mesh=flakes.get_component_by_class(u.HierarchicalInstancedStaticMeshComponent)
cloud_mesh.set_mobility(u.ComponentMobility.MOVABLE)
cloud_mesh.set_editor_property("cast_shadow",False)
cloud_mesh.set_editor_property("bounds_scale",3.)
flakes.set_actor_location(player,False,False)
tint=assets.load_asset(base+"Surface/M_FixtureColor")
finish_dir=base+"Authored/FixtureFinishes/Materials/"
finishes={}
for shape,items in placement["instances"].items():
    proto=full_geometry(next(meshes("Parts/"+shape)))
    groups={}
    for rows,color,colored,finish in items:
        where=rows[0]
        key=(int(where[0]//28),int(where[2]//28),colored,finish)
        transforms,colors=groups.setdefault(key,([],[]))
        transforms.append(transform(rows))
        if colored: colors.append(u.LinearColor(*color,1))
    for (_,__,colored,finish),(transforms,colors) in groups.items():
        actor=spawn(u.AvenueFixtures,vec(),shape)
        override=tint if colored else None
        if finish:
            if finish not in finishes:
                kind=placement["finish_kinds"].get(finish)
                finishes[finish]=assets.load_asset(base+"Surface/M_Reserve"+kind if kind else finish_dir+finish)
                if not finishes[finish]: raise ValueError("Missing authored finish "+finish)
            override=finishes[finish]
        actor.install(proto,override,transforms,colors,False)
for record in placement["doors"]:
    tr=transform(record["pose"])
    actor=spawn(u.AvenueDoor,tr.translation,record["kind"]+" door",tr.rotation.rotator())
    mesh=full_geometry(next(meshes("Authored/"+record["asset"])))
    collision(mesh)
    actor.get_component_by_class(u.StaticMeshComponent).set_static_mesh(mesh)
    actor.set_editor_property("revolving",record["kind"]=="Revolving")
for i,person in enumerate(placement["walkers"]):
    name=["sam","harper","jordan","maya"][person["model"]]
    prefix=base+"Citizens/"+name+"/"+name+"/SkeletalMeshes/"+name
    gait="StreetStroll" if person["pace"]<1.18 else ("StreetBrisk" if person["pace"]>1.59 else "StreetWalk")
    actor=spawn(u.AvenueTraveller,point(person["position"]),name+" "+str(i))
    actor.get_component_by_class(u.SkeletalMeshComponent).set_skeletal_mesh_asset(assets.load_asset(prefix))
    actor.set_editor_property("gait",assets.load_asset(prefix+gait))
    actor.set_editor_property("idle",assets.load_asset(prefix+"Idle_Standing"))
    actor.set_editor_property("pace",person["pace"]*100)
    actor.set_editor_property("route",[point(v) for v in person["path"]])
    # The source routes begin at the start of the current leg. The traveller
    # can already be halfway along that leg on the first frame.
    origin=vec(-20809.9,57389.1,0)
    local=[((point(v)-origin).dot(vec(.872881,.487933,0))*.01,
            (point(v)-origin).dot(vec(-.487933,.872881,0))*.01) for v in person["path"]]
    groups=[]
    for (ax,az),(bx,bz) in zip(local,local[1:]+local[:1]):
        groups.append(1 if abs(ax-bx)>15 and min(ax,bx)>65 else 0 if 15<abs(az-bz)<29 else 2)
    actor.set_editor_property("crossing_groups",groups)
    actor.set_actor_scale3d(vec(1,1,1)*(.93+(i*.037)%.14))
for i,road in enumerate(placement["traffic"]):
    path=road[::8]
    remaining=list(state["traffic_stops"][i])
    start_offset=remaining[0]-(13 if i==0 else 22)
    first=0
    stops=[]
    dist=0.
    for index,(a,b) in enumerate(zip(road,road[1:])):
        length=math.dist(a,b)
        if dist<=start_offset<dist+length: first=index//8
        while remaining and dist+length>=remaining[0]:
            t=(remaining.pop(0)-dist)/max(length,1e-6)
            stops.append(point([x+(y-x)*t for x,y in zip(a,b)]))
        dist+=length
    path=path[first:]+path[:first]
    actor=spawn(u.AvenueTraveller,point(path[0]),"Cross town vehicle "+str(i))
    actor.set_editor_property("traffic",True)
    actor.set_editor_property("avenue_traffic",i==0)
    actor.set_editor_property("stop_lines",stops)
    model=full_geometry(next(meshes("Street/CabBody"))) if i==0 else sedan
    cab=actor.get_component_by_class(u.StaticMeshComponent)
    cab.set_static_mesh(model)
    if i==1:
        set_paint(cab,model,"TrafficPaint")
    kind="CabWheel" if i==0 else "SedanWheel"
    centers=json.loads((stage/"cab_hubs.json").read_text()) if i==0 else placement["wheel_centers"]
    actor.set_editor_property("wheel_models",[full_geometry(next(meshes("Street/"+kind+str(w)))) for w in range(4)])
    actor.set_editor_property("wheel_centers",[point(h) for h in centers])
    rider="maya" if i==0 else "sam"
    actor.set_editor_property("gait",assets.load_asset(base+f"Citizens/{rider}/{rider}/SkeletalMeshes/{rider}Sit_Stand"))
    actor.set_editor_property("pace",680+90*i)
    actor.set_editor_property("route",[point(v) for v in path])
counter=spawn(u.AvenueCoffee,point(placement["counter"]),"Reserve coffee order")
counter.get_component_by_class(u.StaticMeshComponent).set_static_mesh(next(meshes("Street/Coffee")))
counter.set_editor_property("held_model",next(meshes("Street/CoffeeHand")))
barista=spawn(u.AvenueTraveller,point(placement["barista"]),"Barista",u.MathLibrary.make_rot_from_x(axes(state["barista_forward"])))
prefix=base+"Citizens/sam/sam/SkeletalMeshes/sam"
barista.get_component_by_class(u.SkeletalMeshComponent).set_skeletal_mesh_asset(assets.load_asset(prefix))
barista.set_editor_property("gait",assets.load_asset(prefix+"Idle_Standing"))
counter.set_editor_property("barista",barista)
counter.set_editor_property("brew_start",point(state["brew_start"]))
shop=state["shop"]
counter.set_editor_property("customer_spot",point(shop[0])+axes(shop[1])*610-axes(shop[3])*900+axes(shop[2])*16)
def camera_axes(g): return vec(-g[2],g[0],g[1])
grip=state["held_pose"]
counter.set_editor_property("grip",u.Transform(location=camera_axes(grip[0])*100,
    rotation=u.MathLibrary.make_rot_from_xz(camera_axes(grip[1]),camera_axes(grip[2]))))
for site,color,energy,radius,direction,angle,shadow in placement["lamps"]:
    outdoor=radius>=20 and angle>0
    lamp=spawn(u.SpotLight if angle else u.PointLight,point(site),"Street lamp" if outdoor else "Local fixture",
               u.MathLibrary.make_rot_from_x(axes(direction)))
    component=lamp.light_component
    component.set_mobility(u.ComponentMobility.MOVABLE)
    if angle:
        component.set_outer_cone_angle(angle)
        component.set_inner_cone_angle(angle*.58)
    component.set_editor_property("intensity_units",u.LightUnits.LUMENS)
    component.set_editor_property("intensity",energy*(1050 if outdoor else 560))
    component.set_editor_property("attenuation_radius",radius*100)
    component.set_editor_property("cast_shadows",shadow)
    if shadow:
        component.set_editor_property("shadow_resolution_scale",.65)
        component.set_editor_property("source_radius",14 if outdoor else 8)
    component.set_editor_property("max_draw_distance",7600 if outdoor else 3200)
    component.set_light_color(u.LinearColor(*(v**2.2 for v in color),1))
    if outdoor: lamp.set_editor_property("tags",["NightLamp"])
moon=place_mesh(assets.load_asset("/Engine/BasicShapes/Sphere"),vec(-191000,77000,329000),"Lunar surface")
moon.set_actor_scale3d(vec(98,98,98))
moon.set_editor_property("tags",["Moon"])
moon.static_mesh_component.set_mobility(u.ComponentMobility.MOVABLE)
moon.static_mesh_component.set_material(0,assets.load_asset(base+"Surface/M_Moon"))
moon.static_mesh_component.set_collision_enabled(u.CollisionEnabled.NO_COLLISION)
moon.static_mesh_component.set_editor_property("cast_shadow",False)
moon.set_actor_hidden_in_game(True)
if not u.EditorLoadingAndSavingUtils.save_map(world,base+"HeraldSquare"):
    raise RuntimeError("Unable to save Herald Square")
u.log("FIFTH MAP COMPLETE")
