class_name PFGameCase
extends Node3D
## Physical store-style case. Art is an optional local user-supplied image;
## PocketFrame never downloads or distributes game-cover artwork.

const G = preload("res://scripts/geometry.gd")

var cartridge
var is_open := false
var cover_art: Texture2D
var _cover_surface: MeshInstance3D
var lid: Node3D

func configure(card) -> void:
	cartridge = card
	if cartridge:
		cover_art = cartridge.cover_art
	build()

func build() -> void:
	var clear_blue := G.material(Color("3e78a3"), 0.10, 0.30)
	clear_blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	G.rounded(self, Vector3(0.064, 0.008, 0.095), 0.004, 0.002, clear_blue, Vector3.ZERO, "CaseShell")
	lid = Node3D.new()
	lid.name = "CaseLid"
	lid.position = Vector3(0, 0.004, -0.046)
	add_child(lid)
	var cover_mesh := PlaneMesh.new()
	cover_mesh.size = Vector2(0.054, 0.080)
	var cover_mat := G.material(Color("e8e8e8"), 0.0, 0.70)
	cover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cover_mat.albedo_texture = cover_art
	_cover_surface = G.instance(lid, cover_mesh, cover_mat, Vector3(0, 0.0004, 0.046), "CaseCover")
	_cover_surface.rotation.x = PI / 2.0
	if cartridge:
		if cartridge.get_parent():
			cartridge.reparent(self)
		else:
			add_child(cartridge)
		cartridge.position = Vector3(0, 0.007, 0.010)
		cartridge.rotation = Vector3.ZERO
	set_open(false)

func set_open(value: bool) -> void:
	is_open = value
	if lid:
		lid.rotation.x = deg_to_rad(-125.0 if is_open else 0.0)
	if cartridge:
		cartridge.visible = is_open

func take_cartridge():
	if not is_open or cartridge == null or cartridge.inserted:
		return null
	if is_inside_tree() and get_parent():
		cartridge.reparent(get_parent())
	return cartridge
