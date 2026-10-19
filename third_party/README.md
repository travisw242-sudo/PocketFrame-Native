# Third-party source

These are checked-in dependency snapshots, not temporary downloads. Keep their
licences and upstream notices intact. Nested `externals/` folders belong to the
parent project; do not flatten them or replace them with arbitrary latest versions.

| Directory | Origin / version | Local changes |
| --- | --- | --- |
| `azahar/` | [Azahar](https://github.com/azahar-emu/azahar), based on `bfa768727c60ad5bcb9397ad1471f8586605adf8` | Modified core used by preview.7; snapshot is authoritative, not the unmodified upstream commit |
| `godot-cpp/` | [Godot C++ bindings](https://github.com/godotengine/godot-cpp), snapshot bundled with preview.7 | Retained exactly as imported; used with the root `extension_api.json` for Godot 4.7.2 |

The precise godot-cpp upstream revision was not recorded in the original archive;
do not infer a version from the old `godot-cpp-main` folder name. The release's
matching-source archive and historical manifest identify the bundled files.

PocketFrame-specific code is in `../PocketFrameNative/`. Build instructions are
in `../BUILDING.md`; provenance, original paths and the optional upstream test
dataset exception are explained in `../SOURCE-NOTES.md`.

Future dependency updates should record their exact upstream revision, local
changes and test results in a dedicated commit. A separate Azahar fork can be
introduced later; this organization change does not try to reconstruct old patches.
