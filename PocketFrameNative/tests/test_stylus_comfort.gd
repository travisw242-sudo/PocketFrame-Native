extends SceneTree
const Device = preload("res://scripts/handheld.gd")
const Motion = preload("res://scripts/stylus_motion.gd")
const Interactions = preload("res://scripts/immersive_interactions.gd")
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

func hits(mesh: Mesh, x: float) -> bool:
	var faces := mesh.get_faces()
	var start := Vector3(x, 0, 0.058) * 1000
	var end := Vector3(x, 0, 0.020) * 1000
	for i in range(0, faces.size(), 3):
		if Geometry3D.segment_intersects_triangle(start, end, faces[i] * 1000, faces[i + 1] * 1000, faces[i + 2] * 1000) != null:
			return true
	return false

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var device := Device.new()
	world.add_child(device)
	device.position.y = 1
	var dock: Transform3D = device.global_transform
	var motion := Motion.new()
	motion.setup(device, world)
	device.set_stylus_side("right")
	check(device.stylus_stored_position().x > 0 and device.stylus.position.x > 0, "Right-side setting moves stored pen")
	check(device.get_node("LowerHousing/StylusBore").position.x > 0 and device.get_node("StylusWell").position.x > 0, "Right-side setting moves bore and sleeve")
	await process_frame
	await process_frame
	var mesh: Mesh = device.get_node("LowerHousing").get_meshes()[1]
	check(not hits(mesh, 0.05), "Right side now has real opening")
	check(hits(mesh, -0.05), "Previous left opening is filled, not duplicated")
	device.set_stylus_side("left")
	await process_frame
	await process_frame
	mesh = device.get_node("LowerHousing").get_meshes()[1]
	check(not hits(mesh, -0.05) and hits(mesh, 0.05), "Switching back leaves only the left hole")
	device.set_stylus_side("right")
	var hand := Transform3D(Basis(Vector3.UP, 1), device.stylus_handle_position())
	motion.begin(hand, 1)
	var stored: Vector3 = device.stylus.global_position
	motion.held(0.016, hand, dock)
	check(device.stylus.global_position.is_equal_approx(stored), "Extraction grip remains constrained, not instantly reoriented")
	hand.origin.z += Motion.TRAVEL
	motion.held(0.016, hand, dock)
	check(motion.phase == "free", "Right-side rail releases pen only after clear")
	var clear_pose: Transform3D = device.stylus.global_transform
	check(clear_pose.basis.orthonormalized().is_equal_approx(device.global_basis.orthonormalized()), "Rail exit preserves pose before comfort transition")
	hand.origin = Vector3(0.05, 1.12, 0.16)
	var aim := Transform3D(Basis(Vector3.UP, 0.2), hand.origin)
	for i in range(30): motion.held(0.016, hand, dock, aim)
	var expected: Transform3D = motion.writing_pose(hand, aim)
	check(device.stylus.global_transform.is_equal_approx(expected), "Free pen settles into repeatable writing grip")
	check(device.stylus.global_position.distance_to(hand.origin) < 0.09, "Pen sits at anatomical finger pinch, not remote acquisition offset")
	check((-device.stylus.global_basis.z).y < -0.35, "Default grip pitches tip naturally toward lower screen")
	var hand_only: Transform3D = motion.writing_pose(hand)
	check(hand_only.is_equal_approx(expected), "Aim ray cannot twist pen away from shared physical grip frame")
	device.hand_pitch = 12
	device.hand_roll = -9
	device.hand_offset = 0.015
	var fitted: Transform3D = motion.writing_pose(hand, aim)
	var fitted_hand := hand * HandPose.grip_transform(false, 12, -9, 0.015)
	var grip_point := fitted * Vector3(0, 0, HandPose.PEN_GRASP_Z)
	check(grip_point.distance_to(fitted_hand * HandPose.TRIPOD_POINT) < 0.00001, "Hand fit calibration moves pen and visible finger pinch together")
	device.hand_pitch = 0
	device.hand_roll = 0
	device.hand_offset = 0
	motion.writing_hand = 0
	var left_pose: Transform3D = motion.writing_pose(Transform3D.IDENTITY)
	motion.writing_hand = 1
	var right_pose: Transform3D = motion.writing_pose(Transform3D.IDENTITY)
	check(is_equal_approx(left_pose.origin.x, -right_pose.origin.x), "Finger-pinch offset mirrors for either hand")
	device.stylus_grip_angle = 0
	var flat_pose: Transform3D = motion.writing_pose(Transform3D.IDENTITY)
	device.stylus_grip_angle = 60
	var steep_pose: Transform3D = motion.writing_pose(Transform3D.IDENTITY)
	check(absf(rad_to_deg(flat_pose.basis.get_rotation_quaternion().angle_to(steep_pose.basis.get_rotation_quaternion())) - 60) < 0.01, "Grip angle adjustment changes pen tilt predictably")
	device.stylus_grip_angle = 25
	motion.release()
	for i in range(30): motion.unheld(0.016, dock)
	check(motion.phase == "loose", "Short release grace period allows re-grip")
	for i in range(80): motion.unheld(0.016, dock)
	check(motion.phase == "stored" and device.stylus.get_parent() == device and device.stylus.visible, "Dropped pen auto-returns and becomes visible in holster")
	check(device.stylus.position.is_equal_approx(device.stylus_stored_position()) and device.stylus.position.x > 0, "Auto-return uses selected right slot")
	device.stylus_auto_return = false
	motion.begin(Transform3D(Basis.IDENTITY, device.stylus_handle_position()))
	motion.phase = "free"
	device.stylus.global_position += Vector3(0.2, 0.1, 0.2)
	motion.release()
	for i in range(110): motion.unheld(0.016, dock)
	check(motion.phase == "loose", "Auto-return can be disabled")
	device.stylus_auto_return = true
	for i in range(80): motion.unheld(0.016, dock)
	check(motion.phase == "stored", "Re-enabling auto-return retrieves already dropped pen")
	# Recall must not take a held pen. Re-gripping cancels the release timer.
	motion.begin(Transform3D(Basis.IDENTITY, device.stylus_handle_position()))
	motion.phase = "free"
	device.stylus.global_position = Vector3(0.1, 1.1, 0.2)
	motion.release()
	for i in range(20): motion.unheld(0.016, dock)
	hand = Transform3D(Basis.IDENTITY, Vector3(0.1, 1.1, 0.2))
	motion.begin(hand)
	for i in range(80): motion.held(0.016, hand, dock)
	check(motion.phase == "free" and device.stylus.visible, "Re-grip cancels automatic recall")
	motion.release()
	for i in range(48): motion.unheld(0.016, dock)
	check(motion.phase == "recalling" and not device.stylus.visible, "Recall briefly hides pen before reseating, not a flight through shell")
	motion.store()
	check(device.stylus.visible and motion.phase == "stored", "Reset during recall restores visible pen")
	# Changing side during a held console recalls only the pen, not hand locks.
	var interaction := Interactions.new()
	interaction.setup(device, world)
	interaction.holders = [true, false]
	interaction.locked = [true, false]
	interaction.tool = "stylus"
	interaction.tool_hand = 1
	interaction.pen_motion.begin(hand, 1)
	interaction.recall_stylus()
	device.set_stylus_side("left")
	check(interaction.holding(0) and interaction.locked[0], "Side change / pen recall preserves console lock")
	check(interaction.tool.is_empty() and device.stylus.get_parent() == device and device.stylus.position.x < 0, "Recalling held pen allows safe slot relocation")
	device.set_stylus_side("invalid")
	check(device.stylus_side == "left", "Invalid saved slot values fall back to left")
	var launcher = load("res://launcher.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	check(launcher.stylus_side_choice.item_count == 2, "Launcher offers exactly left/right slot choices")
	check(launcher.stylus_return_check != null and launcher.fit_controls.has("stylus_grip_angle"), "Launcher exposes return switch and grip angle")
	check(launcher.fit_controls.has("hand_pitch") and launcher.fit_controls.has("hand_roll") and launcher.fit_controls.has("hand_offset"), "Launcher exposes controller fit controls")
	launcher.queue_free()
	print("STYLUS COMFORT TEST: %d checks, %d failures" % [checks, failures])
	quit(failures)
