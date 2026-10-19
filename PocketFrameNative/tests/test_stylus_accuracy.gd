extends SceneTree
const Device = preload("res://scripts/handheld.gd")
const Motion = preload("res://scripts/stylus_motion.gd")
var failures := 0
var checks := 0

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var device := Device.new()
	world.add_child(device)
	var motion := Motion.new()
	motion.setup(device, world)
	for scale_size in [0.8, 1.0, 1.6, 2.0]:
		device.global_transform = Transform3D(Basis.from_euler(Vector3(.3,.5,-.2)).scaled(Vector3.ONE*scale_size), Vector3(.3,1.2,-.4))
		var screen: Transform3D = device.bottom_surface.global_transform
		for uv in [Vector2(.02,.02), Vector2(.98,.02), Vector2(.5,.5), Vector2(.02,.98), Vector2(.98,.98)]:
			var local := Vector3((uv.x-.5)*device.BOTTOM_SIZE.x, .0002, (uv.y-.5)*device.BOTTOM_SIZE.y)
			var tip := screen*local
			check(device.stylus_touch(tip,tip).distance_to(uv)<.0001, "Exact LCD UV, corners and center at scale %s" % scale_size)
			local.y=.004
			tip=screen*local
			check(device.stylus_touch(tip,tip).x<0, "Hover does not tap")
			local.y=.003
			tip=screen*local
			check(device.stylus_touch(tip,tip).x<0 and device.stylus_touch(tip,tip,true).distance_to(uv)<.0001, "Small tracking lift retains drag, cannot start a tap")
			local.y=.004
			tip=screen*local
			check(device.stylus_touch(tip,tip,true).x<0, "Deliberate lift releases")
		# At common writing angles the collision-limited visible nib must still
		# activate without pressing the trigger or allowing shell penetration.
		for angle in [-90.0, -70.0, -45.0, -25.0, 0.0]:
			var basis := Basis(Vector3.RIGHT, deg_to_rad(angle))
			var start: Transform3D = device.global_transform * Transform3D(basis,Vector3(0,.06,.004))
			var target := start
			target.origin -= device.global_basis.y*.07
			var actual: Transform3D = motion.move_pen(start,target,device.global_transform)
			var tip := actual*Vector3(0,0,-.029)
			check(device.stylus_touch(tip,tip).x>=0, "Collision nib responds at %s degrees, scale %s" % [angle,scale_size])
			check(motion._contact_push(actual,device.global_transform).length()<.00002, "Contact does not penetrate shell")
	# Near-surface drags use the latest point, not the old plane intersection.
	device.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,1,0))
	var a: Vector3=device.bottom_surface.to_global(Vector3(-.01,.001,0))
	var b: Vector3=device.bottom_surface.to_global(Vector3(.01,-.0002,0))
	check(absf(device.stylus_touch(b,a,true).x-(.5+.01/device.BOTTOM_SIZE.x))<.0001, "Drag has no swept-crossing coordinate lag")
	b=device.bottom_surface.to_global(Vector3(.05,0,0))
	check(device.stylus_touch(b,a,true).x<0,"Leaving LCD releases, no sticky edge")
	print("STYLUS ACCURACY: %d checks, %d failures" % [checks,failures])
	quit(failures)
