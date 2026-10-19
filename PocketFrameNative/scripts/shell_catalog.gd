extends RefCounted
const ITEMS := [
	{"id":"nebula","name":"Nebula","base":"25213e","accent":"a99add","image":"nebula.png"},
	{"id":"botanical","name":"Botanical","base":"284b4e","accent":"d6c4ab","image":"botanical.png"},
	{"id":"ocean","name":"Ocean Current","base":"205668","accent":"8ccfc8"},
	{"id":"sunset","name":"Sunset Dunes","base":"b76d5c","accent":"f1d6ad"},
	{"id":"midnight","name":"Midnight Gold","base":"1e2939","accent":"d8b97d"},
	{"id":"matcha","name":"Matcha Leaves","base":"718573","accent":"dce2c8"},
	{"id":"aurora","name":"Arctic Aurora","base":"263a50","accent":"98d2bf"},
	{"id":"coral","name":"Coral Terrazzo","base":"ce928c","accent":"f3dfcf"},
	{"id":"lavender","name":"Lavender Orbit","base":"9684ae","accent":"e7d9ef"},
	{"id":"graphite","name":"Graphite Circuit","base":"303841","accent":"83b6b0"},
]
static func index(id: String) -> int:
	for i in range(ITEMS.size()):
		if ITEMS[i].id==id: return i
	return -1
static func material(i: int, preview: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://scripts/shell_swatch.gdshader") if preview else preload("res://scripts/shell_finish.gdshader")
	mat.set_shader_parameter("design",i)
	mat.set_shader_parameter("base_color",Color(ITEMS[i].base))
	mat.set_shader_parameter("accent_color",Color(ITEMS[i].accent))
	if ITEMS[i].has("image"): mat.set_shader_parameter("artwork",load("res://assets/shells/"+ITEMS[i].image))
	return mat
