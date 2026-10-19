extends RefCounted
## Shared anatomical <-> OpenXR grip conversion. Model: fingers -Z, palm -Y.
## Grip: palm outward +X on left / -X on right; little-to-thumb direction -Z.
const PALM_CENTER := Vector3(0, -0.003, 0.008)
const TRIPOD_POINT := Vector3(-0.024, -0.035, -0.046)
const PEN_GRASP_Z := -0.010
const CARD_PINCH_POINT := Vector3(-0.023,-0.025,-0.060)
const CARD_GRASP := Vector3(0,0,-0.014)

static func card_in_hand(left: bool, size: float) -> Transform3D:
	var side := -1.0 if left else 1.0
	var point := CARD_PINCH_POINT
	if left: point.x=-point.x
	# Thin edge between opposed pads. Contacts point ahead of the fingers,
	# rather than leaving a broad face flat across the palm like the old pen pose.
	var axes := Basis(Vector3.UP*side,Vector3.RIGHT*side,Vector3.FORWARD)
	return Transform3D(axes.scaled(Vector3.ONE*size),point-axes*CARD_GRASP*size)

static func card_pad_target(card: Transform3D, thumb: bool) -> Vector3:
	var face := card*Vector3(0,(1 if thumb else -1)*0.0019,CARD_GRASP.z)
	return face+card.basis.y.normalized()*(1 if thumb else -1)*0.007

static func grip_transform(left: bool, pitch: float = 0, roll: float = 0, offset: float = 0) -> Transform3D:
	var side := -1.0 if left else 1.0
	var axes := Basis(Vector3.BACK * side, Vector3.RIGHT * side, Vector3.UP)
	var fit := Basis.from_euler(Vector3(deg_to_rad(clampf(pitch, -40, 40)), 0, deg_to_rad(clampf(roll, -40, 40)) * side))
	var basis := axes * fit
	return Transform3D(basis, -(basis * PALM_CENTER) + Vector3(0, offset, 0))

static func pen_in_hand(left: bool, angle: float, pen_scale: float) -> Transform3D:
	var point := TRIPOD_POINT
	var back := Vector3(-0.60, 0.35, 0.72).normalized()
	if left:
		point.x = -point.x
		back.x = -back.x
	# The shaft passes outside the palm, back over the thumb web. It no longer
	# originates at the palm center. The same pinch point is used by the hand.
	var basis := Basis.looking_at(-back, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(25 - clampf(angle, 0, 60)))
	return Transform3D(basis.scaled(Vector3.ONE * pen_scale), point - basis.z * PEN_GRASP_Z * pen_scale)

static func console_transform(console: Transform3D, left: bool) -> Transform3D:
	var side := -1.0 if left else 1.0
	var scale_size := console.basis.x.length()
	var orientation := console.basis.orthonormalized() * Basis(Vector3.BACK, deg_to_rad(-95 * side))
	# Physical palm clearance remains constant if the user resizes the device.
	var anchor := Vector3(side * (0.0792 + 0.027 / scale_size), -0.046 / scale_size, 0.015 / scale_size)
	return Transform3D(orientation, console * anchor)
