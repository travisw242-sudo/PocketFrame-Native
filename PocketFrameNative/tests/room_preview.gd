extends SceneTree
const Rooms=preload("res://scripts/room_builder.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1440,1080)
	var room := Rooms.build("teen_2008")
	root.add_child(room)
	Rooms.place_dock(room,Transform3D(Basis.IDENTITY,Vector3(0,1.03,-.48)))
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("617a90")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d4dfec")
	env.environment.ambient_light_energy=.35
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-52,-23,0)
	sun.light_energy=.75
	root.add_child(sun)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov=76
	camera.near=.025
	camera.current=true
	var mesh_count := 0
	for mesh in room.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh: mesh_count+=1
	print("ROOM PREVIEW: meshes ",mesh_count)
	for spec in [["overview",Vector3(1.85,1.7,1.62),Vector3(-.1,1,-1.0)],["seated",Vector3(.8,1.3,-1.22),Vector3(.65,.85,-2.1)],["collection",Vector3(-.3,1.55,1.48),Vector3(1.6,1,-.6)],["fan",Vector3(-.6,1.15,1.1),Vector3(-1.85,.57,.65)],["door",Vector3(.4,1.2,1.1),Vector3(.58,1,1.8)]]:
		camera.position=spec[1]
		camera.look_at(spec[2])
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-logs/bedroom-"+spec[0]+".png")
	quit()
