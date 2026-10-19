extends SceneTree
const NetPanel=preload("res://scripts/multiplayer_panel.gd")
var failures := 0
var checks := 0
func check(ok: bool,title: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(title)
func _initialize() -> void:
	check(NetPanel.describe("3|2|-1|1").contains("Hosting · 2"),"Host count")
	check(NetPanel.describe("3|2|-1|0").contains("Connected · 2"),"Join count")
	check(NetPanel.describe("2|0|-1|0")=="Connecting…","Connecting state")
	check(NetPanel.describe("1|0|7|0")=="Incorrect room password.","Password error")
	check(NetPanel.describe("1|0|5|0").contains("Console ID"),"Duplicate console guidance")
	check(NetPanel.describe("1|0|-103|0").contains("UDP port"),"Port conflict guidance")
	check(NetPanel.describe("1|0|8|0").contains("router/VPN"),"Unreachable host guidance")
	check(NetPanel.describe("1|0|-1|0")=="Disconnected","Disconnected state")
	check(NetPanel.describe("Insert a game cartridge first.").begins_with("Insert"),"No game guidance")
	var panel=NetPanel.new();root.add_child(panel);panel.setup(null,"Player")
	check(panel.password.secret and panel.password.text.is_empty(),"Password masked and not restored")
	check(int(panel.port.value)>=1024,"Nonprivileged UDP port")
	panel._request(1)
	check(panel.status.text.contains("integrated Vulkan"),"Missing runtime handled")
	panel.queue_free()
	print("MULTIPLAYER UI: %d checks, %d failures"%[checks,failures]);quit(failures)
