extends CanvasLayer

const REFERENCE_SCREEN := preload("res://scripts/reference_screen.gd")

signal closed()

const CHARACTER_PORTRAIT := preload("res://scenes/ui/character_portrait.gd")
const AUGMENT_PREVIEW := preload("res://scripts/augment_preview.gd")
const EQUIPMENT_TYPES := ["weapon", "armor", "accessory", "boots"]
const SLOT_TITLES := {"weapon": "무기", "armor": "방어구", "accessory": "장신구", "boots": "신발"}
const SLOT_ICONS := {"weapon": "sword", "armor": "armor", "accessory": "ring", "boots": "boots"}

var heading: Label
var count_label: Label
var card_header: HBoxContainer
var grid: GridContainer
var card_list: VBoxContainer
var card_detail: VBoxContainer
var card_detail_text: Label
var card_detail_title: Label
var card_detail_meta: Label
var card_detail_preview: Label
var list_scroll: ScrollContainer
var card_scroll_position := 0
var equipment: VBoxContainer
var auto_equip: Button
var item_action: Button
var gear_comparison: PanelContainer
var comparison_title: Label
var comparison_values: VBoxContainer
var tray: PanelContainer
var gear_buttons: Dictionary = {}
var selected_item: Dictionary = {}
var current_mode := "equipment"
var equipment_mode := false
var forge_mode := false
var equipment_identity: Label
var portrait_holder: CenterContainer
var portrait: CHARACTER_PORTRAIT
var equipment_slots: HBoxContainer
var mode_buttons: Dictionary = {}
var slot_buttons: Dictionary = {}
var _approved_catalog: REFERENCE_SCREEN
var _approved_card: REFERENCE_SCREEN
var _approved_forge: REFERENCE_SCREEN
var _approved_forge_heading: Button
var _approved_forge_cards_tab: Button
var _approved_card_icon := ""
var _approved_card_category := ""
var _approved_damage_changes: Array[Dictionary] = []
var _legacy_layout: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	$Backdrop.color = UiStyle.SCRIM
	var layout := UiStyle.dialog_layout(self, "")
	_legacy_layout = layout.get_parent().get_parent().get_parent() as Control
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	layout.add_child(modes)
	for entry in [["equipment", "장비 관리"], ["cards", "증강 카드"]]:
		var button := _tab(modes, entry[1])
		button.pressed.connect(_show_mode.bind(entry[0]))
		mode_buttons[entry[0]] = button
	heading = UiStyle.make_title("대장간", 27)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(heading)
	count_label = UiStyle.make_label("", 19, UiStyle.MUTED)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var close_button := UiStyle.make_button("×", Vector2(56, 52))
	close_button.tooltip_text = "닫기"
	close_button.add_theme_font_size_override("font_size", 27)
	close_button.pressed.connect(close)
	modes.add_child(close_button)

	equipment = VBoxContainer.new()
	equipment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment.add_theme_constant_override("separation", 10)
	layout.add_child(equipment)
	equipment_identity = UiStyle.make_label("", 29)
	equipment_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_identity.custom_minimum_size.y = 52
	equipment_identity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment.add_child(equipment_identity)
	var platform := PanelContainer.new()
	platform.size_flags_vertical = Control.SIZE_EXPAND_FILL
	platform.add_theme_stylebox_override("panel", UiStyle.art_panel())
	equipment.add_child(platform)
	var stage_light := TextureRect.new()
	stage_light.texture = UiStyle.tint_gradient(Color("#544435"), UiStyle.ASPHALT)
	stage_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	platform.add_child(stage_light)
	var slots := HBoxContainer.new()
	equipment_slots = slots
	slots.custom_minimum_size.y = 270
	slots.add_theme_constant_override("separation", 2)
	platform.add_child(slots)
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 15)
	slots.add_child(left)
	portrait_holder = CenterContainer.new()
	portrait_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_child(portrait_holder)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_child(right)
	for type in EQUIPMENT_TYPES:
		var slot := UiStyle.make_button(SLOT_TITLES[type], Vector2(108, 113))
		UiStyle.button_icon(slot, SLOT_ICONS[type], 35, true)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot.pressed.connect(_open_equipped.bind(type))
		(right if type in ["armor", "boots"] else left).add_child(slot)
		slot_buttons[type] = slot
	var owned_header := HBoxContainer.new()
	equipment.add_child(owned_header)
	var owned_title := UiStyle.make_title("보유 장비", 23)
	owned_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_header.add_child(owned_title)
	auto_equip = UiStyle.make_button("추천 장비 장착", Vector2(0, 48))
	auto_equip.add_theme_font_size_override("font_size", 18)
	auto_equip.pressed.connect(_auto_equip_recommended)
	owned_header.add_child(auto_equip)

	card_header = HBoxContainer.new()
	layout.add_child(card_header)
	var card_title := UiStyle.make_title("전투 증강 도감", 22)
	card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_header.add_child(card_title)
	card_header.add_child(count_label)

	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	tray = UiStyle.make_panel(UiStyle.ASPHALT)
	tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tray)
	var body := UiStyle.scroll_column(UiStyle.make_margin(tray, 8))
	list_scroll = body.get_parent() as ScrollContainer
	body.add_child(grid)
	card_list = VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 8)
	body.add_child(card_list)
	_build_card_detail(body)
	_build_gear_comparison(layout)
	get_viewport().size_changed.connect(_layout_grid)
	get_viewport().size_changed.connect(_layout_equipment)
	GameData.data_updated.connect(_refresh)
	_layout_grid()
	_layout_equipment()


func _tab(parent: Control, caption: String) -> Button:
	var button := UiStyle.make_button(caption, Vector2(0, 54))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button


func _layout_grid() -> void:
	var width := get_viewport().get_visible_rect().size.x
	var safe := UiStyle.safe_insets(get_viewport())
	grid.columns = 4 if width - safe.x - safe.z >= 340 else 3


func _layout_equipment() -> void:
	if equipment_slots == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.y >= viewport_size.x and viewport_size.x < 600.0
	var safe := UiStyle.safe_insets(get_viewport())
	var workbench_width := minf(viewport_size.x, 700.0) - safe.x - safe.z - 84.0
	var slot_side := clampf(workbench_width * 0.22, 58.0, 108.0)
	var gap := 4 if compact else 8
	equipment_slots.custom_minimum_size.y = clampf(viewport_size.y * 0.26, 180.0, 370.0)
	equipment_slots.add_theme_constant_override("separation", gap)
	for type in slot_buttons:
		var slot: Button = slot_buttons[type]
		slot.custom_minimum_size = Vector2(slot_side, slot_side * 1.03)
		var font := slot.get_theme_font("font")
		var font_size := 22
		while font_size > 14 and font.get_string_size(SLOT_TITLES[type], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > slot_side - 14.0:
			font_size -= 1
		slot.add_theme_font_size_override("font_size", font_size)
	if portrait != null and is_instance_valid(portrait) and _approved_forge == null:
		var portrait_side := clampf(workbench_width - 2.0 * (slot_side + gap), 0.0, 230.0)
		portrait.custom_minimum_size = Vector2(portrait_side, equipment_slots.custom_minimum_size.y)
		portrait.set_framing(3.2, 1.25, 1.8)


func open(_show_equipment: bool = false, at_forge: bool = false) -> void:
	forge_mode = at_forge
	selected_item = {}
	show()
	_show_mode("equipment")


func close() -> void:
	if portrait:
		portrait.set_portrait_active(false)
	hide()
	closed.emit()


func _show_mode(mode: String) -> void:
	current_mode = mode if mode in ["equipment", "cards"] else "equipment"
	equipment_mode = current_mode == "equipment"
	card_detail.hide()
	list_scroll.set_deferred("scroll_vertical", 0)
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	heading.visible = forge_mode and equipment_mode
	equipment.visible = equipment_mode
	grid.visible = equipment_mode
	card_header.visible = not equipment_mode
	card_list.visible = not equipment_mode and not card_detail.visible
	tray.size_flags_vertical = Control.SIZE_FILL if equipment_mode else Control.SIZE_EXPAND_FILL
	list_scroll.custom_minimum_size.y = 86 if equipment_mode else 0
	var leader: Dictionary = GameData.characters.get(GameData.get_leader_id(), {})
	equipment_identity.text = "%s LV.%d" % [leader.get("name", ""), GameData.get_character_total_level(GameData.get_leader_id())]
	_refresh_gear_comparison()
	for mode in mode_buttons:
		_skin_tab(mode_buttons[mode], mode == current_mode)
		mode_buttons[mode].add_theme_font_size_override("font_size", 19)
	if not equipment_mode:
		if portrait:
			portrait.set_portrait_active(false)
		_ensure_approved_catalog()
		_refresh_cards()
		_sync_approved_screen()
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	gear_buttons.clear()
	_refresh_equipped()
	_refresh_portrait()
	var items := _inventory_items()
	var displayed := 0
	for item in items:
		var is_gear := str(item.get("type", "")) in EQUIPMENT_TYPES
		if not is_gear:
			continue
		var grade := str(item.get("grade", ""))
		var button := UiStyle.make_button("%s\n%s" % [item.get("icon", "◆"), grade], Vector2(48, 78))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = str(item.get("name", ""))
		button.add_theme_font_size_override("font_size", 23)
		var color := UiStyle.grade_color(grade)
		UiStyle.skin_button(button, UiStyle.INK_SOFT, color, UiStyle.IVORY)
		if equipment_mode and is_gear:
			_add_equipment_comparison_marker(button, item)
		button.pressed.connect(_open_item.bind(item))
		grid.add_child(button)
		gear_buttons[str(item.get("id", ""))] = button
		displayed += 1
	if displayed == 0:
		grid.add_child(UiStyle.make_label("보유한 장비가 없습니다.", 18, UiStyle.MUTED))
	_update_gear_selection()
	if _approved_forge == null:
		_build_approved_forge()
	_sync_approved_screen()


func _sync_approved_screen() -> void:
	if _approved_forge:
		_approved_forge.visible = equipment_mode
		_approved_forge_heading.visible = true
		_approved_forge_cards_tab.visible = true
	if _approved_catalog:
		_approved_catalog.visible = not equipment_mode and not card_detail.visible
		_approved_card.visible = not equipment_mode and card_detail.visible
	_legacy_layout.hide()


func _build_approved_forge() -> void:
	_approved_forge = REFERENCE_SCREEN.new()
	var screen := _approved_forge
	screen.build(self, "forge")
	_build_reference_tabs(screen, true)
	screen.smithy(Rect2(0, 70, 552, 371), Rect2(166, 89, 212, 333))
	screen.native(portrait, Rect2(145, 77, 263, 365))
	portrait.set_framing(3.13, 1.29, 1.7)
	portrait.stretch_shrink = 1 if not OS.has_feature("android") else 2
	var rectangles := [Rect2(51, 148, 107, 107), Rect2(413, 148, 107, 107),
		Rect2(51, 272, 107, 105), Rect2(413, 272, 107, 105)]
	for index in range(EQUIPMENT_TYPES.size()):
		var type: String = EQUIPMENT_TYPES[index]
		var rect: Rect2 = rectangles[index]
		screen.image(rect, rect)
		var target := screen.relay(rect, slot_buttons[type])
		var trim := UiStyle.frame(Color.TRANSPARENT, UiStyle.AMBER, 10, 3)
		trim.shadow_size = 0
		var neutral := StyleBoxEmpty.new()
		screen.updates.append(func():
			var selected: bool = selected_item.get("type", "") == type
			var current := target.get_theme_stylebox("normal")
			if selected and current != trim:
				target.add_theme_stylebox_override("normal", trim)
			elif not selected and current == trim:
				target.add_theme_stylebox_override("normal", neutral)
		)
	screen.show_label(equipment_identity, Rect2(176, 419, 200, 28), 19, HORIZONTAL_ALIGNMENT_CENTER, Color("#251c16"))
	screen.mask(Rect2(331, 451, 204, 52), Rect2(152, 451, 173, 50))
	screen.solid(Rect2(22, 512, 510, 127), Color("#211b16"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.page.add_child(scroll)
	screen.place(scroll, Rect2(23, 514, 506, 126))
	grid.reparent(scroll, false)
	grid.columns = 4
	screen.image(Rect2(23, 648, 504, 122), Rect2(23, 648, 504, 122))
	screen.solid(Rect2(35, 655, 480, 107), Color("#28221c"))
	screen.text(Rect2(40, 656, 465, 106), "장비를 누르면 착용 중인 장비와 비교합니다.", 20, HORIZONTAL_ALIGNMENT_CENTER)
	screen.native(gear_comparison, Rect2(24, 649, 502, 122))
	screen.relay(Rect2(20, 797, 512, 88), auto_equip)


func _ensure_approved_catalog() -> void:
	if _approved_catalog:
		return
	_approved_catalog = REFERENCE_SCREEN.new()
	_approved_catalog.build(self, "catalog")
	_approved_card = REFERENCE_SCREEN.new()
	_approved_card.build(self, "card")
	for screen in [_approved_catalog, _approved_card]:
		_build_reference_tabs(screen, false)

	_approved_catalog.solid(Rect2(19, 212, 516, 704), Color("#211d19"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_approved_catalog.page.add_child(scroll)
	_approved_catalog.place(scroll, Rect2(20, 226, 515, 678))
	card_list.reparent(scroll, false)
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_list.add_theme_constant_override("separation", 15)
	list_scroll = scroll
	_approved_catalog.solid(Rect2(19, 112, 516, 91), Color("#211d19"))
	_approved_catalog.live_text(Rect2(31, 123, 490, 70), func():
		return "전투 증강 도감  ·  %s" % count_label.text
	, 27, HORIZONTAL_ALIGNMENT_CENTER)

	var screen := _approved_card
	screen.hit(Rect2(32, 108, 187, 65), "목록으로", _close_card_detail)
	var category_icon := screen.field(Rect2(33, 206, 138, 116), func(): return _approved_card_icon, 65, HORIZONTAL_ALIGNMENT_CENTER, Color("#221d18"))
	screen.updates.append(func(): category_icon.modulate = UiStyle.category_tint(_approved_card_category))
	screen.show_label(card_detail_title, Rect2(199, 203, 326, 71), 40)
	screen.show_label(card_detail_meta, Rect2(199, 276, 322, 44), 25)
	screen.show_label(card_detail_text, Rect2(36, 378, 482, 102), 30, HORIZONTAL_ALIGNMENT_CENTER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var preview := screen.field(Rect2(36, 497, 482, 234), func():
		return card_detail_preview.text if _approved_damage_changes.is_empty() else "예상 스킬 피해"
	, 28, HORIZONTAL_ALIGNMENT_CENTER, Color("#2b241d"), REFERENCE_SCREEN.AMBER)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.updates.append(func(): preview.size.y = 234.0 if _approved_damage_changes.is_empty() else 53.0)
	for index in range(4):
		var position := Vector2(35 + index % 2 * 246, 560 + floori(index / 2.0) * 84)
		var box := screen.image(Rect2(position, Vector2(236, 75)), Rect2(position, Vector2(236, 75)))
		var fill := screen.solid(Rect2(position + Vector2(9, 7), Vector2(218, 61)))
		var skill_name := screen.live_text(Rect2(position + Vector2(7, 5), Vector2(221, 29)),
			func(): return "%s  %s" % [_approved_damage_changes[index].slot, _approved_damage_changes[index].name] if index < _approved_damage_changes.size() else "",
			21, HORIZONTAL_ALIGNMENT_CENTER)
		var difference := screen.live_text(Rect2(position + Vector2(9, 34), Vector2(218, 36)),
			func(): return "%d → %d" % [_approved_damage_changes[index].before, _approved_damage_changes[index].after] if index < _approved_damage_changes.size() else "",
			25, HORIZONTAL_ALIGNMENT_CENTER, REFERENCE_SCREEN.AMBER)
		screen.updates.append(func():
			var shown := index < _approved_damage_changes.size()
			for part in [box, fill, skill_name, difference]:
				part.visible = shown
		)
	screen.solid(Rect2(28, 744, 496, 132), Color("#241d18f5"))
	var scope_panel := PanelContainer.new()
	scope_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_panel.add_theme_stylebox_override("panel", UiStyle.frame(Color("#211b16e8"), UiStyle.STEEL, 1))
	screen.page.add_child(scope_panel)
	screen.place(scope_panel, Rect2(28, 744, 496, 132))
	screen.text(Rect2(45, 758, 462, 25), "적용 대상 스킬", 17, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.GOLD_BRIGHT)
	var scope_label := screen.live_text(Rect2(45, 790, 462, 38), _approved_card_scope_text, 24, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.IVORY)
	scope_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.text(Rect2(45, 835, 462, 25), "장착 중인 스킬 기준으로 계산된 예상값", 14, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.MUTED)


func _build_reference_tabs(screen: REFERENCE_SCREEN, forge_screen: bool) -> void:
	# Keep navigation in one predictable strip. The old forge screen mixed a
	# title, a small card button and a separate close button in different sizes.
	# A two-tab strip makes the current area obvious at a glance.
	var bar_height := 76.0 if forge_screen else 100.0
	screen.solid(Rect2(0, 0, 552, bar_height), Color("#171411"))
	var first_width := 220.0 if forge_screen else 224.0
	var second_x := 246.0 if forge_screen else 238.0
	var second_width := 236.0 if forge_screen else 238.0
	var close_x := 490.0 if forge_screen else 490.0
	var first := screen.styled_button(Rect2(18, 13, first_width, 52), "장비 관리", func(): _show_mode("equipment"))
	var second := screen.styled_button(Rect2(second_x, 13, second_width, 52), "증강 카드", func(): _show_mode("cards"))
	var close_button := screen.styled_button(Rect2(close_x, 15, 46, 48), "×", close)
	first.add_theme_font_size_override("font_size", 18 if forge_screen else 20)
	second.add_theme_font_size_override("font_size", 18 if forge_screen else 20)
	close_button.add_theme_font_size_override("font_size", 24)
	if forge_screen:
		_approved_forge_heading = first
		_approved_forge_cards_tab = second
	screen.updates.append(func():
		var equipment_selected := current_mode == "equipment"
		UiStyle.style_clean_button(first, equipment_selected)
		UiStyle.style_clean_button(second, not equipment_selected)
	)


func _build_card_detail(parent: VBoxContainer) -> void:
	card_detail = VBoxContainer.new()
	card_detail.add_theme_constant_override("separation", 14)
	parent.add_child(card_detail)
	var back := UiStyle.make_button("‹ 목록으로", Vector2(0, 60))
	back.pressed.connect(_close_card_detail)
	card_detail.add_child(back)
	card_detail_title = UiStyle.make_title("", 29)
	card_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_detail.add_child(card_detail_title)
	card_detail_meta = UiStyle.make_label("", 20, UiStyle.GOLD_BRIGHT)
	card_detail_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_detail.add_child(card_detail_meta)
	UiStyle.divider(card_detail)
	card_detail_text = UiStyle.make_label("", 24)
	card_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_detail.add_child(card_detail_text)
	card_detail_preview = UiStyle.make_label("", 22, UiStyle.GOLD_BRIGHT)
	card_detail_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_detail.add_child(card_detail_preview)
	card_detail.hide()


func _refresh_cards(source_changed: bool = false) -> void:
	if source_changed:
		_close_card_detail()
		list_scroll.set_deferred("scroll_vertical", 0)
	for child in card_list.get_children():
		card_list.remove_child(child)
		child.queue_free()
	var ids := SurvivalCardDatabase.all_ids()
	var shown := 0
	for card_id in ids:
		var card := SurvivalCardDatabase.get_card(card_id)
		var category := SurvivalCardDatabase.get_category_name(str(card.stat))
		var grade := str(card.grade)
		_add_card_row(str(card.name), "%s · %s" % [category, grade], str(card.description), grade, card)
		shown += 1
	count_label.text = "%d종" % shown
	if shown == 0:
		card_list.add_child(UiStyle.make_label("보유한 카드가 없습니다.", 20, UiStyle.MUTED))


func _add_card_row(title: String, meta: String, description: String, grade: String, upgrade: Dictionary = {}) -> void:
	var button := UiStyle.make_button("", Vector2(0, 100))
	var edge := UiStyle.grade_color(str({"일반": "N", "희귀": "R", "영웅": "SR", "전설": "SSR"}.get(grade, grade)))
	UiStyle.skin_button(button, UiStyle.INK_SOFT, edge, UiStyle.IVORY)
	if _approved_catalog:
		button.custom_minimum_size.y = 141
		var trim := _approved_catalog.trim(Rect2(21, 233, 510, 142), 12, false)
		button.add_theme_stylebox_override("normal", trim)
		var background := ColorRect.new()
		background.color = Color("#2d251d")
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.offset_left = 17
		background.offset_right = -17
		background.offset_top = 16
		background.offset_bottom = -16
		button.add_child(background)
	var margin := UiStyle.make_margin(button, 12)
	margin.name = "CardTextMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var category := SurvivalCardDatabase.get_category(str(upgrade.stat)) if upgrade.has("stat") else ""
	row.add_child(UiStyle.icon_view(UiStyle.category_icon(category), 37, UiStyle.category_tint(category)))
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 3)
	row.add_child(content)
	var display_title := title
	if upgrade.has("stat"):
		var category_name := SurvivalCardDatabase.get_category_name(str(upgrade.stat))
		display_title = "%s  ·  %s  ·  %s" % [title, category_name, grade]
	var title_label := UiStyle.make_title(display_title, 20 if upgrade.has("stat") else 23)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [title_label, UiStyle.make_label(meta, 16 if upgrade.has("stat") else 18, edge), UiStyle.make_label(description, 18 if upgrade.has("stat") else 19)]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
	var arrow := UiStyle.make_label("›", 27, UiStyle.RUST)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)
	# Button children do not contribute to the button's minimum height.
	margin.minimum_size_changed.connect(func():
		button.custom_minimum_size.y = maxf(141 if _approved_catalog else 100, margin.get_combined_minimum_size().y)
	)
	button.pressed.connect(_show_card_detail.bind(title, meta, description, upgrade))
	card_list.add_child(button)


func _show_card_detail(title: String, meta: String, description: String, upgrade: Dictionary = {}) -> void:
	card_scroll_position = list_scroll.scroll_vertical
	card_detail_title.text = title
	card_detail_meta.text = meta
	card_detail_text.text = description
	card_detail_preview.text = AUGMENT_PREVIEW.describe(upgrade) if not upgrade.is_empty() else ""
	_approved_card_category = SurvivalCardDatabase.get_category(str(upgrade.stat)) if upgrade.has("stat") else ""
	_approved_card_icon = {"attack": "⚔", "defense": "⛨", "recovery": "✚"}.get(_approved_card_category, "◆")
	_approved_damage_changes = AUGMENT_PREVIEW.skill_damage_changes(upgrade)
	card_detail_preview.visible = not card_detail_preview.text.is_empty()
	card_list.hide()
	card_detail.show()
	list_scroll.set_deferred("scroll_vertical", 0)
	_sync_approved_screen()

func _approved_card_scope_text() -> String:
	if not _approved_damage_changes.is_empty():
		var slots := PackedStringArray()
		for change in _approved_damage_changes:
			slots.append(str(change.get("slot", "")))
		return " · ".join(slots)
	if not card_detail_preview.text.is_empty():
		return card_detail_preview.text
	return "카드 효과에 따라 적용 대상이 결정됩니다"


func _close_card_detail() -> void:
	if not card_detail.visible:
		return
	card_detail.hide()
	card_list.visible = not equipment_mode
	list_scroll.set_deferred("scroll_vertical", card_scroll_position)
	_sync_approved_screen()

func _skin_tab(button: Button, selected: bool) -> void:
	UiStyle.skin_button(button, UiStyle.SELECTED if selected else UiStyle.INK_SOFT,
		UiStyle.AMBER if selected else UiStyle.STEEL_DARK, UiStyle.IVORY)

func _refresh_portrait() -> void:
	if equipment_mode and portrait == null:
		portrait = CHARACTER_PORTRAIT.new()
		portrait.custom_minimum_size = Vector2(240, 326)
		portrait_holder.add_child(portrait)
	if portrait:
		_layout_equipment()
		portrait.set_portrait_active(equipment_mode)
		if equipment_mode:
			portrait.show_character(GameData.get_leader_id())


func _inventory_items() -> Array[Dictionary]:
	var items := GameData.inventory.duplicate()
	var grades := {"SSR": 4, "SR": 3, "R": 2, "N": 1}
	items.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(grades.get(a.get("grade", ""), 0)) > int(grades.get(b.get("grade", ""), 0)))
	return items


func _equipped_item(slot: String) -> Dictionary:
	var equipped: Dictionary = GameData.equipped_gear.get(GameData.get_leader_id(), {})
	return GameData._get_inventory_item(str(equipped.get(slot, "")))


func _equipment_score(item: Dictionary) -> float:
	return float(item.get("atk", 0)) * 3.0 + float(item.get("def", 0)) * 2.0 + float(item.get("hp", 0)) * 0.35 + float(item.get("spd", 0)) * 12.0


func _add_equipment_comparison_marker(button: Button, item: Dictionary) -> void:
	var slot := str(item.get("type", ""))
	if slot not in EQUIPMENT_TYPES or str(item.get("id", "")) == str(_equipped_item(slot).get("id", "")):
		return
	var equipped := _equipped_item(slot)
	var candidate_score := _equipment_score(item)
	var equipped_score := _equipment_score(equipped) if not equipped.is_empty() else 0.0
	if is_equal_approx(candidate_score, equipped_score):
		return
	var marker := Label.new()
	marker.text = "↑" if candidate_score > equipped_score else "↓"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 26)
	marker.add_theme_color_override("font_color", Color("#ff3f45") if candidate_score > equipped_score else Color("#4c9cff"))
	marker.add_theme_color_override("font_outline_color", Color("#170d0d") if candidate_score > equipped_score else Color("#071529"))
	marker.add_theme_constant_override("outline_size", 5)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	marker.offset_left = -36.0
	marker.offset_top = -38.0
	marker.offset_right = -5.0
	marker.offset_bottom = -4.0
	button.add_child(marker)


func _refresh_equipped() -> void:
	for slot in EQUIPMENT_TYPES:
		var button: Button = slot_buttons[slot]
		var item := _equipped_item(slot)
		button.tooltip_text = str(item.get("name", "비어 있음"))
		button.disabled = item.is_empty()


func _open_equipped(slot: String) -> void:
	var item := _equipped_item(slot)
	if not item.is_empty():
		_open_item(item)


func _open_item(item: Dictionary) -> void:
	selected_item = item
	_refresh_gear_comparison()
	_update_gear_selection()

func _build_gear_comparison(layout: VBoxContainer) -> void:
	gear_comparison = UiStyle.make_panel(UiStyle.INK_SOFT)
	layout.add_child(gear_comparison)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	UiStyle.make_margin(gear_comparison, 10).add_child(details)
	comparison_title = UiStyle.make_title("", 23)
	comparison_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(comparison_title)
	UiStyle.divider(details)
	comparison_values = VBoxContainer.new()
	details.add_child(comparison_values)
	item_action = UiStyle.make_button("장착", Vector2(0, 60), true)
	item_action.add_theme_font_size_override("font_size", 23)
	item_action.pressed.connect(_on_item_action)
	layout.add_child(item_action)

func _refresh_gear_comparison() -> void:
	var item := GameData._get_inventory_item(str(selected_item.get("id", "")))
	var slot := str(item.get("type", ""))
	var can_preview := equipment_mode and slot in EQUIPMENT_TYPES
	gear_comparison.visible = can_preview
	item_action.visible = can_preview
	if not can_preview:
		return
	var equipped := _equipped_item(slot)
	var is_equipped: bool = equipped.get("id") == item.get("id")
	comparison_title.text = "%s  ·  장착 중" % item.name if is_equipped else str(item.name)
	comparison_title.tooltip_text = str(item.get("desc", ""))
	item_action.text = "장착 해제" if is_equipped else "장착"
	for child in comparison_values.get_children():
		comparison_values.remove_child(child)
		child.queue_free()
	for field in [["atk", "물리 공격력"], ["def", "장비 방어"], ["hp", "장비 체력"], ["spd", "장비 이동"]]:
		var before := float(equipped.get(field[0], 0))
		var after := float(item.get(field[0], 0))
		if is_equal_approx(before, after) and (not is_equipped or is_zero_approx(after)):
			continue
		if field[0] == "atk":
			var base := GameData.get_character_stat_manager(GameData.get_leader_id()).phys_atk()
			var delta := after - before
			before = base * GameData.attack_damage_mult
			after = before + base * delta / 100.0
		var row := HBoxContainer.new()
		var name_label := UiStyle.make_label(field[1], 17, UiStyle.MUTED)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var tint := UiStyle.IVORY if is_equipped else (Color("#ff7264") if after > before else UiStyle.DEFENSE)
		var value := String.num(after, 2) if is_equipped else "%s → %s" % [String.num(before, 2), String.num(after, 2)]
		row.add_child(UiStyle.make_label(value, 21, tint))
		comparison_values.add_child(row)
	if comparison_values.get_child_count() == 0:
		comparison_values.add_child(UiStyle.make_label("능력치 변동 없음", 18, UiStyle.MUTED))

func _update_gear_selection() -> void:
	var selected_id := str(selected_item.get("id", ""))
	for id in gear_buttons:
		var button: Button = gear_buttons[id]
		var item := GameData._get_inventory_item(str(id))
		var trim := UiStyle.AMBER if id == selected_id else UiStyle.grade_color(str(item.get("grade", "")))
		UiStyle.skin_button(button, UiStyle.SELECTED if id == selected_id else UiStyle.INK_SOFT, trim, UiStyle.IVORY)
	for slot in slot_buttons:
		var button: Button = slot_buttons[slot]
		var selected: bool = selected_item.get("type", "") == slot
		UiStyle.skin_button(button, UiStyle.SELECTED if selected else UiStyle.INK_SOFT, UiStyle.AMBER if selected else UiStyle.STEEL, UiStyle.IVORY)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := button.get_theme_stylebox(state)
			style.content_margin_left = 5
			style.content_margin_right = 5


func _on_item_action() -> void:
	var slot := str(selected_item.get("type", ""))
	var id := str(selected_item.get("id", ""))
	if slot not in EQUIPMENT_TYPES or GameData._get_inventory_item(id).is_empty():
		return
	var leader := GameData.get_leader_id()
	var current: Dictionary = GameData.equipped_gear.get(leader, {})
	current[slot] = null if current.get(slot) == id else id
	GameData.equipped_gear[leader] = current
	_commit_equipment()
	UiStyle.play_sfx("equip", -2.0)


func _auto_equip_recommended() -> void:
	var leader := GameData.get_leader_id()
	var current: Dictionary = GameData.equipped_gear.get(leader, {})
	var best_scores := {}
	for item in GameData.inventory:
		var slot := str(item.get("type", ""))
		if slot not in EQUIPMENT_TYPES:
			continue
		var score := _equipment_score(item)
		if not best_scores.has(slot) or score > float(best_scores[slot]):
			best_scores[slot] = score
			current[slot] = str(item.get("id", ""))
	GameData.equipped_gear[leader] = current
	_commit_equipment()
	UiStyle.play_sfx("equip", -2.0)
	UiFeedback.show_success("추천 장비를 장착했습니다.")


func _commit_equipment() -> void:
	GameData.recalculate_party_stats()
	GameData.save_to_disk()
	GameData.data_updated.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		if card_detail.visible:
			_close_card_detail()
		else:
			close()
		get_viewport().set_input_as_handled()
