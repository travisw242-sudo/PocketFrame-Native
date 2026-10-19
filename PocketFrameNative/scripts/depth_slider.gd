extends RefCounted
## Direct fingertip drag in the moving lid's frame. No grip/trigger required.
var device: Node3D
var active_tip := -1
var just_started := false
var just_released := false
var anchor_z := 0.0
var anchor_level := 0.0
var last_point := Vector3.ZERO

func setup(console: Node3D) -> void:
	device = console

func active() -> bool:
	return active_tip >= 0

func hand_index() -> int:
	return active_tip / 2 if active() else -1

func reset() -> void:
	active_tip = -1
	just_started = false
	just_released = false

func step(_delta: float, tips: Array, eligible: Array) -> void:
	just_started = false
	just_released = false
	var points: Array[Vector3] = []
	for tip: Vector3 in tips:
		points.append(device.lid.to_local(tip))
	var radius := .0055 / device.global_basis.x.length()
	var cap: Vector3 = device.depth_slider.position
	if active():
		if active_tip >= points.size() or not eligible[active_tip]:
			active_tip = -1
		else:
			var p := points[active_tip]
			if absf(p.x-cap.x) > .006+radius*2 or absf(p.y-cap.y) > .006+radius*2 or p.y < -.002 or p.z < -.045 or p.z > -.007 or p.distance_to(last_point) > .045/device.global_basis.x.length():
				active_tip = -1
			else:
				var movement := p.z-anchor_z
				if absf(movement) > .0003/device.global_basis.x.length():
					var level := clampf(anchor_level-movement/.012,0,1)
					if level < .04: level=0
					if level > .98: level=1
					device.set_depth(level)
					anchor_z=p.z
					anchor_level=level
				last_point=p
		if not active(): just_released=true
	if not active() and not just_released:
		for i in range(points.size()):
			var p := points[i]
			if eligible[i] and p.y >= -.001 and absf(p.x-cap.x)<.002+radius and absf(p.y-cap.y)<.002+radius and absf(p.z-cap.z)<.002+radius:
				active_tip=i
				anchor_z=p.z
				anchor_level=device.depth_level
				last_point=p
				just_started=true
				break
