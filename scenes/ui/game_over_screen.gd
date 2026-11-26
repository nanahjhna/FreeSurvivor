extends CanvasLayer

const ITEM_DETAIL := preload("res://scenes/ui/item_detail.gd")
const RESULT_CREST := preload("res://scenes/ui/result_crest.gd")

var body: VBoxContainer
var detail: ITEM_DETAIL


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	var layout := UiStyle.dialog_layout(self, "", 660)
	var panel := layout.get_parent().get_parent() as PanelContainer
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	body = UiStyle.scroll_column(layout)
	UiStyle.divider(layout)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)
	var lobby := UiStyle.make_button("마을 복귀", Vector2(0, 64))
	lobby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby.pressed.connect(GameManager.go_to_lobby)
	actions.add_child(lobby)
	var retry := UiStyle.make_button("다시 도전", Vector2(0, 64), true)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(GameManager.restart)
	actions.add_child(retry)
	for button in [lobby, retry]:
		button.add_theme_font_size_override("font_size", 22)
	UiStyle.skin_button(lobby, Color("#344674"), Color("#a5bbff"))
	UiStyle.skin_button(retry, Color("#e7a73a"), Color("#ffe6a7"), UiStyle.PAPER_INK)
	detail = ITEM_DETAIL.new()
	add_child(detail)
	GameManager.state_changed.connect(_on_state_changed)


func _result_state() -> int:
	return GameManager.GameState.GAME_OVER


func _on_state_changed(state: int) -> void:
	detail.hide()
	visible = state == _result_state()
	if visible:
		_render_result(GameData.last_battle_result)


func _render_result(result: Dictionary) -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var won := bool(result.get("won", false))
	var heading := "생존 실패"
	if won:
		heading = "생존 귀환" if result.get("returned", false) else "생존 성공"
	var crest := RESULT_CREST.new()
	crest.successful = won
	crest.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y * 0.22, 190.0, 300.0)
	body.add_child(crest)
	var hero := VBoxContainer.new()
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 3)
	var crest_inset := UiStyle.make_margin(crest, 36)
	crest_inset.add_child(hero)
	var title := UiStyle.plaque(heading, Color("#234682"), Color("#ffda8b"), Color("#fff4df"), 43)
	title.custom_minimum_size.y = 76
	hero.add_child(title)
	var context := UiStyle.make_label("%s  ·  %s" % [result.get("stage_name", ""), result.get("difficulty", "")], 20)
	context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(context)
	var time := UiStyle.make_label(UiStyle.format_time(float(result.get("time", 0))), 76, Color.WHITE)
	UiStyle.ink_outline(time, 11, Color("#1a2c59"))
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(time)
	var time_title := UiStyle.make_label("생존 시간", 21, Color("#bcdcff"))
	time_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(time_title)
	if result.get("new_stage_record", false) or result.get("new_best_time", false) or result.get("new_best_level", false):
		var record := UiStyle.make_label("✦  신규 기록", 19, UiStyle.GOLD_BRIGHT)
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero.add_child(record)

	UiStyle.divider(body)
	var damage: Dictionary = result.get("damage_by_source", {})
	var total := 0.0
	for amount in damage.values():
		total += float(amount)
	_stat_row(body, "처치 수", str(result.get("kills", 0)))
	_stat_row(body, "도달 레벨", "Lv.%d" % int(result.get("survival_level", 1)))
	_stat_row(body, "총 피해량", "%.0f" % total)
	UiStyle.divider(body)
	body.add_child(UiStyle.plaque("획득 보상", Color("#283a67"), Color("#cfb679"), Color("#fff2cc"), 28))
	var growth := int(result.get("growth_currency_earned", 0))
	if growth > 0:
		_stat_row(body, "경험치", "+%d" % growth)
	_add_reward_items(result)
	if not damage.is_empty():
		var breakdown := VBoxContainer.new()
		breakdown.add_theme_constant_override("separation", 8)
		var toggle := UiStyle.make_button("상세 전투 기록  ▾", Vector2(0, 52))
		UiStyle.skin_button(toggle, Color("#30477b"), Color("#839dd9"))
		toggle.pressed.connect(func():
			breakdown.visible = not breakdown.visible
			toggle.text = "상세 전투 기록  ▴" if breakdown.visible else "상세 전투 기록  ▾"
		)
		body.add_child(toggle)
		body.add_child(breakdown)
		var sources := damage.keys()
		sources.sort_custom(func(a: String, b: String): return float(damage[a]) > float(damage[b]))
		for source in sources:
			var amount := float(damage[source])
			var name := str(GameData.skill_meta.get(source, {}).get("name", source))
			var captions := {"basic": "기본 공격", "card_effect": "카드 효과", "item": "전투 아이템", "other": "기타"}
			_stat_row(breakdown, str(captions.get(source, name)), "%.0f  ·  %.1f%%" % [amount, 100.0 * amount / maxf(total, 0.001)])
		breakdown.hide()


func _stat_row(parent: Control, caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 34
	parent.add_child(row)
	var label := UiStyle.make_label(caption, 20, UiStyle.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(UiStyle.make_label(value, 22))


func _add_reward_items(result: Dictionary) -> void:
	var rewards: Array[Dictionary] = [{
		"name": "골드", "type": "material", "icon": "🟡", "count": int(result.get("gold_earned", 0))
	}]
	for reward in result.get("items_earned", []):
		var text := str(reward)
		var separator := text.rfind(" x")
		var name := text if separator < 0 else text.substr(0, separator)
		var count := 1 if separator < 0 else maxi(1, int(text.substr(separator + 2)))
		var item := {"name": name, "icon": "◆", "count": count}
		for stored in GameData.inventory:
			if stored.get("name") == name:
				item = stored.duplicate()
				item["count"] = count
				break
		rewards.append(item)
	for reward in result.get("cards_earned", []):
		rewards.append({"name": str(reward), "type": "card", "icon": "▤", "count": 1})
	if rewards.is_empty():
		return
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for item in rewards:
		var button := UiStyle.make_button("%s\n×%d" % [item.get("icon", "◆"), item.get("count", 1)], Vector2(0, 96))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = str(item.name)
		button.add_theme_font_size_override("font_size", 24)
		var trim := UiStyle.AMBER if item.name == "골드" else UiStyle.grade_color(str(item.get("grade", "")))
		UiStyle.skin_button(button, Color("#465b92"), trim)
		button.pressed.connect(func(): detail.show_item(item))
		grid.add_child(button)
