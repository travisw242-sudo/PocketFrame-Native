extends SceneTree
const Device = preload("res://scripts/handheld.gd")
const SideSlider = preload("res://scripts/side_volume_slider.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Backend = preload("res://scripts/azahar_in_process_backend.gd")
const Hand = preload("res://scripts/virtual_hand.gd")
var checks := 0
var failures := 0

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)

func tick(slider: RefCounted, points: Array, eligible: Array = [true, false, false, false]) -> void:
	slider.step(0.016, points, eligible)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var device := Device.new()
	world.add_child(device)
	device.position.y = 1
	device.set_volume(0.5)
	var cap: MeshInstance3D = device.volume_slider.get_node("VolumeThumb")
	var outer_face := device.volume_slider.position.x + cap.position.x + cap.get_aabb().position.x
	check(outer_face > -0.081 and outer_face < -0.079, "Recessed volume cap protrudes less than two millimeters")
	check(is_equal_approx(device.volume_slider.position.x, -0.0812), "Proven volume touch proxy is unchanged")
	var slider := SideSlider.new()
	slider.setup(device)
	var start := device.volume_slider.global_position + Vector3(-0.004, 0, 0.003)
	var points := [start, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	tick(slider, points)
	check(slider.active() and slider.just_started, "Finger contact captures cap with no button press")
	check(is_equal_approx(device.volume_level, 0.5), "Touching edge of cap does not jump volume")
	check(device.volume_readout.visible and device.volume_readout.text == "VOL 50%", "Touch displays current volume")
	points[0].z -= Device.VOLUME_TRAVEL * 0.25
	tick(slider, points)
	check(absf(device.volume_level - 0.75) < 0.001, "Pushing toward hinge raises volume")
	check(device.volume_slider.position.z < Device.VOLUME_MIN_Z, "Cap visibly travels along side rail")
	points[0].z += Device.VOLUME_TRAVEL * 0.5
	tick(slider, points)
	check(absf(device.volume_level - 0.25) < 0.001, "Pushing toward front lowers volume")
	points[0].z += Device.VOLUME_TRAVEL * 0.25
	tick(slider, points)
	check(is_zero_approx(device.volume_level) and slider.hit_limit and device.volume_readout.text == "MUTED", "Minimum end stop mutes and reports limit")
	points[0].z -= Device.VOLUME_TRAVEL
	tick(slider, points)
	check(slider.active() and is_equal_approx(device.volume_level, 1.0) and slider.hit_limit, "Fast full-travel swipe reaches maximum without dropping capture")
	points[0].z -= 0.004
	tick(slider, points)
	check(is_equal_approx(device.volume_level, 1.0) and not slider.hit_limit, "Maximum clamps without repeated end-stop pulses")
	points[0].z += Device.VOLUME_TRAVEL * 0.25
	tick(slider, points)
	check(absf(device.volume_level - 0.75) < 0.001, "Reversing after end stop responds immediately")
	var before: float = device.volume_level
	points[0].x -= 0.04
	tick(slider, points)
	check(not slider.active() and slider.just_released and is_equal_approx(before, device.volume_level), "Lifting away releases without altering last volume")
	for i in range(50): tick(slider, points)
	check(not device.volume_readout.visible, "Readout fades from view after leaving slider")
	slider.reset()
	device.set_volume(0.5)
	points[0] = device.volume_slider.global_position + Vector3(-0.004, 0, 0.018)
	tick(slider, points)
	check(not slider.active() and is_equal_approx(device.volume_level, 0.5), "Touching bare rail does not jump slider")
	points[0] = device.volume_slider.global_position + Vector3(0.010, 0, 0)
	tick(slider, points)
	check(not slider.active(), "Cannot touch slider through shell from inside")
	points[0] = device.volume_slider.global_position + Vector3(-0.004, 0, 0)
	tick(slider, points, [false, false, false, false])
	check(not slider.active(), "Holding/tool/tracking-ineligible finger cannot adjust volume")
	tick(slider, points)
	check(slider.active(), "Eligible contact can start again")
	points[0].z += 0.1
	tick(slider, points)
	check(not slider.active() and is_equal_approx(device.volume_level, 0.5), "Tracking-sized jump cancels without muting")
	points[0] = device.volume_slider.global_position + Vector3(-0.004, 0, 0)
	tick(slider, points)
	tick(slider, points, [false, false, false, false])
	check(not slider.active(), "Tracking loss cancels touch capture")
	slider.reset()
	points[0] = device.volume_slider.global_position + Vector3(-0.004, 0, 0)
	tick(slider, points)
	points[0].z += 0.0001
	tick(slider, points)
	check(is_equal_approx(device.volume_level, 0.5), "Sub-millimeter jitter does not change volume")
	slider.reset()
	points = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, device.volume_slider.global_position + Vector3(-0.004, 0, 0)]
	tick(slider, points, [false, false, false, true])
	check(slider.active_tip == 3 and slider.hand_index() == 1, "Either hand and thumb can touch cap")
	# Console-local motion survives room transforms and user-selected size.
	slider.reset()
	device.global_transform = Transform3D(Basis.from_euler(Vector3(0.3, 0.8, 0.2)).scaled(Vector3.ONE * 1.6), Vector3(0.2, 1.1, -0.5))
	points[0] = device.to_global(device.volume_slider.position + Vector3(-0.004, 0, 0))
	tick(slider, points)
	points[0] -= device.global_basis.z * Device.VOLUME_TRAVEL * 0.2
	tick(slider, points)
	check(absf(device.volume_level - 0.7) < 0.001, "Slider follows rotated/scaled console, not world coordinates")
	var carrier: Transform3D = Transform3D(Basis(Vector3.UP, 0.1), Vector3(0.03, 0.02, 0.01))
	device.global_transform = carrier * device.global_transform
	points[0] = carrier * points[0]
	tick(slider, points)
	check(absf(device.volume_level - 0.7) < 0.001, "Moving finger and console together does not change volume")
	var hand := Hand.new()
	world.add_child(hand)
	hand.build(false)
	hand.skeleton.force_update_all_bone_transforms()
	var index: int = hand.bones.index_dip
	var actual: Vector3 = hand.skeleton.global_transform * hand.skeleton.get_bone_global_pose(index) * Vector3(0, 0, -hand._digits.index.segments.z)
	check(hand.fingertip_position().is_equal_approx(actual), "Contact endpoint matches articulated visible finger, not aim ray")
	# Game audio routing is isolated from Windows / Master and does not stop
	# stream playback while muted. Native core can create its audio node with
	# no cartridge, so this check never touches ROMs or saves.
	var master_db := AudioServer.get_bus_volume_db(0)
	var master_muted := AudioServer.is_bus_mute(0)
	var audio := Audio.new()
	var player := AudioStreamPlayer.new()
	world.add_child(player)
	audio.set_level(1)
	audio.attach_player(player)
	var bus := AudioServer.get_bus_index(Audio.BUS)
	check(player.bus == Audio.BUS and bus > 0, "Only game player routes to isolated audio bus")
	audio.set_level(0.5)
	for i in range(40): audio.update(0.016)
	check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.25)) < 0.05, "Slider adjusts actual game bus with perceptual gain curve")
	audio.set_level(0)
	for i in range(40): audio.update(0.016)
	check(AudioServer.is_bus_mute(bus), "Minimum truly mutes game bus")
	audio.set_level(0.005)
	audio.update(0.016)
	check(not AudioServer.is_bus_mute(bus), "Tiny nonzero setting unmutes even when gain is at floor")
	audio.set_level(0)
	audio.update(0.016)
	check(AudioServer.is_bus_mute(bus), "Exact zero mutes even when gain was already at floor")
	audio.set_level(1)
	for i in range(40): audio.update(0.016)
	check(not AudioServer.is_bus_mute(bus) and absf(AudioServer.get_bus_volume_db(bus)) < 0.05, "Raising slider smoothly restores game volume")
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), master_db) and AudioServer.is_bus_mute(0) == master_muted, "Master volume and mute remain unchanged")
	var backend := Backend.new()
	world.add_child(backend)
	backend.set_volume(0)
	backend.set_enabled(true)
	await process_frame
	await process_frame
	var native_player: AudioStreamPlayer
	if backend._core is Node:
		for child in backend._core.get_children():
			if child is AudioStreamPlayer: native_player = child
	check(native_player != null and native_player.bus == Audio.BUS, "Real native audio child is routed before playback")
	if native_player:
		check(native_player.playing and not native_player.stream_paused, "Muting never pauses native generator / stream")
	backend.set_volume(0.3)
	for i in range(40): backend.game_audio.update(0.016)
	check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.09)) < 0.05, "Integrated backend volume reaches real native audio bus")
	backend.set_enabled(false)
	await process_frame
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.device.set_volume(0.42)
	check(absf(scene.emulator_backend.output_volume - 0.42) < 0.001 and scene.settings_dirty, "Console signal updates backend and marks setting for persistence")
	check(absf(scene.volume_gui.value - 42) < 0.01, "Desktop volume UI follows physical slider changes")
	scene.volume_touch.active_tip = 0
	scene.router.update_touch(Vector2(0.5, 0.5), true)
	scene._update_vr_touch()
	check(not scene.router.touch_down, "Volume contact cannot accidentally send laser touchscreen input")
	var launcher = load("res://launcher.tscn").instantiate()
	root.add_child(launcher)
	launcher.fit_controls.volume.slider.set_value_no_signal(70)
	launcher.volume_seen = 0.7
	launcher._sync_volume_from_setting(0.3)
	check(absf(launcher.fit_controls.volume.slider.value - 30) < 0.01, "Open launcher preserves new physical volume instead of stale startup value")
	launcher.fit_controls.volume.slider.set_value_no_signal(55)
	launcher._sync_volume_from_setting(0.3)
	check(absf(launcher.fit_controls.volume.slider.value - 55) < 0.01, "Explicit launcher volume edit wins over stale on-disk value")
	print("VOLUME TEST: %d checks, %d failures" % [checks, failures])
	quit(failures)
