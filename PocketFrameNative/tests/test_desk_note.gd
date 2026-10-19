extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main._load_room("studio")
	main._process(0)
	check(main.desk_note.get_parent()==main.get_node("StudioTable"),"Note belongs to desk")
	check(main.desk_note.is_visible_in_tree(),"Guide is visible in Studio")
	check(not main.world_status.visible,"No floating guide in Studio")
	check(main.desk_note.body.text.begins_with(main.world_status.text) and main.desk_note.body.text.contains("hold Y"),"Same live guide plus headset menu hint on paper")
	check(main.desk_note.body.global_basis.z.dot(Vector3.UP)>.99,"Printed face points upward")
	check(main.desk_note.body.no_depth_test==false,"Paper text respects depth")
	main.xr_enabled=true
	main.xr_camera.position=Vector3(0,1.6,0)
	main._recenter_dock()
	check(main.get_node("StudioTable").visible,"Recenter preserves desk")
	check(main.desk_note.is_visible_in_tree() and not main.world_status.visible,"Recenter keeps paper instead of floating text")
	main.xr_enabled=false
	main._load_room("teen_2008")
	check(not main.desk_note.is_visible_in_tree(),"No Studio paper left floating in Bedroom")
	main._load_room("studio")
	check(main.desk_note.is_visible_in_tree(),"Guide returns with Studio")
	main._process(0)
	if "--capture-note" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		main.ui.hide()
		root.size=Vector2i(1100,850)
		main.camera.global_position=main.desk_note.global_position+Vector3(0,.43,.33)
		main.camera.look_at(main.desk_note.global_position,Vector3.UP)
		main.camera.fov=40
		main.camera.h_offset=0
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/validation/desk-note.png"))
	print("DESK NOTE: %d checks, %d failures"%[checks,failures])
	main.queue_free()
	quit(failures)
