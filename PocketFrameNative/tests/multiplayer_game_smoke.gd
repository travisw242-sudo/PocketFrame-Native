extends SceneTree
## Explicit ROM read-only boot with isolated profile; no game input/save edits.
var core: Node
var started := 0
var hosting := false
var host_ready := false
var finished := false
var port := 24993
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var game := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game="):game=arg.trim_prefix("--game=")
	if game.is_empty() or not FileAccess.file_exists(game):quit(2);return
	core=ClassDB.instantiate("PFAzaharCore");root.add_child(core)
	core.start();core.set_resolution_factor(1);core.load_game(game)
	started=Time.get_ticks_msec()
func _process(_delta: float) -> bool:
	if finished or core==null:return false
	if Time.get_ticks_msec()-started>45000:
		finished=true;push_error("Multiplayer game smoke timed out: "+str(core.get_network_status()));core.queue_free();quit(1);return false
	if not hosting and core.get_presented_frame_count()>30:
		hosting=true
		core.configure_network(1,"FrameHost","127.0.0.1",port,"TestPass")
	var state: PackedStringArray=core.get_network_status().split("|")
	if state.size()==4 and int(state[0])>=3 and not host_ready:
		host_ready=true;print("HOST READY")
	if state.size()==4 and int(state[0])>=3 and int(state[1])>=2:
		finished=true
		print("PASS GAME MULTIPLAYER: rendered %d frames, room status %s"%[core.get_presented_frame_count(),core.get_network_status()])
		# Let the peer verify reconnecting to the same live game host.
		create_timer(5).timeout.connect(func():
			core.configure_network(0,"","",port,"")
			core.queue_free();quit(0))
	return false
