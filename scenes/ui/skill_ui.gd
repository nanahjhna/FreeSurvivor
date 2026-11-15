extends CanvasLayer

signal closed()

@onready var skill_cards_box: HBoxContainer = $Panel/Margin/VBox/CardsContainer
@onready var feedback_label: Label = $Panel/Margin/VBox/FeedbackLabel
@onready var screen_vbox: VBoxContainer = $Panel/Margin/VBox

var selected_slot: String = "q"
var selected_skill: String = ""
var _slot_target_chosen: bool = false
var slot_buttons: Dictionary = {}
var loadout_hint: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_loadout_controls()
	GameData.data_updated.connect(_refresh_ui)

func open():
	visible = true
	feedback_label.text = ""
	_refresh_ui()

func close():
	visible = false
	closed.emit()

func _refresh_ui():
	for child in skill_cards_box.get_children():
		child.queue_free()
	_update_loadout_controls()
	var keys = ["q", "w", "e", "r"]
	for k in keys:
		var meta = GameData.skill_meta[k]
		var cur_lvl = GameData.skill_levels.get(k, 1)
		var card = _create_skill_card(k, meta, cur_lvl)
		skill_cards_box.add_child(card)

func _build_loadout_controls():
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "전투 슬롯 (선택한 스킬을 슬롯에 터치/클릭)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	for slot in ["q", "w", "e", "r"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 42)
		button.toggle_mode = true
		button.pressed.connect(_on_loadout_slot_pressed.bind(slot))
		slot_buttons[slot] = button
		row.add_child(button)
	screen_vbox.add_child(row)
	screen_vbox.move_child(row, screen_vbox.get_node("CardsContainer").get_index())
	loadout_hint = Label.new()
	loadout_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_vbox.add_child(loadout_hint)
	screen_vbox.move_child(loadout_hint, screen_vbox.get_node("CardsContainer").get_index())

func _update_loadout_controls():
	for slot in slot_buttons:
		var skill_id := GameData.get_equipped_skill(str(slot))
		var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
		var button: Button = slot_buttons[slot]
		button.text = "%s: %s %s" % [str(slot).to_upper(), str(meta.get("icon", "—")), str(meta.get("name", "빈 슬롯"))]
		button.button_pressed = str(slot) == selected_slot
		button.tooltip_text = "현재 장착: %s. 선택한 스킬을 장착하거나 교체합니다." % str(meta.get("name", ""))
	loadout_hint.text = (
		"선택 스킬: %s · 대상 슬롯: %s (스킬→슬롯 또는 슬롯→스킬 순서로 선택)"
		% [
			str(GameData.skill_meta.get(selected_skill, {}).get("name", "스킬 없음")),
			selected_slot.to_upper()
		]
	)

func _on_loadout_slot_pressed(slot: String):
	selected_slot = slot
	if selected_skill != "":
		if GameData.equip_skill(slot, selected_skill):
			feedback_label.text = "%s 스킬을 %s 슬롯에 장착했습니다." % [
				str(GameData.skill_meta[selected_skill].get("name", "")), slot.to_upper()
			]
			selected_skill = ""
			_slot_target_chosen = false
		else:
			feedback_label.text = "전투 중에는 스킬 슬롯을 변경할 수 없습니다."
			feedback_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	else:
		_slot_target_chosen = true
	_update_loadout_controls()

func _on_skill_selected(skill_id: String):
	selected_skill = skill_id
	if _slot_target_chosen:
		_on_loadout_slot_pressed(selected_slot)
		return
	feedback_label.text = "%s 선택됨 · 장착할 슬롯 버튼을 누르세요." % str(GameData.skill_meta[skill_id].get("name", "스킬"))
	feedback_label.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	_update_loadout_controls()

func _create_skill_card(key: String, meta: Dictionary, lvl: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 360)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	var key_lbl = Label.new()
	key_lbl.text = "[" + key.to_upper() + " 스킬]"
	key_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(key_lbl)
	
	var icon = Label.new()
	icon.text = meta.get("icon", "⚡")
	icon.add_theme_font_size_override("font_size", 42)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon)
	
	var name_lbl = Label.new()
	name_lbl.text = meta.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	
	var lvl_lbl = Label.new()
	lvl_lbl.text = "현재 레벨: Lv." + str(lvl) + " / 10"
	lvl_lbl.add_theme_font_size_override("font_size", 13)
	lvl_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1))
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lvl_lbl)
	
	var cd = max(0.5, meta.base_cd - (meta.cd_step * (lvl - 1)))
	var dmg = meta.base_dmg_ratio + (meta.dmg_step * (lvl - 1))
	var stats = Label.new()
	stats.text = "쿨타임: %.1fs\n위력: x%.2f\n사거리: %.1f · SP: %d" % [
		cd, dmg, float(meta.get("range", 0.0)), int(meta.get("sp_cost", 0))
	]
	stats.add_theme_font_size_override("font_size", 12)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)
	var unlock_level := int(meta.get("unlock_level", 1))
	var unlock_label := Label.new()
	unlock_label.text = "해금: 계정 레벨 %d" % unlock_level
	unlock_label.add_theme_font_size_override("font_size", 11)
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(unlock_label)
	
	var desc = Label.new()
	desc.text = meta.get("desc", "")
	desc.add_theme_font_size_override("font_size", 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	var select_button := Button.new()
	select_button.text = "스킬 선택 / 장착"
	select_button.custom_minimum_size = Vector2(0, 38)
	select_button.disabled = GameData.player_level < unlock_level
	select_button.tooltip_text = (
		"스킬을 선택한 후 원하는 슬롯을 눌러 장착합니다."
		if not select_button.disabled
		else "계정 레벨 %d에 해금됩니다." % unlock_level
	)
	select_button.pressed.connect(_on_skill_selected.bind(key))
	vbox.add_child(select_button)
	
	var cost = meta.cost_base * lvl
	var up_btn = Button.new()
	up_btn.custom_minimum_size = Vector2(0, 42)
	if lvl >= 10:
		up_btn.text = "최대 레벨"
		up_btn.disabled = true
	else:
		up_btn.text = "강화 (💰%d)" % cost
		up_btn.disabled = (GameData.player_gold < cost)
		if GameData.player_gold < cost:
			var reason := Label.new()
			reason.text = "⛔ 골드 %d 부족" % (cost - GameData.player_gold)
			reason.add_theme_font_size_override("font_size", 11)
			reason.add_theme_color_override("font_color", Color(1.0, 0.58, 0.5))
			reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(reason)
	
	up_btn.pressed.connect(func(): _on_upgrade_skill(key))
	vbox.add_child(up_btn)
	
	return panel

func _on_upgrade_skill(key: String):
	if GameData.level_up_skill(key):
		feedback_label.text = "✨ 스킬이 성공적으로 강화되었습니다!"
		feedback_label.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
	else:
		feedback_label.text = "❌ 골드가 부족합니다!"
		feedback_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_refresh_ui()

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
