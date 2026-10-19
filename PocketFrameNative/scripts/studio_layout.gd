extends RefCounted
## Seated-scale desk. +Z is the player's side of the dock frame.
const TABLE_SIZE := Vector3(1.20, .03, .65)
const TABLE_OFFSET := Vector3(0, -.057, -.10)
const REACH := .43
const EYE_TO_DOCK := .40

static func dock_for_head(head: Transform3D) -> Transform3D:
	var forward := -head.basis.z
	forward.y=0
	if forward.length_squared()<.0001: forward=Vector3.FORWARD
	forward=forward.normalized()
	return Transform3D(Basis.looking_at(forward,Vector3.UP),head.origin+forward*REACH+Vector3(0,-EYE_TO_DOCK,0))

static func table_for_dock(dock: Transform3D) -> Transform3D:
	return dock.translated_local(TABLE_OFFSET)
