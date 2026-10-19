extends SceneTree
const Device=preload("res://scripts/handheld.gd")
const Rack=preload("res://scripts/cartridge_rack.gd")
const Library=preload("res://scripts/cartridge_library.gd")
const Clicks=preload("res://scripts/cartridge_clicks.gd")
var checks:=0
var failures:=0
func check(ok: bool,title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var world:=Node3D.new()
	root.add_child(world)
	var device:=Device.new()
	world.add_child(device)
	device.position.y=1
	var rack:=Rack.new()
	world.add_child(rack)
	rack.setup(device,device.global_transform)
	rack.set_process(false)
	var expected:=0
	for file in DirAccess.open("res://games").get_files():
		if file.get_extension().to_lower() in Library.Metadata.FORMATS: expected+=1
	check(rack.cards.size()==expected,"Exactly one card per detected supported game")
	check(expected>0,"Real games available for read-only metadata check")
	for entry in rack.library.entries.values():
		print("CARTRIDGE METADATA: ",entry.display_name," · ",entry.art_source)
		check(entry.icon!=null,"Embedded art extracted from actual local CCI")
		if entry.icon: check(entry.icon.get_width()==48 and entry.icon.get_height()==48,"SMDH icon is decoded at native 48x48")
	var paths:=[]
	for entry in rack.library.entries.values(): paths.append(entry.content_path)
	var card: Node3D=rack.cards.values()[0]
	check(card.get_node("KeyTab")!=null,"White card includes keyed corner tab")
	check(card.get_node("CartridgeLabel").rotation==Vector3.ZERO,"Label lies flat on card face")
	var size: Vector3=card.get_node("GameCard").get_aabb().size
	check(absf(size.y-.0038)<.00001 and absf(size.z-.033)<.00001,"Real-scale card thickness and length")
	var events: Array=[]
	device.cartridge_slot.cartridge_inserted.connect(func(c): events.append("load:"+c.game_id))
	device.cartridge_slot.cartridge_ejected.connect(func(_c): events.append("stop"))
	check(rack.mount_path(paths[0]),"Selected launch cartridge mounts physically")
	check(events.size()==1 and card.inserted,"Insertion requests exactly one game load")
	check(not rack.mount_path(paths[0]),"Latched slot rejects duplicate load")
	check(card.get_parent()==device.cartridge_slot,"Inserted card follows console")
	var before: Vector3=card.global_position
	device.position.x+=.12
	check(absf(card.global_position.x-before.x-.12)<.0001,"Console motion carries inserted card")
	var hands: Array=[Transform3D(Basis.IDENTITY,card.global_position),Transform3D.IDENTITY]
	rack.reserve(hands,[true,true],[false,false],[true,true],[[],[]])
	rack.reserve(hands,[true,true],[true,false],[true,true],[[],[]])
	check(not rack.held_by(0),"Flush latched card cannot be pulled out before pressing")
	var far: Vector3=device.cartridge_slot.to_global(Vector3(0,0,-.1))
	rack.touch_eject([far],[true])
	var start: Vector3=device.cartridge_slot.to_global(Vector3(0,0,-.008))
	rack.touch_eject([start],[false])
	check(rack.mode=="latched","Ineligible holder cannot eject")
	rack.touch_eject([start],[true])
	check(rack.mode=="latched","Initial fingertip contact does not eject")
	rack.touch_eject([device.cartridge_slot.to_global(Vector3(0,0,-.0055))],[true])
	check(rack.mode=="popping" and events==["load:"+card.game_id,"stop"],"Push stroke unlatches and stops once")
	rack._process(.3)
	check(rack.mode=="popped" and absf(card.position.z-rack.POP_Z)<.0001,"Spring leaves exposed grabbable edge")
	check(not card.inserted,"Ejected card no longer counts as loaded")
	hands[0].origin=card.global_position
	rack.reserve(hands,[true,true],[false,false],[true,true],[[],[]])
	rack.reserve(hands,[true,true],[true,false],[true,true],[[],[]])
	check(rack.held_by(0) and rack.seated==null,"Grip takes exposed card after release")
	for scale_size in [1.,1.6]:
		device.global_basis=Basis.from_euler(Vector3(.2,.6,-.1)).scaled(Vector3.ONE*scale_size)
		var pose: Transform3D=rack._slot_pose(rack.ENTRY_Z)
		check(rack._aligned(pose),"Correct card enters rotated/scaled slot")
		pose.basis=pose.basis*Basis(Vector3.RIGHT,PI)
		check(not rack._aligned(pose),"Upside-down card rejected")
		pose=rack._slot_pose(rack.ENTRY_Z)
		pose.origin+=device.global_basis.x*.02
		check(not rack._aligned(pose),"Sideways misalignment rejected")
	device.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,1,0))
	hands[0]=Transform3D.IDENTITY
	rack.blends[0]=0
	rack.offsets[0]=rack._slot_pose(rack.ENTRY_Z)
	rack.move_hands(0,hands)
	check(rack.mode=="guided" and events.size()==2,"Partial entry guides but does not boot")
	hands[0].origin.z+=.034
	rack.move_hands(.016,hands)
	check(rack.mode=="latched" and events.size()==3 and not rack.held_by(0),"Full insertion stroke clicks and starts game once")
	check(Clicks.sound(false).data.size()>0 and Clicks.sound(true).data!=Clicks.sound(false).data,"Insertion/ejection have distinct synthesized clicks")
	check(Clicks.sound(false)==Clicks.sound(false),"Click assets cached, not regenerated while playing")
	check(device.get_node("LowerHousing/GameCardOpening")!=null,"Rear shell has actual card opening")
	var a := Transform3D(Basis.IDENTITY,device.to_global(Vector3(0,.06,.01)))
	var b := Transform3D(Basis.IDENTITY,device.to_global(Vector3(0,-.04,.01)))
	var stopped: Transform3D=rack.move_free_card(a,b)
	check(device.to_local(stopped.origin).y>.010,"Misaligned free cartridge cannot pass through console deck")
	check(rack._card_push(stopped).length()<.00002,"Card collision finishes outside shell")
	print("CARTRIDGE TEST: %d checks, %d failures" % [checks,failures])
	quit(failures)
