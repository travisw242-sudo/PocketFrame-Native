extends SceneTree
## Opt-in real game test. Caller must supply an isolated XDG_DATA_HOME.
var backend: Node
var device: Node3D
var failure := false
func check(ok: bool,title: String) -> void:
	print("LIFECYCLE ",title,": ","PASS" if ok else "FAIL")
	if not ok:failure=true
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var game := "";var duration := 120.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game="):game=arg.trim_prefix("--game=")
		if arg.begins_with("--seconds="):duration=clampf(float(arg.trim_prefix("--seconds=")),10,1800)
	if game.is_empty() or not FileAccess.file_exists(game):quit(2);return
	device=preload("res://scripts/handheld.gd").new();root.add_child(device)
	backend=preload("res://scripts/azahar_in_process_backend.gd").new();root.add_child(backend)
	backend.attach(device);backend.set_quality("sharp");backend.set_stereo_depth(.25);backend.set_enabled(true)
	backend.load_game(game)
	var deadline := Time.get_ticks_msec()+30000
	while backend._core.get_presented_frame_count()<60 and Time.get_ticks_msec()<deadline:await process_frame
	check(backend._core.get_presented_frame_count()>=60,"game boots and produces frames")
	backend.set_paused(true)
	await create_timer(.3).timeout
	var paused_frames: int=backend._core.get_presented_frame_count()
	await create_timer(2).timeout
	check(backend._core.get_presented_frame_count()<=paused_frames+1,"pause halts emulation")
	backend.set_paused(false)
	await create_timer(2).timeout
	check(backend._core.get_presented_frame_count()>paused_frames+10,"resume restores frames")
	var started := Time.get_ticks_msec()
	var minimum_frames: int=backend._core.get_presented_frame_count()
	while Time.get_ticks_msec()-started<duration*1000:
		await create_timer(10).timeout
		var frames: int=backend._core.get_presented_frame_count()
		check(frames>minimum_frames,"sustained frame progress")
		minimum_frames=frames
	backend.unload_game()
	deadline=Time.get_ticks_msec()+15000
	while backend.is_running() and Time.get_ticks_msec()<deadline:await process_frame
	check(not backend.is_running(),"emulator shuts down normally")
	check(device.stereo_material==null and device.bottom_lcd_material==null,"eject restores idle screens")
	backend.set_enabled(false)
	await process_frame
	print("LIFECYCLE COMPLETE failures=",failure)
	quit(1 if failure else 0)
