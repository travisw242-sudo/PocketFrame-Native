extends RefCounted
## Kinematic pen: guided holster, swept shaft contact, gravity after release.
## All collision calculations happen in console-local meters, including scale.
const STORED := Vector3(-0.050, -0.003, 0.022)
const MOUTH := Vector3(-0.050, -0.003, 0.0472)
const TRAVEL := 0.062
const HandPose = preload("res://scripts/hand_pose.gd")
const DECK := AABB(Vector3(-0.0792, -0.0076, -0.0472), Vector3(0.1584, 0.0166, 0.0944))
const LID := AABB(Vector3(-0.0785, -0.0035, -0.088), Vector3(0.157, 0.0078, 0.088))
const RAISED_CONTROLS := [
	AABB(Vector3(-0.070, 0.009, -0.031), Vector3(0.022, 0.006, 0.022)),
	AABB(Vector3(-0.0695, 0.009, 0.0085), Vector3(0.021, 0.003, 0.007)),
	AABB(Vector3(-0.0625, 0.009, 0.0015), Vector3(0.007, 0.003, 0.021)),
	AABB(Vector3(0.063, 0.009, -0.012), Vector3(0.010, 0.002, 0.010)),
	AABB(Vector3(0.053, 0.009, -0.002), Vector3(0.010, 0.002, 0.010)),
	AABB(Vector3(0.053, 0.009, -0.022), Vector3(0.010, 0.002, 0.010)),
	AABB(Vector3(0.043, 0.009, -0.012), Vector3(0.010, 0.002, 0.010)),
	AABB(Vector3(0.045, 0.009, -0.034), Vector3(0.008, 0.001, 0.008)),
]
var device: Node3D
var world: Node3D
var phase := "stored"
var slide := 0.0
var slide_anchor := 0.0
var hand_anchor := Vector3.ZERO
var hand_offset := Transform3D.IDENTITY
var velocity := Vector3.ZERO
var blocked := false
var grip_blend := 0.0
var writing_hand := 1
var loose_time := 0.0
var recall_time := 0.0

func setup(console: Node3D, parent: Node3D) -> void:
	device = console
	world = parent

func store() -> void:
	device.return_stylus()
	phase = "stored"
	slide = 0
	velocity = Vector3.ZERO
	blocked = false
	loose_time = 0
	recall_time = 0

func begin(hand: Transform3D, hand_index: int = 1) -> void:
	writing_hand = hand_index
	grip_blend = 0
	if device.stylus.get_parent() != world:
		device.stylus.reparent(world, true)
	if phase in ["stored", "seating"]:
		phase = "extracting"
		hand_anchor = device.to_local(hand.origin)
		slide_anchor = slide
	else:
		phase = "free"
		hand_offset = hand.affine_inverse() * device.stylus.global_transform
	velocity = Vector3.ZERO
	loose_time = 0

func release() -> void:
	phase = "seating" if phase in ["extracting", "inserting"] else "loose"
	velocity = Vector3.ZERO
	loose_time = 0

func _rail_pose() -> void:
	device.stylus.global_transform = device.global_transform * Transform3D(Basis.IDENTITY, device.stylus_stored_position() + Vector3(0, 0, slide))
	device.stylus_extension = slide / TRAVEL

func writing_pose(hand: Transform3D, aim_pose: Variant = null) -> Transform3D:
	# Pen and hand must use ONE grip frame. The aim ray remains for pointing,
	# not for twisting the visible hand away from the user's wrist.
	var left := writing_hand == 0
	var fit := HandPose.grip_transform(left, device.hand_pitch, device.hand_roll, device.hand_offset)
	return hand * fit * HandPose.pen_in_hand(left, device.stylus_grip_angle, device.global_basis.x.length())

func held(delta: float, hand: Transform3D, dock: Transform3D, aim_pose: Variant = null) -> void:
	if phase in ["extracting", "inserting"]:
		blocked = false
		slide = clampf(slide_anchor + device.to_local(hand.origin).z - hand_anchor.z, 0, TRAVEL)
		_rail_pose()
		if slide >= TRAVEL - 0.00001:
			phase = "free"
			hand_offset = hand.affine_inverse() * device.stylus.global_transform
			grip_blend = 0
		return
	grip_blend = move_toward(grip_blend, 1, delta / 0.22)
	var target := (hand * hand_offset).interpolate_with(writing_pose(hand, aim_pose), smoothstep(0, 1, grip_blend))
	device.stylus.global_transform = move_pen(device.stylus.global_transform, target, dock)
	# Only a nearly aligned TIP entering the actual mouth can enter the rail.
	var local: Transform3D = device.global_transform.affine_inverse() * device.stylus.global_transform
	var tip := local * Vector3(0, 0, -0.029)
	var mouth: Vector3 = device.stylus_mouth_position()
	var radial := Vector2(tip.x - mouth.x, tip.y - mouth.y).length()
	if radial < 0.005 and absf(tip.z - mouth.z) < 0.008 and local.basis.z.normalized().dot(Vector3.BACK) > 0.97:
		phase = "inserting"
		slide = clampf(local.origin.z - device.stylus_stored_position().z, 0, TRAVEL)
		slide_anchor = slide
		hand_anchor = device.to_local(hand.origin)
		_rail_pose()

func unheld(delta: float, dock: Transform3D) -> void:
	if phase == "seating":
		slide = move_toward(slide, 0, 0.12 * delta)
		_rail_pose()
		if is_zero_approx(slide):
			store()
	elif phase == "loose":
		loose_time += delta
		if device.stylus_auto_return and loose_time >= 0.75:
			# Briefly hide before reseating, rather than flying through the console
			# or other scenery. Manual guided insertion remains available.
			phase = "recalling"
			recall_time = 0
			device.stylus.hide()
			return
		velocity.y = maxf(velocity.y - 9.8 * minf(delta, 0.05), -2.0)
		var target: Transform3D = device.stylus.global_transform
		target.origin += velocity * minf(delta, 0.05)
		device.stylus.global_transform = move_pen(device.stylus.global_transform, target, dock)
		if blocked:
			velocity *= 0.2
	elif phase == "recalling":
		recall_time += delta
		if recall_time >= 0.10:
			slide = TRAVEL
			_rail_pose()
			device.stylus.show()
			phase = "seating"

static func _sphere_box(point: Vector3, radius: float, box: AABB) -> Vector3:
	var nearest := point.clamp(box.position, box.end)
	var offset := point - nearest
	var distance := offset.length()
	if distance >= radius:
		return Vector3.ZERO
	if distance > 0.000001:
		return offset * ((radius - distance + 0.00001) / distance)
	var best := INF
	var push := Vector3.ZERO
	for axis in range(3):
		var low := point[axis] - box.position[axis] + radius
		var high := box.end[axis] - point[axis] + radius
		if low < best:
			best = low
			push = Vector3.ZERO
			push[axis] = -low - 0.00001
		if high < best:
			best = high
			push = Vector3.ZERO
			push[axis] = high + 0.00001
	return push

func _contact_push(pose: Transform3D, dock: Transform3D) -> Vector3:
	var inverse: Transform3D = device.global_transform.affine_inverse()
	var local := inverse * pose
	var lid_inverse: Transform3D = device.lid.global_transform.affine_inverse()
	var pen_lid := lid_inverse * pose
	var plinth := dock
	plinth.basis = plinth.basis.orthonormalized()
	plinth = plinth.translated_local(Vector3(0, -0.031, -0.015))
	var pen_plinth := plinth.affine_inverse() * pose
	var scale_size: float = device.global_basis.x.length()
	var pen_scale := pose.basis.x.length()
	var best := Vector3.ZERO
	for i in range(20):
		var z := lerpf(-0.0285, 0.026, float(i) / 19.0)
		var radius := 0.00065 if z < -0.024 else 0.0023 if z > 0.024 else 0.0018
		var sample := Vector3(0, 0, z)
		var local_radius := radius * pen_scale / scale_size
		var point := local * sample
		var push := _sphere_box(point, local_radius, DECK)
		if point.y > 0.007 and point.y < 0.018 and absf(point.x) > 0.040:
			for control: AABB in RAISED_CONTROLS:
				var control_push := _sphere_box(point, local_radius, control)
				if control_push.length_squared() > push.length_squared():
					push = control_push
		push = device.global_basis * push
		if push.length_squared() > best.length_squared():
			best = push
		push = device.lid.global_basis * _sphere_box(pen_lid * sample, local_radius, LID)
		if push.length_squared() > best.length_squared():
			best = push
		push = plinth.basis * _sphere_box(pen_plinth * sample, radius * pen_scale, AABB(Vector3(-0.17, -0.011, -0.145), Vector3(0.34, 0.022, 0.29)))
		if push.length_squared() > best.length_squared():
			best = push
		var floor_depth := radius * pen_scale - (pose * sample).y
		if floor_depth > best.length():
			best = Vector3(0, floor_depth + 0.00001, 0)
	return best

func move_pen(start: Transform3D, target: Transform3D, dock: Transform3D) -> Transform3D:
	blocked = false
	var scale_size: float = device.global_basis.x.length()
	# Clamp tracking teleports, then sweep translation AND rotation. A tiny pen
	# must not jump through a thin lid between display frames.
	var travel := target.origin.distance_to(start.origin)
	if travel > 0.12 * scale_size:
		target.origin = start.origin.move_toward(target.origin, 0.12 * scale_size)
		travel = 0.12 * scale_size
	var angle := start.basis.orthonormalized().get_rotation_quaternion().angle_to(target.basis.orthonormalized().get_rotation_quaternion())
	var steps := clampi(ceili((travel / scale_size + angle * 0.03) / 0.0015), 1, 100)
	var pose := start
	for step in range(1, steps + 1):
		var weight := float(step) / steps
		var goal := start.interpolate_with(target, weight)
		# Keep the correction from earlier substeps, but allow tangential sliding.
		var previous_goal := start.interpolate_with(target, float(step - 1) / steps)
		pose.origin += goal.origin - previous_goal.origin
		pose.basis = goal.basis
		for iteration in range(12):
			var push := _contact_push(pose, dock)
			if push.length_squared() < 0.000000000001:
				break
			blocked = true
			pose.origin += push
		# Never accept an unresolved intersection (e.g. trapped under a closing lid).
		if _contact_push(pose, dock).length_squared() > 0.0000000001:
			return start
	return pose
