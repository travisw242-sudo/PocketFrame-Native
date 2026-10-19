# Matching source — PocketFrame Native 0.1.0-preview.7

This snapshot accompanies the exact PocketFrame Native release payload. It
contains the modified Azahar core, native Godot adapter, frontend/assets,
bundled dependency sources and notices. Git histories, build outputs, caches,
ROMs, firmware, personal settings/saves and pairing credentials are excluded.
Some upstream dependency tests contain PUBLIC test certificates/example keys;
these are upstream fixtures, not any user's credentials.

## Layout

```
PocketFrameNative/       Godot project, native adapter, build/install scripts
work/AzaharSource/       complete modified emulator + vendored dependency sources
work/godot-cpp-main/     binding sources used for the adapter
extension_api.json      API definition used for Godot 4.7.2
licenses/               distributed component notices
SOURCE-MANIFEST.json    SHA256 for each source file and release binary hashes
```

Upstream Azahar base commit: bfa768727c60ad5bcb9397ad1471f8586605adf8.
The snapshot itself, including local modifications/new files, is authoritative.
Godot executable/template version: 4.7.2 stable, official build ed1daf0bf.
Original ARM64 core/adapter were built with Ubuntu 24.04 cross GCC/G++ 13,
CMake and Ninja; source/build-output freshness was checked before packaging.
Not a promise of byte-for-byte reproducible binaries: timestamps, compiler and
Git version metadata can differ when rebuilding a source archive.

## Native libraries (Ubuntu / WSL Ubuntu)

Extract this archive to a writable directory. From its root:

1. Run `bash PocketFrameNative/tools/setup-ubuntu.sh` to install build tools.
   Review this script first; package installation requires local sudo/root.
2. Run `bash PocketFrameNative/tools/build-linux-arm64.sh`.
   It defaults to two compiler jobs. Use `PF_BUILD_JOBS=2` and `PF_BUILD_DIR`
   to choose concurrency/cache location. This does NOT use the Windows build.

The core enables libretro/Vulkan, disables OpenGL and Qt/SDL desktop frontends,
and stages the resulting ARM64 core and adapter in the Godot project. The
complete configure options are in the build script. The external build cache
defaults to `~/.cache/pocketframe-arm64`; source directories are not build caches.
The adapter shares platform libstdc++ with the core (do not re-enable a static
C++ runtime in godot-cpp; that previously caused startup locale-facet crashes).

## Godot export (Windows reference workflow)

1. Download the OFFICIAL Godot 4.7.2 Windows console/editor executable from
   https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable
2. In PowerShell at this source root, run
   `./PocketFrameNative/tools/Get-LinuxExportTemplate.ps1`
   to obtain the matching official Linux ARM64 template. Its source and range
   verification are in the script. The expected template SHA256 is
   f252aaad156ca8afd614ab463445c61b9d5b4daa85e058d77586c3284d300f00.
3. Import/open `PocketFrameNative/project.godot` in that Godot editor to import
   textures/models. Use the **Steam Frame ARM64** export preset. The custom
   release template points to `../work/native-export-runtime/linux_release.arm64`.
4. Or run the audited command-line export, using your actual Godot path:

   ```powershell
   ./PocketFrameNative/tools/Export-NativeTest.ps1 -GodotExecutable 'C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe' -LicenseDirectory './licenses' -Destination './new-export'
   ```

5. Package an installer with Python 3.11+:
   `python PocketFrameNative/tools/preview/make-package.py new-export new-package`
   Keep the source archive and notices with any redistributed binaries.

Godot will report that the Linux-only extension cannot load on Windows while
importing/exporting; that is expected. The export resource audit must still pass.
The binding API is intentionally fixed to the matching Godot version.

## Licences / changes

Azahar and its local modifications are distributed under GPL-3.0 as provided in
`work/AzaharSource/LICENSE.txt`; individual upstream files retain their notices.
PocketFrame's own source retains its MIT notice, and the integrated distribution
includes the GPL emulator. Godot, godot-cpp, hand assets and bundled libraries
retain their own notices; full bundled dependency licences are in their source
directories. Do not remove these when modifying or redistributing this snapshot.
Source availability does not grant rights to Nintendo games, firmware or logos.

Unmodified Godot engine binaries are obtained from the official release above;
its MIT notice and full distributed copyright list are included under licenses/.
Standard platform libraries (libc/libstdc++/Vulkan loader and drivers) come from
SteamOS / the selected Steam Linux Runtime, not from this application bundle.
