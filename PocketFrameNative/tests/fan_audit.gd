extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var scene: Node3D=load("res://assets/rooms/motel/SM_PedestalFan.scn").instantiate()
	root.add_child(scene)
	for node in scene.find_children("*","MeshInstance3D",true,false):
		print(node.name," transform=",node.global_transform," bounds=",node.get_aabb())
		for s in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(s)
			print("SURFACE ",s," material=",node.mesh.surface_get_material(s).resource_name," vertices=",arrays[Mesh.ARRAY_VERTEX].size())
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var parents: Array[int]=[]
			var by_position := {}
			for v in vertices.size():
				var key := vertices[v].snapped(Vector3.ONE*.00001)
				parents.append(by_position.get(key,v));by_position[key]=parents[v]
			for t in range(0,indices.size(),3):
				var a := leader(parents,indices[t])
				for k in [1,2]: parents[leader(parents,indices[t+k])]=a
			var groups := {}
			for v in vertices.size():
				var group := leader(parents,v)
				if not groups.has(group): groups[group]=AABB(vertices[v],Vector3.ZERO)
				else: groups[group]=groups[group].expand(vertices[v])
			var removed := {}
			for group in groups:
				var bounds: AABB=groups[group]
				# Only the separate cable and loose plug. Fan base/stand are preserved.
				if (bounds.position.z<-.24 and bounds.end.y<.02) or (bounds.position.z<-.24 and bounds.size.y>1 and bounds.size.x<.3): removed[group]=true
			var kept := PackedInt32Array()
			for t in range(0,indices.size(),3):
				if removed.has(leader(parents,indices[t])): continue
				for k in range(3): kept.append(indices[t+k])
			arrays[Mesh.ARRAY_INDEX]=kept
			var clean := ArrayMesh.new()
			clean.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			clean.surface_set_material(0,node.mesh.surface_get_material(s))
			node.mesh=clean
			print("REPLACED FAN CORD: ",removed.size()," components; retained ",kept.size()/3," triangles")
	var packed := PackedScene.new()
	packed.pack(scene)
	var result := ResourceSaver.save(packed,"res://assets/rooms/motel/SM_PedestalFan_Connected.scn",ResourceSaver.FLAG_COMPRESS)
	assert(result==OK)
	scene.free()
	quit()
func leader(parents: Array[int], i: int) -> int:
	while parents[i]!=i:
		parents[i]=parents[parents[i]]
		i=parents[i]
	return i
