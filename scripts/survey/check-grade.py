"""Compare the shipped core to off-grid LiDAR readings and a separately baked adjacent cell."""

import argparse
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np
import rasterio

from grade import CORE, DATUM, Grade, bake, read_dem

parser = argparse.ArgumentParser()
parser.add_argument("dem", type=Path)
args = parser.parse_args()
base = Grade()
controls = np.array(
    [
        [301046.48, 64852.83],
        [301064.52, 64842.76],
        [301056.02, 64913.12],
        [301094.20, 64896.53],
        [301052.20, 64894.60],
        [301085.04, 64880.80],
        [301077.31, 64904.35],
        [301054.20, 64840.57],
    ]
)
with rasterio.open(args.dem) as src:
    observed = read_dem(src, *controls.T)
error = np.abs(np.array([base.surface(*p) + DATUM for p in controls]) - observed)
print(
    f"{len(controls)} surface controls: mean absolute error {error.mean():.3f} m; maximum {error.max():.3f} m"
)
if error.max() > 0.08:
    raise SystemExit("Surface registration failed")
with TemporaryDirectory() as temp:
    side = CORE[2] - CORE[0]
    path = Path(temp) / "east.json"
    bake(args.dem, (CORE[2], CORE[1], CORE[2] + side, CORE[3]), path)
    east = Grade(path)
    north = np.arange(CORE[1], CORE[3] + 1)
    delta = np.abs(base.height(CORE[2], north) - east.height(CORE[2], north))
    # The finished hardscape must also match between integer sample positions.
    probe = np.linspace(CORE[1], CORE[3], side * 4 + 1)
    pavement = max(abs(base.surface(CORE[2], n) - east.surface(CORE[2], n)) for n in probe)
    print(
        f"{len(north)} shared DEM vertices / {len(probe)} pavement probes; maximum seam {max(delta.max(),pavement):.5f} m"
    )
    if delta.max() > 0.001 or pavement > 0.001:
        raise SystemExit("Adjacent survey cells disagree")
