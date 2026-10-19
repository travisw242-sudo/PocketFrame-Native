extends SceneTree
const Pose=preload("res://scripts/hand_pose.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1100,800)
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.cartridge_rack.set_process(false)
	scene.ui.hide()
	scene.world_status.hide()
	scene.camera.h_offset=0
	scene.camera.v_offset=0
	var rack=scene.cartridge_rack
	for card in rack.cards.values(): card.hide()
	rack.tray.hide()
	scene.device.hide()
	var card: Node3D=rack.cards.values()[0]
	card.show()
	for i in range(2):
		var controller: Node3D=[scene.left,scene.right][i]
		var visual=[scene.left_hand_visual,scene.right_hand_visual][i]
		var world:=Transform3D(Basis.IDENTITY,Vector3(.3,1.35,-.2))
		controller.global_transform=world*Pose.grip_transform(i==0).affine_inverse()
		controller.get_node("ControllerMarker").hide()
		controller.get_node("ControllerMarkerLabel").hide()
		card.global_transform=world*Pose.card_in_hand(i==0,1.25)
		visual.show()
		visual.set_game_inputs({},Vector2.ZERO,1,"cartridge",{"cartridge_world":card.global_transform,"collision_device":scene.device,"grip":1.})
		scene.camera.global_position=world.origin+Vector3(.12 if i==1 else -.12,-.02,-.17)
		scene.camera.look_at(card.global_position,Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-logs/card-pinch-%s.png" % ["left" if i==0 else "right"])
		visual.hide()
	scene.device.show()
	card.hide()
	var mouth: Node3D=scene.device.get_node("CartridgeSlot")
	scene.camera.global_position=mouth.global_position+scene.device.global_basis*Vector3(.012,-.008,-.085)
	scene.camera.look_at(mouth.global_position,scene.device.global_basis.y.normalized())
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-logs/card-slot-open.png")
	quit()
