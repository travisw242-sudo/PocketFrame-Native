extends RefCounted
static func packaged() -> bool:
	return not OS.has_feature("editor")
static func root_folder() -> String:
	return OS.get_executable_path().get_base_dir() if packaged() else ProjectSettings.globalize_path("res://")
static func games_folder() -> String:
	return root_folder().path_join("games")
static func logs_folder() -> String:
	var path := ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(path)
	return path
