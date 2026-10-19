class_name PFGameCartridge
extends Node3D
## White 3DS-format card, dimensions in meters; metadata never owns the ROM.

signal inserted_changed(inserted: bool)
signal load_requested(content_path: String)

var game_id := ""
var display_name := "Untitled cartridge"
var content_path := ""
var cover_art_path := ""
var cover_art: Texture2D
var inserted := false
var full_label_art := false
var product_code := ""
var metadata_stamp := ""
var _label_header: Label3D
var _label_title: Label3D
const SIZE := Vector3(0.035,0.0038,0.033)
var _art_surface: MeshInstance3D

func configure(id: String, label: String, path: String = "") -> void:
	game_id = id
	display_name = label
	content_path = path

func set_inserted(value: bool) -> void:
	if inserted == value:
		return
	inserted = value
	inserted_changed.emit(inserted)

func set_cover_art_file(path: String) -> bool:
	cover_art_path = path
	cover_art=null
	if path.is_empty():
		cover_art = null
		return false
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return false
	cover_art = ImageTexture.create_from_image(image)
	if _art_surface:
		var material: StandardMaterial3D = _art_surface.material_override
		material.albedo_texture = cover_art
	return true

func build_visual() -> void:
	const G = preload("res://scripts/geometry.gd")
	var card := G.material(Color("dfdfda"), 0.0, 0.52)
	G.rounded(self, Vector3(0.033,0.0038,0.033),0.0018,0.0004,card,Vector3.ZERO,"GameCard")
	# Raised upper-right compatibility tab, like the supplied reference.
	G.rounded(self,Vector3(.003,.0038,.006),.0006,.0003,card,Vector3(.017,0,-.0135),"KeyTab")
	var edge := G.material(Color("b9bcb7"),0,.6)
	G.rounded(self,Vector3(.029,.00012,.028),.001,.00004,edge,Vector3(0,.00192,0),"LabelRecess")
	var white := G.material(Color("f8f8f3"),0,.7)
	G.rounded(self,Vector3(.0278,.0001,.0268),.0008,.00003,white,Vector3(0,.002,0),"LabelPaper")
	var label_mesh := PlaneMesh.new()
	label_mesh.size = Vector2(.027,.026) if full_label_art else Vector2(.018,.018)
	var label_mat := G.material(Color.WHITE if cover_art else Color("526778"), 0.0, 0.75)
	label_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	label_mat.albedo_texture = cover_art
	_art_surface = G.instance(self,label_mesh,label_mat,Vector3(0,.00208,0),"CartridgeLabel")
	# PlaneMesh already lies on XZ; rotating it would make the label stand up.
	var header := G.label(self,"NINTENDO 3DS",Vector3(0,.0022,-.011),.000055)
	_label_header=header
	header.modulate=Color("20252b")
	header.visible=not full_label_art
	var title := G.label(self,display_name.left(34),Vector3(0,.0022,.011),.000028)
	_label_title=title
	title.modulate=Color("20252b")
	title.visible=not full_label_art
	if not product_code.is_empty(): title.text=product_code.left(16)
	# Reverse-side contact comb; no texture/ROM content is modified.
	var contact_mesh := BoxMesh.new()
	contact_mesh.size=Vector3(.001,.00012,.009)
	var comb := MultiMesh.new()
	comb.transform_format=MultiMesh.TRANSFORM_3D
	comb.mesh=contact_mesh
	comb.instance_count=17
	for i in range(17): comb.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(-.013+i*.0016,-.00196,.010)))
	var contacts := MultiMeshInstance3D.new()
	contacts.name="ContactComb"
	contacts.multimesh=comb
	contacts.material_override=G.material(Color("b99c52"),.65,.35)
	add_child(contacts)
	G.rounded(self,Vector3(.030,.0001,.00025),.0001,.00002,edge,Vector3(0,.00193,-.0155),"ShellSeam")

func request_load() -> bool:
	if content_path.is_empty():
		return false
	load_requested.emit(content_path)
	return true

func refresh_art(entry: Dictionary) -> void:
	metadata_stamp=str(entry.get("stamp",""))
	display_name=entry.display_name
	var label_loaded := set_cover_art_file(str(entry.cover_path))
	if cover_art==null: cover_art=entry.get("icon",null)
	full_label_art=label_loaded
	if _art_surface:
		_art_surface.mesh.size=Vector2(.027,.026) if full_label_art else Vector2(.018,.018)
		var mat: StandardMaterial3D=_art_surface.material_override
		mat.albedo_texture=cover_art
		mat.albedo_color=Color.WHITE if cover_art else Color("526778")
	if _label_header: _label_header.visible=not full_label_art
	if _label_title: _label_title.visible=not full_label_art
