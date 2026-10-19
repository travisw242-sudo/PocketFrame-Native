extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1280,800)
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.ui.hide()
	scene.world_status.hide()
	var rack=scene.cartridge_rack
	scene.camera.position=rack.tray.global_position+Vector3(0,.20,.20)
	scene.camera.look_at(rack.tray.global_position,Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-logs/cartridge-tray-preview.png")
	for card in rack.cards.values(): card.hide()
	var card: Node3D=rack.cards.values()[0]
	card.show()
	card.global_transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*3),Vector3(0,1.28,-.30))
	scene.camera.position=Vector3(.025,1.45,-.15)
	scene.camera.look_at(card.global_position,Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-logs/cartridge-detail-preview.png")
	quit()
