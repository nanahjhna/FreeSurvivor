extends Node
class_name SkillLoadoutManager

# 6 slots: 0=left click, 1=right click, 2..5 = keys 1-4
var slots: Array = [null, null, null, null, null, null]

func equip(slot: int, skill_id: String) -> bool:
	if slot < 0 or slot >= slots.size():
		return false
	if skill_id == null or skill_id == "":
		return false
	# prevent duplicate
	for s in slots:
		if s == skill_id:
			return false
	slots[slot] = skill_id
	return true

func unequip(slot: int):
	if slot >= 0 and slot < slots.size():
		slots[slot] = null

func get_skill(slot: int) -> String:
	if slot >= 0 and slot < slots.size():
		return slots[slot]
	return ""

func is_equipped(skill_id: String) -> bool:
	return slots.has(skill_id)