extends CanvasLayer

signal closed()

@onready var grid_container: GridContainer = $Panel/Margin/VBox/Body/LeftArea/Scroll/GridContainer
@onready var item_name_lbl: Label = $Panel/Margin/VBox/Body/RightDetail/Content/Header/Info/NameLabel
@onready var item_grade_lbl: Label = $Panel/Margin/VBox/Body/RightDetail/Content/Header/Info/GradeLabel
@onready var item_icon_lbl: Label = get_node(
	"Panel/Margin/VBox/Body/RightDetail/Content/Header/IconPanel/IconLabel"
)
@onready var item_stats_lbl: Label = $Panel/Margin/VBox/Body/RightDetail/Content/StatsLabel
@onready var item_desc_lbl: Label = $Panel/Margin/VBox/Body/RightDetail/Content/DescLabel
@onready var action_btn: Button = $Panel/Margin/VBox/Body/RightDetail/Content/ActionBtn
@onready var left_area: VBoxContainer = $Panel/Margin/VBox/Body/LeftArea

var current_filter: String = "all"
var selected_item_idx: int = 0
var display_items: Array[Dictionary] = []
var auto_equip_button: Button
var equipment_slot_row: HBoxContainer
var equipment_slot_buttons: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var portrait := UiStyle.fit_modal($Panel, Vector2(760, 990))
	$Panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	$Panel/Margin/VBox/Body/RightDetail.add_theme_stylebox_override("panel", UiStyle.sub_panel_style())
	UiStyle.apply_button(action_btn, true)
	for tab_node in [$Panel/Margin/VBox/Tabs/TabAll, $Panel/Margin/VBox/Tabs/TabGear, $Panel/Margin/VBox/Tabs/TabMat, $Panel/Margin/VBox/Header/CloseBtn]:
		UiStyle.apply_button(tab_node as Button)
	grid_container.columns = clampi(int((get_viewport().get_visible_rect().size.x - 96.0) / 118.0), 3, 6) if portrait else 6
	if portrait:
		var margin := $Panel/Margin as MarginContainer
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		$Panel/Margin/VBox/Body/LeftArea/Scroll.custom_minimum_size.y = 300
		$Panel/Margin/VBox/Header/CloseBtn.custom_minimum_size = Vector2(52, 48)
		for tab_node in [$Panel/Margin/VBox/Tabs/TabAll, $Panel/Margin/VBox/Tabs/TabGear, $Panel/Margin/VBox/Tabs/TabMat]:
			var tab := tab_node as Button
			tab.custom_minimum_size.x = 0
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.add_theme_font_size_override("font_size", 14)
		$Panel/Margin/VBox/Tabs/TabMat.text = "기타"
	_build_equipment_strip()
	auto_equip_button = UiStyle.make_button("✨ 추천 장비 자동 장착", Vector2(0, 44))
	auto_equip_button.tooltip_text = "직업과 장비 능력치를 비교해 가장 높은 점수의 장비를 장착합니다. 기존 장비는 삭제하거나 판매하지 않습니다."
	auto_equip_button.pressed.connect(_auto_equip_recommended)
	action_btn.get_parent().add_child(auto_equip_button)
	GameData.data_updated.connect(_refresh_ui)

func open():
	visible = true
	_refresh_ui()

func close():
	visible = false
	closed.emit()

func _refresh_ui():
	for tab_node in [$Panel/Margin/VBox/Tabs/TabAll, $Panel/Margin/VBox/Tabs/TabGear, $Panel/Margin/VBox/Tabs/TabMat]:
		var tab := tab_node as Button
		UiStyle.apply_button(tab)
		var selected: bool = (tab.name == "TabAll" and current_filter == "all") or (tab.name == "TabGear" and current_filter == "gear") or (tab.name == "TabMat" and current_filter == "mat")
		if selected:
			tab.add_theme_stylebox_override("normal", UiStyle.button_style(Color(0.25, 0.045, 0.028, 0.98), UiStyle.GOLD_BRIGHT))
	_build_display_items()
	_refresh_equipment_strip()
	_populate_grid()
	_show_detail(selected_item_idx)

func _build_equipment_strip():
	var heading := UiStyle.make_label("현재 장착", 14, UiStyle.GOLD_BRIGHT)
	left_area.add_child(heading)
	left_area.move_child(heading, 0)
	equipment_slot_row = HBoxContainer.new()
	equipment_slot_row.add_theme_constant_override("separation", 8)
	left_area.add_child(equipment_slot_row)
	left_area.move_child(equipment_slot_row, 1)
	for slot in [["weapon", "⚔", "무기"], ["armor", "🛡", "방어구"], ["accessory", "✦", "장신구"]]:
		var button := UiStyle.make_button("", Vector2(0, 72))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_equipped_slot_pressed.bind(str(slot[0])))
		equipment_slot_buttons[str(slot[0])] = button
		equipment_slot_row.add_child(button)

func _refresh_equipment_strip():
	var leader_id := GameData.get_leader_id()
	var equipment_value: Variant = GameData.equipped_gear.get(leader_id, {})
	var equipment: Dictionary = equipment_value if equipment_value is Dictionary else {}
	for slot_name in equipment_slot_buttons:
		var button := equipment_slot_buttons[slot_name] as Button
		var item_id := str(equipment.get(slot_name, ""))
		var item := GameData._get_inventory_item(item_id) if not item_id.is_empty() else {}
		var slot_title := "무기" if slot_name == "weapon" else ("방어구" if slot_name == "armor" else "장신구")
		var icon := "⚔" if slot_name == "weapon" else ("🛡" if slot_name == "armor" else "✦")
		button.text = "%s  %s\n%s" % [icon, slot_title, str(item.get("name", "빈 슬롯"))]
		button.disabled = item_id.is_empty()
		button.tooltip_text = str(item.get("name", "장착된 아이템이 없습니다."))

func _on_equipped_slot_pressed(slot_name: String):
	var equipment_value: Variant = GameData.equipped_gear.get(GameData.get_leader_id(), {})
	var equipment: Dictionary = equipment_value if equipment_value is Dictionary else {}
	var equipped_id := str(equipment.get(slot_name, ""))
	if equipped_id.is_empty():
		return
	current_filter = "gear"
	for index in range(display_items.size()):
		if str(display_items[index].get("id", "")) == equipped_id:
			selected_item_idx = index
			_refresh_ui()
			return

func _build_display_items():
	display_items = GameData.inventory.duplicate()
	var consumables = [
		{
			"id": "consumable_1", "type": "consumable", "name": "치유 물약",
			"icon": "🧪", "desc": "HP를 35 회복합니다.",
			"count": GameData.item_counts.get(1, 0)
		},
		{
			"id": "consumable_2", "type": "consumable", "name": "화면 폭탄",
			"icon": "💣", "desc": "주변 적에게 큰 피해를 줍니다.",
			"count": GameData.item_counts.get(2, 0)
		},
		{
			"id": "consumable_3", "type": "consumable", "name": "질풍 물약",
			"icon": "💨", "desc": "5초 동안 이동속도가 증가합니다.",
			"count": GameData.item_counts.get(3, 0)
		}
	]
	for consumable in consumables:
		display_items.append(consumable)
	display_items.sort_custom(func(a: Dictionary, b: Dictionary):
		var grade_order := {"SSR":4, "SR":3, "R":2, "N":1}
		var a_grade := int(grade_order.get(a.get("grade", "N"), 0))
		var b_grade := int(grade_order.get(b.get("grade", "N"), 0))
		return a_grade > b_grade if a_grade != b_grade else str(a.get("type", "")) < str(b.get("type", ""))
	)

func _populate_grid():
	for child in grid_container.get_children():
		child.queue_free()
	
	for i in range(display_items.size()):
		var itm = display_items[i]
		if current_filter != "all":
			if current_filter == "gear" and itm.type not in ["weapon", "armor", "accessory"]:
				continue
			elif current_filter == "mat" and itm.type != "material" and itm.type != "consumable":
				continue
		
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(88, 96)
		slot_btn.toggle_mode = true
		slot_btn.button_pressed = (i == selected_item_idx)
		var grade := str(itm.get("grade", "N"))
		var grade_color := Color(0.68, 0.53, 0.34)
		match grade:
			"R": grade_color = Color(0.76, 0.58, 0.36)
			"SR": grade_color = Color(0.9, 0.43, 0.28)
			"SSR": grade_color = UiStyle.GOLD_BRIGHT
		slot_btn.add_theme_stylebox_override("normal", UiStyle.button_style(Color(0.055, 0.03, 0.027, 0.98), grade_color))
		slot_btn.add_theme_stylebox_override("hover", UiStyle.button_style(Color(0.17, 0.045, 0.025, 1.0), grade_color.lightened(0.2)))
		slot_btn.add_theme_stylebox_override("pressed", UiStyle.button_style(Color(0.25, 0.045, 0.028, 1.0), UiStyle.GOLD_BRIGHT))
		slot_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var ic = Label.new()
		ic.text = itm.get("icon", "📦")
		ic.add_theme_font_size_override("font_size", 28)
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(ic)
		if itm.has("grade"):
			var grade_label := UiStyle.make_label(grade, 11, grade_color)
			grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(grade_label)
		
		if itm.has("count"):
			var cnt = Label.new()
			cnt.text = "x" + str(itm.count)
			cnt.add_theme_font_size_override("font_size", 11)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(cnt)
		
		slot_btn.add_child(vbox)
		var itm_idx = i
		slot_btn.pressed.connect(func(): _on_item_clicked(itm_idx))
		grid_container.add_child(slot_btn)

func _on_item_clicked(idx: int):
	selected_item_idx = idx
	_refresh_ui()

func _show_detail(idx: int):
	if idx < 0 or idx >= display_items.size():
		return
	var itm = display_items[idx]
	item_name_lbl.text = itm.get("name", "아이템")
	item_grade_lbl.text = "%s  ·  %s" % [str(itm.get("grade", "일반")), str(itm.get("type", "기타"))]
	item_icon_lbl.text = itm.get("icon", "📦")
	item_desc_lbl.text = itm.get("desc", "")
	
	var stats_text = ""
	if itm.has("atk") and itm.atk > 0:
		stats_text += "공격력: +%d  " % itm.atk
	if itm.has("def") and itm.def > 0:
		stats_text += "방어력: +%d  " % itm.def
	if itm.has("hp") and itm.hp > 0:
		stats_text += "HP: +%d  " % itm.hp
	if itm.has("spd") and itm.spd != 0:
		stats_text += "이동속도: +%.1f  " % itm.spd
	
	if stats_text == "":
		stats_text = "보유 수량: %d개" % itm.get("count", 1)
	item_stats_lbl.text = stats_text
	
	if itm.type in ["weapon", "armor", "accessory"]:
		action_btn.visible = true

		var leader_id = GameData.get_leader_id()
		var equipped_id = GameData.equipped_gear.get(leader_id, {}).get(itm.type, null)
		action_btn.text = "해제" if equipped_id == itm.id else "⚔️ 장착"
		if equipped_id != null and equipped_id != itm.id:
			var current := GameData._get_inventory_item(str(equipped_id))
			item_stats_lbl.text += "\n장착 중 대비  공격 %+d · 방어 %+d · HP %+d · 속도 %+.1f" % [
				int(itm.get("atk", 0)) - int(current.get("atk", 0)), int(itm.get("def", 0)) - int(current.get("def", 0)),
				int(itm.get("hp", 0)) - int(current.get("hp", 0)), float(itm.get("spd", 0.0)) - float(current.get("spd", 0.0))]
	else:
		action_btn.visible = false

func _on_action_pressed():
	if selected_item_idx < 0 or selected_item_idx >= display_items.size():
		return
	var itm = display_items[selected_item_idx]
	if itm.type not in ["weapon", "armor", "accessory"]:
		return

	var leader_char_id = GameData.get_leader_id()
	if not GameData.equipped_gear.has(leader_char_id):
		GameData.equipped_gear[leader_char_id] = {}
	if GameData.equipped_gear[leader_char_id].get(itm.type, null) == itm.id:
		GameData.equipped_gear[leader_char_id][itm.type] = null
	else:
		GameData.equipped_gear[leader_char_id][itm.type] = itm.id
	GameData.recalculate_party_stats()
	GameData.save_to_disk()
	GameData.data_updated.emit()
	_show_detail(selected_item_idx)

func _auto_equip_recommended():
	var leader_id := GameData.get_leader_id()
	var best_by_type: Dictionary = {}
	var best_score: Dictionary = {}
	for item in GameData.inventory:
		var item_type := str(item.get("type", ""))
		if item_type not in ["weapon", "armor", "accessory"]:
			continue
		var score := _equipment_score(item)
		if not best_score.has(item_type) or score > float(best_score[item_type]):
			best_score[item_type] = score
			best_by_type[item_type] = str(item.get("id", ""))
	if not GameData.equipped_gear.has(leader_id):
		GameData.equipped_gear[leader_id] = {}
	for item_type in best_by_type:
		GameData.equipped_gear[leader_id][item_type] = best_by_type[item_type]
	GameData.recalculate_party_stats()
	GameData.save_to_disk()
	GameData.data_updated.emit()
	UiFeedback.show_success("추천 장비를 장착했습니다. 기존 장비는 인벤토리에 유지됩니다.")

func _equipment_score(item: Dictionary) -> float:
	return float(item.get("atk", 0)) * 3.0 + float(item.get("def", 0)) * 2.0 + float(item.get("hp", 0)) * 0.35 + float(item.get("spd", 0.0)) * 12.0

func _on_tab_all(): current_filter = "all"; _refresh_ui()
func _on_tab_gear(): current_filter = "gear"; _refresh_ui()
func _on_tab_mat(): current_filter = "mat"; _refresh_ui()

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
