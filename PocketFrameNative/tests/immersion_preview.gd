extends SceneTree
const HandPose = preload("res://scripts/hand_pose.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.ui.visible = false
	var device: Node3D = scene.device
	var dock: Transform3D = device.global_transform
	var hands := [Transform3D(Basis.IDENTITY, device.to_global(Vector3(-0.066, 0, 0.009))), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-50)), device.stylus_handle_position())]
	scene.immersion.step(1, hands, [true, true], [true, false], [false, false], dock)
	scene.immersion.step(1, hands, [true, true], [true, true], [false, false], dock)
	hands[1].origin += device.global_basis.z * scene.immersion.pen_motion.TRAVEL
	scene.immersion.step(1, hands, [true, true], [true, true], [false, false], dock)
	var tip: Vector3 = scene.device.bottom_surface.global_position + Vector3(0, 0.002, 0)
	var pen_local := HandPose.pen_in_hand(false, device.stylus_grip_angle, device.global_basis.x.length())
	var pen_basis: Basis = device.global_basis.orthonormalized() * Basis(Vector3.BACK, -PI / 2) * pen_local.basis
	var pen_pose := Transform3D(pen_basis, tip - pen_basis * Vector3(0, 0, -0.029))
	var grip_local: Transform3D = scene.immersion.pen_motion.writing_pose(Transform3D.IDENTITY)
	hands[1] = pen_pose * grip_local.affine_inverse()
	scene.immersion.pen_motion.grip_blend = 1
	for i in range(4):
		scene.immersion.step(0.016, hands, [true, true], [true, true], [false, false], dock)
	scene.left.global_transform = hands[0]
	scene.right.global_transform = hands[1]
	scene.left_hand_visual.set_tracking_visible(true)
	scene.right_hand_visual.set_tracking_visible(true)
	for controller in [scene.left, scene.right]:
		controller.get_node("ControllerMarker").hide()
		controller.get_node("ControllerMarkerLabel").hide()
	scene.left_hand_visual.set_game_inputs({}, Vector2.ZERO, 1, "console", {"console_world": device.global_transform})
	scene.right_hand_visual.set_game_inputs({}, Vector2.ZERO, 1, "stylus")
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://immersion-preview.png"))
	quit()
