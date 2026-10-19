class_name PFVirtualHand
extends Node3D
## Controller-driven bare hand. GPU-skinned fingers, independent analog input,
## and contextual poses; this does not pretend to be optical finger tracking.
const HandMesh = preload("res://scripts/hand_mesh.gd")
const HandPose = preload("res://scripts/hand_pose.gd")
const DIGITS := ["index", "middle", "ring", "pinky"]
var is_left := false
var skeleton: Skeleton3D
var skin_mesh: MeshInstance3D
var bones: Dictionary = {}
var finger_curls := PackedFloat32Array([0.08, 0.13, 0.18, 0.23])
var thumb_press := 0.0
var interaction_pose := ""
var _joint_values: Array[Vector3] = []
var _rest_rotations: Array[Quaternion] = []
var _mirror := 1.0
var _digits: Dictionary = {}

func build(left_hand: bool) -> void:
	if skeleton:
		return
	is_left = left_hand
	_mirror = -1 if is_left else 1
	name = "LeftVirtualHand" if is_left else "RightVirtualHand"
	skeleton = Skeleton3D.new()
	skeleton.name = "HandSkeleton"
	add_child(skeleton)
	var builder := HandMesh.new()
	var mesh := builder.build(skeleton, is_left)
	bones = builder.bones
	for digit in builder.digit_data:
		_digits[digit.title] = digit
	skeleton.reset_bone_poses()
	skin_mesh = MeshInstance3D.new()
	skin_mesh.name = "AnatomicalHand"
	skin_mesh.mesh = mesh
	skin_mesh.skin = skeleton.create_skin_from_rest_transforms()
	skin_mesh.skeleton = NodePath("..")
	# Conservative bounds cover a fist / opposed thumb without XR culling pops.
	skin_mesh.custom_aabb = AABB(Vector3(-0.13, -0.12, -0.15), Vector3(0.26, 0.20, 0.28))
	skeleton.add_child(skin_mesh)
	for bone in range(skeleton.get_bone_count()):
		_joint_values.append(Vector3.ZERO)
		_rest_rotations.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	position = Vector3(0, -0.018, 0.030)
	set_game_inputs({}, Vector2.ZERO, 1)

func _pose(bone: String, angles: Vector3, blend: float) -> void:
	var id: int = bones[bone]
	# No arbitrary target can demand a finger flip or MCP hyperextension.
	if bone.begins_with("thumb"):
		angles.x = clampf(angles.x, -1.65 if bone.ends_with("pip") else -1.15, 0.30)
		angles.y = clampf(angles.y, -1.25, 0.35)
		angles.z = clampf(angles.z, -0.45, 0.70)
	else:
		angles.x = clampf(angles.x, -1.65, 0.20 if bone.ends_with("mcp") else 0.05)
		angles.y = clampf(angles.y, -0.28, 0.28)
		angles.z = clampf(angles.z, -0.12, 0.12)
	angles.y *= _mirror
	angles.z *= _mirror
	_joint_values[id] = _joint_values[id].lerp(angles, blend)
	skeleton.set_bone_pose_rotation(id, _rest_rotations[id] * Quaternion.from_euler(_joint_values[id]))

func _pinch_digit(title: String, target: Vector3, blend: float, dip: float = 0.26) -> void:
	# Analytical three-phalange pinch: proximal joint can lift while the distal
	# joints curl down, rather than burying the entire finger inside a fist.
	target.x *= _mirror
	var digit: Dictionary = _digits[title]
	var rest: Transform3D = digit.root
	var local := rest.affine_inverse() * target
	var segments: Vector3 = digit.segments
	var second := sqrt(segments.y * segments.y + segments.z * segments.z + 2 * segments.y * segments.z * cos(dip))
	var distance := clampf(local.length(), absf(segments.x - second) + 0.001, segments.x + second - 0.0005)
	var horizontal := Vector2(local.x, local.z).length()
	var yaw := atan2(-local.x, -local.z)
	var shoulder := atan2(local.y, horizontal) + acos(clampf((segments.x * segments.x + distance * distance - second * second) / (2 * segments.x * distance), -1, 1))
	var elbow := acos(clampf((distance * distance - segments.x * segments.x - second * second) / (2 * segments.x * second), -1, 1))
	var beta := atan2(segments.z * sin(dip), segments.y + segments.z * cos(dip))
	_pose(title + "_mcp", Vector3(shoulder, yaw, 0), blend)
	_pose(title + "_pip", Vector3(-elbow + beta, 0, 0), blend)
	_pose(title + "_dip", Vector3(-dip, 0, 0), blend)

func _console_thumb(console: Transform3D, control: Vector3, blend: float) -> void:
	# Solve in three dimensions with the first knuckle outside the shell. A
	# planar pinch could reach the button while its proximal segment cut right
	# through the side wall. The bend plane is now an explicit clearance arc.
	var data: Dictionary = _digits.thumb
	var root_rest: Transform3D = skeleton.get_bone_rest(bones.thumb_mcp)
	var origin := root_rest.origin
	var target := to_local(console * control)
	var segments: Vector3 = data.segments
	var second := segments.y + segments.z
	var direction := (target - origin).normalized()
	var distance := clampf(target.distance_to(origin), 0.012, segments.x + second - 0.0005)
	var side := -1.0 if is_left else 1.0
	var outward := global_basis.inverse() * (console.basis.orthonormalized() * Vector3(side, 1.2, 0))
	var bend := (outward - direction * outward.dot(direction)).normalized()
	var along := (segments.x * segments.x + distance * distance - second * second) / (2 * distance)
	var elbow := origin + direction * along + bend * sqrt(maxf(0, segments.x * segments.x - along * along))
	var first_dir := (elbow - origin).normalized()
	var second_dir := (origin + direction * distance - elbow).normalized()
	var axis := -first_dir.cross(second_dir).normalized()
	if axis.length_squared() < 0.5: return
	var frame := Basis(axis, (-first_dir).cross(axis), -first_dir).orthonormalized()
	var rotation := frame.get_rotation_quaternion()
	var current := skeleton.get_bone_pose_rotation(bones.thumb_mcp)
	var next := current.slerp(rotation, blend)
	skeleton.set_bone_pose_rotation(bones.thumb_mcp, next)
	_joint_values[bones.thumb_mcp] = (_rest_rotations[bones.thumb_mcp].inverse() * next).get_euler()
	_pose("thumb_pip", Vector3(-acos(clampf(first_dir.dot(second_dir), -1, 1)), 0, 0), blend)
	_pose("thumb_dip", Vector3.ZERO, blend)

func set_game_inputs(values: Dictionary, stick: Vector2, delta: float, interaction: String = "", sensors: Dictionary = {}) -> void:
	if not skeleton:
		return
	interaction_pose = interaction
	var grip := clampf(float(sensors.get("grip", 0.0)), 0, 1)
	var trigger := clampf(float(sensors.get("trigger", 1.0 if values.get("L" if is_left else "R", false) else 0.0)), 0, 1)
	var digital_thumb: bool = bool(values.get("A", false)) or bool(values.get("B", false)) or bool(values.get("X", false)) or bool(values.get("Y", false))
	if is_left:
		digital_thumb = stick.length() > 0.10
		for direction in ["UP", "DOWN", "LEFT", "RIGHT"]:
			digital_thumb = digital_thumb or bool(values.get(direction, false))
	var pressing := bool(sensors.get("thumb_press", digital_thumb))
	var blend := 1.0 - exp(-38.0 * maxf(delta, 0))
	var target_frame := HandPose.grip_transform(is_left, float(sensors.get("hand_pitch", 0)), float(sensors.get("hand_roll", 0)), float(sensors.get("hand_offset", 0)))
	if interaction == "console" and sensors.has("console_world"):
		var parent := get_parent_node_3d()
		var parent_world := parent.global_transform if parent else Transform3D.IDENTITY
		target_frame = parent_world.affine_inverse() * HandPose.console_transform(sensors.console_world, is_left)
	transform = transform.interpolate_with(target_frame, blend)
	thumb_press = lerpf(thumb_press, 1.0 if pressing else 0.0, blend)
	var targets := [maxf(0.08 + grip * 0.16, trigger * 0.97), lerpf(0.13, 0.94, grip), lerpf(0.18, 0.98, grip), lerpf(0.23, 1.0, grip)]
	var opposition := 0.12 + grip * 0.30
	var thumb_curl := 0.10 + grip * 0.36
	if interaction == "console":
		targets = [maxf(0.48, trigger * 0.94), 0.70, 0.79, 0.86]
		opposition = 0.91
		thumb_curl = 0.20 + thumb_press * 0.20
	elif interaction == "stylus":
		targets = [0.45, 0.60, 0.78, 0.86]
		opposition = 1.0
		thumb_curl = 0.54
	elif interaction == "hinge":
		targets = [0.30, 0.38, 0.55, 0.64]
		opposition = 0.72
		thumb_curl = 0.34
	for i in range(4):
		finger_curls[i] = lerpf(finger_curls[i], targets[i], blend)
		var curl: float = targets[i]
		var spread: float = [-0.04, 0.0, 0.035, 0.08][i] * (1 - curl)
		if interaction == "stylus" and i == 0:
			# Curated tripod flexion, not an unconstrained reach into the palm.
			_pose("index_mcp", Vector3(-0.12, 0, 0), blend)
			_pose("index_pip", Vector3(-1.48, 0, 0), blend)
			_pose("index_dip", Vector3(-0.82, 0, 0), blend)
			continue
		if interaction == "console":
			var flex: Vector3 = [Vector3(0.18 - trigger * 0.03, -1.30, -0.80), Vector3(0.10, -1.18, -0.62), Vector3(0.08, -1.20, -0.66), Vector3(0.05, -1.22, -0.70)][i]
			_pose(DIGITS[i] + "_mcp", Vector3(flex.x, 0.12 if i == 0 else 0, 0), blend)
			_pose(DIGITS[i] + "_pip", Vector3(flex.y, 0, 0), blend)
			_pose(DIGITS[i] + "_dip", Vector3(flex.z, 0, 0), blend)
			continue
		# All three phalanges bend, with a little independent distal motion.
		# Negative X bends -Z fingers into the palm, rather than backward.
		_pose(DIGITS[i] + "_mcp", Vector3(-lerpf(0.03, 1.05, curl), spread, 0), blend)
		_pose(DIGITS[i] + "_pip", Vector3(-lerpf(0.04, 1.48, curl), 0, 0), blend)
		_pose(DIGITS[i] + "_dip", Vector3(-lerpf(0.02, 0.90, curl), 0, 0), blend)
	var lift := 0.40 if interaction == "console" else 0.14 if interaction == "stylus" else 0.03
	if interaction == "stylus":
		var point := HandPose.TRIPOD_POINT + Vector3(-0.003, -0.002, 0.001)
		point.x *= _mirror
		_pinch_digit("thumb", point, blend)
	elif interaction == "console" and sensors.has("console_world"):
		var console: Transform3D = sensors.console_world
		var size := console.basis.x.length()
		var control := Vector3(-0.059 if is_left else 0.058, 0.012 + 0.014 / size - thumb_press * 0.001, -0.007)
		# An oversized console must not demand a physically impossible reach.
		control.x += stick.x * 0.003
		control.z -= stick.y * 0.003
		control.x = signf(control.x) * maxf(absf(control.x), 0.0792 - 0.012 / size)
		_console_thumb(console, control, blend)
	else:
		_pose("thumb_mcp", Vector3(lift - thumb_curl * 0.20, -opposition * 1.04 + stick.x * 0.08, opposition * 0.62), blend)
		_pose("thumb_pip", Vector3(-thumb_curl * 0.78 - thumb_press * 0.10, 0, 0.05), blend)
		_pose("thumb_dip", Vector3(-thumb_curl * 0.62 - thumb_press * 0.08, 0, 0), blend)

func set_tracking_visible(value: bool) -> void:
	visible = value

func fingertip_position(digit: String = "index") -> Vector3:
	# Use the same articulated endpoint the skinned hand renders, never the
	# controller grip origin or pointing ray. Main thread updates after posing.
	skeleton.force_update_all_bone_transforms()
	var data: Dictionary = _digits[digit]
	return skeleton.global_transform * skeleton.get_bone_global_pose(bones[digit + "_dip"]) * Vector3(0, 0, -data.segments.z)
