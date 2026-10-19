class_name PFEmulatorBackend
extends Node
## Transport-independent contract between the PocketFrame interaction layer and
## an emulator runtime. Implementations must keep only the newest video frame.

signal connection_changed(connected: bool, message: String)

var device: PFHandheld
var enabled := false
var connected := false
var message := "Emulator disabled"
var output_volume := 0.7
var stereo_depth := 0.0
var player_name := "Player"

func set_stereo_depth(value: float) -> void:
	stereo_depth = clampf(value, 0, 1)

func set_player_name(value: String) -> void:
	player_name = value.strip_edges().left(10)
	if player_name.is_empty(): player_name = "Player"

func set_volume(value: float) -> void:
	output_volume = clampf(value, 0, 1)

func attach(target: PFHandheld) -> void:
	device = target

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_set_state(false, "Emulator disabled")

func send_touch(_uv: Vector2, _pressed: bool) -> void:
	pass

func send_button(_button: String, _pressed: bool) -> void:
	pass

func send_stick(_value: Vector2) -> void:
	pass

func load_game(_content_path: String) -> void:
	_set_state(false, "No emulator runtime is available to load this cartridge")

func unload_game() -> void:
	_set_state(false,"No cartridge loaded")

func _set_state(value: bool, detail: String) -> void:
	if connected == value and message == detail:
		return
	connected = value
	message = detail
	connection_changed.emit(connected, message)
