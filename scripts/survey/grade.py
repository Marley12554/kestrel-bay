"""Survey-frame terrain shared by the DEM bake, the CityGML mesh and the player.

The core and collar are in EPSG:32118 metres. The collar meets the old flat
preview; adjacent production cells use raw samples and the same NAVD88 origin.
"""

import base64
import json
import zlib
from pathlib import Path

import numpy as np
import shapely
from shapely.geometry import Polygon

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / "dist/midtown-source"
OUTPUT = ROOT / "preview/survey"
FRAME = json.loads(Path(__file__).with_name("frame.json").read_text())
EAST, NORTH = FRAME["origin_east_north_m"]
DATUM = FRAME["origin_elevation_m"]
CORE = (301008, 64816, 301120, 64928)
COLLAR = 80
PILOT = json.loads(Path(__file__).with_name("herald-reference.json").read_text())
BINS = set(PILOT["source_bins"].values())
SURVEY_FOOT = 1200 / 3937


def polygons(geometry):
    if geometry.geom_type == "Polygon":
        if geometry.area > 1e-8:
            yield geometry
    elif hasattr(geometry, "geoms"):
        for part in geometry.geoms:
            yield from polygons(part)


def rings(facet):
    return [np.fromstring(p.text, sep=" ").reshape(-1, 3) for p in facet.iter("posList")]


def encode(array):
    return base64.b64encode(zlib.compress(array.tobytes(), 9)).decode("ascii")


def decode(value, dtype, shape):
    return np.frombuffer(zlib.decompress(base64.b64decode(value)), dtype).reshape(shape)


class Grade:
    def __init__(self, path=OUTPUT / "grade.json"):
        data = json.loads(path.read_text())
        self.x, self.n = data["origin_en"]
        self.size = data["samples"]
        self.raw = decode(data["navd88_cm"], "<i2", (self.size, self.size))
        self.core = data["core_en"]
        self.collar = data["collar"]
        edge = self.size - 1
        self.bounds = shapely.box(self.x, self.n, self.x + edge, self.n + edge)
        self.curb_scale = data["curb_pixels_per_metre"]
        self.curb = decode(data["surface_cm"], "u1", (edge * self.curb_scale,) * 2)
        x, y = np.meshgrid(np.arange(self.size) + self.x, np.arange(self.size) + self.n)
        distance = np.minimum.reduce((x - self.x, y - self.n, self.x + edge - x, self.n + edge - y))
        fade = np.clip(distance / self.collar, 0.0, 1.0)
        indices = np.minimum(np.arange(self.size) * self.curb_scale, self.curb.shape[0] - 1)
        # LiDAR already sees the pavement. Remove the modeled hardscape step at
        # the samples before adding it back on the exact sidewalk polygon.
        base = (self.raw - self.curb[np.ix_(indices, indices)]) * 0.01 - data["datum_navd88_m"]
        self.y = base * fade**2 * (3 - 2 * fade)

    def height(self, east, north):
        x = np.clip(np.asarray(east) - self.x, 0.0, self.size - 1.0)
        y = np.clip(np.asarray(north) - self.n, 0.0, self.size - 1.0)
        i = np.minimum(x.astype(int), self.size - 2)
        j = np.minimum(y.astype(int), self.size - 2)
        u, v = x - i, y - j
        a, b = self.y[j, i], self.y[j, i + 1]
        c, d = self.y[j + 1, i], self.y[j + 1, i + 1]
        return a + (b - a) * u + (d - b) * v + np.maximum(v - u, 0.0) * (c - a - d + b)

    def surface(self, east, north):
        i = int((east - self.x) * self.curb_scale)
        j = int((north - self.n) * self.curb_scale)
        if not (0 <= i < self.curb.shape[1] and 0 <= j < self.curb.shape[0]):
            return 0.0
        return self.height(east, north) + self.curb[j, i] * 0.01

    def build_triangles(self):
        i, j = np.meshgrid(np.arange(self.size - 1) + self.x, np.arange(self.size - 1) + self.n)
        starts = np.column_stack((i.ravel(), j.ravel()))[:, None, :]
        lo = starts + np.array([[0, 0], [1, 0], [1, 1], [0, 0]])
        hi = starts + np.array([[0, 0], [1, 1], [0, 1], [0, 0]])
        self.triangles = shapely.polygons(np.concatenate([lo, hi]))
        self.tree = shapely.STRtree(self.triangles)

    def drape(self, footprint):
        ids = self.tree.query(footprint, predicate="intersects")
        clipped = shapely.intersection(self.triangles[ids], footprint)
        # Each ordinary grid triangle is already triangulated. Keep all thin
        # boundary pieces too, so opposite sides of an intersection meet.
        return [p for part in clipped for p in polygons(part)]


def read_dem(src, east, north):
    from pyproj import Transformer
    from rasterio.windows import Window

    east, north = np.broadcast_arrays(east, north)
    transform = Transformer.from_crs(FRAME["horizontal_crs"], src.crs, always_xy=True)
    x, y = transform.transform(east.ravel(), north.ravel())
    col, row = ~src.transform * (x, y)
    col, row = col - 0.5, row - 0.5  # pixel centres
    i, j = np.floor(col).astype(int), np.floor(row).astype(int)
    u, v = col - i, row - j
    x0, y0 = i.min(), j.min()
    pixels = src.read(1, window=Window(x0, y0, i.max() - x0 + 2, j.max() - y0 + 2), masked=True)
    if np.ma.getmaskarray(pixels).any():
        raise ValueError("DEM has missing elevations in the requested window")
    i, j = i - x0, j - y0
    ft = (pixels[j, i] * (1 - u) + pixels[j, i + 1] * u) * (1 - v) + (
        pixels[j + 1, i] * (1 - u) + pixels[j + 1, i + 1] * u
    ) * v
    return np.asarray(ft).reshape(east.shape) * SURVEY_FOOT


def bake(dem, core=CORE, output=OUTPUT / "grade.json"):
    import xml.etree.ElementTree as ET
    import rasterio
    from affine import Affine
    from rasterio.features import rasterize

    if core[2] - core[0] != core[3] - core[1] or core[2] <= core[0]:
        raise ValueError("A production cell must be square and have positive extent")
    x, n = core[0] - COLLAR, core[1] - COLLAR
    edge = core[2] + COLLAR - x
    grid = np.arange(edge + 1)
    easting, northing = np.meshgrid(x + grid, n + grid)
    with rasterio.open(dem) as src:
        if src.crs.to_epsg() != 2263:
            raise ValueError("Expected New York Long Island US survey feet")
        heights = read_dem(src, easting, northing)
    # +N rows in this file, +Z south in Godot. Preserve the actual source
    # curb/platform heights instead of baking a curb into every DEM sample.
    bounds = shapely.box(x, n, x + edge, n + edge)
    shapes = []
    for layer in ("Plaza", "Sidewalk"):
        for _, obj in ET.iterparse(CACHE / (layer + ".xml"), events=("end",)):
            if obj.tag not in ("Square", "Road"):
                continue
            for p in obj.iter("Polygon"):
                pts = rings(p)
                a = pts[0]
                if np.ptp(a[:, 2]) > 0.02 or a[0, 2] < 0.05:
                    continue
                if (
                    a[:, 0].max() < x
                    or a[:, 0].min() > x + edge
                    or a[:, 1].max() < n
                    or a[:, 1].min() > n + edge
                ):
                    continue
                poly = Polygon(a[:, :2], [r[:, :2] for r in pts[1:]])
                for part in polygons(shapely.make_valid(poly).intersection(bounds)):
                    shapes.append((part, round((a[0, 2] + (0.06 if layer == "Plaza" else 0)) * 100)))
            obj.clear()
    scale = 4
    mask = rasterize(
        sorted(shapes, key=lambda item: item[1]),
        out_shape=(edge * scale,) * 2,
        transform=Affine(1 / scale, 0, x, 0, 1 / scale, n),
        dtype="uint8",
    )
    data = dict(
        crs="EPSG:32118",
        datum_navd88_m=DATUM,
        origin_en=[x, n],
        godot_origin_en=[EAST, NORTH],
        samples=edge + 1,
        core_en=list(core),
        collar=COLLAR,
        curb_pixels_per_metre=scale,
        navd88_cm=encode(np.rint(heights * 100).astype("<i2")),
        surface_cm=encode(mask),
    )
    output.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("dem", type=Path)
    parser.add_argument("--core", type=int, nargs=4, default=CORE, metavar=("W", "S", "E", "N"))
    parser.add_argument("--out", type=Path, default=OUTPUT / "grade.json")
    args = parser.parse_args()
    bake(args.dem, args.core, args.out)
