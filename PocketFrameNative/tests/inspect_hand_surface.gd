extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene: Node3D = load("res://assets/vendor/xr_hands/Hand_Nails_R.gltf").instantiate()
	root.add_child(scene)
	var mesh: Mesh = scene.find_child("mesh_Hand_Nails_R", true, false).mesh
	var a := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var links: Array = []
	for v in vertices: links.append([])
	for t in range(0, indices.size(), 3):
		for j in range(3):
			links[indices[t + j]].append(indices[t + (j + 1) % 3])
			links[indices[t + j]].append(indices[t + (j + 2) % 3])
	var seen := {}
	for start in range(vertices.size()):
		if seen.has(start): continue
		var stack := [start]
		seen[start] = true
		var count := 0
		var bounds := AABB(vertices[start], Vector3.ZERO)
		var uvs := Rect2(uv[start], Vector2.ZERO)
		while not stack.is_empty():
			var v: int = stack.pop_back()
			count += 1
			bounds = bounds.expand(vertices[v])
			uvs = uvs.expand(uv[v])
			for n in links[v]:
				if not seen.has(n):
					seen[n] = true
					stack.append(n)
		print("COMPONENT vertices=", count, " bounds=", bounds, " uv=", uvs)
	print("HAND vertices=", vertices.size(), " triangles=", indices.size() / 3)
	quit()
