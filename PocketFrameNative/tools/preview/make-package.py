"""Build a manifest-verified personal-use preview ZIP from an audited export."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("export", type=Path)
parser.add_argument("destination", type=Path)
args = parser.parse_args()
source = args.export.resolve()
destination = args.destination.resolve()
if destination.exists():
    raise SystemExit("Choose a new destination; existing packages are not overwritten")
destination.mkdir(parents=True)
for name in ["PocketFrameNative.arm64", "PocketFrameNative.pck", "libPocketFrameRuntime.so"]:
    shutil.copy2(source / name, destination / name)
shutil.copytree(source / "runtime", destination / "runtime")
shutil.copytree(source / "licenses", destination / "licenses")
tools = Path(__file__).resolve().parent
for name in ["install.py", "Install-ToFrame.ps1", "README.md", "launch.sh", "apply-library-art.py"]:
    shutil.copy2(tools / name, destination / name)
    if name == "launch.sh":
        (destination / name).write_bytes((destination / name).read_bytes().replace(b"\r\n", b"\n"))
(destination / "artwork").mkdir()
for path in (tools / "artwork").glob("*.png"):
    shutil.copy2(path, destination / "artwork" / path.name)
files = {}
for path in sorted(destination.rglob("*")):
    if path.is_file():
        if path.suffix.lower() in {".cci", ".3ds", ".cia", ".sav", ".key", ".log"}:
            raise SystemExit("Forbidden user-data file in package")
        with path.open("rb") as stream:
            files[path.relative_to(destination).as_posix()] = hashlib.file_digest(stream, "sha256").hexdigest()
(destination / "manifest.json").write_text(json.dumps({"version": "0.1.0-preview.7", "files": files}, indent=2)+"\n")
archive = destination.parent / (destination.name + ".zip")
if archive.exists():
    raise SystemExit("Archive already exists")
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as output:
    for path in destination.rglob("*"):
        if path.is_file():output.write(path, path.relative_to(destination))
print("Built personal preview:", archive)
print("Files:", len(files), "ZIP bytes:", archive.stat().st_size)
