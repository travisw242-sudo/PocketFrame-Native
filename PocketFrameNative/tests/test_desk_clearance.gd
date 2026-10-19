extends SceneTree
const Rooms=preload("res://scripts/room_builder.gd")
const Bedroom=preload("res://scripts/bedroom.gd")
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var room := Rooms.build("teen_2008")
	root.add_child(room)
	for title in ["FamilyHandMeDownComputer","Headphones","WindowSill","SchoolBook","DeskCup"]:
		print(title," ",Bedroom.bounds(room.get_node(title)))
	var pc := Bedroom.bounds(room.get_node("FamilyHandMeDownComputer"))
	var sill := Bedroom.bounds(room.get_node("WindowSill"))
	var phones := Bedroom.bounds(room.get_node("Headphones"))
	var desktop := Bedroom.bounds(room.get_node("Desktop"))
	check(not pc.intersects(sill) and pc.position.z-sill.end.z>.04,"PC housing clears window sill by at least 4 cm")
	check(phones.size.y>.07 and phones.size.y<.10,"Headphones have plausible full-size earcup thickness")
	for title in ["SchoolBook","DeskCup"]:
		check(not phones.intersects(Bedroom.bounds(room.get_node(title))),"Headphones clear "+title)
	for prop in [pc,phones]:
		check(prop.position.x>desktop.position.x and prop.end.x<desktop.end.x and prop.position.z>desktop.position.z and prop.end.z<desktop.end.z,"Desk prop stays within tabletop edges")
		check(absf(prop.position.y-desktop.end.y)<.004,"Desk prop rests on tabletop")
	check(phones.end.z< -1.84,"Headphones clear the live cartridge tray")
	room.free()
	print("DESK CLEARANCE: %d checks, %d failures" % [checks,failures])
	quit(failures)
