"""Create one recipient-friendly ZIP containing App + matching source + notices."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import zipfile

parser=argparse.ArgumentParser()
parser.add_argument("app",type=Path)
parser.add_argument("destination",type=Path)
args=parser.parse_args()
project=Path(__file__).resolve().parents[2]
workspace=project.parent
app=args.app.resolve()
destination=args.destination.resolve()
if destination.exists():raise SystemExit("Choose a new destination; no existing share folder is overwritten")
destination.mkdir(parents=True)
version="0.1.0-preview.7"
app_manifest=json.loads((app/"manifest.json").read_text())
if app_manifest["version"]!=version:raise SystemExit("Version mismatch")
for name,expected in app_manifest["files"].items():
    path=app/name
    if path.is_symlink() or not path.resolve().is_relative_to(app):raise SystemExit("Unsafe payload")
    with path.open("rb") as stream:
        if hashlib.file_digest(stream,"sha256").hexdigest()!=expected:raise SystemExit("Corrupt app: "+name)
shutil.copytree(app,destination/"App")
shutil.copy2(Path(__file__).with_name("START-HERE.md"),destination/"START-HERE.md")

ignored_dirs={".git",".godot","__pycache__","CMakeFiles"}
binary_suffixes={".exe",".dll",".so",".a",".o",".obj",".pdb",".lib",".pyc"}
forbidden={".cci",".3ds",".cia",".cxi",".3dsx",".sav",".pfx",".p12"}
source_files={}
def walk(root):
    for folder,dirs,files in os.walk(root):
        dirs[:]=sorted(name for name in dirs if name not in ignored_dirs and not (Path(folder)/name).is_symlink())
        for name in sorted(files):
            path=Path(folder)/name
            if name==".git" or path.suffix.lower() in binary_suffixes:continue
            if path.suffix.lower() in forbidden:raise SystemExit("Forbidden user-data type in source: "+str(path))
            if path.is_symlink() and not path.resolve().is_relative_to(root.resolve()):raise SystemExit("Source symlink escapes root")
            if path.is_file():yield path

def add_tree(archive,root,prefix):
    for path in walk(root):add_file(archive,path,prefix/path.relative_to(root))

def add_file(archive,path,name):
    data=path.read_bytes()
    key=name.as_posix()
    archive.writestr(key,data)
    source_files[key]=hashlib.sha256(data).hexdigest()

source_zip=destination/"Matching-Source.zip"
with zipfile.ZipFile(source_zip,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for folder in ["scripts","native","assets","tests"]:
        add_tree(archive,project/folder,Path("PocketFrameNative")/folder)
    for name in ["project.godot","main.tscn","native_boot.tscn","openxr_action_map.tres","icon.svg","LICENSE","CMakeLists.txt","export_presets.cfg"]:
        add_file(archive,project/name,Path("PocketFrameNative")/name)
    add_file(archive,project/"bin/PocketFrameAzahar.gdextension",Path("PocketFrameNative/bin/PocketFrameAzahar.gdextension"))
    for name in ["build-linux-arm64.sh","setup-ubuntu.sh","linux-arm64.cmake","Export-NativeTest.ps1","Get-LinuxExportTemplate.ps1"]:
        add_file(archive,project/"tools"/name,Path("PocketFrameNative/tools")/name)
    add_tree(archive,project/"tools/preview",Path("PocketFrameNative/tools/preview"))
    add_tree(archive,project/"tools/share",Path("PocketFrameNative/tools/share"))
    add_tree(archive,workspace/"third_party/azahar",Path("third_party/azahar"))
    add_tree(archive,workspace/"third_party/godot-cpp",Path("third_party/godot-cpp"))
    add_file(archive,workspace/"extension_api.json",Path("extension_api.json"))
    add_file(archive,workspace/"third_party/README.md",Path("third_party/README.md"))
    add_tree(archive,workspace/"tests",Path("tests"))
    for name in ["LICENSE","LICENSING.md","SOURCE-NOTES.md","CONTRIBUTING.md"]:
        add_file(archive,workspace/name,Path(name))
    add_tree(archive,app/"licenses",Path("licenses"))
    add_file(archive,Path(__file__).with_name("BUILDING.md"),Path("BUILDING.md"))
    archive.writestr("SOURCE-MANIFEST.json",json.dumps({"version":version,"azahar_base_commit":"bfa768727c60ad5bcb9397ad1471f8586605adf8",
        "release_payload_sha256":app_manifest["files"],"source_files":source_files},indent=2)+"\n")
with zipfile.ZipFile(source_zip) as archive:
    bad=archive.testzip()
    if bad:raise SystemExit("Source ZIP integrity failure: "+bad)

hashes=[]
for path in sorted(destination.rglob("*")):
    if path.is_file():
        with path.open("rb") as stream:digest=hashlib.file_digest(stream,"sha256").hexdigest()
        hashes.append(digest+"  "+path.relative_to(destination).as_posix())
(destination/"SHA256SUMS.txt").write_text("\n".join(hashes)+"\n")
release=destination.parent/(destination.name+".zip")
if release.exists():raise SystemExit("Release ZIP already exists")
# Source ZIP is already compressed. Store it without expensive recompression.
with zipfile.ZipFile(release,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for path in sorted(destination.rglob("*")):
        if path.is_file():archive.write(path,path.relative_to(destination),compress_type=zipfile.ZIP_STORED if path==source_zip else zipfile.ZIP_DEFLATED)
with zipfile.ZipFile(release) as archive:
    bad=archive.testzip()
    if bad:raise SystemExit("Release ZIP integrity failure: "+bad)
print("SHARE READY:",release)
print("Release bytes:",release.stat().st_size,"Source files:",len(source_files),"Source ZIP bytes:",source_zip.stat().st_size)
