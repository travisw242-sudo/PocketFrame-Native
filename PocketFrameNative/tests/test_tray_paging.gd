extends SceneTree
const Device=preload("res://scripts/handheld.gd")
const Rack=preload("res://scripts/cartridge_rack.gd")
var checks := 0
var failures := 0
var rack: Node3D
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func touch(height: float, eligible: bool = true) -> void:
	rack.touch_tray([rack.tray.to_global(rack.tray_buttons[0]+Vector3(0,height,0))],[eligible])
func visible_count() -> int:
	var count := 0
	for card in rack.cards.values():
		if card.visible: count+=1
	return count
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var device := Device.new()
	world.add_child(device)
	rack=Rack.new()
	world.add_child(rack)
	rack.setup(device,Transform3D(Basis(Vector3.UP,.45),Vector3(0,1,-.4)))
	rack.set_process(false)
	# Virtual fixtures only: never create, remove or modify actual game files.
	for card in rack.cards.values(): card.queue_free()
	rack.cards.clear(); rack.library.entries.clear(); rack.homes.clear()
	for i in range(17):
		var id := "fixture-%02d"%i
		rack.library.register_game(id,"Test cartridge %d"%i,"C:/virtual-test-only/%s.cci"%id)
		var card=rack.library.spawn_cartridge(id)
		rack.add_child(card); rack.cards[id]=card
	rack._layout()
	check(rack.page_count()==3 and visible_count()==8,"Seventeen virtual games produce three correctly sized pages")
	check(rack.next_page_label.text=="NEXT PAGE" and rack.tray_buttons.size()==1,"Only a single page button, no recall control")
	var feedback_count := [0]
	rack.feedback.connect(func(_hand: int): feedback_count[0]+=1)
	touch(.04);touch(.003)
	check(rack.page==1 and visible_count()==8,"Direct fingertip press advances one page without controller buttons")
	check(rack.next_page_cap.position.y<0 and feedback_count[0]==1,"Press depresses cap and emits haptic feedback")
	for height in [.002,.009,.017,.004]: touch(height)
	check(rack.page==1 and feedback_count[0]==1,"Contact jitter and holding finger down do not repeat pages")
	touch(.04)
	check(is_zero_approx(rack.next_page_cap.position.y),"Lifting finger releases button")
	touch(-.025)
	check(rack.page==2 and visible_count()==1,"Fast swept fingertip press is detected and last page has one card")
	touch(.04);touch(.003)
	check(rack.page==0 and visible_count()==8,"Next page wraps to the first page")
	touch(.04);touch(.003,false)
	check(rack.page==0,"Ineligible or holding hand cannot operate tray button")
	touch(.04)
	var point: Vector3=rack.tray.to_global(rack.tray_buttons[0]+Vector3(0,.003,0))
	rack.touch_tray([point,point],[true,true])
	check(rack.page==1,"Two fingertips simultaneously press only once")
	# Changing pages never hides or teleports a card currently held by a user.
	var held_card: Node3D=rack.cards["fixture-08"]
	rack.held[0]=held_card
	var held_pose := held_card.global_transform
	rack.next_page()
	check(held_card.visible and held_card.global_transform.is_equal_approx(held_pose),"Held cartridge remains visible and unmoved while paging")
	rack.held[0]=null
	for id in rack.library.entries.keys():
		if id!="fixture-00":
			rack.library.entries.erase(id)
			rack.cards[id].hide()
	rack._layout()
	check(rack.page==0 and rack.next_page_label.text=="ALL GAMES","Single page clearly labelled instead of appearing broken")
	touch(.04);touch(.003)
	check(rack.page==0,"One-page library is safe to press")
	world.queue_free()
	print("TRAY PAGING: %d checks, %d failures" % [checks,failures])
	quit(failures)
