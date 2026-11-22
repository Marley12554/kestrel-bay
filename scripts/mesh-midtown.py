"""Convert the bounded CityGML extract to a portable tiled glTF scene (numpy, mapbox-earcut)."""
from array import array
from collections import defaultdict
from pathlib import Path
import json
import struct
import xml.etree.ElementTree as ET
import zlib

import mapbox_earcut
import numpy as np
import shapely
from shapely.geometry import Polygon

from survey.grade import BINS, EAST, NORTH, PILOT, SURVEY_FOOT, Grade, polygons

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "dist/midtown-source"
LAYERS = {"Roadbed": (58, 74, 79), "Intersection": (58, 74, 79),
          "Plaza": (181, 165, 146), "Sidewalk": (177, 181, 172)}
STONE = [(205, 197, 178), (170, 179, 180), (181, 151, 132),
         (189, 183, 171), (160, 172, 178), (211, 201, 185)]

class Tile:
    def __init__(self):
        self.positions = array("f")
        self.normals = array("f")
        self.colors = bytearray()
        self.indices = array("I")

    def polygon(self, facet, base, color, street, grade, anchored=False):
        rings = []
        for tag in facet.iter("posList"):
            ring = np.fromstring(tag.text, dtype=float, sep=" ").reshape(-1, 3)
            if np.array_equal(ring[0], ring[-1]):
                ring = ring[:-1]
            if len(ring) >= 3:
                rings.append(ring)
        if not rings:
            return
        outer = rings[0]
        # Skip the underside and vertical fascia of the six-inch sidewalk solids.
        if street and (np.ptp(outer[:, 2]) > .02 or (outer[0, 2] < .05 and street in ("Plaza","Sidewalk"))):
            return
        if street:
            west, south, east, north = grade.bounds.bounds
            if outer[:,0].max() >= west and outer[:,0].min() <= east and outer[:,1].max() >= south and outer[:,1].min() <= north:
                face = shapely.make_valid(Polygon(outer[:,:2], [r[:,:2] for r in rings[1:]]))
                face = face.difference(grade.occupied)
                grade.covered.append(face.intersection(grade.bounds))
                z = outer[0,2] - base
                tag = 85 if street in ("Intersection","Roadbed") else 170
                for part in polygons(face.difference(grade.bounds)):
                    self.write_face(self.graded_rings(part, z), 0, color, street)
                for part in grade.drape(face):
                    self.write_face(self.graded_rings(part, z, grade), 0, color, street, tag)
                # Ground has a tangible curb wherever the surveyed sidewalk ends.
                if street == "Sidewalk":
                    for boundary in rings:
                        for a, b in zip(boundary, np.roll(boundary,-1,axis=0)):
                            segment = shapely.LineString([a[:2],b[:2]]).intersection(grade.bounds)
                            if segment.length < .01: continue
                            ends = np.array(segment.coords)
                            stops = np.linspace(0,1,int(np.ceil(segment.length))+1)
                            for t,u in zip(stops,stops[1:]):
                                pts = ends[0] + (ends[-1]-ends[0])*np.array([t,u,u,t])[:,None]
                                heights = grade.height(*pts.T) + np.array([0,0,z,z])
                                self.write_face([np.column_stack((pts,heights))], 0, color, None, 200)
                return
        if anchored:
            for ring in rings:
                bottom = ring[:,2] <= anchored[0]+.06
                ring[:,2] += anchored[1]
                ring[bottom,2] = base + grade.height(ring[bottom,0],ring[bottom,1]) - .04
        self.write_face(rings,base,color,street)

    @staticmethod
    def graded_rings(polygon, z, grade=None):
        result = []
        for ring in [polygon.exterior, *polygon.interiors]:
            xy = np.array(ring.coords)[:-1]
            height = np.full(len(xy), z)
            if grade is not None:
                height += grade.height(*xy.T)
            result.append(np.column_stack((xy,height)))
        return result

    def write_face(self, rings, base, color, street, tag=255):
        outer = rings[0]
        local = outer - outer[0]
        normal = np.cross(local, np.roll(local, -1, axis=0)).sum(axis=0)
        length = np.linalg.norm(normal)
        if length < 1e-7:
            return
        normal /= length
        axis = int(abs(normal).argmax())
        vertices = np.concatenate(rings)
        flat = np.delete(vertices, axis, axis=1)
        indices = mapbox_earcut.triangulate_float64(flat, np.cumsum([len(r) for r in rings], dtype=np.uint32)).reshape(-1, 3)
        if not len(indices):
            return
        # Earcut triangulates consistently in projected 2D; keep outward 3D winding.
        if street and normal[2] < 0:
            normal *= -1
        if normal[axis] * (-1 if axis == 1 else 1) < 0:
            indices = indices[:, ::-1]
        first = len(self.positions) // 3
        self.indices.frombytes((indices + first).astype('<u4').tobytes())
        xyz = np.column_stack((vertices[:,0]-EAST, vertices[:,2]-base, NORTH-vertices[:,1]))
        self.positions.frombytes(xyz.astype('<f4').tobytes())
        self.normals.extend([normal[0],normal[2],-normal[1]] * len(vertices))
        # glTF vertex colours are linear, supplied here as normalized bytes.
        rgba = bytes([round(((c/255+.055)/1.055)**2.4*255) for c in color] + [tag])
        self.colors.extend(rgba * len(vertices))

def build():
    grade = Grade()
    grade.build_triangles()
    grade.covered = []
    grade.occupied = Polygon(np.asarray(PILOT["survey_control"]["ring_epsg2263_us_ft"])*SURVEY_FOOT)
    tiles = defaultdict(Tile)
    for layer in [*LAYERS, "Buildings"]:
        objects = 0
        for _, obj in ET.iterparse(CACHE / (layer+".xml"), events=("end",)):
            if obj.tag not in ("Road","Square","Building"):
                continue
            building = layer == "Buildings"
            if building and obj.findtext(".//stringAttribute[@name='building_identification_number']/value") in BINS:
                obj.clear()
                continue
            coordinate = obj.find(".//lowerCorner") if building else obj.find(".//posList")
            x,y,z = map(float,coordinate.text.split()[:3])
            tile = tiles[(int((x-EAST)//350),int((y-NORTH)//350))]
            color = STONE[zlib.crc32(obj.get('id','').encode()) % len(STONE)] if building else LAYERS[layer]
            if building:
                polys = obj.findall(".//lod2MultiSurface//Polygon")
            else:
                polys = obj.iter("Polygon")
            anchored = False
            if building:
                upper = np.fromstring(obj.findtext(".//upperCorner"), sep=" ")
                if grade.bounds.intersects(shapely.box(x,y,upper[0],upper[1])):
                    anchored = (z, float(grade.height((x+upper[0])*.5,(y+upper[1])*.5)))
            for polygon in polys:
                tile.polygon(polygon,z if building else (-.06 if layer=="Plaza" else 0),color,None if building else layer,grade,anchored)
            objects += 1
            obj.clear()
        print(layer,objects,flush=True)
    # The old map uses a single flat backing plane between surveyed pavement
    # polygons. Fill those same gaps on grade, including recessed thresholds.
    gaps = grade.bounds.difference(shapely.union_all([grade.occupied, *grade.covered]))
    backing = tiles[(int((grade.x-EAST)//350), int((grade.n-NORTH)//350))]
    for part in grade.drape(gaps):
        backing.write_face(backing.graded_rings(part, 0., grade), 0, LAYERS["Sidewalk"], "Sidewalk", 170)
    blob=bytearray()
    doc={"asset":{"version":"2.0","generator":"Kestrel Bay · TUM / NYC Open Data"},"buffers":[],
         "bufferViews":[],"accessors":[],"scenes":[{"nodes":[]}],"scene":0,"nodes":[],"meshes":[],
         "materials":[{"name":"Survey stone and pavement","doubleSided":True,"pbrMetallicRoughness":{"metallicFactor":0,"roughnessFactor":.88}}]}
    def accessor(data,kind,component,count,**extra):
        while len(blob)%4: blob.append(0)
        view=len(doc["bufferViews"])
        doc["bufferViews"].append({"buffer":0,"byteOffset":len(blob),"byteLength":len(data)})
        blob.extend(data)
        doc["accessors"].append(dict(bufferView=view,componentType=component,count=count,type=kind,**extra))
        return len(doc["accessors"])-1
    for coord,t in sorted(tiles.items()):
        n=len(t.positions)//3
        if not n:continue
        points=np.frombuffer(t.positions,dtype='<f4').reshape(-1,3)
        pos=accessor(t.positions.tobytes(),"VEC3",5126,n,min=points.min(axis=0).tolist(),max=points.max(axis=0).tolist())
        normal=accessor(t.normals.tobytes(),"VEC3",5126,n)
        color=accessor(t.colors,"VEC4",5121,n,normalized=True)
        idx=accessor(t.indices.tobytes(),"SCALAR",5125,len(t.indices))
        i=len(doc["nodes"])
        doc["meshes"].append({"primitives":[{"attributes":{"POSITION":pos,"NORMAL":normal,"COLOR_0":color},"indices":idx,"material":0}]})
        doc["nodes"].append({"name":"Midtown_%d_%d"%coord,"mesh":i})
        doc["scenes"][0]["nodes"].append(i)
    doc["buffers"]=[{"byteLength":len(blob)}]
    meta=json.dumps(doc,separators=(',',':')).encode()
    meta+=b' '*(-len(meta)%4)
    blob+=bytes(-len(blob)%4)
    out=ROOT/"dist/midtown-source/midtown.glb"
    with out.open("wb") as f:
        f.write(struct.pack('<4sIIII',b'glTF',2,28+len(meta)+len(blob),len(meta),0x4e4f534a))
        f.write(meta);f.write(struct.pack('<II',len(blob),0x004e4942));f.write(blob)
    print(out.stat().st_size,"bytes,",sum(len(t.indices)//3 for t in tiles.values()),"triangles")

if __name__ == "__main__":
    build()
