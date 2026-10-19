class_name PFHoldSolver
extends RefCounted
## Device axes: +X right, +Y surface normal, +Z toward the player.
## The held state latches. Hand separation does not silently drop the object.
enum State { DOCKED, CANDIDATE, HELD }
var state: State = State.DOCKED
var dwell := 0.0
var tracking_lost := 0.0
var pickup_distance := 0.23
var min_distance := 0.075
var dwell_seconds := 0.45
var require_grips := true
var last_basis := Basis.IDENTITY

func step(delta: float, left: Transform3D, right: Transform3D, valid: bool, grips: bool, release: bool) -> Dictionary:
	var previous := state
	if release:
		reset()
		return {"state": state, "changed": previous != state, "valid": false}
	if not valid:
		tracking_lost += delta
		dwell = 0.0
		if state == State.CANDIDATE:
			state = State.DOCKED
		return {"state": state, "changed": previous != state, "valid": false}
	tracking_lost = 0.0
	var span := right.origin - left.origin
	var distance := span.length()
	# Controller orientations vary by runtime and hand posture. Spacing plus an
	# explicit squeeze is the reliable pickup gate.
	var candidate := distance >= min_distance and distance <= pickup_distance
	if state != State.HELD:
		if candidate and (grips or not require_grips):
			state = State.CANDIDATE
			dwell += delta
			if dwell >= dwell_seconds:
				state = State.HELD
		else:
			state = State.DOCKED
			dwell = 0.0
	var basis := solve_basis(left, right, last_basis)
	if distance >= min_distance:
		last_basis = basis
	return {"state": state, "changed": previous != state, "valid": true,
		"target": Transform3D(basis, (left.origin + right.origin) * 0.5),
		"progress": clampf(dwell / dwell_seconds, 0, 1)}

static func solve_basis(left: Transform3D, right: Transform3D, fallback: Basis) -> Basis:
	var span := right.origin - left.origin
	if span.length() < 0.075:
		return fallback
	var x := span.normalized()
	var up := left.basis.y + right.basis.y
	var y := up - x * up.dot(x)
	if y.length_squared() < 0.001:
		return fallback
	y = y.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, z.cross(x).normalized(), z).orthonormalized()

func reset() -> void:
	state = State.DOCKED
	dwell = 0.0
	tracking_lost = 0.0
