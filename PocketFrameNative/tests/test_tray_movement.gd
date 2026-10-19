extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var device=preload("res://scripts/handheld.gd").new()
	world.add_child(device)
	var rack=preload("res://scripts/cartridge_rack.gd").new()
	world.add_child(rack)
	rack.setup(device,Transform3D(Basis.IDENTITY,Vector3(0,1,-.4)))
	rack.set_process(false)
	for card in rack.cards.values(): card.queue_free()
	rack.cards.clear();rack.library.entries.clear();rack.homes.clear()
	rack.library.register_game("fixture","Virtual test","C:/virtual-fixture/test.cci")
	var card=rack.library.spawn_cartridge("fixture")
	rack.add_child(card);rack.cards.fixture=card;rack._layout()
	var hands := [Transform3D(Basis.IDENTITY,rack.tray.to_global(Vector3(.127,0,0))),Transform3D.IDENTITY]
	var tips := [[],[]]
	rack.reserve(hands,[true,true],[false,false],[true,true],tips)
	var reserved: Array=rack.reserve(hands,[true,true],[true,false],[true,true],tips)
	check(rack.tray_hand==0 and reserved[0] and not rack.held_by(0),"Rim grip reserves hand without pretending a card is held")
	var relative: Transform3D=rack.tray.global_transform.affine_inverse()*card.global_transform
	hands[0]=Transform3D(Basis(Vector3.UP,.6),hands[0].origin+Vector3(.2,.18,.15))
	rack.move_hands(.016,hands)
	check(rack.tray.global_transform.is_equal_approx(hands[0]*rack.tray_offset),"Tray follows translation and rotation with no snap")
	check((rack.tray.global_transform.affine_inverse()*card.global_transform).is_equal_approx(relative),"Cards travel on the tray")
	hands[1]=Transform3D(Basis.IDENTITY,rack.tray.to_global(Vector3(-.127,0,0)))
	rack.reserve(hands,[true,true],[true,true],[true,true],tips)
	check(rack.tray_hand==0 and not rack.busy_by(1),"Second hand cannot steal held tray")
	var placed: Transform3D=rack.tray.global_transform
	rack.reserve(hands,[true,true],[false,false],[true,true],tips)
	hands[0].origin+=Vector3(1,1,1)
	rack.move_hands(.1,hands);rack._process(1)
	check(rack.tray_hand==-1 and rack.tray.global_transform.is_equal_approx(placed),"Release freezes world pose without falling")
	rack.recall(Transform3D.IDENTITY)
	check(rack.tray.global_transform.is_equal_approx(placed),"Console docking does not recall a placed tray")
	rack.recall(Transform3D.IDENTITY,true)
	check(not rack.tray_placed and not rack.tray.global_transform.is_equal_approx(placed),"Room change can reset tray deliberately")
	hands[0]=Transform3D(Basis.IDENTITY,rack.tray.to_global(Vector3(.127,0,0)))
	rack.reserve(hands,[true,true],[false,false],[true,true],tips)
	rack.reserve(hands,[true,true],[true,false],[true,true],tips)
	placed=rack.tray.global_transform
	rack.reserve(hands,[false,true],[true,false],[true,true],tips)
	check(rack.tray_hand==-1 and rack.tray.global_transform.is_equal_approx(placed),"Tracking loss releases safely in place")
	check(not rack._near_tray(Transform3D(Basis.IDENTITY,rack.tray.to_global(rack.tray_buttons[0])),[]),"Page button is not a tray grab target")
	world.queue_free()
	print("TRAY MOVEMENT: %d checks, %d failures"%[checks,failures])
	quit(failures)
