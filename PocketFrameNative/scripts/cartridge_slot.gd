class_name PFCartridgeSlot
extends Node3D
## Logical rear-slot state. Spatial insertion/ejection gestures will call this
## component once controller collision/ray interaction is calibrated in VR.

signal cartridge_inserted(cartridge)
signal cartridge_ejected(cartridge)
signal cartridge_snapped(cartridge)

var cartridge
var insertion_offset := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.015))
var snap_distance := 0.035

func can_insert(candidate) -> bool:
	return candidate != null and cartridge == null and not candidate.inserted

func insert(candidate) -> bool:
	if not can_insert(candidate):
		return false
	cartridge = candidate
	candidate.set_inserted(true)
	cartridge_inserted.emit(candidate)
	return true

func insertion_transform() -> Transform3D:
	return (global_transform if is_inside_tree() else transform) * insertion_offset

func can_snap(candidate_transform: Transform3D) -> bool:
	if cartridge != null:
		return false
	return candidate_transform.origin.distance_to(insertion_transform().origin) <= snap_distance

func try_snap(candidate, candidate_transform: Transform3D) -> bool:
	if candidate == null or not can_insert(candidate) or not can_snap(candidate_transform):
		return false
	if candidate.is_inside_tree():
		candidate.global_transform = insertion_transform()
	if not insert(candidate):
		return false
	cartridge_snapped.emit(candidate)
	return true

func eject():
	var result: Variant = cartridge
	if result == null:
		return null
	cartridge = null
	result.set_inserted(false)
	cartridge_ejected.emit(result)
	return result

func has_game() -> bool:
	return cartridge != null and not cartridge.content_path.is_empty()
