class_name PFInputRouter
extends RefCounted
## Semantic output contract for a future emulator adapter.
## Does not inject keys into another app or implement emulation.
signal button_changed(button: String, pressed: bool)
signal stick_changed(value: Vector2)
signal touch_changed(uv: Vector2, pressed: bool)
var previous: Dictionary = {}
var last_stick := Vector2.ZERO
var last_touch := Vector2(-1, -1)
var touch_down := false

func update(values: Dictionary, stick: Vector2) -> void:
	for key in values:
		if bool(previous.get(key, false)) != bool(values[key]):
			button_changed.emit(key, bool(values[key]))
	previous = values.duplicate()
	if not last_stick.is_equal_approx(stick):
		last_stick = stick
		stick_changed.emit(stick)

func update_touch(uv: Vector2, pressed: bool) -> void:
	var down := pressed and uv.x >= 0
	if down != touch_down or (down and uv != last_touch):
		last_touch = uv
		touch_down = down
		touch_changed.emit(uv, down)

func release_all() -> void:
	var empty: Dictionary = {}
	for key in previous:
		empty[key] = false
	update(empty, Vector2.ZERO)
	update_touch(Vector2(-1, -1), false)
