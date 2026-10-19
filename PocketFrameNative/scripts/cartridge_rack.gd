extends Node3D
## One physical card per library entry, paged reachable tray in any environment.
const Library = preload("res://scripts/cartridge_library.gd")
const HandPose = preload("res://scripts/hand_pose.gd")
const Clicks = preload("res://scripts/cartridge_clicks.gd")
const G = preload("res://scripts/geometry.gd")
const Contact = preload("res://scripts/stylus_motion.gd")
signal library_changed(count: int)
signal feedback(hand: int)
var library := Library.new()
var device: Node3D
var cards: Dictionary = {}
var homes: Dictionary = {}
var tray: Node3D
var tray_hand := -1
var tray_offset := Transform3D.IDENTITY
var tray_placed := false
var heading: Label3D
var click_player: AudioStreamPlayer
var held := [null,null]
var offsets := [Transform3D.IDENTITY,Transform3D.IDENTITY]
var blends := [0.,0.]
var previous_grips := [true,true]
var seated: Node3D
var mode := "empty" # empty / guided / latched / popping / popped
var depth := 0.0
var press_tip := -1
var press_start := 0.0
var press_armed := true
var insertion_anchor := 0.0
var insertion_depth := 0.0
var held_insertion_hand := -1
var guide_retreat := 0.0
var guide_blocked := [false,false]
var last_event := ""
var page := 0
var scan_timer := 0.0
var drop_times: Dictionary = {}
var dock_pose := Transform3D.IDENTITY
var tray_buttons: Array[Vector3]=[Vector3(0,0,.063)]
var next_page_cap: MeshInstance3D
var next_page_label: Label3D
var previous_tray_tips: Array=[]
var tray_touch := -1
const PAGE_SIZE := 8
const ENTRY_Z := -.017
const LATCH_Z := .015
const POP_Z := .007

func setup(console: Node3D, dock: Transform3D) -> void:
	device=console
	dock_pose=dock
	tray=Node3D.new()
	tray.name="GameCartridgeTray"
	add_child(tray)
	G.rounded(tray,Vector3(.24,.009,.15),.012,.002,G.material(Color("344550"),.15,.6),Vector3(0,-.008,0),"Tray")
	heading=G.label(tray,"GAME CARDS",Vector3(0,-.001,-.061),.00010)
	next_page_cap=G.rounded(tray,Vector3(.12,.004,.024),.004,.0008,G.material(Color("50766f"),.1,.6),tray_buttons[0],"NextPageButton")
	next_page_label=G.label(tray,"NEXT PAGE",tray_buttons[0]+Vector3(0,.003,0),.00008)
	# Close-up mechanism feedback must remain audible with either XR or desktop
	# camera, independently of emulator volume and spatial listener placement.
	click_player=AudioStreamPlayer.new()
	click_player.name="CartridgeMechanismAudio"
	click_player.volume_db=-1
	add_child(click_player)
	refresh()
	recall(dock)

func refresh() -> void:
	var old_ids := library.entries.keys()
	library.scan_folder()
	for id in library.entries:
		if cards.has(id):
			if cards[id].metadata_stamp!=library.entries[id].get("stamp",""):
				cards[id].refresh_art(library.entries[id])
			continue
		var card=library.spawn_cartridge(id)
		add_child(card)
		cards[id]=card
	for id in cards:
		if not library.entries.has(id) and cards[id]!=seated and not cards[id] in held:
			cards[id].hide() # Only a virtual prop. Never remove/rename its ROM.
	_layout()
	if old_ids!=library.entries.keys(): library_changed.emit(library.entries.size())

func _layout() -> void:
	if not tray: return
	var ids := library.entries.keys()
	page=clampi(page,0,maxi(0,(ids.size()-1)/PAGE_SIZE))
	var size: float=device.global_basis.x.length()
	for i in range(ids.size()):
		var id: String=ids[i]
		var card: Node3D=cards[id]
		var index := i%PAGE_SIZE
		homes[id]=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),Vector3((index%4-1.5)*.055,.005,(index/4)*.057-.029))
		if card==seated or card in held: continue
		card.visible=i/PAGE_SIZE==page
		if not drop_times.has(id): card.global_transform=tray.global_transform*homes[id]
	heading.text="GAME CARDS · %d   %d/%d" % [ids.size(),page+1,maxi(1,ceili(float(ids.size())/PAGE_SIZE))]
	var multiple := page_count()>1
	next_page_label.text="NEXT PAGE" if multiple else "ALL GAMES"
	next_page_cap.material_override.albedo_color=Color("50766f") if multiple else Color("414e57")

func page_count() -> int:
	return maxi(1,ceili(float(library.entries.size())/PAGE_SIZE))

func recall(dock: Transform3D, force: bool = false) -> void:
	dock_pose=dock
	if not tray: return
	if tray_placed and not force: return
	tray_hand=-1
	tray_placed=false
	var basis := dock.basis.orthonormalized()
	tray.global_transform=Transform3D(basis,dock.origin+basis*Vector3(.265,-.004,.015))
	drop_times.clear()
	previous_tray_tips.clear()
	tray_touch=-1
	_layout()

func next_page() -> void:
	page=(page+1)%page_count()
	_layout()

func mount_path(path: String) -> bool:
	var normalized := path.replace("\\","/").to_lower()
	for id in library.entries:
		if str(library.entries[id].content_path).replace("\\","/").to_lower()==normalized:
			return _latch(cards[id])
	# A launcher may explicitly select a file outside games. Register only that file.
	if not FileAccess.file_exists(path): return false
	var id := normalized.sha256_text().left(16)
	library.register_game(id,path.get_file().get_basename(),path)
	var card=library.spawn_cartridge(id)
	add_child(card)
	cards[id]=card
	return _latch(card)

func _click(ejecting: bool) -> void:
	click_player.stream=Clicks.sound(ejecting)
	click_player.play()

func _slot_pose(z: float) -> Transform3D:
	return device.cartridge_slot.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,z))

func _latch(card: Node3D) -> bool:
	if device.cartridge_slot.cartridge!=null: return false
	if seated!=null and seated!=card: return false
	seated=card
	mode="latched"
	depth=LATCH_Z
	card.reparent(device.cartridge_slot,true)
	card.transform=Transform3D(Basis.IDENTITY,Vector3(0,0,depth))
	card.show()
	device.cartridge_slot.insert(card)
	_click(false)
	press_tip=-1
	press_armed=false
	last_event="Cartridge clicked in · "+card.display_name
	return true

func eject() -> bool:
	if mode!="latched" or seated==null: return false
	device.cartridge_slot.eject()
	mode="popping"
	press_tip=-1
	press_armed=false
	_click(true)
	last_event="Cartridge released · grip the exposed edge"
	return true

func held_by(hand: int) -> bool:
	return held[hand]!=null

func busy_by(hand: int) -> bool:
	return held_by(hand) or tray_hand==hand

func _near_tray(hand: Transform3D, fingers: Array) -> bool:
	if tray_hand>=0: return false
	var points: Array=[hand.origin]
	points.append_array(fingers)
	for point: Vector3 in points:
		var p := tray.to_local(point)
		# Grip the rim, not the cards or the touch-operated page button.
		if absf(p.y)>.045 or absf(p.x)>.15 or absf(p.z)>.105: continue
		if absf(p.x)>.105 or p.z<-.074 or p.z>.081: return true
	return false

func touch_tray(tips: Array, eligible: Array) -> void:
	# Button top is y=.002, with ~4 mm allowance for the fingertip pad.
	# A swept crossing catches quick presses that skip the thin visible cap.
	var pressing := -1
	var contact_remains := false
	var current_tips: Array=[]
	for i in range(tips.size()):
		current_tips.append(null)
		if i>=eligible.size() or not eligible[i]: continue
		var p: Vector3=tray.to_local(tips[i])
		current_tips[i]=p
		var offset := p-tray_buttons[0]
		if absf(offset.x)<.070 and absf(offset.z)<.023 and offset.y<.026 and offset.y>-.045: contact_remains=true
		var hits := absf(offset.x)<.062 and absf(offset.z)<.015 and offset.y<=.006 and offset.y>=-.010
		if not hits and i<previous_tray_tips.size() and previous_tray_tips[i]!=null:
			var before: Vector3=previous_tray_tips[i]
			if before.y>.006 and p.y<=.006 and before.distance_to(p)<.12:
				var crossing := before.lerp(p,(before.y-.006)/(before.y-p.y))-tray_buttons[0]
				hits=absf(crossing.x)<.062 and absf(crossing.z)<.015
		if hits and pressing<0: pressing=i
	previous_tray_tips=current_tips
	if tray_touch<0 and pressing>=0:
		tray_touch=0
		next_page()
		feedback.emit(pressing/2)
	elif tray_touch>=0 and not contact_remains and pressing<0:
		tray_touch=-1
	var depression := -.002 if tray_touch>=0 else 0.0
	next_page_cap.position.y=tray_buttons[0].y+depression
	next_page_label.position.y=tray_buttons[0].y+.003+depression

func return_popped() -> void:
	if seated==null or not mode in ["popping","popped"]: return
	var card := seated
	seated=null;mode="empty"
	card.reparent(self,true)
	drop_times[card.game_id]=1.0

func release_all() -> void:
	for i in range(2):
		_release(i)
	previous_grips=[true,true]

func _near_card(hand: Transform3D, fingers: Array):
	var best: Node3D=null
	var distance := .032*device.global_basis.x.length()
	for card: Node3D in cards.values():
		if not card.visible or card in held or card.inserted: continue
		if card==seated and mode!="popped": continue
		var d := hand.origin.distance_to(card.global_position)
		for point: Vector3 in fingers: d=minf(d,point.distance_to(card.global_position))
		if d<distance: distance=d; best=card
	return best

func reserve(hands: Array, tracked: Array, grips: Array, eligible: Array, fingers: Array) -> Array:
	last_event=""
	for i in range(2):
		if busy_by(i) and (not tracked[i] or not grips[i] or not eligible[i]):
			_release(i)
		if not busy_by(i) and tracked[i] and eligible[i] and grips[i] and not previous_grips[i]:
			var card: Node3D=_near_card(hands[i],fingers[i])
			if card:
				held[i]=card
				if card==seated: seated=null; mode="empty"
				card.reparent(self,true)
				offsets[i]=hands[i].affine_inverse()*card.global_transform
				blends[i]=0
				guide_blocked[i]=false
				drop_times.erase(card.game_id)
				feedback.emit(i)
			elif _near_tray(hands[i],fingers[i]):
				tray_hand=i
				tray_placed=true
				tray_offset=hands[i].affine_inverse()*tray.global_transform
				previous_tray_tips.clear()
				feedback.emit(i)
		previous_grips[i]=grips[i] if tracked[i] else true
	return [busy_by(0),busy_by(1)]

func _release(hand: int) -> void:
	if tray_hand==hand:
		tray_hand=-1 # Leave the last world pose untouched: no gravity or recall.
		previous_tray_tips.clear()
	var card: Node3D=held[hand]
	if card==null: return
	held[hand]=null
	if card==seated and mode=="guided":
		mode="popping"
		depth=minf(depth,POP_Z)
	else:
		drop_times[card.game_id]=0.0
	held_insertion_hand=-1

func _aligned(pose: Transform3D) -> bool:
	var local: Transform3D=device.cartridge_slot.global_transform.affine_inverse()*pose
	var leading := local*Vector3(0,0,.0165)
	# Capture the leading edge near the opening, not a hidden center point.
	# Only a nearby, broadly correctly oriented card is assisted.
	return absf(leading.x)<.019 and absf(leading.y)<.015 and leading.z>-.024 and leading.z<.012 and local.basis.y.normalized().dot(Vector3.UP)>.5 and local.basis.z.normalized().dot(Vector3.BACK)>.6

func hand_card_pose(hand: Transform3D, index: int) -> Transform3D:
	var fit := HandPose.grip_transform(index==0,device.hand_pitch,device.hand_roll,device.hand_offset)
	return hand*fit*HandPose.card_in_hand(index==0,device.global_basis.x.length())

func _guide_probe(hand: Transform3D,index: int) -> Vector3:
	# Rotating the wrist must not accidentally insert/retract a card: measure
	# the intended pinch point, not the controller's offset grip origin.
	return device.cartridge_slot.to_local(hand_card_pose(hand,index)*HandPose.CARD_GRASP)

func _card_push(pose: Transform3D) -> Vector3:
	var local: Transform3D=device.global_transform.affine_inverse()*pose
	var lid_local: Transform3D=device.lid.global_transform.affine_inverse()*pose
	var radius := .002*pose.basis.x.length()/device.global_basis.x.length()
	var best := Vector3.ZERO
	for x in [-.0165,0.,.0165]:
		for z in [-.0165,0.,.0165]:
			var sample := Vector3(x,0,z)
			var push: Vector3=device.global_basis*Contact._sphere_box(local*sample,radius,Contact.DECK)
			if push.length_squared()>best.length_squared(): best=push
			push=device.lid.global_basis*Contact._sphere_box(lid_local*sample,radius,Contact.LID)
			if push.length_squared()>best.length_squared(): best=push
	return best

func move_free_card(start: Transform3D,target: Transform3D) -> Transform3D:
	var size: float=device.global_basis.x.length()
	if target.origin.distance_to(device.global_position)>.20*size and start.origin.distance_to(device.global_position)>.20*size: return target
	var angle := start.basis.orthonormalized().get_rotation_quaternion().angle_to(target.basis.orthonormalized().get_rotation_quaternion())
	var steps := clampi(ceili((start.origin.distance_to(target.origin)/size+angle*.025)/.002),1,80)
	var pose := start
	for step in range(1,steps+1):
		var goal := start.interpolate_with(target,float(step)/steps)
		var previous := start.interpolate_with(target,float(step-1)/steps)
		pose.origin+=goal.origin-previous.origin
		pose.basis=goal.basis
		for iteration in range(12):
			var push := _card_push(pose)
			if push.length_squared()<1e-12: break
			pose.origin+=push
		if _card_push(pose).length_squared()>1e-10: return start
	return pose

func move_hands(delta: float, hands: Array) -> void:
	if tray_hand>=0:
		tray.global_transform=hands[tray_hand]*tray_offset
		previous_tray_tips.clear()
		for id in homes:
			var home_card: Node3D=cards[id]
			if home_card!=seated and not home_card in held and not drop_times.has(id):
				home_card.global_transform=tray.global_transform*homes[id]
	for i in range(2):
		var card: Node3D=held[i]
		if card==null: continue
		if card==seated and mode=="guided":
			var probe := _guide_probe(hands[i],i)
			var travel := probe.z-insertion_anchor
			depth=clampf(insertion_depth+travel,ENTRY_Z-.04,LATCH_Z+.002)
			card.global_transform=_slot_pose(depth)
			if depth>=LATCH_Z:
				held[i]=null
				held_insertion_hand=-1
				_latch(card)
				feedback.emit(i)
			elif travel<-.014 or absf(probe.x)>guide_retreat+.055:
				seated=null;mode="empty"
				guide_blocked[i]=true
				offsets[i]=hands[i].affine_inverse()*card.global_transform
				blends[i]=0
			continue
		blends[i]=move_toward(blends[i],1,delta/.15)
		var pose: Transform3D=(hands[i]*offsets[i]).interpolate_with(hand_card_pose(hands[i],i),smoothstep(0,1,blends[i]))
		if guide_blocked[i]:
			var lead: Vector3=device.cartridge_slot.to_local(pose*Vector3(0,0,.0165))
			if lead.z<-.032: guide_blocked[i]=false
		if seated==null and not guide_blocked[i] and _aligned(pose):
			seated=card;mode="guided";depth=ENTRY_Z
			held_insertion_hand=i
			insertion_anchor=_guide_probe(hands[i],i).z
			guide_retreat=absf(_guide_probe(hands[i],i).x)
			insertion_depth=ENTRY_Z
			card.global_transform=_slot_pose(depth)
			feedback.emit(i)
		else:
			card.global_transform=move_free_card(card.global_transform,pose)

func touch_eject(tips: Array, eligible: Array) -> void:
	if mode!="latched": return
	var any_near := false
	for i in range(tips.size()):
		if not eligible[i]: continue
		var p: Vector3=device.cartridge_slot.to_local(tips[i])
		var near := absf(p.x)<.021 and absf(p.y)<.009 and p.z>-.014 and p.z<.005
		any_near=any_near or near
		if not near: continue
		if press_tip<0 and press_armed: press_tip=i;press_start=p.z
		if press_tip==i:
			var movement := p.z-press_start
			seated.position.z=LATCH_Z+clampf(movement,0,.0018)
			if movement>=.0018:
				eject();feedback.emit(i/2)
				return
	if not any_near:
		press_armed=true;press_tip=-1
		seated.position.z=LATCH_Z
	elif press_tip>=0 and (press_tip>=eligible.size() or not eligible[press_tip]):
		press_tip=-1

func _process(delta: float) -> void:
	if not device: return
	scan_timer+=delta
	if scan_timer>=5:
		scan_timer=0
		refresh()
	if mode=="popping" and seated:
		depth=move_toward(depth,POP_Z,.085*delta)
		seated.global_transform=_slot_pose(depth)
		if is_equal_approx(depth,POP_Z): mode="popped"
		if mode=="popped":
			seated.reparent(device.cartridge_slot,true)
			seated.transform=Transform3D(Basis.IDENTITY,Vector3(0,0,POP_Z))
	for id in drop_times.keys():
		drop_times[id]+=delta
		var card: Node3D=cards[id]
		if drop_times[id]>.8:
			drop_times.erase(id)
			if homes.has(id): card.global_transform=tray.global_transform*homes[id]
			_layout()
		else: card.global_position.y=maxf(tray.global_position.y-.002,card.global_position.y-delta*.12)
