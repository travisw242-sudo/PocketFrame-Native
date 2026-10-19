extends SceneTree
const Hand = preload("res://scripts/virtual_hand.gd")
const HandPose = preload("res://scripts/hand_pose.gd")
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
	var right := Hand.new()
	root.add_child(right)
	right.build(false)
	var left := Hand.new()
	root.add_child(left)
	left.build(true)
	check(right.skeleton.get_bone_count() == 16 and left.skeleton.get_bone_count() == 16, "Both hands have wrist and three joints for each digit")
	check(right.skin_mesh.mesh.get_surface_count() == 2, "Skin and nails share one two-surface skinned mesh")
	var nail_normals: PackedVector3Array = right.skin_mesh.mesh.surface_get_arrays(1)[Mesh.ARRAY_NORMAL]
	var average := Vector3.ZERO
	for normal in nail_normals: average += normal
	check(average.y > 0, "Nails face outward from dorsal fingers")
	check(right.skin_mesh.skin.get_bind_count() == 16, "All skeleton joints have skin bind transforms")
	check(right.scale.is_equal_approx(Vector3.ONE) and left.scale.is_equal_approx(Vector3.ONE), "Mirroring does not use a negative node scale")
	check(right.bones.has("index_mcp") and right.bones.has("middle_dip") and right.bones.has("thumb_pip"), "Finger names and assignments are anatomical")
	var triangles := 0
	var weights_ok := true
	var mirrored := true
	for surface in range(2):
		var arrays: Array = right.skin_mesh.mesh.surface_get_arrays(surface)
		var left_arrays: Array = left.skin_mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var left_vertices: PackedVector3Array = left_arrays[Mesh.ARRAY_VERTEX]
		var left_points: Dictionary = {}
		for point in left_vertices:
			left_points[point.snapped(Vector3.ONE * 0.000001)] = true
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
		for vertex in range(vertices.size()):
			var point := Vector3(-vertices[vertex].x, vertices[vertex].y, vertices[vertex].z).snapped(Vector3.ONE * 0.000001)
			mirrored = mirrored and left_points.has(point)
			var sum := 0.0
			for slot in range(4):
				var weight := weights[vertex * 4 + slot]
				sum += weight
				weights_ok = weights_ok and is_finite(weight) and weight >= 0 and weight <= 1 and ids[vertex * 4 + slot] < 16
			weights_ok = weights_ok and absf(sum - 1) < 0.0001
	check(weights_ok, "All skin weights are finite, normalized and refer to valid joints")
	check(mirrored, "Left/right mesh anatomy is explicitly mirrored")
	check(triangles < 16000, "Per-hand geometry stays below 16k triangles")
	for digit in ["index", "middle", "ring", "pinky", "thumb"]:
		check(right.skeleton.get_bone_parent(right.bones[digit + "_dip"]) == right.bones[digit + "_pip"], digit + " distal joint follows middle joint")
	right.set_game_inputs({}, Vector2.ZERO, 1, "", {"grip": 1.0, "trigger": 0.0})
	check(right.finger_curls[1] > 0.9 and right.finger_curls[0] < 0.3, "Grip closes lower fingers independently of trigger finger")
	right.set_game_inputs({}, Vector2.ZERO, 1, "", {"grip": 0.0, "trigger": 1.0})
	check(right.finger_curls[0] > 0.95 and right.finger_curls[1] < 0.2, "Trigger animates index independently of grip")
	check(right._joint_values[right.bones.index_pip].x < -1 and right._joint_values[right.bones.index_dip].x < -0.7, "Index bends at middle and distal joints, not only root")
	right.set_game_inputs({}, Vector2.ZERO, 1, "", {"trigger": 0.5})
	check(right.finger_curls[0] > 0.45 and right.finger_curls[0] < 0.55, "Analog trigger half-press yields intermediate curl")
	right.set_game_inputs({}, Vector2.ZERO, 1, "console", {"console_world": Transform3D.IDENTITY})
	var before: Vector3 = right.fingertip_position("thumb")
	right.set_game_inputs({"A": true}, Vector2.ZERO, 1, "console", {"console_world": Transform3D.IDENTITY})
	check(right.thumb_press > 0.99 and right.fingertip_position("thumb").y < before.y - 0.0008, "Button press depresses thumb without pushing it through deck")
	check(right.finger_curls[3] > 0.8, "Console pose remains supported after grip release / locking")
	check(right.position.x > 0, "Console pose offsets palm away from screen edge")
	left.set_game_inputs({"UP": true}, Vector2.ZERO, 1, "console", {"console_world": Transform3D.IDENTITY})
	check(left.thumb_press > 0.99 and left.position.x < 0, "Left D-pad/thumb pose is mirrored and responds to real directional keys")
	right.set_game_inputs({}, Vector2.ZERO, 1)
	for i in range(5): right.set_game_inputs({}, Vector2.ZERO, 1.0 / 90, "", {"trigger": 1.0})
	check(right.finger_curls[0] > 0.85, "Index response is fast at 90 Hz")
	var previous := right.finger_curls[0]
	right.set_game_inputs({}, Vector2.ZERO, 0)
	check(is_equal_approx(previous, right.finger_curls[0]), "Zero elapsed time does not advance pose")
	for i in range(6): right.set_game_inputs({}, Vector2.ZERO, 1.0 / 90)
	check(right.finger_curls[0] < 0.2, "Releasing trigger promptly returns to relaxed pose")
	right.set_game_inputs({}, Vector2.ZERO, 1, "stylus")
	var pinch: Vector3 = right.global_transform * HandPose.TRIPOD_POINT
	right.skeleton.force_update_all_bone_transforms()
	var index_tip: Vector3 = right.skeleton.global_transform * right.skeleton.get_bone_global_pose(right.bones.index_dip) * Vector3(0, 0, -0.068 * 0.23)
	var thumb_tip: Vector3 = right.skeleton.global_transform * right.skeleton.get_bone_global_pose(right.bones.thumb_dip) * Vector3(0, 0, -0.064 * 0.28)
	check(index_tip.distance_to(pinch) < 0.018 and thumb_tip.distance_to(pinch) < 0.018, "Stylus pinch targets actual pen rather than a generic fist")
	check(right._joint_values[right.bones.index_mcp].x <= 0.20, "Pen grip does not hyperextend index MCP")
	check(absf(right._joint_values[right.bones.thumb_mcp].y) <= 1.25, "Thumb opposition cannot rotate through palm")
	var correct_right := HandPose.grip_transform(false)
	var correct_left := HandPose.grip_transform(true)
	check((-correct_right.basis.y).is_equal_approx(Vector3.LEFT) and (-correct_left.basis.y).is_equal_approx(Vector3.RIGHT), "Neutral grip palms face each other, not the floor")
	check((correct_right.basis * Vector3.LEFT).is_equal_approx(Vector3.FORWARD) and (correct_left.basis * Vector3.RIGHT).is_equal_approx(Vector3.FORWARD), "Anatomical thumb side matches OpenXR little-to-thumb axis")
	right.set_game_inputs({}, Vector2.ZERO, 1, "stylus", {"aim_local": Quaternion(Vector3.UP, 2.5), "pinch_world": Vector3(1, 1, 1)})
	check(right.transform.is_equal_approx(correct_right), "Pointing ray / unreachable pen target cannot rotate wrist")
	var console := Transform3D(Basis(Vector3.UP, 0.35), Vector3(0, 1, -0.5))
	for visual in [right, left]:
		visual.set_game_inputs({}, Vector2.ZERO, 1, "console", {"console_world": console})
		visual.skeleton.force_update_all_bone_transforms()
		var palm: Vector3 = console.affine_inverse() * visual.global_position
		check(absf(palm.x) > 0.079 and palm.y < 0, "Console palm is outside side edge and below screen")
		var pad: Vector3 = visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(visual.bones.thumb_dip) * Vector3(0, 0, -0.064 * 0.28)
		var control: Vector3 = console * Vector3(-0.059 if visual.is_left else 0.058, 0.014, -0.020 if visual.is_left else -0.007)
		check(pad.distance_to(control) < 0.025, "Console thumb reaches upper controls without flipping")
		var under := true
		for finger in ["middle", "ring", "pinky"]:
			var data: Dictionary = visual._digits[finger]
			var tip: Vector3 = visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(visual.bones[finger + "_dip"]) * Vector3(0, 0, -data.segments.z)
			under = under and (console.affine_inverse() * tip).y < 0.003
		check(under, "Supporting fingers stay beneath console face")
	var controller := Node3D.new()
	root.add_child(controller)
	controller.transform = Transform3D(Basis.from_euler(Vector3(0.5, 0.8, -0.3)), Vector3(0.12, 1.03, -0.4))
	right.reparent(controller, true)
	right.set_game_inputs({}, Vector2.ZERO, 1, "console", {"console_world": console})
	check(right.global_transform.is_equal_approx(HandPose.console_transform(console, false)), "Console visual grip is stable under controller rotation")
	# Stress old failure cases: wrist / finger targets cannot request 80-degree
	# MCP extension or unbounded lateral flips, even with remote aim targets.
	var limits_ok := true
	for i in range(50):
		right.set_game_inputs({}, Vector2.ZERO, 0.016, "stylus", {"aim_local": Quaternion(Vector3.UP, float(i)), "pinch_world": Vector3(i, i, -i)})
		for finger in DIGITS_FOR_LIMITS:
			var joint: Vector3 = right._joint_values[right.bones[finger + "_mcp"]]
			limits_ok = limits_ok and joint.x <= 0.201 and absf(joint.y) <= 0.281
	check(limits_ok, "Unreachable targets never produce contorted MCP joints")
	right.set_game_inputs({}, Vector2.ZERO, 1, "", {"hand_pitch": 12, "hand_roll": -9, "hand_offset": 0.015})
	check(right.transform.is_equal_approx(HandPose.grip_transform(false, 12, -9, 0.015)), "Live fit controls adjust controller-to-hand alignment")
	var pen := HandPose.pen_in_hand(false, 25, 1.25)
	var grasp := pen * Vector3(0, 0, HandPose.PEN_GRASP_Z)
	check(grasp.is_equal_approx(HandPose.TRIPOD_POINT), "Pen grasp point is exactly the anatomical tripod target")
	var cap := pen * Vector3(0, 0, 0.028)
	check(cap.x < -0.040 and cap.y < -0.015, "Pen cap lies outside palm, not embedded in its center")
	right.set_game_inputs({}, Vector2.ZERO, 1, "hinge")
	check(right.finger_curls[0] < 0.4 and right.finger_curls[2] > 0.5, "Lid uses a lighter grasp distinct from pen / console")
	var mesh_before: Mesh = right.skin_mesh.mesh
	var began := Time.get_ticks_usec()
	for i in range(1000): right.set_game_inputs({}, Vector2.ZERO, 1.0 / 90, "console", {"trigger": float(i % 10) / 10})
	print("HAND POSE BENCH: ", float(Time.get_ticks_usec() - began) / 1000.0, " usec/update; ", triangles, " triangles/hand")
	check(right.skin_mesh.mesh == mesh_before, "Animation never rebuilds geometry")
	right.set_tracking_visible(false)
	left.set_tracking_visible(true)
	check(not right.visible and left.visible, "Each hand can hide independently on tracking loss")
	print("HAND TEST: %d checks, %d failures" % [checks, failures])
	quit(failures)

const DIGITS_FOR_LIMITS := ["index", "middle", "ring", "pinky"]
