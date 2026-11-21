class_name CharacterData
extends Resource

@export var id: String = ""
@export var legacy_id: String = ""
@export var display_name: String = ""
@export var title: String = ""
@export var role: String = ""
@export var grade: String = "R"
@export var icon: String = "⚔️"
@export var color: Color = Color.WHITE
@export var unlocked: bool = true
@export var model_scene: PackedScene
@export var model_scale: Vector3 = Vector3.ONE
@export_storage var animation_profile: String = ""
## Semantic action name -> ordered clip-name candidates from this model's AnimationPlayer.
## Example: {"AttackAlt": ["Bow_Release_RT", "Attack"]}
@export var animation_aliases: Dictionary = {}
@export var base_str: int = 1
@export var base_agi: int = 1
@export var base_vit: int = 1
@export var base_int: int = 1
@export var base_dex: int = 1
@export var base_luk: int = 1
@export var base_hp: float = 100.0
@export var base_atk: float = 10.0
@export var base_def: float = 5.0
@export var base_spd: float = 6.0
## Character-owned skill definitions. These are embedded subresources in this
## .tres file so the character's effects and animation choices stay together.
@export var skills: Array[SkillData] = []
# Legacy migration fields. New characters should fill `skills` instead.
@export_storage var skill_ids: Array[String] = []
@export_storage var skill_loadout: Dictionary = {}
@export var signature_skill: String = ""
@export var weapon_name: String = ""
@export var combat_style: String = ""
@export_multiline var description: String = ""
@export var appearance: String = ""
@export var starting_gear: Dictionary = {}


func get_base_attributes() -> Dictionary:
	return {"STR": base_str, "AGI": base_agi, "VIT": base_vit, "INT": base_int, "DEX": base_dex, "LUK": base_luk}


func get_character_skill_ids() -> Array[String]:
	var result: Array[String] = []
	if not skills.is_empty():
		for index in range(skills.size()):
			var skill := skills[index]
			if skill == null:
				continue
			if not skill.legacy_id.is_empty():
				result.append(skill.legacy_id)
			elif not skill.id.is_empty():
				result.append(skill.id)
			else:
				var kind := "passive" if skill.cast_type == "passive" else "skill"
				result.append("%s_%s_%02d" % [legacy_id if not legacy_id.is_empty() else id, kind, index])
		return result
	return skill_ids.duplicate()


func to_legacy_dictionary() -> Dictionary:
	return {
		"id": legacy_id if not legacy_id.is_empty() else id,
		"registry_id": id,
		"legacy_id": legacy_id,
		"name": display_name,
		"title": title,
		"role": role,
		"grade": grade,
		"icon": icon,
		"color": color,
		"unlocked": unlocked,
		"model_scene": model_scene.resource_path if model_scene != null else "",
		"model_scale": model_scale,
		"animation_profile": animation_profile,
		"animation_aliases": animation_aliases.duplicate(true),
		"base_attributes": get_base_attributes(),
		"base_hp": base_hp,
		"base_atk": base_atk,
		"base_def": base_def,
		"base_spd": base_spd,
		"skill_ids": get_character_skill_ids(),
		"skill_loadout": skill_loadout.duplicate(true),
		"signature_skill": signature_skill,
		"weapon_name": weapon_name,
		"combat_style": combat_style,
		"desc": description,
		"appearance": appearance,
		"starting_gear": starting_gear.duplicate(true)
	}
