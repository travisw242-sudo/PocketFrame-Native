extends RefCounted
static func scan(path: String, errors: Array[String]) -> int:
	var directory := DirAccess.open(path)
	if not directory: return 0
	var count := 0
	for file in directory.get_files():
		var full := path.path_join(file)
		count+=1
		if file.get_extension().to_lower() in ["cci","3ds","cia","cxi","3dsx","app","sav","log","pdb","zip"]: errors.append(full)
	for folder in directory.get_directories():
		var full := path.path_join(folder)
		if folder in ["games","Azahar","Library","tests","test-logs","native","tools","motel"]: errors.append(full)
		count+=scan(full,errors)
	return count
static func run() -> bool:
	var errors: Array[String]=[]
	var count := scan("res://",errors)
	print("PACKAGE AUDIT: ",count," resources; forbidden entries: ",errors)
	return errors.is_empty()
