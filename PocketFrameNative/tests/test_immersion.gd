extends SceneTree
const Device = preload("res://scripts/handheld.gd")
const Interactions = preload("res://scripts/immersive_interactions.gd")
const Pen = preload("res://scripts/stylus_motion.gd")
const Router = preload("res://scripts/input_router.gd")
var failures := 0
var assertions := 0
var world: Node3D
var device: Node3D
var interaction
var dock := Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
var hands: Array

func check(condition: bool, title: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(title)

func _initialize() -> void:
	_run.call_deferred()

func fresh() -> void:
	interaction.reset()
	device.global_transform = dock
	device.set_lid_angle(145)
	hands = [Transform3D(Basis.IDENTITY, device.to_global(Vector3(-0.066, 0, 0.009))), Transform3D(Basis.IDENTITY, device.to_global(Vector3(0.066, 0, 0.009)))]
	tick([false, false])

func tick(grips: Array, triggers: Array = [false, false], tracked: Array = [true, true], clicks: Array = [false, false], aims: Array = [], delta: float = 0.016) -> void:
	interaction.step(delta, hands, tracked, grips, triggers, dock, clicks, aims)

func set_free_pen(pose: Transform3D) -> void:
	if device.stylus.get_parent() != world:
		device.stylus.reparent(world, true)
	device.stylus.global_transform = pose
	interaction.pen_motion.phase = "free"
	interaction.pen_motion.writing_hand = 1
	var grip_local: Transform3D = interaction.pen_motion.writing_pose(Transform3D.IDENTITY)
	hands[1] = pose * grip_local.affine_inverse()
	interaction.pen_motion.hand_offset = hands[1].affine_inverse() * pose
	interaction.pen_motion.grip_blend = 1

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	device = Device.new()
	world.add_child(device)
	interaction = Interactions.new()
	interaction.setup(device, world)
	fresh()
	tick([true, false])
	check(interaction.held_count() == 1 and interaction.holding(0), "Left grip picks up console, not nearby pen")
	check(device.global_transform.is_equal_approx(dock), "Pickup has no pose jump")
	hands[0].origin += Vector3(0.12, 0.03, 0)
	interaction.step(1, hands, [true, true], [true, false], [false, false], dock)
	check(device.position.distance_to(dock.origin + Vector3(0.12, 0.03, 0)) < 0.001, "Single hand carries console")
	hands[1].origin = device.to_global(Vector3(0.066, 0, 0.009))
	var before: Transform3D = device.global_transform
	tick([true, true])
	check(interaction.held_count() == 2 and device.global_transform.is_equal_approx(before), "Second hand joins without jump")
	tick([false, true])
	check(interaction.holding(1) and not interaction.holding(0) and device.global_transform.is_equal_approx(before), "Release transfers hold without jump")
	hands[0].origin += Vector3.ONE
	tick([false, true], [false, false], [false, true])
	check(device.global_transform.is_equal_approx(before), "Free hand movement/tracking loss does not steer console")
	hands[1].origin += Vector3.ONE
	tick([false, false], [false, false], [true, false])
	check(interaction.holding(1) and device.global_transform.is_equal_approx(before), "Holder tracking loss freezes without dropping")
	tick([false, true])
	check(device.global_transform.is_equal_approx(before), "Tracking recovery rebases without jump")
	interaction.step(1, hands, [true, true], [false, false], [false, false], dock)
	check(interaction.held_count() == 0 and device.global_transform.is_equal_approx(dock), "Last grip release docks")
	fresh()
	tick([true, true], [false, false], [true, true], [true, true])
	check(interaction.locked == [true, true] and interaction.held_count() == 2, "Simultaneous clicks lock each hand, not dock")
	tick([false, false], [false, false], [true, true], [true, true])
	check(interaction.held_count() == 2 and interaction.locked == [true, true], "Locks retain hands without grip and clicks debounce")
	tick([false, false])
	tick([false, false], [false, false], [true, true], [false, true])
	check(interaction.locked == [true, false] and not interaction.holding(1), "Unlock frees just right hand")
	tick([false, false])
	tick([true, false], [false, false], [true, true], [true, false])
	check(interaction.holding(0) and not interaction.locked[0], "Unlock with grip held retains temporary hold")
	tick([false, false])
	check(interaction.held_count() == 0, "Unlocked last hand releases")
	fresh()
	tick([true, false])
	tick([false, true])
	check(interaction.holding(1) and device.global_transform.is_equal_approx(dock), "Same-frame holder transfer rebases by identity")
	fresh()
	tick([false, false], [false, false], [true, true], [true, true])
	check(interaction.locked == [false, false], "Free hand cannot lock absent hold")
	fresh()
	hands[1].origin = device.lid.to_global(Vector3(0.06, 0.003, -0.084))
	tick([false, false], [false, true])
	check(interaction.tool.is_empty(), "Trigger alone no longer acquires hinge")
	tick([false, true])
	check(interaction.tool == "hinge" and not interaction.holding(1), "Grip acquires hinge, not body")
	var relative: Vector3 = device.to_local(hands[1].origin) - device.lid.position
	hands[1].origin = device.to_global(device.lid.position + Basis(Vector3.RIGHT, deg_to_rad(20)) * relative)
	tick([false, true])
	check(absf(device.lid_angle - 125) < 0.1, "Grip-held hinge follows hand")
	hands[1].origin = device.to_global(device.lid.position + Basis(Vector3.RIGHT, deg_to_rad(150)) * relative)
	tick([false, true])
	check(is_equal_approx(device.lid_angle, 25), "Hinge clamp retained")
	tick([false, false], [false, true])
	check(interaction.tool.is_empty(), "Grip release releases hinge despite held trigger")
	fresh()
	hands[1].origin = device.stylus_handle_position()
	tick([false, false], [false, true])
	check(interaction.tool.is_empty(), "Trigger alone no longer takes pen")
	tick([false, true])
	check(interaction.tool == "stylus" and interaction.pen_motion.phase == "extracting", "Grip starts pen extraction")
	check(device.stylus.global_position.is_equal_approx(device.to_global(Pen.STORED)), "Pen acquisition does not snap through shell")
	hands[1].origin += Vector3(0.10, 0.10, 0.025)
	tick([false, true])
	var local: Vector3 = device.to_local(device.stylus.global_position)
	check(absf(local.x - Pen.STORED.x) < 0.00001 and absf(local.y - Pen.STORED.y) < 0.00001, "Sideways pull cannot shear pen through slot")
	check(absf(interaction.pen_motion.slide - 0.025) < 0.00001, "Outward hand motion slides pen along channel")
	tick([false, false])
	for i in range(40): tick([false, false])
	check(interaction.pen_motion.phase == "stored" and device.stylus.get_parent() == device, "Partial extraction release slides pen back into well")
	hands[1].origin = device.stylus_handle_position()
	tick([false, true])
	hands[1].origin.z += Pen.TRAVEL
	tick([false, true])
	check(interaction.pen_motion.phase == "free", "Pen is free only after clearing shell")
	var tip: Vector3 = device.stylus.to_global(Vector3(0, 0, -0.029))
	check(device.to_local(tip).z > Pen.MOUTH.z, "Tip is outside shell at rail release")
	check(not interaction.holding(1), "Pen hand cannot hold console simultaneously")
	var pen_pose := Transform3D(device.global_basis, device.to_global(Vector3(0, 0.035, 0.004)))
	set_free_pen(pen_pose)
	hands[1].origin.y -= 0.040
	tick([false, true])
	check(interaction.pen_motion.blocked, "Pen shaft collides with deck")
	check(interaction.pen_motion._contact_push(device.stylus.global_transform, dock).length() < 0.00002, "Whole pen is outside console after collision solve")
	check(interaction.touch_uv.x >= 0, "Collision-limited tip still touches lower LCD")
	var router := Router.new()
	router.update_touch(interaction.touch_uv, true)
	check(router.touch_down, "Physical pen uses existing emulator touch API")
	var old_uv: Vector2 = interaction.touch_uv
	hands[1].origin.x += 0.012
	tick([false, true])
	check(interaction.touch_uv.x > old_uv.x, "Pen slides along LCD while pressed")
	hands[1].origin.y += 0.08
	tick([false, true])
	check(interaction.touch_uv.x < 0, "Lifting releases touchscreen")
	tick([false, false])
	check(interaction.pen_motion.phase == "loose" and device.stylus.get_parent() == world, "Free release does not teleport pen through console")
	var release_y: float = device.stylus.global_position.y
	for i in range(8): tick([false, false])
	check(device.stylus.global_position.y < release_y, "Released pen falls")
	hands[1].origin = device.stylus_handle_position()
	tick([false, true])
	check(interaction.tool == "stylus" and interaction.pen_motion.phase == "free", "Dropped pen can be re-gripped")
	pen_pose = device.global_transform * Transform3D(Basis.IDENTITY, Pen.STORED + Vector3(0, 0, 0.057))
	set_free_pen(pen_pose)
	tick([false, true])
	check(interaction.pen_motion.phase == "inserting", "Aligned tip enters mouth guide")
	hands[1].origin.z -= 0.05
	tick([false, true])
	check(interaction.pen_motion.slide < 0.01, "Pushing slides pen into left well")
	tick([false, false])
	for i in range(10): tick([false, false])
	check(interaction.pen_motion.phase == "stored" and device.stylus.position.is_equal_approx(Pen.STORED), "Inserted pen seats on release")
	fresh()
	device.global_transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.5, 0.1)).scaled(Vector3.ONE * 1.6), Vector3(0.3, 1.2, -0.4))
	dock = device.global_transform
	hands[0] = Transform3D(device.global_basis.orthonormalized(), device.stylus_handle_position())
	tick([true, false])
	hands[0].origin += device.global_basis.z * 0.03
	tick([true, false])
	check(absf(interaction.pen_motion.slide - 0.03) < 0.00001, "Rail supports scaled rotated console")
	tick([true, false], [false, false], [false, true])
	check(interaction.tool.is_empty() and interaction.pen_motion.phase == "stored", "Tracking loss stores pen safely")
	hands[0].origin = device.stylus_handle_position()
	tick([true, false])
	check(interaction.tool.is_empty(), "Tracking recovery cannot auto-grab held grip")
	tick([false, false])
	tick([true, false])
	check(interaction.tool == "stylus", "Either hand can take pen after grip release")
	interaction.reset()
	check(interaction.locked == [false, false] and interaction.pen_motion.phase == "stored" and not device.interaction_hint.visible, "Reset clears locks, pen, tool and hint")
	fresh()
	hands[1] = Transform3D(device.global_basis.orthonormalized(), device.stylus_handle_position() + device.global_basis.z * 0.20)
	var aims := [null, hands[1]]
	tick([false, false], [false, false], [true, true], [false, false], aims)
	check(interaction.hover == "stylus" and device.interaction_hint.text.begins_with("GRIP"), "Nearby pen aim displays grip prompt")
	tick([false, true], [false, false], [true, true], [false, false], aims)
	check(interaction.tool == "stylus", "Short-range grip targeting takes pen")
	interaction.reset()
	tick([false, false])
	hands[1].origin = device.stylus_handle_position() + device.global_basis.z * 0.7
	aims[1] = hands[1]
	tick([false, true], [false, false], [true, true], [false, false], aims)
	check(interaction.tool.is_empty(), "Distant grip cannot take pen")
	await process_frame
	await process_frame
	var meshes: Array = device.get_node("LowerHousing").get_meshes()
	check(meshes.size() == 2, "Cut shell produces renderable geometry")
	if meshes.size() == 2:
		var mesh: Mesh = meshes[1]
		check(not hits_shell(mesh, Vector3(-0.05, 0, 0.058), Vector3(-0.05, 0, 0.020)), "Slot mouth is a real hole through shell")
		check(hits_shell(mesh, Vector3(-0.044, 0, 0.058), Vector3(-0.044, 0, 0.020)), "Wall remains solid beside hole")
	print("IMMERSION TEST: %d checks, %d failures" % [assertions, failures])
	quit(failures)

func hits_shell(mesh: Mesh, start: Vector3, end: Vector3) -> bool:
	var faces := mesh.get_faces()
	for i in range(0, faces.size(), 3):
		# Engine triangle epsilon assumes larger geometry; test millimeter detail
		# in mm so a tiny bore-wall triangle is not treated as degenerate.
		if Geometry3D.segment_intersects_triangle(start * 1000, end * 1000, faces[i] * 1000, faces[i + 1] * 1000, faces[i + 2] * 1000) != null:
			return true
	return false
