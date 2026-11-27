extends Control

signal action_requested

var card: PanelContainer
var banner: PanelContainer
var emblem: PanelContainer
var stat_section: VBoxContainer
var title: Label
var identity: Label
var icon: Label
var stats: Label
var description: Label
var action: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = UiStyle.SCRIM
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	card = UiStyle.make_panel()
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	UiStyle.make_margin(card, 24).add_child(content)

	banner = UiStyle.notice_board()
	content.add_child(banner)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	banner.add_child(header)
	title = UiStyle.make_title("", 33)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := UiStyle.make_button("×", Vector2(58, 54))
	close_button.tooltip_text = "닫기"
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(hide)
	header.add_child(close_button)

	var item_header := HBoxContainer.new()
	item_header.add_theme_constant_override("separation", 16)
	content.add_child(item_header)
	item_header.name = "ItemHeader"
	emblem = UiStyle.make_panel()
	emblem.custom_minimum_size = Vector2(146, 146)
	item_header.add_child(emblem)
	icon = UiStyle.make_label("", 64)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emblem.add_child(icon)
	var item_text := VBoxContainer.new()
	item_text.alignment = BoxContainer.ALIGNMENT_CENTER
	item_text.add_theme_constant_override("separation", 9)
	item_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_header.add_child(item_text)
	var identity_box := UiStyle.plaque("", UiStyle.INK_SOFT, UiStyle.RUST, UiStyle.IVORY, 20)
	item_text.add_child(identity_box)
	identity = identity_box.get_child(0) as Label
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description = UiStyle.make_label("", 21, UiStyle.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_text.add_child(description)
	stat_section = VBoxContainer.new()
	stat_section.add_theme_constant_override("separation", 6)
	content.add_child(stat_section)
	stat_section.add_child(UiStyle.plaque("능력치", UiStyle.INK_SOFT, UiStyle.STEEL, UiStyle.IVORY, 24))
	var stat_plate := UiStyle.make_panel()
	stat_plate.add_theme_stylebox_override("panel", UiStyle.art_panel())
	stat_section.add_child(stat_plate)
	stats = UiStyle.make_label("", 22)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_plate.add_child(stats)
	action = UiStyle.make_button("", Vector2(0, 60), true)
	action.add_theme_font_size_override("font_size", 23)
	action.pressed.connect(func(): action_requested.emit())
	content.add_child(action)
	get_viewport().size_changed.connect(_fit)
	_fit()
	hide()


func _fit() -> void:
	var safe := UiStyle.safe_insets(get_viewport())
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.y >= viewport_size.x and viewport_size.x < 600.0
	card.custom_minimum_size = Vector2(
		maxf(1.0, minf(620.0, viewport_size.x - safe.x - safe.z - 28.0)),
		maxf(1.0, minf(760.0, viewport_size.y - safe.y - safe.w - 28.0))
	)
	emblem.custom_minimum_size = Vector2(104 if compact else 146, 104 if compact else 146)
	title.add_theme_font_size_override("font_size", 25 if compact else 33)
	stats.add_theme_font_size_override("font_size", 18 if compact else 22)
	description.add_theme_font_size_override("font_size", 17 if compact else 21)


func show_item(item: Dictionary, action_text: String = "", comparison: String = "") -> void:
	var grade := str(item.get("grade", ""))
	var trim := UiStyle.grade_color(grade)
	emblem.add_theme_stylebox_override("panel", UiStyle.art_panel(trim))
	title.text = str(item.get("name", "아이템"))
	icon.text = str(item.get("icon", "◆"))
	var type := str(item.get("type", ""))
	var types := {"weapon": "무기", "armor": "방어구", "accessory": "장신구", "boots": "신발", "material": "재료", "card": "카드"}
	identity.text = str(types.get(type, type))
	if not grade.is_empty():
		identity.text = "%s  ·  %s" % [grade, identity.text]
	if item.has("count"):
		identity.text += "\n수량  %d" % int(item.count)
	var values := PackedStringArray()
	for entry in [["atk", "공격력"], ["def", "방어력"], ["hp", "최대 체력"], ["spd", "이동 속도"]]:
		var value := float(item.get(entry[0], 0))
		if not is_zero_approx(value):
			values.append("%s  %s%s" % [entry[1], "+" if value > 0 else "", str(value)])
	stats.text = "\n".join(values)
	if not comparison.is_empty():
		stats.text += "\n" + comparison
	stat_section.visible = not stats.text.is_empty()
	description.text = str(item.get("desc", ""))
	description.visible = not description.text.is_empty()
	action.text = action_text
	action.visible = not action_text.is_empty()
	show()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
