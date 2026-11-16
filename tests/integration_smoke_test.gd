extends Node

var failures: Array[String] = []

func _initialize():
	call_deferred("_run")

func _ready():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures.append(message)
		push_error("SMOKE TEST: " + message)

func _run():
	_check(GameData.characters.keys() == [GameData.FIGHTER_ID], "현재 생성 가능한 직업은 무도가 한 종류여야 함")
	_check(GameData.character_profiles.size() == 1 and GameData.get_profile_at_slot(0).get("class_id") == GameData.FIGHTER_ID, "새 저장의 첫 무도가 누락")
	_check(GameData.get_character_slot_count() == CharacterSlotManager.DEFAULT_SLOTS, "기본 슬롯 수 변경")
	GameData.character_profiles.clear()
	GameData.character_slot_manager.initialize()
	GameData.active_character_id = ""
	GameData.last_selected_character_id = ""

	var first_id := GameData.create_character_profile(0, GameData.FIGHTER_ID, "첫무도가")
	_check(not first_id.is_empty(), "첫 캐릭터 생성 실패")
	GameData.characters[GameData.FIGHTER_ID]["stat_points"] = 1
	_check(GameData.allocate_character_stat(GameData.FIGHTER_ID, "STR"), "영구 STR 투자 실패")
	var first_str := GameData.get_character_stat_manager(GameData.FIGHTER_ID).get_stat("STR")

	var second_id := GameData.create_character_profile(1, GameData.FIGHTER_ID, "둘째무도가")
	_check(not second_id.is_empty(), "두 번째 캐릭터 생성 실패")
	_check(first_id != second_id, "캐릭터 고유 ID 중복")
	_check(GameData.activate_character_profile(first_id), "첫 캐릭터 재활성화 실패")
	_check(GameData.get_character_stat_manager(GameData.FIGHTER_ID).get_stat("STR") == first_str, "캐릭터별 영구 능력치가 분리되지 않음")
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
	_check_survival_deck(first_id, second_id)

	_check(GameData.delete_character_profile(second_id), "개별 캐릭터 삭제 실패")
	_check(GameData.character_profiles.has(first_id), "다른 캐릭터 삭제 시 첫 캐릭터 데이터 손상")
	_check_legacy_slots()

	if failures.is_empty():
		print("SMOKE_TEST_OK: profiles, isolation, survival deck choices, effects, rewards, dungeon draw and energy")
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

func _check_survival_deck(first_id: String, second_id: String):
	var deck := GameManager.deck_manager
	var cards := GameManager.card_manager
	for id in CardDatabase.all_ids():
		_check(not CardDatabase.get_survival_upgrade(id).is_empty(), "서바이벌 효과 누락 " + id)
	var custom := ["strike", "strike", "strike", "strike", "guard", "guard", "guard", "guard", "bleed", "bleed", "blood_burst", "burn"]
	_check(deck.set_deck_checked(custom, cards.owned), "커스텀 덱 편성 실패")
	GameData.begin_survival_run()
	var stage = preload("res://scenes/stages/stage_grassland.tscn").instantiate()
	add_child(stage)
	var player = stage.get_node("Player")
	var panel = stage.get_node("LevelUpPanel")
	player.gain_xp(player.xp_to_next_level)
	_check(panel.visible and panel.current_upgrades.size() == 3, "덱 카드 3장 제시 실패")
	var seen := {}
	for choice in panel.current_upgrades:
		_check(choice.id in custom and not seen.has(choice.id), "덱에 없거나 중복된 선택지")
		seen[choice.id] = true
	panel._on_card_selected(0)
	_check(not panel.visible and deck.deck == custom, "선택 후 편성 덱 변경")
	var old_hp: float = player.max_hp
	GameData.apply_upgrade(CardDatabase.get_survival_upgrade("fortress"))
	_check(is_equal_approx(player.max_hp, old_hp + 32), "최대 HP 카드 적용 실패")
	player.card_hit_bonuses.clear()
	GameData.apply_upgrade(CardDatabase.get_survival_upgrade("bleed"))
	GameData.apply_upgrade(CardDatabase.get_survival_upgrade("blood_burst"))
	var enemy := preload("res://scenes/monsters/zombie/zombie.tscn").instantiate() as BaseMonster
	stage.add_child(enemy)
	_check(is_equal_approx(player._apply_card_hit_effects(enemy, 10.0), 10.0), "첫 공격에 출혈 연계 발동")
	_check(is_equal_approx(player._apply_card_hit_effects(enemy, 10.0), 20.0), "출혈 연계 누락")
	var enemy_hp := enemy.current_hp
	for tick in range(3):
		enemy._tick_card_statuses(1.0)
	_check(is_equal_approx(enemy.current_hp, enemy_hp - 6) and enemy.card_statuses.is_empty(), "출혈 피해 또는 만료 오류")
	var before := cards.owned.duplicate()
	GameManager.victory()
	GameManager.victory()
	var reward_id := ""
	var copies := 0
	for id in cards.owned:
		var gained := int(cards.owned[id]) - int(before.get(id, 0))
		if gained > 0:
			copies += gained
			reward_id = id
	_check(copies == 1 and deck.deck == custom, "클리어 보상 또는 덱 보존 실패")
	if reward_id != "":
		_check(GameData.last_battle_result.cards_earned == [CardDatabase.get_card(reward_id).name], "결과 카드 표시 오류")
	stage.free()
	get_tree().paused = false
	GameManager.current_location = GameManager.Location.LOBBY
	GameData.end_survival_run()
	_check(GameData.activate_character_profile(second_id), "테스트 캐릭터 전환 실패")
	_check(deck.deck != custom, "다른 캐릭터에게 덱이 전달됨")
	_check(GameData.activate_character_profile(first_id), "보상 캐릭터 복귀 실패")
	_check(deck.deck == custom, "커스텀 덱 복원 실패")
	if reward_id != "":
		_check(cards.get_owned_count(reward_id) == int(before.get(reward_id, 0)) + 1, "보상 카드 복원 실패")
