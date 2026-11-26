class_name CharacterSkillDatabase
extends RefCounted

## Runtime adapter over the skills embedded in each CharacterData resource.
## Legacy ID lookup remains for save compatibility; new characters need only
## one character .tres with its skill subresources and slot keys.
static func _get_character(character_class_id: String) -> CharacterData:
	return CharacterRegistry.get_by_id(character_class_id)


static func get_runtime_skill_id(character: CharacterData, skill: SkillData, index: int) -> String:
	if not skill.legacy_id.is_empty():
		return skill.legacy_id
	if not skill.id.is_empty():
		return skill.id
	var fallback_kind := "passive" if skill.cast_type == "passive" else "skill"
	var skill_key := skill.slot_key if not skill.slot_key.is_empty() else "%s_%02d" % [fallback_kind, index]
	return "%s_%s" % [character.legacy_id if not character.legacy_id.is_empty() else character.id, skill_key]


static func get_skill_ids(character_class_id: String) -> Array:
	var character := _get_character(character_class_id)
	var result: Array = []
	if character == null:
		return result
	if not character.skills.is_empty():
		for index in range(character.skills.size()):
			var skill := character.skills[index]
			if skill != null and skill.implemented:
				result.append(get_runtime_skill_id(character, skill, index))
		return result
	for canonical_id in character.skill_ids:
		var skill := SkillRegistry.get_by_id(canonical_id)
		if skill == null or not skill.implemented:
			continue
		result.append(skill.legacy_id if not skill.legacy_id.is_empty() else skill.id)
	return result


static func get_registered_character_ids() -> Array[String]:
	var ids: Array[String] = []
	for character in CharacterRegistry.all():
		var legacy_id := character.legacy_id if not character.legacy_id.is_empty() else character.id
		if not get_skill_ids(legacy_id).is_empty():
			ids.append(legacy_id)
	return ids


static func has_skill_assignment(character_class_id: String) -> bool:
	return not get_skill_ids(character_class_id).is_empty()


static func get_source_clip(character: CharacterData, animation_key: String) -> String:
	if character == null or animation_key.is_empty():
		return ""
	var aliases: Variant = character.animation_aliases.get(animation_key, [animation_key])
	var candidates: Array = aliases if aliases is Array else [aliases]
	for alias in candidates:
		if character.animation_source_clips.has(alias):
			return str(character.animation_source_clips[alias])
	return str(character.animation_source_clips.get(animation_key, animation_key))


static func get_skill_set(character_class_id: String) -> Dictionary:
	var skills: Dictionary = {}
	var character := _get_character(character_class_id)
	if character == null:
		return skills
	if not character.skills.is_empty():
		for index in range(character.skills.size()):
			var skill := character.skills[index]
			if skill != null and skill.implemented:
				var key := get_runtime_skill_id(character, skill, index)
				skills[key] = skill.to_game_dictionary()
		return skills
	for skill_id in get_skill_ids(character_class_id):
		var skill := SkillRegistry.get_by_id(str(skill_id))
		if skill != null:
			skills[str(skill_id)] = skill.to_game_dictionary()
	return skills


static func get_default_levels(character_class_id: String) -> Dictionary:
	var levels: Dictionary = {}
	for skill_id in get_skill_ids(character_class_id):
		levels[skill_id] = 1
	return levels


static func get_default_loadout(character_class_id: String) -> Dictionary:
	var character := _get_character(character_class_id)
	var result: Dictionary = {}
	if character == null:
		return result
	if not character.skills.is_empty():
		for index in range(character.skills.size()):
			var skill := character.skills[index]
			if skill == null or not skill.implemented or skill.cast_type in ["passive", "unassigned"]:
				continue
			if skill.slot_key in ["q", "w", "e", "r"]:
				result[skill.slot_key] = get_runtime_skill_id(character, skill, index)
		return result
	for slot in character.skill_loadout:
		var canonical_id := str(character.skill_loadout[slot])
		var skill := SkillRegistry.get_by_id(canonical_id)
		if skill == null or not skill.implemented or skill.cast_type in ["passive", "unassigned"]:
			continue
		result[str(slot)] = skill.legacy_id if not skill.legacy_id.is_empty() else skill.id
	return result


static func canonicalize_skill_id(character_class_id: String, skill_id: String) -> String:
	var candidate := str(skill_id)
	if candidate.is_empty():
		return candidate
	var skill_set := get_skill_set(character_class_id)
	if skill_set.has(candidate):
		return candidate
	var legacy_skill := SkillRegistry.get_by_id(candidate)
	if legacy_skill == null or legacy_skill.animation_key.is_empty():
		return candidate
	for canonical_id in get_skill_ids(character_class_id):
		var canonical_skill := SkillRegistry.get_by_id(str(canonical_id))
		if canonical_skill != null and canonical_skill.animation_key == legacy_skill.animation_key:
			return str(canonical_id)
	return candidate
