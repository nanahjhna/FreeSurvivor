extends RefCounted

## Stable monster IDs are referenced by the spawner, quests, and saved records.
## Add a scene and its defaults here; gameplay code continues to use the ID.
const MONSTERS: Dictionary = {
	"infected": {
		"name": "감염자", "scene": "res://scenes/monsters/monster01/monster01.tscn",
		"hp": 35.0, "speed": 3.2, "damage": 7.0, "range": 1.6, "interval": 1.0, "xp": 1,
		"gold": 25, "is_boss": false, "potion_chance": 0.5, "fall_on_death": false
	},
	"infected_boss": {
		"name": "거대 감염자", "scene": "res://scenes/monsters/monster01/monster01.tscn",
		"hp": 900.0, "speed": 1.7, "damage": 24.0, "range": 3.0, "interval": 1.0, "xp": 60,
		"gold": 500, "is_boss": true, "potion_chance": 1.0, "visual_scale": Vector3(2.2, 2.2, 2.2),
		"collision_scale": Vector3(2.2, 2.2, 2.2), "fall_on_death": false
	},
	"zombie": {
		"name": "좀비", "scene": "res://scenes/monsters/zombie/zombie.tscn",
		"hp": 35.0, "speed": 3.2, "damage": 7.0, "range": 1.4, "interval": 1.0, "xp": 1,
		"gold": 35, "is_boss": false, "potion_chance": 0.5
	},
	"mutant": {
		"name": "뮤턴트", "scene": "res://scenes/monsters/mutant/mutant.tscn",
		"hp": 110.0, "speed": 2.1, "damage": 16.0, "range": 1.8, "interval": 1.4, "xp": 5,
		"gold": 90, "is_boss": false, "potion_chance": 0.5
	},
	"skeleton": {
		"name": "스켈레톤", "scene": "res://scenes/monsters/skeleton/skeleton_enemy.tscn",
		"hp": 25.0, "speed": 2.6, "damage": 8.0, "range": 8.0, "interval": 2.0, "xp": 2,
		"gold": 35, "is_boss": false, "potion_chance": 0.5
	},
	"fast_zombie": {
		"name": "빠른 좀비", "scene": "res://scenes/monsters/zombie/zombie.tscn",
		"hp": 28.0, "speed": 4.6, "damage": 9.0, "range": 1.5, "interval": 0.8, "xp": 2,
		"gold": 35, "is_boss": false, "potion_chance": 0.5
	},
	"elite": {
		"name": "정예 뮤턴트", "scene": "res://scenes/monsters/mutant/mutant.tscn",
		"hp": 250.0, "speed": 2.4, "damage": 22.0, "range": 1.9, "interval": 1.2, "xp": 12,
		"gold": 90, "is_boss": false, "potion_chance": 0.7, "visual_scale": Vector3(1.3, 1.3, 1.3)
	},
	"mutant_lord": {
		"name": "뮤턴트 군주", "scene": "res://scenes/monsters/mutant/mutant.tscn",
		"hp": 650.0, "speed": 1.9, "damage": 30.0, "range": 2.6, "interval": 1.4, "xp": 45,
		"gold": 500, "is_boss": true, "potion_chance": 1.0, "visual_scale": Vector3(2.0, 2.0, 2.0),
		"collision_scale": Vector3(2.0, 2.0, 2.0), "fall_on_death": false
	}
}


static func get_definition(monster_id: String) -> Dictionary:
	var definition: Variant = MONSTERS.get(monster_id, {})
	return definition.duplicate(true) if definition is Dictionary else {}


static func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for monster_id in MONSTERS.keys():
		ids.append(str(monster_id))
	return ids
