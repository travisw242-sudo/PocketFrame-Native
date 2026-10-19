class_name PFScreenCanvas
extends Control
## High-resolution original test interface. No ROMs or emulator UI is bundled.
var upper := true
var status := "DESKTOP STUDIO"
var selection := 0
var touch := Vector2(-1, -1)
var font: Font = ThemeDB.fallback_font
var active_buttons := "READY"
var volume_percent := 70
var depth_percent := 0
var cartridge_count := 0
var home_state := "NO CARTRIDGE"
var clock_text := ""
const SETTINGS_HEADLINE := "HOLD Y"
const SETTINGS_ACTION := "TO OPEN SETTINGS"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_clock()
	var timer := Timer.new()
	timer.wait_time=1.0
	timer.timeout.connect(_update_clock)
	add_child(timer); timer.start()
	queue_redraw()

func _update_clock() -> void:
	var now := Time.get_datetime_dict_from_system()
	var next := "%02d:%02d" % [now.hour,now.minute]
	if clock_text!=next: clock_text=next;queue_redraw()

func set_home_context(state: String, volume: float, depth: float, count: int) -> void:
	var v := roundi(volume*100)
	var d := roundi(depth*100)
	if home_state==state and volume_percent==v and depth_percent==d and cartridge_count==count: return
	home_state=state; volume_percent=v; depth_percent=d; cartridge_count=count
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("101b25"))
	if upper:
		# Layered landscape, intentionally all vector so the surface stays crisp.
		for i in range(32):
			var t := float(i) / 31.0
			draw_rect(Rect2(0, h * t, w, h / 31 + 1), Color("345e6c").lerp(Color("132432"), t))
		draw_circle(Vector2(w * 0.77, h * 0.32), h * 0.13, Color("c2d8c9"))
		for layer in range(4):
			var pts := PackedVector2Array([Vector2(0, h)])
			for i in range(61):
				var x := float(i) / 60 * w
				var y := h * (0.53 + layer * 0.095) + sin(float(i) * 0.13 + layer * 2) * h * 0.09 + cos(float(i) * 0.29) * h * 0.024
				pts.append(Vector2(x, y))
			pts.append(Vector2(w, h))
			draw_colored_polygon(pts, Color("315664").lerp(Color("101b25"), float(layer) / 3))
		draw_string(font, Vector2(75, 100), "POCKETFRAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color("e5f5f0"))
		draw_string(font, Vector2(w-300,100), clock_text, HORIZONTAL_ALIGNMENT_RIGHT, 225, 50, Color("e5f5f0"))
		# The idle viewport is already 1600x960. Larger, high-contrast lettering
		# helps at lap distance more than increasing its texture resolution again.
		var card := StyleBoxFlat.new();card.bg_color=Color("10242d")
		card.set_corner_radius_all(36)
		draw_style_box(card,Rect2(64,h*.41,w-128,h*.47))
		draw_circle(Vector2(185,h*.61),86,Color("c2eadf"))
		draw_string(font,Vector2(99,h*.61+34),"Y",HORIZONTAL_ALIGNMENT_CENTER,172,104,Color("10242d"))
		draw_string(font,Vector2(320,h*.41+138),SETTINGS_HEADLINE,HORIZONTAL_ALIGNMENT_LEFT,-1,112,Color("eefbf5"))
		draw_string(font,Vector2(320,h*.41+218),SETTINGS_ACTION,HORIZONTAL_ALIGNMENT_LEFT,-1,62,Color("c2eadf"))
		draw_string(font,Vector2(320,h*.41+300),"Right Steam controller · TOP button",HORIZONTAL_ALIGNMENT_LEFT,-1,46,Color("eefbf5"))
		draw_string(font,Vector2(320,h*.41+370),"Free hand · hold for about 1 second",HORIZONTAL_ALIGNMENT_LEFT,-1,44,Color("b9d5d0"))
		draw_string(font, Vector2(80, h - 38), "INSERT A CARTRIDGE TO PLAY", HORIZONTAL_ALIGNMENT_CENTER, w-160, 44, Color("c2dadb"))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("e1e6e3"))
		draw_string(font, Vector2(65, 85), "POCKETFRAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("304a51"))
		draw_string(font, Vector2(65, 145), home_state, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("668087"))
		var titles := ["CARTRIDGES", "VOLUME", "3D DEPTH"]
		for i in range(3):
			var box := Rect2(65 + i * 390, 245, 345, 360)
			var style := StyleBoxFlat.new()
			style.bg_color = Color("bfd7d3") if selection == i else Color("d0d9d6")
			style.set_corner_radius_all(28)
			draw_style_box(style, box)
			var center := box.get_center() - Vector2(0, 35)
			if i == 0:
				draw_rect(Rect2(center-Vector2(57,65),Vector2(114,130)),Color("45656d"))
				draw_rect(Rect2(center-Vector2(40,45),Vector2(80,65)),Color("d0d9d6"))
				for pin in range(5): draw_rect(Rect2(center+Vector2(-38+pin*17,39),Vector2(9,15)),Color("b8a479"))
			elif i == 1:
				draw_line(center+Vector2(-70,0),center+Vector2(70,0),Color("45656d"),10,true)
				draw_circle(center+Vector2(lerpf(-70,70,volume_percent/100.0),0),22,Color("45656d"))
			else:
				draw_circle(center, 58, Color("45656d"), false, 7)
				draw_circle(center, 12, Color("45656d"))
			draw_string(font, Vector2(box.position.x, 552), titles[i], HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 28, Color("304a51"))
		var details := ["%d games on your tray. Insert a cartridge into the rear slot." % cartridge_count,"Slide the LEFT-side volume switch. Current level: %d%%." % volume_percent,"Slide the switch beside the UPPER screen. Depth: %d%%." % depth_percent]
		draw_string(font,Vector2(65,710),details[selection],HORIZONTAL_ALIGNMENT_LEFT,1160,27,Color("304a51"))
		draw_string(font, Vector2(65, 845), "Save your game before removing its cartridge.", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("668087"))
		if touch.x >= 0:
			draw_circle(touch, 22, Color("f09157"), false, 5)

func set_status(value: String, buttons: String) -> void:
	if status != value or active_buttons != buttons:
		status = value
		active_buttons = buttons
		queue_redraw()

func tap(uv: Vector2) -> void:
	touch = uv * size
	if touch.y >= 245 and touch.y <= 605:
		selection = clampi(int((touch.x - 65) / 390), 0, 2)
	queue_redraw()
