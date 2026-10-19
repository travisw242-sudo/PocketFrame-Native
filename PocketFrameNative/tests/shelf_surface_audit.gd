extends SceneTree
const Rooms=preload("res://scripts/room_builder.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var room := Rooms.build("teen_2008")
	root.add_child(room)
	var rows := {}
	for node in room.get_node("CollectionShelf").find_children("*","MeshInstance3D",true,false):
		for s in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var a: Vector3=node.global_transform*vertices[indices[i]]
				var b: Vector3=node.global_transform*vertices[indices[i+1]]
				var c: Vector3=node.global_transform*vertices[indices[i+2]]
				if maxf(absf(a.y-b.y),absf(a.y-c.y))>.0001: continue
				var area := (b-a).cross(c-a).length()*.5
				var key := snappedf(a.y,.001)
				rows[key]=rows.get(key,0.0)+area
	print("SHELF HORIZONTAL SURFACES (y: area): ",rows)
	room.free(); quit()
