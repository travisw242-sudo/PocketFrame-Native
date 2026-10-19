extends SceneTree
## Opt-in real GPU boot. No controller input, config writes or save manipulation.
const Device = preload("res://scripts/handheld.gd")
const Backend = preload("res://scripts/azahar_in_process_backend.gd")
var backend: Node
var device: Node3D
var started := 0
var phase := 0
var phase_frame := 0
var finished := false
var expected_scale := 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game="): game=arg.trim_prefix("--game=")
		if arg=="--sharp": expected_scale=2
		if arg=="--ultra": expected_scale=3
	if game.is_empty() or not FileAccess.file_exists(game):
		push_error("Pass an explicit existing --game path for this opt-in smoke test")
		quit(1)
		return
	device=Device.new()
	root.add_child(device)
	device.position=Vector3(0,1,-.5)
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.position=Vector3(0,1.30,-.15)
	camera.look_at(device.position+Vector3(0,.03,0),Vector3.UP)
	camera.current=true
	backend=Backend.new()
	root.add_child(backend)
	backend.attach(device)
	backend.set_player_name("FrameTest")
	backend.set_quality("ultra" if expected_scale==3 else "sharp" if expected_scale==2 else "balanced")
	backend.set_stereo_depth(.2)
	backend.set_enabled(true)
	backend.load_game(ProjectSettings.globalize_path(game))
	started=Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if started==0 or finished: return false
	if Time.get_ticks_msec()-started>60000:
		_finish(1,"Timed out waiting for mono/stereo frames: "+backend.message)
		return false
	if not device.stereo_material: return false
	var top: Texture2D=device.stereo_material.get_shader_parameter("lcd_image")
	var stereo: bool=device.stereo_material.get_shader_parameter("stereo_image")
	var frames: int=backend._core.get_presented_frame_count()
	var should_stereo:=phase!=1
	var minimum_frames := 600 if phase==0 else 180 if phase==2 else 60
	if stereo!=should_stereo or frames-phase_frame<minimum_frames: return false
	var wanted_width: int=(800 if should_stereo else 400)*expected_scale
	if top.get_width()!=wanted_width or top.get_height()!=240*expected_scale:
		_finish(1,"Incorrect eye resolution")
		return false
	print("GPU STEREO PHASE %d: %dx%d, stereo=%s, frames=%d" % [phase,top.get_width(),top.get_height(),stereo,frames])
	if phase==0:
		top.get_image().save_png("res://test-logs/stereo-smoke-top.png")
		var eye_image := top.get_image()
		var different := 0
		for y in range(0,eye_image.get_height(),2):
			for x in range(0,eye_image.get_width()/2,2):
				if eye_image.get_pixel(x,y)!=eye_image.get_pixel(x+eye_image.get_width()/2,y): different+=1
		print("GPU STEREO eye-pair differing sampled pixels: ",different," (2D game scenes may legitimately match)")
		backend.set_stereo_depth(0)
	elif phase==1:
		backend.set_stereo_depth(.35)
	else:
		_finish(0,"Real GPU boot + stereo / mono / stereo transitions passed")
		return false
	phase+=1
	phase_frame=frames
	return false

func _finish(code: int, message: String) -> void:
	finished=true
	print("STEREO SMOKE: ",message)
	backend.set_enabled(false)
	await process_frame
	quit(code)
