class_name PFAzaharBridge
extends "res://scripts/emulator_backend.gd"
## Local adapter for Azahar's separate-screen layout.
## The companion helper owns Windows capture and touch injection; Godot consumes
## its two local TCP frame streams and sends lower-screen touch over localhost.

const INPUT_PORT := 42502
const FRAME_PORT := 42503

var _top_texture: ImageTexture
var _bottom_texture: ImageTexture
var _udp := PacketPeerUDP.new()
var _tcp := StreamPeerTCP.new()
var _frame_bytes := PackedByteArray()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_set_state(false, "Bridge disabled")
		return
	var error := _udp.connect_to_host("127.0.0.1", INPUT_PORT)
	if error != OK:
		_set_state(false, "Bridge UDP unavailable (%s)" % error_string(error))
		return
	_tcp.connect_to_host("127.0.0.1", FRAME_PORT)
	_set_state(false, "Waiting for Azahar bridge frames")

func _process(delta: float) -> void:
	if not enabled:
		return
	_tcp.poll()
	if _tcp.get_status() == StreamPeerTCP.STATUS_ERROR:
		_tcp = StreamPeerTCP.new()
		_frame_bytes.clear()
	if _tcp.get_status() == StreamPeerTCP.STATUS_NONE:
		_tcp.connect_to_host("127.0.0.1", FRAME_PORT)
		return
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var available := _tcp.get_available_bytes()
	if available > 0:
		var received := _tcp.get_data(available)
		if received[0] == OK:
			_frame_bytes.append_array(received[1])
	_consume_frames()

func send_touch(uv: Vector2, pressed: bool) -> void:
	if not enabled:
		return
	# The helper maps these coordinates only to Azahar's secondary window.
	_udp.put_packet(("TOUCH %d %.6f %.6f" % [1 if pressed else 0, clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)]).to_utf8_buffer())

func send_button(button: String, pressed: bool) -> void:
	if enabled:
		_udp.put_packet(("BUTTON %s %d" % [button, 1 if pressed else 0]).to_utf8_buffer())

func send_stick(value: Vector2) -> void:
	if enabled:
		_udp.put_packet(("STICK %.4f %.4f" % [value.x, value.y]).to_utf8_buffer())

func load_game(content_path: String) -> void:
	# The capture bridge intentionally does not automate another application's
	# file UI. The inserted card becomes the selected title; current Azahar
	# sessions still load it through the user's own emulator library.
	_set_state(connected, "Cartridge selected · load in Azahar: " + content_path.get_file())

func _consume_frames() -> void:
	var latest_top := PackedByteArray()
	var latest_bottom := PackedByteArray()
	while _frame_bytes.size() >= 5:
		var size := _frame_bytes.decode_u32(1)
		if _frame_bytes.size() < 5 + size:
			break
		var kind := _frame_bytes[0]
		var bytes := _frame_bytes.slice(5, 5 + size)
		_frame_bytes = _frame_bytes.slice(5 + size)
		if kind == 1:
			latest_top = bytes
		elif kind == 2:
			latest_bottom = bytes
	# A live texture is not a video archive: decode only the most recent
	# complete frame from each screen and discard stale queued frames.
	if not latest_top.is_empty():
		_load_frame(latest_top, true)
	if not latest_bottom.is_empty():
		_load_frame(latest_bottom, false)

func _load_frame(bytes: PackedByteArray, upper: bool) -> void:
	var image := Image.new()
	if image.load_bmp_from_buffer(bytes) != OK:
		return
	var texture := ImageTexture.create_from_image(image)
	if upper:
		_top_texture = texture
	else:
		_bottom_texture = texture
	if device and _top_texture and _bottom_texture:
		device.set_screen_textures(_top_texture, _bottom_texture)
		_set_state(true, "Azahar top + bottom connected")

func _set_state(value: bool, detail: String) -> void:
	if connected == value and message == detail:
		return
	connected = value
	message = detail
	connection_changed.emit(connected, message)
