extends Node
class_name CardManager

var owned: Dictionary = {}  # id -> count
var equipped: Array = []   # max 3

func add_card(id: String, count: int = 1):
	owned[id] = owned.get(id, 0) + count

func remove_card(id: String, count: int = 1):
	if owned.has(id):
		owned[id] = max(0, owned[id] - count)
		if owned[id] == 0:
			owned.erase(id)

func equip_card(id: String) -> bool:
	if equipped.size() >= 3:
		return false
	if not owned.has(id):
		return false
	if equipped.has(id):
		return false
	equipped.append(id)
	return true

func unequip_card(id: String):
	equipped.erase(id)

func is_equipped(id: String) -> bool:
	return equipped.has(id)