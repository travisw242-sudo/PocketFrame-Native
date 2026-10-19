# PocketFrame Native

A virtual dual-screen handheld you can hold and play in standalone Steam Frame VR—with an optional AR passthrough view.

**Experimental community preview · Linux ARM64 · Vulkan / OpenXR**

PocketFrame runs on the headset itself. A paired computer is used for installation; PC streaming is not required for normal play afterward.

## Download

[Download the Steam Frame preview](https://github.com/travisw242-sudo/PocketFrame-Native/releases/tag/v0.1.0-preview.7) — choose **PocketFrame-Native-0.1.0-preview.7.zip** from **Assets**.

Extract the entire ZIP. It includes the application, installer, instructions, component notices and **Matching-Source.zip**. GitHub's automatically generated “Source code” downloads contain the repository source, **not the playable app**.

No games, firmware, personal saves or headset pairing credentials are included. Supply your own legally obtained game dumps. Please do not upload or request ROMs in this repository.

## Features

- Hold the console with one or both hands; click each stick to lock or unlock that hand's grip.
- Insert and eject virtual game cartridges from a movable cartridge tray.
- Use the lower touchscreen with a removable stylus.
- Adjust the hinge, volume slider and stereoscopic 3D slider.
- Switch between **Studio** and supported **AR passthrough**.
- Choose from ten shell finishes and 1x, 2x or 3x rendering options.

Stereo 3D depends on the game. Higher resolution and stereo increase GPU load; compatibility and performance vary.

## Install from Windows

1. Enable Developer Mode on Steam Frame. Pair your PC using Valve's SteamOS Devkit Client and approve the pairing on the headset.
2. Keep the headset awake on the same trusted home network. Extract the complete release ZIP.
3. Open PowerShell in the extracted **App** folder and run:

   ```powershell
   ./Install-ToFrame.ps1 -Address YOUR_HEADSET_IP
   ```

4. Launch **Library → Non-Steam → Devkit Game: PocketFrame** on the headset.

Use your own headset address. The installer uses your existing Valve devkit pairing and requires **Steam Linux Runtime 4 ARM64** on the headset. It does not require root, flash firmware, disable SteamOS read-only protection or bypass SSH host verification.

This is an unsigned community package. Read the scripts before running them. If Windows blocks a downloaded script, review it and follow your normal trusted-script approval process; do not disable security protections indiscriminately.

### Alternative installation

Copy the extracted **App** folder to your paired headset and run this inside that folder:

```sh
python3 install.py --register
```

See **App/README.md** in the release for details. This avoids running the Windows PowerShell installer, but still requires the devkit pairing/runtime setup.

## Add your games

On the **headset**, put supported game dumps such as `.cci` files in:

```text
/home/steamos/.local/share/pocketframe-native/games/
```

Use **Browse Device Files** in Valve's devkit tool to transfer them. Restart PocketFrame to refresh the cartridge tray, then insert a cartridge to load its game.

**Save inside the game before ejecting a cartridge or quitting.** Quitting does not create an automatic save state. Back up your saves before updates.

## In-headset controls

| Action | Control |
| --- | --- |
| Open settings | Hold the physical **top Y button on the free right Steam controller** for about one second |
| Use settings | Point and pull trigger; right stick scrolls |
| Change environment | Select **Studio · virtual room** or **AR · passthrough**, pinned at the top of settings |
| Hold console | Grip |
| Lock/unlock a hand's grip | Press that hand's stick **down** while holding the console |
| Change appearance | Choose a shell in settings |
| Change rendering resolution | Choose quality in settings, then quit and relaunch |

Start at 1x and try 2x if performance allows. AR availability depends on the headset's local passthrough/runtime support. There is **no real-furniture collision or occlusion**: remain seated in a clear area.

## Preview status and bug reports

This is an early native port, not a finished or certified release. Game compatibility, longer sessions, sleep/wake behavior and performance need broader testing. Multiplayer is experimental; do not expose an unreviewed service to the public internet.

When reporting an issue, include the PocketFrame version, headset OS version, game title, quality/stereo settings and reproduction steps. Redact personal information from logs. Never attach ROMs, saves, firmware, pairing keys or account credentials.

## Source and credits

**The source is directly browsable here:** [Godot app](PocketFrameNative/scripts/), [native adapter](PocketFrameNative/native/), [modified Azahar core](third_party/azahar/) and [tests](PocketFrameNative/tests/).

Start with [BUILDING.md](BUILDING.md) to build it, [SOURCE-NOTES.md](SOURCE-NOTES.md) for layout/provenance, [CONTRIBUTING.md](CONTRIBUTING.md) for changes and bug reports, and [LICENSING.md](LICENSING.md) for component licences.

Development starts from an honest import of the preview.7 source, not a reconstruction of earlier development commits. Main now separates dependencies under `third_party/`; [SOURCE-NOTES.md](SOURCE-NOTES.md) explains the layout, historical paths and optional upstream test-data exception. The unchanged release tag and **Matching-Source.zip** preserve the preview snapshot. **SOURCE-MANIFEST.json** records that original archive's file and binary checksums, not a fresh manifest of main.

Built with Godot, OpenXR and a modified Azahar emulator core. Azahar and its modifications retain their GPL-3.0 licensing; PocketFrame's own source retains its MIT notice. Other components/assets retain their respective licences. Full notices accompany the release and source snapshot. Keep them and corresponding source available when redistributing.

PocketFrame is an independent community project, **not affiliated with or endorsed by Valve, Nintendo or the Azahar developers**. Game and platform names belong to their respective owners.
