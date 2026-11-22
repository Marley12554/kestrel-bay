"""Stream TUM's citywide LoD2 CityGML ZIPs into a bounded Midtown source extract."""
import json
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source-assets/NYC-CityGML"
CACHE = ROOT / "dist/midtown-source"
# EPSG:32118, metres. Origin at Bryant Park, east/north axes.
EAST, NORTH = json.loads((ROOT / "scripts/survey/frame.json").read_text())["origin_east_north_m"]
HALF_X, HALF_Y = 1050, 1200
LAYERS = ["Buildings", "Roadbed", "Intersection", "Sidewalk", "Plaza"]
START = re.compile(rb"<(?:core:)?cityObjectMember>")
END = re.compile(rb"</(?:core:)?cityObjectMember>")
POINT = re.compile(rb"<gml:(?:lowerCorner|posList)(?: [^>]*)?>([-.\d]+) ([-.\d]+)")

def records(stream):
    buffer = b""
    inside = False
    while chunk := stream.read(1024 * 1024):
        buffer += chunk
        while True:
            if not inside:
                start = START.search(buffer)
                if not start:
                    buffer = buffer[-32:]
                    break
                buffer = buffer[start.end():]
                inside = True
            end = END.search(buffer)
            if not end:
                break
            yield buffer[:end.start()]
            buffer = buffer[end.end():]
            inside = False
    if inside:
        raise ValueError("Truncated CityGML object")

def extract(layer):
    archive, = SOURCE.glob(f"*{layer}*.zip")
    target = CACHE / (layer + ".xml")
    count = 0
    with subprocess.Popen(["unzip", "-p", str(archive), "*.gml"], stdout=subprocess.PIPE) as pipe, target.with_suffix(".tmp").open("wb") as out:
        out.write(b"<objects>")
        for record in records(pipe.stdout):
            coord = POINT.search(record)
            if coord and abs(float(coord[1])-EAST) <= HALF_X and abs(float(coord[2])-NORTH) <= HALF_Y:
                # Prefixes are declared once per source archive. The local fragment is namespace-free.
                out.write(re.sub(rb"(<\/?|\s)(?:[a-zA-Z]+):(?=[\w]+[\s=>/])", rb"\1", record))
                count += 1
        if pipe.wait() or not count:
            raise ValueError(f"Incomplete {layer} extract ({count} objects)")
        out.write(b"</objects>")
    target.with_suffix(".tmp").replace(target)
    print(f"{layer}: {count} objects", flush=True)

if __name__ == "__main__":
    CACHE.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(extract, LAYERS))
