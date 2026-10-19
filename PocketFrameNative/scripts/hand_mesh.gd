extends RefCounted
## Original anatomical hand mesh, in meters. Two skinned surfaces, no assets
## borrowed from another game. Right-hand rest geometry is mirrored explicitly
## for the left hand, including winding and bone rests (no negative node scale).
const DIGITS := ["index", "middle", "ring", "pinky"]
const ROOTS := [Vector3(-0.024, 0, -0.027), Vector3(-0.006, 0.001, -0.031), Vector3(0.012, 0, -0.028), Vector3(0.028, -0.001, -0.022)]
const LENGTHS := [0.068, 0.077, 0.071, 0.056]
const RADII := [0.0081, 0.0086, 0.0079, 0.0067]
static var shared_skin: StandardMaterial3D
var rig: Skeleton3D
var mirror := 1.0
var bones: Dictionary = {}
var rest_global: Array[Transform3D] = []
var digit_data: Array[Dictionary] = []
var surface: SurfaceTool
var vertex_count := 0
var triangle_count := 0

func _reflect(transform: Transform3D) -> Transform3D:
	var m := Basis(Vector3(mirror, 0, 0), Vector3.UP, Vector3.BACK)
	return Transform3D(m * transform.basis * m, m * transform.origin)

func _bone(title: String, parent: int, rest: Transform3D) -> int:
	var index := rig.get_bone_count()
	rig.add_bone(title)
	if parent >= 0:
		rig.set_bone_parent(index, parent)
	rig.set_bone_rest(index, _reflect(rest))
	rest_global.append(rest if parent < 0 else rest_global[parent] * rest)
	bones[title] = index
	return index

func build(skeleton: Skeleton3D, left: bool) -> ArrayMesh:
	rig = skeleton
	mirror = -1 if left else 1
	_bone("wrist", -1, Transform3D.IDENTITY)
	for i in range(4):
		_digit_rig(DIGITS[i], Transform3D(Basis.IDENTITY, ROOTS[i]), LENGTHS[i], RADII[i])
	_digit_rig("thumb", Transform3D(Basis.from_euler(Vector3(0.10, 0.68, -0.35)), Vector3(-0.029, -0.003, 0.0)), 0.064, 0.0091)
	_begin()
	_palm()
	for digit in digit_data:
		_finger(digit)
	var mesh := surface.commit()
	if not shared_skin:
		shared_skin = StandardMaterial3D.new()
		shared_skin.vertex_color_use_as_albedo = true
		shared_skin.vertex_color_is_srgb = true
		shared_skin.roughness = 0.64
		shared_skin.metallic = 0
		var noise := FastNoiseLite.new()
		noise.seed = 3867
		noise.frequency = 0.18
		noise.fractal_octaves = 2
		var pores := NoiseTexture2D.new()
		pores.width = 256
		pores.height = 256
		pores.noise = noise
		pores.seamless = true
		pores.as_normal_map = true
		pores.bump_strength = 0.25
		shared_skin.normal_enabled = true
		shared_skin.normal_texture = pores
		shared_skin.normal_scale = 0.10
		shared_skin.uv1_triplanar = true
		shared_skin.uv1_scale = Vector3.ONE * 180
	mesh.surface_set_material(0, shared_skin)
	_begin()
	for digit in digit_data:
		_nail(digit)
	surface.generate_normals()
	mesh = surface.commit(mesh)
	var nail := StandardMaterial3D.new()
	nail.vertex_color_use_as_albedo = true
	nail.vertex_color_is_srgb = true
	nail.roughness = 0.36
	nail.metallic = 0
	mesh.surface_set_material(1, nail)
	return mesh

func _digit_rig(title: String, root: Transform3D, length: float, radius: float) -> void:
	var segments := Vector3(length * 0.46, length * 0.31, length * 0.23)
	if title == "thumb":
		segments = Vector3(length * 0.38, length * 0.34, length * 0.28)
	var first := _bone(title + "_mcp", 0, root)
	var second := _bone(title + "_pip", first, Transform3D(Basis.IDENTITY, Vector3(0, 0, -segments.x)))
	var third := _bone(title + "_dip", second, Transform3D(Basis.IDENTITY, Vector3(0, 0, -segments.y)))
	digit_data.append({"title": title, "length": length, "radius": radius, "segments": segments, "bones": [first, second, third], "root": root})

func _begin() -> void:
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	vertex_count = 0

func _vertex(pos: Vector3, color: Color, bone: int = 0, other: int = 0, influence: float = 0) -> int:
	surface.set_color(color)
	surface.set_bones(PackedInt32Array([bone, other, 0, 0]))
	surface.set_weights(PackedFloat32Array([1 - influence, influence, 0, 0]))
	surface.add_vertex(Vector3(pos.x * mirror, pos.y, pos.z))
	vertex_count += 1
	return vertex_count - 1

func _tri(a: int, b: int, c: int) -> void:
	surface.add_index(a)
	surface.add_index(b if mirror > 0 else c)
	surface.add_index(c if mirror > 0 else b)
	triangle_count += 1

func _bridge(first: Array[int], second: Array[int]) -> void:
	for i in range(first.size()):
		var next := (i + 1) % first.size()
		_tri(first[i], first[next], second[next])
		_tri(first[i], second[next], second[i])

func _skin(point: Vector3, palm_side: float, crease: float = 0) -> Color:
	# Warm knuckles, lighter palm, subtle small variation instead of plastic
	# uniform color. Geometry provides folds; no expensive per-frame noise.
	var base := Color("bd876b").lerp(Color("d8a68a"), clampf(palm_side, 0, 1) * 0.65)
	var grain := sin(point.x * 6100 + point.z * 4300) * sin(point.z * 3700 - point.y * 5100) * 0.012
	base = base.lightened(maxf(grain, 0)).darkened(maxf(-grain, 0) + crease * 0.12)
	return base

func _palm() -> void:
	var last: Array[int] = []
	for ring in range(33):
		var t := float(ring) / 32
		var z := lerpf(0.060, -0.032, t)
		var width := 0.0215 + 0.0158 * smoothstep(0.15, 0.72, t)
		width -= 0.002 * smoothstep(0.86, 1, t)
		var thick := lerpf(0.0095, 0.011, sin(t * PI * 0.8))
		var current: Array[int] = []
		for side in range(44):
			var angle := TAU * float(side) / 44
			var x := cos(angle) * width
			var y := signf(sin(angle)) * pow(absf(sin(angle)), 0.65) * thick
			# Thenar pad and hypothenar pad give a soft anatomical palm, while
			# dorsal metacarpals remain comparatively flat with knuckle ridges.
			if y < 0:
				y -= 0.005 * exp(-pow((x + 0.018) / 0.018, 2) - pow((z - 0.012) / 0.031, 2))
				y -= 0.002 * exp(-pow((x - 0.023) / 0.014, 2) - pow(z / 0.038, 2))
			else:
				for finger in range(4):
					y += 0.0030 * exp(-pow((x - ROOTS[finger].x) / 0.006, 2) - pow((z + 0.025) / 0.014, 2))
					var tendon_x: float = ROOTS[finger].x * lerpf(0.55, 1.0, clampf((0.045 - z) / 0.07, 0, 1))
					y += 0.00065 * exp(-pow((x - tendon_x) / 0.002, 2) - pow((z - 0.005) / 0.032, 2))
			var front_z := z + maxf(0, t - 0.75) * (absf(x) / width) * 0.023
			var crease := 0.0
			if y < -0.004:
				crease = exp(-pow((z + 0.008 + x * 0.22) / 0.0018, 2))
				crease += exp(-pow((z - 0.013 + x * 0.42) / 0.0015, 2)) * 0.65
				# Thumb life-line and paired wrist folds are shallow depressions,
				# not dark painted stripes. Static geometry adds no frame-time work.
				crease += exp(-pow((x + 0.012 + pow((z - 0.008) * 3, 2)) / 0.0014, 2)) * 0.55
				crease += exp(-pow((z - 0.041 - x * 0.10) / 0.0013, 2)) * 0.65
				crease += exp(-pow((z - 0.048 - x * 0.08) / 0.0012, 2)) * 0.45
				y += minf(crease, 1.5) * 0.00035
			var p := Vector3(x, y, front_z)
			var influence := 0.0
			var bone := 0
			if z < -0.012:
				var nearest := 0
				for finger in range(1, 4):
					if absf(x - ROOTS[finger].x) < absf(x - ROOTS[nearest].x):
						nearest = finger
				bone = bones[DIGITS[nearest] + "_mcp"]
				influence = 0.35 * smoothstep(-0.012, -0.032, z)
			current.append(_vertex(p, _skin(p, maxf(0, -sin(angle)), crease), 0, bone, influence))
		if not last.is_empty():
			_bridge(last, current)
		else:
			var center := _vertex(Vector3(0, 0, z), _skin(Vector3.ZERO, 0.3))
			for i in range(current.size()):
				_tri(center, current[(i + 1) % current.size()], current[i])
		last = current
	# Front cap sits inside the finger roots, hiding the base without sockets.
	var center := _vertex(Vector3(0, 0, -0.028), _skin(Vector3.ZERO, 0.5))
	for i in range(last.size()):
		_tri(center, last[i], last[(i + 1) % last.size()])

func _finger(digit: Dictionary) -> void:
	var length: float = digit.length
	var radius: float = digit.radius
	var segments: Vector3 = digit.segments
	var ids: Array = digit.bones
	var root: Transform3D = digit.root
	var last: Array[int] = []
	for ring in range(47):
		var distance := lerpf(-0.009, length, float(ring) / 46)
		var t := clampf(distance / length, 0, 1)
		var taper := lerpf(1.0, 0.73, t)
		var first_fold := exp(-pow((distance - segments.x) / 0.0015, 2))
		var second_fold := exp(-pow((distance - segments.x - segments.y) / 0.0013, 2))
		var knuckle := exp(-pow((distance - segments.x) / 0.004, 2)) * 0.08
		knuckle += exp(-pow((distance - segments.x - segments.y) / 0.003, 2)) * 0.04
		if distance > length - 0.007:
			taper *= sqrt(maxf(0.0001, 1 - pow((distance - length + 0.007) / 0.007, 2)))
		var r := radius * (taper + knuckle)
		var bone: int = ids[0]
		var other: int = 0
		var blend := 1 - smoothstep(-0.009, 0.004, distance)
		if distance > segments.x - 0.005:
			bone = ids[0]
			other = ids[1]
			blend = smoothstep(segments.x - 0.005, segments.x + 0.005, distance)
		if distance > segments.x + segments.y - 0.004:
			bone = ids[1]
			other = ids[2]
			blend = smoothstep(segments.x + segments.y - 0.004, segments.x + segments.y + 0.004, distance)
		var current: Array[int] = []
		for side in range(24):
			var angle := TAU * float(side) / 24
			var pad := 0.87 if sin(angle) > 0 else 1.0
			var wrinkles := 0.0
			for joint in [segments.x, segments.x + segments.y]:
				for offset in [-0.0022, 0.0, 0.0022]:
					wrinkles += exp(-pow((distance - joint - offset - cos(angle) * 0.0006) / 0.00065, 2))
			var indentation := (first_fold + second_fold) * (0.00025 if sin(angle) > 0 else 0.0004) + wrinkles * 0.0002
			var local := Vector3(cos(angle) * r, sin(angle) * (r * pad - indentation), -distance)
			var p := root * local
			var color := _skin(p, maxf(0, -sin(angle)), (first_fold + second_fold) * 0.65 + wrinkles * 0.25)
			color = color.lerp(Color("b57867"), maxf(0, sin(angle)) * (first_fold + second_fold) * 0.18)
			current.append(_vertex(p, color, bone, other, blend))
		if not last.is_empty():
			_bridge(last, current)
		last = current
	# Commit normals once for the entire skin surface after the final digit.
	if digit.title == "thumb":
		surface.generate_normals()

func _nail(digit: Dictionary) -> void:
	var ids: Array = digit.bones
	var distal: float = digit.segments.z
	var radius: float = digit.radius
	var transform: Transform3D = rest_global[ids[2]]
	var last: Array[int] = []
	for ring in range(6):
		var radial := maxf(0.001, float(ring) / 5)
		var current: Array[int] = []
		for i in range(28):
			var angle := TAU * float(i) / 28
			var x := cos(angle) * radial * radius * 0.65
			var z := -distal * 0.55 + sin(angle) * radial * distal * 0.38
			var taper := lerpf(0.83, 0.68, clampf(-z / distal, 0, 1))
			var y := radius * taper * sqrt(maxf(0.2, 1 - pow(x / (radius * 0.9), 2))) + 0.0004
			var color := Color("d3aca0").lerp(Color("e4d0bc"), smoothstep(0.78, 0.90, -z / distal))
			var moon := exp(-pow((z + distal * 0.28) / (distal * 0.12), 2) - pow(x / (radius * 0.43), 2))
			color = color.lerp(Color("ead8ca"), moon * 0.38)
			color = color.lerp(Color("aa786d"), smoothstep(0.80, 1, radial) * 0.38)
			y -= smoothstep(0.75, 1, radial) * 0.0003
			current.append(_vertex(transform * Vector3(x, y, z), color, ids[2]))
		if not last.is_empty():
			# Nail faces upward; reverse the loft's winding for a dorsal patch.
			for i in range(current.size()):
				var next := (i + 1) % current.size()
				_tri(last[i], current[next], last[next])
				_tri(last[i], current[i], current[next])
		last = current
