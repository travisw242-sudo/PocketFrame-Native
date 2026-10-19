extends SceneTree
const Hand = preload("res://scripts/rigged_hand.gd")
const Device = preload("res://scripts/handheld.gd")
const SideSlider = preload("res://scripts/side_volume_slider.gd")
const HandPose = preload("res://scripts/hand_pose.gd")
var failures := 0
func check(ok: bool, title: String) -> void:
	if not ok:
		failures += 1
		push_error(title)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var device := Device.new()
	root.add_child(device)
	device.transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.4, 0)).scaled(Vector3.ONE * 1.25), Vector3(0, 1, -0.3))
	device.set_volume(0.5)
	var controller := Node3D.new()
	root.add_child(controller)
	var hand := Hand.new()
	controller.add_child(hand)
	hand.build(true)
	var pointing := device.global_basis.orthonormalized() * Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT)
	controller.global_transform = Transform3D(pointing * HandPose.grip_transform(true).basis.inverse(), device.global_position)
	hand.set_game_inputs({}, Vector2.ZERO, 1, "", {"grip": 0.7})
	controller.global_position += device.volume_slider.global_position - device.global_basis.x.normalized() * 0.005 - hand.fingertip_position()
	hand.set_game_inputs({}, Vector2.ZERO, 1, "", {"grip": 0.7, "collision_device": device})
	var slider := SideSlider.new()
	slider.setup(device)
	slider.step(0.016, [hand.fingertip_position(), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO], [true, false, false, false])
	check(slider.active(), "Imported index can still touch volume cap with hand contact enabled")
	check(is_equal_approx(device.volume_level, 0.5), "Hand contact does not jump volume on acquisition")
	controller.global_position -= device.global_basis.z * Device.VOLUME_TRAVEL * 0.2
	hand.set_game_inputs({}, Vector2.ZERO, 1, "", {"grip": 0.7, "collision_device": device})
	slider.step(0.016, [hand.fingertip_position(), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO], [true, false, false, false])
	check(slider.active() and device.volume_level > 0.65, "Articulated index still slides volume with unchanged touch behavior")
	print("RIGGED TOUCH TEST: ", failures, " failures")
	quit(failures)
