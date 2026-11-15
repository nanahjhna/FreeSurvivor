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

var current_filter: String = "all"
var selected_item_idx: int = 0
var display_items: Array[Dictionary] = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameData.data_updated.connect(_refresh_ui)

func open():
	visible = true
	_refresh_ui()

func close():
	visible = false
	closed.emit()

func _refresh_ui():
	_build_display_items()
	_populate_grid()
	_show_detail(selected_item_idx)

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
		
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(80, 80)
		slot_btn.toggle_mode = true
		slot_btn.button_pressed = (i == selected_item_idx)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var ic = Label.new()
		ic.text = itm.get("icon", "📦")
		ic.add_theme_font_size_override("font_size", 28)
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(ic)
		
		if itm.has("count"):
			var cnt = Label.new()
			cnt.text = "x" + str(itm.count)
			cnt.add_theme_font_size_override("font_size", 11)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	item_grade_lbl.text = "등급: " + itm.get("grade", "일반") + " • " + itm.get("type", "기타")
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
		var leader_index = clampi(GameData.leader_index, 0, GameData.party_slots.size() - 1)
		var leader_id = GameData.party_slots[leader_index]
		var equipped_id = GameData.equipped_gear.get(leader_id, {}).get(itm.type, null)
		action_btn.text = "해제" if equipped_id == itm.id else "⚔️ 대표 캐릭터에게 장착"
	else:
		action_btn.visible = false

func _on_action_pressed():
	if selected_item_idx < 0 or selected_item_idx >= display_items.size():
		return
	var itm = display_items[selected_item_idx]
	if itm.type not in ["weapon", "armor", "accessory"]:
		return
	var leader_index = clampi(GameData.leader_index, 0, GameData.party_slots.size() - 1)
	var leader_char_id = GameData.party_slots[leader_index]
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

func _on_tab_all(): current_filter = "all"; _refresh_ui()
func _on_tab_gear(): current_filter = "gear"; _refresh_ui()
func _on_tab_mat(): current_filter = "mat"; _refresh_ui()

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
