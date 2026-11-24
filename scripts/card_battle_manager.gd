class_name CardBattleManager
extends Node

signal state_changed()
signal message_emitted(text: String)
signal floor_cleared(reward: Dictionary)
signal dungeon_finished(victory: bool, summary: Dictionary)

const MAX_FLOOR = 5
const HAND_LIMIT = 10
const DRAW_COUNT = 5

const ENEMIES := {
	1: {"name":"묘지 쥐", "icon":"🐀", "hp":42, "pattern":[{"type":"attack","value":7}, {"type":"attack","value":8}, {"type":"defend","value":6}]},
	2: {"name":"해골 병사", "icon":"💀", "hp":58, "pattern":[{"type":"attack","value":9}, {"type":"defend","value":8}, {"type":"heavy","value":14}]},
	4: {"name":"강화 뮤턴트", "icon":"👹", "hp":88, "pattern":[{"type":"attack","value":12}, {"type":"buff","value":3}, {"type":"heavy","value":19}]},
	5: {"name":"심연의 카드 군주", "icon":"🐲", "hp":135, "pattern":[{"type":"attack","value":14}, {"type":"status","value":5}, {"type":"defend","value":14}, {"type":"heavy","value":24}]}
}

var floor := 1
var max_player_hp := 100.0
var player_hp := 100.0
var player_block := 0.0
var max_energy := 3
var energy := 3
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var hand: Array[String] = []
var exhaust_pile: Array[String] = []
var player_statuses: Dictionary = {}
var enemy_statuses: Dictionary = {}
var enemy: Dictionary = {}
var enemy_hp := 0.0
var enemy_block := 0.0
var enemy_pattern_index := 0
var enemy_strength := 0
var attacks_used_this_turn := 0
var waiting_for_reward := false
var run_finished := false
var rewards_claimed: Dictionary = {}
var character_stats: StatManager
var class_id := GameData.FIGHTER_ID


func start_dungeon() -> bool:
	GameManager.card_manager.ensure_starter_collection()
	GameManager.deck_manager.ensure_starter_deck(GameManager.card_manager.owned)
	if not GameManager.deck_manager.validate_deck(GameManager.card_manager.owned):
		return false
	class_id = GameData.get_leader_id()
	character_stats = GameData.get_character_stat_manager(class_id)
	max_player_hp = character_stats.max_hp() + GameData.get_active_character_equipment_hp()
	player_hp = max_player_hp
	floor = 1
	rewards_claimed.clear()
	run_finished = false
	_start_floor()
	return true


func _start_floor():
	waiting_for_reward = false
	player_block = 0.0
	player_statuses.clear()
	enemy_statuses.clear()
	if floor == 3:
		var healed := minf(max_player_hp - player_hp, max_player_hp * 0.25)
		player_hp += healed
		waiting_for_reward = true
		var event_reward := {"gold": 80, "growth": 1, "card": "adrenaline", "event": true, "message":"고대 성소에서 체력을 회복했습니다."}
		floor_cleared.emit(event_reward)
		state_changed.emit()
		return
	enemy = ENEMIES.get(floor, ENEMIES[1]).duplicate(true)
	enemy_hp = float(enemy.hp)
	enemy_block = 0.0
	enemy_pattern_index = 0
	enemy_strength = 0
	draw_pile = Array(GameManager.deck_manager.deck.duplicate(), TYPE_STRING, &"", null)
	draw_pile.shuffle()
	discard_pile.clear()
	hand.clear()
	exhaust_pile.clear()
	_start_player_turn()


func _start_player_turn():
	player_block = 0.0
	energy = max_energy
	attacks_used_this_turn = 0
	_tick_status(enemy_statuses, true)
	if enemy_hp <= 0:
		_complete_floor()
		return
	draw_cards(DRAW_COUNT)
	state_changed.emit()


func draw_cards(count: int):
	for _i in range(count):
		if hand.size() >= HAND_LIMIT:
			break
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		hand.append(draw_pile.pop_back())


func can_play_card(hand_index: int) -> String:
	if waiting_for_reward or run_finished:
		return "지금은 카드를 사용할 수 없습니다."
	if hand_index < 0 or hand_index >= hand.size():
		return "카드를 선택해 주세요."
	var card := CardDatabase.get_card(hand[hand_index])
	if card.is_empty():
		return "알 수 없는 카드입니다."
	if energy < int(card.get("cost", 0)):
		return "에너지가 부족합니다."
	if str(card.get("type", "")) == "consume_status" and get_enemy_status(str(card.get("status", ""))) <= 0:
		return "필요한 상태이상이 없습니다."
	return ""

func get_card_preview(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size(): return {}
	var card := CardDatabase.get_card(hand[hand_index])
	var card_type := str(card.get("type", ""))
	var scaling := str(card.get("scaling", "physical"))
	var value := float(card.get("value", 0))
	var preview := {"damage":0, "block":0, "status":"", "energy_after":energy - int(card.get("cost", 0)), "combo":""}
	if card_type in ["attack", "status_attack"]:
		preview.damage = int(_estimate_damage(value, scaling) * int(card.get("hits", 1)))
	if card_type == "block": preview.block = int(scale_block(value))
	if card_type == "status_attack": preview.status = "%s %d" % [card.get("status", ""), int(card.get("stacks", 0))]
	if card_type == "consume_status":
		var stacks := get_enemy_status(str(card.get("status", "")))
		preview.damage = int(_estimate_damage(value * stacks, scaling))
		preview.combo = "%s %d중첩 소모" % [card.get("status", ""), stacks]
	if card_type == "block_attack":
		preview.damage = int(_estimate_damage(value, scaling) + player_block * float(card.get("block_ratio", 0)))
		preview.combo = "현재 방어도 연계"
	if card_type == "finisher":
		preview.damage = int(_estimate_damage(value + attacks_used_this_turn * float(card.get("per_attack", 0)), scaling))
		preview.combo = "공격 카드 %d회 연계" % attacks_used_this_turn
	preview.damage = maxi(0, int(preview.damage) - int(enemy_block))
	return preview

func _estimate_damage(value: float, scaling: String) -> float:
	var bonus := character_stats.get_stat("INT") * 0.055 if scaling == "magic" else character_stats.get_stat("STR") * 0.05
	var strength := int(player_statuses.get("strength", {}).get("stacks", 0))
	var weakness := 0.75 if player_statuses.has("weak") else 1.0
	var vulnerable := 1.5 if enemy_statuses.has("vulnerable") else 1.0
	return maxf(0.0, (value * (1.0 + bonus) + strength) * weakness * vulnerable)

func has_combo_for_card(hand_index: int) -> bool:
	var preview := get_card_preview(hand_index)
	return not str(preview.get("combo", "")).is_empty()

func has_playable_card() -> bool:
	for index in range(hand.size()):
		if can_play_card(index).is_empty(): return true
	return false


func play_card(hand_index: int) -> bool:
	var reason := can_play_card(hand_index)
	if not reason.is_empty():
		message_emitted.emit(reason)
		return false
	var card_id := hand[hand_index]
	var card := CardDatabase.get_card(card_id)
	energy -= int(card.get("cost", 0))
	hand.remove_at(hand_index)
	if card.get("tags", []).has("attack"):
		attacks_used_this_turn += 1
	var message := CardEffectResolver.resolve(card, self)
	if bool(card.get("exhaust", false)):
		exhaust_pile.append(card_id)
	else:
		discard_pile.append(card_id)
	message_emitted.emit(message)
	if enemy_hp <= 0:
		_complete_floor()
	else:
		state_changed.emit()
	return true


func end_player_turn():
	if waiting_for_reward or run_finished:
		return
	discard_pile.append_array(hand)
	hand.clear()
	_enemy_turn()


func _enemy_turn():
	enemy_block = 0.0
	var intent := get_enemy_intent()
	match str(intent.get("type", "attack")):
		"attack", "heavy":
			_damage_player(float(intent.get("value", 0)) + enemy_strength)
		"defend": enemy_block += float(intent.get("value", 0))
		"buff": enemy_strength += int(intent.get("value", 0))
		"status":
			_damage_player(float(intent.get("value", 0)) + enemy_strength)
			add_player_status("weak", 2, 2)
	enemy_pattern_index += 1
	_tick_status(player_statuses, false)
	if player_hp <= 0:
		_finish_dungeon(false)
	else:
		_start_player_turn()


func get_enemy_intent() -> Dictionary:
	var pattern: Array = enemy.get("pattern", [])
	if pattern.is_empty():
		return {"type":"attack", "value":5}
	return pattern[enemy_pattern_index % pattern.size()]


func get_intent_text() -> String:
	var intent := get_enemy_intent()
	match str(intent.get("type", "attack")):
		"attack":
			var attack_damage := int(intent.value) + enemy_strength
			return "다음 행동: 공격 %d · 현재 방어 기준 HP 피해 %d" % [attack_damage, maxi(0, attack_damage - int(player_block))]
		"heavy":
			var heavy_damage := int(intent.value) + enemy_strength
			return "다음 행동: 강력한 공격 %d · 현재 방어 기준 HP 피해 %d" % [heavy_damage, maxi(0, heavy_damage - int(player_block))]
		"defend": return "다음 행동: 방어도 %d" % int(intent.value)
		"buff": return "다음 행동: 공격력 +%d" % int(intent.value)
		"status": return "다음 행동: 약화 공격 %d" % int(intent.value)
	return "다음 행동: 알 수 없음"


func scale_card_damage(value: float, scaling: String) -> float:
	var bonus := character_stats.get_stat("INT") * 0.055 if scaling == "magic" else character_stats.get_stat("STR") * 0.05
	var strength := int(player_statuses.get("strength", {}).get("stacks", 0))
	var weakness := 0.75 if player_statuses.has("weak") else 1.0
	var vulnerable := 1.5 if enemy_statuses.has("vulnerable") else 1.0
	var crit_chance := character_stats.crit_rate() / 100.0
	var crit := 1.5 if randf() < crit_chance else 1.0
	return maxf(0.0, (value * (1.0 + bonus) + strength) * weakness * vulnerable * crit)


func scale_block(value: float) -> float:
	return value * (1.0 + float(character_stats.base_stats.VIT) * 0.04)


func damage_enemy(amount: float):
	var blocked := minf(enemy_block, amount)
	enemy_block -= blocked
	enemy_hp = maxf(0.0, enemy_hp - (amount - blocked))


func _damage_player(amount: float):
	var blocked := minf(player_block, amount)
	player_block -= blocked
	player_hp = maxf(0.0, player_hp - (amount - blocked))
	message_emitted.emit("적의 공격: %d 피해" % int(amount - blocked))


func add_enemy_status(id: String, stacks: int, duration: int):
	_add_status(enemy_statuses, id, stacks, duration)

func add_player_status(id: String, stacks: int, duration: int):
	_add_status(player_statuses, id, stacks, duration)

func _add_status(target: Dictionary, id: String, stacks: int, duration: int):
	if id.is_empty(): return
	var current: Dictionary = target.get(id, {"stacks":0, "duration":duration})
	current.stacks = int(current.get("stacks", 0)) + stacks
	current.duration = maxi(int(current.get("duration", 0)), duration)
	target[id] = current

func get_enemy_status(id: String) -> int:
	return int(enemy_statuses.get(id, {}).get("stacks", 0))

func consume_enemy_status(id: String) -> int:
	var stacks := get_enemy_status(id)
	enemy_statuses.erase(id)
	return stacks

func _tick_status(target: Dictionary, is_enemy: bool):
	for id in target.keys():
		var status: Dictionary = target[id]
		if id in ["bleed", "burn", "poison"]:
			var damage := float(status.get("stacks", 0))
			if is_enemy: damage_enemy(damage)
			else: _damage_player(damage)
		status.duration = int(status.get("duration", 1)) - 1
		if int(status.duration) <= 0: target.erase(id)


func _complete_floor():
	if waiting_for_reward or rewards_claimed.has(floor): return
	waiting_for_reward = true
	var reward := {"gold":40 + floor * 25, "growth":1 if floor >= 4 else 0, "card":_random_reward_card(), "event":false}
	floor_cleared.emit(reward)
	state_changed.emit()


func claim_floor_reward(reward: Dictionary):
	if not waiting_for_reward or rewards_claimed.has(floor): return
	rewards_claimed[floor] = true
	GameData.player_gold += int(reward.get("gold", 0))
	GameData.player_growth_currency += int(reward.get("growth", 0))
	var card_id := str(reward.get("card", ""))
	if not card_id.is_empty(): GameManager.card_manager.add_card(card_id)
	GameData.save_to_disk()
	if floor >= MAX_FLOOR:
		_finish_dungeon(true)
	else:
		floor += 1
		_start_floor()


func _random_reward_card() -> String:
	var ids := CardDatabase.all_ids()
	return str(ids.pick_random()) if not ids.is_empty() else ""


func _finish_dungeon(victory: bool):
	if run_finished: return
	run_finished = true
	waiting_for_reward = false
	var reached := floor if victory else maxi(0, floor - 1)
	var profile := GameData.get_character_profile(GameData.active_character_id)
	profile["card_dungeon_best_floor"] = maxi(int(profile.get("card_dungeon_best_floor", 0)), reached)
	GameData.save_to_disk()
	dungeon_finished.emit(victory, {"floor":floor, "best_floor":profile.card_dungeon_best_floor})
	state_changed.emit()
