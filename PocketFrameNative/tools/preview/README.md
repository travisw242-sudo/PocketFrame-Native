# PocketFrame Native Preview

Version 0.1.0-preview.7 • standalone Linux ARM64 • Vulkan / OpenXR

This is an experimental community preview, not a Steam Store release or a
Valve/Nintendo-endorsed product. The PC is not needed
to play after installation. Developer pairing is needed for this installation
method. No administrator/root access, OS changes or firmware flashing is used.

## Install / update from Windows

Extract this entire ZIP to a new folder. With Steam Frame awake on the same LAN,
run Install-ToFrame.ps1 in PowerShell with `-Address YOUR_HEADSET_IP`.
First pair this PC through Valve's SteamOS Devkit Client and approve on the headset.
The installer uses the existing pairing key; it never asks for your Steam password.
Do not disable SSH host-key checking. A new/untrusted device must be paired first.

Or copy the extracted folder to the headset, then run:
`python3 install.py --register`

Open Library > Non-Steam > Devkit Game: PocketFrame. Valve's development installer
adds the Devkit prefix; this is not a store-distributed app. Library artwork is
installed alongside the shortcut. Steam may need to refresh the library view.
A desktop entry named PocketFrame Native is also installed.

## Files and safe updates

App: ~/.local/share/pocketframe-native/releases/0.1.0-preview.7
Active version: ~/.local/share/pocketframe-native/current
Games: ~/.local/share/pocketframe-native/games
Existing settings and saves: ~/.local/share/PocketFrame Native

Put your own legally dumped supported games in the games folder. No games, keys,
firmware, account credentials or user saves are included. Updates verify files,
keep the previous version and never clear games or the user profile. Close
PocketFrame before updating. Failed validation does not switch active versions.
The manifest detects file corruption; this preview is not digitally signed.

To import copies of games from the old local test install, use
`python3 install.py --register --import-games /home/steamos/devkit-game/PocketFrameNativeAlpha_20261016/games`.
Existing names are never overwritten. Originals remain intact. No saves need
migrating: this app uses the same isolated native profile, not the Windows profile.

To roll back: close the app, then `python3 install.py --rollback --register`.
Rollback changes app binaries only; it does not roll back save files or settings.
Do not delete the old test entry/build until you are satisfied with this preview.

## In the headset

Hold physical top Y on the free RIGHT controller for 0.8 seconds. Point and
trigger to click. Native 1x / Sharp 2x / Ultra 3x save immediately; quit and
relaunch to apply. 2x and stereo may lower performance in demanding games.
Use the console's physical 3D slider for supported games/scenes.
Open Console shells > show designs to choose any of the ten Windows shell
finishes, or Classic Graphite. Changes apply immediately and save for relaunch.
While gripping the console, press DOWN on that hand's stick to lock/unlock its
grip. You can lock either or both hands, then release the grip buttons. The Y
menu also lists the headset's games-folder path. Restart after adding games.

Save INSIDE your game before using Quit app > Quit to library. Quit waits for
the emulator to close normally. It does not make a save state or save game progress
for you. Avoid forcibly stopping the app during a save.

AR requires locally available passthrough support. Real furniture has no collision
or occlusion. Stay seated in a clear area; turn AR off to return to Studio.
OpenXR focus loss pauses emulation and releases inputs; focus return resumes it.
Actual headset sleep/wake and long-session behavior still require owner testing.
Multiplayer is experimental; do not expose an unreviewed service to the internet.

## Before calling this stable

1. Save a disposable slot in-game, quit through the menu, relaunch and load it.
2. Play 20–30 minutes at your chosen quality; check audio and frame consistency.
3. Save, sleep/wake the headset, check tracking, audio and controls; do not power
   off during a save. Try AR off/on and stereo off/on after resuming.
4. Quit/relaunch without a PC connection. Keep the old build until these pass.

## Sharing

Share the complete release ZIP, including Matching-Source.zip and all notices,
not just the App subfolder. Matching-Source.zip contains the modified emulator,
native adapter, frontend and bundled dependency sources plus build instructions.
No games, personal saves, firmware, headset pairing keys or account credentials
are included. Recipients supply their own legally obtained game dumps. Review
the included component licences before redistributing a modified package.
