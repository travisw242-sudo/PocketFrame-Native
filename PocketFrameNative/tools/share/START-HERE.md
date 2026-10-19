# PocketFrame Native — Steam Frame standalone preview

Version 0.1.0-preview.7 • Linux ARM64 • Vulkan / OpenXR

An experimental virtual dual-screen handheld for Steam Frame. Includes Studio,
supported AR passthrough, stereo 3D, virtual cartridges, hands, stylus, hinge,
volume slider and ten shell finishes. Not endorsed by Valve or Nintendo.

## What to share

Share this COMPLETE release ZIP. It contains:

- **App/** — playable native application, installer and component notices.
- **Matching-Source.zip** — modified emulator/app and dependency sources, with
  build instructions and a source-file checksum manifest.
- **SHA256SUMS.txt** — checksums for the app payload and source archive.

No games, firmware, personal saves, account credentials or headset pairing keys
are included. Recipients supply their own legally obtained game dumps. Do not
add ROMs to this release before sharing. Keep source and notices available with
the binaries when redistributing. This package is unsigned; checksums detect
corruption, not a malicious replacement from an untrusted download source.

## Install from a Windows PC

1. Enable Developer Mode on Steam Frame, then pair your own PC through Valve's
   SteamOS Devkit Client. Approve the pairing on your headset. Keep it awake on
   the same trusted home network. This installer uses your existing pairing key.
2. Extract this entire release ZIP. Open PowerShell in **App/** and run:
   `./Install-ToFrame.ps1 -Address YOUR_HEADSET_IP`
   Use your own headset address, not another person's. The installer does not
   bypass execution policy or SSH host checking. If Windows blocks a downloaded
   script, review it and use your normal trusted-script approval process.
3. Open **Library > Non-Steam > Devkit Game: PocketFrame** on the headset.
   No PC streaming or connection is needed for normal play after installation.

Requires Steam Linux Runtime 4 ARM64 on the headset. If missing, installation
stops with an explanation rather than changing system software. No root access,
firmware flashing or SteamOS read-only changes are used.

Linux-side install is also supported: copy **App/** to the paired headset and run
`python3 install.py --register` there. More details are in **App/README.md**.

## Add games

On the HEADSET, place supported dumps such as `.cci` files in:
`/home/steamos/.local/share/pocketframe-native/games/`

Use Browse Device Files in Valve's devkit tool. Restart PocketFrame after adding
games; cartridges appear on the tray. Insert one into the rear slot to play.
Save inside the game before ejecting or quitting. Quit does not create a save state.

## Controls

- Hold physical **top Y on the free RIGHT Steam controller** for about a second
  to open settings. Point and trigger to click; right stick scrolls.
- Grip the console; **press DOWN on that hand's stick** to lock/unlock its grip.
  You can lock each hand separately and let go of the grip buttons.
- The menu includes the games-folder path, quality buttons, AR and shell picker.
- Studio and AR buttons stay at the top of the menu even while scrolling.
  Shell changes are immediate; resolution changes need quit and relaunch.
- Start at 1x; try Sharp 2x if performance allows. 3x/stereo increase GPU load.
- AR requires locally supported passthrough hardware/runtime. There is no real
  furniture collision or occlusion. Stay seated in a clear space.

## Preview limitations

Game compatibility, sustained VR performance and physical headset sleep/wake
need broader testing. Multiplayer is experimental; do not expose an unreviewed
service to the public internet. This is not a Steam Store or certified release.
Updates retain saves/settings and the persistent game library. Back up your own
saves regularly. Never share your headset pairing key or Steam credentials.
