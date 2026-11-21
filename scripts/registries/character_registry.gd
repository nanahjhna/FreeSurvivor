extends Node

const CHARACTER_FOLDER := "res://data/characters"
var _by_id: Dictionary = {}
var _aliases: Dictionary = {}


func _ready() -> void:
	_scan_folder()
	validate_refs()


func _scan_folder() -> void:
	_by_id.clear()
	_aliases.clear()
	var directory := DirAccess.open(CHARACTER_FOLDER)
	if directory == null:
		push_warning("CharacterRegistry 폴더를 열 수 없습니다: " + CHARACTER_FOLDER)
		return
	var paths: Array[String] = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "tres":
			paths.append(CHARACTER_FOLDER.path_join(file_name))
		file_name = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	for path in paths:
		var character := load(path) as CharacterData
		if character == null:
			push_warning("CharacterRegistry가 CharacterData를 읽지 못했습니다: " + path)
			continue
		register(character)


func register(character: CharacterData) -> bool:
	if character == null or character.id.strip_edges().is_empty():
		push_warning("CharacterRegistry: ID가 비어 있는 리소스는 등록할 수 없습니다.")
		return false
	if _by_id.has(character.id):
		push_warning("CharacterRegistry: 중복 ID " + character.id)
		return false
	_by_id[character.id] = character
	if not character.legacy_id.is_empty():
		if _aliases.has(character.legacy_id):
			push_warning("CharacterRegistry: 중복 legacy_id " + character.legacy_id)
		else:
			_aliases[character.legacy_id] = character.id
	return true


func get_by_id(character_id: String) -> CharacterData:
	var canonical_id := str(_aliases.get(character_id, character_id))
	var resource: Variant = _by_id.get(canonical_id)
	return resource as CharacterData if resource is CharacterData else null


func all() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	var ids: Array = _by_id.keys()
	ids.sort()
	for canonical_id in ids:
		result.append(_by_id[canonical_id] as CharacterData)
	return result


func has(character_id: String) -> bool:
	return get_by_id(character_id) != null


func get_legacy_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for character in all():
		var key := character.legacy_id if not character.legacy_id.is_empty() else character.id
		result[key] = character.to_legacy_dictionary()
	return result


func validate_refs() -> Array[String]:
	var issues: Array[String] = []
	for character in all():
		if character.model_scene == null:
			issues.append("%s: model_scene 누락" % character.id)
		if not character.skills.is_empty():
			for skill in character.skills:
				if skill == null:
					issues.append("%s: 비어 있는 내장 스킬 항목" % character.id)
				elif skill.implemented and skill.cast_type not in ["heal", "passive"] and skill.effect_scene == null:
					issues.append("%s/%s: 효과 씬 누락" % [character.id, skill.legacy_id])
				elif skill.implemented and not skill.animation_key.is_empty() and not character.animation_aliases.has(skill.animation_key):
					issues.append("%s/%s: animation_key '%s'가 animation_aliases에 없습니다" % [character.id, skill.legacy_id, skill.animation_key])
		else:
			for skill_id in character.skill_ids:
				if not SkillRegistry.has(skill_id):
					issues.append("%s: 등록되지 않은 스킬 참조 %s" % [character.id, skill_id])
	for issue in issues:
		push_warning("CharacterRegistry 참조 오류: " + issue)
	return issues
