extends Node

var failures: Array[String] = []

func _ready():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures.append(message)
		push_error("SMOKE TEST: " + message)

func _run():
	_check(GameData.characters.has(GameData.FIGHTER_ID), "기본 직업 등록 누락")
	_check(GameData.character_profiles.size() == 1 and GameData.get_profile_at_slot(0).get("class_id") == GameData.FIGHTER_ID, "새 저장의 첫 캐릭터 누락")
	_check(GameData.get_character_slot_count() == CharacterSlotManager.DEFAULT_SLOTS, "기본 슬롯 수 변경")
	GameData.character_profiles.clear()
	GameData.character_slot_manager.initialize()
	GameData.active_character_id = ""
	GameData.last_selected_character_id = ""

	var first_id := GameData.create_character_profile(0, GameData.FIGHTER_ID, "첫무도가")
	_check(not first_id.is_empty(), "첫 캐릭터 생성 실패")
	var class_id := GameData.FIGHTER_ID
	GameData.player_gold = 10000
	var purchase_count := ceili(float(GameData.get_character_xp_to_next(class_id)) / GameData.get_character_xp_per_purchase())
	for purchase in purchase_count:
		_check(GameData.purchase_character_experience(class_id), "영구 캐릭터 경험치 구매 실패")
	var first_level := GameData.get_character_total_level(class_id)
	_check(first_level > 1, "경험치 구매 후 영구 레벨업 누락")

	var second_id := GameData.create_character_profile(1, GameData.FIGHTER_ID, "둘째무도가")
	_check(not second_id.is_empty(), "두 번째 캐릭터 생성 실패")
	_check(first_id != second_id, "캐릭터 고유 ID 중복")
	_check(GameData.get_character_total_level(class_id) == 1, "새 캐릭터에 다른 캐릭터의 영구 성장 적용")
	_check(GameData.activate_character_profile(first_id), "첫 캐릭터 재활성화 실패")
	_check(GameData.get_character_total_level(class_id) == first_level, "캐릭터별 영구 레벨이 분리되지 않음")
	_check(GameData.player_level == 1 and GameData.player_current_xp == 0, "서바이벌 진행도가 영구 저장에서 복원됨")

	GameManager.card_manager.ensure_starter_collection()
	GameManager.deck_manager.ensure_starter_deck(GameManager.card_manager.owned)
	_check(GameManager.deck_manager.deck.size() == 12, "기본 덱이 12장이 아님")
	_check(GameManager.deck_manager.validate_deck(GameManager.card_manager.owned), "보유 수량 대비 덱 검증 실패")
	var battle := CardBattleManager.new()
	add_child(battle)
	_check(battle.start_dungeon(), "카드 던전 시작 실패")
	_check(battle.hand.size() == 5, "전투 시작 시 5장 드로우 실패")
	_check(battle.energy == 3, "전투 시작 에너지가 3이 아님")
	await _check_survival_run(first_id, second_id)

	_check(GameData.delete_character_profile(second_id), "개별 캐릭터 삭제 실패")
	_check(GameData.character_profiles.has(first_id), "다른 캐릭터 삭제 시 첫 캐릭터 데이터 손상")
	_check_legacy_slots()

	if failures.is_empty():
		print("SMOKE_TEST_OK: profiles, migration, growth, deck, augment picks and survival rewards")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_FAILED: ", failures)
		get_tree().quit(1)

func _check_legacy_slots():
	var old_profiles := {}
	for cls in ["warrior", "mage"]:
		var stats: Dictionary = StatManager.LEGACY_STATS[cls].duplicate()
		var points := 3 if cls == "mage" else 1
		stats.INT += points
		var old_deck := CardDatabase.STARTER_DECK.duplicate()
		if cls == "mage":
			old_deck[0] = "burn"
		old_profiles[cls] = {
			"id": cls, "class_id": cls, "name": cls, "best_survival_level": 8 + points,
			"state": {
				"characters": {cls: {"attributes": stats, "stat_points_spent": points, "growth_migration_v2": true}},
				"deck": {"cards": old_deck, "name": cls},
				"player_gold": 100 * points,
				"party_slots": ["warrior", "mage"]
			}
		}
	var legacy := {"schema_version": 2, "character_slots": ["warrior", null, "mage"], "last_selected_character_id": "mage", "character_profiles": old_profiles}
	var file := FileAccess.open(GameData.SAVE_FILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(GameData.load_from_disk(), "기존 슬롯 파일 읽기 실패")
	for index in [0, 2]:
		var profile := GameData.get_profile_at_slot(index)
		var old_id := "mage" if index == 2 else "warrior"
		var points := 3 if index == 2 else 1
		_check(profile.get("id") == old_id and profile.get("name") == old_id and profile.get("class_id") == GameData.FIGHTER_ID, "슬롯 ID, 이름 또는 무도가 이전 실패")
		_check(GameData.activate_character_profile(old_id), "이전된 캐릭터 접속 실패")
		_check(GameData.get_character_stat_manager(GameData.FIGHTER_ID).get_stat("INT") == int(StatManager.FIGHTER_STATS.INT) + points, "투자한 INT 이전 실패")
		_check(GameData.player_gold == points * 100 and GameManager.deck_manager.deck_name == old_id, "슬롯별 골드 또는 덱 혼합")
		_check(GameManager.deck_manager.deck[0] == ("burn" if index == 2 else "strike") and profile.best_survival_level == 8 + points, "덱 구성 또는 기록 손실")
	_check(GameData.character_slot_manager.expand_slots(6) and GameData.save_to_disk(), "슬롯 확장 저장 실패")
	_check(GameData.load_from_disk() and GameData.get_character_slot_count() == 6, "슬롯 확장 복원 실패")
	_check(GameData.get_character_stat_manager(GameData.FIGHTER_ID).get_stat("INT") == int(StatManager.FIGHTER_STATS.INT) + 3, "이전 능력치 중복 적용")

func _check_survival_run(first_id: String, second_id: String):
	var deck := GameManager.deck_manager
	var cards := GameManager.card_manager
	var custom := ["strike", "strike", "strike", "strike", "guard", "guard", "guard", "guard", "bleed", "bleed", "blood_burst", "burn"]
	_check(deck.set_deck_checked(custom, cards.owned), "커스텀 덱 편성 실패")
	GameManager._prepare_battle("stage_1")
	GameManager.starting_draft_picks = 0
	var stage = preload("res://scenes/stages/stage_grassland.tscn").instantiate()
	add_child(stage)
	var player = stage.get_node("Player")
	var panel = stage.get_node("LevelUpPanel")
	player.gain_xp(player.xp_to_next_level)
	_check(not panel.visible and player.level == 2, "전투 Lv.2에서 증강 선택이 발생함")
	while player.level < 5:
		player.gain_xp(player.xp_to_next_level)
	_check(panel.visible and panel.current_upgrades.size() == 3, "전투 Lv.5에서 증강 3장 제시 실패")
	var seen := {}
	for choice in panel.current_upgrades:
		_check(not SurvivalCardDatabase.get_card(choice.id).is_empty() and not seen.has(choice.id), "미등록 또는 중복 증강 제시")
		seen[choice.id] = true
	var chosen_id: String = panel.current_upgrades[0].id
	panel._apply_upgrade_at(0)
	_check(not panel.visible and deck.deck == custom, "선택 후 편성 덱 변경")
	_check(GameData.survival_card_counts.get(chosen_id, 0) == 1, "선택한 증강 적용 누락")
	GameManager.add_dungeon_gold(25)
	var gold_before := GameData.player_gold
	GameManager.game_over()
	GameManager.game_over()
	_check(GameData.player_gold == gold_before + 12 and GameData.last_battle_result.gold_earned == 12, "사망 보상 정산 또는 중복 방지 실패")
	stage.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	GameManager.current_location = GameManager.Location.LOBBY
	GameData.end_survival_run()
	_check(GameData.activate_character_profile(second_id), "테스트 캐릭터 전환 실패")
	_check(deck.deck != custom, "다른 캐릭터에게 덱이 전달됨")
	_check(GameData.activate_character_profile(first_id), "보상 캐릭터 복귀 실패")
	_check(deck.deck == custom, "커스텀 덱 복원 실패")
	_check(GameData.player_gold == gold_before + 12, "재접속 후 전투 보상 누락")
