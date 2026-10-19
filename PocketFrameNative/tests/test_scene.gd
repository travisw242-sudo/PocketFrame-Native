extends SceneTree
const Main = preload("res://scripts/main.gd")
const Solver = preload("res://scripts/hold_solver.gd")
var failures := 0
func check(value: bool, label: String) -> void:
 if not value:
  failures += 1
  push_error("FAIL: " + label)
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var scene := Main.new()
 root.add_child(scene)
 await process_frame
 check(scene.device.lid != null, "Articulated lid built")
 check(scene.device.buttons.size() == 9, "All animated physical controls built")
 check(scene.device.top_viewport.size == Vector2i(1600,960), "High-resolution top display")
 check(scene.device.bottom_viewport.size == Vector2i(1280,960), "High-resolution touch display")
 check(scene.azahar_bridge.device == scene.device and not scene.azahar_bridge.enabled, "Azahar bridge stays opt-in and attaches to physical LCDs")
 check(is_instance_valid(scene.left_hand_visual) and is_instance_valid(scene.right_hand_visual), "Controller-driven virtual hands are built")
 check(scene.ui.find_child("HandModelChoice", true, false) != null, "Running settings expose hand comparison choice")
 scene.immersion.holders[0] = true
 scene._setup_virtual_hands("legacy")
 check(scene.left_hand_visual.skeleton.get_bone_count() == 16 and scene.immersion.holding(0), "Legacy comparison does not release console hold")
 scene._setup_virtual_hands("rigged")
 check(scene.left_hand_visual.skeleton.get_bone_count() == 26 and scene.immersion.holding(0), "Rigged comparison restores imported model without touching hold")
 scene.immersion.holders[0] = false
 check(scene.room_environment != null and scene.room_id in ["studio","teen_2008"], "Room loader honors a valid saved room preset")
 scene._load_room("teen_2008")
 check(scene.room_environment.get_node_or_null("BedroomFloor") != null, "Late-2000s bedroom room preset builds procedural furniture")
 scene.device.set_volume(.25)
 check(is_equal_approx(scene.device.volume_level, .25) and scene.device.volume_db() < -20, "Volume slider uses a useful perceptual audio curve")
 scene.device.set_depth(.75)
 check(is_equal_approx(scene.device.depth_level, .75), "Depth slider retains continuous 3D strength")
 scene.device.set_stylus_extension(.5)
 check(is_equal_approx(scene.device.stylus_extension, .5), "Stylus extraction state is modeled")
 scene.device.set_lid_angle(115)
 check(is_equal_approx(scene.device.lid.rotation.x, deg_to_rad(65)), "Lid angle applied at hinge")
 var center: Vector3 = scene.device.bottom_surface.global_position
 var normal: Vector3 = scene.device.bottom_surface.global_basis.y.normalized()
 var uv: Vector2 = scene.device.ray_to_touch(center + normal, -normal)
 check(uv.is_equal_approx(Vector2(.5,.5)), "Actual built screen ray hit")
 scene.router.update_touch(Vector2(.8,.45),true)
 check(scene.device.bottom_canvas.selection == 2, "Touch selected third tile")
 scene.router.update_touch(Vector2(-1,-1),false)
 var key := InputEventKey.new()
 key.physical_keycode = KEY_L
 key.pressed = true
 Input.parse_input_event(key)
 await process_frame
 await process_frame
 check(scene.router.previous.get("A",false), "Keyboard A routes through actual scene")
 key.pressed = false
 Input.parse_input_event(key)
 await process_frame
 await process_frame
 check(not scene.router.previous.get("A",true), "Keyboard A releases")
 scene._toggle_sim()
 scene.grab_cooldown = 0
 var space := InputEventKey.new()
 space.physical_keycode = KEY_SPACE
 space.pressed = true
 Input.parse_input_event(space)
 await process_frame
 await process_frame
 for i in range(100): scene._update_hold(.016)
 check(scene.solver.state == Solver.State.HELD, "Desktop simulator picks up through real solver")
 space = space.duplicate()
 space.pressed = false
 Input.parse_input_event(space)
 scene._dock()
 check(scene.solver.state == Solver.State.DOCKED, "Scene docks")
 var meshes: Array[MeshInstance3D] = []
 collect_meshes(scene.device,meshes)
 var triangles := 0
 for node in meshes:
  for surface in range(node.mesh.get_surface_count()):
   var arrays := node.mesh.surface_get_arrays(surface)
   if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0:
    triangles += arrays[Mesh.ARRAY_INDEX].size()/3
   else:triangles += arrays[Mesh.ARRAY_VERTEX].size()/3
 print("MODEL: ",meshes.size()," mesh parts; ",triangles," triangles")
 print("SCENE TEST: ",failures," failures")
 scene.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
func collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
 if node is MeshInstance3D:result.append(node)
 for child in node.get_children():collect_meshes(child,result)
