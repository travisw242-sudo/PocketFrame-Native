extends SceneTree
const Hand = preload("res://scripts/rigged_hand.gd")
const Device = preload("res://scripts/handheld.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var device := Device.new()
	root.add_child(device)
	for left in [true, false]:
		var hand := Hand.new()
		root.add_child(hand)
		hand.build(left)
		for size in [1.0, 1.25, 1.6]:
			device.scale = Vector3.ONE * size
			device.set_lid_angle(164)
			hand.set_game_inputs({}, Vector2.ZERO, 1, "console", {"console_world": device.global_transform, "collision_device": device})
			var tip := hand.fingertip_position()
			var target := device.to_global(Vector3(-0.065 if left else 0.065, 0.006, -0.048 - 0.006 / size))
			var error := tip.distance_to(target)
			print("BUMPER left=", left, " size=", size, " error=", error, " tip=", device.to_local(tip))
			if error > 0.018: failures += 1
			# This same pose must survive grip release while stick-locked.
			hand.set_game_inputs({}, Vector2.ZERO, 1, "console", {"grip": 0.0, "console_world": device.global_transform, "collision_device": device})
			if hand.fingertip_position().distance_to(tip) > 0.0001: failures += 1
			hand.set_game_inputs({}, Vector2.ZERO, 1, "console", {"trigger": 1.0, "console_world": device.global_transform, "collision_device": device})
			if hand.fingertip_position().distance_to(tip) < 0.0002: failures += 1
			for b in range(hand.skeleton.get_bone_count()):
				if hand.skeleton.get_bone_pose_position(b).distance_to(hand.skeleton.get_bone_rest(b).origin) > 0.00001: failures += 1
		hand.queue_free()
	print("PLAYING GRIP: ", failures, " failures")
	quit(failures)
