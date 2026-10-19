extends SceneTree
const Device = preload("res://scripts/handheld.gd")
var device: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1200, 850)
	var world := Node3D.new()
	root.add_child(world)
	device = Device.new()
	world.add_child(device)
	device.position.y = 1
	device.set_stylus_extension(1)
	device.stylus.position.x -= 0.012
	device.stylus.rotation.y = -0.15
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("15202d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -30, 0)
	light.light_energy = 1.8
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.near = 0.002
	camera.position = Vector3(-0.09, 1.014, 0.17)
	camera.look_at(Vector3(-0.03, 1.002, 0.028))
	camera.fov = 46
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://stylus-slot-preview.png"))
	quit()
