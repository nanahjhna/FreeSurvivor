extends Node

## Runtime factory for registered character visuals.
const FALLBACK_CHARACTER_MODEL := "res://assets/char/char03/char03.glb"

func get_definition(player_id: String) -> Dictionary:
	var character := CharacterRegistry.get_by_id(player_id)
	var definition: Variant = GameData.characters.get(player_id, {})
	if character != null and not GameData.characters.has(player_id):
		definition = GameData.characters.get(character.id, GameData.characters.get(character.legacy_id, {}))
	if not definition is Dictionary:
		return {}
	var resolved: Dictionary = definition.duplicate(true)
	if character != null and character.model_scene != null:
		resolved["model_scene"] = character.model_scene.resource_path
		resolved["model_scale"] = character.model_scale
	var scene_path := str(resolved.get("model_scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		if ResourceLoader.exists(FALLBACK_CHARACTER_MODEL):
			push_warning("캐릭터 모델을 찾지 못해 기본 모델을 사용합니다: %s -> %s" % [scene_path, FALLBACK_CHARACTER_MODEL])
			resolved["model_scene"] = FALLBACK_CHARACTER_MODEL
		else:
			push_warning("캐릭터 모델과 기본 대체 모델이 모두 없습니다: %s" % scene_path)
	return resolved


func has_model_definition(player_id: String) -> bool:
	var scene_path := str(get_definition(player_id).get("model_scene", ""))
	return not scene_path.is_empty() and ResourceLoader.exists(scene_path)


func create_model(player_id: String, parent: Node3D) -> Node3D:
	var definition := get_definition(player_id)
	var scene_path := str(definition.get("model_scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("플레이어 모델이 등록되지 않았습니다: %s" % player_id)
		return null
	var model_scene := load(scene_path) as PackedScene
	if model_scene == null:
		push_warning("플레이어 모델 씬을 불러오지 못했습니다: %s" % scene_path)
		return null
	var model := model_scene.instantiate() as Node3D
	if model == null:
		push_warning("플레이어 모델의 루트는 Node3D여야 합니다: %s" % scene_path)
		return null
	model.name = "CharacterModel_%s" % player_id
	var model_scale: Variant = definition.get("model_scale", Vector3.ONE)
	if model_scale is Vector3:
		model.scale = model_scale
	parent.add_child(model)
	return model


func get_animation_profile(player_id: String) -> String:
	return str(get_definition(player_id).get("animation_profile", player_id))


func get_animation_aliases(player_id: String) -> Dictionary:
	var character := CharacterRegistry.get_by_id(player_id)
	if character != null and not character.animation_aliases.is_empty():
		return character.animation_aliases.duplicate(true)
	var aliases: Variant = get_definition(player_id).get("animation_aliases", {})
	return aliases.duplicate(true) if aliases is Dictionary else {}


func get_skill_animation_key(skill_id: String, slot_key: String = "") -> String:
	var character := CharacterRegistry.get_by_id(GameData.get_leader_id())
	if character != null:
		for index in range(character.skills.size()):
			var character_skill := character.skills[index]
			if character_skill != null and (character_skill.id == skill_id or character_skill.legacy_id == skill_id):
				return character_skill.animation_key
			if character_skill != null and CharacterSkillDatabase.get_runtime_skill_id(character, character_skill, index) == skill_id:
				return character_skill.animation_key
		if not slot_key.is_empty():
			for character_skill in character.skills:
				if character_skill != null and character_skill.slot_key == slot_key:
					return character_skill.animation_key
	var skill := SkillRegistry.get_by_id(skill_id)
	return skill.animation_key if skill != null else "AttackAlt"
