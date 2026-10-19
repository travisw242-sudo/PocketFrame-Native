extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(title)
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var device=preload("res://scripts/handheld.gd").new();root.add_child(device)
	var bottom := ImageTexture.create_from_image(Image.create(640,480,false,Image.FORMAT_RGBA8))
	for stereo in [false,true,false]:
		var top := ImageTexture.create_from_image(Image.create(1600 if stereo else 800,480,false,Image.FORMAT_RGBA8))
		device.set_screen_textures(top,bottom)
		check(device.stereo_material.get_shader_parameter("lcd_image")==top,"Top texture bound")
		check(device.stereo_material.get_shader_parameter("stereo_image")==stereo,"Stereo/mono transition retained")
		check(device.bottom_lcd_material.get_shader_parameter("lcd_image")==bottom,"Bottom has distance filter")
		check(not device.bottom_lcd_material.get_shader_parameter("stereo_image"),"Bottom never splits into stereo")
	device.set_stereo_swap(true)
	check(device.stereo_material.get_shader_parameter("swap_eyes"),"Eye swap retained")
	device.clear_screen_textures()
	check(device.bottom_surface.material_override==device.idle_bottom_material and device.bottom_lcd_material==null,"Ejection restores bottom idle material")
	check(device.upper_surface.material_override==device.idle_upper_material and device.stereo_material==null,"Ejection restores top idle material")
	device.queue_free();await process_frame
	print("LCD FILTER: %d checks, %d failures"%[checks,failures]);quit(failures)
