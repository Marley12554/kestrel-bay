"""Package Fifth Avenue on Windows, smoke-test it, and publish its itch update."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TARGET = "marley12554/kestrel-bay:windows-unreal"


def find_butler():
    installed = shutil.which("butler")
    if installed:
        return Path(installed)
    versions = Path(os.environ["APPDATA"]) / "itch" / "broth" / "butler" / "versions"
    candidates = [p for p in versions.glob("*/butler.exe")
                  if all(part.isdigit() for part in p.parent.name.split("."))]
    if not candidates:
        raise SystemExit("Install the itch desktop app or put itch.io's butler.exe on PATH.")
    return max(candidates, key=lambda p: tuple(map(int, p.parent.name.split("."))))


def main():
    if sys.platform != "win32":
        raise SystemExit("Run this on the Windows Unreal build machine.")
    butler = find_butler()
    output = ROOT / "dist" / "unreal-windows" / "Windows"
    subprocess.run(["cmd.exe", "/d", "/c", r"scripts\unreal\package-windows.cmd"], cwd=ROOT, check=True)
    launcher = output / "FifthAvenue.exe"
    game = output / "FifthAvenue/Binaries/Win64/FifthAvenue.exe"
    if not launcher.is_file() or not game.is_file() or not any((output / "FifthAvenue/Content/Paks").glob("*.pak")):
        raise SystemExit(f"The Windows game is missing its launcher, executable or cooked assets in {output}.")
    # Keep the test settings and log out of both the player's profile and the upload.
    profile = Path(tempfile.mkdtemp(prefix="FifthAvenueRelease-"))
    log = profile / "smoke.log"
    print(f"Testing the packaged Windows game. Log: {log}", flush=True)
    subprocess.run([str(game), "-AvenueBlockTest", "-unattended", "-windowed", "-ResX=1280",
                    "-ResY=720", f"-UserDir={profile}", f"-abslog={log}"], check=True, timeout=300)
    if "Avenue block checks passed:" not in log.read_text(encoding="utf-8-sig", errors="replace"):
        raise SystemExit(f"Gameplay smoke test did not finish. See {log}.")
    (output / ".itch.toml").write_text('[[actions]]\nname = "play"\npath = "FifthAvenue.exe"\n', encoding="utf-8")
    revision = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    subprocess.run([str(butler), "validate", str(output)], check=True)
    subprocess.run([str(butler), "push", str(output), TARGET, "--userversion", revision,
                    "--ignore", "*.pdb", "--ignore", "Manifest_*.txt"], check=True)
    subprocess.run([str(butler), "status", TARGET.split(":")[0]], check=True)


if __name__ == "__main__":
    main()
