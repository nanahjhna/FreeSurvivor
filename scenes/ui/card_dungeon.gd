extends Control

var battle: CardBattleManager
var floor_label: Label
var enemy_name: Label
var enemy_hp: ProgressBar
var enemy_info: Label
var intent_label: Label
var player_hp: ProgressBar
var player_info: Label
var energy_label: Label
var pile_label: Label
var hand_box: HBoxContainer
var feedback_label: Label
var target_button: Button
var end_turn_button: Button
var selected_hand_index := -1
var overlay: PanelContainer
var overlay_title: Label
var overlay_text: Label
var overlay_button: Button
var pending_reward: Dictionary = {}
var battle_speed := 1.0

func _ready():
	GameManager.current_location = GameManager.Location.CARD_DECK
	_build_ui()
	battle = CardBattleManager.new()
	add_child(battle)
	battle.state_changed.connect(_refresh)
	battle.message_emitted.connect(_show_message)
	battle.floor_cleared.connect(_show_reward)
	battle.dungeon_finished.connect(_show_finish)
	if not battle.start_dungeon():
		_show_message("유효한 12장 덱이 필요합니다.")
		overlay.visible = true
		overlay_title.text = "입장 실패"
		overlay_text.text = "덱 관리 화면에서 12장을 편성해 주세요."
		overlay_button.text = "덱 관리로"
	else:
		_refresh()

func _build_ui():
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UiStyle.ASPHALT
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	floor_label = UiStyle.make_title("", 24)
	floor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(floor_label)
	var leave := UiStyle.make_button("던전 포기", Vector2(150, 44))
	leave.pressed.connect(GameManager.go_to_lobby)
	top.add_child(leave)
	var speed := OptionButton.new()
	speed.custom_minimum_size = Vector2(130, 44)
	for label in ["속도 1x", "속도 2x", "속도 3x"]: speed.add_item(label)
	speed.item_selected.connect(func(index): battle_speed = float(index + 1))
	top.add_child(speed)
	var enemy_panel := UiStyle.make_panel()
	enemy_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(enemy_panel)
	var enemy_box := VBoxContainer.new()
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_panel.add_child(enemy_box)
	enemy_name = UiStyle.make_title("", 30)
	enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_box.add_child(enemy_name)
	var icon := Label.new()
	icon.text = "👹"
	icon.add_theme_font_size_override("font_size", 94)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_box.add_child(icon)
	enemy_hp = ProgressBar.new()
	enemy_hp.custom_minimum_size = Vector2(700, 34)
	enemy_box.add_child(enemy_hp)
	enemy_info = UiStyle.make_label("", 15)
	enemy_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_box.add_child(enemy_info)
	intent_label = UiStyle.make_label("", 19, Color(1, 0.62, 0.42))
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_box.add_child(intent_label)
	target_button = UiStyle.make_button("선택한 카드를 적에게 사용", Vector2(330, 48), true)
	target_button.pressed.connect(_use_selected_card)
	enemy_box.add_child(target_button)
	var cancel_button := UiStyle.make_button("카드 선택 취소", Vector2(220, 42))
	cancel_button.pressed.connect(_cancel_card_selection)
	enemy_box.add_child(cancel_button)
	var player_row := HBoxContainer.new()
	root.add_child(player_row)
	player_hp = ProgressBar.new()
	player_hp.custom_minimum_size = Vector2(430, 32)
	player_row.add_child(player_hp)
	player_info = UiStyle.make_label("", 15)
	player_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_row.add_child(player_info)
	energy_label = UiStyle.make_label("", 22, Color(1, 0.86, 0.3))
	player_row.add_child(energy_label)
	pile_label = UiStyle.make_label("", 15)
	player_row.add_child(pile_label)
	end_turn_button = UiStyle.make_button("턴 종료", Vector2(150, 46))
	end_turn_button.pressed.connect(_end_turn)
	player_row.add_child(end_turn_button)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 245)
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(hand_scroll)
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 10)
	hand_scroll.add_child(hand_box)
	feedback_label = UiStyle.make_label("카드를 선택한 뒤 적을 눌러 사용하세요.", 15, Color(0.75, 0.86, 1))
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(feedback_label)
	_build_overlay()

func _build_overlay():
	overlay = UiStyle.make_panel()
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	overlay.position = Vector2(-310, -180)
	overlay.custom_minimum_size = Vector2(620, 360)
	add_child(overlay)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	overlay.add_child(box)
	overlay_title = UiStyle.make_title("", 30)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_title)
	overlay_text = UiStyle.make_label("", 18)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_text)
	overlay_button = UiStyle.make_button("계속", Vector2(220, 52), true)
	overlay_button.pressed.connect(_overlay_action)
	box.add_child(overlay_button)
	overlay.visible = false

func _refresh():
	if battle == null: return
	floor_label.text = "CARD DUNGEON · %d / %d층" % [battle.floor, CardBattleManager.MAX_FLOOR]
	var is_event := battle.floor == 3 and battle.waiting_for_reward
	enemy_name.text = "보상 이벤트" if is_event else "%s  %s" % [battle.enemy.get("icon", "👹"), battle.enemy.get("name", "적")]
	enemy_hp.max_value = maxf(1.0, float(battle.enemy.get("hp", 1)))
	enemy_hp.value = battle.enemy_hp
	enemy_info.text = "HP %d / %d · 방어도 %d · 상태 %s" % [int(battle.enemy_hp), int(enemy_hp.max_value), int(battle.enemy_block), _status_text(battle.enemy_statuses)]
	intent_label.text = "이벤트 층" if is_event else battle.get_intent_text()
	player_hp.max_value = battle.max_player_hp
	player_hp.value = battle.player_hp
	player_info.text = "HP %d/%d · 방어도 %d · 상태 %s" % [int(battle.player_hp), int(battle.max_player_hp), int(battle.player_block), _status_text(battle.player_statuses)]
	energy_label.text = "⚡ %d / %d" % [battle.energy, battle.max_energy]
	pile_label.text = "뽑기 %d · 버림 %d · 소멸 %d" % [battle.draw_pile.size(), battle.discard_pile.size(), battle.exhaust_pile.size()]
	for child in hand_box.get_children(): child.queue_free()
	for index in range(battle.hand.size()):
		var card := CardDatabase.get_card(battle.hand[index])
		var is_combo := battle.has_combo_for_card(index)
		var combo_mark := "\n🔗 연계 가능" if is_combo else ""
		var button := UiStyle.make_button("[%s]\n%s\n⚡%d%s\n\n%s" % [card.grade, card.name, card.cost, combo_mark, card.desc], Vector2(210, 220), index == selected_hand_index or is_combo)
		button.disabled = not battle.can_play_card(index).is_empty()
		button.tooltip_text = "%s\n태그: %s" % [card.desc, ", ".join(PackedStringArray(card.tags))]
		button.pressed.connect(_select_card.bind(index))
		hand_box.add_child(button)
	target_button.disabled = selected_hand_index < 0 or not battle.can_play_card(selected_hand_index).is_empty()
	end_turn_button.disabled = battle.waiting_for_reward or battle.run_finished

func _status_text(statuses: Dictionary) -> String:
	if statuses.is_empty(): return "없음"
	var parts: Array[String] = []
	for id in statuses: parts.append("%s %d" % [id, int(statuses[id].get("stacks", 0))])
	return ", ".join(PackedStringArray(parts))

func _select_card(index: int):
	if selected_hand_index == index:
		_cancel_card_selection()
		return
	selected_hand_index = index
	var card := CardDatabase.get_card(battle.hand[index])
	var preview := battle.get_card_preview(index)
	feedback_label.text = "%s 선택 · 예상 피해 %d · 방어 %d · 상태 %s · 사용 후 ⚡%d%s" % [
		card.name, int(preview.get("damage", 0)), int(preview.get("block", 0)), str(preview.get("status", "없음")),
		int(preview.get("energy_after", 0)), (" · 🔗 " + str(preview.combo)) if not str(preview.get("combo", "")).is_empty() else ""]
	_refresh()

func _use_selected_card():
	if battle.play_card(selected_hand_index): selected_hand_index = -1

func _cancel_card_selection():
	selected_hand_index = -1
	feedback_label.text = "카드 선택을 취소했습니다."
	_refresh()

func _end_turn():
	if battle.has_playable_card() and battle.energy > 0:
		UiFeedback.confirm("턴 종료", "아직 사용할 수 있는 카드와 에너지가 남아 있습니다. 그래도 턴을 종료할까요?", _confirm_end_turn)
		return
	_confirm_end_turn()

func _confirm_end_turn():
	selected_hand_index = -1
	battle.end_player_turn()

func _show_message(text: String): feedback_label.text = text

func _show_reward(reward: Dictionary):
	pending_reward = reward
	overlay.visible = true
	overlay_title.text = "3층 보상 이벤트" if bool(reward.get("event", false)) else "%d층 클리어" % battle.floor
	var card := CardDatabase.get_card(str(reward.get("card", "")))
	overlay_text.text = "%s\n\n골드 +%d · 성장 재화 +%d · 카드 [%s] 획득" % [str(reward.get("message", "보상을 선택했습니다.")), int(reward.get("gold", 0)), int(reward.get("growth", 0)), str(card.get("name", "없음"))]
	overlay_button.text = "보상 받고 계속"

func _show_finish(victory: bool, summary: Dictionary):
	pending_reward.clear()
	overlay.visible = true
	overlay_title.text = "던전 정복!" if victory else "던전 패배"
	overlay_text.text = "도달 층: %d · 최고 기록: %d층\n영구 보상은 캐릭터 저장 데이터에 반영되었습니다." % [int(summary.get("floor", 1)), int(summary.get("best_floor", 0))]
	overlay_button.text = "마을로 복귀"

func _overlay_action():
	if not pending_reward.is_empty():
		var reward := pending_reward.duplicate(true)
		pending_reward.clear()
		overlay.visible = false
		battle.claim_floor_reward(reward)
	elif battle != null and battle.run_finished:
		GameManager.go_to_lobby()
	else:
		GameManager.go_to_deck_builder()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") and not overlay.visible:
		feedback_label.text = "던전 포기 버튼으로 마을에 돌아갈 수 있습니다."
