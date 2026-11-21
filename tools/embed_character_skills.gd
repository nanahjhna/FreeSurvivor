extends SceneTree

const CHARACTER_FOLDER := "res://data/characters"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := root.get_node_or_null("SkillRegistry")
	if registry == null:
		push_error("SkillRegistry 오토로드를 찾을 수 없습니다.")
		quit(1)
		return
	var directory := DirAccess.open(CHARACTER_FOLDER)
	if directory == null:
		push_error("캐릭터 폴더를 열 수 없습니다: " + CHARACTER_FOLDER)
		quit(1)
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
			continue
		var changed := false
		if character.skills.is_empty():
			var slot_by_skill: Dictionary = {}
			for slot in character.skill_loadout:
				slot_by_skill[str(character.skill_loadout[slot])] = str(slot)
			var source_ids: Array[String] = []
			for skill_id in character.skill_ids:
				if not source_ids.has(skill_id):
					source_ids.append(skill_id)
			for skill_id in character.skill_loadout.values():
				var value := str(skill_id)
				if not source_ids.has(value):
					source_ids.append(value)

			var embedded_skills: Array[SkillData] = []
			for source_id in source_ids:
				var source_skill := registry.call("get_by_id", source_id) as SkillData
				if source_skill == null:
					push_warning("%s: 스킬 리소스를 찾지 못했습니다: %s" % [character.id, source_id])
					continue
				var skill_copy := source_skill.duplicate(true) as SkillData
				skill_copy.resource_path = ""
				skill_copy.slot_key = str(slot_by_skill.get(source_id, ""))
				if skill_copy.slot_key == "w":
					skill_copy.animation_key = "Kick"
				elif skill_copy.slot_key in ["q", "e", "r"]:
					skill_copy.animation_key = "AttackAlt"
				embedded_skills.append(skill_copy)

			character.skills = embedded_skills
			character.skill_ids.clear()
			character.skill_loadout.clear()
			changed = true

		if character.animation_aliases.is_empty():
			character.animation_aliases = _get_animation_aliases(character.animation_profile)
			changed = not character.animation_aliases.is_empty() or changed
		if not changed:
			continue
		var error := ResourceSaver.save(character, path)
		if error != OK:
			push_error("캐릭터 스킬 내장 저장 실패(%d): %s" % [error, path])
			quit(1)
			return
		print("CHARACTER_DATA_UPDATED %s skills=%d animations=%d" % [character.id, character.skills.size(), character.animation_aliases.size()])
	quit(0)


func _get_animation_aliases(profile: String) -> Dictionary:
	match profile:
		"char02":
			return {
				"Idle": ["Idle_Sword_RT", "Idle"], "Walk": ["Polearm_Run_RT", "Sword_Run_RT", "Run"],
				"Run": ["Polearm_Run_RT", "Sword_Run_RT", "Run"], "Attack": ["Sword_Regular_A_RT", "Sword_Attack_RT", "Sword_Attack_A_RT"],
				"AttackAlt": ["Sword_Regular_B_RT", "Sword_Attack_B_RT", "Sword_Regular_A_RT"], "Kick": ["Sword_Attack_RT", "Sword_Regular_A_RT"]
			}
		"fighter", "mage":
			return {
				"Idle": ["Breathing_Idle_RT"], "Walk": ["Run_Female_RT"], "Run": ["Run_Female_RT"],
				"Attack": ["Standing_1H_Magic_Attack_01_RT", "Standing_1H_Magic_Attack_03_RT"],
				"AttackAlt": ["Standing_1H_Magic_Attack_03_RT", "Standing_1H_Magic_Attack_01_RT"],
				"Kick": ["Standing_2H_Magic_Area_Attack_02_RT", "Standing_2H_Magic_Attack_01_RT"],
				"Hit": ["Hit_Chest_RT"], "Death": ["Livershot_Knockdown_RT"]
			}
		"archer":
			return {
				"Idle": ["Breathing_Idle_RT", "Idle_Bow_RT", "Bow_Idle_RT", "Idle"],
				"Walk": ["Walk_Bow_RT", "Walk_Female_RT", "Walk_Forward_RT", "Walk_RT", "Walk"],
				"Run": ["Run_Bow_RT", "Run_Female_RT", "Bow_Run_RT", "Run_Forward_RT", "Run"],
				"Attack": ["Bow_Release_RT", "Bow_Shoot_RT", "Bow_Attack_RT", "Bow_Pull_Back_RT", "Attack"],
				"AttackAlt": ["Bow_Release_RT", "Bow_Shoot_RT", "Bow_Attack_RT", "Attack"], "Kick": ["Bow_Release_RT", "Bow_Shoot_RT", "Attack"],
				"Hit": ["Hit_Chest_RT", "Hit_React_RT", "Hit"], "Death": ["Livershot_Knockdown_RT", "Death"]
			}
		"paladin":
			return {
				"Idle": ["Action_Idle_To_Fight_Idle_RT", "One_Hand_Weapon_Idle_RT", "Breathing_Idle_RT", "Idle"],
				"Walk": ["Fast_Run_RT", "Sword_Run_RT", "Walk_Forward_RT", "Walk"],
				"Run": ["Fast_Run_RT", "Sword_Run_RT", "Run_Forward_RT", "Run"],
				"Attack": ["Great_Sword_Kick_RT", "Combo_Punch_RT", "Sword_Regular_A_RT", "Attack"],
				"AttackAlt": ["Combo_Punch_RT", "Great_Sword_Kick_RT", "Sword_Regular_A_RT", "Attack"],
				"Kick": ["Great_Sword_Kick_RT", "Combo_Punch_RT", "Attack"], "Hit": ["Medium_Hit_To_Head_RT", "Hit_Chest_RT"],
				"Death": ["Spin_Death_RT", "Livershot_Knockdown_RT", "Death"]
			}
	return {}
