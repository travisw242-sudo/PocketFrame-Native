extends SceneTree
## Code-native vector artwork and typeset wordmark; no licensed game imagery.
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var destination := ProjectSettings.globalize_path("res://tools/preview/artwork")
	DirAccess.make_dir_recursive_absolute(destination)
	for spec in [["portrait",Vector2i(600,900)],["capsule",Vector2i(920,430)],["hero",Vector2i(1920,620)],["logo",Vector2i(960,300)],["icon",Vector2i(256,256)]]:
		var id: String=spec[0];var size: Vector2i=spec[1]
		var vp := SubViewport.new();vp.size=size;vp.disable_3d=true
		vp.transparent_bg=id=="logo";vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
		if id!="logo":
			var bg := ColorRect.new();bg.size=size;bg.color=Color("10232d");vp.add_child(bg)
			for i in range(12):
				var stripe := ColorRect.new();stripe.color=Color(.17,.4,.43,.1)
				stripe.position=Vector2(size.x*(i/12.0),0);stripe.size=Vector2(2,size.y);vp.add_child(stripe)
		var texture := TextureRect.new();texture.texture=load("res://icon.svg")
		texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_size := float(size.x)*.72 if id=="portrait" else float(size.y)*.82
		texture.size=Vector2.ONE*icon_size
		texture.position=Vector2((size.x-icon_size)/2,size.y*.12) if id=="portrait" else Vector2(size.x*.07,(size.y-icon_size)/2)
		if id=="icon":texture.size=size;texture.position=Vector2.ZERO
		if id!="logo":vp.add_child(texture)
		else:texture.free()
		if id!="icon":
			var label := Label.new();label.text="POCKETFRAME";label.add_theme_color_override("font_color",Color("d6f3ed"))
			label.add_theme_font_size_override("font_size",50 if id=="portrait" else 80 if id=="hero" else 54)
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			label.size=Vector2(size.x if id in ["portrait","logo"] else size.x*.6,110)
			label.position=Vector2(0,size.y*.68) if id=="portrait" else Vector2(0,90) if id=="logo" else Vector2(size.x*.36,size.y*.32)
			vp.add_child(label)
			if id!="logo":
				var subtitle := Label.new();subtitle.text="NATIVE PREVIEW  /  VR + AR";subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
				subtitle.add_theme_color_override("font_color",Color("8bb7b0"));subtitle.add_theme_font_size_override("font_size",20 if id=="portrait" else 26)
				subtitle.size=label.size;subtitle.position=label.position+Vector2(0,88);vp.add_child(subtitle)
		await process_frame;await RenderingServer.frame_post_draw
		var error := vp.get_texture().get_image().save_png(destination.path_join(id+".png"))
		if error!=OK:quit(error);return
		vp.queue_free();await process_frame
	print("Created five library artwork assets");quit()
