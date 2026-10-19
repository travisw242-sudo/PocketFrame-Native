extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var frames: Array = []
	var core: Object = app.emulator_backend._core
	core.connect("frame_ready", func(top: Texture2D, bottom: Texture2D): frames.assign([top, bottom]))
	await create_timer(18).timeout
	if frames.size() != 2:
		push_error("No LCD textures were delivered")
		quit(1)
		return
	var sharp := "--quality=sharp" in OS.get_cmdline_user_args()
	var backend := OS.get_environment("POCKETFRAME_GPU")
	var scale := 2 if sharp and backend == "vulkan" else 1
	if frames[0].get_size() != Vector2(400 * scale, 240 * scale) or frames[1].get_size() != Vector2(320 * scale, 240 * scale):
		push_error("Unexpected LCD texture dimensions: %s / %s" % [frames[0].get_size(), frames[1].get_size()])
		quit(2)
		return
	var path := ProjectSettings.globalize_path("res://quality-tests")
	DirAccess.make_dir_recursive_absolute(path)
	var prefix := backend + ("-sharp" if sharp else "-balanced")
	var top_error: int = frames[0].get_image().save_png(path.path_join(prefix + "-top.png"))
	var bottom_error: int = frames[1].get_image().save_png(path.path_join(prefix + "-bottom.png"))
	if top_error != OK or bottom_error != OK:
		push_error("Could not save LCD verification images")
		quit(3)
		return
	print("PASS: %s LCD textures %s / %s; presented %d frames" % [prefix, frames[0].get_size(), frames[1].get_size(), core.call("get_presented_frame_count")])
	quit()
