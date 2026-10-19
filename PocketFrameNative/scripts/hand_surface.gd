extends RefCounted
## One-time Loop refinement of CC0 art. Welded positional topology keeps UV
## seams closed; UVs, tangents and skin bindings remain split where authored.
## Nail masks come from separate nail topology, not approximate UV rectangles.
static var meshes: Dictionary = {}

static func refined(source: Mesh, left: bool) -> ArrayMesh:
	if meshes.has(left): return meshes[left]
	var a := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var links: Array = []
	var colors := PackedColorArray()
	for v in vertices:
		links.append([])
		colors.append(Color(0, 0, 0, 1))
	for t in range(0, indices.size(), 3):
		for j in range(3):
			links[indices[t + j]].append(indices[t + (j + 1) % 3])
			links[indices[t + j]].append(indices[t + (j + 2) % 3])
	var seen := {}
	for start in range(vertices.size()):
		if seen.has(start): continue
		var stack := [start]
		var component: Array[int] = []
		var bounds := AABB(vertices[start], Vector3.ZERO)
		seen[start] = true
		while not stack.is_empty():
			var v: int = stack.pop_back()
			component.append(v)
			bounds = bounds.expand(vertices[v])
			for n in links[v]:
				if not seen.has(n):
					seen[n] = true
					stack.append(n)
		# Five isolated nail patches, excluding the large wrist end cap.
		if component.size() >= 20 and component.size() <= 40 and bounds.size.length() < 0.030:
			for v in component: colors[v] = Color(1, 0.5, 0, 1)
	var welded := {}
	var ids: Array[int] = []
	var points: Array[Vector3] = []
	var neighbors: Array = []
	var boundary: Array = []
	for p in vertices:
		var key := p.snapped(Vector3.ONE * 0.000001)
		if not welded.has(key):
			welded[key] = points.size()
			points.append(p)
			neighbors.append({})
			boundary.append({})
		ids.append(welded[key])
	var edges := {}
	for t in range(0, indices.size(), 3):
		for j in range(3):
			var x: int = ids[indices[t + j]]
			var y: int = ids[indices[t + (j + 1) % 3]]
			var other: int = ids[indices[t + (j + 2) % 3]]
			var key := Vector2i(mini(x, y), maxi(x, y))
			if not edges.has(key): edges[key] = []
			edges[key].append(other)
			neighbors[x][y] = true
			neighbors[y][x] = true
	for key in edges:
		if edges[key].size() == 1:
			boundary[key.x][key.y] = true
			boundary[key.y][key.x] = true
	var smooth: Array[Vector3] = []
	for v in range(points.size()):
		var ns: Array = neighbors[v].keys()
		var bs: Array = boundary[v].keys()
		var p: Vector3 = points[v]
		if bs.size() == 2:
			p = p * 0.75 + (points[bs[0]] + points[bs[1]]) * 0.125
		elif bs.is_empty() and ns.size() >= 3:
			var beta := 3.0 / (8 * ns.size()) if ns.size() > 3 else 3.0 / 16
			p *= 1 - ns.size() * beta
			for n in ns: p += points[n] * beta
		# Preserve the authored wrist termination; smoothing its separate cap
		# and sleeve differently can open a thin seam at the cut-off.
		if points[v].z > 0.019: p = points[v]
		smooth.append(p)
	var out_v := PackedVector3Array()
	for v in range(vertices.size()): out_v.append(smooth[ids[v]])
	var out_uv := uv.duplicate()
	var out_n := normals.duplicate()
	var out_t := tangents.duplicate()
	var out_b := bones.duplicate()
	var out_w := weights.duplicate()
	var out_c := colors.duplicate()
	var out_i := PackedInt32Array()
	var mids := {}
	for t in range(0, indices.size(), 3):
		var triangle: Array[int] = [indices[t], indices[t + 1], indices[t + 2]]
		var middle: Array[int] = []
		for j in range(3):
			var x: int = triangle[j]
			var y: int = triangle[(j + 1) % 3]
			var key := Vector2i(mini(x, y), maxi(x, y))
			if not mids.has(key):
				mids[key] = out_v.size()
				var edge_key := Vector2i(mini(ids[x], ids[y]), maxi(ids[x], ids[y]))
				var p := (vertices[x] + vertices[y]) * 0.5
				if edges[edge_key].size() == 2:
					p = (vertices[x] + vertices[y]) * 0.375 + (points[edges[edge_key][0]] + points[edges[edge_key][1]]) * 0.125
				if vertices[x].z > 0.019 and vertices[y].z > 0.019: p = (vertices[x] + vertices[y]) * 0.5
				out_v.append(p)
				out_uv.append((uv[x] + uv[y]) * 0.5)
				out_n.append((normals[x] + normals[y]).normalized())
				out_c.append(colors[x].lerp(colors[y], 0.5))
				var tangent := Vector3(tangents[x * 4], tangents[x * 4 + 1], tangents[x * 4 + 2]) + Vector3(tangents[y * 4], tangents[y * 4 + 1], tangents[y * 4 + 2])
				tangent = tangent.normalized()
				out_t.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, tangents[x * 4 + 3]]))
				var influences := {}
				for v in [x, y]:
					for slot in range(4):
						var bone: int = bones[v * 4 + slot]
						influences[bone] = float(influences.get(bone, 0)) + weights[v * 4 + slot] * 0.5
				var order: Array = influences.keys()
				order.sort_custom(func(b1, b2): return influences[b1] > influences[b2])
				var total := 0.0
				for slot in range(mini(4, order.size())): total += influences[order[slot]]
				for slot in range(4):
					out_b.append(order[slot] if slot < order.size() else 0)
					out_w.append(float(influences[order[slot]]) / total if slot < order.size() else 0)
			middle.append(mids[key])
		out_i.append_array(PackedInt32Array([triangle[0], middle[0], middle[2], triangle[1], middle[1], middle[0], triangle[2], middle[2], middle[1], middle[0], middle[1], middle[2]]))
	# Separate nail patches need real clearance from the refined fingertip,
	# otherwise two near-coplanar skins shimmer like dirty/cracked nail polish.
	for v in range(out_v.size()):
		if out_c[v].r > 0.5: out_v[v] += out_n[v] * 0.0008
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = out_v
	result[Mesh.ARRAY_NORMAL] = out_n
	result[Mesh.ARRAY_TANGENT] = out_t
	result[Mesh.ARRAY_TEX_UV] = out_uv
	result[Mesh.ARRAY_COLOR] = out_c
	result[Mesh.ARRAY_BONES] = out_b
	result[Mesh.ARRAY_WEIGHTS] = out_w
	result[Mesh.ARRAY_INDEX] = out_i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result)
	meshes[left] = mesh
	return mesh
