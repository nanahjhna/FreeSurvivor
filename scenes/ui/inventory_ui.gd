extends CanvasLayer

signal closed()

const ITEM_DETAIL := preload("res://scenes/ui/item_detail.gd")
const CHARACTER_PORTRAIT := preload("res://scenes/ui/character_portrait.gd")
const EQUIPMENT_TYPES := ["weapon", "armor", "accessory"]
const SLOT_TITLES := {"weapon": "무기", "armor": "방어구", "accessory": "장신구"}
const SLOT_ICONS := {"weapon": "⚔", "armor": "🛡", "accessory": "✦"}

var heading: Label
var count_label: Label
var filters: HBoxContainer
var grid: GridContainer
var equipment: VBoxContainer
var item_detail: ITEM_DETAIL
var selected_item: Dictionary = {}
var current_filter := "all"
var equipment_mode := false
var forge_mode := false
var equipment_identity: Label
var portrait_holder: CenterContainer
var portrait: CHARACTER_PORTRAIT
var mode_buttons: Dictionary = {}
var filter_buttons: Dictionary = {}
var slot_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	var layout := UiStyle.dialog_layout(self, "")
	var frame := layout.get_parent().get_parent() as PanelContainer
	frame.add_theme_stylebox_override("panel", UiStyle.frame(Color("#edcb94"), Color("#ac7549"), 20, 5))
	var header_band := UiStyle.make_panel()
	header_band.add_theme_stylebox_override("panel", UiStyle.frame(Color("#54348c"), Color("#c798ef"), 12, 3))
	layout.add_child(header_band)
	var header := HBoxContainer.new()
	header_band.add_child(header)
	heading = UiStyle.make_label("가방", 34, Color("#fff1e0"))
	UiStyle.ink_outline(heading, 6, Color("#372255"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	count_label = UiStyle.make_label("", 19, Color("#ead3fb"))
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(count_label)
	var close_button := UiStyle.make_button("×", Vector2(56, 52))
	close_button.tooltip_text = "닫기"
	close_button.add_theme_font_size_override("font_size", 27)
	UiStyle.skin_button(close_button, Color("#763f7b"), Color("#e5b5f4"))
	close_button.pressed.connect(close)
	header.add_child(close_button)
	UiStyle.divider(layout)

	var modes := HBoxContainer.new()
	layout.add_child(modes)
	for entry in [[false, "인벤토리"], [true, "장비 관리"]]:
		var button := _tab(modes, entry[1])
		button.pressed.connect(_show_mode.bind(entry[0]))
		mode_buttons[entry[0]] = button

	var body := UiStyle.scroll_column(layout)
	equipment = VBoxContainer.new()
	equipment.add_theme_constant_override("separation", 10)
	body.add_child(equipment)
	equipment_identity = UiStyle.make_label("", 29, UiStyle.PAPER_INK)
	equipment_identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_identity.custom_minimum_size.y = 52
	equipment_identity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment.add_child(equipment_identity)
	var platform := PanelContainer.new()
	platform.add_theme_stylebox_override("panel", UiStyle.frame(Color("#f7dfaa"), Color("#bf9361"), 14, 2))
	equipment.add_child(platform)
	var stage_light := TextureRect.new()
	stage_light.texture = UiStyle.tint_gradient(Color("#efd09b"), Color("#fff0c4"))
	stage_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	platform.add_child(stage_light)
	var slots := HBoxContainer.new()
	slots.custom_minimum_size.y = 342
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
		var slot := UiStyle.make_button("", Vector2(108, 113))
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot.pressed.connect(_open_equipped.bind(type))
		(right if type == "armor" else left).add_child(slot)
		slot_buttons[type] = slot
	var auto_equip := UiStyle.make_button("추천 장비 장착", Vector2(0, 52))
	UiStyle.skin_button(auto_equip, Color("#a26a36"), Color("#ffe3a0"))
	auto_equip.add_theme_font_size_override("font_size", 21)
	auto_equip.pressed.connect(_auto_equip_recommended)
	equipment.add_child(auto_equip)
	UiStyle.divider(equipment)
	equipment.add_child(UiStyle.make_label("보유 장비", 25, UiStyle.PAPER_INK))

	filters = HBoxContainer.new()
	body.add_child(filters)
	for entry in [["all", "전체"], ["gear", "장비"], ["mat", "재료·소모품"]]:
		var button := _tab(filters, entry[1])
		button.pressed.connect(_set_filter.bind(entry[0]))
		filter_buttons[entry[0]] = button
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	body.add_child(grid)

	item_detail = ITEM_DETAIL.new()
	item_detail.action_requested.connect(_on_item_action)
	add_child(item_detail)
	get_viewport().size_changed.connect(_layout_grid)
	GameData.data_updated.connect(_refresh)
	_layout_grid()


func _tab(parent: Control, caption: String) -> Button:
	var button := UiStyle.make_button(caption, Vector2(0, 54))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button


func _layout_grid() -> void:
	var width := get_viewport().get_visible_rect().size.x
	var safe := UiStyle.safe_insets(get_viewport())
	grid.columns = clampi(int((minf(width, 700.0) - safe.x - safe.z - 88.0) / 106.0), 2, 5)


func open(show_equipment: bool = false, at_forge: bool = false) -> void:
	forge_mode = at_forge
	show()
	_show_mode(show_equipment)


func close() -> void:
	item_detail.hide()
	if portrait:
		portrait.set_portrait_active(false)
	hide()
	closed.emit()


func _show_mode(show_equipment: bool) -> void:
	equipment_mode = show_equipment
	current_filter = "all"
	_refresh()


func _set_filter(filter: String) -> void:
	current_filter = filter
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	heading.text = ("대장간" if forge_mode else "장비 관리") if equipment_mode else "가방"
	equipment.visible = equipment_mode
	var leader: Dictionary = GameData.characters.get(GameData.get_leader_id(), {})
	equipment_identity.text = "%s  %s" % [leader.get("icon", "⚔"), leader.get("name", "")]
	filters.visible = not equipment_mode
	for mode in mode_buttons:
		_skin_tab(mode_buttons[mode], mode == equipment_mode)
		mode_buttons[mode].add_theme_font_size_override("font_size", 19)
	for filter in filter_buttons:
		_skin_tab(filter_buttons[filter], current_filter == filter)
		filter_buttons[filter].add_theme_font_size_override("font_size", 18)
	_refresh_equipped()
	_refresh_portrait()
	var items := _inventory_items()
	var displayed := 0
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for item in items:
		var is_gear := str(item.get("type", "")) in EQUIPMENT_TYPES
		if (equipment_mode or current_filter == "gear") and not is_gear:
			continue
		if current_filter == "mat" and str(item.get("type", "")) not in ["material", "consumable"]:
			continue
		var grade := str(item.get("grade", ""))
		var button := UiStyle.make_button("%s\n%s" % [item.get("icon", "◆"), "×%d" % int(item.count) if item.has("count") else grade], Vector2(80, 96))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = str(item.get("name", ""))
		button.add_theme_font_size_override("font_size", 30)
		var color := UiStyle.grade_color(grade)
		UiStyle.skin_button(button, _slot_face(grade), color)
		button.pressed.connect(_open_item.bind(item))
		grid.add_child(button)
		displayed += 1
	count_label.text = "%d종" % displayed
	if displayed == 0:
		grid.add_child(UiStyle.make_label("보유한 아이템이 없습니다.", 18, UiStyle.PAPER_INK))

func _skin_tab(button: Button, selected: bool) -> void:
	if selected:
		UiStyle.skin_button(button, Color("#67479b"), Color("#e4c3fb"))
	else:
		UiStyle.skin_button(button, Color("#e1b27e"), Color("#c19062"), UiStyle.PAPER_INK)

func _slot_face(grade: String) -> Color:
	match grade:
		"SSR": return Color("#ad6637")
		"SR": return Color("#6847a5")
		"R": return Color("#3762a5")
	return Color("#575267")

func _refresh_portrait() -> void:
	if equipment_mode and portrait == null:
		portrait = CHARACTER_PORTRAIT.new()
		portrait.custom_minimum_size = Vector2(240, 326)
		portrait_holder.add_child(portrait)
	if portrait:
		portrait.set_portrait_active(equipment_mode)
		if equipment_mode:
			portrait.show_character(GameData.get_leader_id())


func _inventory_items() -> Array[Dictionary]:
	var items := GameData.inventory.duplicate()
	for item in [
		{"slot": 1, "name": "치유 물약", "icon": "🧪", "desc": "HP를 35 회복합니다."},
		{"slot": 2, "name": "화면 폭탄", "icon": "💣", "desc": "주변 적에게 큰 피해를 줍니다."},
		{"slot": 3, "name": "질풍 물약", "icon": "💨", "desc": "5초간 이동 속도가 증가합니다."}
	]:
		var slot := int(item.slot)
		var amount := int(GameData.item_counts.get(slot, 0))
		if amount > 0:
			items.append(item.merged({"type": "consumable", "count": amount}))
	var grades := {"SSR": 4, "SR": 3, "R": 2, "N": 1}
	items.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(grades.get(a.get("grade", ""), 0)) > int(grades.get(b.get("grade", ""), 0)))
	return items


func _equipped_item(slot: String) -> Dictionary:
	var equipped: Dictionary = GameData.equipped_gear.get(GameData.get_leader_id(), {})
	return GameData._get_inventory_item(str(equipped.get(slot, "")))


func _refresh_equipped() -> void:
	for slot in EQUIPMENT_TYPES:
		var button: Button = slot_buttons[slot]
		var item := _equipped_item(slot)
		button.text = "%s\n%s" % [item.get("icon", SLOT_ICONS[slot]), SLOT_TITLES[slot]]
		button.tooltip_text = str(item.get("name", "비어 있음"))
		button.disabled = item.is_empty()
		var grade := str(item.get("grade", ""))
		UiStyle.skin_button(button, _slot_face(grade), UiStyle.grade_color(grade))
		button.add_theme_font_size_override("font_size", 22)


func _open_equipped(slot: String) -> void:
	var item := _equipped_item(slot)
	if not item.is_empty():
		_open_item(item)


func _open_item(item: Dictionary) -> void:
	selected_item = item
	var slot := str(item.get("type", ""))
	var action := ""
	var comparison := ""
	if slot in EQUIPMENT_TYPES:
		var equipped := _equipped_item(slot)
		var is_equipped: bool = not equipped.is_empty() and equipped.id == item.id
		action = "장착 해제" if is_equipped else "장착"
		if not equipped.is_empty() and not is_equipped:
			comparison = "장착 중 대비  공격 %+d · 방어 %+d · HP %+d · 이동 %+.1f" % [
				int(item.get("atk", 0)) - int(equipped.get("atk", 0)),
				int(item.get("def", 0)) - int(equipped.get("def", 0)),
				int(item.get("hp", 0)) - int(equipped.get("hp", 0)),
				float(item.get("spd", 0)) - float(equipped.get("spd", 0))]
	item_detail.show_item(item, action, comparison)


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
	_open_item(selected_item)


func _auto_equip_recommended() -> void:
	var leader := GameData.get_leader_id()
	var current: Dictionary = GameData.equipped_gear.get(leader, {})
	var best_scores := {}
	for item in GameData.inventory:
		var slot := str(item.get("type", ""))
		if slot not in EQUIPMENT_TYPES:
			continue
		var score := float(item.get("atk", 0)) * 3.0 + float(item.get("def", 0)) * 2.0 + float(item.get("hp", 0)) * 0.35 + float(item.get("spd", 0)) * 12.0
		if not best_scores.has(slot) or score > float(best_scores[slot]):
			best_scores[slot] = score
			current[slot] = str(item.get("id", ""))
	GameData.equipped_gear[leader] = current
	_commit_equipment()
	UiFeedback.show_success("추천 장비를 장착했습니다.")


func _commit_equipment() -> void:
	GameData.recalculate_party_stats()
	GameData.save_to_disk()
	GameData.data_updated.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
