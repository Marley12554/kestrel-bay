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
