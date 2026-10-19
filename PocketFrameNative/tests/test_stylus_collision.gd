extends SceneTree
const Device = preload("res://scripts/handheld.gd")
const Pen = preload("res://scripts/stylus_motion.gd")
var failures := 0
var checks := 0

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(title)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var device := Device.new()
	world.add_child(device)
	device.position.y = 1
	var dock: Transform3D = device.global_transform
	var motion := Pen.new()
	motion.setup(device, world)
	var start := Transform3D(Basis.IDENTITY, Vector3(0, 1.08, 0.004))
	var target := start.translated(Vector3(0, -0.12, 0))
	var actual: Transform3D = motion.move_pen(start, target, dock)
	check(motion.blocked and actual.origin.y > 1.010, "Fast deck sweep cannot tunnel to underside")
	check(motion._contact_push(actual, dock).length() < 0.00002, "Fast deck sweep leaves no shaft intersection")
	start = Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 1.07, 0.004))
	target = start.translated(Vector3(0, -0.09, 0))
	actual = motion.move_pen(start, target, dock)
	var tip: Vector3 = actual * Vector3(0, 0, -0.029)
	check(motion.blocked and tip.y > 1.0088 and tip.y < 1.012, "Upright tip stops at LCD instead of penetrating")
	check(device.stylus_touch(tip, tip).distance_to(Vector2(0.5, 0.5)) < 0.001, "Upright collision tip retains correct center UV")
	start = device.lid.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.04, -0.04))
	target = device.lid.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, -0.04, -0.04))
	actual = motion.move_pen(start, target, dock)
	check(motion.blocked and device.lid.to_local(actual.origin).y > 0.005, "Fast sweep cannot tunnel through angled upper lid")
	check(motion._contact_push(actual, dock).length() < 0.00002, "Lid sweep leaves whole shaft outside")
	start = Transform3D(Basis.IDENTITY, Vector3(0.09, 1.012, 0.004))
	target = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.07, 1.007, 0.004))
	actual = motion.move_pen(start, target, dock)
	check(motion.blocked and motion._contact_push(actual, dock).length() < 0.00002, "Rotation plus translation preserves non-penetration")
	start = Transform3D(Basis.IDENTITY, Vector3(0, 1.004, 0.004))
	actual = motion.move_pen(start, start, dock)
	check(motion.blocked and motion._contact_push(actual, dock).length() < 0.00002, "Console moving onto pen causes depenetration")
	# Test plinth outside the console footprint, then floor well outside plinth.
	start = Transform3D(Basis.IDENTITY, Vector3(0.12, 1.02, 0.04))
	actual = motion.move_pen(start, start.translated(Vector3(0, -0.08, 0)), dock)
	check(motion.blocked and actual.origin.y >= 0.981, "Dropped shaft rests on display plinth")
	start = Transform3D(Basis.IDENTITY, Vector3(0.5, 0.04, 0.5))
	actual = motion.move_pen(start, start.translated(Vector3(0, -0.08, 0)), dock)
	check(motion.blocked and actual.origin.y >= 0.002, "Dropped shaft cannot fall through floor")
	start = Transform3D(Basis.IDENTITY, Vector3(-0.059, 1.04, -0.02))
	actual = motion.move_pen(start, start.translated(Vector3(0, -0.035, 0)), dock)
	check(motion.blocked and actual.origin.y > 1.016, "Raised circle pad blocks pen above deck level")
	# Same sweep on a rotated, scaled device should give the same local result.
	device.global_transform = Transform3D(Basis.from_euler(Vector3(0.3, 0.8, 0.2)).scaled(Vector3.ONE * 1.6), Vector3(0.3, 1.3, -0.4))
	dock = device.global_transform
	start = device.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0.004))
	target = device.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, -0.04, 0.004))
	actual = motion.move_pen(start, target, dock)
	check(motion.blocked and device.to_local(actual.origin).y > 0.010, "Rotated scaled shell blocks pen in local meters")
	device.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	dock = device.global_transform
	start = Transform3D(Basis.IDENTITY, Vector3(0, 1.0114, 0.004))
	target = start.translated(Vector3(0, -0.001, 0))
	var began := Time.get_ticks_usec()
	for i in range(200): motion.move_pen(start, target, dock)
	print("CONTACT BENCH: ", float(Time.get_ticks_usec() - began) / 200.0, " usec/update")
	print("STYLUS COLLISION TEST: %d checks, %d failures" % [checks, failures])
	quit(failures)
