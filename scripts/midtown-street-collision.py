"""Bake street-level collision from the Midtown survey glTF (numpy)."""
import json
import struct
from pathlib import Path

import numpy as np

from survey.grade import EAST, NORTH, Grade

grade = Grade()
root = Path(__file__).resolve().parents[1]
with (root / "dist/midtown-source/midtown.glb").open("rb") as src:
    length = struct.unpack_from("<I", src.read(20), 12)[0]
    model = json.loads(src.read(length))
    src.read(8)
    blob = src.read()

def values(index, dtype, width):
    accessor = model["accessors"][index]
    offset = model["bufferViews"][accessor["bufferView"]]["byteOffset"]
    return np.frombuffer(blob, dtype, accessor["count"] * width, offset).reshape(-1, width)

# Ground footprints intersect a horizontal cut at waist height.
walls = []
for mesh in model["meshes"]:
    group = mesh["primitives"][0]
    vertices = values(group["attributes"]["POSITION"], "<f4", 3)
    triangles = vertices[values(group["indices"], "<u4", 1).ravel()].reshape(-1, 3, 3)
    levels = triangles[:,:,1] - grade.height(EAST + triangles[:,:,0], NORTH - triangles[:,:,2])
    low = levels < 1
    cut = low.any(axis=1) & ~low.all(axis=1)
    for tri, heights in zip(triangles[cut], levels[cut]):
        points = []
        for i, a in enumerate(tri):
            b = tri[i-1]
            ah, bh = heights[i], heights[i-1]
            if (ah < 1) != (bh < 1):
                points.append(a + (b-a)*((1-ah)/(bh-ah)))
        a, b = points
        if np.linalg.norm(a-b) < .005:
            continue
        bottom_a = (a[0], a[1]-1, a[2])
        bottom_b = (b[0], b[1]-1, b[2])
        top_a = (a[0], a[1]+2, a[2])
        top_b = (b[0], b[1]+2, b[2])
        walls.extend((bottom_a, top_a, top_b, bottom_a, top_b, bottom_b))
# Save a binary resource via Godot for compact delivery.
out = root / "dist/midtown-source/walls.tres"
out.write_text('[gd_resource type="ConcavePolygonShape3D" format=3]\n[resource]\nbackface_collision = true\ndata = PackedVector3Array(' +
               ','.join(f"{v:.3f}" for point in walls for v in point) + ')\n')
