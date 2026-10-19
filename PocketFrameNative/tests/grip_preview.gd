extends SceneTree
const HandPose = preload("res://scripts/hand_pose.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.ui.hide()
	scene.world_status.hide()
	var device: Node3D = scene.device
	var console: Transform3D = device.global_transform
	for i in range(2):
		var controller: XRController3D = [scene.left, scene.right][i]
		var visual: Node3D = [scene.left_hand_visual, scene.right_hand_visual][i]
		controller.global_transform = HandPose.console_transform(console, i == 0) * HandPose.grip_transform(i == 0).affine_inverse()
		controller.get_node("ControllerMarker").hide()
		controller.get_node("ControllerMarkerLabel").hide()
		visual.set_tracking_visible(true)
		visual.set_game_inputs({}, Vector2.ZERO, 1, "console", {"console_world": console, "collision_device": device})
	var pen_mode := "--pen-grip-preview" in OS.get_cmdline_user_args()
	if pen_mode:
		var pen_local := HandPose.pen_in_hand(false, device.stylus_grip_angle, device.global_basis.x.length())
		var hand_basis: Basis = console.basis.orthonormalized() * Basis(Vector3.BACK, -PI / 2)
		var tip: Vector3 = device.bottom_surface.global_position + device.bottom_surface.global_basis.y.normalized() * 0.001
		var hand_world := Transform3D(hand_basis, tip - hand_basis * (pen_local * Vector3(0, 0, -0.029)))
		scene.right.global_transform = hand_world * HandPose.grip_transform(false).affine_inverse()
		device.stylus.reparent(scene, true)
		device.stylus.global_transform = hand_world * pen_local
		scene.right_hand_visual.set_game_inputs({}, Vector2.ZERO, 1, "stylus", {"collision_device": device})
	scene.yaw = 0.22
	scene.pitch = 0.55
	scene.distance = 0.44
	scene._update_camera()
	var underside := "--underside" in OS.get_cmdline_user_args()
	if underside:
		device.global_position += Vector3.UP * 0.35
		for controller in [scene.left, scene.right]: controller.global_position += Vector3.UP * 0.35
		scene.camera.global_position = device.global_position + Vector3(0.16, -0.22, 0.22)
		scene.camera.look_at(device.global_position)
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://console-under-grip-preview.png" if underside else "res://pen-grip-preview.png" if pen_mode else "res://console-grip-preview.png"))
	quit()
