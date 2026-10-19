class_name PFCartridgeLibrary
extends RefCounted
## Only the explicitly scoped games folder is scanned. ROM files are read-only.

const Cartridge = preload("res://scripts/game_cartridge.gd")
const GameCase = preload("res://scripts/game_case.gd")
const Metadata = preload("res://scripts/game_metadata.gd")

var entries: Dictionary = {}

func scan_folder(folder: String = "res://games") -> int:
	if folder=="res://games": folder=preload("res://scripts/app_paths.gd").games_folder()
	var directory := DirAccess.open(folder)
	if directory==null: return 0
	var files := directory.get_files()
	files.sort()
	var seen: Dictionary = {}
	for file in files:
		if not file.get_extension().to_lower() in Metadata.FORMATS: continue
		var path := ProjectSettings.globalize_path(folder.path_join(file))
		var id := path.sha256_text().left(16)
		seen[id]=true
		var stamp := str(FileAccess.get_modified_time(path))
		var art := ""
		for extension in ["png","jpg","jpeg","webp"]:
			var sidecar: String=path.get_basename()+"."+extension
			if FileAccess.file_exists(sidecar): art=sidecar; break
		if not art.is_empty(): stamp+="/"+art+"/"+str(FileAccess.get_modified_time(art))
		if entries.has(id) and entries[id].get("stamp","")==stamp: continue
		var metadata := Metadata.read_game(path)
		register_game(id,metadata.display_name,path,art)
		entries[id].icon=metadata.icon
		entries[id].product_code=metadata.product_code
		entries[id].art_source="local label image" if not art.is_empty() else metadata.art_source
		entries[id].stamp=stamp
		entries[id].scanned=true
	for id in entries.keys():
		if entries[id].get("scanned",false) and not seen.has(id): entries.erase(id)
	return entries.size()

func register_game(id: String, display_name: String, content_path: String, cover_path: String = "") -> void:
	entries[id] = {"id": id, "display_name": display_name, "content_path": content_path, "cover_path": cover_path}

func spawn_cartridge(id: String):
	if not entries.has(id):
		return null
	var entry: Dictionary = entries[id]
	var card = Cartridge.new()
	card.configure(str(entry.id), str(entry.display_name), str(entry.content_path))
	var label_loaded: bool=card.set_cover_art_file(str(entry.cover_path))
	if card.cover_art==null: card.cover_art=entry.get("icon",null)
	card.full_label_art=label_loaded
	card.product_code=str(entry.get("product_code",""))
	card.build_visual()
	card.metadata_stamp=str(entry.get("stamp",""))
	return card

func spawn_case(id: String):
	var card = spawn_cartridge(id)
	if card == null:
		return null
	var game_case = GameCase.new()
	game_case.configure(card)
	game_case.set_open(false)
	return game_case
