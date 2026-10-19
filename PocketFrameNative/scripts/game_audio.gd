extends RefCounted
## Dedicated in-process game bus. Never changes Master, OS or headset volume,
## nor pauses/flushed the audio generator (which would reintroduce dropouts).
const BUS := "PocketFrame Game"
var level := 0.7
var gain_db := -6.196
var configured := false
var applied_mute := false

func _bus() -> int:
	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
	return index

func set_level(value: float) -> void:
	level = clampf(value, 0, 1)
	if not configured:
		gain_db = linear_to_db(maxf(0.0001, level * level))
		_apply()

func attach_player(node: Node) -> void:
	if node is AudioStreamPlayer:
		_apply()
		node.bus = BUS

func update(delta: float) -> void:
	if not configured:
		return
	var target := linear_to_db(maxf(0.0001, level * level))
	if is_equal_approx(gain_db, target):
		if applied_mute != (level <= 0 and gain_db < -70):
			_apply()
		return
	gain_db = lerpf(gain_db, target, 1.0 - exp(-45.0 * delta))
	if absf(gain_db - target) < 0.02:
		gain_db = target
	_apply()

func _apply() -> void:
	var index := _bus()
	AudioServer.set_bus_volume_db(index, gain_db)
	applied_mute = level <= 0 and gain_db < -70
	AudioServer.set_bus_mute(index, applied_mute)
	configured = true
