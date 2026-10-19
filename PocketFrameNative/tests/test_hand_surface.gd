extends SceneTree
const Hand = preload("res://scripts/rigged_hand.gd")
var failures := 0
var checks := 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for left in [true, false]:
		var hand := Hand.new()
		root.add_child(hand)
		hand.build(left)
		var mesh: Mesh = hand.skin_mesh.mesh
		var a := mesh.surface_get_arrays(0)
		var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		check(mesh.surface_get_array_index_len(0) / 3 == 13632, "Loop refinement increases hand geometry from 3408 to 13632 triangles")
		var valid := true
		var nails := 0
		for v in range(points.size()):
			valid = valid and points[v].is_finite() and normals[v].is_finite() and normals[v].length() > 0.99
			if colors[v].r > 0.5: nails += 1
			var sum := 0.0
			for slot in range(4):
				var w := weights[v * 4 + slot]
				valid = valid and is_finite(w) and w >= 0 and bones[v * 4 + slot] < 26
				sum += w
			valid = valid and absf(sum - 1) < 0.0001
		check(valid, "Refined normals and four-weight skin bindings remain finite and normalized")
		check(nails > 300 and nails < points.size() / 4, "Clean nail material mask is confined to nail patches")
		var cached := mesh
		for frame in range(20): hand.set_game_inputs({}, Vector2.ZERO, 0.011, "stylus")
		check(hand.skin_mesh.mesh == cached, "Refinement is cached, never rebuilt during animation")
		print("CLEAN HAND left=", left, " vertices=", points.size(), " nail vertices=", nails)
		hand.queue_free()
	print("HAND SURFACE: %d checks, %d failures" % [checks, failures])
	quit(failures)
