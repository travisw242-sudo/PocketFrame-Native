# Contributing to PocketFrame Native

This repository starts with the exact source snapshot for preview.7. Earlier
development was not maintained as a public, incremental Git history; this import
does not pretend otherwise. New fixes should be small, reviewable commits.

## Development

On Windows, the vendored source has long paths. Clone with long-path support
enabled for this checkout rather than changing your global Git configuration:

```sh
git clone -c core.longpaths=true https://github.com/travisw242-sudo/PocketFrame-Native.git
```

Read [BUILDING.md](BUILDING.md) for prerequisites, native build/export commands
and the exact Godot/core versions. See [SOURCE-NOTES.md](SOURCE-NOTES.md) for the
layout and third-party provenance. Use branches and pull requests for changes;
explain the problem, solution and tests. Keep unrelated refactors separate.

The native Steam Frame project is `PocketFrameNative/`. Windows app sources are
not part of this repository. Do not add downloaded engine binaries, build caches
or exported applications to Git; downloadable builds belong in Releases.

## Tests

The source-layout check requires only Python 3.11+ and does not compile or run
the emulator:

```sh
python -m unittest discover -s tests -v
```

It checks dependency paths, build-script references and Python syntax. It does
not replace a clean build or headset testing.

With the matching Godot editor installed, UI-only checks can be run from the
repository root (replace `godot` with the path to your editor executable):

```sh
godot --headless --xr-mode off --path PocketFrameNative --script res://tests/test_vr_menu.gd -- --no-emulator --desktop
godot --headless --xr-mode off --path PocketFrameNative --script res://tests/test_native_shell.gd -- --no-emulator --desktop
godot --headless --xr-mode off --path PocketFrameNative --script res://tests/test_native_shell_picker.gd -- --no-emulator --desktop
```

Import the Godot project first if its assets have not yet been imported. A native
Linux-only extension cannot load on Windows; the UI tests above do not require
that extension. Native core behavior, controller interactions, AR and VR comfort
still require the built libraries and physical hardware. Report what you actually
tested; do not describe untested hardware behavior as passing.

## Bug reports

Include the release version, headset OS, game title (no ROM), quality/stereo
settings, reproduction steps and expected/actual behavior. Redact usernames,
emails, local file paths and network addresses from any logs/screenshots.
Never upload saves, firmware, game dumps, passwords or pairing credentials.

## Licensing and privacy

Preserve component notices and document changes to upstream code. Do not replace
vendored dependencies without explaining the version and changes. See
[LICENSING.md](LICENSING.md). The public keys/certificates under upstream JWT
tests/examples are public test fixtures, not credentials for PocketFrame.

Use a GitHub private noreply address for commits if you do not want your email
public. Review `git diff --cached` before committing; `.gitignore` is a safeguard,
not a substitute for checking the files you are publishing.
