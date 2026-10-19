extends Node3D
## Free-hands-only comfort locomotion. No continuous movement and no emulator input changes.
const G=preload("res://scripts/geometry.gd")
var enabled := true
var aiming := false
var turn_armed := false
var teleport_armed := false
var line := MeshInstance3D.new()
var marker: MeshInstance3D
var valid_target := false
var destination := Vector3.ZERO
var path := PackedVector3Array()
const FLOOR_Y := .035
# Furniture volumes, in bedroom coordinates. Expanded landing clearance below
# prevents destinations that would put the user's body inside furniture.
const OBSTACLES := [
	AABB(Vector3(-2.05,0,-2.4),Vector3(1.4,.9,2.3)),
	AABB(Vector3(-.14,0,-2.46),Vector3(1.65,.80,.88)),
	AABB(Vector3(.075,.8,-2.267),Vector3(.45,.40,.484)), # Computer, not an invisible wall over the entire desk.
	AABB(Vector3(-.24,0,-1.42),Vector3(.52,1.05,.60)),
	AABB(Vector3(-.65,0,-2.4),Vector3(.5,1.1,.65)),
	AABB(Vector3(1.50,0,-1.05),Vector3(.6,1.9,1.0)),
	AABB(Vector3(1.35,0,.48),Vector3(.75,1.15,.95)),
	AABB(Vector3(-2.06,0,.36),Vector3(.52,1.4,.6)),
]

func _ready() -> void:
	name="ComfortLocomotion"
	add_child(line)
	var mat := G.material(Color("58cbb9"))
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override=mat
	var ring := TorusMesh.new()
	ring.inner_radius=.16; ring.outer_radius=.18; ring.rings=24; ring.ring_segments=8
	marker=G.instance(self,ring,mat,Vector3.ZERO,"TeleportDestination")
	marker.hide()

static func landing_clear(point: Vector3) -> bool:
	if not Rect2(-1.9,-2.28,3.8,3.94).has_point(Vector2(point.x,point.z)): return false
	for obstacle in OBSTACLES:
		if obstacle.grow(.20).has_point(Vector3(point.x,.10,point.z)): return false
	return true

func trace(pose: Transform3D) -> bool:
	path.clear()
	var start := pose.origin
	var velocity := -pose.basis.z.normalized()*4.2
	var previous := start
	path.append(start)
	for i in range(1,61):
		var t := i*.025
		var point := start+velocity*t+Vector3(0,-4.9*t*t,0)
		if point.y<=FLOOR_Y:
			var weight := clampf((previous.y-FLOOR_Y)/maxf(.0001,previous.y-point.y),0,1)
			destination=previous.lerp(point,weight)
			path.append(destination)
			return landing_clear(destination)
		path.append(point)
		for obstacle in OBSTACLES:
			if obstacle.grow(.015).intersects_segment(previous,point)!=null: return false
		if absf(point.x)>2.1 or point.z < -2.5 or point.z>1.9: return false
		previous=point
	return false

static func turned(origin: Transform3D, head: Vector3, radians: float) -> Transform3D:
	var rotation := Basis(Vector3.UP,radians)
	return Transform3D(rotation*origin.basis,head+rotation*(origin.origin-head))

static func translated_to(origin: Transform3D, head: Vector3, target: Vector3) -> Transform3D:
	# Preserve physical head height and the tracking floor, never change user's scale.
	origin.origin+=Vector3(target.x-head.x,0,target.z-head.z)
	return origin

func step(allowed: bool, left_stick: Vector2, right_stick: Vector2, pose: Transform3D, rig: Node3D, head: Node3D, aim_available: bool = true, turn_available: bool = true) -> void:
	if not allowed or not enabled:
		aiming=false; teleport_armed=false; turn_armed=false
		line.hide(); marker.hide()
		return
	if not aim_available: aiming=false; teleport_armed=false
	if not turn_available: turn_armed=false
	if turn_available and absf(right_stick.x)<.30: turn_armed=true
	if turn_available and turn_armed and absf(right_stick.x)>.65:
		rig.global_transform=turned(rig.global_transform,head.global_position,-signf(right_stick.x)*PI/6)
		turn_armed=false
		# Aim pose was sampled before turning. Cancel this frame's teleport.
		aiming=false; teleport_armed=false
	if aim_available and left_stick.length()<.30:
		if aiming:
			if trace(pose): rig.global_transform=translated_to(rig.global_transform,head.global_position,destination)
		aiming=false; teleport_armed=true
	elif aim_available and teleport_armed and left_stick.y>.55 and absf(left_stick.x)<.7:
		aiming=true
	elif aiming and (left_stick.y<-.5 or absf(left_stick.x)>.8):
		aiming=false # Sideways/backward cancels; center releases to travel.
	# Keep aiming through intermediate stick values during a natural, gradual
	# release. Cancelling at y<.4 used to discard the gesture before center.
	if aiming: valid_target=trace(pose)
	line.visible=aiming
	marker.visible=aiming and valid_target
	if aiming:
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in path: mesh.surface_add_vertex(point)
		mesh.surface_end()
		line.mesh=mesh
		marker.position=destination
		line.material_override.albedo_color=Color("58cbb9") if valid_target else Color("d47d68")
