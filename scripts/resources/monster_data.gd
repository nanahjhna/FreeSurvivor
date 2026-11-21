class_name MonsterData
extends Resource

@export var id: String = ""
@export var legacy_id: String = ""
@export var display_name: String = ""
@export var model_scene: PackedScene
@export var skill_ids: Array[String] = []
@export var hp: float = 1.0
@export var speed: float = 1.0
@export var damage: float = 1.0
@export var attack_range: float = 1.5
@export var attack_interval: float = 1.0
@export var xp: int = 0
@export var gold: int = 0
@export var loot: Dictionary = {}
@export var is_boss: bool = false
@export var potion_chance: float = 0.0
@export var visual_scale: Vector3 = Vector3.ONE
@export var collision_scale: Vector3 = Vector3.ONE
@export var fall_on_death: bool = true
@export var icon: String = "👾"
@export var grade: String = "일반"
@export_multiline var description: String = ""
@export var card_floor: int = 0
@export var card_hp: int = 0
@export var card_icon: String = "👾"
@export var card_pattern: Array[Dictionary] = []


func to_dictionary() -> Dictionary:
	return {
		"id": legacy_id if not legacy_id.is_empty() else id,
		"registry_id": id,
		"legacy_id": legacy_id,
		"name": display_name,
		"scene": model_scene.resource_path if model_scene != null else "",
		"skill_ids": skill_ids.duplicate(),
		"hp": hp,
		"speed": speed,
		"damage": damage,
		"range": attack_range,
		"interval": attack_interval,
		"xp": xp,
		"gold": gold,
		"loot": loot.duplicate(true),
		"is_boss": is_boss,
		"potion_chance": potion_chance,
		"visual_scale": visual_scale,
		"collision_scale": collision_scale,
		"fall_on_death": fall_on_death,
		"icon": icon,
		"grade": grade,
		"desc": description,
		"card_floor": card_floor,
		"card_hp": card_hp,
		"card_icon": card_icon,
		"card_pattern": card_pattern.duplicate(true)
	}
