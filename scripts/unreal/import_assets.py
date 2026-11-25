"""Unreal Editor commandlet. Set FIFTH_ROOT to the repository checkout."""
import os
from pathlib import Path
import unreal as ue

root = Path(os.environ["FIFTH_ROOT"])
staging = root / "dist/unreal-staging"
assets = ue.get_editor_subsystem(ue.EditorAssetSubsystem)

def bring(path, folder):
    task = ue.AssetImportTask()
    task.filename = str(path)
    task.destination_path = "/Game/Manhattan/" + folder
    task.automated = True
    task.replace_existing = True
    task.save = True
    ue.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    if not task.imported_object_paths:
        raise RuntimeError("Import failed for "+str(path))

if os.environ.get("FIFTH_STREET_EXTRAS"):
    for name in ("WinterStreet","Coffee","CoffeeHand","SedanHull",*[f"SedanWheel{i}" for i in range(4)]):
        bring(staging/(name+".glb"),"Street")
    for part in sorted(staging.glob("Fixture*.glb")):
        if not assets.does_directory_exist("/Game/Manhattan/Parts/"+part.stem):
            bring(part,"Parts")
    bring(staging/"West36.glb","West36")
    bring(staging/"midtown.glb","Survey")
    bring(root/"preview/reserve/brew.wav","Audio")
    bring(root/"preview/reserve/door_chime.wav","Audio")
else:
    if not os.environ.get("FIFTH_CHARACTERS_ONLY"):
        if os.environ.get("FIFTH_IMPORT_SURVEY","1") == "1":
            bring(root/"preview/survey/1350-broadway.glb", "Herald")
            bring(staging/"midtown.glb", "Survey")
        bring(staging/"West36.glb","West36")
        for part in sorted([*staging.glob("Fixture*.glb"),*staging.glob("Door*.glb")]):
            bring(part,"Parts")
        for name in ["Sedan","YellowCab","HeraldDetails","AvenueStreet","WinterStreet","Coffee","CoffeeHand","SedanHull",*[f"SedanWheel{i}" for i in range(4)]]:
            bring(staging/(name+".glb"), "Street")
    for name in ["sam","maya","jordan","harper"]:
        bring(staging/(name+".glb"),"Citizens/"+name)
    for path in [*sorted((root/"preview/audio").glob("*.wav")),root/"preview/reserve/brew.wav",root/"preview/reserve/door_chime.wav"]:
        bring(path,"Audio")
    for path in sorted(staging.glob("footstep*.wav")):
        bring(path,"Audio")
    for path in [root/"preview/winter/frontage/white_sandstone_blocks_02_diffuse.jpg",root/"preview/survey/buff-running-bond.png",root/"preview/winter/assets/asphalt_snow_Diffuse.jpg",root/"preview/winter/assets/snow_02_Diffuse.jpg",root/"preview/winter/assets/lroc_color_poles_1k.jpg"]:
        if path.is_file(): bring(path,"Surface")
    ue.log("FIFTH IMPORT COMPLETE")
