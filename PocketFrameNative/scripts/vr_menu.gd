extends Node3D
## Real stereo world-space UI. No desktop overlay, native keyboard or OS window.
const SIZE := Vector2(.78,.78)
const PIXELS := Vector2i(1024,1024)
var viewport: SubViewport
var content: VBoxContainer
var keyboard: VBoxContainer
var active_field: LineEdit
var multiplayer_panel
var cursor: MeshInstance3D
var laser: MeshInstance3D
var pointer_down := false
var pointer_armed := false
var last_pixel := Vector2.ZERO
var shift := false
var letters: Array[Button]=[]
var hold_time := 0.0
var toggle_armed := true
var scroll_time := 0.0
var root_control: Control
signal native_view_requested(passthrough: bool)
signal native_quality_requested(quality: String)
signal native_shell_requested(id: String)
const Shells=preload("res://scripts/shell_catalog.gd")
var shell_buttons: Array[Button]=[]
var shell_grid: VBoxContainer
var shell_status: Label
var classic_shell: Button
signal quit_requested
var quit_confirmation: VBoxContainer
var quit_status: Label
var quit_confirm: Button
var native_ar: Button
var native_studio: Button
var native_view_state: Label
var native_ar_reason: Label
var native_quality_buttons: Array[Button]=[]
var native_quality_hint: Label
var native_eye_swap: CheckButton
var grip_help: Label
var games_help: Label
const GRIP_HELP := "HAND GRIP LOCK\nWhile holding the console, press that hand's stick DOWN to lock or unlock its grip. Lock each hand separately, then release the grip buttons."
const GAMES_HELP := "ADD GAMES ON STEAM FRAME\n/home/steamos/.local/share/pocketframe-native/games/\nCopy your own game files here, then restart PocketFrame to refresh the cartridge tray."

func setup(backend: Node, player_name: String) -> void:
	name="HeadsetMenu"
	viewport=SubViewport.new();viewport.size=PIXELS;viewport.disable_3d=true
	viewport.gui_disable_input=false
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(viewport)
	root_control=PanelContainer.new();root_control.size=PIXELS
	var theme := Theme.new();theme.default_font_size=26
	theme.set_constant("minimum_height","Button",48)
	root_control.theme=theme
	var style := StyleBoxFlat.new();style.bg_color=Color("142530")
	style.set_corner_radius_all(18)
	for side in ["left","right","top","bottom"]: style.set("content_margin_"+side,22)
	root_control.add_theme_stylebox_override("panel",style)
	viewport.add_child(root_control)
	var layout := VBoxContainer.new();layout.add_theme_constant_override("separation",12);root_control.add_child(layout)
	var bar := HBoxContainer.new();layout.add_child(bar)
	var title := Label.new();title.text="POCKETFRAME · NATIVE";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.add_child(title)
	_button(bar,"Close",close)
	_button(bar,"Quit app",show_quit_confirmation)
	var help := Label.new();help.text="Point + trigger: click   ·   Right stick: scroll   ·   Hold right Y: close"
	help.add_theme_font_size_override("font_size",20);layout.add_child(help)
	var scroll := ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;layout.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	quit_confirmation=VBoxContainer.new();layout.add_child(quit_confirmation);layout.move_child(quit_confirmation,2)
	quit_status=Label.new();quit_status.text="Save inside your game first. Quitting does not create a save state."
	quit_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;quit_confirmation.add_child(quit_status)
	var quit_row := HBoxContainer.new();quit_confirmation.add_child(quit_row)
	quit_confirm=_button(quit_row,"Quit to library",func():quit_requested.emit())
	_button(quit_row,"Keep playing",func():quit_confirmation.hide())
	quit_confirmation.hide()
	# Keep the view switch outside the scrolling settings body: always visible.
	var view_controls := VBoxContainer.new();layout.add_child(view_controls);layout.move_child(view_controls,2)
	native_view_state=Label.new();native_view_state.text="CURRENT VIEW: STUDIO";view_controls.add_child(native_view_state)
	var view_row := HBoxContainer.new();view_controls.add_child(view_row)
	native_studio=_button(view_row,"Studio · virtual room",func():native_view_requested.emit(false))
	native_ar=_button(view_row,"AR · passthrough",func():native_view_requested.emit(true))
	for button in [native_studio,native_ar]:button.toggle_mode=true;button.custom_minimum_size.y=64
	native_studio.set_pressed_no_signal(true)
	native_ar_reason=Label.new();native_ar_reason.add_theme_font_size_override("font_size",19)
	native_ar_reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;view_controls.add_child(native_ar_reason)
	# Popup windows are not part of the texture receiving our VR pointer input.
	# Keep all choices directly on the world-space panel instead.
	var quality_title := Label.new();quality_title.text="Game resolution";content.add_child(quality_title)
	var quality_row := HBoxContainer.new();content.add_child(quality_row)
	for index in range(3):
		var button := _button(quality_row,["Native 1×","Sharp 2×","Ultra 3×"][index],_choose_native_quality.bind(index))
		button.toggle_mode=true;button.custom_minimum_size.y=60
		native_quality_buttons.append(button)
	native_quality_hint=Label.new();native_quality_hint.text="Applies next app launch. Higher resolution and stereo increase GPU load."
	native_quality_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;native_quality_hint.add_theme_font_size_override("font_size",19);content.add_child(native_quality_hint)
	select_native_quality(0)
	native_eye_swap=CheckButton.new();native_eye_swap.text="Swap stereoscopic eyes";content.add_child(native_eye_swap)
	var shell_toggle := _button(content,"Console shells · show designs",func():pass)
	shell_toggle.toggle_mode=true
	shell_grid=VBoxContainer.new();content.add_child(shell_grid)
	shell_toggle.toggled.connect(func(on: bool):shell_grid.visible=on;shell_toggle.text="Console shells · hide designs" if on else "Console shells · show designs")
	var swatches := GridContainer.new();swatches.columns=3;swatches.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	swatches.add_theme_constant_override("h_separation",10);swatches.add_theme_constant_override("v_separation",10);shell_grid.add_child(swatches)
	for i in range(Shells.ITEMS.size()):
		var button := _button(swatches,"",_choose_shell.bind(Shells.ITEMS[i].id))
		button.custom_minimum_size=Vector2(240,136);button.toggle_mode=true;shell_buttons.append(button)
		var swatch := ColorRect.new();swatch.position=Vector2(10,7);swatch.size=Vector2(220,82)
		# Same artwork/procedural shaders as the Windows launcher's swatches.
		swatch.material=Shells.material(i,true);swatch.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(swatch)
		var label := Label.new();label.text=Shells.ITEMS[i].name;label.position=Vector2(0,97);label.size.x=240
		label.add_theme_font_size_override("font_size",21);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(label)
	classic_shell=_button(shell_grid,"Classic Graphite",_choose_shell.bind(""));classic_shell.toggle_mode=true
	shell_status=Label.new();shell_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;shell_status.add_theme_font_size_override("font_size",20)
	shell_grid.add_child(shell_status);select_native_shell("");shell_grid.hide()
	grip_help=Label.new();grip_help.text=GRIP_HELP;grip_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	grip_help.add_theme_font_size_override("font_size",24);content.add_child(grip_help)
	games_help=Label.new();games_help.text=GAMES_HELP;games_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	games_help.add_theme_font_size_override("font_size",24);content.add_child(games_help)
	multiplayer_panel=preload("res://scripts/multiplayer_panel.gd").new();content.add_child(multiplayer_panel)
	multiplayer_panel.setup(backend,player_name,1.6)
	for field in [multiplayer_panel.nickname,multiplayer_panel.address,multiplayer_panel.password,multiplayer_panel.port.get_line_edit()]:
		field.virtual_keyboard_enabled=false
		field.focus_entered.connect(func(): show_keyboard(field);scroll.ensure_control_visible.call_deferred(field))
	keyboard=VBoxContainer.new();layout.add_child(keyboard)
	for row in ["1234567890","qwertyuiop","asdfghjkl","zxcvbnm.-:"]:
		var line := HBoxContainer.new();keyboard.add_child(line)
		for character in row:
			var key := _button(line,character,_type.bind(character))
			if character.to_upper()!=character: letters.append(key)
	var tools := HBoxContainer.new();keyboard.add_child(tools)
	_button(tools,"Shift",_shift)
	_button(tools,"Space",_type.bind(" "))
	_button(tools,"_",_type.bind("_"))
	_button(tools,"/",_type.bind("/"))
	_button(tools,"Backspace",_backspace)
	_button(tools,"Done",func():multiplayer_panel.port.apply();keyboard.hide();active_field=null;viewport.gui_release_focus())
	keyboard.hide()
	var quad := QuadMesh.new();quad.size=SIZE
	var screen := MeshInstance3D.new();screen.mesh=quad
	var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture=viewport.get_texture();material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode=BaseMaterial3D.CULL_BACK
	screen.material_override=material;add_child(screen)
	var sphere := SphereMesh.new();sphere.radius=.004;sphere.height=.008
	var pointer_material := StandardMaterial3D.new();pointer_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;pointer_material.albedo_color=Color("8cecc5")
	cursor=MeshInstance3D.new();cursor.mesh=sphere;cursor.material_override=pointer_material;add_child(cursor)
	laser=MeshInstance3D.new();laser.mesh=ImmediateMesh.new();laser.material_override=pointer_material;add_child(laser)
	close()

func update_native_view(active: bool, available: bool, explanation: String) -> void:
	native_ar.set_pressed_no_signal(active);native_ar.disabled=not available
	native_studio.set_pressed_no_signal(not active);native_studio.disabled=false
	native_view_state.text="CURRENT VIEW: "+("AR PASSTHROUGH" if active else "STUDIO")
	native_ar_reason.text="Switch views instantly. AR does not detect real furniture." if available else explanation

func select_native_quality(index: int) -> void:
	for i in range(native_quality_buttons.size()):
		native_quality_buttons[i].set_pressed_no_signal(i==clampi(index,0,2))

func _choose_native_quality(index: int) -> void:
	select_native_quality(index)
	native_quality_hint.text="%s selected · restart PocketFrame to apply." % ["Native 1×","Sharp 2×","Ultra 3×"][index]
	native_quality_requested.emit(["balanced","sharp","ultra"][index])

func quality_saved(ok: bool) -> void:
	if ok:native_quality_hint.text+=" Settings saved. Use Quit app, then relaunch to apply."
	else:native_quality_hint.text="Could not save settings. Check free space; keep the app open and retry."

func select_native_shell(id: String) -> void:
	var index: int=Shells.index(id)
	for i in range(shell_buttons.size()):shell_buttons[i].set_pressed_no_signal(i==index)
	classic_shell.set_pressed_no_signal(index<0)
	shell_status.text="Selected: "+(Shells.ITEMS[index].name if index>=0 else "Classic Graphite")+" · applies immediately"

func _choose_shell(id: String) -> void:
	if not id.is_empty() and Shells.index(id)<0:return
	select_native_shell(id);native_shell_requested.emit(id)

func shell_saved(ok: bool) -> void:
	shell_status.text+=" · saved" if ok else " · could not save; choice may not survive relaunch"

func show_quit_confirmation() -> void:
	keyboard.hide();quit_confirmation.show()

func show_quitting(detail: String) -> void:
	quit_confirmation.show();quit_confirm.disabled=true;quit_status.text=detail

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new();button.text=text;button.focus_mode=Control.FOCUS_NONE
	button.custom_minimum_size=Vector2(0,48);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback);parent.add_child(button);return button

func show_keyboard(field: LineEdit) -> void:
	active_field=field;keyboard.show()

func _type(character: String) -> void:
	if not is_instance_valid(active_field):return
	active_field.insert_text_at_caret(character.to_upper() if shift else character)
	active_field.text_changed.emit(active_field.text)

func _backspace() -> void:
	if not is_instance_valid(active_field):return
	if active_field.has_selection():
		active_field.delete_text(active_field.get_selection_from_column(),active_field.get_selection_to_column())
	elif active_field.caret_column>0:
		var caret := active_field.caret_column
		active_field.delete_text(caret-1,caret);active_field.caret_column=caret-1
	active_field.text_changed.emit(active_field.text)

func _shift() -> void:
	shift=not shift
	for button in letters:button.text=button.text.to_upper() if shift else button.text.to_lower()

func toggle_gesture(delta: float, pressed: bool, eligible: bool) -> bool:
	if not pressed:
		hold_time=0;toggle_armed=true;return false
	if not eligible or not toggle_armed:hold_time=0;return false
	hold_time+=delta
	if hold_time<.8:return false
	toggle_armed=false;hold_time=0;return true

func open_at(head: Transform3D) -> void:
	var forward := -head.basis.z;forward.y=0
	if forward.length_squared()<.001:forward=Vector3.FORWARD
	forward=forward.normalized()
	global_transform=Transform3D(Basis.looking_at(forward,Vector3.UP),head.origin+forward*.9+Vector3(0,.02,0))
	show();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	pointer_armed=false
	cursor.hide();laser.hide()

func close() -> void:
	if viewport:
		_release_pointer()
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if keyboard:keyboard.hide()
	active_field=null
	hide()

func ray_pixel(origin: Vector3, direction: Vector3) -> Vector2:
	var local_origin := to_local(origin)
	var local_direction := global_basis.inverse()*direction
	if local_direction.z>=-.0001:return Vector2(-1,-1)
	var distance := -local_origin.z/local_direction.z
	if distance<0 or distance>3:return Vector2(-1,-1)
	var point := local_origin+local_direction*distance
	var uv := Vector2(point.x/SIZE.x+.5,.5-point.y/SIZE.y)
	if uv.x<0 or uv.y<0 or uv.x>1 or uv.y>1:return Vector2(-1,-1)
	return uv*Vector2(PIXELS)

func _release_pointer() -> void:
	pointer_armed=false
	if not pointer_down:return
	var away := InputEventMouseMotion.new();away.position=Vector2(-100,-100);viewport.push_input(away,true)
	var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;event.position=Vector2(-100,-100)
	viewport.push_input(event,true);pointer_down=false

func pointer_step(delta: float, pose: Transform3D, tracked: bool, down: bool, scroll_axis: float) -> void:
	if not visible:return
	if not down:pointer_armed=true
	if not pointer_armed:down=false
	scroll_time=maxf(0,scroll_time-delta)
	var pixel := ray_pixel(pose.origin,-pose.basis.z) if tracked else Vector2(-1,-1)
	var hit := pixel.x>=0
	cursor.visible=hit;laser.visible=hit
	if not hit:
		_release_pointer();return
	var point := Vector3((pixel.x/PIXELS.x-.5)*SIZE.x,(.5-pixel.y/PIXELS.y)*SIZE.y,.003)
	cursor.position=point
	var beam := laser.mesh as ImmediateMesh;beam.clear_surfaces();beam.surface_begin(Mesh.PRIMITIVE_LINES)
	beam.surface_add_vertex(to_local(pose.origin));beam.surface_add_vertex(point);beam.surface_end()
	var motion := InputEventMouseMotion.new();motion.position=pixel;motion.relative=pixel-last_pixel;motion.button_mask=MOUSE_BUTTON_MASK_LEFT if pointer_down else 0
	viewport.push_input(motion,true);last_pixel=pixel
	if down!=pointer_down:
		var click := InputEventMouseButton.new();click.position=pixel;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
		click.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		pointer_down=down;viewport.push_input(click,true)
	if absf(scroll_axis)>.5 and scroll_time<=0:
		var wheel := InputEventMouseButton.new();wheel.position=pixel;wheel.button_index=MOUSE_BUTTON_WHEEL_UP if scroll_axis>0 else MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
		viewport.push_input(wheel,true);wheel.pressed=false;viewport.push_input(wheel,true);scroll_time=.1
