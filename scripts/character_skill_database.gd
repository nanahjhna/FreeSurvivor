class_name CharacterSkillDatabase
extends RefCounted

const SKILL_DATABASE := preload("res://scripts/skill_database.gd")

# Character definitions only reference shared skill IDs. To add a character,
# register its skills in SkillDatabase and add slot IDs here.
const CHARACTER_SKILL_ASSIGNMENTS: Dictionary = {
	"fighter": {
		"skills": ["fighter_passive", "fighter_q", "fighter_w", "fighter_e", "fighter_r", "fighter_volley", "fighter_renewal"],
		"loadout": {"q": "fighter_q", "w": "fighter_w", "e": "fighter_e", "r": "fighter_r", "a": "fighter_volley", "s": "fighter_renewal"}
	},
	"fighter_2d": {
		"skills": ["fighter_passive", "fighter_q", "fighter_w", "fighter_e", "fighter_r", "fighter_volley", "fighter_renewal"],
		"loadout": {"q": "fighter_q", "w": "fighter_w", "e": "fighter_e", "r": "fighter_r", "a": "fighter_volley", "s": "fighter_renewal"}
	},
	"char02": {
		"skills": ["fighter_passive", "fighter_q", "fighter_w", "fighter_e", "fighter_r", "fighter_volley", "fighter_renewal"],
		"loadout": {"q": "fighter_q", "w": "fighter_w", "e": "fighter_e", "r": "fighter_r", "a": "fighter_volley", "s": "fighter_renewal"}
	}
}

static func get_skill_ids(character_class_id: String) -> Array:
	var config: Dictionary = CHARACTER_SKILL_ASSIGNMENTS.get(character_class_id, {})
	var result: Array = []
	for skill_id in config.get("skills", []):
		if SKILL_DATABASE.has_skill(str(skill_id)):
			result.append(str(skill_id))
	return result


static func get_registered_character_ids() -> Array[String]:
	var ids: Array[String] = []
	for character_id in CHARACTER_SKILL_ASSIGNMENTS.keys():
		ids.append(str(character_id))
	return ids


static func has_skill_assignment(character_class_id: String) -> bool:
	return CHARACTER_SKILL_ASSIGNMENTS.has(character_class_id) and not get_skill_ids(character_class_id).is_empty()


static func get_skill_set(character_class_id: String) -> Dictionary:
	return SKILL_DATABASE.get_game_skills(get_skill_ids(character_class_id))

static func get_default_levels(character_class_id: String) -> Dictionary:
	var result: Dictionary = {}
	for skill_id in get_skill_ids(character_class_id):
		result[skill_id] = 1
	return result

static func get_default_loadout(character_class_id: String) -> Dictionary:
	var config: Dictionary = CHARACTER_SKILL_ASSIGNMENTS.get(character_class_id, {})
	var registered_skills := get_skill_ids(character_class_id)
	var result: Dictionary = {}
	for slot in config.get("loadout", {}):
		var skill_id := str(config["loadout"][slot])
		if registered_skills.has(skill_id):
			result[str(slot)] = skill_id
	return result
