extends Node

const MONSTER_FOLDER := "res://data/monsters"
var _by_id: Dictionary = {}
var _aliases: Dictionary = {}


func _ready() -> void:
	_scan_folder()
	validate_refs()


func _scan_folder() -> void:
	_by_id.clear()
	_aliases.clear()
	var files := ResourceLoader.list_directory(MONSTER_FOLDER)
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var path := MONSTER_FOLDER.path_join(file_name)
		var monster := ResourceLoader.load(path) as MonsterData
		if monster == null:
			push_warning("MonsterRegistry가 MonsterData를 읽지 못했습니다: " + path)
			continue
		register(monster)


func register(monster: MonsterData) -> bool:
	if monster == null or monster.id.strip_edges().is_empty():
		push_warning("MonsterRegistry: ID가 비어 있는 리소스는 등록할 수 없습니다.")
		return false
	if _by_id.has(monster.id):
		push_warning("MonsterRegistry: 중복 ID " + monster.id)
		return false
	_by_id[monster.id] = monster
	if not monster.legacy_id.is_empty():
		if _aliases.has(monster.legacy_id):
			push_warning("MonsterRegistry: 중복 legacy_id " + monster.legacy_id)
		else:
			_aliases[monster.legacy_id] = monster.id
	return true


func get_by_id(monster_id: String) -> MonsterData:
	var canonical_id := str(_aliases.get(monster_id, monster_id))
	var resource: Variant = _by_id.get(canonical_id)
	return resource as MonsterData if resource is MonsterData else null


func all() -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	var ids: Array = _by_id.keys()
	ids.sort()
	for canonical_id in ids:
		result.append(_by_id[canonical_id] as MonsterData)
	return result


func has(monster_id: String) -> bool:
	return get_by_id(monster_id) != null


func get_card_floor_definition(floor: int) -> Dictionary:
	for monster in all():
		if monster.card_floor == floor:
			return monster.to_dictionary()
	return {}


func validate_refs() -> Array[String]:
	var issues: Array[String] = []
	for monster in all():
		if monster.model_scene == null:
			issues.append("%s: model_scene 누락" % monster.id)
		for skill_id in monster.skill_ids:
			if not SkillRegistry.has(skill_id):
				issues.append("%s: 등록되지 않은 스킬 참조 %s" % [monster.id, skill_id])
	for issue in issues:
		push_warning("MonsterRegistry 참조 오류: " + issue)
	return issues
