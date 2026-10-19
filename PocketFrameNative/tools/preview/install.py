"""User-local, versioned Steam Frame installation. Never deletes user data."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import struct
import subprocess
import sys
import time

GAME_ID = "PocketFrame"
ROOT = Path.home() / ".local/share/pocketframe-native"
RUNTIME = Path.home() / ".local/share/Steam/steamapps/common/SteamLinuxRuntime_4-arm64/run"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def relative(name):
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\\" in name or not path.parts:
        raise ValueError("Unsafe manifest path")
    return Path(*path.parts)


def verify(folder, manifest):
    for name, expected in manifest["files"].items():
        path = folder / relative(name)
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(folder.resolve()):
            raise ValueError("Missing/unsafe file: " + name)
        if digest(path) != expected:
            raise ValueError("Checksum mismatch: " + name)


def active_process():
    # Inspect only process executable paths, never command lines or credentials.
    for item in Path("/proc").iterdir():
        if item.name.isdigit():
            try:
                if (item / "exe").resolve().name == "PocketFrameNative.arm64":
                    return True
            except OSError:
                pass
    return False


def switch_link(root, name, target):
    link = root / name
    if link.exists() and not link.is_symlink():
        raise ValueError("Refusing to replace a non-link: " + str(link))
    temporary = root / (name + ".next")
    if temporary.exists() or temporary.is_symlink():
        raise ValueError("Previous unfinished switch found: " + str(temporary))
    temporary.symlink_to(target)
    os.replace(temporary, link)


def import_games(source, destination):
    copied = 0
    if source:
        source = Path(source).resolve(strict=True)
        if not source.is_dir():
            raise ValueError("Import source is not a directory")
        for game in source.iterdir():
            if game.is_symlink() or not game.is_file() or game.suffix.lower() not in {".cci", ".3ds", ".cxi", ".3dsx"}:
                continue
            target = destination / game.name
            if target.exists():
                print("Keeping existing game:", game.name)
                continue
            # Exclusive creation; never replace or move an existing game.
            partial = destination / ("." + game.name + ".import-" + str(time.time_ns()) + ".part")
            with game.open("rb") as incoming, partial.open("xb") as outgoing:
                shutil.copyfileobj(incoming, outgoing, 4 * 1024 * 1024)
            if digest(game) != digest(partial):
                raise ValueError("Imported copy failed validation: " + game.name)
            os.link(partial, target)  # Exclusive publication, never overwrite.
            partial.unlink()  # Only this installer's verified temporary copy.
            copied += 1
    return copied


def read_shortcuts(data):
    """Read-only subset of Steam binary VDF used for shortcut artwork IDs."""
    position = 0

    def string():
        nonlocal position
        end = data.index(b"\0", position)
        value = data[position:end].decode("utf-8", errors="replace")
        position = end + 1
        return value

    def obj():
        nonlocal position
        result = {}
        while position < len(data):
            kind = data[position]
            position += 1
            if kind == 8:
                return result
            key = string()
            if kind == 0:
                result[key] = obj()
            elif kind == 1:
                result[key] = string()
            elif kind == 2:
                result[key] = struct.unpack_from("<I", data, position)[0]
                position += 4
            else:
                raise ValueError("Unsupported shortcut field type")
        return result
    return obj()


def install_artwork(base):
    found = 0
    for config in (Path.home() / ".local/share/Steam/userdata").glob("*/config/shortcuts.vdf"):
        document = read_shortcuts(config.read_bytes())
        shortcuts = document.get("shortcuts", document.get("Shortcuts", {}))
        for entry in shortcuts.values():
            if not isinstance(entry, dict) or entry.get("AppName", entry.get("appname")) != "Devkit Game: " + GAME_ID:
                continue
            app_id = entry.get("appid", entry.get("AppID"))
            if not isinstance(app_id, int):
                continue
            grid = config.parent / "grid"
            grid.mkdir(exist_ok=True)
            for source, suffix in [("portrait.png", "p.png"), ("capsule.png", ".png"), ("hero.png", "_hero.png"), ("logo.png", "_logo.png")]:
                target = grid / (str(app_id) + suffix)
                if target.exists() and digest(target) != digest(base / "artwork" / source):
                    backup = target.with_name(target.name + ".before-pocketframe-" + str(time.time_ns()))
                    shutil.copy2(target, backup)
                shutil.copy2(base / "artwork" / source, target)
            refresh = subprocess.run([sys.executable, str(base / "apply-library-art.py"), str(app_id)], capture_output=True, text=True, timeout=30)
            if refresh.returncode==0:
                print("Steam artwork API accepted the library cache refresh")
            else:
                print("Artwork files installed; live cache refresh unavailable. Library refresh may be needed.")
            found += 1
    return found


def register(base):
    helper = Path.home() / "devkit-utils/steam-client-create-shortcut"
    if not helper.is_file():
        raise ValueError("Pair this headset with Valve's Devkit Client first")
    bridge = Path.home() / "devkit-game" / GAME_ID
    bridge.parent.mkdir(exist_ok=True)
    if bridge.exists() or bridge.is_symlink():
        if not bridge.is_symlink() or bridge.resolve() != base.resolve():
            raise ValueError("An unrelated PocketFrame devkit title exists; not overwritten")
    else:
        bridge.symlink_to(base, target_is_directory=True)
    parameters = {"gameid": GAME_ID, "directory": str(base), "force_appid": "", "lepton_args": "",
                  "argv": ["./launch.sh"], "env": {},
                  "settings": {"compat_tool": "SteamLinuxRuntime_4-arm64", "steam_play": "0"}}
    result = subprocess.run([sys.executable, str(helper), "--parms", json.dumps(parameters)],
                            capture_output=True, text=True, timeout=45)
    # Do not echo Valve helper output: debug lines can contain private IPC tokens.
    if result.returncode:
        raise ValueError("Steam registration failed; existing test entry is unchanged")
    reply = json.loads(result.stdout)
    if "success" not in reply or reply.get("error"):
        raise ValueError("Steam did not confirm registration; installation remains available")
    for _ in range(6):
        if install_artwork(base):
            print("Library artwork installed")
            return
        time.sleep(1)
    print("Artwork packaged; library shortcut is not yet flushed to disk. Rerun --register to apply artwork.")


def install(source, root, manifest, check_runtime=True):
    verify(source, manifest)
    version = manifest["version"]
    if not version or any(c not in "0123456789abcdefghijklmnopqrstuvwxyz.-" for c in version):
        raise ValueError("Unsafe version name")
    root.mkdir(parents=True, exist_ok=True)
    if root.is_symlink():
        raise ValueError("Install root must not be a symlink")
    releases = root / "releases"
    releases.mkdir(exist_ok=True)
    if releases.is_symlink():
        raise ValueError("Release directory must not be a symlink")
    target = releases / version
    if target.is_symlink():
        raise ValueError("Release target must not be a symlink")
    if not target.exists():
        target.mkdir()
        for name in manifest["files"]:
            destination = target / relative(name)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / name, destination)
        shutil.copy2(source / "manifest.json", target / "manifest.json")
    verify(target, manifest)
    games = root / "games"
    games.mkdir(exist_ok=True)
    if games.is_symlink():
        raise ValueError("Game library must not be redirected through a symlink")
    if not (target / "games").exists():
        (target / "games").symlink_to(games, target_is_directory=True)
    if (target / "games").resolve() != games.resolve():
        raise ValueError("Release games path does not point at the persistent library")
    for name in ["launch.sh", "PocketFrameNative.arm64"]:
        path = target / name
        path.chmod(path.stat().st_mode | 0o100)
    if check_runtime:
        for args in [["--", "--audit-export"], ["--quit-after", "90", "--", "--desktop", "--no-emulator"]]:
            subprocess.run([str(RUNTIME), "--", str(target / "PocketFrameNative.arm64"), "--headless", "--xr-mode", "off"] + args,
                           cwd=target, env=dict(os.environ, XDG_DATA_HOME=str(root / "validation-data")), check=True, timeout=45)
    current = root / "current"
    old = current.resolve() if current.is_symlink() else None
    if old and old != target.resolve():
        if not old.is_relative_to(releases.resolve()):
            raise ValueError("Existing active version points outside this install")
        switch_link(root, "previous", old)
    switch_link(root, "current", target.resolve())
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--register", action="store_true")
    parser.add_argument("--rollback", action="store_true")
    parser.add_argument("--import-games")
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    manifest = json.loads((source / "manifest.json").read_text())
    verify(source, manifest)
    if args.verify_only:
        print("Package checksums verified; no changes made")
        return
    if platform.system() != "Linux" or platform.machine() not in {"aarch64", "arm64"}:
        raise ValueError("Install on Steam Frame Linux ARM64, not this computer")
    if active_process():
        raise ValueError("Close PocketFrame before installing/updating")
    if not RUNTIME.is_file():
        raise ValueError("Required Steam Linux Runtime 4 ARM64 is not installed")
    if args.rollback:
        previous = ROOT / "previous"
        if not previous.is_symlink() or not previous.resolve().is_relative_to((ROOT / "releases").resolve()):
            raise ValueError("No valid previous version is available")
        old_manifest = json.loads((previous / "manifest.json").read_text())
        verify(previous.resolve(), old_manifest)
        switch_link(ROOT, "current", previous.resolve())
    else:
        install(source, ROOT, manifest)
        print("Game copies imported:", import_games(args.import_games, ROOT / "games"))
    desktop = Path.home() / ".local/share/applications/pocketframe-native.desktop"
    content = '[Desktop Entry]\nType=Application\nName=PocketFrame Native\nX-PocketFrame-Managed=true\nTerminal=false\nCategories=Game;\n'
    content += 'Exec="' + str(RUNTIME) + '" -- "' + str(ROOT / "current/launch.sh") + '"\n'
    content += 'Icon=' + str(ROOT / "current/artwork/icon.png") + '\n'
    desktop.parent.mkdir(parents=True, exist_ok=True)
    if desktop.exists() and "X-PocketFrame-Managed=true" not in desktop.read_text():
        raise ValueError("An unrelated desktop entry exists; it has not been overwritten")
    desktop.write_text(content)
    if args.register:
        register(ROOT / "current")
    print("Installed: PocketFrame Native Preview")
    print("Games, native saves and settings are preserved. Old test entry remains available.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit("INSTALLATION STOPPED: " + str(error))
