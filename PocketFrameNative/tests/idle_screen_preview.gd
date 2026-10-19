extends SceneTree
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var viewport := SubViewport.new();viewport.size=Vector2i(1600,960);viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var canvas=preload("res://scripts/screen_canvas.gd").new();canvas.upper=true;canvas.size=viewport.size;viewport.add_child(canvas)
	await process_frame;await RenderingServer.frame_post_draw
	var destination := ProjectSettings.globalize_path("res://../outputs/validation/native-idle-top.png")
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var result := viewport.get_texture().get_image().save_png(destination)
	print("Top idle screen capture: ",result);quit(result)
