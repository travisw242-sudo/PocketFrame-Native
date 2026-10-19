# PocketFrame Native 0.1.0-preview.7

Experimental standalone Steam Frame build: Linux ARM64, Vulkan and OpenXR.

## Download and install

Download **PocketFrame-Native-0.1.0-preview.7.zip** below and extract it completely. Read **START-HERE.md** before installing. The ZIP contains the app, installer, matching source and component notices. Source is now directly browsable in the repository; GitHub's automatic “Source code” downloads contain source, not the playable app.

Requires a developer-mode Steam Frame, Valve devkit pairing and Steam Linux Runtime 4 ARM64. No root or firmware flashing is needed. The app runs standalone after installation.

**No games or firmware are included.** Add your own legally obtained dumps on the headset at:

```text
/home/steamos/.local/share/pocketframe-native/games/
```

Restart PocketFrame after adding games. Save in-game before ejecting or quitting.

## In this update

Separate **Studio · virtual room** and **AR · passthrough** buttons stay at the top of the Y menu while scrolling. The current view is clearly indicated. Hold the free right controller's physical top **Y** button for about one second to open settings.

Includes the existing virtual cartridges, hands, stylus, hinge/volume/3D controls, ten shells and 1x/2x/3x quality choices.

## Validation and limitations

Automated menu tests: 32 checks passed. Native shell: 14 passed. Shell picker: 15 passed. Package audit, installation/startup on the owner's Frame and ZIP integrity checks passed. The new environment buttons still need the owner's physical in-headset verification. Compatibility, sustained performance and sleep/wake require broader testing.

Unsigned experimental community software, not a Steam Store or certified release. AR has no real-furniture collision/occlusion; stay seated in a clear space. Keep the included source and notices with redistributed binaries.

## SHA-256

For **PocketFrame-Native-0.1.0-preview.7.zip** (144,446,512 bytes):

```text
b7d90603b600a8aad1fa4446742b7793673eb301d934652cd100c14b9b3cb54d
```

Checksums help detect corruption; they do not authenticate an untrusted publisher.
