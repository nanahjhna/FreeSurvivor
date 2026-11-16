extends Node
class_name CharacterSlotManager

const MAX_SLOTS = 10
const DEFAULT_SLOTS = 5

signal slots_changed()

var slots: Array = []  # Array of character_id strings or null.

func _ready():
	if slots.is_empty():
		initialize()

func initialize(slot_count: int = DEFAULT_SLOTS):
	var safe_count := clampi(slot_count, 1, MAX_SLOTS)
	slots.resize(safe_count)
	for i in range(slots.size()):
		slots[i] = null
	slots_changed.emit()

func load_slots(saved_slots: Array):
	var safe_count := clampi(max(DEFAULT_SLOTS, saved_slots.size()), 1, MAX_SLOTS)
	slots.resize(safe_count)
	for i in range(safe_count):
		var value: Variant = saved_slots[i] if i < saved_slots.size() else null
		slots[i] = str(value) if value != null and not str(value).is_empty() else null
	slots_changed.emit()

func to_array() -> Array:
	return slots.duplicate()

func get_slot_count() -> int:
	return slots.size()

func get_slot(i: int) -> Variant:
	if i >= 0 and i < slots.size():
		return slots[i]
	return null

func set_slot(i: int, char_id: String) -> bool:
	if i < 0 or i >= slots.size():
		return false
	if char_id.is_empty():
		return false
	slots[i] = char_id
	slots_changed.emit()
	return true

func find_empty_slot() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1

func clear_slot(i: int) -> bool:
	if i < 0 or i >= slots.size():
		return false
	slots[i] = null
	slots_changed.emit()
	return true

func remove_character(char_id: String):
	for i in range(slots.size()):
		if slots[i] == char_id:
			slots[i] = null
	slots_changed.emit()

func expand_slots(new_count: int) -> bool:
	var safe_count := clampi(new_count, DEFAULT_SLOTS, MAX_SLOTS)
	if safe_count <= slots.size():
		return false
	var old_count := slots.size()
	slots.resize(safe_count)
	for i in range(old_count, safe_count):
		slots[i] = null
	slots_changed.emit()
	return true
