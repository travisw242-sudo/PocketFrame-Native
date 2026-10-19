extends Node3D

const G = preload("res://scripts/geometry.gd")
const Handheld = preload("res://scripts/handheld.gd")
const HoldSolver = preload("res://scripts/hold_solver.gd")
const Router = preload("res://scripts/input_router.gd")
const AzaharBridge = preload("res://scripts/azahar_bridge.gd")
const AzaharInProcessBackend = preload("res://scripts/azahar_in_process_backend.gd")
const RoomBuilder = preload("res://scripts/room_builder.gd")
const ARMode = preload("res://scripts/ar_mode.gd")
const RoomLocomotion = preload("res://scripts/room_locomotion.gd")
const StudioLayout = preload("res://scripts/studio_layout.gd")
var locomotion := RoomLocomotion.new()
var ar_mode := ARMode.new()
var ar_button: CheckButton
var ar_status: Label
var world_environment: WorldEnvironment
var studio_table_visible := true
const VirtualHand = preload("res://scripts/virtual_hand.gd")
const RiggedHand = preload("res://scripts/rigged_hand.gd")
var hand_model := "rigged"
const ImmersiveInteractions = preload("res://scripts/immersive_interactions.gd")
const SideVolumeSlider = preload("res://scripts/side_volume_slider.gd")
const DepthSlider = preload("res://scripts/depth_slider.gd")
const CartridgeRack = preload("res://scripts/cartridge_rack.gd")
var cartridge_rack: Node3D
var startup_game_path := ""
var depth_touch := DepthSlider.new()
var depth_gui: HSlider
var immersion := ImmersiveInteractions.new()
var volume_touch := SideVolumeSlider.new()
var volume_gui: HSlider
var device: PFHandheld
var solver := PFHoldSolver.new()
var router := PFInputRouter.new()
var emulator_backend: Node
# Compatibility handle for the capture implementation and its existing tests.
# It remains null only when launching the future integrated runtime.
var azahar_bridge
var rig: XROrigin3D
var xr_camera: XRCamera3D
var camera: Camera3D
var left: XRController3D
var right: XRController3D
var aim: XRController3D
var left_aim: XRController3D
var left_hand_visual
var right_hand_visual
var xr_enabled := false
var ui: CanvasLayer
var status_label: Label
var input_label: Label
var world_status: Label3D
var desk_note
var vr_menu
var dock_pose := Transform3D(Basis.IDENTITY, Vector3(0, 1.03, -0.48))
var yaw := 0.38
var pitch := 0.61
var distance := 0.40
var device_scale := 1.25
var grip_pitch := 0.0
var height_offset := 0.025
var grab_cooldown := 0.0
var desktop_sim := false
var sim_separation := 0.30
var sim_phase := 0.0
var sim_markers: Array[MeshInstance3D] = []
var rotation_drag := false
var last_trigger := false
var settings_dirty := false
var settings_timer := 0.0
var screenshot_frame := 0
var screenshot_after := 45
var beauty := false
var room_preview := false
var screenshot_path := ""
var log_lines: Array[String] = []
var debug_line: MeshInstance3D
var desktop_touch_down := false
var dock_chord_down := false
var room_id := "studio"
var room_environment: Node3D
var render_quality := "balanced"
var quitting := false
var session_paused := false

func _ready() -> void:
	if preload("res://scripts/app_paths.gd").packaged():
		OS.set_environment("POCKETFRAME_RUNTIME_ROOT",preload("res://scripts/app_paths.gd").root_folder())
		OS.set_environment("POCKETFRAME_PROFILE",ProjectSettings.globalize_path("user://emulator"))
	beauty = "--beauty" in OS.get_cmdline_user_args()
	room_preview = "--room-preview" in OS.get_cmdline_user_args()
	var requested_room := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
		if arg.begins_with("--screenshot-after="):
			screenshot_after = maxi(45, int(arg.trim_prefix("--screenshot-after=")))
		if arg.begins_with("--room="):
			requested_room = arg.trim_prefix("--room=")
	_load_settings()
	render_quality = str(_setting("render_quality", "balanced"))
	_setup_world()
	_load_room(requested_room if not requested_room.is_empty() else str(_setting("room", "studio")))
	device = Handheld.new()
	add_child(device)
	device.cartridge_slot.cartridge_inserted.connect(_on_cartridge_inserted)
	device.cartridge_slot.cartridge_ejected.connect(_on_cartridge_ejected)
	device.cartridge_slot.cartridge_snapped.connect(_on_cartridge_snapped)
	if not "--no-emulator" in OS.get_cmdline_user_args():
		emulator_backend = AzaharInProcessBackend.new()
	else:
		azahar_bridge = AzaharBridge.new()
		emulator_backend = azahar_bridge
	add_child(emulator_backend)
	emulator_backend.attach(device)
	device.depth_changed.connect(_on_console_depth_changed)
	device.set_depth(float(_setting("stereo_depth", 0)))
	device.set_stereo_swap(bool(_setting("stereo_swap", false)))
	emulator_backend.set_stereo_depth(device.depth_level)
	emulator_backend.set_player_name(str(_setting("player_name", "Player")))
	device.volume_changed.connect(_on_console_volume_changed)
	device.set_volume(float(_setting("volume", 0.7)))
	emulator_backend.set_volume(device.volume_level)
	emulator_backend.connection_changed.connect(func(_connected: bool, detail: String): _log(detail))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			render_quality = arg.trim_prefix("--quality=").to_lower()
	if emulator_backend.has_method("set_quality"):
		emulator_backend.call("set_quality", render_quality)
	emulator_backend.set_enabled(not "--no-emulator" in OS.get_cmdline_user_args())
	# Development-only direct loader. Normal play still happens by inserting a
	# physical virtual cartridge; this makes a native-core smoke test explicit
	# and repeatable without crawling the user's game folders.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game="):
			# Keep this forgiving when Windows launches Godot through a shell: a
			# quoted path can retain its quote characters at either edge.
			var test_game := arg.trim_prefix("--game=").strip_edges()
			test_game = test_game.trim_prefix("\"").trim_suffix("\"")
			if FileAccess.file_exists(test_game):
				startup_game_path=test_game
			else:
				_log("Requested game was not found: " + test_game)
	device.global_transform = dock_pose
	device.scale = Vector3.ONE * device_scale
	_setup_xr()
	_setup_virtual_hands()
	immersion.setup(device, self)
	volume_touch.setup(device)
	depth_touch.setup(device)
	cartridge_rack=CartridgeRack.new()
	add_child(cartridge_rack)
	cartridge_rack.setup(device,dock_pose)
	cartridge_rack.feedback.connect(func(i: int):
		if xr_enabled:
			var controller: XRController3D=[left,right][i]
			controller.trigger_haptic_pulse("haptic",0,.15,.035,0))
	if not startup_game_path.is_empty(): cartridge_rack.mount_path(startup_game_path)
	device.set_stylus_side(str(_setting("stylus_side", "left")))
	device.stylus_auto_return = bool(_setting("stylus_auto_return", true))
	device.stylus_grip_angle = clampf(float(_setting("stylus_grip_angle", 25)), 0, 60)
	device.hand_pitch = clampf(float(_setting("hand_pitch", 0)), -40, 40)
	device.hand_roll = clampf(float(_setting("hand_roll", 0)), -40, 40)
	device.hand_offset = clampf(float(_setting("hand_offset", 0)), -0.04, 0.04)
	_build_ui()
	vr_menu=preload("res://scripts/vr_menu.gd").new()
	add_child(vr_menu)
	vr_menu.setup(emulator_backend,str(_setting("player_name","Player")))
	vr_menu.native_view_requested.connect(_set_ar)
	vr_menu.native_quality_requested.connect(func(value: String):render_quality=value;settings_dirty=true;vr_menu.quality_saved(_save_settings()))
	vr_menu.quit_requested.connect(_quit_cleanly)
	vr_menu.native_shell_requested.connect(_apply_native_shell)
	vr_menu.select_native_quality(preload("res://scripts/quality_presets.gd").index(render_quality))
	vr_menu.native_eye_swap.set_pressed_no_signal(device.stereo_swap_eyes)
	vr_menu.native_eye_swap.toggled.connect(func(on: bool):device.set_stereo_swap(on);settings_dirty=true)
	_native_refresh_view_controls()
	_native_try_ar.call_deferred()
	if xr_enabled:ui.hide()
	device.set_lid_angle(float(_setting("lid_angle", 145.0)))
	device.body_material.albedo_color = Color(str(_setting("shell_color", "303841")))
	device.set_shell_design(str(_setting("shell_design","")))
	vr_menu.select_native_shell(device.shell_design)
	router.button_changed.connect(_on_button)
	router.button_changed.connect(func(button: String, pressed: bool): emulator_backend.send_button(button, pressed))
	router.stick_changed.connect(func(value: Vector2): emulator_backend.send_stick(value))
	router.touch_changed.connect(_on_touch)
	get_window().focus_exited.connect(func(): router.release_all(); desktop_touch_down = false)
	get_tree().auto_accept_quit=false
	get_window().close_requested.connect(_quit_cleanly)
	_log("Startup: " + ("OpenXR active" if xr_enabled else "Desktop studio"))
	if beauty or room_preview:
		ui.hide()
		world_status.hide()
		camera.h_offset = 0
		if room_preview:
			camera.fov = 70
			distance = 2.35
			yaw = -0.18
			pitch = 0.20
			left.hide()
			right.hide()
			aim.hide()
		else:
			device.scale = Vector3.ONE * 1.25
			distance = 0.35
		_update_camera()

func _setup_world() -> void:
	var environment := WorldEnvironment.new()
	world_environment=environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111922")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5c8dc")
	env.ambient_light_energy = 0.30
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("243951")
	sky_mat.sky_horizon_color = Color("526b80")
	sky_mat.ground_bottom_color = Color("131c28")
	sky_mat.ground_horizon_color = Color("657584")
	sky.sky_material = sky_mat
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_color = Color("edf3ff")
	light.light_energy = 0.85
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 6.0
	add_child(light)
	for entry in [[Vector3(-0.4, 1.7, -0.3), Color("9ac7e0"), 0.025], [Vector3(0.3, 1.3, -0.85), Color("f4ddbd"), 0.035]]:
		var fill := OmniLight3D.new()
		fill.position = entry[0]
		fill.light_color = entry[1]
		fill.light_energy = entry[2]
		fill.omni_range = 2.0
		add_child(fill)
	G.rounded(self, Vector3(0.34, 0.022, 0.29), 0.027, 0.006, G.material(Color("1d2934"), 0.35, 0.44), dock_pose.origin + Vector3(0, -0.031, -0.015), "DisplayPlinth")
	var studio_table := G.rounded(self, StudioLayout.TABLE_SIZE, 0.025, 0.006, G.material(Color("18212b"), 0.1, 0.65), Vector3.ZERO, "StudioTable")
	studio_table.global_transform = StudioLayout.table_for_dock(dock_pose)
	desk_note = preload("res://scripts/desk_note.gd").new()
	get_node("StudioTable").add_child(desk_note)
	desk_note.position = Vector3(-.38, .0165, 0)
	camera = Camera3D.new()
	camera.fov = 39
	camera.near = 0.008
	camera.far = 20
	add_child(camera)
	camera.current = true
	camera.h_offset = -0.045
	_update_camera()
	world_status = Label3D.new()
	world_status.font_size = 36
	world_status.pixel_size = 0.00015
	world_status.outline_size = 0
	world_status.position = dock_pose.origin + Vector3(0, 0.20, -0.18)
	world_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world_status.modulate = Color("b3cad5")
	add_child(world_status)
	world_status.visible = false
	for i in [-1, 1]:
		var mesh := SphereMesh.new()
		mesh.radius = 0.009
		mesh.height = 0.018
		var marker := G.instance(self, mesh, G.material(Color("8ed9ce"), 0.1, 0.3), Vector3.ZERO, "SimulatedHand")
		marker.hide()
		sim_markers.append(marker)

func _load_room(next_room: String) -> void:
	var valid_room := false
	for entry in RoomBuilder.available_rooms():
		if entry.id==next_room: valid_room=true
	if not valid_room: next_room="studio"
	var previous_room := room_id
	room_id = next_room
	if room_environment:
		room_environment.queue_free()
	room_environment = RoomBuilder.build(room_id)
	add_child(room_environment)
	if room_environment.has_node("DeskDock"):
		dock_pose=room_environment.get_node("DeskDock").global_transform
		if is_instance_valid(cartridge_rack): cartridge_rack.recall(dock_pose,true)
		if xr_enabled and not ar_mode.active: _spawn_at_desk()
	elif previous_room=="teen_2008" and not ar_mode.active:
		# The fixed bedroom desk must not leave Studio's dock outside its table.
		dock_pose=Transform3D(Basis.IDENTITY,Vector3(0,1.03,-.48))
		get_node("DisplayPlinth").global_transform=dock_pose.translated_local(Vector3(0,-.031,-.015))
		get_node("StudioTable").global_transform=StudioLayout.table_for_dock(dock_pose)
		if is_instance_valid(cartridge_rack): cartridge_rack.recall(dock_pose,true)
	if is_instance_valid(world_status): world_status.position=dock_pose.origin+Vector3(0,.16,-.16)
	RoomBuilder.place_dock(room_environment,dock_pose)
	_sync_environment()
	if previous_room!="studio" and room_id=="studio" and xr_enabled and not ar_mode.active:
		_recenter_dock()
	settings_dirty = true

func _sync_environment() -> void:
	var is_studio := room_id == "studio" and not ar_mode.active
	room_environment.visible=not ar_mode.active
	get_node("StudioTable").visible = is_studio and studio_table_visible
	get_node("DisplayPlinth").visible = is_studio
	world_status.visible = xr_enabled and room_id != "studio" and not ar_mode.active

func _set_ar(enabled: bool) -> void:
	var interface := XRServer.find_interface("OpenXR")
	if enabled:
		if not xr_enabled or not ar_mode.enable(interface,get_viewport(),world_environment.environment):
			_log(ARMode.reason(interface,xr_enabled))
		else: _log("AR passthrough enabled · physical furniture is not collision tracked")
	else:
		ar_mode.disable(interface,get_viewport(),world_environment.environment)
		_log("Virtual room restored")
	_sync_environment()
	if is_instance_valid(ar_button): ar_button.set_pressed_no_signal(ar_mode.active)
	if is_instance_valid(ar_status): ar_status.text=ARMode.reason(interface,xr_enabled)
	if not enabled or ar_mode.active:
		config.set_value("device","prefer_ar",enabled)
		settings_dirty=true
	_native_refresh_view_controls()

func _native_refresh_view_controls() -> void:
	if not vr_menu:return
	var interface := XRServer.find_interface("OpenXR")
	var available: bool=xr_enabled and interface!=null and ARMode.supported(interface.get_supported_environment_blend_modes())
	vr_menu.update_native_view(ar_mode.active,available,ARMode.reason(interface,xr_enabled))

func _native_try_ar() -> void:
	if not xr_enabled:return
	# Allow the local runtime to provide its current blend-mode capabilities.
	for frame in range(90):
		await get_tree().process_frame
		var interface := XRServer.find_interface("OpenXR")
		if interface and ARMode.supported(interface.get_supported_environment_blend_modes()):
			if bool(_setting("prefer_ar",true)):_set_ar(true)
			else:_native_refresh_view_controls()
			return
	_native_refresh_view_controls()

func _cycle_room() -> void:
	var rooms := RoomBuilder.available_rooms()
	var index := 0
	for i in range(rooms.size()):
		if rooms[i].id == room_id:
			index = i
			break
	_load_room(str(rooms[(index + 1) % rooms.size()].id))
	_log("Room loaded: " + room_id)

func _setup_xr() -> void:
	rig = XROrigin3D.new()
	add_child(rig)
	xr_camera = XRCamera3D.new()
	xr_camera.near = 0.02
	xr_camera.far = 30
	rig.add_child(xr_camera)
	# The tracked pose and analog squeeze are separate OpenXR actions.
	# Godot aliases the OpenXR `grip_pose` action to the runtime pose name `grip`.
	left = _controller("left_hand", "grip")
	right = _controller("right_hand", "grip")
	aim = _controller("right_hand", "aim")
	left_aim = _controller("left_hand", "aim")
	add_child(locomotion)
	locomotion.enabled=bool(_setting("room_locomotion",true))
	for controller in [left, right]:
		controller.button_pressed.connect(func(action: String): _log(str(controller.tracker) + ": " + action))
	var interface := XRServer.find_interface("OpenXR")
	var desktop_forced := "--desktop" in OS.get_cmdline_user_args() or beauty or DisplayServer.get_name() == "headless"
	if not desktop_forced and interface and interface.is_initialized():
		xr_enabled = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr_camera.current = true
		world_status.visible = room_id != "studio" and not ar_mode.active
		if interface.has_signal("session_stopping"):
			interface.connect("session_stopping",func():_set_session_paused(true))
		if interface.has_signal("session_visible"):
			interface.connect("session_visible",func():_set_session_paused(true))
		if interface.has_signal("session_focussed"):
			interface.connect("session_focussed",func():_set_session_paused(false))
		# Reposition the dock once tracking has supplied the user's seated height.
		_recenter_when_tracked()
	else:
		camera.current = true

func _controller(tracker_name: String, pose_name: String) -> XRController3D:
	var controller := XRController3D.new()
	controller.tracker = tracker_name
	controller.pose = pose_name
	rig.add_child(controller)
	if pose_name == "grip":
		_add_controller_marker(controller, Color("55d9cf") if tracker_name == "left_hand" else Color("ffae70"), "L" if tracker_name == "left_hand" else "R")
	return controller

func _add_controller_marker(controller: XRController3D, tint: Color, label_text: String) -> void:
	# A compact marker provides a reliable in-app hand reference even when the
	# runtime does not composite its own controller model into this application.
	var mesh := SphereMesh.new()
	mesh.radius = 0.020
	mesh.height = 0.040
	var marker := MeshInstance3D.new()
	marker.name = "ControllerMarker"
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.1
	marker.material_override = material
	controller.add_child(marker)
	var label := Label3D.new()
	label.name = "ControllerMarkerLabel"
	label.text = label_text
	label.position = Vector3(0, 0.032, 0)
	label.pixel_size = 0.0014
	label.font_size = 42
	label.outline_size = 8
	label.modulate = tint
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	controller.add_child(label)

func _setup_virtual_hands(style: String = "") -> void:
	hand_model = style if not style.is_empty() else str(_setting("hand_model", "rigged"))
	if style.is_empty() and "--legacy-hands" in OS.get_cmdline_user_args(): hand_model = "legacy"
	for visual in [left_hand_visual, right_hand_visual]:
		if is_instance_valid(visual):
			visual.hide()
			visual.queue_free()
	var hand_type = VirtualHand if hand_model == "legacy" else RiggedHand
	left_hand_visual = hand_type.new()
	left.add_child(left_hand_visual)
	left_hand_visual.build(true)
	right_hand_visual = hand_type.new()
	right.add_child(right_hand_visual)
	right_hand_visual.build(false)
	left_hand_visual.set_tracking_visible(false)
	right_hand_visual.set_tracking_visible(false)

func _recenter_when_tracked() -> void:
	for i in range(180):
		await get_tree().process_frame
		if xr_camera.position.length() > 0.1:
			_recenter_dock()
			return

func _recenter_dock() -> void:
	if not xr_enabled:
		return
	if room_id=="teen_2008" and not ar_mode.active:
		_spawn_at_desk()
		dock_pose=room_environment.get_node("DeskDock").global_transform
		_dock()
		return
	dock_pose = StudioLayout.dock_for_head(xr_camera.global_transform)
	get_node("DisplayPlinth").global_transform = dock_pose.translated_local(Vector3(0, -0.031, -0.015))
	# Keep the desk guide reachable after seated-height calibration/recentering.
	get_node("StudioTable").global_transform = StudioLayout.table_for_dock(dock_pose)
	studio_table_visible=true
	_sync_environment()
	RoomBuilder.place_dock(room_environment,dock_pose)
	world_status.position = dock_pose.origin + Vector3(0, 0.16, -0.16)
	_dock()

func _spawn_at_desk() -> void:
	if not room_environment.has_node("PlayerSpawn"): return
	var forward := -xr_camera.global_basis.z
	forward.y=0
	if forward.length()>.01:
		rig.global_transform=RoomLocomotion.turned(rig.global_transform,xr_camera.global_position,forward.signed_angle_to(Vector3.FORWARD,Vector3.UP))
	rig.global_transform=RoomLocomotion.translated_to(rig.global_transform,xr_camera.global_position,room_environment.get_node("PlayerSpawn").global_position)

func _update_locomotion() -> void:
	if vr_menu and vr_menu.visible:return
	var allowed := room_id=="teen_2008" and not ar_mode.active and immersion.held_count()==0 and immersion.tool_hand<0
	for i in range(2):
		allowed=allowed and not cartridge_rack.busy_by(i)
	# Actual ownership controls the lockout, not incidental analog pressure from
	# resting fingers. Each movement gesture needs only its own controller pose.
	locomotion.step(allowed,left.get_vector2("primary"),right.get_vector2("primary"),left_aim.global_transform,rig,xr_camera,left.get_has_tracking_data() and left_aim.get_has_tracking_data(),right.get_has_tracking_data())

func _process(delta: float) -> void:
	if quitting or session_paused:return
	grab_cooldown = maxf(grab_cooldown - delta, 0)
	if xr_enabled:_update_headset_menu(delta)
	if xr_enabled or desktop_sim:
		_update_hold(delta)
	else:
		device.global_transform = dock_pose
		device.scale = Vector3.ONE * device_scale
	if xr_enabled: _update_locomotion()
	var values := _read_controls()
	var stick := _read_stick()
	var held_inputs := values.duplicate()
	if vr_menu and vr_menu.visible:
		for key in held_inputs:held_inputs[key]=false
		stick=Vector2.ZERO
	if xr_enabled and (immersion.held_count() == 0 or not immersion.holding_tracking_valid([left.get_has_tracking_data(), right.get_has_tracking_data()])):
		for key in held_inputs:
			held_inputs[key] = false
		stick = Vector2.ZERO
	router.update(held_inputs, stick)
	device.animate_controls(held_inputs, stick, delta)
	_update_virtual_hands(held_inputs, stick, delta)
	if xr_enabled and not (vr_menu and vr_menu.visible):
		_update_volume_touch(delta)
		_update_vr_touch()
	var names: Array[String] = []
	for key in held_inputs:
		if held_inputs[key]:
			names.append(key)
	var status := _status()
	var screen_status: String = emulator_backend.message if emulator_backend.enabled else status
	device.bottom_canvas.set_status(screen_status, " + ".join(names) if not names.is_empty() else "READY")
	var home_state := "NO CARTRIDGE"
	if cartridge_rack.seated!=null and cartridge_rack.mode=="latched":
		home_state="STARTING GAME" if "loading" in screen_status.to_lower() or "retry" in screen_status.to_lower() else "CHECK CARTRIDGE"
	for canvas in [device.top_canvas,device.bottom_canvas]:
		canvas.set_home_context(home_state,device.volume_level,device.depth_level,cartridge_rack.library.entries.size())
	status_label.text = status
	input_label.text = "INPUT  " + (" + ".join(names) if not names.is_empty() else "—")
	world_status.text = status + "\nGrip to hold • click that hand's stick to lock / unlock\nFree hand: GRIP pen cap or lid rim • pen slot: " + device.stylus_side
	world_status.text+="\nGame cards: tray on right · grip, align, push · press card edge to eject"
	world_status.text+="\nGrip the tray rim to move it · release to leave it floating"
	if room_id=="teen_2008": world_status.text+="\nEmpty hands: left stick forward + release = teleport · right stick = 30° turn"
	var paper_guide: String=world_status.text
	if room_id=="studio":paper_guide+="\nMENU / MULTIPLAYER: free right hand · hold Y"
	desk_note.set_guide(paper_guide)
	if settings_dirty:
		settings_timer += delta
		if settings_timer > 0.7:
			_save_settings()
	if not screenshot_path.is_empty():
		screenshot_frame += 1
		if screenshot_frame == screenshot_after:
			_capture.call_deferred()

func _tracking_valid() -> bool:
	return left.get_has_tracking_data() and right.get_has_tracking_data()

func _toggle_menu() -> void:
	if xr_enabled and vr_menu:
		if vr_menu.visible:vr_menu.close()
		else:
			vr_menu.open_at(xr_camera.global_transform)
			router.release_all()
			ui.hide()
	else:ui.visible=not ui.visible

func _update_headset_menu(delta: float) -> void:
	if not vr_menu:return
	var free_right: bool = right.get_has_tracking_data() and not immersion.holding(1) and immersion.tool_hand!=1 and not cartridge_rack.busy_by(1)
	if vr_menu.toggle_gesture(delta,right.is_button_pressed("menu_toggle"),free_right or vr_menu.visible):
		_toggle_menu()
		right.trigger_haptic_pulse("haptic",0,.12,.04,0)
	if not vr_menu.visible:return
	var left_pointing: bool=left_aim.get_has_tracking_data() and left.get_has_tracking_data() and left.get_float("trigger")>.1 and not immersion.holding(0)
	var use_right: bool=aim.get_has_tracking_data() and right.get_has_tracking_data() and not immersion.holding(1) and immersion.tool_hand!=1 and not cartridge_rack.busy_by(1) and not left_pointing
	var pointer: XRController3D=aim if use_right else left_aim
	var controller: XRController3D=right if use_right else left
	vr_menu.pointer_step(delta,pointer.global_transform,pointer.get_has_tracking_data() and controller.get_has_tracking_data(),controller.get_float("trigger")>.55,right.get_vector2("primary").y)

func _on_console_volume_changed(value: float) -> void:
	if emulator_backend:
		emulator_backend.set_volume(value)
	settings_dirty = true
	if is_instance_valid(volume_gui):
		volume_gui.set_value_no_signal(value * 100)
		(volume_gui.get_meta("readout") as Label).text = "Console volume   %d%%" % roundi(value * 100)

func _on_console_depth_changed(value: float) -> void:
	if emulator_backend:
		emulator_backend.set_stereo_depth(value)
	settings_dirty = true
	if is_instance_valid(depth_gui):
		depth_gui.set_value_no_signal(value * 100)
		(depth_gui.get_meta("readout") as Label).text = "3D depth   %d%%" % roundi(value*100)

func _update_volume_touch(delta: float) -> void:
	var tips: Array[Vector3] = []
	var eligible: Array[bool] = []
	var tracked := [left.get_has_tracking_data(), right.get_has_tracking_data()]
	for i in range(2):
		var usable: bool = tracked[i] and not immersion.holding(i) and immersion.tool_hand != i and not cartridge_rack.busy_by(i) and immersion.holding_tracking_valid(tracked)
		var visual: PFVirtualHand = [left_hand_visual, right_hand_visual][i]
		for finger in ["index", "thumb"]:
			tips.append(visual.fingertip_position(finger) if usable else Vector3.ZERO)
			eligible.append(usable)
	volume_touch.step(delta, tips, eligible)
	# A finger can operate only one physical slider at a time.
	var depth_eligible := eligible.duplicate()
	if volume_touch.active(): depth_eligible.fill(false)
	depth_touch.step(delta, tips, depth_eligible)
	cartridge_rack.touch_eject(tips,eligible)
	cartridge_rack.touch_tray(tips,eligible)
	if depth_touch.just_started:
		var controller: XRController3D = [left,right][depth_touch.hand_index()]
		controller.trigger_haptic_pulse("haptic",0,.08,.02,0)
	if volume_touch.just_started or volume_touch.hit_limit:
		var controller: XRController3D = [left, right][volume_touch.hand_index()]
		controller.trigger_haptic_pulse("haptic", 0, 0.10 if volume_touch.hit_limit else 0.06, 0.018, 0)

func _update_virtual_hands(values: Dictionary, stick: Vector2, delta: float) -> void:
	if not left_hand_visual or not right_hand_visual:
		return
	var show_left := xr_enabled and left.get_has_tracking_data()
	var show_right := xr_enabled and right.get_has_tracking_data()
	left_hand_visual.set_tracking_visible(show_left)
	right_hand_visual.set_tracking_visible(show_right)
	left.get_node("ControllerMarker").visible = not show_left
	left.get_node("ControllerMarkerLabel").visible = not show_left
	right.get_node("ControllerMarker").visible = not show_right
	right.get_node("ControllerMarkerLabel").visible = not show_right
	if show_left:
		left_hand_visual.set_game_inputs(values,left.get_vector2("primary"),delta,"cartridge" if cartridge_rack.held_by(0) else immersion.tool if immersion.tool_hand==0 else "console" if immersion.holding(0) else "",_hand_sensors(left))
	if show_right:
		right_hand_visual.set_game_inputs(values,right.get_vector2("primary"),delta,"cartridge" if cartridge_rack.held_by(1) else immersion.tool if immersion.tool_hand==1 else "console" if immersion.holding(1) else "",_hand_sensors(right))

func _hand_sensors(controller: XRController3D) -> Dictionary:
	var thumb_pressed := controller.is_button_pressed("primary_click")
	for action in ["game_a", "game_b", "game_x", "game_y", "game_start", "game_select"]:
		thumb_pressed = thumb_pressed or controller.is_button_pressed(action)
	var sensors := {"grip": maxf(controller.get_float("squeeze"), 1.0 if controller.is_button_pressed("squeeze_click") else 0.0), "trigger": controller.get_float("trigger"), "thumb_press": thumb_pressed or controller.get_vector2("primary").length() > 0.10, "hand_pitch": device.hand_pitch, "hand_roll": device.hand_roll, "hand_offset": device.hand_offset}
	sensors.collision_device = device
	var hand_index := 0 if controller==left else 1
	if cartridge_rack.held_by(hand_index): sensors.cartridge_world=cartridge_rack.held[hand_index].global_transform
	if immersion.holding(0 if controller == left else 1):
		sensors.console_world = device.global_transform
	return sensors

func _grab_readout() -> String:
	return "TRACK L:%s R:%s  GRIP %.2f / %.2f" % [
		"OK" if left.get_has_tracking_data() else "—",
		"OK" if right.get_has_tracking_data() else "—",
		left.get_float("squeeze"), right.get_float("squeeze")]

func _update_immersive_hold(delta: float) -> void:
	var tracked := [left.get_has_tracking_data(), right.get_has_tracking_data()]
	var grips: Array = []
	var triggers: Array = []
	var clicks: Array = []
	var aims: Array = []
	for i in range(2):
		var controller: XRController3D = [left, right][i]
		grips.append(grab_cooldown <= 0 and (controller.get_float("squeeze") > (0.25 if immersion.previous_grips[i] else 0.40) or controller.is_button_pressed("squeeze_click")))
		triggers.append(controller.get_float("trigger") > (0.35 if immersion.previous_triggers[i] else 0.55))
		clicks.append(controller.is_button_pressed("primary_click"))
		if vr_menu and vr_menu.visible:
			grips[i]=grips[i] and (immersion.holding(i) or immersion.tool_hand==i or cartridge_rack.busy_by(i))
			triggers[i]=false
			clicks[i]=false
		var pointer: XRController3D = [left_aim, aim][i]
		aims.append(pointer.global_transform if pointer.get_has_tracking_data() else null)
	var dock_target := dock_pose
	dock_target.basis = dock_target.basis.scaled(Vector3.ONE * device_scale)
	var previous_angle := device.lid_angle
	var fingers: Array = []
	for i in range(2):
		var visual: Node3D = [left_hand_visual, right_hand_visual][i]
		# Current tracked parent transform, last articulated pose: no extra
		# animation step and no one-frame controller-position lag.
		fingers.append([visual.fingertip_position("index"), visual.fingertip_position("thumb")] if tracked[i] and not immersion.holding(i) else [])
	var hands := [left.global_transform,right.global_transform]
	var available := [tracked[0] and not immersion.holding(0) and immersion.tool_hand!=0,tracked[1] and not immersion.holding(1) and immersion.tool_hand!=1]
	if not immersion.holding_tracking_valid(tracked): available.fill(false)
	var reserved: Array=cartridge_rack.reserve(hands,tracked,grips,available,fingers)
	if vr_menu and vr_menu.visible:
		for i in range(2):reserved[i]=reserved[i] or not immersion.holding(i)
	immersion.step(delta,hands,tracked,grips,triggers,dock_target,clicks,aims,fingers,reserved)
	cartridge_rack.move_hands(delta,hands)
	solver.state = PFHoldSolver.State.HELD if immersion.held_count() > 0 else PFHoldSolver.State.DOCKED
	if absf(previous_angle - device.lid_angle) > 0.05:
		settings_dirty = true
	if not immersion.last_event.is_empty():
		_log(immersion.last_event)
		for i in range(2):
			if tracked[i] and (immersion.holding(i) or immersion.tool_hand == i):
				var controller: XRController3D = [left, right][i]
				controller.trigger_haptic_pulse("haptic", 0, 0.18, 0.04, 0)

func _update_hold(delta: float) -> void:
	if xr_enabled and not desktop_sim:
		_update_immersive_hold(delta)
		return
	var l := left.global_transform
	var r := right.global_transform
	var valid := _tracking_valid()
	var left_squeeze := left.get_float("squeeze")
	var right_squeeze := right.get_float("squeeze")
	var grips := (left_squeeze > 0.35 or left.is_button_pressed("squeeze_click")) and (right_squeeze > 0.35 or right.is_button_pressed("squeeze_click"))
	var release := left.is_button_pressed("primary_click") and right.is_button_pressed("primary_click")
	if desktop_sim:
		sim_separation = move_toward(sim_separation, 0.165 if Input.is_physical_key_pressed(KEY_SPACE) else 0.31, delta * 0.4)
		sim_phase += delta
		var center := dock_pose.origin + Vector3(0, 0.06, 0.06)
		var tilt := Basis.from_euler(Vector3(sin(sim_phase * 0.6) * 0.06, sin(sim_phase * 0.4) * 0.10, 0))
		l = Transform3D(tilt, center + tilt.x * -sim_separation / 2)
		r = Transform3D(tilt, center + tilt.x * sim_separation / 2)
		sim_markers[0].position = l.origin
		sim_markers[1].position = r.origin
		valid = true
		grips = Input.is_physical_key_pressed(KEY_SPACE)
		release = false
	if release and not dock_chord_down:
		dock_chord_down = true
		_dock()
		return
	dock_chord_down = release
	var result := solver.step(delta, l, r, valid and grab_cooldown <= 0, grips, false)
	if result.changed and solver.state == PFHoldSolver.State.HELD:
		_log("Pickup gesture latched")
		if xr_enabled:
			for controller in [left, right]:
				controller.trigger_haptic_pulse("haptic", 0, 0.25, 0.07, 0)
	var target := dock_pose
	if solver.state == PFHoldSolver.State.HELD:
		if not result.valid:
			# Freeze pose and release gameplay inputs while tracking is unavailable.
			return
		target = result.target
		target.basis = target.basis * Basis(Vector3.RIGHT, deg_to_rad(grip_pitch))
		target.origin += target.basis.y * height_offset
	target.basis = target.basis.scaled(Vector3.ONE * device_scale)
	device.global_transform = device.global_transform.interpolate_with(target, 1.0 - exp(-24.0 * delta))

func _update_vr_touch() -> void:
	if cartridge_rack and (cartridge_rack.busy_by(0) or cartridge_rack.busy_by(1) or cartridge_rack.press_tip>=0):
		router.update_touch(Vector2(-1,-1),false)
		return
	if (volume_touch.active() or volume_touch.just_released or depth_touch.active() or depth_touch.just_released) and immersion.tool != "stylus":
		router.update_touch(Vector2(-1, -1), false)
		return
	if immersion.tool == "stylus":
		if immersion.touch_uv.x >= 0 and not router.touch_down:
			var controller: XRController3D = [left, right][immersion.tool_hand]
			controller.trigger_haptic_pulse("haptic", 0, 0.10, 0.025, 0)
		router.update_touch(immersion.touch_uv, immersion.touch_uv.x >= 0)
		return
	if immersion.tool == "hinge" or immersion.held_count() == 2 or not immersion.holding_tracking_valid([left.get_has_tracking_data(), right.get_has_tracking_data()]):
		router.update_touch(Vector2(-1, -1), false)
		if debug_line:
			debug_line.hide()
		return
	var pointer := left_aim if immersion.holding(1) else aim
	var pointer_controller := left if immersion.holding(1) else right
	if not pointer.get_has_tracking_data():
		router.update_touch(Vector2(-1, -1), false)
		return
	var origin := pointer.global_position
	var direction := -pointer.global_basis.z
	var uv := device.ray_to_touch(origin, direction)
	var pressed := pointer_controller.get_float("trigger") > 0.55
	router.update_touch(uv, pressed)
	# A small indicator appears at the actual screen hit, avoiding an opaque laser.
	if uv.x >= 0:
		device.bottom_canvas.touch = uv * device.bottom_canvas.size
		device.bottom_canvas.queue_redraw()

func _read_controls() -> Dictionary:
	var v := {"A": Input.is_physical_key_pressed(KEY_L), "B": Input.is_physical_key_pressed(KEY_K),
		"X": Input.is_physical_key_pressed(KEY_I), "Y": Input.is_physical_key_pressed(KEY_J),
		"L": Input.is_physical_key_pressed(KEY_Q), "R": Input.is_physical_key_pressed(KEY_E),
		"START": Input.is_physical_key_pressed(KEY_ENTER), "SELECT": Input.is_physical_key_pressed(KEY_BACKSPACE),
		"UP": Input.is_physical_key_pressed(KEY_UP), "DOWN": Input.is_physical_key_pressed(KEY_DOWN),
		"LEFT": Input.is_physical_key_pressed(KEY_LEFT), "RIGHT": Input.is_physical_key_pressed(KEY_RIGHT)}
	if xr_enabled:
		var usable_left := left.get_has_tracking_data() and immersion.holding(0)
		var usable_right := right.get_has_tracking_data() and immersion.holding(1)
		for key in ["A", "B", "X", "Y", "START", "SELECT"]:
			v[key] = (usable_left and left.is_button_pressed("game_" + key.to_lower())) or (usable_right and right.is_button_pressed("game_" + key.to_lower()))
		v["L"] = usable_left and left.is_button_pressed("bumper")
		v["R"] = usable_right and right.is_button_pressed("bumper")
		for key in ["UP", "DOWN", "LEFT", "RIGHT"]:
			v[key] = usable_left and left.is_button_pressed("dpad_" + key.to_lower())
	v["D-PAD"] = v["UP"] or v["DOWN"] or v["LEFT"] or v["RIGHT"]
	return v

func _read_stick() -> Vector2:
	if xr_enabled:
		if not left.get_has_tracking_data() or not immersion.holding(0):
			return Vector2.ZERO
		var value := left.get_vector2("primary")
		return value if value.length() > 0.15 else Vector2.ZERO
	return Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))).limit_length()

func _status() -> String:
	if cartridge_rack and cartridge_rack.tray_hand>=0: return "GAME TRAY · release grip to place"
	if xr_enabled:
		if volume_touch.active():
			return "VOLUME · MUTED" if device.volume_level <= 0 else "VOLUME · %d%% · slide toward hinge to raise" % roundi(device.volume_level * 100)
		if depth_touch.active():
			return "3D · OFF" if device.depth_level <= 0 else "3D · %d%% · slide up for more depth" % roundi(device.depth_level*100)
		if cartridge_rack.mode=="guided": return "CARTRIDGE · keep gripping and push straight into the rear slot"
		if cartridge_rack.held_by(0) or cartridge_rack.held_by(1): return "CARTRIDGE · contacts first, label toward console underside"
		if cartridge_rack.mode in ["popping","popped"]: return "CARTRIDGE · grip the exposed edge to remove"
		if cartridge_rack.press_tip>=0: return "CARTRIDGE · push inward to eject · save your game first"
		if not immersion.holding_tracking_valid([left.get_has_tracking_data(), right.get_has_tracking_data()]):
			return "TRACKING LOST · POSE PAUSED"
		if immersion.tool == "stylus":
			if immersion.pen_motion.phase == "extracting":
				return "STYLUS · keep gripping; pull straight outward until clear"
			if immersion.pen_motion.phase == "inserting":
				return "STYLUS · slide inward; release grip to seat in slot"
			return "STYLUS · touch lower LCD; tip into %s slot to store" % device.stylus_side
		if immersion.tool == "hinge":
			return "HINGE · move your hand to adjust the lid"
		if immersion.held_count() > 0:
			var state := "L: " + ("LOCKED" if immersion.locked[0] else "GRIP" if immersion.holding(0) else "FREE")
			state += " · R: " + ("LOCKED" if immersion.locked[1] else "GRIP" if immersion.holding(1) else "FREE")
			if not immersion.hover.is_empty():
				state += " · GRIP FOR " + immersion.hover.to_upper()
			return state
	if xr_enabled and not _tracking_valid():
		return "TRACKING LOST · POSE PAUSED" if solver.state == PFHoldSolver.State.HELD else "WAITING FOR CONTROLLERS"
	if solver.state == PFHoldSolver.State.HELD:
		return "HELD · TWO-HAND POSE"
	if solver.state == PFHoldSolver.State.CANDIDATE:
		return "PICKUP · %d%%" % int(solver.dwell / solver.dwell_seconds * 100)
	return "DOCKED · READY TO PICK UP" if xr_enabled or desktop_sim else "DESKTOP STUDIO · VR NOT ACTIVE"

func _dock() -> void:
	if volume_touch.device:
		volume_touch.reset()
	if depth_touch.device:
		depth_touch.reset()
	immersion.reset()
	solver.reset()
	grab_cooldown = 0.8
	router.release_all()
	device.global_transform = dock_pose
	device.scale = Vector3.ONE * device_scale
	if cartridge_rack:
		cartridge_rack.release_all()
		cartridge_rack.recall(dock_pose)
	_log("Docked")

func _update_camera() -> void:
	var target := dock_pose.origin + Vector3(0, 0.025, -0.02)
	if room_preview:
		target = Vector3(0, 1.35, -1.10)
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not xr_enabled:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotation_drag = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance + (-0.025 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.025), 0.18, 0.85)
			_update_camera()
		if event.button_index == MOUSE_BUTTON_LEFT:
			desktop_touch_down = event.pressed
			_desktop_touch(event.position, event.pressed)
	if event is InputEventMouseMotion and not xr_enabled:
		if rotation_drag:
			yaw -= event.relative.x * 0.008
			pitch = clampf(pitch + event.relative.y * 0.006, -0.4, 1.4)
			_update_camera()
		elif desktop_touch_down:
			_desktop_touch(event.position, true)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_quit_cleanly()
			KEY_G:
				if not xr_enabled:
					_toggle_sim()
			KEY_R: _dock()
			KEY_F: _recenter_dock()
			KEY_M: _cycle_room()
			KEY_BRACKETLEFT: device.set_lid_angle(device.lid_angle - 5)
			KEY_BRACKETRIGHT: device.set_lid_angle(device.lid_angle + 5)

func _input(event: InputEvent) -> void:
	# Handle the menu hotkey before other desktop controls can consume it, but
	# don't steal the letter H while typing in a text field.
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H:
		if not get_viewport().gui_get_focus_owner() is LineEdit:
			_toggle_menu();get_viewport().set_input_as_handled();return
	# Release even when the mouse moves over the settings panel before release.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and desktop_touch_down:
			desktop_touch_down = false
			router.update_touch(Vector2(-1, -1), false)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotation_drag = false

func _desktop_touch(pos: Vector2, pressed: bool) -> void:
	var uv := device.ray_to_touch(camera.project_ray_origin(pos), camera.project_ray_normal(pos))
	router.update_touch(uv, pressed)

func _on_button(button: String, pressed: bool) -> void:
	_log(button + (" down" if pressed else " up"))

func _on_touch(uv: Vector2, pressed: bool) -> void:
	if emulator_backend.enabled:
		emulator_backend.send_touch(uv, pressed)
	if pressed:
		device.bottom_canvas.tap(uv)

func _on_cartridge_inserted(cartridge) -> void:
	if cartridge == null:
		return
	if cartridge.request_load():
		emulator_backend.load_game(cartridge.content_path)
		_log("Cartridge inserted: " + cartridge.display_name)
	else:
		_log("Cartridge inserted without a selected game file")

func _on_cartridge_ejected(_cartridge) -> void:
	router.release_all()
	emulator_backend.unload_game()
	_log("Cartridge ejected · game stopped")

func _on_cartridge_snapped(_cartridge) -> void:
	# Feedback is intentionally short: a positive confirmation without masking
	# gameplay haptics. A later grab layer can target only the hand holding card.
	if xr_enabled:
		left.trigger_haptic_pulse("haptic", 0, 0.18, 0.035, 0)
		right.trigger_haptic_pulse("haptic", 0, 0.18, 0.035, 0)
	_log("Cartridge snapped into rear slot")

func _toggle_sim() -> void:
	desktop_sim = not desktop_sim
	for marker in sim_markers:
		marker.visible = desktop_sim
	_dock()

func _log(message: String) -> void:
	var line := Time.get_datetime_string_from_system() + "  " + message
	print(line)
	log_lines.append(line)
	if log_lines.size() > 200:
		log_lines.pop_front()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(screenshot_path)
	print("Screenshot: ", screenshot_path, " result: ", error)
	get_tree().quit(error)

var config := ConfigFile.new()
var settings_path := "user://settings.cfg"
func _load_settings() -> void:
	config.load(settings_path)
	device_scale = float(_setting("scale", 1.25))
	grip_pitch = float(_setting("grip_pitch", 0.0))
	height_offset = float(_setting("height_offset", 0.025))
	solver.require_grips = bool(_setting("require_grips", true))
	solver.pickup_distance = float(_setting("pickup_distance", 0.23))

func _setting(key: String, fallback: Variant) -> Variant:
	return config.get_value("device", key, fallback)

func _save_settings() -> bool:
	config.set_value("device", "scale", device_scale)
	config.set_value("device", "volume", device.volume_level)
	config.set_value("device", "stereo_depth", device.depth_level)
	config.set_value("device", "stereo_swap", device.stereo_swap_eyes)
	config.set_value("device", "lid_angle", device.lid_angle)
	config.set_value("device", "grip_pitch", grip_pitch)
	config.set_value("device", "height_offset", height_offset)
	config.set_value("device", "require_grips", solver.require_grips)
	config.set_value("device", "pickup_distance", solver.pickup_distance)
	config.set_value("device", "shell_color", device.body_material.albedo_color.to_html(false))
	config.set_value("device", "shell_design",device.shell_design)
	config.set_value("device", "room", room_id)
	config.set_value("device", "room_locomotion", locomotion.enabled)
	config.set_value("device", "render_quality", render_quality)
	config.set_value("device", "stylus_side", device.stylus_side)
	config.set_value("device", "stylus_auto_return", device.stylus_auto_return)
	config.set_value("device", "stylus_grip_angle", device.stylus_grip_angle)
	config.set_value("device", "hand_pitch", device.hand_pitch)
	config.set_value("device", "hand_roll", device.hand_roll)
	config.set_value("device", "hand_offset", device.hand_offset)
	var error := config.save(settings_path)
	if error!=OK:
		_log("Settings could not be saved: "+error_string(error))
		return false
	settings_dirty = false
	settings_timer = 0.0
	return true

func _set_session_paused(value: bool) -> void:
	if not is_instance_valid(emulator_backend) or quitting:return
	session_paused=value
	router.release_all();desktop_touch_down=false
	if emulator_backend.has_method("set_paused"):emulator_backend.set_paused(value)
	if value:_save_settings()
	_log("Headset session paused" if value else "Headset session resumed")

func _apply_native_shell(id: String) -> void:
	device.set_shell_design(id)
	if id.is_empty():device.body_material.albedo_color=Color("303841")
	settings_dirty=true
	vr_menu.shell_saved(_save_settings())

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED:_set_session_paused(true)
	elif what==NOTIFICATION_APPLICATION_RESUMED:_set_session_paused(false)

func _quit_cleanly() -> void:
	if quitting:return
	if not _save_settings():
		if vr_menu:vr_menu.quality_saved(false)
		return
	quitting=true
	router.release_all();desktop_touch_down=false
	if vr_menu:vr_menu.show_quitting("Closing emulator safely… Please wait.")
	if emulator_backend:
		emulator_backend.unload_game()
		while emulator_backend.has_method("is_running") and emulator_backend.is_running():
			await get_tree().process_frame
	_log("Clean shutdown completed")
	get_tree().quit()

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(308, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.047, 0.069, 0.093, 0.94)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(315, clampf(get_viewport().get_visible_rect().size.y - 104, 360, 800))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	_ui_label(column, "P O C K E T F R A M E", 20, Color("e0eae8"))
	_ui_label(column, "PHYSICAL PROTOTYPE  /  0.1", 12, Color("7999a9"))
	column.add_child(HSeparator.new())
	status_label = _ui_label(column, "Starting", 13, Color("9acdbf"))
	input_label = _ui_label(column, "INPUT —", 13, Color("c3d0d8"))
	var multiplayer_panel := preload("res://scripts/multiplayer_panel.gd").new()
	column.add_child(multiplayer_panel)
	multiplayer_panel.setup(emulator_backend,str(_setting("player_name","Player")))
	column.add_child(HSeparator.new())
	_ui_label(column,"GAME CARTRIDGES",12,Color("7999a9"))
	var game_count := _ui_label(column,"%d games · cards on the tray to your right" % cartridge_rack.library.entries.size(),12,Color("9acdbf"))
	cartridge_rack.library_changed.connect(func(count: int): game_count.text="%d games · cards on the tray to your right" % count)
	var next_cards := Button.new()
	next_cards.text="Next cartridge page"
	next_cards.pressed.connect(cartridge_rack.next_page)
	column.add_child(next_cards)
	var eject_card := Button.new()
	eject_card.text="Press / eject inserted cartridge"
	eject_card.pressed.connect(cartridge_rack.eject)
	column.add_child(eject_card)
	if not xr_enabled:
		var choice := OptionButton.new()
		var ids: Array=cartridge_rack.library.entries.keys()
		for id in ids: choice.add_item(cartridge_rack.library.entries[id].display_name)
		cartridge_rack.library_changed.connect(func(_count: int):
			ids.assign(cartridge_rack.library.entries.keys())
			choice.clear()
			for id in ids: choice.add_item(cartridge_rack.library.entries[id].display_name))
		column.add_child(choice)
		var insert_card := Button.new()
		insert_card.text="Insert selected cartridge (desktop test)"
		insert_card.pressed.connect(func():
			cartridge_rack.return_popped()
			if choice.selected>=0 and choice.selected<ids.size(): cartridge_rack.mount_path(cartridge_rack.library.entries[ids[choice.selected]].content_path))
		column.add_child(insert_card)
	_ui_label(column, "HANDHELD", 12, Color("7999a9"))
	_slider(column, "Size", 0.8, 2.0, device_scale, 0.05, func(value: float): device_scale = value)
	_slider(column, "Lid angle", 25, 175, float(_setting("lid_angle", 145)), 1, func(value: float): device.set_lid_angle(value))
	volume_gui = _slider(column, "Console volume", 0, 100, device.volume_level * 100, 1, func(value: float): device.set_volume(value / 100))
	depth_gui = _slider(column, "3D depth", 0, 100, device.depth_level*100, 1, func(value: float): device.set_depth(value/100))
	var swap_eyes := CheckBox.new()
	swap_eyes.text = "Swap 3D eyes"
	swap_eyes.tooltip_text = "Use if stereoscopic depth appears reversed."
	swap_eyes.button_pressed = device.stereo_swap_eyes
	swap_eyes.toggled.connect(func(value: bool): device.set_stereo_swap(value); settings_dirty=true)
	column.add_child(swap_eyes)
	var pen_side := OptionButton.new()
	pen_side.add_item("Stylus slot: Left-handed / left")
	pen_side.add_item("Stylus slot: Right-handed / right")
	pen_side.select(1 if device.stylus_side == "right" else 0)
	pen_side.item_selected.connect(func(index: int):
		immersion.recall_stylus()
		device.set_stylus_side("right" if index == 1 else "left")
		settings_dirty = true)
	column.add_child(pen_side)
	var pen_return := CheckBox.new()
	pen_return.text = "Auto-return dropped stylus"
	pen_return.button_pressed = device.stylus_auto_return
	pen_return.toggled.connect(func(on: bool): device.stylus_auto_return = on; settings_dirty = true)
	column.add_child(pen_return)
	_slider(column, "Stylus grip angle", 0, 60, device.stylus_grip_angle, 1, func(value: float): device.stylus_grip_angle = value)
	var recall_pen := Button.new()
	recall_pen.text = "Recall stylus"
	recall_pen.pressed.connect(func(): immersion.recall_stylus(); router.update_touch(Vector2(-1, -1), false))
	column.add_child(recall_pen)
	_ui_label(column, "HAND / CONTROLLER FIT", 12, Color("7999a9"))
	var hand_choice := OptionButton.new()
	hand_choice.name = "HandModelChoice"
	hand_choice.add_item("Rigged hands + contact (test)")
	hand_choice.add_item("Previous procedural hands")
	hand_choice.select(1 if hand_model == "legacy" else 0)
	hand_choice.item_selected.connect(func(index: int):
		var selected_hand_style := "legacy" if index == 1 else "rigged"
		config.set_value("device", "hand_model", selected_hand_style)
		settings_dirty = true
		_setup_virtual_hands(selected_hand_style))
	column.add_child(hand_choice)
	_slider(column, "Hand tilt (degrees)", -40, 40, device.hand_pitch, 1, func(value: float): device.hand_pitch = value)
	_slider(column, "Hand roll (degrees)", -40, 40, device.hand_roll, 1, func(value: float): device.hand_roll = value)
	_slider(column, "Hand wrist offset (cm)", -4, 4, device.hand_offset * 100, 0.25, func(value: float): device.hand_offset = value / 100)
	var colors := HBoxContainer.new()
	column.add_child(colors)
	for item in [["Graphite", "303841"], ["Pearl", "bfc3bf"], ["Crimson", "742b35"]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(func(): device.set_shell_design("");device.body_material.albedo_color = Color(item[1]); settings_dirty = true)
		colors.add_child(button)
	var shell_choice := OptionButton.new()
	shell_choice.add_item("Classic solid colour")
	var catalog=preload("res://scripts/shell_catalog.gd")
	for item in catalog.ITEMS: shell_choice.add_item(item.name)
	shell_choice.select(catalog.index(device.shell_design)+1)
	shell_choice.item_selected.connect(func(i: int): device.set_shell_design(catalog.ITEMS[i-1].id if i>0 else "");settings_dirty=true)
	column.add_child(shell_choice)
	column.add_child(HSeparator.new())
	_ui_label(column, "HOLD CALIBRATION", 12, Color("7999a9"))
	_slider(column, "Grip pitch", -90, 90, grip_pitch, 1, func(value: float): grip_pitch = value)
	_slider(column, "Height offset (cm)", -5, 8, height_offset * 100, 0.5, func(value: float): height_offset = value / 100)
	_slider(column, "Pickup distance (cm)", 15, 35, solver.pickup_distance * 100, 1, func(value: float): solver.pickup_distance = value / 100)
	var check := CheckBox.new()
	check.text = "Desktop simulator: require grips"
	check.disabled = xr_enabled
	check.button_pressed = solver.require_grips
	check.toggled.connect(func(on: bool): solver.require_grips = on; settings_dirty = true)
	column.add_child(check)
	var dock := Button.new()
	dock.text = "Return to dock  ·  R"
	dock.pressed.connect(_dock)
	column.add_child(dock)
	var recenter := Button.new()
	recenter.text = "Recenter / return to computer desk  ·  F"
	recenter.pressed.connect(_recenter_dock)
	recenter.disabled = not xr_enabled
	column.add_child(recenter)
	var room_button := Button.new()
	room_button.text = "Room: %s  ·  M" % ("Studio" if room_id == "studio" else "Bedroom")
	room_button.pressed.connect(func(): _cycle_room(); room_button.text = "Room: %s  ·  M" % ("Studio" if room_id == "studio" else "Bedroom"))
	column.add_child(room_button)
	var locomotion_toggle := CheckButton.new()
	locomotion_toggle.text="Teleport + 30° snap turn (empty hands)"
	locomotion_toggle.button_pressed=locomotion.enabled
	locomotion_toggle.toggled.connect(func(on: bool): locomotion.enabled=on;settings_dirty=true)
	column.add_child(locomotion_toggle)
	ar_button=CheckButton.new()
	ar_button.name="ARModeToggle"
	ar_button.text="AR / camera passthrough"
	var ar_interface := XRServer.find_interface("OpenXR")
	ar_button.disabled=not xr_enabled or ar_interface==null or not ARMode.supported(ar_interface.get_supported_environment_blend_modes())
	ar_button.toggled.connect(_set_ar)
	column.add_child(ar_button)
	ar_status=_ui_label(column,ARMode.reason(ar_interface,xr_enabled),12,Color("94a9b5"))
	ar_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var quality := OptionButton.new()
	quality.add_item("Performance · 1×")
	quality.add_item("Balanced · 1× crisp")
	quality.add_item("Sharp · 2× rendering")
	quality.add_item("Ultra · 3× (experimental)")
	quality.select(3 if render_quality=="ultra" else 2 if render_quality == "sharp" else 0 if render_quality == "performance" else 1)
	quality.item_selected.connect(func(index: int):
		render_quality = ["performance", "balanced", "sharp", "ultra"][index]
		settings_dirty = true
		_log("Quality saved: " + render_quality + " · restart PocketFrame to apply"))
	column.add_child(quality)
	if not xr_enabled:
		var sim := Button.new()
		sim.text = "Toggle gesture simulator  ·  G"
		sim.pressed.connect(_toggle_sim)
		column.add_child(sim)
		_ui_label(column, "Right-drag: orbit · Wheel: zoom\nI J K L: X Y B A · WASD: stick\nArrows: D-pad · Q / E: shoulders\nClick lower screen: touch\nSimulator: hold Space to bring hands in\nM: change room · H: hide panel · Esc: quit", 13, Color("94a9b5"))
	_ui_label(column, "Original model · Azahar bridge available\nLaunch with --emulator-bridge after starting bridge/Launch_Bridge.bat", 12, Color("718995"))

func _ui_label(parent: Node, text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _slider(parent: Node, title: String, low: float, high: float, value: float, step_size: float, callback: Callable) -> HSlider:
	var label := _ui_label(parent, "%s   %.2f" % [title, value], 13, Color("bacbd3"))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step_size
	slider.value = value
	slider.custom_minimum_size.y = 18
	slider.value_changed.connect(func(v: float): label.text = "%s   %.2f" % [title, v]; callback.call(v); settings_dirty = true)
	parent.add_child(slider)
	slider.set_meta("readout", label)
	return slider
