extends RefCounted
## Finger contact only. Captures the physical cap, not an arbitrary point on
## the rail; relative dragging avoids a volume jump on the first touch.
var device: Node3D
var active_tip := -1
var hovering := false
var just_started := false
var just_released := false
var hit_limit := false
var previous_points: Array = []
var previous_eligible: Array = []
var anchor_z := 0.0
var anchor_level := 0.0
var last_point := Vector3.ZERO
var feedback_time := 0.0

func setup(console: Node3D) -> void:
	device = console

func reset() -> void:
	active_tip = -1
	hovering = false
	just_started = false
	just_released = false
	hit_limit = false
	previous_points.clear()
	previous_eligible.clear()
	feedback_time = 0
	device.show_volume_feedback(false, false)

func active() -> bool:
	return active_tip >= 0

func hand_index() -> int:
	return active_tip / 2 if active_tip >= 0 else -1

func _hit_box(radius: float) -> AABB:
	return AABB(device.volume_slider.position - Vector3(0.002, 0.0021, 0.0035) - Vector3.ONE * radius, Vector3(0.004, 0.0042, 0.007) + Vector3.ONE * radius * 2)

func step(delta: float, tips: Array, eligible: Array) -> void:
	just_started = false
	just_released = false
	hit_limit = false
	hovering = false
	feedback_time = maxf(0, feedback_time - delta)
	var size: float = device.global_basis.x.length()
	var radius := 0.0055 / size
	var points: Array[Vector3] = []
	for tip: Vector3 in tips:
		points.append(device.to_local(tip))
	if active():
		if active_tip >= points.size() or not eligible[active_tip]:
			active_tip = -1
		else:
			var p := points[active_tip]
			var knob: Vector3 = device.volume_slider.position
			# Release when lifted away, passed through the shell, or tracking jumps.
			if p.x > -0.079 or absf(p.x - knob.x) > 0.004 + radius * 2 or absf(p.y - knob.y) > 0.004 + radius * 2 or p.z < device.VOLUME_MAX_Z - 0.012 - radius or p.z > device.VOLUME_MIN_Z + 0.012 + radius or p.distance_to(last_point) > 0.045 / size:
				active_tip = -1
			else:
				var movement := p.z - anchor_z
				if absf(movement) >= 0.00035 / size:
					var before: float = device.volume_level
					var next := clampf(anchor_level - movement / device.VOLUME_TRAVEL, 0, 1)
					if next < 0.008:
						next = 0
					elif next > 0.992:
						next = 1
					device.set_volume(next)
					hit_limit = (next <= 0 and before > 0) or (next >= 1 and before < 1)
					anchor_level = next
					anchor_z = p.z
				last_point = p
		if not active():
			just_released = true
			feedback_time = 0.7
	if not active() and not just_released:
		for i in range(points.size()):
			if not eligible[i] or points[i].x > -0.079:
				continue
			var box := _hit_box(radius)
			if box.grow(0.005 / size).has_point(points[i]):
				hovering = true
			var contact := box.has_point(points[i])
			# A swept touch prevents a fast fingertip brushing straight through
			# the small cap, but tracking reacquisition never creates a sweep.
			if not contact and previous_points.size() == points.size() and previous_eligible[i]:
				var previous: Vector3 = previous_points[i]
				if previous.x <= -0.079 and previous.distance_to(points[i]) <= 0.045 / size:
					contact = box.intersects_segment(previous, points[i]) != null
			if contact and box.grow(0.004 / size).has_point(points[i]):
				active_tip = i
				anchor_z = points[i].z
				anchor_level = device.volume_level
				last_point = points[i]
				just_started = true
				break
	previous_points = points
	previous_eligible = eligible.duplicate()
	device.show_volume_feedback(active() or hovering or feedback_time > 0, active())
