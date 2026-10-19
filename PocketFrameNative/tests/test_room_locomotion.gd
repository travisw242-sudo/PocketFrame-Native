extends SceneTree
const Nav=preload("res://scripts/room_locomotion.gd")
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	check(Nav.landing_clear(Vector3(.8,0,-1.22)),"Desk spawn has body clearance")
	check(Nav.landing_clear(Vector3(0,0,0)),"Open floor allows teleport")
	for point in [Vector3(-1.3,0,-1),Vector3(.7,0,-2),Vector3(1.8,0,-.6),Vector3(1.7,0,.9),Vector3(2.1,0,0),Vector3(0,0,2)]:
		check(not Nav.landing_clear(point),"Furniture/walls excluded: "+str(point))
	var rig := Node3D.new()
	root.add_child(rig)
	var head := Node3D.new()
	rig.add_child(head); head.position=Vector3(.3,1.65,.2)
	var pivot := head.global_position
	rig.global_transform=Nav.turned(rig.global_transform,pivot,PI/6)
	check(head.global_position.distance_to(pivot)<.0001,"Snap turn pivots at head without orbiting")
	rig.global_transform=Nav.translated_to(rig.global_transform,head.global_position,Vector3(.8,0,-1.22))
	check(head.global_position.distance_to(Vector3(.8,1.65,-1.22))<.0001,"Teleport preserves physical eye height")
	var nav := Nav.new()
	root.add_child(nav)
	var pose := Transform3D(Basis.from_euler(Vector3(-.6,0,0)),Vector3(0,1.2,1.1))
	check(nav.trace(pose),"Downward ray lands on open floor")
	var target := nav.destination
	nav.step(true,Vector2.ZERO,Vector2.ZERO,pose,rig,head)
	nav.step(true,Vector2(0,1),Vector2.ZERO,pose,rig,head)
	check(nav.aiming and nav.marker.visible,"Forward stick previews arc and destination")
	nav.step(true,Vector2.ZERO,Vector2.ZERO,pose,rig,head)
	check(Vector2(head.global_position.x,head.global_position.z).distance_to(Vector2(target.x,target.z))<.001,"Release commits valid teleport")
	nav.step(true,Vector2(0,1),Vector2.ZERO,pose,rig,head)
	var before := rig.global_transform
	nav.step(false,Vector2.ZERO,Vector2(1,0),pose,rig,head)
	check(not nav.aiming and not nav.marker.visible and rig.global_transform.is_equal_approx(before),"Holding/tool/AR/tracking block cancels without movement")
	nav.step(true,Vector2(0,1),Vector2(1,0),pose,rig,head)
	check(not nav.aiming and rig.global_transform.is_equal_approx(before),"Controls must return to neutral after block")
	nav.step(true,Vector2.ZERO,Vector2.ZERO,pose,rig,head)
	nav.step(true,Vector2.ZERO,Vector2(1,0),pose,rig,head)
	var first_turn := rig.global_transform
	nav.step(true,Vector2.ZERO,Vector2(1,0),pose,rig,head)
	check(not first_turn.is_equal_approx(before) and rig.global_transform.is_equal_approx(first_turn),"One 30 degree turn per stick deflection")
	check(not nav.trace(Transform3D(Basis.IDENTITY,Vector3(.7,1,-1.2))),"Arc into desk is blocked")
	nav.step(true,Vector2.ZERO,Vector2.ZERO,pose,rig,head)
	nav.step(true,Vector2(0,.9),Vector2.ZERO,pose,rig,head)
	for value in [.7,.5,.39,.31]:
		nav.step(true,Vector2(0,value),Vector2.ZERO,pose,rig,head)
		check(nav.aiming,"Gradual release retains aim at "+str(value))
	check(nav.valid_target,"Gradual release still has a valid target")
	var release_target := nav.destination
	nav.step(true,Vector2(0,.20),Vector2.ZERO,pose,rig,head)
	check(not nav.aiming and Vector2(head.global_position.x,head.global_position.z).distance_to(Vector2(release_target.x,release_target.z))<.001,"Gradual release commits at center deadzone")
	nav.step(true,Vector2.ZERO,Vector2.ZERO,pose,rig,head,false,true)
	var before_independent_turn := rig.global_transform
	nav.step(true,Vector2.ZERO,Vector2(1,0),pose,rig,head,false,true)
	check(not rig.global_transform.is_equal_approx(before_independent_turn),"Snap turn works without left aim tracking")
	nav.step(true,Vector2.ZERO,Vector2.ZERO,pose,rig,head,true,false)
	nav.step(true,Vector2(0,1),Vector2.ZERO,pose,rig,head,true,false)
	check(nav.aiming,"Teleport works without right controller tracking")
	nav.step(true,Vector2(0,-.8),Vector2.ZERO,pose,rig,head,true,false)
	check(not nav.aiming,"Deliberate backward stick still cancels teleport")
	var above_desk := Transform3D(Basis.from_euler(Vector3(-.2,PI,0)),Vector3(.8,1.0,-1.85))
	check(nav.trace(above_desk),"Aim above clear desktop is not blocked by an oversized invisible desk volume")
	nav.queue_free(); rig.queue_free()
	print("ROOM LOCOMOTION: %d checks, %d failures" % [checks,failures])
	quit(failures)
