extends SceneTree
var failures := 0
func check(ok: bool,title: String) -> void:
	print("PREVIEW ",title,": ","PASS" if ok else "FAIL")
	if not ok:failures+=1
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var main=load("res://main.tscn").instantiate();root.add_child(main);main.set_process(false)
	var path := ProjectSettings.globalize_path("res://../outputs/validation/native-preview-settings.cfg")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir());main.settings_path=path
	main.config.set_value("test","sentinel","preserved")
	main.vr_menu._choose_native_quality(1)
	var saved := ConfigFile.new();check(saved.load(path)==OK,"quality saved immediately")
	check(saved.get_value("device","render_quality","")=="sharp","quality persists across config reload")
	check(saved.get_value("test","sentinel","")=="preserved","unrelated config entries preserved")
	for item in main.vr_menu.Shells.ITEMS:
		main.vr_menu._choose_shell(item.id)
		saved.load(path)
		check(main.device.shell_design==item.id and saved.get_value("device","shell_design","")==item.id,"live shell and persistence: "+item.name)
	main.vr_menu._choose_shell("")
	check(main.device.shell_design.is_empty() and main.device.body_material.albedo_color.is_equal_approx(Color("303841")),"classic restores graphite")
	main._set_session_paused(true);check(main.session_paused,"session pause handled")
	main._set_session_paused(false);check(not main.session_paused,"session resume handled")
	main.vr_menu.show_quit_confirmation();check(main.vr_menu.quit_confirmation.visible,"headset quit confirmation available")
	main._quit_cleanly();check(main.quitting,"clean quit entered")
	check(not main.settings_dirty,"settings flushed before exit")
	print("PREVIEW COMPLETE failures=",failures);quit(failures)
