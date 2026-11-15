extends CanvasLayer

signal closed()

var _list: GridContainer
var _gold_label: Label
var _tab_gear: Button
var _tab_consumable: Button
var _current_tab: String = "gear"

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	visible = false
	_build_ui()
	GameData.data_updated.connect(_refresh)
	GameData.currency_changed.connect(func(_g, _c): _refresh())

func _build_ui():
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.72)
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(980, 700)
	center.add_child(panel)

	var margin := UiStyle.make_margin(panel, 24)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := UiStyle.make_title("🪙 상점", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = UiStyle.make_label("", 17, Color(1.0, 0.87, 0.42))
	header.add_child(_gold_label)
	var close := UiStyle.make_button("← 닫기 [ESC]", Vector2(150, 42))
	close.pressed.connect(close_screen)
	header.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	vbox.add_child(tabs)
	_tab_gear = UiStyle.make_button("⚔️ 장비 상점", Vector2(180, 42))
	_tab_gear.toggle_mode = true
	_tab_gear.pressed.connect(func(): _set_tab("gear"))
	tabs.add_child(_tab_gear)
	_tab_consumable = UiStyle.make_button("🧪 소모품 상점", Vector2(180, 42))
	_tab_consumable.toggle_mode = true
	_tab_consumable.pressed.connect(func(): _set_tab("consumable"))
	tabs.add_child(_tab_consumable)
	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = GridContainer.new()
	_list.columns = 3
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 12)
	_list.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_list)

func open():
	visible = true
	_set_tab(_current_tab)

func close_screen():
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

func _set_tab(tab: String):
	_current_tab = tab
	_tab_gear.button_pressed = tab == "gear"
	_tab_consumable.button_pressed = tab == "consumable"
	_refresh()

func _refresh():
	if not visible:
		return
	_gold_label.text = "💰 %d 골드" % GameData.player_gold
	for child in _list.get_children():
		child.queue_free()
	if _current_tab == "gear":
		_render_gear()
	else:
		_render_consumables()

func _render_gear():
	for id in GameData.SHOP_CATALOG:
		var item: Dictionary = GameData.SHOP_CATALOG[id]
		var owned := _owns_gear(id)
		var price := int(item.get("price", 0))
		var reason := ""
		if owned:
			reason = "이미 보유 중인 장비입니다."
		elif GameData.player_gold < price:
			reason = "골드 부족 (필요 %d / 보유 %d)" % [price, GameData.player_gold]
		_list.add_child(_make_item_card(
			str(item.get("icon", "⚔️")),
			str(item.get("name", "장비")),
			"[%s] %s" % [item.get("grade", "N"), item.get("type", "")],
			_gear_stats(item),
			price,
			"보유 중" if owned else "구매",
			reason,
			func(): _request_buy(id, str(item.get("name", "장비")), price),
			owned
		))

func _render_consumables():
	for entry in GameData.SHOP_CONSUMABLES:
		var slot := int(entry.get("slot", 1))
		var price := int(entry.get("price", 0))
		var count := int(GameData.item_counts.get(slot, 0))
		var reason := ""
		if GameData.player_gold < price:
			reason = "골드 부족 (필요 %d / 보유 %d)" % [price, GameData.player_gold]
		_list.add_child(_make_item_card(
			str(entry.get("icon", "🧪")),
			str(entry.get("name", "소모품")),
			"보유 수량: %d개" % count,
			str(entry.get("desc", "")),
			price,
			"구매",
			reason,
			func(): _request_buy("consumable:%d" % slot, str(entry.get("name", "소모품")), price),
			false
		))

func _gear_stats(item: Dictionary) -> String:
	var parts: Array[String] = []
	if int(item.get("atk", 0)) > 0: parts.append("ATK +%d" % int(item.atk))
	if int(item.get("def", 0)) > 0: parts.append("DEF +%d" % int(item.def))
	if int(item.get("hp", 0)) > 0: parts.append("HP +%d" % int(item.hp))
	return "  ".join(parts) + "\n" + str(item.get("desc", ""))

func _owns_gear(id: String) -> bool:
	for item in GameData.inventory:
		if str(item.get("id", "")) == id:
			return true
	return false

func _make_item_card(
	icon: String, title: String, subtitle: String, body: String,
	price: int, button_text: String, reason: String, on_buy: Callable, owned: bool
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 230)
	panel.add_theme_stylebox_override("panel", UiStyle.sub_panel_style())

	var margin := UiStyle.make_margin(panel, 14)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vbox.add_child(top)
	var icon_label := UiStyle.make_label(icon, 34, Color(1.0, 0.85, 0.45))
	icon_label.custom_minimum_size = Vector2(48, 0)
	top.add_child(icon_label)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	titles.add_child(UiStyle.make_label(title, 17, Color(1.0, 0.9, 0.55)))
	titles.add_child(UiStyle.make_label(subtitle, 12, Color(0.7, 0.8, 0.92)))

	var body_label := UiStyle.make_label(body, 12, Color(0.86, 0.9, 0.98))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_label)

	var price_label := UiStyle.make_label("💰 %d 골드" % price, 14, Color(1.0, 0.85, 0.4))
	vbox.add_child(price_label)

	if reason != "":
		var reason_label := UiStyle.make_label("⛔ " + reason, 12, Color(1.0, 0.55, 0.5))
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(reason_label)

	var buy := UiStyle.make_button(button_text, Vector2(0, 40), true)
	buy.disabled = owned or reason != ""
	buy.pressed.connect(on_buy)
	vbox.add_child(buy)
	return panel

func _request_buy(key: String, item_name: String, price: int):
	UiFeedback.confirm(
		"구매 확인",
		"%s을(를) %d 골드에 구매하시겠습니까?\n보유 골드: %d" % [item_name, price, GameData.player_gold],
		func(): _do_buy(key)
	)

func _do_buy(key: String):
	var result := GameData.buy_shop_item(key)
	if bool(result.get("ok", false)):
		var rewards: Array = result.get("reward", [])
		UiFeedback.show_reward(str(result.get("message", "구매 완료")), rewards)
		_refresh()
	else:
		UiFeedback.show_error(str(result.get("message", "구매할 수 없습니다.")))
