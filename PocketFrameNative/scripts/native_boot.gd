extends Node
func _ready() -> void:
	OS.set_environment("POCKETFRAME_GPU","vulkan")
	OS.set_environment("POCKETFRAME_RUNTIME_ROOT",preload("res://scripts/app_paths.gd").root_folder())
	OS.set_environment("POCKETFRAME_PROFILE",ProjectSettings.globalize_path("user://emulator"))
	if "--audit-export" in OS.get_cmdline_user_args():
		get_tree().quit(0 if preload("res://scripts/release_audit.gd").run() else 1)
		return
	if "--lifecycle-smoke" in OS.get_cmdline_user_args():
		add_child(preload("res://scripts/native_validation.gd").new())
		return
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
