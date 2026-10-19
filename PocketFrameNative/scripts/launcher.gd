extends Control

const Rooms = preload("res://scripts/room_builder.gd")
const Quality = preload("res://scripts/quality_presets.gd")
const Paths = preload("res://scripts/app_paths.gd")
const Shells = preload("res://scripts/shell_catalog.gd")
var selected_shell := ""
var shell_buttons: Array[Button]=[]
var shell_status: Label
const INK := Color("e8f0f4")
const MUTED := Color("94a9b8")
const ACCENT := Color("82e1c4")
var saved := ConfigFile.new()
var device_settings := ConfigFile.new()
var library_status: Label
var quality_choice: OptionButton
var backend_choice: OptionButton
var room_choice: OptionButton
var color_choice: OptionButton
var games: Array[String] = []
var fit_controls: Dictionary = {}
var grip_check: CheckBox
var stylus_side_choice: OptionButton
var stylus_return_check: CheckBox
var hand_model_choice: OptionButton
var status: Label
var vr_button: Button
var desktop_button: Button
var launching := false
var launch_result_path := ""
var launch_deadline := 0
var launch_is_desktop := false
var pending_capture := ""
var volume_seen := 0.7
var depth_seen := 0.0
var player_name_edit: LineEdit
var volume_sync_time := 0.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--audit-export" in args:
		get_tree().quit(0 if preload("res://scripts/release_audit.gd").run() else 1)
		return
	if "--session" in args or "--emulator-integrated" in args or "--emulator-bridge" in args or "--desktop" in args or "--beauty" in args or "--room-preview" in args:
		get_tree().change_scene_to_file.call_deferred("res://main.tscn")
		return
	get_window().title = "PocketFrame · Launcher"
	get_window().content_scale_size = Vector2i(960, 870)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().min_size = Vector2i(860, 710)
	get_window().size = Vector2i(960, 870)
	get_window().move_to_center()
	saved.load("user://launcher.cfg")
	device_settings.load("user://settings.cfg")
	volume_seen = float(device_settings.get_value("device", "volume", 0.7))
	depth_seen = float(device_settings.get_value("device", "stereo_depth", 0))
	selected_shell=str(device_settings.get_value("device","shell_design",""))
	_build_theme()
	_build_ui()
	_scan_games()
	if "--launcher-fit-preview" in OS.get_cmdline_user_args():
		(find_child("SettingsTabs", true, false) as TabContainer).current_tab = 1
	if "--launcher-shells-preview" in OS.get_cmdline_user_args():
		(find_child("SettingsTabs",true,false) as TabContainer).current_tab=2
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--launcher-preview="):
			pending_capture = arg.trim_prefix("--launcher-preview=")
	if not pending_capture.is_empty():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pending_capture)
		var icon := preload("res://icon.svg").get_image()
		icon.save_png(ProjectSettings.globalize_path("res://launcher-icon.png"))
		get_tree().quit()

func _box(color: Color, radius: int = 10, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box

func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	for kind in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, _box(Color("253749")))
		theme.set_stylebox("hover", kind, _box(Color("334d60")))
		theme.set_stylebox("pressed", kind, _box(Color("3a6067")))
		theme.set_stylebox("disabled", kind, _box(Color("1b2733")))
		var focus := _box(Color(0, 0, 0, 0))
		focus.border_color = ACCENT
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", kind, focus)
		theme.set_color("font_color", kind, INK)
		theme.set_color("font_disabled_color", kind, MUTED)
	theme.set_stylebox("panel", "PopupMenu", _box(Color("233444")))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_stylebox("panel", "TabContainer", _box(Color("152432"), 12, 22))
	theme.set_stylebox("tab_selected", "TabContainer", _box(Color("253b4b"), 8, 12))
	theme.set_stylebox("tab_unselected", "TabContainer", _box(Color("111c27"), 8, 12))
	theme.set_color("font_selected_color", "TabContainer", ACCENT)
	theme.set_color("font_unselected_color", "TabContainer", MUTED)

func _label(parent: Node, text: String, size_px: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _dropdown(parent: Node, title: String, labels: Array[String], selected: int) -> OptionButton:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 7)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(group)
	_label(group, title, 14, MUTED)
	var choice := OptionButton.new()
	choice.custom_minimum_size.y = 44
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in labels:
		choice.add_item(item)
	choice.select(clampi(selected, 0, maxi(0, labels.size() - 1)))
	group.add_child(choice)
	return choice

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0c1620")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	column.add_child(header)
	var icon := TextureRect.new()
	icon.texture = preload("res://icon.svg")
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var heading := VBoxContainer.new()
	header.add_child(heading)
	_label(heading, "PocketFrame", 30)
	_label(heading, "Your handheld. Your games. Your space.", 15, MUTED)
	var badge := _label(header,"PREVIEW 0.2",12,ACCENT)
	badge.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var tabs := TabContainer.new()
	tabs.name = "SettingsTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	var play := VBoxContainer.new()
	var play_scroll := ScrollContainer.new()
	play_scroll.name = "Play"
	play_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(play_scroll)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.add_theme_constant_override("separation", 11)
	play_scroll.add_child(play)
	_label(play, "Ready when you are", 22)
	library_status = _label(play,"Scanning cartridge library…",14,ACCENT)
	library_status.name="CartridgeLibraryStatus"
	var cartridge_tip := _label(play,"Start with an empty console. Insert a cartridge from the tray to play.\nAdd your games to the games folder; no game selection is needed here.",14,MUTED)
	cartridge_tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var graphics := HBoxContainer.new()
	graphics.add_theme_constant_override("separation", 18)
	play.add_child(graphics)
	var current_quality := str(device_settings.get_value("device", "render_quality", "sharp"))
	quality_choice = _dropdown(graphics, "Image quality", Quality.LABELS, Quality.index(current_quality))
	backend_choice = _dropdown(graphics, "Renderer", ["Vulkan"], 0)
	backend_choice.disabled = true
	var names: Array[String] = []
	var selected_room := 0
	var available := Rooms.available_rooms()
	for i in range(available.size()):
		names.append(available[i].name)
		if available[i].id == device_settings.get_value("device", "room", "studio"):
			selected_room = i
	room_choice = _dropdown(play, "Room", names, selected_room)
	var tip := _label(play, "Sharp is recommended. Ultra renders at 3× and needs more GPU headroom.\nQuality changes apply to your next session.", 14, ACCENT)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for choice in [quality_choice, backend_choice, room_choice]:
		choice.item_selected.connect(func(_i: int): _save())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play.add_child(spacer)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	play.add_child(tools)
	_button(tools, "Start SteamVR", func(): OS.shell_open("steam://rungameid/250820"))
	_button(tools, "Refresh games", _scan_games)
	_button(tools, "Games folder", func(): OS.shell_open(Paths.games_folder()))
	_label(play, "For VR: connect your headset and have SteamVR ready before launching.", 14, MUTED)
	var multiplayer_tip := _label(play,"Multiplayer: load a cartridge, then free your right hand and hold Y for the headset menu. Point + trigger to click. See MULTIPLAYER.txt for Internet setup.",13,MUTED)
	multiplayer_tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_build_fit_tab(tabs)
	_build_shell_tab(tabs)
	status = _label(column, "Ready to play. Your choices are saved automatically.", 14, MUTED)
	status.custom_minimum_size.y = 44
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	vr_button = _button(actions, "Launch in VR", func(): _launch(false))
	vr_button.custom_minimum_size.y = 56
	vr_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vr_button.add_theme_stylebox_override("normal", _box(Color("78dbbc")))
	vr_button.add_theme_stylebox_override("hover", _box(Color("a1edd6")))
	vr_button.add_theme_color_override("font_color", Color("102c2b"))
	desktop_button = _button(actions, "Play on desktop", func(): _launch(true))
	desktop_button.custom_minimum_size.y = 56
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	_button(footer, "App folder", func(): OS.shell_open(Paths.root_folder()))
	_button(footer, "VR controls", _show_controls)
	_button(footer, "Session logs", func():
		OS.shell_open(Paths.logs_folder()))

func _show_controls() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "PocketFrame · VR controls"
	dialog.dialog_text = "Grip a side to pick up the console. Click that hand's stick to LOCK.\nRelease grip while locked; click again to UNLOCK. Free both hands to dock.\n\nWith a FREE hand, GRIP the lid's top rim to adjust its angle.\nGRIP the mint pen cap and pull straight outward until clear.\nThe pen eases into a writing grip. Touch its actual tip to the lower LCD.\nGuide the tip into the slot, push inward and release grip to store.\nDropped pens auto-return after a short pause (unless disabled).\n\nVOLUME: touch the LEFT-side slider cap with a free index finger or thumb.\nNo button press needed. Slide toward the HINGE for louder, toward the\nFRONT for quieter; minimum mutes. Lift away to stop. A readout shows %.\nHold with the other hand or leave the console docked while adjusting.\n\nConsole fit: volume, left/right pen slot, auto-return, pen angle, hand fit.\nHand and pen use the same controller grip frame; fingers have joint limits.\nTriggers remain for gameplay / laser touch, not grabbing tools."
	add_child(dialog)
	dialog.dialog_text += "\n\n3D: touch the slider on the RIGHT of the upper LCD with a free finger.\nSlide UP away from the hinge for depth; DOWN fully for off. Start at 10–25%.\nLower LCD stays flat. H settings offers Swap 3D eyes if depth looks reversed.\nSet your profile name in Console fit BEFORE launching a game."
	dialog.dialog_text+="\n\nGAME CARDS: tray on your right. GRIP card, contacts-first and label\ntoward the console underside, then PUSH until it clicks. SAVE before removal.\nPress the card edge inward to eject; GRIP after it springs outward.\nPress NEXT PAGE with a free fingertip; lift off before pressing again.\nALL GAMES means the entire library fits on one page. Dropped cards return automatically."
	dialog.popup_centered(Vector2i(790, 370))

func _build_fit_tab(tabs: TabContainer) -> void:
	var fit := VBoxContainer.new()
	var fit_scroll := ScrollContainer.new()
	fit_scroll.name = "Console fit"
	fit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(fit_scroll)
	fit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fit.add_theme_constant_override("separation", 13)
	fit_scroll.add_child(fit)
	_label(fit, "Make it comfortable", 22)
	_label(fit, "These are the same console settings used inside PocketFrame.", 14, MUTED)
	_fit_slider(fit, "Console size", "scale", 0.8, 2.0, 0.05, 1.25)
	_fit_slider(fit, "Lid angle (degrees)", "lid_angle", 25, 175, 1, 145)
	_fit_slider(fit, "Console volume (%)", "volume", 0, 100, 1, 0.7, 100)
	_label(fit, "Emulated 3DS profile name (next game launch)", 14, MUTED)
	player_name_edit = LineEdit.new()
	player_name_edit.max_length = 10
	player_name_edit.text = str(device_settings.get_value("device", "player_name", "Player"))
	player_name_edit.placeholder_text = "Player · up to 10 characters"
	fit.add_child(player_name_edit)
	player_name_edit.text_changed.connect(func(value: String):
		device_settings.load("user://settings.cfg")
		device_settings.set_value("device", "player_name", value.strip_edges())
		device_settings.save("user://settings.cfg"))
	_label(fit, "Used when games ask for your system name; existing saves are not renamed.", 13, MUTED)
	_fit_slider(fit, "Stereoscopic 3D depth (%) · 0 = off", "stereo_depth", 0, 100, 1, 0, 100)
	_label(fit, "In VR, touch the slider on the right side of the UPPER lid and slide up.\nStart low (10–25%). Lower LCD stays flat. 3D may cost extra GPU time.", 13, MUTED)
	stylus_side_choice = _dropdown(fit, "Stylus slot", ["Left-handed · left side", "Right-handed · right side"], 1 if device_settings.get_value("device", "stylus_side", "left") == "right" else 0)
	stylus_side_choice.item_selected.connect(func(_i: int): _save())
	stylus_return_check = CheckBox.new()
	stylus_return_check.text = "Automatically return a dropped stylus"
	stylus_return_check.button_pressed = bool(device_settings.get_value("device", "stylus_auto_return", true))
	stylus_return_check.toggled.connect(func(_on: bool): _save())
	fit.add_child(stylus_return_check)
	_fit_slider(fit, "Stylus grip angle (degrees)", "stylus_grip_angle", 0, 60, 1, 25)
	_label(fit, "Hand / controller fit", 18)
	hand_model_choice = _dropdown(fit, "Hand model", ["Detailed hands", "Classic hands"], 1 if device_settings.get_value("device", "hand_model", "rigged") == "legacy" else 0)
	hand_model_choice.item_selected.connect(func(index: int):
		# Only an explicit selection writes this preference, so other launcher
		# changes cannot overwrite an in-game hand comparison made meanwhile.
		device_settings.load("user://settings.cfg")
		device_settings.set_value("device", "hand_model", "legacy" if index == 1 else "rigged")
		device_settings.save("user://settings.cfg"))
	_fit_slider(fit, "Hand tilt (degrees)", "hand_pitch", -40, 40, 1, 0)
	_fit_slider(fit, "Hand roll (degrees)", "hand_roll", -40, 40, 1, 0)
	_fit_slider(fit, "Hand wrist offset (cm)", "hand_offset", -4, 4, 0.25, 0, 100)
	_fit_slider(fit, "Grip pitch (degrees)", "grip_pitch", -90, 90, 1, 0)
	_fit_slider(fit, "Height offset (cm)", "height_offset", -5, 8, 0.5, 0.025, 100)
	_fit_slider(fit, "Pickup distance (cm)", "pickup_distance", 15, 35, 1, 0.23, 100)
	var color := str(device_settings.get_value("device", "shell_color", "303841"))
	color_choice = _dropdown(fit, "Console color", ["Graphite", "Pearl", "Crimson"], maxi(0, ["303841", "bfc3bf", "742b35"].find(color)))
	color_choice.item_selected.connect(func(_i: int): _save())
	color_choice.item_selected.connect(func(_i: int): _choose_shell(""))
	grip_check = CheckBox.new()
	grip_check.text = "Require grip confirmation in the desktop gesture simulator"
	grip_check.button_pressed = bool(device_settings.get_value("device", "require_grips", true))
	grip_check.toggled.connect(func(_value: bool): _save())
	fit.add_child(grip_check)

func _build_shell_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name="Shells";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",16)
	scroll.add_child(column)
	_label(column,"Make it yours",22)
	var note := _label(column,"Ten original finishes. Artwork wraps the outside lid and underside,\nwith coordinated colour on the inner deck. Applies to your next session.",14,MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var grid := GridContainer.new();grid.columns=5
	grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12)
	column.add_child(grid)
	for i in range(Shells.ITEMS.size()):
		var button := Button.new()
		button.custom_minimum_size=Vector2(154,125)
		button.toggle_mode=true
		button.tooltip_text=Shells.ITEMS[i].name
		grid.add_child(button);shell_buttons.append(button)
		var swatch := ColorRect.new()
		swatch.position=Vector2(9,8);swatch.size=Vector2(136,78)
		swatch.material=Shells.material(i,true);swatch.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(swatch)
		var label := _label(button,Shells.ITEMS[i].name,13)
		label.position=Vector2(0,94);label.size.x=154;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.pressed.connect(func(): _choose_shell(Shells.ITEMS[i].id))
	shell_status=_label(column,"",14,ACCENT)
	_button(column,"Use classic solid colour instead",func(): _choose_shell(""))
	_refresh_shell_selection()

func _refresh_shell_selection() -> void:
	for i in range(shell_buttons.size()): shell_buttons[i].set_pressed_no_signal(Shells.ITEMS[i].id==selected_shell)
	if shell_status: shell_status.text="Selected: "+(Shells.ITEMS[Shells.index(selected_shell)].name if Shells.index(selected_shell)>=0 else "Classic solid colour")

func _choose_shell(id: String) -> void:
	selected_shell=id
	device_settings.load("user://settings.cfg")
	device_settings.set_value("device","shell_design",id)
	device_settings.save("user://settings.cfg")
	_refresh_shell_selection()
	_save()

func _fit_slider(parent: Node, title: String, key: String, low: float, high: float, step_size: float, fallback: float, multiplier: float = 1) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label := _label(row, title, 14, MUTED)
	label.custom_minimum_size.x = 205
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step_size
	slider.value = float(device_settings.get_value("device", key, fallback)) * multiplier
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var readout := _label(row, "%.2f" % slider.value, 14)
	readout.custom_minimum_size.x = 56
	fit_controls[key] = {"slider": slider, "multiplier": multiplier, "readout": readout}
	slider.value_changed.connect(func(value: float): readout.text = "%.2f" % value; _save())

func _add_game(path: String) -> void:
	if games.has(path) or not FileAccess.file_exists(path):
		return
	games.append(path)

func _scan_games() -> void:
	games.clear()
	var folder := DirAccess.open(Paths.games_folder())
	if folder:
		var files := folder.get_files()
		files.sort()
		for file in files:
			if file.get_extension().to_lower() in preload("res://scripts/game_metadata.gd").FORMATS:
				_add_game(Paths.games_folder().path_join(file))
	_update_library_status()

func _update_library_status() -> void:
	library_status.text="%d games ready as cartridges" % games.size() if not games.is_empty() else "No cartridges yet — you can still explore the room."

func _save() -> void:
	if not is_instance_valid(grip_check) or not is_instance_valid(room_choice):
		return
	# Preserve unrelated preferences written by a running game since this UI opened.
	device_settings.load("user://settings.cfg")
	_sync_volume_from_setting(float(device_settings.get_value("device", "volume", 0.7)))
	_sync_depth_from_setting(float(device_settings.get_value("device", "stereo_depth", 0)))
	# Old selected-game / extra-game preferences are left intact but no longer
	# used for startup. The physical cartridge library owns game selection.
	saved.set_value("launcher", "backend", "vulkan" if backend_choice.selected == 0 else "opengl")
	saved.save("user://launcher.cfg")
	device_settings.set_value("device", "render_quality", Quality.IDS[quality_choice.selected])
	device_settings.set_value("device", "room", Rooms.available_rooms()[room_choice.selected].id)
	device_settings.set_value("device", "shell_color", ["303841", "bfc3bf", "742b35"][color_choice.selected])
	device_settings.set_value("device", "require_grips", grip_check.button_pressed)
	device_settings.set_value("device", "stylus_side", "right" if stylus_side_choice.selected == 1 else "left")
	device_settings.set_value("device", "stylus_auto_return", stylus_return_check.button_pressed)
	for key in fit_controls:
		device_settings.set_value("device", key, fit_controls[key].slider.value / fit_controls[key].multiplier)
	var error := device_settings.save("user://settings.cfg")
	if status and error != OK:
		status.text = "Could not save settings. Please check that your user folder is writable."

func _session_arguments() -> PackedStringArray:
	return PackedStringArray(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", ProjectSettings.globalize_path("res://Launch-Vulkan-Test.ps1"), "-Backend", "vulkan" if backend_choice.selected == 0 else "opengl", "-Quality", Quality.IDS[quality_choice.selected], "-Room", Rooms.available_rooms()[room_choice.selected].id])

func _launch(desktop: bool) -> void:
	if launching:
		return
	_save()
	if Paths.packaged():
		_launch_packaged(desktop)
		return
	var args := _session_arguments()
	if desktop:
		args.append("-Desktop")
	launch_result_path = "user://launcher-result-%d.json" % Time.get_ticks_usec()
	args.append_array(["-ResultFile", ProjectSettings.globalize_path(launch_result_path)])
	vr_button.disabled = true
	desktop_button.disabled = true
	status.text = "Starting PocketFrame…"
	launching = true
	launch_is_desktop = desktop
	launch_deadline = Time.get_ticks_msec() + 45000
	var process := OS.create_process("powershell.exe", args, false)
	if process < 0:
		_launch_finished(1, "Windows could not start the launch helper.", desktop)

func _launch_packaged(desktop: bool) -> void:
	var lock_path := "user://session-lock.json"
	if FileAccess.file_exists(lock_path):
		var lock_data=JSON.parse_string(FileAccess.get_file_as_string(lock_path))
		if lock_data is Dictionary and OS.is_process_running(int(lock_data.get("pid",-1))):
			_launch_finished(1,"A PocketFrame session is already running. Close it before launching another.",desktop)
			return
	var args := PackedStringArray(["--xr-mode","off" if desktop else "on","--log-file",Paths.logs_folder().path_join("session-%d.log"%Time.get_unix_time_from_system()),"--","--session","--emulator-integrated","--quality="+Quality.IDS[quality_choice.selected],"--room="+Rooms.available_rooms()[room_choice.selected].id])
	if desktop: args.append("--desktop")
	var previous_backend := OS.get_environment("POCKETFRAME_GPU")
	var previous_root := OS.get_environment("POCKETFRAME_RUNTIME_ROOT")
	var previous_profile := OS.get_environment("POCKETFRAME_PROFILE")
	OS.set_environment("POCKETFRAME_GPU","vulkan" if backend_choice.selected==0 else "opengl")
	OS.set_environment("POCKETFRAME_RUNTIME_ROOT",Paths.root_folder())
	OS.set_environment("POCKETFRAME_PROFILE",ProjectSettings.globalize_path("user://emulator"))
	var pid := OS.create_process(OS.get_executable_path(),args,false)
	OS.set_environment("POCKETFRAME_GPU",previous_backend)
	OS.set_environment("POCKETFRAME_RUNTIME_ROOT",previous_root)
	OS.set_environment("POCKETFRAME_PROFILE",previous_profile)
	if pid>0:
		var lock := FileAccess.open(lock_path,FileAccess.WRITE)
		if lock: lock.store_string(JSON.stringify({"pid":pid}))
	_launch_finished(0 if pid>0 else 1,"Could not start PocketFrame.",desktop)

func _sync_volume_from_setting(value: float) -> void:
	if not fit_controls.has("volume"):
		return
	var control: Dictionary = fit_controls.volume
	var current: float = control.slider.value / control.multiplier
	# Preserve physical slider adjustments made while this launcher was open.
	# A user actively changing this GUI slider still wins over the disk value.
	if is_equal_approx(current, volume_seen):
		control.slider.set_value_no_signal(clampf(value, 0, 1) * control.multiplier)
		control.readout.text = "%.2f" % control.slider.value
	volume_seen = control.slider.value / control.multiplier

func _sync_depth_from_setting(value: float) -> void:
	if not fit_controls.has("stereo_depth"): return
	var control: Dictionary = fit_controls.stereo_depth
	var current: float = control.slider.value / control.multiplier
	if is_equal_approx(current, depth_seen):
		control.slider.set_value_no_signal(clampf(value,0,1)*control.multiplier)
		control.readout.text="%.2f" % control.slider.value
	depth_seen=control.slider.value/control.multiplier

func _process(delta: float) -> void:
	if not launching:
		volume_sync_time += delta
		if volume_sync_time >= 1 and fit_controls.has("volume") and not fit_controls.volume.slider.has_focus():
			volume_sync_time = 0
			var fresh := ConfigFile.new()
			if fresh.load("user://settings.cfg") == OK:
				_sync_volume_from_setting(float(fresh.get_value("device", "volume", 0.7)))
				if not fit_controls.stereo_depth.slider.has_focus():
					_sync_depth_from_setting(float(fresh.get_value("device", "stereo_depth", 0)))
		return
	if FileAccess.file_exists(launch_result_path):
		var parser := JSON.new()
		var content := FileAccess.get_file_as_string(launch_result_path).trim_prefix("\ufeff")
		if parser.parse(content) == OK and parser.data is Dictionary:
			var result: Dictionary = parser.data
			_launch_finished(0 if result.get("ok", false) else 1, str(result.get("message", "Launch failed.")), launch_is_desktop)
	if launching and Time.get_ticks_msec() > launch_deadline:
		_launch_finished(1, "The launch helper did not respond. Check the session logs before trying again.", launch_is_desktop)

func _launch_finished(code: int, output: String, desktop: bool) -> void:
	launching = false
	vr_button.disabled = false
	desktop_button.disabled = false
	if code == 0:
		status.text = "Desktop session launched." if desktop else "VR session launched. Put on your headset."
	else:
		status.text = "Could not launch. See the message below."
		var dialog := AcceptDialog.new()
		dialog.title = "PocketFrame launch"
		dialog.dialog_text = output.strip_edges().left(1600)
		add_child(dialog)
		dialog.popup_centered(Vector2i(740, 260))

