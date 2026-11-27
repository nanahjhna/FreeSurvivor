extends CanvasLayer

signal closed()

var _list: GridContainer
var _scroll: ScrollContainer
var _panel: PanelContainer
var _tab_char: Button
var _tab_monster: Button
var _current_tab: String = "character"

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	visible = false
	_build_ui()
	GameData.data_updated.connect(_refresh)

func _build_ui():
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = UiStyle.SCRIM
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_panel = UiStyle.make_panel()
	center.add_child(_panel)

	var margin := UiStyle.make_margin(_panel, 24)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := UiStyle.make_title("📖 도감", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiStyle.make_button("← 닫기 [ESC]", Vector2(150, 42))
	close.pressed.connect(close_screen)
	header.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	vbox.add_child(tabs)
	_tab_char = UiStyle.make_button("👥 캐릭터 도감", Vector2(180, 42))
	_tab_char.toggle_mode = true
	_tab_char.pressed.connect(func(): _set_tab("character"))
	tabs.add_child(_tab_char)
	_tab_monster = UiStyle.make_button("👹 몬스터 도감", Vector2(180, 42))
	_tab_monster.toggle_mode = true
	_tab_monster.pressed.connect(func(): _set_tab("monster"))
	tabs.add_child(_tab_monster)
	vbox.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = GridContainer.new()
	_list.columns = 3
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 12)
	_list.add_theme_constant_override("v_separation", 12)
	_scroll.add_child(_list)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()

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
	_tab_char.button_pressed = tab == "character"
	_tab_monster.button_pressed = tab == "monster"
	_refresh()

func _refresh():
	if not visible:
		return
	for child in _list.get_children():
		child.queue_free()
	if _current_tab == "character":
		_render_characters()
	else:
		_render_monsters()
	_fit_layout.call_deferred()

func _fit_layout() -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(_list):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UiStyle.safe_insets(get_viewport())
	var width := maxf(260.0, viewport_size.x - safe.x - safe.z - 24.0)
	var height := maxf(360.0, viewport_size.y - safe.y - safe.w - 24.0)
	_panel.custom_minimum_size = Vector2(minf(980.0, width), minf(700.0, height))
	var compact := viewport_size.y >= viewport_size.x and viewport_size.x < 600.0
	_list.columns = 1 if compact else (2 if width < 900.0 else 3)
	var gaps := float(maxi(0, _list.columns - 1) * 12)
	var card_width := maxf(1.0, (width - 28.0 - gaps) / float(_list.columns))
	for card in _list.get_children():
		var panel := card as Control
		if panel == null:
			continue
		panel.custom_minimum_size = Vector2(card_width, 154.0 if compact else 180.0)

func _render_characters():
	for cid in GameData.characters:
		var c: Dictionary = GameData.characters[cid]
		var attributes: Dictionary = c.get("attributes", StatManager.get_default_stats(str(cid), c))
		var card := _make_card(
			str(c.get("icon", "⚔️")),
			"%s [%s]" % [c.get("name", ""), c.get("grade", "")],
			"%s · 영구 능력치" % c.get("role", ""),
			"STR %d  AGI %d  VIT %d\nINT %d  DEX %d  LUK %d\n%s" % [
				int(attributes.get("STR", 0)), int(attributes.get("AGI", 0)), int(attributes.get("VIT", 0)),
				int(attributes.get("INT", 0)), int(attributes.get("DEX", 0)), int(attributes.get("LUK", 0)),
				str(c.get("desc", ""))
			],
			Color(1.0, 0.9, 0.5)
		)
		_list.add_child(card)

func _render_monsters():
	for mid in GameData.MONSTER_BESTIARY:
		var info: Dictionary = GameData.MONSTER_BESTIARY[mid]
		var unlocked := GameData.is_bestiary_unlocked(mid)
		var kills := int(GameData.monster_kill_counts.get(mid, 0))
		if unlocked:
			_list.add_child(_make_card(
				str(info.get("icon", "👹")),
				"%s [%s]" % [info.get("name", ""), info.get("grade", "")],
				"처치 기록: %d회" % kills,
				str(info.get("desc", "")),
				Color(0.95, 0.55, 0.45)
			))
		else:
			_list.add_child(_make_card(
				"❓",
				"미확인 몬스터",
				"아직 마주치지 않았습니다",
				"전투에서 이 몬스터를 처치하면 도감이 해금됩니다.",
				Color(0.55, 0.58, 0.65)
			))

func _make_card(icon: String, title: String, subtitle: String, body: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 180)
	panel.add_theme_stylebox_override("panel", UiStyle.sub_panel_style())

	var margin := UiStyle.make_margin(panel, 14)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vbox.add_child(top)

	var icon_label := UiStyle.make_label(icon, 34, accent)
	icon_label.custom_minimum_size = Vector2(48, 0)
	top.add_child(icon_label)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	titles.add_child(UiStyle.make_label(title, 17, accent))
	var subtitle_label := UiStyle.make_label(subtitle, 12, Color(0.7, 0.8, 0.92))
	subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(subtitle_label)

	var body_label := UiStyle.make_label(body, 12, Color(0.86, 0.9, 0.98))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_label)
	return panel
