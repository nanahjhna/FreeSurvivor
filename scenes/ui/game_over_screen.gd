extends CanvasLayer

const ITEM_DETAIL := preload("res://scenes/ui/item_detail.gd")
const RESULT_CREST := preload("res://scenes/ui/result_crest.gd")
const REFERENCE_SCREEN := preload("res://scripts/reference_screen.gd")

var body: VBoxContainer
var detail: ITEM_DETAIL
var approved: REFERENCE_SCREEN
var legacy_layout: Control
var details_return: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	$ColorRect.color = UiStyle.SCRIM
	var layout := UiStyle.dialog_layout(self, "", 660)
	legacy_layout = layout.get_parent().get_parent().get_parent() as Control
	var header := UiStyle.notice_board()
	header.add_child(UiStyle.make_title("전투 결과", 30))
	layout.add_child(header)
	body = UiStyle.scroll_column(layout)
	UiStyle.divider(layout)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)
	var lobby := UiStyle.make_button("마을 복귀", Vector2(0, 64))
	lobby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.button_icon(lobby, "home", 25)
	lobby.pressed.connect(GameManager.go_to_lobby)
	actions.add_child(lobby)
	var retry := UiStyle.make_button("다시 도전", Vector2(0, 64), true)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.button_icon(retry, "restart", 25)
	retry.pressed.connect(GameManager.restart)
	actions.add_child(retry)
	for button in [lobby, retry]:
		button.add_theme_font_size_override("font_size", 22)
	details_return = UiStyle.make_button("결과 요약", Vector2(0, 45))
	details_return.pressed.connect(_show_approved_summary)
	layout.add_child(details_return)
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
	crest.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y * 0.25, 185.0, 320.0)
	body.add_child(crest)
	var hero := VBoxContainer.new()
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 3)
	var crest_inset := UiStyle.make_margin(crest, 24)
	crest_inset.add_child(hero)
	hero.add_child(UiStyle.icon_view("shield", 43, UiStyle.GOLD_BRIGHT if won else UiStyle.DANGER_EDGE))
	var title := UiStyle.make_label(heading, 36, UiStyle.GOLD_BRIGHT if won else UiStyle.IVORY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(title)
	var context := UiStyle.make_label("%s  ·  %s" % [result.get("stage_name", ""), result.get("difficulty", "")], 18, UiStyle.MUTED)
	context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(context)
	UiStyle.divider(hero)
	var time_title := UiStyle.make_label("생존 시간", 18, UiStyle.MUTED)
	time_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(time_title)
	var time := UiStyle.make_label(UiStyle.format_time(float(result.get("time", 0))), 47)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(time)
	if result.get("new_stage_record", false) or result.get("new_best_time", false) or result.get("new_best_level", false):
		var record := UiStyle.make_label("신규 기록", 19, UiStyle.GOLD_BRIGHT)
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero.add_child(record)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 10)
	hero.add_child(metrics)

	UiStyle.divider(body)
	var damage: Dictionary = result.get("damage_by_source", {})
	var total := 0.0
	for amount in damage.values():
		total += float(amount)
	UiStyle.metric(metrics, "처치 수", str(result.get("kills", 0)))
	UiStyle.metric(metrics, "도달 레벨", "Lv.%d" % int(result.get("survival_level", 1)))
	UiStyle.metric(metrics, "총 피해량", "%.0f" % total)
	UiStyle.divider(body)
	var rewards_header := UiStyle.notice_board()
	rewards_header.add_child(UiStyle.make_title("획득 보상", 26))
	body.add_child(rewards_header)
	var growth := int(result.get("growth_currency_earned", 0))
	if growth > 0:
		_stat_row(body, "경험치", "+%d" % growth)
	_add_reward_items(result)
	if not damage.is_empty():
		var breakdown := VBoxContainer.new()
		breakdown.add_theme_constant_override("separation", 8)
		var toggle := UiStyle.make_button("상세 전투 기록  ▾", Vector2(0, 52))
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
	_build_approved_result(result, heading)


func _build_approved_result(result: Dictionary, heading: String) -> void:
	if approved:
		remove_child(approved)
		approved.queue_free()
	approved = REFERENCE_SCREEN.new()
	var screen := approved
	screen.build(self, "result")
	if not bool(result.get("won", false)):
		screen.solid(Rect2(0, 83, 552, 270), Color("#241c19"))
		var crest := RESULT_CREST.new()
		crest.successful = false
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.page.add_child(crest)
		screen.place(crest, Rect2(83, 106, 386, 214))
		screen.text(Rect2(79, 183, 394, 78), heading, 45, HORIZONTAL_ALIGNMENT_CENTER)
	elif bool(result.get("returned", false)):
		screen.mask(Rect2(122, 238, 313, 62), Rect2(350, 241, 78, 56))
		screen.text(Rect2(105, 237, 342, 64), heading, 47, HORIZONTAL_ALIGNMENT_CENTER)
	screen.field(Rect2(370, 370, 141, 48), func(): return UiStyle.format_time(float(result.get("time", 0))), 35, HORIZONTAL_ALIGNMENT_RIGHT)
	screen.field(Rect2(372, 431, 141, 50), func(): return str(result.get("kills", 0)), 35, HORIZONTAL_ALIGNMENT_RIGHT)
	screen.field(Rect2(87, 684, 169, 51), func(): return "%d G" % int(result.get("gold_earned", 0)), 31, HORIZONTAL_ALIGNMENT_CENTER)
	var extra := PackedStringArray()
	for item in result.get("items_earned", []):
		extra.append(str(item))
	for card in result.get("cards_earned", []):
		extra.append(str(card))
	screen.solid(Rect2(301, 590, 171, 141), Color("#2a231e"))
	screen.text(Rect2(303, 600, 169, 75), "◆" if not extra.is_empty() else "—", 53, HORIZONTAL_ALIGNMENT_CENTER, REFERENCE_SCREEN.AMBER)
	var reward_title := "추가 보상 없음"
	if extra.size() == 1:
		reward_title = extra[0]
	elif extra.size() > 1:
		reward_title = "추가 보상 %d종" % extra.size()
	screen.text(Rect2(295, 683, 188, 56), reward_title, 23, HORIZONTAL_ALIGNMENT_CENTER)
	screen.hit(Rect2(69, 576, 423, 173), "획득 보상 상세", _show_result_details)
	screen.styled_button(Rect2(167, 751, 218, 42), "상세 전투 기록", _show_result_details).add_theme_font_size_override("font_size", 19)
	screen.hit(Rect2(19, 797, 236, 102), "마을 복귀", GameManager.go_to_lobby)
	screen.hit(Rect2(269, 797, 264, 102), "다시 도전", GameManager.restart)
	_show_approved_summary()


func _show_approved_summary() -> void:
	detail.hide()
	legacy_layout.hide()
	approved.show()


func _show_result_details() -> void:
	approved.hide()
	legacy_layout.show()


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
		UiStyle.skin_button(button, UiStyle.INK_SOFT, trim, UiStyle.IVORY)
		button.pressed.connect(func(): detail.show_item(item))
		grid.add_child(button)
