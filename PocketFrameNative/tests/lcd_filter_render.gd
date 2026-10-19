extends SceneTree
var failures := 0
func check(ok: bool, title: String) -> void:
	print(title,": ","PASS" if ok else "FAIL")
	if not ok:failures+=1
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var viewport := SubViewport.new();viewport.size=Vector2i(512,256)
	viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1
	camera.position=Vector3(0,0,2);viewport.add_child(camera);camera.current=true
	var image := Image.create(800,480,false,Image.FORMAT_RGBA8)
	for y in range(480):
		for x in range(800):image.set_pixel(x,y,Color.WHITE if (x+y)%2==0 else Color.BLACK)
	var checker := ImageTexture.create_from_image(image)
	var atlas := Image.create(800,240,false,Image.FORMAT_RGBA8);atlas.fill(Color.RED)
	atlas.fill_rect(Rect2i(400,0,400,240),Color.BLUE)
	var stereo := ImageTexture.create_from_image(atlas)
	for i in range(4):
		var quad := MeshInstance3D.new();var mesh := QuadMesh.new();mesh.size=Vector2(.45,.45)
		quad.mesh=mesh;quad.position.x=-.75+i*.5;viewport.add_child(quad)
		if i==0:
			var mat := StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_texture=checker;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;quad.material_override=mat
		else:
			var mat := ShaderMaterial.new();mat.shader=preload("res://scripts/stereo_lcd.gdshader")
			mat.set_shader_parameter("lcd_image",checker if i==1 else stereo)
			mat.set_shader_parameter("stereo_image",i>=2);mat.set_shader_parameter("swap_eyes",i==3)
			quad.material_override=mat
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	var noise: Array[float]=[]
	for center in [64,192]:
		var samples: Array[float]=[];var total := 0.0
		for y in range(96,160):
			for x in range(center-32,center+32):
				var value := capture.get_pixel(x,y).r;samples.append(value);total+=value
		var mean := total/samples.size();var variance := 0.0
		for value in samples:variance+=(value-mean)*(value-mean)
		noise.append(variance/samples.size())
	print("Minified variance nearest=",noise[0]," filtered=",noise[1])
	check(noise[0]>.05 and noise[1]<noise[0]*.5,"Distance filter reduces high-frequency aliasing")
	var left := capture.get_pixel(320,128);var right := capture.get_pixel(448,128)
	check(left.r>.9 and left.b<.05,"Left eye remains red without right-eye bleed")
	check(right.b>.9 and right.r<.05,"Swapped eye remains blue without left-eye bleed")
	var destination := ProjectSettings.globalize_path("res://../outputs/native-tests/lcd-filter-validation.png")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):destination=arg.trim_prefix("--capture=")
	check(capture.save_png(destination)==OK,"Visual evidence saved")
	print("LCD GPU RENDER failures: ",failures);quit(failures)
