extends SceneTree
## Opt-in GPU lifecycle test. Reads two explicit ROMs; sends no gameplay input.
const Device=preload("res://scripts/handheld.gd")
const Backend=preload("res://scripts/azahar_in_process_backend.gd")
const Rack=preload("res://scripts/cartridge_rack.gd")
var device: Node3D
var backend: Node
var rack: Node3D
var games: Array[String]=[]
var began:=0
var phase:=0
var finishing:=false
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game="): games.append(ProjectSettings.globalize_path(arg.trim_prefix("--game=")))
	if games.size()!=2:
		push_error("Explicit --game= paths for two cartridges required")
		quit(1);return
	device=Device.new()
	root.add_child(device)
	device.position=Vector3(0,1,-.5)
	backend=Backend.new()
	root.add_child(backend)
	backend.attach(device)
	backend.set_quality("sharp")
	backend.set_stereo_depth(.2)
	backend.set_enabled(true)
	device.cartridge_slot.cartridge_inserted.connect(func(c): print("SWAP LOAD: ",c.display_name);backend.load_game(c.content_path))
	device.cartridge_slot.cartridge_ejected.connect(func(_c): backend.unload_game())
	rack=Rack.new()
	root.add_child(rack)
	rack.setup(device,device.global_transform)
	rack.mount_path(games[0])
	began=Time.get_ticks_msec()
func _process(_delta: float) -> bool:
	if began==0 or finishing: return false
	if backend.message.begins_with("Native runtime:"):
		_finish(1,backend.message);return false
	if Time.get_ticks_msec()-began>45000: _finish(1,"GPU swap timed out: "+backend.message);return false
	var frames: int=backend._core.get_presented_frame_count()
	if phase in [0,1] and backend.connected and frames>=90:
		print("SWAP PHASE ",phase,": game producing ",frames," frames")
		rack.eject()
		if device.stereo_material!=null or backend.connected:
			_finish(1,"Ejection did not immediately clear game screens");return false
		print("SWAP EJECT: output cleared immediately")
		if phase==0:
			rack.return_popped()
			# Exercise queued reload while the old worker can still be shutting down.
			if not rack.mount_path(games[1]): _finish(1,"Second card could not enter");return false
		phase+=1
	elif phase==2 and backend.message.contains("no cartridge loaded") and frames==0:
		_finish(0,"load / eject / queued replacement / eject passed; runtime idle")
	return false
func _finish(code: int,message: String) -> void:
	finishing=true
	print("CARTRIDGE GPU SMOKE: ",message)
	backend.set_enabled(false)
	await process_frame
	quit(code)
