extends "res://scripts/virtual_hand.gd"
## CC0 XR Tools art + authored poses, adapted to PocketFrame's input contract.
## Contact is visual/kinematic: never drives the emulator or console with forces.
const Contact = preload("res://scripts/hand_contact.gd")
const Surface = preload("res://scripts/hand_surface.gd")
const ASSETS := "res://assets/vendor/xr_hands/"
const TITLES := ["thumb", "index", "middle", "ring", "pinky"]
const SOURCE_NAMES := ["Thumb", "Index", "Middle", "Ring", "Little"]
var model: Node3D
var chains: Dictionary = {}
var open_pose: Dictionary = {}
var closed_pose: Dictionary = {}
var pinch_pose: Dictionary = {}
var rest_pose: Array[Quaternion] = []
var contact_curls: Dictionary = {}
var contact_device: Node3D
var contact_count := 0
var _grip_cache: Dictionary = {}
var _card_pose_cache: Dictionary = {}
var _skin_points := PackedVector3Array()
var _skin_bones := PackedInt32Array()
var _skin_weights := PackedFloat32Array()
static var material: ShaderMaterial

func build(left_hand: bool) -> void:
	if skeleton: return
	is_left = left_hand
	name = "LeftRiggedHand" if is_left else "RightRiggedHand"
	var suffix := "L" if is_left else "R"
	model = load(ASSETS + "Hand_Nails_" + suffix + ".gltf").instantiate()
	add_child(model)
	# Canonical frame matches hand_pose.gd: fingers -Z, palm -Y. Left/right
	# assets are distinct meshes; no negative scale or inverted skin normals.
	model.transform = Transform3D(Basis(Vector3.BACK, -PI / 2 if is_left else PI / 2).scaled(Vector3.ONE * 0.85), Vector3(0.0075 if is_left else -0.0075, -0.015, 0.038))
	skeleton = model.find_child("Skeleton3D", true, false)
	skin_mesh = model.find_child("mesh_Hand_Nails_" + suffix, true, false)
	skin_mesh.mesh = Surface.refined(skin_mesh.mesh, is_left)
	if not material:
		material = ShaderMaterial.new()
		material.shader = preload("res://scripts/clean_hand.gdshader")
		material.set_shader_parameter("skin_color", load(ASSETS + "caucasian_realistic_baseColor.png"))
		material.set_shader_parameter("skin_normal", load(ASSETS + "hands_normal.png"))
	skin_mesh.material_override = material
	var arrays := skin_mesh.mesh.surface_get_arrays(0)
	var source_points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var source_bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var source_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for v in range(source_points.size()):
		var name: String = skin_mesh.skin.get_bind_name(source_bones[v * 4])
		if not name.begins_with("Thumb") and not name.begins_with("Wrist"): continue
		_skin_points.append(source_points[v])
		for slot in range(4):
			_skin_bones.append(source_bones[v * 4 + slot])
			_skin_weights.append(source_weights[v * 4 + slot])
	for b in range(skeleton.get_bone_count()):
		rest_pose.append(skeleton.get_bone_rest(b).basis.orthonormalized().get_rotation_quaternion())
	for i in range(5):
		var title: String = TITLES[i]
		var labels := ["Metacarpal", "Proximal", "Distal", "Tip"] if i == 0 else ["Proximal", "Intermediate", "Distal", "Tip"]
		var chain: Array[int] = []
		for label in labels:
			chain.append(skeleton.find_bone(SOURCE_NAMES[i] + "_" + label + "_" + suffix))
		chains[title] = chain
		for j in range(3): bones[title + ["_mcp", "_pip", "_dip"][j]] = chain[j]
	open_pose = _load_pose("Grip 5.res")
	closed_pose = _load_pose("Grip.res")
	pinch_pose = _load_pose("Pinch Tight.res")
	skeleton.reset_bone_poses()
	set_game_inputs({}, Vector2.ZERO, 1)

func _load_pose(file: String) -> Dictionary:
	var animation: Animation = load(ASSETS + file)
	var result := {}
	for track in range(animation.get_track_count()):
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
		var path := animation.track_get_path(track)
		var title := String(path.get_subname(0)).replace("_R", "_L") if is_left else String(path.get_subname(0))
		var id := skeleton.find_bone(title)
		if id < 0: continue
		var q: Quaternion = animation.track_get_key_value(track, 0)
		if is_left: q = Quaternion(q.x, -q.y, -q.z, q.w)
		result[id] = q.normalized()
	return result

func _digit_pose(title: String, curl: float, blend: float = 1, pinch: bool = false) -> void:
	# Include metacarpals for the little palm cup from the authored grip.
	var prefix: String = SOURCE_NAMES[TITLES.find(title)] + "_"
	for id in range(skeleton.get_bone_count()):
		if not skeleton.get_bone_name(id).begins_with(prefix): continue
		var start: Quaternion = open_pose.get(id, rest_pose[id])
		var finish: Quaternion = (pinch_pose if pinch else closed_pose).get(id, rest_pose[id])
		skeleton.set_bone_pose_rotation(id, skeleton.get_bone_pose_rotation(id).slerp(start.slerp(finish, curl), blend).normalized())

func _restore_bind_dimensions() -> void:
	# Bone rotations are animated; translations and scale are immutable. A
	# global-pose setter decomposes a basis and can accumulate scale/shear during
	# repeated contact IK, eventually stretching the skin into long spikes.
	for id in range(skeleton.get_bone_count()):
		var rest := skeleton.get_bone_rest(id)
		skeleton.set_bone_pose_position(id, rest.origin)
		skeleton.set_bone_pose_scale(id, rest.basis.get_scale())

func _set_joint_basis(id: int, desired: Basis) -> void:
	# Set ONLY a normalized local rotation, never global pose / bone length.
	var parent := skeleton.get_bone_parent(id)
	var parent_basis := Basis.IDENTITY if parent < 0 else skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	var local := parent_basis.inverse() * desired.orthonormalized()
	skeleton.set_bone_pose_rotation(id, local.orthonormalized().get_rotation_quaternion().normalized())

func _chain_points(title: String) -> Array[Vector3]:
	skeleton.force_update_all_bone_transforms()
	var points: Array[Vector3] = []
	for id in chains[title]:
		points.append(skeleton.global_transform * skeleton.get_bone_global_pose(id).origin)
	return points

func _depth(title: String) -> float:
	var points := _chain_points(title)
	var radius := 0.007 if title in ["thumb", "middle"] else 0.0055 if title == "pinky" else 0.0065
	var depth := 0.0
	for i in range(1 if title == "thumb" else 0, 3):
		depth = maxf(depth, Contact.capsule_depth(points[i], points[i + 1], radius * (1 - i * 0.12), contact_device))
	return depth

func _contact_curl(title: String, wanted: float) -> float:
	if not is_instance_valid(contact_device): return wanted
	if global_position.distance_to(contact_device.global_position) > 0.20 + contact_device.global_basis.x.length() * 0.13: return wanted
	_digit_pose(title, 0)
	var initial := _depth(title)
	var safe := 0.0
	if initial > 0.0004:
		# A resized console may already overlap the relaxed pose. Search for a
		# nonpenetrating curl instead of treating that overlap as acceptable.
		var best_depth := initial
		for i in range(1, 17):
			var candidate := wanted * i / 16
			_digit_pose(title, candidate)
			var depth := _depth(title)
			if depth < best_depth or depth < 0.0004:
				best_depth = depth
				safe = candidate
		contact_count += 1
		return safe
	# Scan the closure, not only the final pose: a closed finger might otherwise
	# teleport through a thin shell and look clear again on its other side.
	for i in range(1, 9):
		var candidate := wanted * i / 8
		_digit_pose(title, candidate)
		if _depth(title) > maxf(initial, 0.0003) + 0.0001:
			var high := candidate
			for attempt in range(5):
				var middle := (safe + high) * 0.5
				_digit_pose(title, middle)
				if _depth(title) <= maxf(initial, 0.0003) + 0.0001: safe = middle
				else: high = middle
			contact_count += 1
			return safe
		safe = candidate
	return wanted

func _reach(title: String, target: Vector3, card: Variant = null) -> void:
	# Bounded CCD adjusts a real articulated chain, retaining the authored pose
	# as its anatomical starting point instead of stretching a finger mesh.
	var ids: Array = chains[title]
	var starting: Dictionary = {}
	for id in ids: starting[id] = skeleton.get_bone_pose_rotation(id)
	for iteration in range(22 if card!=null else 7):
		for j in range(2, -1, -1):
			var points := _chain_points(title)
			var origin: Vector3 = points[j]
			var from := (points[3] - origin).normalized()
			var to := (target - origin).normalized()
			if from.length_squared() < 0.5 or to.length_squared() < 0.5: continue
			var turn := Quaternion(from, to)
			turn = Quaternion.IDENTITY.slerp(turn, minf(1, 0.22 / maxf(turn.get_angle(), 0.001)))
			var id: int = ids[j]
			var pose := skeleton.get_bone_global_pose(id)
			var local_turn := skeleton.global_basis.inverse() * Basis(turn) * skeleton.global_basis
			pose.basis = local_turn * pose.basis
			var before := skeleton.get_bone_pose_rotation(id)
			var error := points[3].distance_to(target)
			var depth := _card_depth(title,card) if card!=null else _depth(title)
			_set_joint_basis(id, pose.basis)
			var rotation := skeleton.get_bone_pose_rotation(id)
			var next_depth := _card_depth(title,card) if card!=null else _depth(title)
			if rotation.angle_to(starting[id]) > (1.4 if card!=null else .85) or next_depth > maxf(depth, 0.0005) + 0.0002 or fingertip_position(title).distance_to(target) > error + 0.0001:
				skeleton.set_bone_pose_rotation(id, before)

func _card_depth(title: String, card: Transform3D) -> float:
	# Finger phalanges, not just their tip centers, must clear the thin shell.
	var inverse := card.affine_inverse()
	var size := card.basis.x.length()
	var points := _chain_points(title)
	var depth := 0.0
	var box := AABB(Vector3(-.0165,-.00215,-.0165),Vector3(.035,.0043,.033))
	for segment in range(3):
		var radius := (.007 if title=="thumb" else .0065 if title!="pinky" else .0055)*(1-segment*.12)
		for step in range(7):
			var point: Vector3=inverse*points[segment].lerp(points[segment+1],float(step)/6)
			depth=maxf(depth,maxf(0,radius/size-Contact.box_distance(point,box))*size)
	return depth

func _clear_card(title: String, card: Transform3D) -> void:
	# Bounded, rotation-only contact correction. No bone translation/scaling,
	# no rigid forces pushing the cartridge or user's tracked controller around.
	if _card_depth(title,card)<.0004: return
	var ids: Array=chains[title]
	var starting: Dictionary={}
	for id in ids: starting[id]=skeleton.get_bone_pose_rotation(id)
	for iteration in range(4):
		for j in range(3):
			var id: int=ids[j]
			var before := skeleton.get_bone_pose_rotation(id)
			var best := before
			var depth := _card_depth(title,card)
			for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
				for direction in [-1.,1.]:
					var candidate := (before*Quaternion(axis,direction*.16)).normalized()
					if candidate.angle_to(starting[id])>.65: continue
					skeleton.set_bone_pose_rotation(id,candidate)
					var next := _card_depth(title,card)
					if next<depth-.00001: depth=next;best=candidate
				skeleton.set_bone_pose_rotation(id,before)
			skeleton.set_bone_pose_rotation(id,best)
		if _card_depth(title,card)<.0004: break

func _palm_contact() -> void:
	if not is_instance_valid(contact_device): return
	# Multiple overlapping spheres cover the palm, heel and thumb web. Finger
	# capsules are solved separately so the hand is not one rigid fist collider.
	for iteration in range(3):
		var largest := Vector3.ZERO
		for center in [Vector3(0, 0, 0.016), Vector3(-0.020, -0.003, 0), Vector3(0.020, 0, 0), Vector3(0, 0, 0.039)]:
			var world: Vector3 = global_transform * center
			for shape in [[contact_device.global_transform, Contact.BASE], [contact_device.lid.global_transform, Contact.LID]]:
				var push := Contact.sphere_push(world, 0.012, shape[0], shape[1])
				if push.length_squared() > largest.length_squared(): largest = push
		if largest.length_squared() < 0.00000001: break
		global_position += largest.limit_length(0.025)
		contact_count += 1

func _whole_contact() -> void:
	# Depenetrate all articulated capsules as well as the palm. This also
	# handles an initially overlapping pose / resized shell, not only closure.
	for iteration in range(10):
		var largest := Vector3.ZERO
		var escape := 0.0
		var side := -1.0 if is_left else 1.0
		var size := contact_device.global_basis.x.length()
		for title in TITLES:
			var points := _chain_points(title)
			var radius := 0.007 if title in ["thumb", "middle"] else 0.0055 if title == "pinky" else 0.0065
			# The thumb metacarpal is inside the palm, not an exposed phalanx.
			# Its flesh is covered by palm shapes rather than a diagonal capsule
			# cutting across empty space between the heel and thumb web.
			for j in range(1 if title == "thumb" else 0, 3):
				for step in range(5):
					var point := points[j].lerp(points[j + 1], step / 4.0)
					for shape in [[contact_device.global_transform, Contact.BASE], [contact_device.lid.global_transform, Contact.LID]]:
						var push := Contact.sphere_push(point, radius * (1 - j * 0.12) + 0.0007, shape[0], shape[1])
						if push.length_squared() > largest.length_squared(): largest = push
						if push.length_squared() > 0.00000001:
							var local: Vector3 = shape[0].affine_inverse() * point
							escape = maxf(escape, (shape[1].size.x * 0.5 - local.x * side) * size + radius * (1 - j * 0.12) + 0.0009)
		if largest.length_squared() < 0.00000001: break
		# A held hand must escape toward its own side, never oscillate between
		# the underside and lid or push the two hands through each other.
		if interaction_pose == "console":
			global_position += contact_device.global_basis.x.normalized() * side * minf(escape, 0.015)
		else:
			global_position += largest.limit_length(0.015)
		contact_count += 1

func _aim_joint(id: int, child: int, target: Vector3) -> void:
	skeleton.force_update_all_bone_transforms()
	var pose := skeleton.get_bone_global_pose(id)
	var origin := skeleton.global_transform * pose.origin
	var end := skeleton.global_transform * skeleton.get_bone_global_pose(child).origin
	var turn := Quaternion((end - origin).normalized(), (target - origin).normalized())
	pose.basis = skeleton.global_basis.inverse() * Basis(turn) * skeleton.global_basis * pose.basis
	_set_joint_basis(id, pose.basis)

func _thumb_hold(target: Vector3, console: Transform3D) -> void:
	var points := _chain_points("thumb")
	var first := points[0].distance_to(points[1])
	var middle := points[1].distance_to(points[2])
	var last := points[2].distance_to(points[3])
	var distal_angle := 0.28
	var second := sqrt(middle * middle + last * last + 2 * middle * last * cos(distal_angle))
	var origin := points[0]
	var direction := (target - origin).normalized()
	var distance := clampf(origin.distance_to(target), absf(first - second) + 0.001, first + second - 0.001)
	var outward := console.basis.orthonormalized() * Vector3(-1 if is_left else 1, 1.2, 0.15)
	var bend := (outward - direction * outward.dot(direction)).normalized()
	var along := (first * first + distance * distance - second * second) / (2 * distance)
	var elbow := origin + direction * along + bend * sqrt(maxf(0, first * first - along * along))
	var end := origin + direction * distance
	var lower := (end - elbow).normalized()
	var normal := (elbow - origin).cross(lower).normalized()
	var beta := atan2(last * sin(distal_angle), middle + last * cos(distal_angle))
	var joint := elbow + lower.rotated(normal, -beta) * middle
	var ids: Array = chains.thumb
	_aim_joint(ids[0], ids[1], elbow)
	_aim_joint(ids[1], ids[2], joint)
	_aim_joint(ids[2], ids[3], end)

func _fit_skin() -> void:
	# Cold cached-grip refinement only. Real thumb-web / heel vertices close
	# the gaps left by conservative capsules without inflating the whole hand.
	skeleton.force_update_all_bone_transforms()
	var poses: Array[Transform3D] = []
	for bind in range(skin_mesh.skin.get_bind_count()):
		var bone := skeleton.find_bone(skin_mesh.skin.get_bind_name(bind))
		poses.append(skeleton.get_bone_global_pose(bone) * skin_mesh.skin.get_bind_pose(bind))
	var points := PackedVector3Array()
	for v in range(_skin_points.size()):
		var p := Vector3.ZERO
		for slot in range(4):
			var weight := _skin_weights[v * 4 + slot]
			if weight > 0: p += (poses[_skin_bones[v * 4 + slot]] * _skin_points[v]) * weight
		points.append(skeleton.global_transform * p)
	for attempt in range(5):
		var largest := Vector3.ZERO
		for point in points:
			for shape in [[contact_device.global_transform, Contact.BASE], [contact_device.lid.global_transform, Contact.LID]]:
				var push := Contact.sphere_push(point, 0.00015, shape[0], shape[1])
				if push.length_squared() > largest.length_squared(): largest = push
		if largest.length_squared() < 0.0000000025: break
		global_position += largest
		for v in range(points.size()): points[v] += largest
	# Opposing underside/top contacts can alternate a tiny normal correction.
	# Resolve any remainder toward the hand's own side instead of oscillating.
	var side := -1.0 if is_left else 1.0
	var escape := 0.0
	var size := contact_device.global_basis.x.length()
	for point in points:
		for shape in [[contact_device.global_transform, Contact.BASE], [contact_device.lid.global_transform, Contact.LID]]:
			if Contact.sphere_push(point, 0.0001, shape[0], shape[1]).length_squared() > 0.0000000025:
				var local: Vector3 = shape[0].affine_inverse() * point
				escape = maxf(escape, (shape[1].size.x * 0.5 - local.x * side) * size + 0.0002)
	global_position += contact_device.global_basis.x.normalized() * side * escape

func _support_curl(title: String, target: Vector3) -> void:
	# Keep support fingers on the artist's anatomical pose curve. Unrestricted
	# multi-axis IK can meet a pad target by twisting fingers sideways.
	var best: float = contact_curls[title]
	var best_error := INF
	for step in range(17):
		var curl := float(step) / 16
		_digit_pose(title, curl)
		if _depth(title) > 0.0005: continue
		var error := fingertip_position(title).distance_squared_to(target)
		if error < best_error:
			best_error = error
			best = curl
	_digit_pose(title, best)
	contact_curls[title] = best

func _bumper_finger(console: Transform3D, pressure: float) -> void:
	# Dedicated playing grip: index curls around the rear corner, while the
	# other fingers support the shell. Three fixed-length phalanges, with a
	# softly flexed distal joint rather than a straight pointing finger.
	var size := console.basis.x.length()
	var side := -1.0 if is_left else 1.0
	var target := console * Vector3(side * 0.065, 0.001, -0.048 - (0.006 - pressure * 0.001) / size)
	var points := _chain_points("index")
	var first := points[0].distance_to(points[1])
	var middle := points[1].distance_to(points[2])
	var last := points[2].distance_to(points[3])
	var distal_angle := 0.55 + pressure * 0.08
	var second := sqrt(middle * middle + last * last + 2 * middle * last * cos(distal_angle))
	var origin := points[0]
	var direction := (target - origin).normalized()
	var distance := clampf(origin.distance_to(target), absf(first - second) + 0.001, first + second - 0.001)
	var pole := console.basis.orthonormalized() * Vector3(side * 0.8, 0.1, -1.5)
	var bend := (pole - direction * pole.dot(direction)).normalized()
	var along := (first * first + distance * distance - second * second) / (2 * distance)
	var elbow := origin + direction * along + bend * sqrt(maxf(0, first * first - along * along))
	var end := origin + direction * distance
	var lower := (end - elbow).normalized()
	var normal := (elbow - origin).cross(lower).normalized()
	var beta := atan2(last * sin(distal_angle), middle + last * cos(distal_angle))
	var joint := elbow + lower.rotated(normal, -beta) * middle
	var ids: Array = chains.index
	_aim_joint(ids[0], ids[1], elbow)
	_aim_joint(ids[1], ids[2], joint)
	_aim_joint(ids[2], ids[3], end)

func set_game_inputs(values: Dictionary, stick: Vector2, delta: float, interaction: String = "", sensors: Dictionary = {}) -> void:
	if not skeleton: return
	_restore_bind_dimensions()
	interaction_pose = interaction
	contact_device = sensors.get("collision_device", null)
	var blend := 1 - exp(-38 * maxf(delta, 0))
	var previous_frame := global_transform
	var previous_rotations: Array[Quaternion] = []
	for id in range(skeleton.get_bone_count()): previous_rotations.append(skeleton.get_bone_pose_rotation(id))
	var cache_key := ""
	if interaction == "console" and sensors.has("console_world") and is_instance_valid(contact_device):
		var console: Transform3D = sensors.console_world
		cache_key = "%s/%s/%s/%s/%s" % [snappedf(console.basis.x.length(), 0.001), snappedf(contact_device.lid_angle, 1), stick.snapped(Vector2.ONE * 0.25), bool(sensors.get("thumb_press", values.get("A", false) or stick.length() > 0.1)), snappedf(float(sensors.get("trigger", 1.0 if values.get("L" if is_left else "R", false) else 0)), 0.25)]
		if _grip_cache.has(cache_key):
			var cached: Dictionary = _grip_cache[cache_key]
			global_transform = previous_frame.interpolate_with(console * cached.frame, blend)
			for id in range(skeleton.get_bone_count()): skeleton.set_bone_pose_rotation(id, previous_rotations[id].slerp(cached.rotations[id], blend))
			contact_curls = cached.curls.duplicate()
			contact_count = cached.contacts
			thumb_press = lerpf(thumb_press, 1.0 if cached.pressed else 0.0, blend)
			return
	var frame := HandPose.grip_transform(is_left, float(sensors.get("hand_pitch", 0)), float(sensors.get("hand_roll", 0)), float(sensors.get("hand_offset", 0)))
	if interaction == "console" and sensors.has("console_world"):
		var console: Transform3D = sensors.console_world
		var size := console.basis.x.length()
		var side := -1.0 if is_left else 1.0
		var world := Transform3D(console.basis.orthonormalized() * Basis(Vector3.BACK, deg_to_rad(-75 * side)), console * Vector3(side * (0.0792 + 0.024 / size), -0.0075 - 0.035 / size, -0.047 + 0.050 / size))
		var parent := get_parent_node_3d()
		frame = (parent.global_transform.affine_inverse() if parent else Transform3D.IDENTITY) * world
	elif interaction=="cartridge" and sensors.has("cartridge_world"):
		var card: Transform3D=sensors.cartridge_world
		var world := card*HandPose.card_in_hand(is_left,card.basis.x.length()).affine_inverse()
		var parent := get_parent_node_3d()
		frame=(parent.global_transform.affine_inverse() if parent else Transform3D.IDENTITY)*world
	transform = frame if not cache_key.is_empty() or interaction=="cartridge" else transform.interpolate_with(frame, blend)
	contact_count = 0
	_palm_contact()
	var card_key := ""
	if interaction=="cartridge" and sensors.has("cartridge_world"):
		var card: Transform3D=sensors.cartridge_world
		var relative: Transform3D=global_transform.affine_inverse()*card
		card_key="%s/%s/%s" % [snappedf(card.basis.x.length(),.001),relative.origin.snapped(Vector3.ONE*.001),relative.basis.orthonormalized().get_euler().snapped(Vector3.ONE*.02)]
		if _card_pose_cache.has(card_key):
			var rotations: Array=_card_pose_cache[card_key]
			for id in range(skeleton.get_bone_count()): skeleton.set_bone_pose_rotation(id,rotations[id])
			return
	var grip := clampf(float(sensors.get("grip", 0)), 0, 1)
	var trigger := clampf(float(sensors.get("trigger", 1.0 if values.get("L" if is_left else "R", false) else 0)), 0, 1)
	var pressing := bool(sensors.get("thumb_press", stick.length() > 0.1 or values.get("A", false) or values.get("UP", false)))
	thumb_press = lerpf(thumb_press, 1.0 if pressing else 0.0, blend)
	for title in TITLES:
		var wanted := maxf(0.08, trigger) if title == "index" else lerpf(0.12, 1, grip)
		if title == "thumb": wanted = 0.25 + grip * 0.35
		if interaction == "console": wanted = 0.82 + trigger * 0.12 if title == "index" else 0.95 if title != "thumb" else 0.5
		elif interaction == "stylus": wanted = 0.95 if title in ["index", "thumb"] else 0.7
		elif interaction=="cartridge": wanted={"index":.68,"thumb":.75,"middle":.42,"ring":.48,"pinky":.54}[title]
		elif interaction == "hinge": wanted = 0.5
		# Save the previous animated pose while contact searches candidate poses.
		var previous := {}
		for id in range(skeleton.get_bone_count()): previous[id] = skeleton.get_bone_pose_rotation(id)
		var actual := _contact_curl(title, wanted) if not interaction in ["stylus","cartridge"] else wanted
		contact_curls[title] = actual
		for id in previous: skeleton.set_bone_pose_rotation(id, previous[id])
		_digit_pose(title, actual, 1 if not cache_key.is_empty() or interaction=="cartridge" else blend, interaction == "stylus" or (interaction=="cartridge" and title in ["index","thumb"]))
	if interaction == "console" and sensors.has("console_world"):
		var console: Transform3D = sensors.console_world
		var size := console.basis.x.length()
		# Supporting pads seek the underside, rather than merely forming a
		# nonpenetrating fist in empty space beneath the device.
		# At native/smaller size the authored curl already cups the narrow shell;
		# forcing pads farther inward there folds the metacarpal skin/webbing.
		for finger in (["middle", "ring", "pinky"] if size > 1.05 else []):
			var row: float = {"index": -0.023, "middle": -0.004, "ring": 0.015, "pinky": 0.032}[finger]
			var support := Vector3((-1.0 if is_left else 1.0) * (0.079 - 0.012 / size), -0.0075 - 0.007 / size, row / size)
			_support_curl(finger, console * support)
		_bumper_finger(console, trigger)
		var control := Vector3(-0.059 if is_left else 0.058, (0.0118 if is_left else 0.0109) + 0.0065 / size - (1.0 if pressing else 0.0) * 0.0005, -0.020 if is_left else -0.007)
		control.x += stick.x * 0.003
		control.z -= stick.y * 0.003
		control.x = signf(control.x) * maxf(absf(control.x), 0.0792 - 0.020 / size)
		_thumb_hold(console * control, console)
		if is_instance_valid(contact_device):
			_whole_contact()
			_bumper_finger(console, trigger)
			_thumb_hold(console * control, console)
			_whole_contact()
			_fit_skin()
	elif interaction == "stylus":
		var point := HandPose.TRIPOD_POINT
		if is_left: point.x = -point.x
		for title in ["index", "thumb"]: _reach(title, global_transform * point)
	elif interaction=="cartridge" and sensors.has("cartridge_world"):
		var card: Transform3D=sensors.cartridge_world
		for title in TITLES: _clear_card(title,card)
		_reach("index",HandPose.card_pad_target(card,false),card)
		_reach("thumb",HandPose.card_pad_target(card,true),card)
		var rotations: Array[Quaternion]=[]
		for id in range(skeleton.get_bone_count()): rotations.append(skeleton.get_bone_pose_rotation(id))
		if _card_pose_cache.size()>=128: _card_pose_cache.clear()
		_card_pose_cache[card_key]=rotations
	elif is_instance_valid(contact_device) and global_position.distance_to(contact_device.global_position) < 0.20 + contact_device.global_basis.x.length() * 0.13:
		_whole_contact()
	if not cache_key.is_empty():
		var rotations: Array[Quaternion] = []
		for id in range(skeleton.get_bone_count()): rotations.append(skeleton.get_bone_pose_rotation(id))
		if _grip_cache.size() >= 256: _grip_cache.erase(_grip_cache.keys()[0])
		_grip_cache[cache_key] = {"frame": sensors.console_world.affine_inverse() * global_transform, "rotations": rotations, "curls": contact_curls.duplicate(), "contacts": contact_count, "pressed": pressing}
		global_transform = previous_frame.interpolate_with(global_transform, blend)
		for id in range(skeleton.get_bone_count()): skeleton.set_bone_pose_rotation(id, previous_rotations[id].slerp(rotations[id], blend))

func fingertip_position(digit: String = "index") -> Vector3:
	if not skeleton or not chains.has(digit): return global_position
	skeleton.force_update_all_bone_transforms()
	return skeleton.global_transform * skeleton.get_bone_global_pose(chains[digit][3]).origin
