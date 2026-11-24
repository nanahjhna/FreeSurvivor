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
	scrim.color = Color(0.018, 0.014, 0.02, 0.82)
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	card = UiStyle.make_panel()
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	UiStyle.make_margin(card, 24).add_child(content)

	banner = UiStyle.make_panel()
	content.add_child(banner)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	banner.add_child(header)
	title = UiStyle.make_label("", 33, Color.WHITE)
	UiStyle.ink_outline(title, 7, Color("#45225d"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := UiStyle.make_button("×", Vector2(58, 54))
	close_button.tooltip_text = "닫기"
	UiStyle.skin_button(close_button, Color("#926448"), Color("#ffdc99"))
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(hide)
	header.add_child(close_button)

	var item_header := HBoxContainer.new()
	item_header.add_theme_constant_override("separation", 16)
	content.add_child(item_header)
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
	var identity_box := UiStyle.plaque("", Color("#59402f"), Color("#9c714a"), Color("#fff0ce"), 20)
	item_text.add_child(identity_box)
	identity = identity_box.get_child(0) as Label
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description = UiStyle.make_label("", 21, UiStyle.PAPER_INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_text.add_child(description)
	stat_section = VBoxContainer.new()
	stat_section.add_theme_constant_override("separation", 6)
	content.add_child(stat_section)
	stat_section.add_child(UiStyle.plaque("능력치", Color("#614631"), Color("#a8754b"), Color("#fff0cc"), 24))
	var stat_plate := UiStyle.make_panel()
	stat_plate.add_theme_stylebox_override("panel", UiStyle.frame(Color("#ead4a4"), Color("#d5ad77"), 9, 2))
	stat_section.add_child(stat_plate)
	stats = UiStyle.make_label("", 22, UiStyle.PAPER_INK)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_plate.add_child(stats)
	action = UiStyle.make_button("", Vector2(0, 60), true)
	UiStyle.skin_button(action, UiStyle.BLUE, UiStyle.BLUE_EDGE)
	action.add_theme_font_size_override("font_size", 23)
	action.pressed.connect(func(): action_requested.emit())
	content.add_child(action)
	get_viewport().size_changed.connect(_fit)
	_fit()
	hide()


func _fit() -> void:
	var safe := UiStyle.safe_insets(get_viewport())
	card.custom_minimum_size.x = minf(620, get_viewport_rect().size.x - safe.x - safe.z - 48)


func show_item(item: Dictionary, action_text: String = "", comparison: String = "") -> void:
	var grade := str(item.get("grade", ""))
	var trim := UiStyle.grade_color(grade)
	var faces := {"SSR": Color("#ab572b"), "SR": Color("#813caa"), "R": Color("#395fc1")}
	var tone: Color = faces.get(grade, Color("#775486"))
	card.add_theme_stylebox_override("panel", UiStyle.frame(UiStyle.PAPER, Color("#c59058"), 22, 7))
	banner.add_theme_stylebox_override("panel", UiStyle.frame(tone, trim.lightened(0.12), 13, 4))
	emblem.add_theme_stylebox_override("panel", UiStyle.frame(tone.darkened(0.23), trim, 20, 5))
	title.text = str(item.get("name", "아이템"))
	icon.text = str(item.get("icon", "◆"))
	var type := str(item.get("type", ""))
	var types := {"weapon": "무기", "armor": "방어구", "accessory": "장신구", "material": "재료", "consumable": "소모품", "card": "카드"}
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
