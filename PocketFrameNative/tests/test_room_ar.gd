extends SceneTree
const Rooms=preload("res://scripts/room_builder.gd")
const AR=preload("res://scripts/ar_mode.gd")
var checks := 0
var failures := 0
class FakeXR:
	extends RefCounted
	var environment_blend_mode := XRInterface.XR_ENV_BLEND_MODE_OPAQUE
	var modes: Array=[XRInterface.XR_ENV_BLEND_MODE_OPAQUE]
	var reject := false
	func is_initialized() -> bool: return true
	func get_supported_environment_blend_modes() -> Array: return modes
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var room := Rooms.build("teen_2008")
	root.add_child(room)
	check(room.get_node("BedroomFloor").position.y<=0,"Full-scale room floor stays at tracking floor")
	for name in ["Bed","Desk","DeskChair","Nightstand","BedroomTV","BedsideLamp","CollectionShelf"]:
		check(room.has_node(NodePath(name)),"Detailed imported furniture: "+name)
	var pose := Transform3D(Basis(Vector3.UP,.7),Vector3(.1,.85,-.6))
	Rooms.place_dock(room,pose)
	check(room.get_node("DeskDock").global_position.distance_to(Vector3(.8,.813,-1.76))<.001,"Fixed computer desk dock does not follow arbitrary recenter poses")
	check(not room.has_node("DockFurniture") and room.find_children("GameCaseSpine*","",true,false).is_empty(),"No center table or placeholder palette blocks")
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("123456")
	var xr := FakeXR.new()
	var ar := AR.new()
	check(not ar.enable(xr,viewport,environment),"Opaque-only SteamVR cannot falsely enable AR")
	check(not viewport.transparent_bg and environment.background_color==Color("123456"),"Unsupported request leaves VR view intact")
	xr.modes.append(XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND)
	check(ar.enable(xr,viewport,environment),"Supported alpha compositor enables AR")
	check(ar.active and viewport.transparent_bg and environment.background_color.a==0,"AR preserves compositor alpha")
	ar.disable(xr,viewport,environment)
	check(not ar.active and not viewport.transparent_bg and environment.background_color==Color("123456"),"Disabling AR restores original view")
	check(xr.environment_blend_mode==XRInterface.XR_ENV_BLEND_MODE_OPAQUE,"Opaque composition restored")
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	var backend_id: int=main.emulator_backend.get_instance_id()
	main.immersion.holders[0]=true
	main._load_room("teen_2008")
	check(main.immersion.holding(0) and main.emulator_backend.get_instance_id()==backend_id,"Changing room preserves holder and emulator instance")
	var support_height: float=main.room_environment.get_node("Desktop").global_position.y+.0225
	var tray_height: float=main.cartridge_rack.tray.global_position.y-.0125
	check(absf(support_height-tray_height)<.002,"Portable tray rests on the room tabletop")
	main.xr_camera.position=Vector3(.3,1.6,.2)
	main.rig.rotation.y=.7
	main._spawn_at_desk()
	check(main.xr_camera.global_position.distance_to(Vector3(.8,1.6,-1.22))<.001,"Spawn aligns tracked head above desk anchor without changing height")
	check((-main.xr_camera.global_basis.z).distance_to(Vector3.FORWARD)<.001,"Spawn faces computer desk rather than room center")
	check(main.ar_mode.enable(xr,main.get_viewport(),main.world_environment.environment),"Supported test compositor enables in app environment")
	main._sync_environment()
	check(not main.room_environment.visible and not main.get_node("DisplayPlinth").visible,"AR hides opaque room and plinth")
	main._load_room("studio")
	check(not main.room_environment.visible and not main.get_node("StudioTable").visible,"Room change cannot obscure active passthrough")
	main.ar_mode.disable(xr,main.get_viewport(),main.world_environment.environment)
	main._sync_environment()
	check(main.get_node("DisplayPlinth").visible and main.immersion.holding(0),"Returning to VR preserves console hold")
	main.queue_free()
	print("ROOM/AR: %d checks, %d failures" % [checks,failures])
	quit(failures)
