extends VBoxContainer
## Desktop setup for the emulator's private local-wireless room, not VR avatars.
var backend: Node
var nickname: LineEdit
var address: LineEdit
var port: SpinBox
var password: LineEdit
var status: Label
var elapsed := 0.0
var pending_until := 0
var text_scale := 1.0
const ERRORS := ["Connection lost.","Host removed this player.","Network error.",
	"Nickname is already in use.","Console network address is already in use.",
	"Console ID is already in use. Each player needs their own emulator profile.",
	"Incompatible emulator room version.","Incorrect room password.",
	"Could not reach the host. Check address, UDP port, firewall and router/VPN.",
	"Room is full.","Host blocked this player.","Permission denied.","Player not found."]

func setup(runtime: Node, player_name: String, scale_factor: float = 1.0) -> void:
	text_scale=scale_factor
	backend=runtime
	name="MultiplayerPanel"
	add_theme_constant_override("separation",8)
	_label("MULTIPLAYER · PRIVATE GAME CONNECTION",14)
	_label("Each player loads their own game. Connect here, then choose LOCAL wireless inside the game. No shared VR room or Nintendo online service.",12)
	var saved := ConfigFile.new()
	saved.load("user://multiplayer.cfg")
	nickname=_field("Nickname (4–20 letters/numbers)",str(saved.get_value("network","nickname",player_name if player_name.length()>=4 else "Player")))
	nickname.max_length=20
	address=_field("Host address / VPN IP",str(saved.get_value("network","address","127.0.0.1")))
	_label("UDP port",12)
	port=SpinBox.new();port.min_value=1024;port.max_value=65535;port.value=int(saved.get_value("network","port",24872));add_child(port)
	password=_field("Room password (not saved)","")
	password.secret=true
	var buttons := HBoxContainer.new();add_child(buttons)
	for option in [["Host",1],["Join",2],["Disconnect",0]]:
		var button := Button.new();button.text=option[0];buttons.add_child(button)
		if text_scale>1:
			button.custom_minimum_size.y=56
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.pressed.connect(_request.bind(option[1]))
	status=_label("Disconnected · insert a cartridge before connecting.",12)
	_label("Internet: host forwards UDP 24872 (or your chosen port), or both players use a private VPN. Use a password. Only allow firewall access on networks you trust. No automatic router/firewall changes.",12)

func _label(text: String, size_px: int) -> Label:
	var label := Label.new();label.text=text
	label.add_theme_font_size_override("font_size",roundi(size_px*text_scale))
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x=260
	add_child(label);return label

func _field(title: String, value: String) -> LineEdit:
	_label(title,12)
	var field := LineEdit.new();field.text=value
	if text_scale>1:field.custom_minimum_size.y=48
	add_child(field);return field

func _request(mode: int) -> void:
	if not backend or not backend.has_method("configure_network"):
		status.text="Use the integrated Vulkan runtime for multiplayer.";return
	if mode!=0:
		var regex := RegEx.new();regex.compile("^[ a-zA-Z0-9._-]{4,20}$")
		if not regex.search(nickname.text): status.text="Use a nickname with 4–20 letters, numbers, spaces, dot, dash or underscore.";return
		if mode==1 and password.text.length()<8: status.text="Choose a room password with at least 8 characters before hosting.";return
		if mode==2 and address.text.strip_edges().is_empty(): status.text="Enter the host's address.";return
		if not backend.accepting_frames: status.text="Insert a game cartridge first, then Host or Join.";return
		if not backend.connected: status.text="Wait for the game to finish loading, then Host or Join.";return
	var saved := ConfigFile.new()
	saved.set_value("network","nickname",nickname.text)
	saved.set_value("network","address",address.text.strip_edges())
	saved.set_value("network","port",int(port.value))
	saved.save("user://multiplayer.cfg") # Deliberately excludes passwords and auto-connect.
	backend.configure_network(mode,nickname.text,address.text.strip_edges(),int(port.value),password.text if mode!=0 else "")
	status.text="Connecting…" if mode!=0 else "Disconnecting…"
	pending_until=Time.get_ticks_msec()+1000
	if mode==0: password.clear()

static func describe(raw: String) -> String:
	var parts := raw.split("|")
	if parts.size()!=4: return raw
	var state := int(parts[0]);var count := int(parts[1]);var error := int(parts[2])
	if error>=0 and error<ERRORS.size(): return ERRORS[error]
	if error<-100:
		return {-101:"Invalid connection settings.",-102:"Could not initialize networking.",-103:"Cannot host on this UDP port. Another host may be using it.",-104:"Load a game before connecting.",-105:"This emulator core needs the multiplayer update."}.get(error,"Network startup failed.")
	if state>=3: return ("Hosting" if int(parts[3])==1 else "Connected")+" · %d player(s) · use local wireless in-game"%count
	if state==2: return "Connecting…"
	return "Disconnected"

func _process(delta: float) -> void:
	if not status or not backend or not backend.has_method("network_status"): return
	elapsed+=delta
	if elapsed<.5 or Time.get_ticks_msec()<pending_until: return
	elapsed=0
	status.text=describe(backend.network_status())
