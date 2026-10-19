extends SceneTree
var failures := 0
func check(ok: bool,title: String) -> void:
	print("SHELL PICKER ",title,": ","PASS" if ok else "FAIL")
	if not ok:failures+=1
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var world := Node3D.new();root.add_child(world)
	var menu=preload("res://scripts/vr_menu.gd").new();world.add_child(menu);menu.setup(null,"Player")
	var chosen: Array[String]=[];menu.native_shell_requested.connect(func(id: String):chosen.append(id))
	check(menu.shell_buttons.size()==10,"all ten Windows finishes available")
	check(not menu.shell_grid.visible,"swatches start collapsed")
	menu.open_at(Transform3D.IDENTITY);menu.shell_grid.show()
	await process_frame;await process_frame
	var pixel: Vector2=menu.shell_buttons[0].get_global_rect().get_center()
	var point := Vector3((pixel.x/1024-.5)*menu.SIZE.x,(.5-pixel.y/1024)*menu.SIZE.y,.5)
	var pose: Transform3D=menu.global_transform*Transform3D(Basis.IDENTITY,point)
	menu.pointer_step(.016,pose,true,false,0);menu.pointer_step(.016,pose,true,true,0);menu.pointer_step(.016,pose,true,false,0)
	check(chosen==["nebula"] and menu.shell_buttons[0].button_pressed,"controller ray selects Nebula swatch")
	for item in menu.Shells.ITEMS:
		menu._choose_shell(item.id)
		check(chosen.back()==item.id and menu.shell_buttons[menu.Shells.index(item.id)].button_pressed,"select "+item.name)
	menu._choose_shell("")
	check(menu.classic_shell.button_pressed and not menu.shell_buttons[9].button_pressed,"classic selection is exclusive")
	var count := chosen.size();menu._choose_shell("invalid")
	check(chosen.size()==count,"unknown shell rejected")
	world.queue_free();await process_frame
	print("SHELL PICKER failures=",failures);quit(failures)
