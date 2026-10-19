class_name PFRoomBuilder
extends RefCounted
## Extensible visual-room registry. Gameplay, emulator state, and AR passthrough
## are deliberately independent from the selected room.

const G = preload("res://scripts/geometry.gd")

static func available_rooms() -> Array[Dictionary]:
	return [{"id":"studio","name":"PocketFrame Studio"}]

static func build(room_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "RoomEnvironment"
	# Native build deliberately keeps only Studio. Passthrough is compositor
	# blending, not a separate opaque room or a camera-texture approximation.
	return root

static func place_dock(_room: Node3D, _pose: Transform3D) -> void:
	# Kept as the stable room API. Bedroom furniture now has fixed desk anchors;
	# Studio owns its own plinth. Neither needs a second movable table.
	pass
