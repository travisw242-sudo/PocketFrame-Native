# Source layout and provenance

The source import comes from **Matching-Source.zip** in the published
**0.1.0-preview.7** release. App/core code is unchanged; the single optional
upstream test-data pointer omitted from Git is documented below. The current
development branch reorganizes dependencies and updates build/package paths;
it is not the unfinished local preview.8 privacy rebuild. The playable download
and the preview.7 release tag are unchanged.

| Path | Contents |
| --- | --- |
| `PocketFrameNative/scripts/` | Godot console, hands, cartridges, Studio, AR and in-headset UI |
| `PocketFrameNative/native/` | Native Godot-to-emulator adapter |
| `PocketFrameNative/assets/`, `tests/`, `tools/` | Shared assets, checks and build/install/package tools |
| `third_party/azahar/` | Complete modified emulator source and vendored dependencies |
| `third_party/godot-cpp/` | Godot C++ bindings used for this release |
| `licenses/`, `extension_api.json`, `BUILDING.md` | Component notices, binding API and build instructions |

Tracked `third_party/` contains dependency **source**, not build caches.
Ignored `work/` is reserved for downloaded export templates and legacy local
build outputs. Vendoring keeps the exact modified core and dependencies available
without relying on changing download links. GitHub marks this tree as vendored
so third-party code does not dominate the language statistics.

Azahar base commit: `bfa768727c60ad5bcb9397ad1471f8586605adf8`.
Local changes to that base are included in full; this is not an unmodified
upstream checkout. Do not infer that the base commit alone recreates this core.
Upstream project: https://github.com/azahar-emu/azahar

Godot/editor and export template: **4.7.2 stable**, official build `ed1daf0bf`.
The bundled binding API and godot-cpp snapshot are the ones used by this release.
See BUILDING.md for the reference toolchain and platform/runtime dependencies.

`SOURCE-MANIFEST.json` records SHA-256 hashes of each original snapshot file
and the associated release binaries. Some vendored text files are normalized
between CRLF/LF by their upstream Git attributes: the historical byte checksums
apply to the original archive, not those normalized Git checkout files.
Repository documentation added after import
is not listed in that historical manifest; future source changes should be
tracked normally in Git and get a new manifest when a new release is packaged.

The historical manifest and original release archive use `work/AzaharSource/`
and `work/godot-cpp-main/`. On the development branch these map to
`third_party/azahar/` and `third_party/godot-cpp/`, respectively. The move itself
does not change dependency contents. Use Git history for changes after import;
do not treat the historical manifest as a checksum list for current main.

## Optional upstream test-data exception

The release snapshot has only a Git LFS pointer for
`third_party/azahar/externals/teakra/src/test_verifier/data/teaklite2_tests_result.bin`,
not its 357,257,824-byte dataset. That pointer is excluded here to avoid a broken
Git LFS checkout. The historical manifest still lists it; all other original
snapshot files are included, with only the line-ending normalization described
above. It is not used by the PocketFrame/core
build targets in BUILDING.md. Developers who want to run the separate upstream
Teakra verifier need to obtain that optional dataset from upstream separately.

## Development history

Public source development begins with this snapshot. Earlier development history
has not been fabricated or reconstructed. Future development should use
incremental commits.

No ROMs, personal saves, firmware, headset keys or private machine configuration
are part of this source tree. Upstream source includes public JWT test keys and
certificates; these are reproducible fixtures, not owner secrets.
