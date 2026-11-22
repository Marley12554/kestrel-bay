"""Compile an address-specific exterior from surveyed walls, a dated plan and photo elevations."""

import json
import math
import struct
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

import mapbox_earcut as earcut
import numpy as np
import shapely
from shapely.geometry import Polygon, box

from grade import CACHE, OUTPUT, DATUM, EAST, NORTH, Grade, SURVEY_FOOT, polygons

REF = json.loads(Path(__file__).with_name("herald-reference.json").read_text())
ANCHOR = np.array(REF["shell_anchor_en"])
CAP = REF["podium_top_navd88_m"]
# Colours are supplied as sRGB swatches. Emission is linear light.
FINISH = {
    "BuffBrick": ("bfa789", 0.85, 0),
    "IndianaStone": ("d9c6a5", 0.78, 0),
    "Roof": ("53575b", 0.94, 0),
    "Reveal": ("766552", 0.79, 0),
    "Window": ("536b73", 0.24, 0.38),
    "WarmWindow": ("867b65", 0.31, 0.22),
    "CoolWindow": ("668086", 0.28, 0.3),
    "DarkSash": ("34413f", 0.38, 0.55),
    "Spandrel": ("2c665b", 0.48, 0.42),
    "ShopGlass": ("4d6465", 0.22, 0.45),
    "Bronze": ("8d7450", 0.36, 0.68),
    "BankRed": ("ba251f", 0.42, 0.13),
    "Granite": ("5d605c", 0.46, 0.1),
    "DoorGlass": ("425a61", 0.21, 0.43),
    "Freight": ("515c5b", 0.58, 0.57),
    "Soffit": ("b9aa8e", 0.69, 0),
    "DisplayGlass": ("708d91", 0.23, 0.2),
    "Lining": ("947961", 0.73, 0),
    "Light": ("f6d79f", 0.42, 0),
}
EMIT = {
    "WarmWindow": [0.22, 0.15, 0.073],
    "CoolWindow": [0.065, 0.10, 0.12],
    "ShopGlass": [0.030, 0.04, 0.041],
    "DoorGlass": [0.028, 0.034, 0.039],
    "Lining": [0.045, 0.028, 0.016],
    "Light": [0.78, 0.49, 0.23],
}


class Mesh:
    def __init__(self):
        self.patches = defaultdict(list)

    def face(self, material, vertices, indices=None):
        vertices = np.asarray(vertices)
        if indices is None:
            indices = [0, 1, 2, 0, 2, 3] if len(vertices) == 4 else [0, 1, 2]
        self.patches[material].append((vertices, np.array(indices, dtype="<u4").ravel()))

    def save(self, filename):
        doc = dict(
            asset={"version": "2.0"},
            scene=0,
            scenes=[{"nodes": [0]}],
            nodes=[{"name": "HeraldExterior", "mesh": 0}],
            meshes=[{"primitives": []}],
            materials=[],
            accessors=[],
            bufferViews=[],
            buffers=[],
        )
        raw = bytearray()

        def add(data, typ, component, **extra):
            raw.extend(bytes(-len(raw) % 4))
            view = len(doc["bufferViews"])
            doc["bufferViews"].append(dict(buffer=0, byteOffset=len(raw), byteLength=data.nbytes))
            raw.extend(data.tobytes())
            doc["accessors"].append(
                dict(bufferView=view, componentType=component, count=len(data), type=typ, **extra)
            )
            return len(doc["accessors"]) - 1

        for name, parts in self.patches.items():
            color, rough, metal = FINISH[name]
            linear = [((c / 255 + 0.055) / 1.055) ** 2.4 for c in bytes.fromhex(color)]
            material = dict(
                name=name,
                pbrMetallicRoughness=dict(
                    baseColorFactor=linear + [1], roughnessFactor=rough, metallicFactor=metal
                ),
                doubleSided=True,
            )
            if name in EMIT:
                material["emissiveFactor"] = EMIT[name]
            mat = len(doc["materials"])
            doc["materials"].append(material)
            verts, normals, indices = [], [], []
            offset = 0
            for v, idx in parts:
                first = v[idx[:3]]
                n = np.cross(first[1] - first[0], first[2] - first[0])
                length = np.linalg.norm(n)
                if length < 1e-9:
                    continue
                verts.append(v)
                normals.append(np.tile(n / length, (len(v), 1)))
                indices.append(idx + offset)
                offset += len(v)
            positions = np.concatenate(verts).astype("<f4")
            bounds = dict(min=positions.min(axis=0).tolist(), max=positions.max(axis=0).tolist())
            pos = add(positions, "VEC3", 5126, **bounds)
            norm = add(np.concatenate(normals).astype("<f4"), "VEC3", 5126)
            index = add(np.concatenate(indices).astype("<u4"), "SCALAR", 5125)
            doc["meshes"][0]["primitives"].append(
                dict(attributes={"POSITION": pos, "NORMAL": norm}, indices=index, material=mat)
            )
        doc["buffers"] = [{"byteLength": len(raw)}]
        meta = json.dumps(doc, separators=(",", ":")).encode()
        meta += b" " * (-len(meta) % 4)
        raw.extend(bytes(-len(raw) % 4))
        filename.write_bytes(
            struct.pack("<4sIIII", b"glTF", 2, 28 + len(meta) + len(raw), len(meta), 0x4E4F534A)
            + meta
            + struct.pack("<II", len(raw), 0x004E4942)
            + raw
        )


class Elevation:
    """Metres along one wall, NAVD88 height, positive depth toward the street."""

    def __init__(self, a, b, mesh):
        self.a = np.array(a)
        self.length = np.linalg.norm(b - self.a)
        self.along = (b - self.a) / self.length
        self.out = np.array([self.along[1], -self.along[0]])
        self.mesh = mesh

    def pt(self, u, h, d=0.0):
        e, n = self.a + self.along * u + self.out * d
        return [e, h - DATUM, -n]

    def rect(self, l, r, b, t, d, key):
        if r > l + 0.0001 and t > b + 0.0001:
            self.mesh.face(key, [self.pt(l, b, d), self.pt(r, b, d), self.pt(r, t, d), self.pt(l, t, d)])

    def reveal(self, l, r, b, t, front, back, key):
        ring = [(l, b), (r, b), (r, t), (l, t)]
        for i, (x, y) in enumerate(ring):
            u, v = ring[(i + 1) % 4]
            self.mesh.face(
                key, [self.pt(x, y, front), self.pt(u, v, front), self.pt(u, v, back), self.pt(x, y, back)]
            )

    def trim(self, l, r, b, t, d, key):
        self.rect(l, r, b, t, d, key)
        self.reveal(l, r, b, t, 0.0, d, key)

    def cut_stone(self, polygon, key):
        for p in polygons(polygon):
            coords, ids = triangulate(p)
            self.mesh.face(key, [self.pt(u, h) for u, h in coords], ids)


def triangulate(p):
    rings = [np.asarray(r.coords)[:-1] for r in [p.exterior, *p.interiors]]
    coords = np.concatenate(rings)
    idx = earcut.triangulate_float64(coords, np.cumsum([len(r) for r in rings], dtype="uint32"))
    return coords, idx


def extract():
    objects = {}
    for _, building in ET.iterparse(CACHE / "Buildings.xml", events=("end",)):
        if building.tag != "Building":
            continue
        key = building.findtext(".//stringAttribute[@name='building_identification_number']/value")
        if key in REF["source_bins"].values():
            surfaces = {}
            for kind in ["GroundSurface", "RoofSurface", "WallSurface"]:
                surfaces[kind] = []
                for face in building.findall(".//" + kind + "//lod2MultiSurface//Polygon"):
                    rings = [
                        np.fromstring(v.text, sep=" ").reshape(-1, 3)[:-1] - [*ANCHOR, 0]
                        for v in face.iter("posList")
                    ]
                    surfaces[kind].append(rings)
            objects[key] = surfaces
        building.clear()
    if len(objects) != len(REF["source_bins"]):
        raise ValueError("Incomplete pilot CityGML extract")
    return objects


def upper_wall(face, shell, rhythms, floor_count):
    # Nearest photographed orientation gives the bay schedule. All coplanar
    # source fragments and setbacks share a continuous horizontal coordinate.
    street, ref, columns = max(rhythms, key=lambda row: face.out @ row[1].out)
    tangent = face.along @ ref.along
    width = ref.length / columns
    offset = (face.a - ref.a) @ ref.along
    bounds = shell.bounds
    openings = []
    for col in range(
        math.floor((offset + bounds[0] * tangent) / width) - 1,
        math.ceil((offset + bounds[2] * tangent) / width) + 1,
    ):
        u = ((col + 0.5) * width - offset) / tangent
        half = min(0.89, 0.31 * width)
        for floor in range(floor_count):
            h = CAP + 1.02 + floor * REF["office_floor_spacing_m"]
            left, right, bottom, top = u - half, u + half, h, h + 2.12
            aperture = box(left, bottom, right, top)
            if not shell.contains(box(left - 0.15, bottom - 0.12, right + 0.15, top + 0.18)):
                continue
            openings.append(aperture)
            face.reveal(left, right, bottom, top, 0.0, -0.19, "Reveal")
            finish = "Window"
            if (floor % 8 in [2, 3] and col % 7 < 4) or (floor % 9 == 5 and 1 <= col % 9 <= 3):
                finish = "WarmWindow"
            elif floor % 6 == 1 and col % 6 < 4:
                finish = "CoolWindow"
            face.rect(left, right, bottom, top, -0.19, finish)
            face.rect(left, right, bottom + 0.96, bottom + 1.04, -0.14, "DarkSash")
            face.trim(left - 0.04, right + 0.04, bottom - 0.08, bottom, 0.065, "IndianaStone")
    face.cut_stone(shell.difference(shapely.union_all(openings)), "BuffBrick")
    # On the south elevation two uninterrupted limestone fins flank the
    # narrow centre stack and carry the eye into the stepped crown.
    if street == "south":
        for fraction in (4 / 9, 5 / 9):
            centre = (fraction * ref.length - offset) / tangent
            for pier in polygons(shell.intersection(box(centre - 0.15, CAP, centre + 0.15, 130.0))):
                l, b, r, t = pier.bounds
                face.trim(l, r, b, t, 0.22, "IndianaStone")
    if bounds[1] < CAP + 0.1:
        for p in polygons(shell.intersection(box(bounds[0] - 1, CAP + 3.60, bounds[2] + 1, CAP + 3.76))):
            l, b, r, t = p.bounds
            face.trim(l, r, b, t, 0.085, "IndianaStone")
    return len(openings)


def top_and_roofs(objects, mesh, pts):
    coplanar = []
    for key, obj in objects.items():
        for rings in obj["RoofSurface"]:
            p = Polygon(rings[0][:, :2], [r[:, :2] for r in rings[1:]])
            coords, idx = triangulate(p)
            mesh.face("Roof", [[x, rings[0][0, 2] - DATUM, -y] for x, y in coords], idx)
        if key != REF["source_bins"]["office_tower"]:
            continue
        for rings in obj["WallSurface"]:
            v = rings[0]
            # The survey encodes outward-oriented quads, starting bottom-up.
            low, high = max(v[:, 2].min(), CAP), v[:, 2].max()
            if high - low < 0.02:
                continue
            lower_edge = next(
                (a, b)
                for a, b in zip(v, np.roll(v, -1, axis=0))
                if abs(a[2] - b[2]) < 0.001 and a[2] < high - 0.01
            )
            a, b = lower_edge[0][:2], lower_edge[1][:2]
            face = Elevation(a, b, mesh)
            found = next(
                (
                    (base, parts)
                    for base, parts in coplanar
                    if face.out @ base.out > 0.99996 and abs((a - base.a) @ base.out) < 0.065
                ),
                None,
            )
            if found is None:
                coplanar.append((face, [box(0, low, face.length, high)]))
            else:
                base, parts = found
                left, right = sorted(((a - base.a) @ base.along, (b - base.a) @ base.along))
                parts.append(box(left, low, right, high))
    rhythms = [
        (k, Elevation(pts[v["from"]], pts[v["to"]], mesh), v["columns"])
        for k, v in REF["office_rhythm"].items()
    ]
    count = 0
    for face, parts in coplanar:
        shell = shapely.union_all(parts, grid_size=0.01)
        count += upper_wall(face, shell, rhythms, REF["office_floors_above_podium"])
    return count


def studios(f, n):
    bottom, top = 20.45, CAP - 0.65
    bay = f.length / n
    for j in range(n):
        l, r = bay * j, bay * (j + 1)
        inset = min(0.50, bay * 0.12)
        a, b = l + inset, r - inset
        f.rect(l, a, bottom, top, 0, "IndianaStone")
        f.rect(b, r, bottom, top, 0, "IndianaStone")
        f.reveal(a, b, bottom, top, 0.0, -0.21, "Reveal")
        for floor in range(3):
            sill = bottom + (top - bottom) * floor / 3.0
            head = bottom + (top - bottom) * (floor + 1) / 3.0
            f.rect(a, b, sill, head, -0.21, "CoolWindow" if floor == 1 and j % 3 == 0 else "Window")
            if floor > 0:
                f.rect(a, b, sill, sill + 0.70, -0.135, "Spandrel")
            for q in [1 / 3, 2 / 3]:
                x = a + (b - a) * q
                f.rect(x - 0.038, x + 0.038, sill, head, -0.115, "DarkSash")
            f.rect(a, b, head - 0.80, head - 0.73, -0.12, "DarkSash")
        f.trim(a - 0.08, b + 0.08, bottom - 0.13, bottom, 0.10, "Granite")
    f.trim(0, f.length, top, CAP, 0.12, "IndianaStone")


def vestibule(f, a, b, h, fascia, pavement, walls, doors):
    centre = (a + b) * 0.5
    mouth = 0.842  # end of the 45-degree screens on the shared 1.19 m drum
    head = h + 2.57
    back = -4.2
    front = -0.38
    for u in (a, b):
        f.mesh.face("IndianaStone", [f.pt(u, h), f.pt(u, fascia), f.pt(u, fascia, back), f.pt(u, h, back)])
    f.mesh.face("Soffit", [f.pt(a, fascia), f.pt(b, fascia), f.pt(b, fascia, back), f.pt(a, fascia, back)])
    f.rect(a, b, h, fascia, back, "Lining")
    for u in np.arange(a + 0.26, b, 0.40):
        f.rect(u, u + 0.027, h + 0.14, fascia - 0.14, back + 0.032, "Bronze")
    f.rect(a, b, h, h + 0.15, back + 0.04, "Granite")
    floor = [
        [f.pt(a, pavement(a)), f.pt(b, pavement(b))],
        [f.pt(a, h + 0.012, -0.65), f.pt(b, h + 0.012, -0.65)],
        [f.pt(a, h + 0.012, back), f.pt(b, h + 0.012, back)],
    ]
    for edge, next_edge in zip(floor, floor[1:]):
        f.mesh.face("Granite", [edge[0], edge[1], next_edge[1], next_edge[0]])
    for l, r in [(a, centre - mouth), (centre + mouth, b)]:
        f.rect(l, r, h + 0.10, head, front, "DisplayGlass")
        f.rect(l, r, h, h + 0.10, front + 0.02, "Bronze")
        f.rect(l, l + 0.045, h, head, front + 0.045, "Bronze")
        f.rect(r - 0.045, r, h, head, front + 0.045, "Bronze")
    f.rect(a, b, head + 0.13, fascia, front, "DisplayGlass")
    f.rect(a, b, head, head + 0.13, front + 0.035, "Bronze")
    for pos in (a + 0.36, b - 0.36):
        f.rect(pos - 0.17, pos + 0.17, fascia - 0.16, fascia - 0.10, -2.65, "Light")
    ring = [f.pt(a, h, front), f.pt(a, h, back), f.pt(b, h, back), f.pt(b, h, front)]
    walls.extend([u, v] for u, v in zip(ring, ring[1:]))
    walls.extend(
        [
            [f.pt(a - 0.24, h), f.pt(centre - mouth, h, front)],
            [f.pt(centre + mouth, h, front), f.pt(b + 0.24, h)],
        ]
    )
    doors.append(
        dict(
            at=f.pt(centre, h, front - 0.842),
            yaw=math.atan2(f.out[0], -f.out[1]),
            width=b - a,
            depth=-back,
            front=front,
            floor=floor,
        )
    )


def shops(f, l, r, use, grade, labels, walls, doors, annotate):
    # Keep the head level. Each sill and threshold meets the grade just
    # outside its jamb, including either end of the sloping storefront.
    def pavement(u):
        east, north = ANCHOR + f.a + f.along * u + f.out * 0.36
        return grade.surface(east, north) + DATUM

    h = pavement((l + r) * 0.5)
    bottom, fascia = min(pavement(l), pavement(r), h) - 0.22, 19.50
    inset = 0.24
    span = r - l
    face_key = "BankRed" if use == "bank" else ("Bronze" if use == "lobby" else "IndianaStone")
    f.trim(l, r, fascia, 20.33, 0.09, face_key)
    f.trim(l, r, 20.33, 20.45, 0.16, "IndianaStone")
    f.rect(l, l + inset, bottom, fascia, 0, "IndianaStone")
    f.rect(r - inset, r, bottom, fascia, 0, "IndianaStone")
    if span < 1.35 or use == "return":
        f.rect(l, r, bottom, fascia, 0, "IndianaStone")
        walls.append([f.pt(l, h), f.pt(r, h)])
        return
    a, b = l + inset, r - inset
    recess = 1.05 if use == "lobby" else (0.58 if use == "freight" else 0.26)
    if use != "lobby":
        f.reveal(a, b, bottom, fascia, 0.0, -recess, "Reveal")
    if use == "lobby":
        vestibule(f, a, b, h, fascia, pavement, walls, doors)
    elif use == "freight":
        door_head = min(h + 2.70, fascia - 0.13)
        f.rect(a, b, h, door_head, -recess, "Freight")
        centre = (a + b) * 0.5
        f.rect(centre - 0.035, centre + 0.035, h, door_head, -recess + 0.015, "DarkSash")
        for side in (-1, 1):
            x = centre + side * 0.19
            f.rect(x - 0.035, x + 0.035, h + 0.87, h + 1.17, -recess + 0.04, "Bronze")
        f.rect(a, b, h + 0.06, h + 0.34, -recess + 0.018, "Granite")
        f.rect(a, b, door_head, fascia, -recess, "ShopGlass")
        f.rect(a, b, door_head - 0.065, door_head + 0.055, -recess + 0.055, "Bronze")
        f.mesh.face(
            "Granite",
            [
                f.pt(a, pavement(a) - 0.025),
                f.pt(b, pavement(b) - 0.025),
                f.pt(b, h + 0.015, -recess),
                f.pt(a, h + 0.015, -recess),
            ],
        )
        f.rect(a, b, fascia - 0.13, fascia - 0.08, -recess * 0.5, "Light")
    else:
        panels = max(1, round(span / 1.85))
        rail = h + 0.52
        f.rect(a, b, bottom, rail, -recess, "Granite")
        depth = -1.75
        f.reveal(a, b, rail, fascia, -recess, depth, "Soffit")
        f.rect(a, b, rail, fascia, depth, "Lining")
        f.rect(a, b, rail, fascia, -recess, "DisplayGlass")
        for k in range(panels):
            x = a + (b - a) * (k + 0.5) / panels
            f.rect(x - 0.24, x + 0.24, fascia - 0.18, fascia - 0.13, depth + 0.12, "Light")
            if (k % 3) == 1:
                f.rect(x - 0.42, x + 0.42, rail + 0.62, rail + 1.52, depth + 0.14, "Granite")
                f.rect(x - 0.34, x + 0.34, rail + 0.72, rail + 1.42, depth + 0.15, "CoolWindow")
        for k in range(1, panels):
            x = a + (b - a) * k / panels
            f.rect(x - 0.045, x + 0.045, rail, fascia, -recess + 0.06, "DarkSash")
        f.rect(a, b, fascia - 0.67, fascia - 0.60, -recess + 0.065, "Bronze")
    # The collision line follows the recessed glazing/door, including jambs.
    path = [f.pt(l, h), f.pt(a, h), f.pt(a, h, -recess), f.pt(b, h, -recess), f.pt(b, h), f.pt(r, h)]
    if use != "lobby":
        walls.extend([u, v] for u, v in zip(path, path[1:]))
    if annotate:
        word = {
            "bank": "Santander",
            "lobby": "1350",
            "FedEx": "FedEx",
            "pharmacy": "Duane Reade",
            "Playa Bowls": "PLAYA BOWLS",
        }.get(use)
        if word:
            labels.append(
                dict(
                    text=word,
                    at=f.pt((l + r) * 0.5, (fascia + 20.33) * 0.5, 0.115),
                    yaw=math.atan2(f.out[0], -f.out[1]),
                    height=0.34 if use == "bank" else 0.26,
                )
            )


def check_registration(objects):
    control = REF["survey_control"]
    current = Polygon(np.asarray(control["ring_epsg2263_us_ft"]) * SURVEY_FOOT - ANCHOR)
    ground = shapely.union_all([Polygon(r[0][:, :2]) for o in objects.values() for r in o["GroundSurface"]])
    # Tiny slivers in the 2014 shared party wall are irrelevant to the street perimeter.
    delta = ground.exterior.hausdorff_distance(current.exterior)
    top = max(r[0][:, 2].max() for o in objects.values() for r in o["RoofSurface"])
    expected = (control["ground_ft"] + control["roof_above_ground_ft"]) * SURVEY_FOOT
    if delta > 0.61 or abs(top - expected) > 0.15:
        raise ValueError(
            f"Inspect survey registration before building: outline {delta:.3f} m, roof {top-expected:.3f} m"
        )
    print(f"State Plane perimeter disagreement {delta:.5f} m; roof {top:.3f} m NAVD88")


def build():
    objects = extract()
    check_registration(objects)
    mesh = Mesh()
    grade = Grade()
    controls = np.concatenate([v[0][:, :2] for o in objects.values() for v in o["GroundSurface"]])
    pts = {k: controls[np.linalg.norm(controls - v, axis=1).argmin()] for k, v in REF["points"].items()}
    count = top_and_roofs(objects, mesh, pts)
    labels, walls, doors = [], [], []
    rows = [(row, Elevation(pts[row["from"]], pts[row["to"]], mesh)) for row in REF["podium"]]
    totals = {s: sum(f.length for r, f in rows if r["street"] == s) for s in REF["ground_frontages"]}
    used = defaultdict(float)
    for row, f in rows:
        street = row["street"]
        if not row["bays"]:
            shops(f, 0, f.length, "return", grade, labels, walls, doors, False)
            f.rect(0, f.length, 20.45, CAP, 0, "IndianaStone")
            continue
        studios(f, row["bays"])
        start, total = used[street], totals[street]
        for left, right, tenant in REF["ground_frontages"][street]:
            l, r = max(0, left * total - start), min(f.length, right * total - start)
            if r - l < 0.01:
                continue
            if tenant == "corner shop" and street in ("Sixth", "36th"):
                tenant = "Playa Bowls"
            # Each continuous signed tenant gets one label on each elevation.
            midpoint = (left + right) * 0.5 * total - start
            shops(f, l, r, tenant, grade, labels, walls, doors, r - l > 2.4 and 0 <= midpoint < f.length)
        used[street] += f.length
    mesh.save(OUTPUT / "1350-broadway.glb")

    def rounded(o):
        if isinstance(o, list):
            return [rounded(v) for v in o]
        if isinstance(o, dict):
            return {k: rounded(v) for k, v in o.items()}
        return round(float(o), 4) if isinstance(o, (float, np.floating)) else o

    info = dict(
        world_origin=[int(ANCHOR[0] - EAST), 0, int(NORTH - ANCHOR[1])],
        labels=labels,
        street_walls=walls,
        doors=doors,
    )
    (OUTPUT / "1350-street.json").write_text(json.dumps(rounded(info), separators=(",", ":")) + "\n")
    print(
        f"{count} recessed office windows, {sum(r['bays'] for r,_ in rows)} studio bays, {len(labels)} signs"
    )


if __name__ == "__main__":
    build()
