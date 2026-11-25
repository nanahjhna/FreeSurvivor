extends Node

const SKILL_FOLDER := "res://data/skills"
var _by_id: Dictionary = {}
var _aliases: Dictionary = {}


func _ready() -> void:
	_scan_folder()
	validate_refs()


func _scan_folder() -> void:
	_by_id.clear()
	_aliases.clear()
	var files := ResourceLoader.list_directory(SKILL_FOLDER)
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var path := SKILL_FOLDER.path_join(file_name)
		var skill := ResourceLoader.load(path) as SkillData
		if skill == null:
			push_warning("SkillRegistry가 SkillData를 읽지 못했습니다: " + path)
			continue
		register(skill)


func register(skill: SkillData) -> bool:
	if skill == null or skill.id.strip_edges().is_empty():
		push_warning("SkillRegistry: ID가 비어 있는 리소스는 등록할 수 없습니다.")
		return false
	if _by_id.has(skill.id):
		push_warning("SkillRegistry: 중복 ID " + skill.id)
		return false
	_by_id[skill.id] = skill
	if not skill.legacy_id.is_empty():
		if _aliases.has(skill.legacy_id):
			push_warning("SkillRegistry: 중복 legacy_id " + skill.legacy_id)
		else:
			_aliases[skill.legacy_id] = skill.id
	return true


func get_by_id(skill_id: String) -> SkillData:
	var canonical_id := str(_aliases.get(skill_id, skill_id))
	var resource: Variant = _by_id.get(canonical_id)
	return resource as SkillData if resource is SkillData else null


func all() -> Array[SkillData]:
	var result: Array[SkillData] = []
	var ids: Array = _by_id.keys()
	ids.sort()
	for canonical_id in ids:
		result.append(_by_id[canonical_id] as SkillData)
	return result


func has(skill_id: String) -> bool:
	return get_by_id(skill_id) != null


func get_legacy_id(skill_id: String) -> String:
	var resource := get_by_id(skill_id)
	if resource == null:
		return ""
	return resource.legacy_id if not resource.legacy_id.is_empty() else resource.id


func get_champion_skills(champion_id: String, implemented_only: bool = false) -> Array[SkillData]:
	var result: Array[SkillData] = []
	var normalized_id := champion_id.to_lower()
	for skill in all():
		if skill.champion_id.to_lower() != normalized_id:
			continue
		if implemented_only and not skill.implemented:
			continue
		result.append(skill)
	return result


func validate_refs() -> Array[String]:
	var issues: Array[String] = []
	for skill in all():
		if not skill.implemented:
			continue
		if skill.cast_type not in ["heal", "passive"] and skill.effect_scene == null:
			issues.append("%s: 실행 가능한 스킬에 effect_scene 누락" % skill.id)
		if skill.cast_type == "passive" and skill.passive_handler.is_empty():
			issues.append("%s: 패시브 처리기 누락" % skill.id)
	for issue in issues:
		push_warning("SkillRegistry 참조 오류: " + issue)
	return issues
