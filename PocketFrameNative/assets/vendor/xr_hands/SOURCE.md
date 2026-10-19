# Godot XR Tools hand assets

Source: https://github.com/GodotVR/godot-xr-tools
Version: 4.5.1, commit aecfc894d9581cf4ca6df7fdd09098040497aa8e.
Original directory: addons/godot-xr-tools/hands.
Artist: DigitalN8m4r3 / Miodrag Sejic. Model originated in MakeHuman and was
modified in Blender and textured in Substance Painter (see About.md).

Hand models, textures and poses are distributed under the bundled CC0 waiver
(License.md). Preserve that file and the provenance with redistributed builds.
PocketFrame loads the left/right Hand_Nails glTF assets, three skin texture maps,
and the right-hand Grip, Grip 5 and Pinch Tight animations. Left pose rotations
are mirrored mathematically to the separately authored left mesh.

No XR Tools plugin, locomotion, pickup code or physics-hand code is installed.
PocketFrame now derives a one-pass Loop-refined mesh at load time and assigns
a code-defined clean skin/nail material. Original glTF/texture files are kept
unchanged; nail patches have a small outward clearance to avoid skin z-fighting.
PocketFrame's controller adapter and kinematic contact solver are local code.
The source checkout is retained under work/xr-tools-4.5.1 for reproducibility;
it is not a second runnable PocketFrame project and contains no game ROMs.
