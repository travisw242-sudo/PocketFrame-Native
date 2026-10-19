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
	device.set_volume(0.65)
	# Right hand supports device; left index physically touches its side cap.
	scene.right.global_transform = HandPose.console_transform(device.global_transform, false) * HandPose.grip_transform(false).affine_inverse()
	scene.right_hand_visual.set_game_inputs({}, Vector2.ZERO, 1, "console", {"console_world": device.global_transform, "collision_device": device})
	scene.right_hand_visual.set_tracking_visible(true)
	var pointing := device.global_basis.orthonormalized() * Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT)
	scene.left.global_transform = Transform3D(pointing * HandPose.grip_transform(true).basis.inverse(), device.global_position)
	scene.left_hand_visual.set_game_inputs({}, Vector2.ZERO, 1, "", {"grip": 0.7, "trigger": 0.0})
	scene.left_hand_visual.set_tracking_visible(true)
	var cap: Vector3 = device.volume_slider.global_position - device.global_basis.x.normalized() * 0.005
	scene.left.global_position += cap - scene.left_hand_visual.fingertip_position()
	for controller in [scene.left, scene.right]:
		controller.get_node("ControllerMarker").hide()
		controller.get_node("ControllerMarkerLabel").hide()
	scene.volume_touch.step(0.016, [scene.left_hand_visual.fingertip_position(), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO], [true, false, false, false])
	scene.camera.position = device.global_position + Vector3(-0.23, 0.13, 0.20)
	scene.camera.look_at(device.global_position + Vector3(-0.03, 0, 0))
	scene.camera.fov = 43
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://volume-slider-preview.png"))
	quit()
