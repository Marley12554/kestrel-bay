"""Inspect the persisted map independently of its construction commandlet."""
import unreal as u

world=u.EditorLoadingAndSavingUtils.load_map("/Game/Manhattan/HeraldSquare")
if not world: raise RuntimeError("Native map did not load")
actors=u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
def by(cls): return [a for a in actors if isinstance(a,cls)]
def require(ok,what):
    if not ok: raise RuntimeError(what)
surveys=[a for a in by(u.StaticMeshActor) if a.get_actor_label().startswith("Midtown_")]
require(len(surveys)==48,"Missing surveyed Midtown tiles")
require(len(by(u.PlayerStart))==1,"Player spawn")
require(len(by(u.AvenueCar))==1,"Driveable sedan")
require(len(by(u.AvenueDoor))==6,"Interactive doors")
require(len(by(u.AvenueCoffee))==1,"Coffee order counter")
people=by(u.AvenueTraveller)
require(sum(bool(a.get_editor_property("traffic")) for a in people)==2,"Traffic routes")
require(sum(a.get_editor_property("gait") is not None for a in people)==25,"Skinned civilians and barista")
require(all(len(a.get_editor_property("route"))>=2 for a in people if a.get_actor_label()!="Barista"),"Empty route")
car=by(u.AvenueCar)[0]
wheels=[c for c in car.get_components_by_class(u.StaticMeshComponent) if c.get_name().startswith("Wheel")]
require(len(wheels)==4 and all(c.static_mesh for c in wheels),"Four independent sedan wheels")
fixtures=sum(a.get_component_by_class(u.HierarchicalInstancedStaticMeshComponent).get_instance_count() for a in by(u.AvenueFixtures))
require(fixtures>=32000,"Street fixtures")
block=next(a.static_mesh_component for a in by(u.StaticMeshActor) if a.get_actor_label()=="West36")
triangles=block.static_mesh.get_num_triangles(0)
u.log(f"West 36th Street conventional mesh: {triangles} triangles")
require(not block.static_mesh.get_editor_property("nanite_settings").enabled and triangles>70000,
        "Mac storefront mesh lost architectural geometry")
materials={m.get_name() for m in block.get_materials() if m}
require({"M_Buff","M_Window","M_RetailGlazing","IndigoCloth"}.issubset(materials),"Street-facing material assignments")
require(len(by(u.SkyAtmosphere))==1 and any(a.actor_has_tag("Moon") for a in actors),"Day/night sky")
u.log(f"FIFTH LEVEL VERIFIED: {len(surveys)} survey tiles, {len(people)} street actors, {fixtures} fixture instances")

# Guard the paths that passed an actor-count check while the pilot still lost glass and blocked paint.
by_label={a.get_actor_label():a for a in actors}
paint=[a.get_component_by_class(u.HierarchicalInstancedStaticMeshComponent) for a in by(u.AvenueFixtures)
       if a!=by_label["Authored walls and posts"]]
require(all(c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION for c in paint),"Render fixtures block movement")
walls=by_label["Authored walls and posts"].get_component_by_class(u.HierarchicalInstancedStaticMeshComponent)
require(walls.get_instance_count()>150 and walls.get_collision_enabled()!=u.CollisionEnabled.NO_COLLISION,"Source barriers missing")
require(by_label["Surveyed ground beneath pavement"].static_mesh_component.static_mesh.get_num_triangles(0)>250000,"Terrain lost survey resolution")
require("M_Enamel" in [m.get_name() for m in by_label["AvenueStreet"].static_mesh_component.get_materials() if m],"Missing enamel vertex colors")
swing=next(a for a in by(u.AvenueDoor) if not a.get_editor_property("revolving"))
leaf=swing.get_component_by_class(u.StaticMeshComponent)
require(len(leaf.get_materials())>=3,"Door glass and hardware collapsed to one material")
hull=next(c.static_mesh for c in car.get_components_by_class(u.StaticMeshComponent) if c.get_name()=="Sedan")
require(not hull.get_editor_property("nanite_settings").enabled,"Lossy fallback on the Tesla hull")
require(any(a.actor_has_tag("NightLamp") and isinstance(a,u.SpotLight) for a in actors),"Street lamp cones missing")
u.log("FIFTH AUTHORED MATERIALS AND COLLISION VERIFIED")

# A headless Godot dummy renderer once returned identity for every MultiMesh transform.
# Confirm the persisted Unreal floor spans the actual room and check instance diversity.
floor_components=[c for c in paint if c.get_material(0) and c.get_material(0).get_name()=="M_ReserveTerrazzo"]
require(any(max(c.get_instance_transform(0,True).scale3d.to_tuple())>20 for c in floor_components),"Reserve floor lost its room dimensions")
positions=set()
for c in paint:
    for i in range(c.get_instance_count()):
        positions.add(tuple(round(v,1) for v in c.get_instance_transform(i,True).translation.to_tuple()))
require(len(positions)>25000,"Street pieces collapsed onto their parent origins")
u.log(f"FIFTH PLACEMENT VERIFIED: {len(positions)} distinct fixture locations")

# Probe the cooked source of the continuous ground independently of roofs, markings
# and storefront colliders which could otherwise hide a missing triangle.
ground=by_label["Surveyed ground beneath pavement"]
ignored=[a for a in actors if a!=ground]
for ix in range(-8,9):
    for iy in range(-8,9):
        x,y=-39100+300*ix,34100+300*iy
        hit=u.SystemLibrary.line_trace_single(world,u.Vector(x,y,3000),u.Vector(x,y,-2000),
            u.TraceTypeQuery.TRACE_TYPE_QUERY1,True,ignored,u.DrawDebugTrace.NONE,False)
        require(hit is not None and hit.to_tuple()[0],f"Herald Square ground missing at {x}, {y}")
u.log("FIFTH GROUND VERIFIED: 289 collision probes at Herald Square")
