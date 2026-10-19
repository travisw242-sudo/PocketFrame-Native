extends RefCounted
## Lightweight visual-hand contact, not a force applied to the held console.
## Palm spheres and articulated finger capsules collide against shell/lid and
## raised controls. No triangle-mesh physics, no change to the hold solver.
const BASE := AABB(Vector3(-0.079, -0.0075, -0.047), Vector3(0.158, 0.0155, 0.094))
const LID := AABB(Vector3(-0.0785, -0.0035, -0.088), Vector3(0.157, 0.0078, 0.088))

static func box_distance(point: Vector3, box: AABB) -> float:
	var q := (point - box.get_center()).abs() - box.size * 0.5
	return q.max(Vector3.ZERO).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0)

static func sphere_push(point: Vector3, radius: float, frame: Transform3D, box: AABB) -> Vector3:
	var size := frame.basis.x.length()
	var p := frame.affine_inverse() * point
	var r := radius / size
	var nearest := p.clamp(box.position, box.end)
	var difference := p - nearest
	var distance := difference.length()
	if distance >= r: return Vector3.ZERO
	if distance > 0.000001:
		return frame.basis * (difference / distance * (r - distance))
	var q := p - box.get_center()
	var depth := box.size * 0.5 - q.abs()
	var axis := 0 if depth.x <= depth.y and depth.x <= depth.z else 1 if depth.y <= depth.z else 2
	var push := Vector3.ZERO
	push[axis] = (depth[axis] + r) * (1 if q[axis] >= 0 else -1)
	return frame.basis * push

static func penetration(point: Vector3, radius: float, console: Node3D) -> float:
	if not is_instance_valid(console): return 0
	var frame: Transform3D = console.global_transform
	var size := frame.basis.x.length()
	var p := frame.affine_inverse() * point
	var depth := radius - box_distance(p, BASE) * size
	depth = maxf(depth, radius - box_distance(console.lid.to_local(point), LID) * size)
	# A conservative smooth envelope for the raised circle pad / button cluster.
	for control in [Vector3(-0.059, 0.010, -0.020), Vector3(0.058, 0.010, -0.007)]:
		var d: Vector3 = p - control
		var radial := Vector2(d.x, d.z).length() - (0.011 if control.x < 0 else 0.015)
		var vertical := absf(d.y) - 0.002
		var cylinder := Vector2(maxf(radial, 0), maxf(vertical, 0)).length() + minf(maxf(radial, vertical), 0)
		depth = maxf(depth, radius - cylinder * size)
	return maxf(depth, 0)

static func capsule_depth(a: Vector3, b: Vector3, radius: float, console: Node3D) -> float:
	var depth := 0.0
	var samples := maxi(2, ceili(a.distance_to(b) / maxf(radius, 0.003)))
	for i in range(samples + 1):
		depth = maxf(depth, penetration(a.lerp(b, float(i) / samples), radius, console))
	return depth
