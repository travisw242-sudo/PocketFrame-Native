class_name PFGeometry
extends RefCounted
## All model geometry is authored procedurally, in meters.

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

static func instance(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, title: String = "Part") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

static func rounded(parent: Node3D, size: Vector3, radius: float, bevel: float, mat: Material, pos: Vector3, title: String = "Shell") -> MeshInstance3D:
	return instance(parent, rounded_mesh(size, radius, bevel), mat, pos, title)

static func rounded_mesh(size: Vector3, radius: float, bevel: float) -> ArrayMesh:
	# Rounded rectangle rings with a genuinely curved edge profile, not a texture.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	var steps := 5
	var b := minf(bevel, size.y * 0.49)
	for ring in range(steps * 2 + 2):
		var y: float
		var inset: float
		if ring <= steps:
			var a := float(ring) / steps * PI / 2.0
			y = -size.y / 2.0 + b * (1.0 - cos(a))
			inset = b * (1.0 - sin(a))
		else:
			var a := float(ring - steps - 1) / steps * PI / 2.0
			y = size.y / 2.0 - b + b * sin(a)
			inset = b * (1.0 - cos(a))
		var points := PackedVector3Array()
		var r := maxf(radius - inset, 0.0001)
		for corner in range(4):
			var angle := float(corner) * PI / 2.0
			var cx := (size.x / 2.0 - radius) * (1.0 if corner in [0, 3] else -1.0)
			var cz := (size.z / 2.0 - radius) * (1.0 if corner in [0, 1] else -1.0)
			for j in range(16):
				var t := angle + float(j) / 15.0 * PI / 2.0
				points.append(Vector3(cx + cos(t) * r, y, cz + sin(t) * r))
		rings.append(points)
	for k in range(rings.size() - 1):
		for j in range(rings[k].size()):
			var n := (j + 1) % rings[k].size()
			tri(st, rings[k][j], rings[k + 1][j], rings[k + 1][n])
			tri(st, rings[k][j], rings[k + 1][n], rings[k][n])
	for j in range(rings[0].size()):
		var n := (j + 1) % rings[0].size()
		tri(st, Vector3(0, -size.y / 2.0, 0), rings[0][j], rings[0][n])
		tri(st, Vector3(0, size.y / 2.0, 0), rings[-1][n], rings[-1][j])
	st.generate_normals()
	st.index()
	return st.commit()

static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)

static func tube_z(outer: float, inner: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var a := TAU * float(i) / 32
		var b := TAU * float(i + 1) / 32
		var oa := Vector3(cos(a) * outer, sin(a) * outer, 0)
		var ob := Vector3(cos(b) * outer, sin(b) * outer, 0)
		var ia := Vector3(cos(a) * inner, sin(a) * inner, 0)
		var ib := Vector3(cos(b) * inner, sin(b) * inner, 0)
		var front := Vector3(0, 0, length / 2)
		var back := -front
		for quad in [[oa + back, ob + back, ob + front, oa + front], [ib + back, ia + back, ia + front, ib + front], [oa + front, ob + front, ib + front, ia + front], [oa + back, ia + back, ib + back, ob + back]]:
			tri(st, quad[0], quad[1], quad[2])
			tri(st, quad[0], quad[2], quad[3])
	# Deliberately no disk closing the entrance.
	st.generate_normals()
	return st.commit()

static func cylinder(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3, title: String = "Button") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.94
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	mesh.rings = 3
	return instance(parent, mesh, mat, pos, title)

static func label(parent: Node3D, text: String, pos: Vector3, pixel_size: float = 0.000035, color: Color = Color(0.66, 0.7, 0.73)) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font_size = 48
	node.pixel_size = pixel_size
	node.modulate = color
	node.outline_size = 0
	node.no_depth_test = false
	node.shaded = true
	node.rotation.x = -PI / 2.0
	node.position = pos
	parent.add_child(node)
	return node
