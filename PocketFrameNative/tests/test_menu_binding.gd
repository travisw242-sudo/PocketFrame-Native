extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,title: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(title)
func _initialize() -> void:
	var map=load("res://openxr_action_map.tres")
	var menu_action: OpenXRAction
	for action_set in map.get_action_sets():
		for action in action_set.get_actions():
			if action.resource_name=="menu_toggle":menu_action=action
	check(menu_action!=null,"Dedicated physical menu action exists")
	var bindings := {}
	for profile in map.get_interaction_profiles():
		if profile.get_interaction_profile_path()!="/interaction_profiles/valve/frame_controller_valve":continue
		for binding in profile.get_bindings():
			bindings[binding.get_action().resource_name]=binding.get_binding_path()
	check(bindings.get("menu_toggle")=="/user/hand/right/input/y/click","Menu uses physical top Y on RIGHT Frame controller")
	check(bindings.get("game_x")=="/user/hand/right/input/y/click","Physical Y still supplies 3DS X during gameplay")
	check(bindings.get("game_y")=="/user/hand/right/input/x/click","Physical X still supplies 3DS Y during gameplay")
	check(bindings.get("game_a")=="/user/hand/right/input/b/click" and bindings.get("game_b")=="/user/hand/right/input/a/click","Existing positional A/B gameplay mapping preserved")
	print("MENU BINDING: %d checks, %d failures"%[checks,failures]);quit(failures)
