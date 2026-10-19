extends SceneTree
const Pose=preload("res://scripts/hand_pose.gd")
var checks:=0
var failures:=0
func check(ok: bool,title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.cartridge_rack.set_process(false)
	var rack=scene.cartridge_rack
	var card: Node3D=rack.cards.values()[0]
	for size in [.8,1.,1.6,2.]:
		for i in range(2):
			var controller: Node3D=[scene.left,scene.right][i]
			var hand=[scene.left_hand_visual,scene.right_hand_visual][i]
			var world:=Transform3D(Basis.from_euler(Vector3(.2,.6,-.3)),Vector3(.4,1.4,-.2))
			controller.global_transform=world*Pose.grip_transform(i==0).affine_inverse()
			card.global_transform=world*Pose.card_in_hand(i==0,size)
			hand.set_game_inputs({},Vector2.ZERO,1,"cartridge",{"cartridge_world":card.global_transform,"collision_device":scene.device,"grip":1.})
			for title in ["index","thumb"]:
				var target:=Pose.card_pad_target(card.global_transform,title=="thumb")
				var actual: Vector3=hand.fingertip_position(title)
				var error:=actual.distance_to(target)
				print("CARD PAD left=",i==0," size=",size," digit=",title," error_mm=",error*1000)
				check(error<.013,"Pad reaches its own face without a pen grip")
				var local: Vector3=card.to_local(actual)
				check(local.y>.0019 if title=="thumb" else local.y<-.0019,"Pads oppose across card thickness instead of converging through plastic")
			for title in hand.TITLES:
				check(hand._card_depth(title,card.global_transform)<.0005,"Entire finger chain clears cartridge shell")
			var solved: Array=[]
			for id in range(hand.skeleton.get_bone_count()): solved.append(hand.skeleton.get_bone_pose_rotation(id))
			hand.set_game_inputs({},Vector2.ZERO,.016,"cartridge",{"cartridge_world":card.global_transform,"collision_device":scene.device,"grip":1.})
			for id in range(hand.skeleton.get_bone_count()):
				check(absf(solved[id].dot(hand.skeleton.get_bone_pose_rotation(id)))>.99999,"Cached cartridge pose stays stable at VR frame delta")
			for id in range(hand.skeleton.get_bone_count()):
				check(hand.skeleton.get_bone_pose_position(id).distance_to(hand.skeleton.get_bone_rest(id).origin)<.000001,"Card pose preserves bone translations")
	# Forgiving local entrance region, including tilt and moderate offsets.
	for size in [.8,1.25,2.]:
		scene.device.global_transform=Transform3D(Basis.from_euler(Vector3(.4,.7,-.2)).scaled(Vector3.ONE*size),Vector3(0,1,-.5))
		for angle in [-40.,0.,40.]:
			var target: Transform3D=rack._slot_pose(rack.ENTRY_Z)
			target.basis=target.basis*Basis(Vector3.UP,deg_to_rad(angle))
			target.origin+=scene.device.global_basis.y*.008
			check(rack._aligned(target),"Nearby tilted leading edge captures at rotated/scaled slot")
		var far: Transform3D=rack._slot_pose(-.12)
		check(not rack._aligned(far),"Assist never attracts a distant cartridge")
	check(not scene.device.get_node("CartridgeSlot") is MeshInstance3D,"No solid face blocks the carved mouth")
	check(scene.device.get_node("CartridgeSlot").get_child_count()==4,"Only four open rim lips surround mouth")
	check(scene.device.cartridge_slot.global_basis.y.normalized().dot(scene.device.global_basis.y.normalized())<-.99,"Seated label faces underside like a real 3DS")
	var bore: CSGBox3D=scene.device.get_node("LowerHousing/GameCardOpening")
	check(is_equal_approx(bore.size.x,.0356),"Slot width tightly fits keyed cartridge with 0.3 mm clearance per side")
	check(rack.click_player is AudioStreamPlayer and rack.click_player.volume_db>=-1,"Mechanism click is audible without spatial listener attenuation")
	for ejecting in [false,true]:
		var sound=load("res://scripts/cartridge_clicks.gd").sound(ejecting)
		var peak:=0
		for sample in range(sound.data.size()/2): peak=maxi(peak,absi(sound.data.decode_s16(sample*2)))
		check(sound.get_length()>=.1 and peak>10000,"Latch/eject audio has a strong nonempty transient")
	# Actual calibrated controller -> card -> guide -> push, not an identity
	# controller fixture that bypasses the natural grip transforms.
	scene.device.cartridge_slot.cartridge_inserted.disconnect(scene._on_cartridge_inserted)
	scene.device.cartridge_slot.cartridge_ejected.disconnect(scene._on_cartridge_ejected)
	rack.click_player.volume_db=-80
	for size in [.8,1.25,2.]:
		for i in range(2):
			scene.device.global_transform=Transform3D(Basis.from_euler(Vector3(.4,.7,-.2)).scaled(Vector3.ONE*size),Vector3(0,1,-.5))
			scene.device.cartridge_slot.cartridge=null
			card.set_inserted(false)
			card.reparent(rack,true)
			rack.seated=null
			rack.mode="empty"
			rack.held=[null,null]
			rack.held[i]=card
			var entry: Transform3D=rack._slot_pose(rack.ENTRY_Z)
			entry.basis=entry.basis*Basis(Vector3.UP,deg_to_rad(30))*Basis(Vector3.RIGHT,deg_to_rad(-15))
			entry.origin+=scene.device.global_basis*Vector3(.007,.006,-.002)
			var hand: Transform3D=entry*Pose.card_in_hand(i==0,size).affine_inverse()*Pose.grip_transform(i==0).affine_inverse()
			var hands: Array=[Transform3D.IDENTITY,Transform3D.IDENTITY]
			hands[i]=hand
			card.global_transform=entry
			rack.offsets[i]=hand.affine_inverse()*entry
			rack.blends[i]=1
			rack.move_hands(.016,hands)
			check(rack.mode=="guided","Calibrated tilted/off-center card enters assist, either hand")
			check(not card.inserted,"Nearby entrance alone never launches game")
			hands[i].origin+=scene.device.global_basis.z*.033
			rack.move_hands(.016,hands)
			check(rack.mode=="latched" and card.inserted,"Natural grip push reaches latch at rotated/scaled console")
			check(card.global_transform.is_equal_approx(rack._slot_pose(rack.LATCH_Z)),"Assisted card finishes precisely on slot rails")
			check(rack.click_player.playing and rack.click_player.stream==rack.Clicks.sound(false),"Full insertion actually plays latch audio")
			check(rack.eject() and rack.click_player.playing and rack.click_player.stream==rack.Clicks.sound(true),"Ejection actually plays release audio")
	scene.device.cartridge_slot.cartridge=null
	card.set_inserted(false)
	card.reparent(rack,true)
	rack.seated=null; rack.mode="empty";rack.held=[card,null]
	var entry: Transform3D=rack._slot_pose(rack.ENTRY_Z)
	var hand: Transform3D=entry*Pose.card_in_hand(true,scene.device.global_basis.x.length()).affine_inverse()*Pose.grip_transform(true).affine_inverse()
	var hands: Array=[hand,Transform3D.IDENTITY]
	card.global_transform=entry
	rack.offsets[0]=hand.affine_inverse()*entry
	rack.blends[0]=1
	rack.guide_blocked[0]=false
	rack.move_hands(.016,hands)
	check(rack.mode=="guided","Withdrawal fixture starts in guide")
	hands[0].origin-=scene.device.global_basis.z*.020
	rack.move_hands(.016,hands)
	check(rack.mode=="empty" and not card.inserted,"Pulling back cancels insertion without booting")
	rack.move_hands(0,hands)
	check(rack.mode=="empty","Cancelled guide does not instantly recapture the card")
	print("CARTRIDGE FIT: %d checks, %d failures" % [checks,failures])
	quit(failures)
