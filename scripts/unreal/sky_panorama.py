"""Convert the existing linear street EXR to Radiance for Unreal's cubemap importer."""
from pathlib import Path
import subprocess

import numpy as np

root = Path(__file__).resolve().parents[2]
source = root / "preview/winter/assets/urban_street_04_hdri.exr"
target = root / "dist/unreal-staging/StreetPanorama.hdr"
width, height = 1024, 512
pixels = subprocess.check_output([
    "ffmpeg", "-v", "error", "-i", str(source), "-vf", f"scale={width}:{height}",
    "-frames:v", "1", "-pix_fmt", "gbrpf32le", "-f", "rawvideo", "pipe:1",
])
rgb = np.frombuffer(pixels, "<f4").reshape(3, height, width)[[2, 0, 1]].transpose(1, 2, 0)
rgb = np.maximum(rgb, 0)
mantissa, exponent = np.frexp(rgb.max(axis=2))
scale = np.ldexp(256., -exponent)
rgbe = np.empty((height, width, 4), dtype=np.uint8)
rgbe[:, :, :3] = np.minimum(rgb * scale[:, :, None], 255)
rgbe[:, :, 3] = np.where(mantissa > 0, exponent + 128, 0)
with target.open("wb") as out:
    out.write(f"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y {height} +X {width}\n".encode())
    for row in rgbe:
        out.write(bytes((2, 2, width >> 8, width & 255)))
        for channel in row.T:
            for start in range(0, width, 128):
                chunk = channel[start:start + 128]
                out.write(bytes((len(chunk),)) + chunk.tobytes())
