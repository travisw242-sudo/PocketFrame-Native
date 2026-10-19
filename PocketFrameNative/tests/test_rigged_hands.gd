extends SceneTree
const Hand = preload("res://scripts/rigged_hand.gd")
const Device = preload("res://scripts/handheld.gd")
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var device := Device.new()
	root.add_child(device)
	for left in [true, false]:
		var hand := Hand.new()
		root.add_child(hand)
		hand.build(left)
		check(hand.skeleton.get_bone_count() == 26, "Real hand rig retains metacarpals and fingertips")
		check(hand.material.get_shader_parameter("skin_color") != null and hand.material.get_shader_parameter("skin_normal") != null, "Clean skin/nail material is loaded")
		check(hand.model.scale.x > 0 and hand.model.scale.y > 0 and hand.model.scale.z > 0, "No negative-scale mirroring")
		hand.set_game_inputs({}, Vector2.ZERO, 1, "", {"grip": 0, "trigger": 0})
		var open := hand.fingertip_position()
		hand.set_game_inputs({}, Vector2.ZERO, 1, "", {"grip": 0, "trigger": 1})
		check(hand.fingertip_position().distance_to(open) > 0.015, "Analog trigger moves actual imported fingertip")
		for size in [0.8, 1.0, 1.25, 1.6, 2.0]:
			device.global_transform = Transform3D(Basis.from_euler(Vector3(0.3, -0.5, 0.2)).scaled(Vector3.ONE * size), Vector3(0.1, 1, -0.4))
			hand.set_game_inputs({}, Vector2.ZERO, 1, "console", {"console_world": device.global_transform, "collision_device": device})
			for title in hand.TITLES:
				var depth: float = hand._depth(title)
				check(depth < 0.002, "Articulated " + title + " capsule stays outside console")
			check(skin_hits(hand, device) == 0, "Imported skin stays outside shell, not only the bone endpoints")
			for stick in [Vector2.ONE, -Vector2.ONE, Vector2(-1, 1), Vector2(1, -1)]:
				hand.set_game_inputs({}, stick, 1, "console", {"console_world": device.global_transform, "collision_device": device, "thumb_press": true, "trigger": 1.0})
				var hits := skin_hits(hand, device)
				check(hits == 0, "Pressed/stick-corner imported grip left=%s size=%s stick=%s hits=%s" % [left, size, stick, hits])
			check(hand._grip_cache.size() > 0, "Settled console grips are cached")
		var began := Time.get_ticks_usec()
		for i in range(50): hand.set_game_inputs({}, Vector2.ZERO, 0.011, "console", {"console_world": device.global_transform, "collision_device": device})
		print("RIGGED HAND BENCH ", float(Time.get_ticks_usec() - began) / 50, " us/update")
		hand.set_game_inputs({}, Vector2.ZERO, 1, "stylus")
		var pinch: Vector3 = hand.HandPose.TRIPOD_POINT
		if left: pinch.x = -pinch.x
		for title in ["index", "thumb"]:
			print("PINCH ", left, " ", title, " error=", hand.fingertip_position(title).distance_to(hand.global_transform * pinch))
			check(hand.fingertip_position(title).distance_to(hand.global_transform * pinch) < 0.025, "Imported pen grip reaches actual tripod point")
		hand.set_tracking_visible(false)
		check(not hand.visible, "Tracking loss hides whole imported hand")
		hand.queue_free()
	print("RIGGED HAND TEST: %d checks, %d failures" % [checks, failures])
	quit(failures)

func skin_hits(hand: Node3D, device: Node3D) -> int:
	var mesh: Mesh = hand.skin_mesh.mesh
	var hit := 0
	var poses: Array[Transform3D] = []
	hand.skeleton.force_update_all_bone_transforms()
	for b in range(hand.skin_mesh.skin.get_bind_count()):
		var bone: int = hand.skin_mesh.skin.get_bind_bone(b)
		if bone < 0: bone = hand.skeleton.find_bone(hand.skin_mesh.skin.get_bind_name(b))
		poses.append(device.global_transform.affine_inverse() * hand.skeleton.global_transform * hand.skeleton.get_bone_global_pose(bone) * hand.skin_mesh.skin.get_bind_pose(b))
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for v in range(vertices.size()):
			var p := Vector3.ZERO
			for j in range(4): p += (poses[ids[v * 4 + j]] * vertices[v]) * weights[v * 4 + j]
			if absf(p.x) < 0.0775 and absf(p.z) < 0.045 and p.y > -0.0065 and p.y < 0.007:
				hit += 1
	return hit
