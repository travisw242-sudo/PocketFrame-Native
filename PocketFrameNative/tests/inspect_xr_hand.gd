extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var model: Node3D = load("res://assets/vendor/xr_hands/Hand_Nails_R.gltf").instantiate()
	root.add_child(model)
	model.print_tree_pretty()
	var rig: Skeleton3D = model.find_child("Skeleton3D", true, false)
	for b in range(rig.get_bone_count()):
		print(b, " ", rig.get_bone_name(b), " parent=", rig.get_bone_parent(b), " rest=", rig.get_bone_global_rest(b).origin)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		print("MESH ", mesh.name, " ", mesh.get_aabb(), " bind=", mesh.skin.get_bind_count(), " surfaces=", mesh.mesh.get_surface_count())
	var animation: Animation = load("res://assets/vendor/xr_hands/Grip.res")
	for t in range(mini(8, animation.get_track_count())):
		print("ANIM ", animation.track_get_path(t), " type=", animation.track_get_type(t), " first=", animation.track_get_key_value(t, 0))
	quit()
