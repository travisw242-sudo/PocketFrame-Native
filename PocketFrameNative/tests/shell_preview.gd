extends SceneTree
const Device=preload("res://scripts/handheld.gd")
const Shells=preload("res://scripts/shell_catalog.gd")
const G=preload("res://scripts/geometry.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1600,900)
	var world := Node3D.new();root.add_child(world)
	var env := WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("14222d")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8
	world.add_child(env)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-20,0);light.light_energy=.65
	world.add_child(light)
	for i in range(Shells.ITEMS.size()):
		var device := Device.new();world.add_child(device)
		device.position=Vector3((i%5-2)*.20,0,(i/5)*.19)
		device.set_lid_angle(15)
		device.set_shell_design(Shells.ITEMS[i].id)
		assert(device.shell_design==Shells.ITEMS[i].id)
		assert(device.lid.get_node("LidHousing").material_override is ShaderMaterial)
		G.label(world,Shells.ITEMS[i].name,device.position+Vector3(0,.003,.115),.00007,Color("c8ddd8"))
	var camera := Camera3D.new();world.add_child(camera)
	camera.position=Vector3(0,.88,.38);camera.look_at(Vector3(0,0,.09));camera.fov=65;camera.current=true
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-logs/shell-lineup.png")
	print("SHELL PREVIEW: 10 applied shell designs rendered")
	world.queue_free();quit()
