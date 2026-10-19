extends SceneTree
const Device = preload("res://scripts/handheld.gd")
const Interactions = preload("res://scripts/immersive_interactions.gd")
var failures := 0
var checks := 0
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
	for size in [0.8, 1.25, 2.0]:
		for angle in [25, 75, 145, 164, 175]:
			for index in range(2):
				interaction.reset()
				device.transform = Transform3D(Basis.from_euler(Vector3(0.3, 0.4, -0.2)).scaled(Vector3.ONE * size), Vector3(0, 1, -0.4))
				device.set_lid_angle(angle)
				var dock := device.global_transform
				var hands := [Transform3D(Basis.IDENTITY, Vector3.ONE * 2), Transform3D(Basis.IDENTITY, Vector3.ONE * 2)]
				hands[index] = Transform3D(device.global_basis.orthonormalized(), device.to_global(Vector3(-0.074 if index == 0 else 0.074, 0, 0.009)))
				var rim: Vector3 = device.lid.to_global(Vector3(-0.06 if index == 0 else 0.06, 0.003, -0.084))
				var aims: Array = [null, null]
				aims[index] = Transform3D(Basis.looking_at((rim - hands[index].origin).normalized(), Vector3.UP), hands[index].origin)
				var tips: Array = [[], []]
				tips[index] = [rim] # A long hand / pointer cannot steal a body grip.
				interaction.step(0.016, hands, [true, true], [false, false], [false, false], dock, [false, false], aims, tips)
				var grips := [false, false]
				grips[index] = true
				interaction.step(0.016, hands, [true, true], grips, [false, false], dock, [false, false], aims, tips)
				check(interaction.holding(index) and interaction.tool.is_empty(), "Lower shell pickup wins over lid ray on either hand")
				interaction.reset()
				hands[index].origin = rim
				interaction.step(0.016, hands, [true, true], [false, false], [false, false], dock)
				interaction.step(0.016, hands, [true, true], grips, [false, false], dock)
				check(interaction.tool == "hinge", "Deliberate upper-rim grip still adjusts lid")
	interaction.reset()
	print("PICKUP PRIORITY: %d checks, %d failures" % [checks, failures])
	quit(failures)
