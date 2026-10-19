extends Node
## Opt-in packaged-runtime diagnostics; refuses the player's normal profile.
var backend: Node
var failure := false
func check(ok: bool,title: String) -> void:
	printerr("LIFECYCLE ",title,": ","PASS" if ok else "FAIL")
	if not ok:failure=true
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	if DisplayServer.get_name()!="headless" or not OS.get_environment("XDG_DATA_HOME").ends_with("/lifecycle-validation"):
		printerr("Validation requires a separate lifecycle-validation XDG_DATA_HOME and headless mode.")
		get_tree().quit(2);return
	var game := "";var duration := 30.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game="):game=arg.trim_prefix("--game=")
		if arg.begins_with("--seconds="):duration=clampf(float(arg.trim_prefix("--seconds=")),10,1800)
	if game.is_empty() or not FileAccess.file_exists(game):get_tree().quit(2);return
	var device=preload("res://scripts/handheld.gd").new();add_child(device)
	backend=preload("res://scripts/azahar_in_process_backend.gd").new();add_child(backend)
	backend.attach(device);backend.set_quality("sharp");backend.set_stereo_depth(.25);backend.set_enabled(true)
	backend.load_game(game)
	var deadline := Time.get_ticks_msec()+30000
	while backend._core.get_presented_frame_count()<60 and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	check(backend._core.get_presented_frame_count()>=60,"game boots and produces frames")
	backend.set_paused(true);await get_tree().create_timer(.3).timeout
	var paused_frames: int=backend._core.get_presented_frame_count()
	await get_tree().create_timer(2).timeout
	check(backend._core.get_presented_frame_count()<=paused_frames+1,"pause halts emulation")
	backend.set_paused(false);await get_tree().create_timer(2).timeout
	check(backend._core.get_presented_frame_count()>paused_frames+10,"resume restores frames")
	var config := ConfigFile.new();config.set_value("validation","sentinel","preserved")
	check(config.save("user://validation.cfg")==OK,"isolated settings written")
	var restored := ConfigFile.new()
	check(restored.load("user://validation.cfg")==OK and restored.get_value("validation","sentinel","")=="preserved","settings survive disk reload")
	var started := Time.get_ticks_msec();var minimum_frames: int=backend._core.get_presented_frame_count()
	while Time.get_ticks_msec()-started<duration*1000:
		await get_tree().create_timer(10).timeout
		var frames: int=backend._core.get_presented_frame_count()
		check(frames>minimum_frames,"sustained frame progress");minimum_frames=frames
	backend.unload_game();deadline=Time.get_ticks_msec()+15000
	while backend.is_running() and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	check(not backend.is_running(),"emulator shuts down normally")
	check(device.stereo_material==null and device.bottom_lcd_material==null,"eject restores idle screens")
	backend.set_enabled(false);await get_tree().process_frame
	printerr("LIFECYCLE COMPLETE failures=",failure);get_tree().quit(1 if failure else 0)
