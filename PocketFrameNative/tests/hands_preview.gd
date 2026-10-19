extends SceneTree
const Hand = preload("res://scripts/virtual_hand.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1500, 1100)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202830")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c7d7e5")
	environment.environment.ambient_light_energy = 0.30
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_color = Color("fff1df")
	light.light_energy = 0.95
	light.shadow_enabled = true
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 135, 0)
	fill.light_energy = 0.35
	world.add_child(fill)
	var roles := ["", "", "fist", "console", "stylus", "hinge"]
	for i in range(6):
		var holder := Node3D.new()
		holder.position = Vector3((i % 3 - 1) * 0.20, 0, floorf(float(i) / 3) * 0.27 - 0.135)
		world.add_child(holder)
		var hand := Hand.new()
		holder.add_child(hand)
		hand.build(i == 1)
		if i == 1:
			hand.rotation.z = PI
		hand.set_game_inputs({}, Vector2.ZERO, 1, roles[i] if roles[i] != "fist" else "", {"grip": 1.0 if roles[i] == "fist" else 0.0, "trigger": 1.0 if roles[i] == "fist" else 0.0})
		# This is an anatomical pose sheet, not a controller-alignment fixture.
		hand.transform = Transform3D(Basis(Vector3.BACK, PI) if i == 1 else Basis.IDENTITY, Vector3(0, -0.018, 0.030))
		var label := Label3D.new()
		label.text = ["RELAXED", "PALM / LEFT", "SQUEEZE", "CONSOLE", "STYLUS", "LID"][i]
		label.font_size = 34
		label.pixel_size = 0.00018
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 0.03, -0.125)
		holder.add_child(label)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 0.9, 0.50)
	camera.look_at(Vector3(0, -0.015, 0.02))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.73
	camera.near = 0.01
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://hands-preview.png"))
	quit()
