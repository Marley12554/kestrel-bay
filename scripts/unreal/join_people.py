"""Retain one native skinned renderer per citizen while preserving the material sections."""
import json
import struct
import sys
from pathlib import Path

def join(path):
    raw=path.read_bytes()
    size=struct.unpack_from("<I",raw,12)[0]
    doc=json.loads(raw[20:20+size])
    nodes=[(i,n) for i,n in enumerate(doc["nodes"]) if "skin" in n and "mesh" in n]
    if not nodes: raise ValueError("Missing skinned body: "+str(path))
    # Godot's exported skin resources may be separate references with the same bind table.
    first=nodes[0][1]
    pieces=[]
    for _,n in nodes:
        skin=doc["skins"][n["skin"]]
        reference=doc["skins"][first["skin"]]
        if skin["joints"]!=reference["joints"]:raise ValueError("Different bone orders")
        if any(n.get(k)!=first.get(k) for k in ("matrix","rotation","translation","scale")):raise ValueError("Different part transforms")
        pieces.extend(doc["meshes"][n["mesh"]]["primitives"])
    for _,n in nodes[1:]:
        del n["skin"],n["mesh"]
    doc["meshes"]=[{"name":path.stem.capitalize(),"primitives":pieces}]
    first["mesh"]=0
    first["name"]=path.stem.capitalize()
    # Selected gameplay clips only. Exclude rest-pose clips without motion.
    doc["animations"]=[a for a in doc.get("animations",[]) if "Street" in a.get("name","") or a.get("name") in ("Idle_Standing","Sit_Stand","Run")]
    meta=json.dumps(doc,separators=(",",":")).encode()
    meta+=b" "*(-len(meta)%4)
    tail=raw[20+size:]
    path.write_bytes(struct.pack("<4sIIII",b"glTF",2,20+len(meta)+len(tail),len(meta),0x4e4f534a)+meta+tail)

if __name__=="__main__":
    for name in ("sam","maya","jordan","harper"):join(Path(sys.argv[1])/(name+".glb"))
