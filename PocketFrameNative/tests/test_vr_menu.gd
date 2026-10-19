extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,title: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(title)
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var world := Node3D.new();root.add_child(world)
	var menu=preload("res://scripts/vr_menu.gd").new();world.add_child(menu);menu.setup(null,"Player")
	check(not menu.visible and menu.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Closed menu has no render cost")
	check("stick DOWN" in menu.grip_help.text and "each hand" in menu.grip_help.text,"Menu explains per-hand stick grip lock")
	check("/home/steamos/.local/share/pocketframe-native/games/" in menu.games_help.text and "restart" in menu.games_help.text,"Menu explains headset games folder and refresh")
	check(not menu.toggle_gesture(.5,true,true),"Short press doesn't open menu")
	check(menu.toggle_gesture(.31,true,true),"Hold opens once")
	check(not menu.toggle_gesture(2,true,true),"Holding does not repeatedly toggle")
	menu.toggle_gesture(0,false,true)
	check(not menu.toggle_gesture(1,true,false),"Occupied menu hand cannot open menu")
	menu.toggle_gesture(0,false,true)
	check(menu.toggle_gesture(.9,true,true),"Release rearms gesture")
	menu.open_at(Transform3D(Basis.IDENTITY,Vector3(2,1.3,-4)))
	check(menu.visible and menu.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"Visible world panel renders")
	var pose: Transform3D=menu.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,.5))
	check(menu.ray_pixel(pose.origin,-pose.basis.z).is_equal_approx(Vector2(512,512)),"Controller ray maps to center")
	check(menu.ray_pixel(pose.origin,pose.basis.z).x<0,"Backward ray cannot click through panel")
	var miss: Vector3=pose.origin+menu.global_basis.x*2
	check(menu.ray_pixel(miss,-pose.basis.z).x<0,"Outside ray misses")
	menu.update_native_view(false,true,"Available")
	var view_requests: Array[bool]=[]
	menu.native_view_requested.connect(func(on: bool):view_requests.append(on);menu.update_native_view(on,true,"Available"))
	await process_frame;await process_frame
	var view_position: Vector2=menu.native_studio.global_position
	var scroll: ScrollContainer=menu.content.get_parent()
	scroll.scroll_vertical=9999
	await process_frame;await process_frame
	check(menu.native_studio.global_position.is_equal_approx(view_position),"Studio/AR controls stay pinned while settings scroll")
	for button in [menu.native_ar,menu.native_studio]:
		var view_pixel: Vector2=button.get_global_rect().get_center()
		var view_point := Vector3((view_pixel.x/1024-.5)*menu.SIZE.x,(.5-view_pixel.y/1024)*menu.SIZE.y,.5)
		var view_pose: Transform3D=menu.global_transform*Transform3D(Basis.IDENTITY,view_point)
		menu.pointer_step(.016,view_pose,true,false,0);menu.pointer_step(.016,view_pose,true,true,0);menu.pointer_step(.016,view_pose,true,false,0)
	check(view_requests==[true,false],"VR pointer selects AR then Studio without a dropdown")
	check(menu.native_studio.button_pressed and not menu.native_ar.button_pressed,"Confirmed Studio view remains selected")
	scroll.scroll_vertical=0
	await process_frame;await process_frame
	var quality_requests: Array[String]=[]
	menu.native_quality_requested.connect(func(value: String):quality_requests.append(value))
	await process_frame;await process_frame
	var sharp: Button=menu.native_quality_buttons[1]
	var sharp_pixel := sharp.get_global_rect().get_center()
	var sharp_local := Vector3((sharp_pixel.x/1024-.5)*menu.SIZE.x,(.5-sharp_pixel.y/1024)*menu.SIZE.y,.5)
	var sharp_pose: Transform3D=menu.global_transform*Transform3D(Basis.IDENTITY,sharp_local)
	menu.pointer_step(.016,sharp_pose,true,false,0)
	menu.pointer_step(.016,sharp_pose,true,true,0)
	menu.pointer_step(.016,sharp_pose,true,false,0)
	check(quality_requests==["sharp"] and sharp.button_pressed,"VR ray selects Sharp directly without popup")
	check(not menu.native_quality_buttons[0].button_pressed and not menu.native_quality_buttons[2].button_pressed,"Quality selection is exclusive")
	check("restart" in menu.native_quality_hint.text,"Quality selection explains restart requirement")
	check(not menu.quit_confirmation.visible,"Quit requires confirmation")
	menu.show_quit_confirmation()
	check(menu.quit_confirmation.visible and "Save inside" in menu.quit_status.text,"Quit warns to save inside game first")
	menu.quality_saved(true)
	check("Settings saved" in menu.native_quality_hint.text,"Successful save confirmed")
	menu.quality_saved(false)
	check("Could not save" in menu.native_quality_hint.text,"Save failure is not reported as success")
	menu.quit_confirmation.hide()
	var field: LineEdit=menu.multiplayer_panel.address
	field.text="";field.caret_column=0
	menu.show_keyboard(field);menu._type("1");menu._type(".");menu._type("2")
	check(field.text=="1.2" and menu.keyboard.visible,"In-headset text entry")
	menu._backspace();check(field.text=="1.","Keyboard backspace")
	menu._shift();menu._type("a");check(field.text=="1.A","Keyboard shift")
	field.select_all();menu._backspace();check(field.text=="","Selected text deletion")
	check(menu.multiplayer_panel.password.secret,"Password remains masked")
	await process_frame;await process_frame
	# Actual ray-to-viewport click, not just invoking the keyboard callback.
	var key: Button=menu.letters[0]
	var pixel := key.get_global_rect().get_center()
	var local_point := Vector3((pixel.x/1024-.5)*menu.SIZE.x,(.5-pixel.y/1024)*menu.SIZE.y,.5)
	var key_pose: Transform3D=menu.global_transform*Transform3D(Basis.IDENTITY,local_point)
	menu.pointer_step(.016,key_pose,true,false,0)
	menu.pointer_step(.016,key_pose,true,true,0)
	menu.pointer_step(.016,key_pose,true,false,0)
	check(field.text=="Q","Trigger ray clicks rendered keyboard key")
	menu.pointer_step(.016,key_pose,true,true,0)
	menu.pointer_step(.016,key_pose,false,true,0)
	check(not menu.pointer_down,"Tracking loss releases pointer")
	check(field.text=="Q","Tracking loss cancels pending click without typing")
	menu.pointer_step(.016,key_pose,true,true,0)
	check(not menu.pointer_down and field.text=="Q","Held trigger cannot click again after tracking resumes")
	if "--capture-menu" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		menu.viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/validation/vr-menu-keyboard.png"))
		menu.keyboard.hide()
		await process_frame;await RenderingServer.frame_post_draw
		menu.viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/validation/vr-menu.png"))
	menu.close()
	check(not menu.visible and not menu.pointer_down and menu.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Close clears pointer and disables render")
	world.queue_free();print("VR MENU: %d checks, %d failures"%[checks,failures]);quit(failures)
