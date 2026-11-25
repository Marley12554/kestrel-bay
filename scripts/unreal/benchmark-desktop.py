"""Measure the packaged game with a fresh profile and check the 80 FPS floor."""
import argparse
import csv
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--width", type=int, default=2560)
    parser.add_argument("--height", type=int, default=1440)
    parser.add_argument("--quality", choices=("low", "medium", "high", "ultra"), default="high")
    args = parser.parse_args()
    executable = args.executable.resolve(strict=True)
    platform = {"win32": "Windows", "darwin": "Mac"}[sys.platform]
    quality = ("low", "medium", "high", "ultra").index(args.quality)
    profile_parent = None
    if platform == "Mac":
        # The signed game can write only inside its own app container.
        with (executable.parent.parent / "Info.plist").open("rb") as handle:
            bundle = plistlib.load(handle)["CFBundleIdentifier"]
        profile_parent = Path.home() / "Library" / "Containers" / bundle / "Data" / "Library" / "Application Support"
        profile_parent.mkdir(parents=True, exist_ok=True)
    profile = Path(tempfile.mkdtemp(prefix="FifthAvenueBench-", dir=profile_parent))
    saved = profile / "Saved"
    config = saved / "Config" / platform / "GameUserSettings.ini"
    config.parent.mkdir(parents=True)
    config.write_text(f"[/Script/Engine.GameUserSettings]\nVersion=5\n\n"
                      f"[FifthAvenue]\nQuality={quality}\nFrameTarget=180\n")
    print(f"{args.width} x {args.height}, {args.quality}, GPU target 180 FPS. Reports in {profile}", flush=True)
    passed = True
    for route, flag in (("street", None), ("west36", "-AvenueBlockBench"), ("driving", "-AvenueDriveBench")):
        command = [str(executable), "-AvenueBench", "-windowed", "-unattended", "-nosplash", "-ForceRes", "-NoVSync",
                   f"-ResX={args.width}", f"-ResY={args.height}", f"-UserDir={profile}"]
        if flag:
            command.append(flag)
        with (profile / f"{route}.log").open("w") as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=300)
        report = profile / f"{route}.csv"
        (saved / "AvenueBench.csv").rename(report)
        with report.open(encoding="utf-8-sig") as handle:
            rows = list(csv.DictReader(handle))
        expected = [route, "simulated_shootout" if route == "street" else f"{route}_effects"]
        if [row["scenario"] for row in rows] != expected:
            raise RuntimeError(f"Incomplete benchmark in {report}")
        for row in rows:
            frames = int(row["frames"])
            missed = int(row["over_12_50_ms"])
            at120 = 100 * (frames - int(row["over_8_33_ms"])) / frames
            print(f'{row["scenario"]}: {1000 / float(row["mean_ms"]):.1f} FPS average, '
                  f'{at120:.1f}% at 120+ FPS, {missed}/{frames} below 80, '
                  f'worst {row["worst_ms"]} ms', flush=True)
            passed &= missed == 0
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
