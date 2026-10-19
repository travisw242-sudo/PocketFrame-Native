extends RefCounted
## All coordinates are console/controller geometry; no ROM or game assumptions.
const Solver = preload("res://scripts/hold_solver.gd")
const PEN_GRIP_OFFSET := Vector3(0, -0.012, -0.075)
const PenMotion = preload("res://scripts/stylus_motion.gd")
var pen_motion := PenMotion.new()
var device: Node3D
var world: Node3D
var holders := [false, false]
var locked := [false, false]
var previous_clicks := [false, false]
var tool_armed := [true, true]
var hover := ""
var previous_grips := [false, false]
var previous_triggers := [false, false]
var hold_offset := Transform3D.IDENTITY
var last_basis := Basis.IDENTITY
var tool_hand := -1
var tool := ""
var hinge_start_angle := 0.0
var hinge_start_polar := 0.0
var previous_tip := Vector3.ZERO
var tip_valid := false
var touch_uv := Vector2(-1, -1)
var last_event := ""
var needs_rebase := false

func setup(console: Node3D, parent: Node3D) -> void:
	device = console
	world = parent
	pen_motion.setup(console, parent)
	last_basis = device.global_basis.orthonormalized()

func held_count() -> int:
	return int(holders[0]) + int(holders[1])

func holding(hand: int) -> bool:
	return holders[hand]

func holding_tracking_valid(tracked: Array) -> bool:
	for i in range(2):
		if holders[i] and not tracked[i]:
			return false
	return true

func reset() -> void:
	holders = [false, false]
	locked = [false, false]
	previous_clicks = [true, true]
	tool_armed = [false, false]
	hover = ""
	device.show_interaction_hint("")
	# A held button must be released before picking up again after docking.
	previous_grips = [true, true]
	previous_triggers = [true, true]
	needs_rebase = false
	_release_tool(true)
	pen_motion.store()

func _reference(hands: Array) -> Transform3D:
	if held_count() == 2:
		last_basis = Solver.solve_basis(hands[0], hands[1], last_basis)
		return Transform3D(last_basis, (hands[0].origin + hands[1].origin) * 0.5)
	return hands[0] if holders[0] else hands[1]

func _near_body(point: Vector3) -> bool:
	var local := device.to_local(point)
	return minf(local.distance_to(Vector3(-0.066, 0, 0.009)), local.distance_to(Vector3(0.066, 0, 0.009))) < 0.055

func _near_lid(point: Vector3, radius: float = 0.022) -> bool:
	var local: Vector3 = device.lid.to_local(point)
	var rim := Vector3(clampf(local.x, -0.075, 0.075), 0.003, -0.084)
	return local.distance_to(rim) < radius

func _tool_target(hand: Transform3D, aim_pose: Variant, fingertips: Array = []) -> String:
	# Grip poses sit inside the palm, not at the visible fingertips. Support
	# both direct reach and a short aim segment; never grab across the room.
	var scale_size: float = device.global_basis.x.length()
	var finger := hand * PEN_GRIP_OFFSET
	var pen: Vector3 = device.stylus_handle_position()
	# Use the fingers the player can actually see. Calibration rotated the
	# hand away from the legacy controller-forward probe. Direct cap contact
	# wins over the much broader body pickup area, without widening that area.
	if pen_motion.phase != "recalling":
		for point in fingertips:
			if point is Vector3 and point.distance_to(pen) < 0.018 * scale_size:
				return "stylus"
	if pen_motion.phase != "recalling" and minf(hand.origin.distance_to(pen), finger.distance_to(pen)) < 0.027 * scale_size:
		return "stylus"
	# Direct, deliberate rim contact still works with a nearly closed lid.
	# But a lower-shell grip wins over a forward probe or aim ray reaching the
	# lid: otherwise the left hand keeps editing the hinge instead of carrying.
	var local_hand := device.to_local(hand.origin)
	if _near_lid(hand.origin, 0.018) and (not _near_body(hand.origin) or local_hand.y > 0.025):
		return "hinge"
	if _near_body(hand.origin):
		return ""
	for point in fingertips:
		if point is Vector3 and _near_lid(point): return "hinge"
	if _near_lid(hand.origin) or (fingertips.is_empty() and _near_lid(finger)):
		return "hinge"
	if aim_pose is Transform3D:
		var ray: Transform3D = aim_pose
		var start := ray.origin
		var end := start - ray.basis.z.normalized() * 0.24 * scale_size
		var near_pen := Geometry3D.get_closest_point_to_segment(pen, start, end)
		if pen_motion.phase != "recalling" and near_pen.distance_to(pen) < 0.014 * scale_size:
			return "stylus"
		var rim_left: Vector3 = device.lid.to_global(Vector3(-0.075, 0.003, -0.084))
		var rim_right: Vector3 = device.lid.to_global(Vector3(0.075, 0.003, -0.084))
		var closest := Geometry3D.get_closest_points_between_segments(start, end, rim_left, rim_right)
		if closest[0].distance_to(closest[1]) < 0.016 * scale_size:
			return "hinge"
	return ""

func _polar(point: Vector3) -> float:
	var local: Vector3 = device.to_local(point) - device.lid.position
	return atan2(local.y, -local.z)

func _release_tool(force_store: bool = false) -> void:
	if tool_hand >= 0:
		tool_armed[tool_hand] = false
	if tool == "stylus" and is_instance_valid(device):
		if force_store:
			pen_motion.store()
		else:
			pen_motion.release()
	tool = ""
	tool_hand = -1
	tip_valid = false
	touch_uv = Vector2(-1, -1)

func recall_stylus() -> void:
	if tool == "stylus":
		_release_tool(true)
	pen_motion.store()

func step(delta: float, hands: Array, tracked: Array, grips: Array, triggers: Array, dock: Transform3D, clicks: Array = [false, false], aims: Array = [], fingertips: Array = [], reserved: Array = [false,false]) -> void:
	last_event = ""
	hover = ""
	var was_touching := touch_uv.x >= 0
	# Remember the old tip in the old screen frame. Reusing an old world point
	# with the new moving console can invent a plane crossing during pickup.
	var last_local_tip: Vector3 = device.bottom_surface.to_local(previous_tip) if tip_valid else Vector3.ZERO
	touch_uv = Vector2(-1, -1)
	var old_count := held_count()
	var old_holders := holders.duplicate()
	for i in range(2):
		if tracked[i] and not grips[i]:
			tool_armed[i] = true
		if holders[i] and tracked[i] and clicks[i] and not previous_clicks[i]:
			locked[i] = not locked[i]
			last_event = "%s hand %s" % ["Left" if i == 0 else "Right", "locked" if locked[i] else "unlocked"]
		if holders[i] and tracked[i] and not grips[i] and not locked[i]:
			holders[i] = false
	if tool_hand >= 0 and (not tracked[tool_hand] or not grips[tool_hand] or not holding_tracking_valid(tracked)):
		var released_hand := tool_hand
		_release_tool(not tracked[released_hand] or not holding_tracking_valid(tracked))
		tool_armed[released_hand] = tracked[released_hand] and not grips[released_hand]
	# Grip tools are reserved before console acquisition, so a hand cannot
	# simultaneously drive the hinge/pen and pull the entire console.
	for i in range(2):
		if tracked[i] and not reserved[i] and not holders[i] and tool_hand < 0 and holding_tracking_valid(tracked):
			var candidate := _tool_target(hands[i], aims[i] if aims.size() == 2 else null, fingertips[i] if fingertips.size() == 2 else [])
			if not candidate.is_empty():
				hover = candidate
			if not grips[i] or not tool_armed[i]:
				continue
			if candidate == "stylus":
				tool_hand = i
				tool = "stylus"
				pen_motion.begin(hands[i], i)
				last_event = "Stylus gripped · pull outward from the %s slot" % device.stylus_side
			elif candidate == "hinge":
				tool_hand = i
				tool = "hinge"
				hinge_start_angle = device.lid_angle
				hinge_start_polar = _polar(hands[i].origin)
				last_event = "Hinge grabbed"
	for i in range(2):
		if tracked[i] and not reserved[i] and grips[i] and not previous_grips[i] and i != tool_hand and _near_body(hands[i].origin):
			holders[i] = true
			if not old_holders[i] and clicks[i] and not previous_clicks[i]:
				locked[i] = true
	var count := held_count()
	if holders != old_holders:
		needs_rebase = count > 0
	if count > 0 and not holding_tracking_valid(tracked):
		needs_rebase = true
	if needs_rebase and count > 0 and holding_tracking_valid(tracked):
		hold_offset = _reference(hands).affine_inverse() * device.global_transform
		needs_rebase = false
		last_event = "Console held with %d hand(s)" % count
	if count > 0:
		if holding_tracking_valid(tracked):
			var target := _reference(hands) * hold_offset
			device.global_transform = device.global_transform.interpolate_with(target, 1.0 - exp(-30.0 * delta))
	else:
		device.global_transform = device.global_transform.interpolate_with(dock, 1.0 - exp(-18.0 * delta))
		if old_count > 0:
			last_event = "Console returned to dock"
	if tool == "hinge":
		var movement := wrapf(_polar(hands[tool_hand].origin) - hinge_start_polar, -PI, PI)
		device.set_lid_angle(clampf(hinge_start_angle - rad_to_deg(movement), 25, 175))
	elif tool == "stylus":
		var previous_phase: String = pen_motion.phase
		pen_motion.held(delta, hands[tool_hand], dock, aims[tool_hand] if aims.size() == 2 else null)
		if previous_phase == "extracting" and pen_motion.phase == "free":
			last_event = "Stylus clear of slot"
		elif previous_phase == "free" and pen_motion.phase == "inserting":
			last_event = "Stylus aligned with slot · slide inward"
		var tip: Vector3 = device.stylus.to_global(Vector3(0, 0, -0.029))
		if pen_motion.phase == "free":
			touch_uv = device.stylus_touch(tip, device.bottom_surface.to_global(last_local_tip) if tip_valid else tip, was_touching)
		previous_tip = tip
		tip_valid = pen_motion.phase == "free"
	if tool != "stylus":
		pen_motion.unheld(delta, dock)
	for i in range(2):
		previous_grips[i] = grips[i] if tracked[i] else true
		previous_triggers[i] = triggers[i] if tracked[i] else true
		previous_clicks[i] = clicks[i] if tracked[i] else true
	device.show_interaction_hint(hover if tool.is_empty() else "")
