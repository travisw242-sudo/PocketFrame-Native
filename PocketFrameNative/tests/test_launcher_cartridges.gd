extends SceneTree
const Rooms=preload("res://scripts/room_builder.gd")
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var launcher=load("res://launcher.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	check(Rooms.available_rooms()[1].id=="teen_2008" and Rooms.available_rooms()[1].name=="Bedroom","Bedroom label changes without breaking saved preset IDs")
	check(launcher.room_choice.get_item_text(1)=="Bedroom","Launcher displays Bedroom")
	check(launcher.find_children("*","FileDialog",true,false).is_empty(),"No startup game picker")
	check(not launcher.vr_button.disabled and not launcher.desktop_button.disabled,"Both session modes enabled")
	var args: PackedStringArray=launcher._session_arguments()
	check(not args.has("-Game") and not " ".join(args).contains("--game="),"Launch command does not select or auto-insert a game")
	check(args.has("-Backend") and args.has("-Quality") and args.has("-Room"),"Renderer, quality and room choices retained")
	launcher.games.clear()
	launcher._update_library_status()
	check(not launcher.vr_button.disabled and not launcher.desktop_button.disabled,"Empty library does not prevent launching")
	check(launcher.library_status.text.contains("still explore"),"Empty-library status explains room access")
	launcher.queue_free()
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	check(main.startup_game_path.is_empty(),"Normal startup has no requested game")
	check(main.cartridge_rack.seated==null and main.cartridge_rack.mode=="empty","Console starts with empty cartridge slot")
	main.queue_free()
	print("CARTRIDGE LAUNCHER: %d checks, %d failures" % [checks,failures])
	quit(failures)
