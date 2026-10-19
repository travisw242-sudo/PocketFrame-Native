extends SceneTree
const Hand = preload("res://scripts/virtual_hand.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for left in [false, true]:
		var hand := Hand.new()
		root.add_child(hand)
		hand.build(left)
		for size in [0.8, 1.0, 1.6, 2.0]:
			for sample in [Vector3.ZERO, Vector3(1, 1, 1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, -1, 1)]:
				checks += 1
				var press: bool = sample.z > 0
				var console := Transform3D(Basis.from_euler(Vector3(0.3, -0.45, 0.2)).scaled(Vector3.ONE * size), Vector3(0.2, 1, -0.3))
				hand.set_game_inputs({"A": press, "UP": press}, Vector2(sample.x, sample.y), 1, "console", {"console_world": console, "trigger": sample.z})
				hand.skeleton.force_update_all_bone_transforms()
				var transforms: Array[Transform3D] = []
				for bone in range(16):
					transforms.append(console.affine_inverse() * hand.skeleton.global_transform * hand.skeleton.get_bone_global_pose(bone) * hand.skeleton.get_bone_global_rest(bone).affine_inverse())
				var hits := 0
				var by_bone := {}
				for surface in range(2):
					var arrays: Array = hand.skin_mesh.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
					var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
					for v in range(vertices.size()):
						var p := Vector3.ZERO
						for slot in range(4):
							p += (transforms[ids[v * 4 + slot]] * vertices[v]) * weights[v * 4 + slot]
						# Conservative interior: ignore bevels and sub-mm contact.
						if absf(p.x) < 0.0775 and absf(p.z) < 0.045 and p.y > -0.0065 and p.y < 0.007:
							hits += 1
							var title: String = hand.skeleton.get_bone_name(ids[v * 4])
							by_bone[title] = by_bone.get(title, 0) + 1
				if hits > 0:
					failures += 1
					push_error("CLEARANCE left=%s size=%s input=%s hits=%s bones=%s" % [left, size, sample, hits, by_bone])
		hand.queue_free()
	print("HAND CLEARANCE: %d poses, %d failures" % [checks, failures])
	quit(failures)
