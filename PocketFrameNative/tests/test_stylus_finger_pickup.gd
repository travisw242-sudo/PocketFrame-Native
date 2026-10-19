extends SceneTree
const Device = preload("res://scripts/handheld.gd")
const Hand = preload("res://scripts/rigged_hand.gd")
const Interactions = preload("res://scripts/immersive_interactions.gd")
var checks := 0
var failures := 0

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var device := Device.new()
	world.add_child(device)
	var interaction := Interactions.new()
	interaction.setup(device, world)
	for slot in ["left", "right"]:
		device.set_stylus_side(slot)
		for index in range(2):
			for digit in ["index", "thumb"]:
				interaction.reset()
				var controller := Node3D.new()
				world.add_child(controller)
				var hand := Hand.new()
				controller.add_child(hand)
				hand.build(index == 0)
				hand.set_game_inputs({}, Vector2.ZERO, 1, "", {"hand_pitch": 12, "hand_roll": -9})
				controller.position += device.stylus_handle_position() - hand.fingertip_position(digit)
				check(controller.position.distance_to(device.stylus_handle_position()) > 0.027, "Fixture reaches cap with visible finger, not palm origin")
				var hands := [Transform3D(Basis.IDENTITY, Vector3(1, 1, 1)), Transform3D(Basis.IDENTITY, Vector3(1, 1, 1))]
				hands[index] = controller.global_transform
				var points: Array = [[], []]
				points[index] = [hand.fingertip_position("index"), hand.fingertip_position("thumb")]
				interaction.step(0.016, hands, [true, true], [false, false], [false, false], Transform3D.IDENTITY, [false, false], [], points)
				check(interaction.hover == "stylus", "Visible fingertip hovering cap offers pickup")
				var grips := [false, false]
				grips[index] = true
				interaction.step(0.016, hands, [true, true], grips, [false, false], Transform3D.IDENTITY, [false, false], [], points)
				check(interaction.tool == "stylus" and interaction.tool_hand == index and not interaction.holding(index), "Grip takes pen rather than console at fingertip contact")
				controller.queue_free()
	interaction.reset()
	var hands := [Transform3D(Basis.IDENTITY, Vector3(-0.066, 0, 0.009)), Transform3D(Basis.IDENTITY, Vector3(1, 1, 1))]
	interaction.step(0.016, hands, [true, true], [false, false], [false, false], Transform3D.IDENTITY)
	interaction.step(0.016, hands, [true, true], [true, false], [false, false], Transform3D.IDENTITY)
	check(interaction.holding(0) and interaction.tool.is_empty(), "Ordinary body pickup is not stolen by pen")
	interaction.reset()
	print("STYLUS FINGER PICKUP: %d checks, %d failures" % [checks, failures])
	quit(failures)
