extends Node
class_name CharacterSlotManager

const MAX_SLOTS = 10
const DEFAULT_SLOTS = 5

var slots: Array = []  # array of character_id or null

func _ready():
	slots.resize(DEFAULT_SLOTS)
	for i in range(slots.size()):
		slots[i] = null

func get_slot(i: int) -> Variant:
	if i >= 0 and i < slots.size():
		return slots[i]
	return null

func set_slot(i: int, char_id: String) -> bool:
	if i < 0 or i >= slots.size():
		return false
	slots[i] = char_id
	return true

func find_empty_slot() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1

func remove_character(char_id: String):
	for i in range(slots.size()):
		if slots[i] == char_id:
			slots[i] = null