extends SceneTree
## Reproducible semantic bindings, with an explicit Steam Frame profile.
var actions: Dictionary = {}
func _initialize() -> void:
	var map := OpenXRActionMap.new()
	var action_set := OpenXRActionSet.new()
	action_set.resource_name = "pocketframe"
	action_set.localized_name = "PocketFrame controls"
	map.add_action_set(action_set)
	var types := {"grip_pose": 3, "aim_pose": 3, "haptic": 4, "primary": 2, "squeeze": 1, "squeeze_click": 0, "trigger": 1,
		"primary_click": 0, "bumper": 0, "game_a": 0, "game_b": 0, "game_x": 0, "game_y": 0,
		"game_start": 0, "game_select": 0, "dpad_up": 0, "dpad_down": 0, "dpad_left": 0, "dpad_right": 0}
	for title in types:
		var action := OpenXRAction.new()
		action.resource_name = title
		action.localized_name = str(title).replace("_", " ").capitalize()
		action.action_type = types[title]
		action.toplevel_paths = PackedStringArray(["/user/hand/left", "/user/hand/right"])
		action_set.add_action(action)
		actions[title] = action
	var frame := OpenXRInteractionProfile.new()
	frame.interaction_profile_path = "/interaction_profiles/valve/frame_controller_valve"
	map.add_interaction_profile(frame)
	var touch := OpenXRInteractionProfile.new()
	touch.interaction_profile_path = "/interaction_profiles/oculus/touch_controller"
	map.add_interaction_profile(touch)
	for profile in [frame, touch]:
		for hand in ["left", "right"]:
			for pair in [["grip_pose", "input/grip/pose"], ["aim_pose", "input/aim/pose"], ["primary", "input/thumbstick"],
				["primary_click", "input/thumbstick/click"], ["squeeze", "input/squeeze/value"], ["trigger", "input/trigger/value"], ["haptic", "output/haptic"]]:
				bind(profile, pair[0], hand, pair[1])
			bind(profile, "bumper", hand, "input/bumper/click" if profile == frame else "input/trigger/value")
			if profile == frame:
				bind(profile, "squeeze_click", hand, "input/squeeze/click")
	# Nintendo diamond positions: A=east, B=south, X=north, Y=west.
	for pair in [["a", "b"], ["b", "a"], ["x", "y"], ["y", "x"]]:
		bind(frame, "game_" + pair[0], "right", "input/" + pair[1] + "/click")
	for direction in ["up", "down", "left", "right"]:
		bind(frame, "dpad_" + direction, "left", "input/dpad_" + direction + "/click")
	bind(frame, "game_start", "right", "input/menu/click")
	bind(frame, "game_select", "left", "input/view/click")
	bind(touch, "game_a", "right", "input/a/click")
	bind(touch, "game_b", "right", "input/b/click")
	bind(touch, "game_x", "left", "input/x/click")
	bind(touch, "game_y", "left", "input/y/click")
	bind(touch, "game_start", "left", "input/menu/click")
	var result := ResourceSaver.save(map, "res://openxr_action_map.tres")
	print("Action map saved: ", result, "; profiles: ", map.get_interaction_profile_count())
	quit(result)

func bind(profile: OpenXRInteractionProfile, action: String, hand: String, path: String) -> void:
	var binding := OpenXRIPBinding.new()
	binding.action = actions[action]
	binding.binding_path = "/user/hand/" + hand + "/" + path
	var bindings: Array = profile.bindings.duplicate()
	bindings.append(binding)
	profile.bindings = bindings
