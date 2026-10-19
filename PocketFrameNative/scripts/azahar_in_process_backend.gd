class_name PFAzaharInProcessBackend
extends "res://scripts/emulator_backend.gd"
## Host-side half of the future GDExtension integration.
##
## `PFAzaharCore` is intentionally absent until the native extension is built.
## Keeping this adapter in GDScript lets the VR model and input routing be
## completed and tested before the C++ toolchain is available.

const EXTENSION_CLASS := "PFAzaharCore"
const GameAudio = preload("res://scripts/game_audio.gd")
var game_audio := GameAudio.new()
var _core: Object
var native_fps := 0.0
var _sample_elapsed := 0.0
var _last_presented_frame_count := 0
var quality := "balanced"
var accepting_frames := false
var multiplayer_requested := false
var paused := false

func set_paused(value: bool) -> void:
	paused=value
	_call_core("set_paused",[value])

func is_running() -> bool:
	return _core!=null and _core.has_method("is_running") and bool(_core.call("is_running"))

func configure_network(mode: int, nickname: String, address: String, port: int, password: String) -> void:
	multiplayer_requested=mode!=0
	_call_core("configure_network",[mode,nickname,address,port,password])

func network_status() -> String:
	if not _core or not _core.has_method("get_network_status"):
		return "Networking runtime is unavailable."
	if not accepting_frames:
		return "Insert a game cartridge first."
	return str(_core.call("get_network_status"))

func set_stereo_depth(value: float) -> void:
	super.set_stereo_depth(value)
	_call_core("set_stereo_depth", [stereo_depth])

func set_player_name(value: String) -> void:
	super.set_player_name(value)
	_call_core("set_player_name", [player_name])

func set_volume(value: float) -> void:
	super.set_volume(value)
	game_audio.set_level(output_volume)

func set_quality(value: String) -> void:
	quality = value.to_lower()
	if _core and _core.has_method("set_resolution_factor"):
		_core.call("set_resolution_factor", preload("res://scripts/quality_presets.gd").factor(quality))

func set_enabled(value: bool) -> void:
	super.set_enabled(value)
	if not enabled:
		if _core is Node and is_instance_valid(_core):
			_core.queue_free()
		_core = null
		return
	if not ClassDB.class_exists(EXTENSION_CLASS):
		_set_state(false, "Native ARM64 runtime is missing or could not be loaded")
		return
	_core = ClassDB.instantiate(EXTENSION_CLASS)
	if _core == null:
		_set_state(false, "Integrated runtime could not start")
		return
	if _core is Node:
		_core.child_entered_tree.connect(game_audio.attach_player)
		add_child(_core)
	set_quality(quality)
	set_stereo_depth(stereo_depth)
	set_player_name(player_name)
	# The future extension owns its emulation thread. Its `frame_ready` signal
	# will hand the newest pair of ImageTextures back on Godot's main thread.
	if _core.has_signal("frame_ready"):
		_core.connect("frame_ready", _on_frame_ready)
	if _core.has_signal("state_changed"):
		_core.connect("state_changed", _on_state_changed)
	if _core.has_method("start"):
		_core.call("start")
	# Loading the extension only proves that the bridge is available.  The
	# native worker changes this to connected after a legal game is loaded and
	# it has produced its first frame.
	_set_state(false, "Integrated runtime available · no game loaded")

func send_touch(uv: Vector2, pressed: bool) -> void:
	_call_core("set_touch", [uv, pressed])

func send_button(button: String, pressed: bool) -> void:
	_call_core("set_button", [button, pressed])

func send_stick(value: Vector2) -> void:
	_call_core("set_circle_pad", [value])

func load_game(content_path: String) -> void:
	accepting_frames=true
	_last_presented_frame_count=0
	_sample_elapsed=0
	native_fps=0
	_call_core("load_game", [content_path])
	_set_state(false, "Loading cartridge: " + content_path.get_file())

func unload_game() -> void:
	accepting_frames=false
	_last_presented_frame_count=0
	_sample_elapsed=0
	native_fps=0
	_call_core("unload_game",[])
	if device: device.clear_screen_textures()
	_set_state(false,"Cartridge ejected · no game loaded")

func _process(delta: float) -> void:
	game_audio.update(delta)
	_sample_elapsed += delta
	if _sample_elapsed < 1.0:
		return
	var current_frame_count := _last_presented_frame_count
	if _core and _core.has_method("get_presented_frame_count"):
		current_frame_count = int(_core.call("get_presented_frame_count"))
	native_fps = (current_frame_count - _last_presented_frame_count) / _sample_elapsed
	_last_presented_frame_count = current_frame_count
	_sample_elapsed = 0.0
	if connected:
		_set_state(true, "Native Azahar runtime connected · %.1f FPS" % native_fps)

func _call_core(method: String, args: Array) -> void:
	if _core and _core.has_method(method):
		_core.callv(method, args)

func _on_frame_ready(top: Texture2D, bottom: Texture2D) -> void:
	if device and accepting_frames:
		device.set_screen_textures(top, bottom)

func _on_state_changed(is_connected: bool, detail: String) -> void:
	if is_connected and not accepting_frames: return
	_set_state(is_connected, detail)
