extends SceneTree
const Device = preload("res://scripts/handheld.gd")
const DepthControl = preload("res://scripts/depth_slider.gd")
const Backend = preload("res://scripts/azahar_in_process_backend.gd")
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(title)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var device := Device.new()
	root.add_child(device)
	var slider := DepthControl.new()
	slider.setup(device)
	for size in [.8,1.,1.6,2.]:
		for lid_angle in [75.,145.,175.]:
			device.global_transform=Transform3D(Basis.from_euler(Vector3(.3,.7,-.2)).scaled(Vector3.ONE*size),Vector3(.3,1.2,-.4))
			device.set_lid_angle(lid_angle)
			device.set_depth(.5)
			slider.reset()
			var p: Vector3=device.depth_slider.position+Vector3(0,.001,0)
			slider.step(.016,[device.lid.to_global(p)],[true])
			check(slider.active() and slider.just_started,"Free fingertip captures upper cap")
			check(is_equal_approx(device.depth_level,.5),"First touch does not jump depth")
			p.z-=.006
			slider.step(.016,[device.lid.to_global(p)],[true])
			check(is_equal_approx(device.depth_level,1.),"Sliding up raises depth at rotated lid/scale")
			p.z+=.012
			slider.step(.016,[device.lid.to_global(p)],[true])
			check(is_zero_approx(device.depth_level),"Bottom stop disables 3D")
			p.y+=.04
			slider.step(.016,[device.lid.to_global(p)],[true])
			check(not slider.active() and slider.just_released,"Lifting finger releases cap")
			slider.reset()
			slider.step(.016,[device.depth_slider.global_position],[false])
			check(not slider.active(),"Holder/tool/lost tracking cannot move slider")
	for scale_size in [1,2]:
		var bottom := ImageTexture.create_from_image(Image.create(320*scale_size,240*scale_size,false,Image.FORMAT_RGBA8))
		for stereo in [false,true,false]:
			var top := ImageTexture.create_from_image(Image.create((800 if stereo else 400)*scale_size,240*scale_size,false,Image.FORMAT_RGBA8))
			device.set_screen_textures(top,bottom)
			check(device.stereo_material.get_shader_parameter("stereo_image")==stereo,"Correct eye atlas detection during live resize")
			check(device.bottom_lcd_material.get_shader_parameter("lcd_image")==bottom and not device.bottom_lcd_material.get_shader_parameter("stereo_image"),"Lower screen remains separate and flat")
	device.set_stereo_swap(true)
	check(device.stereo_material.get_shader_parameter("swap_eyes"),"Eye reversal option reaches shader")
	var backend := Backend.new()
	root.add_child(backend)
	backend.attach(device)
	backend.set_player_name("  ZeldaFan  ")
	backend.set_stereo_depth(.25)
	backend.set_enabled(true)
	check(backend._core!=null and backend._core.has_method("set_stereo_depth"),"New native stereo library loads")
	check(backend.player_name=="ZeldaFan" and is_equal_approx(backend.stereo_depth,.25),"Profile and depth configured before ROM boot")
	backend.set_stereo_depth(0)
	check(is_zero_approx(backend.stereo_depth),"Live disable reaches backend")
	backend.set_enabled(false)
	await process_frame
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.device.set_depth(.3)
	check(is_equal_approx(scene.emulator_backend.stereo_depth,.3) and is_equal_approx(scene.depth_gui.value,30),"Physical depth synchronizes backend and GUI")
	scene.depth_touch.active_tip=0
	scene.router.update_touch(Vector2(.5,.5),true)
	scene._update_vr_touch()
	check(not scene.router.touch_down,"3D slider cannot send accidental lower-screen input")
	scene._dock()
	check(not scene.depth_touch.active(),"Dock clears captured slider finger")
	var launcher=load("res://launcher.tscn").instantiate()
	root.add_child(launcher)
	check(launcher.player_name_edit.max_length==10,"Profile editor uses system name length limit")
	launcher.fit_controls.stereo_depth.slider.set_value_no_signal(0)
	launcher.depth_seen=0
	launcher._sync_depth_from_setting(.3)
	check(is_equal_approx(launcher.fit_controls.stereo_depth.slider.value,30),"Open launcher follows persisted physical depth")
	launcher.fit_controls.stereo_depth.slider.set_value_no_signal(60)
	launcher._sync_depth_from_setting(.3)
	check(is_equal_approx(launcher.fit_controls.stereo_depth.slider.value,60),"Explicit launcher depth edit wins")
	print("STEREO TEST: %d checks, %d failures" % [checks,failures])
	quit(failures)
