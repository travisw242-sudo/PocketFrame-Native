extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var rooms=preload("res://scripts/room_builder.gd").available_rooms()
	check(rooms.size()==1 and rooms[0].id=="studio","Native build contains Studio only")
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name")=="PocketFrame Native","Native profile is isolated")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://native_boot.tscn","Native boot bypasses Windows launcher")
	check(ProjectSettings.get_setting("xr/openxr/enabled"),"OpenXR enabled for headset")
	var ar=preload("res://scripts/ar_mode.gd")
	check(not ar.supported([XRInterface.XR_ENV_BLEND_MODE_OPAQUE]),"No fake passthrough without alpha")
	check(ar.supported([XRInterface.XR_ENV_BLEND_MODE_OPAQUE,XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND]),"Supports return from AR to Studio")
	var menu=preload("res://scripts/vr_menu.gd").new();root.add_child(menu);menu.setup(null,"Player")
	check(menu.native_quality_buttons.size()==3,"Three direct quality buttons retained")
	check(menu.native_quality_buttons[0].button_pressed,"Start at native 1x")
	menu.select_native_quality(2)
	check(menu.native_quality_buttons[2].button_pressed and not menu.native_quality_buttons[0].button_pressed,"Restores selected quality without popup")
	menu.update_native_view(false,false,"Unavailable")
	check(menu.native_ar.disabled and not menu.native_ar.button_pressed,"Unavailable AR disabled in menu")
	check(not menu.native_studio.disabled and menu.native_studio.button_pressed,"Studio stays available without passthrough")
	menu.update_native_view(true,true,"Available")
	check(not menu.native_ar.disabled and menu.native_ar.button_pressed,"AR state reflected in headset")
	check(not menu.native_studio.button_pressed and "AR PASSTHROUGH" in menu.native_view_state.text,"Current view clearly labeled and exclusive")
	check(not menu.native_eye_swap.button_pressed,"Stereo eye ordering defaults unchanged")
	menu.queue_free();await process_frame
	print("NATIVE SHELL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
