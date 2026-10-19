extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1440,1080)
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main._load_room("teen_2008")
	main.device.global_transform=main.dock_pose
	main.device.scale=Vector3.ONE*main.device_scale
	main.ui.hide(); main.world_status.hide()
	main.camera.global_position=Vector3(.8,1.3,-1.22)
	main.camera.look_at(Vector3(.8,.83,-1.94))
	main.camera.fov=76
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-logs/bedroom-desk-spawn.png")
	main.camera.global_position=Vector3(.85,1.30,-1.85)
	main.camera.look_at(Vector3(.30,1.04,-2.10))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-logs/bedroom-pc-clearance.png")
	main.queue_free()
	quit()
