class_name PFHandheld
extends Node3D

const G = preload("res://scripts/geometry.gd")
const Screen = preload("res://scripts/screen_canvas.gd")
const CartridgeSlot = preload("res://scripts/cartridge_slot.gd")
const StylusMotion = preload("res://scripts/stylus_motion.gd")
const BOTTOM_SIZE := Vector2(0.078, 0.0585)
const VOLUME_MIN_Z := 0.022
const VOLUME_MAX_Z := -0.002
const VOLUME_TRAVEL := VOLUME_MIN_Z - VOLUME_MAX_Z
signal volume_changed(level: float)
var lid: Node3D
var bottom_surface: MeshInstance3D
var upper_surface: MeshInstance3D
var top_canvas: PFScreenCanvas
var bottom_canvas: PFScreenCanvas
var body_material: StandardMaterial3D
var shell_design := ""

func set_shell_design(id: String) -> void:
	var catalog=preload("res://scripts/shell_catalog.gd")
	var i: int=catalog.index(id)
	shell_design=id if i>=0 else ""
	var lid_shell := lid.get_node("LidHousing") as MeshInstance3D
	var housing := get_node("LowerHousing") as CSGMesh3D
	if i<0:
		lid_shell.material_override=body_material
		housing.material=body_material
		return
	body_material.albedo_color=Color(catalog.ITEMS[i].base)
	lid_shell.material_override=catalog.material(i)
	var lower: ShaderMaterial=catalog.material(i).duplicate()
	lower.set_shader_parameter("panel_size",Vector2(.158,.094))
	lower.set_shader_parameter("center_z",0.0)
	housing.material=lower
var buttons: Dictionary = {}
var button_rest: Dictionary = {}
var circle_pad: Node3D
var lid_angle := 145.0
var top_viewport: SubViewport
var bottom_viewport: SubViewport
var cartridge_slot
var volume_slider: Node3D
var depth_slider: Node3D
var stylus: Node3D
var volume_level := 0.7
var depth_level := 0.0
signal depth_changed(value: float)
var stereo_material: ShaderMaterial
var bottom_lcd_material: ShaderMaterial
var idle_upper_material: Material
var idle_bottom_material: Material
var stereo_swap_eyes := false
var stylus_extension := 0.0
var interaction_hint: Label3D
var volume_readout: Label3D
var volume_thumb_material: StandardMaterial3D
var stylus_side := "left"
var stylus_auto_return := true
var stylus_grip_angle := 25.0
var hand_pitch := 0.0
var hand_roll := 0.0
var hand_offset := 0.0

func stylus_stored_position() -> Vector3:
	var pos := StylusMotion.STORED
	pos.x = absf(pos.x) if stylus_side == "right" else -absf(pos.x)
	return pos

func stylus_mouth_position() -> Vector3:
	var pos := stylus_stored_position()
	pos.z = StylusMotion.MOUTH.z
	return pos

func set_stylus_side(side: String) -> void:
	stylus_side = "right" if side == "right" else "left"
	var x := stylus_stored_position().x
	var bore := get_node_or_null("LowerHousing/StylusBore") as Node3D
	var well := get_node_or_null("StylusWell") as Node3D
	if bore:
		bore.position.x = x
	if well:
		well.position.x = x
	if is_instance_valid(stylus) and stylus.get_parent() == self:
		set_stylus_extension(stylus_extension)

func show_interaction_hint(target: String) -> void:
	if not is_instance_valid(interaction_hint):
		interaction_hint = Label3D.new()
		interaction_hint.font_size = 32
		interaction_hint.pixel_size = 0.00014
		interaction_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		interaction_hint.modulate = Color("82e1c4")
		add_child(interaction_hint)
	interaction_hint.visible = not target.is_empty()
	if target.is_empty():
		return
	interaction_hint.text = "GRIP · " + ("STYLUS" if target == "stylus" else "LID")
	interaction_hint.position = to_local(stylus_handle_position()) + Vector3(0, 0.022, 0) if target == "stylus" else to_local(lid.to_global(Vector3(0, 0.003, -0.084))) + Vector3(0, 0.022, 0)

func _ready() -> void:
	build()

func build() -> void:
	body_material = G.material(Color("303841"), 0.30, 0.27)
	body_material.clearcoat_enabled = true
	body_material.clearcoat = 0.32
	body_material.clearcoat_roughness = 0.24
	var black := G.material(Color("080c12"), 0.1, 0.28)
	var matte := G.material(Color("21272f"), 0.1, 0.47)
	var seam := G.material(Color("10151b"), 0.1, 0.5)
	var rim := G.material(Color("65717b"), 0.65, 0.27)
	var rubber := G.material(Color("555f67"), 0, 0.78)
	var silver := G.material(Color("89959f"), 0.72, 0.21)
	# Multi-layer lower shell, seam, rim and molded top deck.
	# Real subtraction through the front wall, not a dark disk over a solid mesh.
	var housing := CSGMesh3D.new()
	housing.name = "LowerHousing"
	housing.snap = 0.00001
	housing.mesh = G.rounded_mesh(Vector3(0.158, 0.009, 0.094), 0.010, 0.002)
	housing.material = body_material
	housing.position = Vector3(0, -0.003, 0)
	add_child(housing)
	var bore := CSGCylinder3D.new()
	bore.name = "StylusBore"
	bore.snap = 0.00001
	bore.operation = CSGShape3D.OPERATION_SUBTRACTION
	bore.radius = 0.0028
	bore.height = 0.060
	bore.sides = 32
	bore.rotation.x = PI / 2
	bore.position = Vector3(-0.050, 0, 0.020)
	housing.add_child(bore)
	# Real rear opening, wide enough for the keyed 35 mm card, not a black decal.
	var card_bore := CSGBox3D.new()
	card_bore.name="GameCardOpening"
	card_bore.snap=.00001
	card_bore.operation=CSGShape3D.OPERATION_SUBTRACTION
	card_bore.size=Vector3(.0356,.0046,.038)
	card_bore.position=Vector3(.019,.001,-.031)
	housing.add_child(card_bore)
	G.rounded(self, Vector3(0.1583, 0.0011, 0.0943), 0.010, 0.00035, seam, Vector3(0, 0.0016, 0), "HousingSeam")
	G.rounded(self, Vector3(0.1582, 0.0022, 0.0942), 0.010, 0.0007, rim, Vector3(0, 0.0029, 0), "SatinEdge")
	G.rounded(self, Vector3(0.1577, 0.005, 0.0937), 0.010, 0.0015, body_material, Vector3(0, 0.0055, 0), "ControlDeck")
	G.rounded(self, Vector3(0.086, 0.0014, 0.066), 0.004, 0.0005, black, Vector3(0, 0.0082, 0.004), "TouchBezel")
	bottom_viewport = _screen_viewport(false)
	bottom_canvas = bottom_viewport.get_child(0)
	bottom_surface = _screen(self, BOTTOM_SIZE, bottom_viewport.get_texture(), Vector3(0, 0.009, 0.004), "TouchLCD")
	idle_bottom_material=bottom_surface.material_override
	# Circle pad has a recessed socket, rubber cap, and concentric inset.
	G.cylinder(self, 0.012, 0.001, black, Vector3(-0.059, 0.0084, -0.020), "CirclePadSocket")
	circle_pad = Node3D.new()
	circle_pad.position = Vector3(-0.059, 0.0103, -0.020)
	add_child(circle_pad)
	G.cylinder(circle_pad, 0.0103, 0.003, rubber, Vector3.ZERO, "CirclePad")
	G.cylinder(circle_pad, 0.008, 0.00025, G.material(Color("657078"), 0, 0.82), Vector3(0, 0.00155, 0))
	# D-pad uses one shared node so every directional press depresses the cap.
	var dpad := Node3D.new()
	dpad.position = Vector3(-0.059, 0.0097, 0.012)
	add_child(dpad)
	G.rounded(dpad, Vector3(0.021, 0.0022, 0.007), 0.001, 0.0005, matte, Vector3.ZERO, "DPadHorizontal")
	G.rounded(dpad, Vector3(0.007, 0.0023, 0.021), 0.001, 0.0005, matte, Vector3.ZERO, "DPadVertical")
	G.cylinder(dpad, 0.0027, 0.00015, black, Vector3(0, 0.0013, 0))
	buttons["D-PAD"] = dpad
	button_rest["D-PAD"] = dpad.position
	for key in ["A", "B", "X", "Y"]:
		var offset: Vector2 = {"A": Vector2(0.010, 0), "B": Vector2(0, 0.010), "X": Vector2(0, -0.010), "Y": Vector2(-0.010, 0)}[key]
		var pos := Vector3(0.058 + offset.x, 0.0095, -0.007 + offset.y)
		G.cylinder(self, 0.0054, 0.0006, black, pos - Vector3(0, 0.001, 0), key + "Socket")
		var cap := G.cylinder(self, 0.0047, 0.0028, matte, pos, key)
		G.label(cap, key, Vector3(0, 0.0015, 0), 0.000045, Color("c0c7cd"))
		buttons[key] = cap
		button_rest[key] = pos
	for i in range(2):
		var key: String = ["SELECT", "START"][i]
		var pos := Vector3(0.057, 0.0087, 0.020 + i * 0.009)
		var cap := G.cylinder(self, 0.0022, 0.0011, matte, pos, key)
		buttons[key] = cap
		button_rest[key] = pos
		G.label(self, key, pos + Vector3(-0.010, 0.0005, 0), 0.000016)
	G.cylinder(self, 0.0036, 0.0011, rubber, Vector3(0.049, 0.009, -0.030), "CStick")
	# Home button and power detail.
	G.rounded(self, Vector3(0.012, 0.0008, 0.004), 0.0018, 0.0002, matte, Vector3(0, 0.0084, 0.039), "HomeKey")
	G.label(self, "HOME", Vector3(0, 0.009, 0.039), 0.000019)
	G.label(self, "MIC", Vector3(-0.020, 0.0086, 0.039), 0.000014)
	G.cylinder(self, 0.00065, 0.0002, black, Vector3(-0.013, 0.0086, 0.039), "Microphone")
	# Shoulder controls, ports and visible edge detailing.
	for i in [-1, 1]:
		var key: String = "L" if i == -1 else "R"
		var p := Vector3(i * 0.063, 0.006, -0.044)
		var cap := G.rounded(self, Vector3(0.024, 0.006, 0.008), 0.003, 0.0013, matte, p, key)
		buttons[key] = cap
		button_rest[key] = p
		G.label(cap, key, Vector3(0, 0.0032, 0), 0.00003)
		for z in [-0.033, 0.033]:
			var screw := G.cylinder(self, 0.0018, 0.00025, silver, Vector3(i * 0.063, -0.0076, z), "Screw")
			G.rounded(screw, Vector3(0.002, 0.0001, 0.00035), 0.00015, 0.00003, black, Vector3(0, -0.00015, 0))
	# Open mouth: four thin lips, never a solid black plate across the opening.
	var mouth := Node3D.new()
	mouth.name="CartridgeSlot"
	mouth.position=Vector3(.019,-.002,-.0473)
	add_child(mouth)
	for y in [-.0025,.0025]:
		G.rounded(mouth,Vector3(.0364,.00035,.0014),.00015,.00008,matte,Vector3(0,y,.0004),"SlotLip")
	for x in [-.018,.018]:
		G.rounded(mouth,Vector3(.0004,.0048,.0014),.00015,.00008,matte,Vector3(x,0,.0004),"SlotCheek")
	# A lined tunnel with visible floor, ceiling, guide rails and contacts.
	# Its rear wall sits INSIDE the boolean cut so the opening has real depth.
	G.rounded(self,Vector3(.035,.0045,.0004),.0002,.00008,black,Vector3(.019,-.002,-.013),"CardWellBack")
	for y in [-.00412,.00012]:
		G.rounded(self,Vector3(.035,.00022,.033),.0002,.00006,black,Vector3(.019,y,-.030),"CardWellLining")
	for x in [.001,.037]:
		G.rounded(self,Vector3(.00055,.0038,.032),.00015,.00007,matte,Vector3(x,-.002,-.030),"CardWellGuide")
	for i in range(9):
		G.rounded(self,Vector3(.0012,.00013,.004),.0001,.00003,silver,Vector3(.009+i*.0027,-.00008,-.017),"CardWellContact")
	cartridge_slot = CartridgeSlot.new()
	cartridge_slot.name = "CartridgeSlotState"
	cartridge_slot.position = Vector3(0.020, -0.002, -0.0472)
	# Original 3DS: label faces the underside, contacts face the top deck.
	# Roll around the insertion axis; leading/contact edge still travels +Z.
	cartridge_slot.rotation.z = PI
	add_child(cartridge_slot)
	G.rounded(self, Vector3(0.011, 0.003, 0.0006), 0.00025, 0.00015, black, Vector3(-0.022, -0.002, -0.0472), "ChargePort")
	# Original-style left side slider: toward the hinge = louder.
	G.rounded(self, Vector3(0.001, 0.003, 0.024), 0.0004, 0.0002, matte, Vector3(-0.0795, 0.001, 0.010), "VolumeRail")
	volume_slider = Node3D.new()
	volume_slider.name = "VolumeSlider"
	volume_slider.position = Vector3(-0.0812, 0.0023, 0.010)
	add_child(volume_slider)
	volume_thumb_material = G.material(Color("667078"), 0.05, 0.60)
	# Keep the proven touch proxy / rail travel unchanged; only recess the
	# visible cap. Its outer face is now ~1.6 mm beyond the housing, not 4 mm.
	G.rounded(volume_slider, Vector3(0.0015, 0.0036, 0.007), 0.0004, 0.0002, volume_thumb_material, Vector3(0.0014, 0, 0), "VolumeThumb")
	for z in [-0.002, 0, 0.002]:
		G.rounded(volume_slider, Vector3(0.00025, 0.0029, 0.00045), 0.0001, 0.00005, rubber, Vector3(0.00055, 0, z), "VolumeRib")
	for mark in [["+", -0.008], ["−", 0.028]]:
		var label := G.label(self, mark[0], Vector3(-0.0805, 0.0023, mark[1]), 0.00005)
		label.rotation = Vector3(0, -PI / 2, 0)
	volume_readout = Label3D.new()
	volume_readout.name = "VolumeReadout"
	volume_readout.font_size = 30
	volume_readout.pixel_size = 0.00012
	volume_readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	volume_readout.modulate = Color("82e1c4")
	volume_readout.position = Vector3(-0.100, 0.025, 0.010)
	volume_readout.hide()
	add_child(volume_readout)
	# Left-front stylus well replaces the old decorative black port disk.
	stylus = Node3D.new()
	stylus.name = "Stylus"
	stylus.position = stylus_stored_position()
	add_child(stylus)
	var stylus_mat := G.material(Color("aeb8c0"), 0.72, 0.20)
	var stylus_body := G.cylinder(stylus, 0.0018, 0.050, stylus_mat, Vector3.ZERO, "StylusBody")
	stylus_body.rotation.x = PI / 2.0
	var stylus_tip := G.cylinder(stylus, 0.0009, 0.006, black, Vector3(0, 0, -0.026), "StylusTip")
	stylus_tip.rotation.x = PI / 2.0
	var cap := G.cylinder(stylus, 0.0023, 0.004, G.material(Color("82e1c4"), 0.35, 0.3), Vector3(0, 0, 0.026), "StylusCap")
	cap.rotation.x = PI / 2.0
	# Open-ended sleeve has real inner walls and a recessed back, not a front cap.
	G.instance(self, G.tube_z(0.0028, 0.0026, 0.056), black, Vector3(-0.050, -0.003, 0.019), "StylusWell")
	set_stylus_side(stylus_side)
	for i in range(2):
		var led := G.material(Color("4bc3e1") if i == 0 else Color("dfa54b"), 0.05, 0.2)
		led.emission_enabled = true
		led.emission = led.albedo_color
		led.emission_energy_multiplier = 1.6
		G.rounded(self, Vector3(0.003, 0.001, 0.0006), 0.00025, 0.00015, led, Vector3(0.053 + i * 0.007, 0, 0.047), "StatusLED")
	# Hinge pivot and barrel segments. The top panel rotates around the real hinge.
	lid = Node3D.new()
	lid.name = "LidPivot"
	lid.position = Vector3(0, 0.011, -0.043)
	add_child(lid)
	for x in [-0.058, 0.0, 0.058]:
		var barrel := G.cylinder(self, 0.0044, 0.025 if x == 0 else 0.035, body_material, Vector3(x, 0.011, -0.043), "HingeBarrel")
		barrel.rotation.z = PI / 2.0
	G.rounded(lid, Vector3(0.157, 0.0055, 0.088), 0.010, 0.0018, body_material, Vector3(0, -0.0005, -0.044), "LidHousing")
	G.rounded(lid, Vector3(0.155, 0.0012, 0.086), 0.009, 0.0004, rim, Vector3(0, 0.0023, -0.044), "LidTrim")
	G.rounded(lid, Vector3(0.1535, 0.0012, 0.0845), 0.0085, 0.0004, black, Vector3(0, 0.0031, -0.044), "InnerLid")
	G.rounded(lid, Vector3(0.109, 0.0006, 0.0668), 0.002, 0.0002, matte, Vector3(0, 0.0039, -0.042), "UpperLCDBezel")
	top_viewport = _screen_viewport(true)
	top_canvas = top_viewport.get_child(0)
	upper_surface = _screen(lid, Vector2(0.104, 0.0624), top_viewport.get_texture(), Vector3(0, 0.0043, -0.042), "UpperLCD")
	idle_upper_material=upper_surface.material_override
	# Lens ring, glass lens, bezel bumpers and modeled speaker apertures.
	G.cylinder(lid, 0.0021, 0.00035, rim, Vector3(0, 0.004, -0.078), "CameraRing")
	G.cylinder(lid, 0.0015, 0.0005, G.material(Color("132b40"), 0.7, 0.1), Vector3(0, 0.00425, -0.078), "CameraLens")
	for side in [-1, 1]:
		for row in range(6):
			for col in range(3):
				G.cylinder(lid, 0.0007, 0.00016, matte, Vector3(side * (0.063 + col * 0.0025), 0.00383, -0.054 + row * 0.0031), "SpeakerAperture")
		for z in [-0.010, -0.077]:
			G.rounded(lid, Vector3(0.007, 0.0009, 0.0035), 0.0013, 0.0003, rubber, Vector3(side * 0.067, 0.0039, z), "RubberBumper")
	G.label(lid, "3D", Vector3(0.071, 0.004, -0.017), 0.000019)
	G.rounded(lid, Vector3(0.001, 0.001, 0.015), 0.0004, 0.0003, matte, Vector3(0.074, 0.004, -0.026), "DepthSliderRail")
	depth_slider = Node3D.new()
	depth_slider.name = "DepthSlider"
	depth_slider.position = Vector3(0.074, 0.0047, -0.022)
	lid.add_child(depth_slider)
	G.rounded(depth_slider, Vector3(0.0024, 0.0015, 0.004), 0.0006, 0.0004, rubber, Vector3.ZERO, "DepthSliderThumb")
	# Outer cameras are visible when the lid is closed or viewed from behind.
	for x in [-0.018, 0.018]:
		var ring := G.cylinder(lid, 0.0028, 0.0004, black, Vector3(x, -0.0035, -0.072), "OuterCamera")
		ring.rotation.x = PI
		G.cylinder(ring, 0.0017, 0.0003, silver, Vector3(0, 0.0003, 0), "OuterLens")
	set_lid_angle(lid_angle)
	set_volume(volume_level)
	set_depth(depth_level)
	set_stylus_extension(stylus_extension)

func _screen_viewport(upper: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 960) if upper else Vector2i(1280, 960)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var canvas := Screen.new()
	canvas.upper = upper
	canvas.size = vp.size
	vp.add_child(canvas)
	return vp

func _screen(parent: Node3D, dimensions: Vector2, texture: Texture2D, pos: Vector3, title: String) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = dimensions
	var mat := G.material(Color.WHITE, 0.06, 0.2)
	mat.albedo_texture = texture
	# Idle screens use linear filtering; live game screens use the footprint
	# filter below so fine detail remains stable when viewed from the lap.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	# LCD pixels are self-lit. Keep their contrast independent of studio lights.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var glass := G.material(Color(0.03, 0.05, 0.07, 0.035), 0.0, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic_specular = 0.12
	G.instance(parent, mesh, glass, pos + Vector3(0, 0.00004, 0), title + "Glass")
	return G.instance(parent, mesh, mat, pos, title)

func set_lid_angle(degrees: float) -> void:
	lid_angle = clampf(degrees, 15, 175)
	if lid:
		lid.rotation.x = deg_to_rad(180 - lid_angle)

func set_volume(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	var changed := not is_equal_approx(next, volume_level)
	volume_level = next
	if volume_slider:
		volume_slider.position.z = lerpf(VOLUME_MIN_Z, VOLUME_MAX_Z, volume_level)
	if volume_readout:
		volume_readout.text = "MUTED" if volume_level <= 0 else "VOL %d%%" % roundi(volume_level * 100)
	if changed:
		volume_changed.emit(volume_level)

func show_volume_feedback(show: bool, touching: bool) -> void:
	if volume_readout:
		volume_readout.visible = show
	if volume_thumb_material:
		volume_thumb_material.emission_enabled = touching
		volume_thumb_material.emission = Color("5eae9a")
		volume_thumb_material.emission_energy_multiplier = 0.35

func volume_db() -> float:
	# Square the slider to make low-volume adjustment practical in VR.
	return linear_to_db(maxf(0.0001, volume_level * volume_level))

func set_depth(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	var changed := not is_equal_approx(next, depth_level)
	depth_level = next
	if depth_slider:
		depth_slider.position.z = lerpf(-0.020, -0.032, depth_level)
	if changed:
		depth_changed.emit(depth_level)

func set_stylus_extension(value: float) -> void:
	stylus_extension = clampf(value, 0.0, 1.0)
	if stylus:
		stylus.position = stylus_stored_position() + Vector3(0, 0, stylus_extension * StylusMotion.TRAVEL)

func stylus_handle_position() -> Vector3:
	return stylus.to_global(Vector3(0, 0, 0.025))

func return_stylus() -> void:
	if stylus.get_parent() != self:
		stylus.reparent(self, false)
	stylus.transform = Transform3D(Basis.IDENTITY, stylus_stored_position())
	stylus.show()
	stylus_extension = 0.0

func stylus_touch(tip: Vector3, previous: Vector3, touching: bool = false) -> Vector2:
	if lid_angle < 55:
		return Vector2(-1, -1)
	var inverse := bottom_surface.global_transform.affine_inverse()
	var current := inverse * tip
	var last := inverse * previous
	# Match the visible nib, not a 5 mm hover zone. Separate entry/release
	# distances tolerate tracking noise without adding smoothing/input lag.
	# 2.5 mm covers the cap's 2.3 mm collision radius at shallow pen angles.
	var height := 0.0035 if touching else 0.0025
	if current.y >= -0.001 and current.y <= height:
		pass
	elif last.y > 0 and current.y < -0.001:
		# Fast initial tap only. During a drag use the current position, never
		# pin coordinates to an old swept crossing. Deep penetration releases.
		if touching or current.y < -0.008:
			return Vector2(-1, -1)
		current = last.lerp(current, last.y / (last.y - current.y))
	else:
		return Vector2(-1, -1)
	var uv := Vector2(current.x / BOTTOM_SIZE.x + 0.5, current.z / BOTTOM_SIZE.y + 0.5)
	return uv if uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1 else Vector2(-1, -1)

func animate_controls(values: Dictionary, stick: Vector2, delta: float) -> void:
	for key in buttons:
		var down := bool(values.get(key, false))
		var target: Vector3 = button_rest[key] - Vector3(0, 0.0009 if down else 0.0, 0)
		buttons[key].position = buttons[key].position.lerp(target, 1.0 - exp(-30.0 * delta))
	if circle_pad:
		circle_pad.position.x = -0.059 + stick.x * 0.0022
		circle_pad.position.z = -0.020 - stick.y * 0.0022

func ray_to_touch(origin: Vector3, direction: Vector3) -> Vector2:
	if lid_angle < 55:
		return Vector2(-1, -1)
	return surface_uv(bottom_surface.global_transform, BOTTOM_SIZE, origin, direction)

static func surface_uv(surface: Transform3D, dimensions: Vector2, origin: Vector3, direction: Vector3) -> Vector2:
	var inverse := surface.affine_inverse()
	var o := inverse * origin
	var d := inverse.basis * direction
	if d.y >= -0.000001:
		return Vector2(-1, -1)
	var t := -o.y / d.y
	if t < 0:
		return Vector2(-1, -1)
	var p := o + d * t
	var uv := Vector2(p.x / dimensions.x + 0.5, p.z / dimensions.y + 0.5)
	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1:
		return Vector2(-1, -1)
	return uv

func set_screen_textures(top: Texture2D, bottom: Texture2D) -> void:
	# Hidden home screens need not render two high-resolution viewports per VR frame.
	top_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	bottom_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if stereo_material == null:
		stereo_material = ShaderMaterial.new()
		stereo_material.shader = preload("res://scripts/stereo_lcd.gdshader")
		upper_surface.material_override = stereo_material
	stereo_material.set_shader_parameter("lcd_image", top)
	stereo_material.set_shader_parameter("stereo_image", top.get_width() * 3 == top.get_height() * 10)
	stereo_material.set_shader_parameter("swap_eyes", stereo_swap_eyes)
	if bottom_lcd_material == null:
		bottom_lcd_material=ShaderMaterial.new()
		bottom_lcd_material.shader=preload("res://scripts/stereo_lcd.gdshader")
		bottom_surface.material_override=bottom_lcd_material
	bottom_lcd_material.set_shader_parameter("lcd_image",bottom)
	bottom_lcd_material.set_shader_parameter("stereo_image",false)

func set_stereo_swap(value: bool) -> void:
	stereo_swap_eyes = value
	if stereo_material:
		stereo_material.set_shader_parameter("swap_eyes", value)

func clear_screen_textures() -> void:
	top_viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	bottom_viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	upper_surface.material_override=idle_upper_material
	stereo_material=null
	bottom_surface.material_override=idle_bottom_material
	bottom_lcd_material=null
