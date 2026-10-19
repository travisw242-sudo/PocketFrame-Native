extends SceneTree
const Layout=preload("res://scripts/studio_layout.gd")
var checks := 0
var failures := 0
func check(ok: bool,title: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(title)
func _initialize() -> void:
	for height in [1.1,1.25,1.6,1.9]:
		for yaw in [0.,.7,-1.8]:
			var head := Transform3D(Basis(Vector3.UP,yaw),Vector3(2,height,-3))
			var dock := Layout.dock_for_head(head)
			var table := Layout.table_for_dock(dock)
			var local_head := table.affine_inverse()*head.origin
			check(local_head.z-Layout.TABLE_SIZE.z/2>=.20,"Player remains at least 20 cm outside near edge")
			check(is_equal_approx(head.origin.y-(table.origin.y+.015),.442),"Seated surface is 44.2 cm below eye height")
			var plinth_bottom := dock.origin.y-.031-.011
			check(is_equal_approx(plinth_bottom,table.origin.y+.015),"Display plinth rests on desk instead of hovering")
			var note_local := Vector3(-.38,.0165,0)
			check(absf(note_local.x)+.17<Layout.TABLE_SIZE.x/2 and .13<Layout.TABLE_SIZE.z/2,"Desk note fits smaller surface")
	var vertical_head := Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,1.25,0))
	check(Layout.dock_for_head(vertical_head).basis.is_finite(),"Looking vertically does not break recenter")
	print("STUDIO LAYOUT: %d checks, %d failures"%[checks,failures])
	quit(failures)
