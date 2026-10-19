class_name PFCaseInteraction
extends RefCounted
## Pure interaction state for a game case and rear cartridge slot. VR gestures
## call these methods; this class intentionally has no controller dependency.

enum State { CLOSED, OPEN, CARD_HELD, INSERTED }

var state: State = State.CLOSED
var game_case
var slot
var held_card

func configure(case_node, slot_node) -> void:
	game_case = case_node
	slot = slot_node

func open_case() -> bool:
	if game_case == null or state != State.CLOSED:
		return false
	game_case.set_open(true)
	state = State.OPEN
	return true

func close_case() -> bool:
	if game_case == null or state != State.OPEN:
		return false
	game_case.set_open(false)
	state = State.CLOSED
	return true

func take_card():
	if game_case == null or state != State.OPEN:
		return null
	held_card = game_case.take_cartridge()
	if held_card == null:
		return null
	state = State.CARD_HELD
	return held_card

func release_card(candidate_transform: Transform3D) -> bool:
	if held_card == null or slot == null or state != State.CARD_HELD:
		return false
	if not slot.try_snap(held_card, candidate_transform):
		return false
	held_card = null
	state = State.INSERTED
	return true
