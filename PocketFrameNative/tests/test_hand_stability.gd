extends SceneTree
const Hand = preload("res://scripts/rigged_hand.gd")
const Device = preload("res://scripts/handheld.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var device := Device.new()
	root.add_child(device)
	device.transform = Transform3D(Basis.from_euler(Vector3(0.4, -0.5, 0.3)).scaled(Vector3.ONE * 1.25), Vector3(0.1, 1, -0.4))
	for left in [true, false]:
		var controller := Node3D.new()
		root.add_child(controller)
		var hand := Hand.new()
		controller.add_child(hand)
		hand.build(left)
		# Recover even if an earlier frame had already corrupted a bone.
		hand.skeleton.set_bone_pose_scale(hand.bones.index_dip, Vector3.ONE * 10)
		hand.skeleton.set_bone_pose_position(hand.bones.index_dip, Vector3(0, 1, 0))
		var position_error := 0.0
		var scale_error := 0.0
		for frame in range(240):
			var angle := float(frame) * 0.08
			controller.transform = Transform3D(Basis.from_euler(Vector3(sin(angle), angle, cos(angle) * 0.4)), device.stylus_handle_position() + Vector3(sin(angle) * 0.025, 0.015, cos(angle) * 0.035))
			var mode: String = ["", "console", "stylus", "stylus", "hinge", "stylus"][int(frame / 40)]
			hand.set_game_inputs({}, Vector2.ZERO, 1.0 / 90, mode, {"grip": 1.0, "console_world": device.global_transform, "collision_device": device})
			for bone in range(hand.skeleton.get_bone_count()):
				var rest := hand.skeleton.get_bone_rest(bone)
				position_error = maxf(position_error, hand.skeleton.get_bone_pose_position(bone).distance_to(rest.origin))
				scale_error = maxf(scale_error, hand.skeleton.get_bone_pose_scale(bone).distance_to(rest.basis.get_scale()))
		print("STABILITY left=", left, " translation drift=", position_error, " scale drift=", scale_error)
		if position_error > 0.00001 or scale_error > 0.0001: failures += 1
		controller.queue_free()
	print("HAND STABILITY: ", failures, " failures")
	quit(failures)
