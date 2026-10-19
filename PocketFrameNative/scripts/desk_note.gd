class_name PFDeskNote
extends Node3D
## A world-space paper guide, not a camera-facing overlay or active viewport.
const G = preload("res://scripts/geometry.gd")
var body: Label3D

func _init() -> void:
	name = "DeskNote"
	# Local +Z is the printed face; lay it flat with the heading away from us.
	rotation_degrees = Vector3(-90, 0, -5)
	var paper := BoxMesh.new()
	paper.size = Vector3(.32, .23, .001)
	G.instance(self, paper, G.material(Color("eee6cd"), 0, .95), Vector3.ZERO, "Paper")
	var title := _label("POCKETFRAME / QUICK START", 42)
	title.position = Vector3(0, .087, .0007)
	var rule := BoxMesh.new()
	rule.size = Vector3(.282, .0007, .0001)
	G.instance(self, rule, G.material(Color("608579"), 0, 1), Vector3(0, .069, .0007), "PrintedRule")
	body = _label("", 36)
	body.position = Vector3(-.141, .055, .0008)
	body.width = 1410
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.line_spacing = 12
	var footer := _label("KEEP THIS HANDY  /  INSERT A CARTRIDGE TO PLAY", 22)
	footer.position = Vector3(0, -.096, .0008)
	footer.modulate = Color("587065")

func _label(text: String, size_px: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size_px
	label.pixel_size = .0002
	label.outline_size = 0
	label.modulate = Color("243a3d")
	label.no_depth_test = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(label)
	return label

func set_guide(text: String) -> void:
	# Avoid rebuilding text geometry every frame when status hasn't changed.
	if body.text != text: body.text = text
