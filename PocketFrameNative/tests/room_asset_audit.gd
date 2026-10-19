extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var report := {}
	for name in ["SM_Bed","SM_Desk01","Vintage_Computer"]:
		var path: String="res://assets/rooms/motel/"+name+".scn"
		print("DEPENDENCIES ",name," ",ResourceLoader.get_dependencies(path))
		var scene: Node3D=load(path).instantiate()
		var rows: Array=[]
		for node in scene.find_children("*","MeshInstance3D",true,false):
			var triangles := 0
			for s in range(node.mesh.get_surface_count()):
				var mat: StandardMaterial3D=node.get_active_material(s)
				triangles+=node.mesh.surface_get_array_index_len(s)/3
				for property in mat.get_property_list():
					var value=mat.get(property.name)
					if value is Texture2D:
						rows.append({"property":property.name,"width":value.get_width(),"path":value.resource_path})
			rows.append({"triangles":triangles})
		report[name]=rows
		scene.free()
	var file := FileAccess.open("res://test-logs/room-asset-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("AUDIT ",report)
	quit()
