extends CanvasLayer

@onready var kill_stat: Label = $CenterContainer/VBoxContainer/Stats/KillStat
@onready var time_stat: Label = $CenterContainer/VBoxContainer/Stats/TimeStat
@onready var level_stat: Label = $CenterContainer/VBoxContainer/Stats/LevelStat
@onready var gold_stat: Label = $CenterContainer/VBoxContainer/Stats/GoldStat
@onready var xp_stat: Label = $CenterContainer/VBoxContainer/Stats/XPStat
@onready var cards_stat: Label = $CenterContainer/VBoxContainer/Stats/CardsStat
@onready var items_stat: Label = $CenterContainer/VBoxContainer/Stats/ItemsStat
@onready var record_stat: Label = $CenterContainer/VBoxContainer/Stats/RecordStat
@onready var subtitle: Label = $CenterContainer/VBoxContainer/Sub

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_apply_result_skin()
	GameManager.state_changed.connect(_on_state_changed)

func _apply_result_skin():
	$ColorRect.color = Color(0.035, 0.012, 0.012, 0.82)
	var center := $CenterContainer as CenterContainer
	var content := $CenterContainer/VBoxContainer as VBoxContainer
	var panel := UiStyle.make_panel(Color(0.035, 0.025, 0.024, 0.96))
	panel.custom_minimum_size = Vector2(minf(get_viewport().get_visible_rect().size.x - 32.0, 660.0), 0)
	var margin := UiStyle.make_margin(panel, 22)
	center.remove_child(content)
	center.add_child(panel)
	margin.add_child(content)
	var title := content.get_node("Title") as Label
	title.text = "전투 결과"
	title.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	_reflow_result_content(content)
	var restart := content.get_node("ButtonContainer/RestartButton") as Button
	restart.text = "다시 도전"
	UiStyle.apply_button(restart, true)
	var lobby := content.get_node("ButtonContainer/LobbyButton") as Button
	lobby.text = "마을로"
	UiStyle.apply_button(lobby)

func _reflow_result_content(content: VBoxContainer):
	var old_stats := content.get_node("Stats") as VBoxContainer
	var summary := GridContainer.new()
	summary.columns = 2
	summary.add_theme_constant_override("h_separation", 8)
	summary.add_theme_constant_override("v_separation", 8)
	var rewards := HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 8)
	var labels_by_name: Dictionary = {}
	for child in old_stats.get_children():
		if child is Label:
			labels_by_name[child.name] = child
		old_stats.remove_child(child)
	content.remove_child(old_stats)
	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 8)
	var time_card := UiStyle.make_panel(Color(0.16, 0.035, 0.025, 0.98))
	time_card.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.16, 0.035, 0.025, 0.98), UiStyle.GOLD, 1))
	time_card.custom_minimum_size.y = 94
	var time_margin := UiStyle.make_margin(time_card, 12)
	var time_label := labels_by_name["TimeStat"] as Label
	time_label.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	time_label.add_theme_font_size_override("font_size", 27)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_margin.add_child(time_label)
	sections.add_child(time_card)
	sections.add_child(UiStyle.make_label("전투 기록", 15, UiStyle.GOLD_BRIGHT))
	for stat_name in ["KillStat", "LevelStat", "GoldStat", "XPStat"]:
		_add_result_card(summary, labels_by_name[stat_name] as Label, 68)
	sections.add_child(summary)
	sections.add_child(UiStyle.make_label("획득 보상", 15, UiStyle.GOLD_BRIGHT))
	for reward_name in ["CardsStat", "ItemsStat"]:
		_add_result_card(rewards, labels_by_name[reward_name] as Label, 82)
	sections.add_child(rewards)
	var record_panel := UiStyle.make_panel(Color(0.18, 0.035, 0.024, 0.98))
	record_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.18, 0.035, 0.024, 0.98), UiStyle.GOLD, 1))
	var record_margin := UiStyle.make_margin(record_panel, 10)
	var record := labels_by_name["RecordStat"] as Label
	record.add_theme_color_override("font_color", Color(1.0, 0.72, 0.36))
	record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_margin.add_child(record)
	sections.add_child(record_panel)
	content.add_child(sections)
	content.move_child(sections, 2)
	old_stats.queue_free()

func _add_result_card(parent: Control, label: Label, height: float):
	var card := UiStyle.make_panel(UiStyle.INK_SOFT)
	card.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.INK_SOFT, Color(0.48, 0.32, 0.18, 0.72), 1))
	card.custom_minimum_size.y = height
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := UiStyle.make_margin(card, 10)
	label.add_theme_color_override("font_color", UiStyle.IVORY)
	label.add_theme_font_size_override("font_size", 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)
	parent.add_child(card)

func _on_state_changed(new_state):
	if new_state == GameManager.GameState.VICTORY:
		_refresh_result()
		visible = true
	else:
		visible = false

func _refresh_result():
	var result = GameData.last_battle_result
	var mins := int(float(result.get("time", 0.0)) / 60.0)
	var secs = int(result.get("time", 0.0)) % 60
	subtitle.text = str(result.get("stage_name", "전투 지역")) + " 전투를 완료했습니다!"
	kill_stat.text = "처치한 몬스터: " + str(result.get("kills", 0))
	time_stat.text = "전투 시간: %02d:%02d" % [mins, secs]
	level_stat.text = "도달 서바이벌 레벨: Lv.%d" % int(result.get("survival_level", 1))
	gold_stat.text = "획득 골드: +%d" % int(result.get("gold_earned", 0))
	xp_stat.text = "획득 성장 재화: +%d" % int(result.get("growth_currency_earned", 0))
	var earned_cards: Array = result.get("cards_earned", [])
	cards_stat.text = "획득 카드: " + (", ".join(PackedStringArray(earned_cards)) if not earned_cards.is_empty() else "없음")
	var earned_items: Array = result.get("items_earned", [])
	var items_text = ", ".join(PackedStringArray(earned_items)) if not earned_items.is_empty() else "없음"
	items_stat.text = "획득 아이템: " + items_text
	var new_records: Array[String] = []
	if bool(result.get("new_best_time", false)): new_records.append("최고 생존 시간")
	if bool(result.get("new_best_level", false)): new_records.append("최고 서바이벌 레벨")
	record_stat.text = "🏆 최고 기록 갱신: " + (", ".join(PackedStringArray(new_records)) if not new_records.is_empty() else "없음")

func _on_restart_pressed():
	GameManager.restart()

func _on_lobby_pressed():
	GameManager.go_to_lobby()
