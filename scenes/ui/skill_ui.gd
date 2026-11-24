extends CanvasLayer

signal closed()

@onready var skill_cards_box: GridContainer = $Panel/Margin/VBox/CardsContainer
@onready var feedback_label: Label = $Panel/Margin/VBox/FeedbackLabel
@onready var screen_vbox: VBoxContainer = $Panel/Margin/VBox

var selected_slot: String = "q"
var selected_skill: String = ""
var _slot_target_chosen: bool = false
var slot_buttons: Dictionary = {}
var loadout_hint: Label
var passive_info_label: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	UiStyle.apply_button($Panel/Margin/VBox/Header/CloseBtn as Button)
	var portrait := UiStyle.fit_modal($Panel, Vector2(980, 1160))
	if portrait:
		var margin := $Panel/Margin as MarginContainer
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		$Panel/Margin/VBox/Header/CloseBtn.custom_minimum_size = Vector2(52, 48)
		skill_cards_box.columns = 2
		skill_cards_box.add_theme_constant_override("h_separation", 8)
		skill_cards_box.add_theme_constant_override("v_separation", 8)
	else:
		skill_cards_box.columns = 4
	_build_loadout_controls()
	passive_info_label = UiStyle.make_label("", 13, Color(0.88, 0.83, 0.72))
	passive_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_vbox.add_child(passive_info_label)
	screen_vbox.move_child(passive_info_label, 2)
	GameData.data_updated.connect(_refresh_ui)
	GameData.skill_shop_updated.connect(_refresh_ui)

func open():
	visible = true
	selected_skill = ""
	_slot_target_chosen = false
	feedback_label.text = ""
	_refresh_ui()

func close():
	visible = false
	closed.emit()

func _refresh_ui():
	if not visible:
		return
	for child in skill_cards_box.get_children():
		skill_cards_box.remove_child(child)
		child.queue_free()
	if not GameData.is_combat_skill_owned(selected_skill):
		selected_skill = ""
	var passive: Dictionary = {}
	for skill_id in GameData.skill_meta:
		if GameData.is_combat_skill_owned(skill_id) and str(GameData.skill_meta[skill_id].get("cast_type", "")) == "passive":
			passive = GameData.skill_meta[skill_id]
			break
	passive_info_label.visible = not passive.is_empty()
	passive_info_label.text = "패시브 · %s: %s" % [str(passive.get("name", "")), str(passive.get("desc", ""))]
	_update_loadout_controls()
	var keys: Array[String] = []
	for skill_id in GameData.skill_meta:
		if GameData.is_combat_skill_owned(skill_id) and str(GameData.skill_meta[skill_id].get("cast_type", "")) != "passive":
			keys.append(str(skill_id))
	for k in keys:
		var meta = GameData.skill_meta[k]
		var cur_lvl = GameData.skill_levels.get(k, 1)
		var card = _create_skill_card(k, meta, cur_lvl)
		skill_cards_box.add_child(card)

func _build_loadout_controls():
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "스킬 선택 → 장착할 슬롯 누르기"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var slots := GridContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.y >= viewport_size.x
	slots.columns = 4 if not portrait or viewport_size.x >= 600.0 else 2
	slots.add_theme_constant_override("h_separation", 8)
	slots.add_theme_constant_override("v_separation", 8)
	row.add_child(slots)
	for slot in ["q", "w", "e", "r", "a", "s"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiStyle.apply_button(button)
		button.toggle_mode = true
		button.pressed.connect(_on_loadout_slot_pressed.bind(slot))
		slot_buttons[slot] = button
		slots.add_child(button)
	screen_vbox.add_child(row)
	loadout_hint = Label.new()
	loadout_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_vbox.add_child(loadout_hint)

func _update_loadout_controls():
	for slot in slot_buttons:
		var skill_id := GameData.get_equipped_skill(str(slot))
		var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
		var button: Button = slot_buttons[slot]
		button.text = "%s: %s %s" % [str(slot).to_upper(), str(meta.get("icon", "—")), str(meta.get("name", "빈 슬롯"))]
		button.button_pressed = str(slot) == selected_slot
		button.tooltip_text = "현재 장착: %s. 선택한 스킬을 장착하거나 교체합니다." % str(meta.get("name", ""))
	loadout_hint.visible = not selected_skill.is_empty() or _slot_target_chosen
	if not selected_skill.is_empty():
		loadout_hint.text = "%s를 넣을 슬롯을 누르세요" % str(GameData.skill_meta.get(selected_skill, {}).get("name", "스킬"))
	elif _slot_target_chosen:
		loadout_hint.text = "%s에 넣을 스킬을 고르세요" % selected_slot.to_upper()

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
	if not GameData.is_combat_skill_owned(skill_id):
		return
	selected_skill = skill_id
	if _slot_target_chosen:
		_on_loadout_slot_pressed(selected_slot)
		return
	feedback_label.text = ""
	_update_loadout_controls()

func _create_skill_card(key: String, meta: Dictionary, lvl: int) -> PanelContainer:
	var panel := UiStyle.make_panel(Color(0.055, 0.03, 0.027, 0.98))
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.y >= viewport_size.x
	var compact_row := portrait
	var card_width := maxf(132.0, (viewport_size.x - 64.0) / 2.0)
	panel.custom_minimum_size = Vector2(card_width, 290) if compact_row else Vector2(210, 360)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.055, 0.03, 0.027, 0.98), Color(0.62, 0.42, 0.23, 0.86), 1))
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8 if compact_row else 14)
	margin.add_theme_constant_override("margin_top", 10 if compact_row else 16)
	margin.add_theme_constant_override("margin_right", 8 if compact_row else 14)
	margin.add_theme_constant_override("margin_bottom", 10 if compact_row else 16)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6 if compact_row else 12)
	margin.add_child(vbox)
	
	var icon = Label.new()
	icon.text = meta.get("icon", "⚡")
	icon.add_theme_font_size_override("font_size", 31 if compact_row else 42)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon)
	
	var name_lbl = Label.new()
	name_lbl.text = meta.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 14 if compact_row else 17)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	
	var lvl_lbl = Label.new()
	lvl_lbl.text = "임시 레벨 " + str(lvl)
	lvl_lbl.add_theme_font_size_override("font_size", 11 if compact_row else 13)
	lvl_lbl.add_theme_color_override("font_color", UiStyle.GOLD)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lvl_lbl)
	
	var cd = max(0.5, meta.base_cd - (meta.cd_step * (lvl - 1)))
	var dmg = meta.base_dmg_ratio + (meta.dmg_step * (lvl - 1))
	var stats = Label.new()
	stats.text = "재사용 %.1f초" % cd
	if str(meta.get("cast_type", "")) == "heal":
		stats.text += "\n최대 HP의 %.0f%% 회복" % (float(meta.get("heal_ratio", 0.2)) * 100.0)
	else:
		var power := "마법 공격력" if bool(meta.get("uses_magic_power", false)) else "물리 공격력"
		stats.text += "\n%s × %.2f\n사거리 %.1fm" % [power, dmg, float(meta.get("range", 0.0))]
	stats.add_theme_font_size_override("font_size", 14)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)
	var unlock_level := int(meta.get("unlock_level", 1))
	var unlock_label := Label.new()
	unlock_label.text = "스테이지 시작 시 습득" if unlock_level == 1 else "서바이벌 Lv.%d에 습득" % unlock_level
	unlock_label.add_theme_font_size_override("font_size", 9 if compact_row else 11)
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(unlock_label)
	
	var desc = Label.new()
	desc.text = meta.get("desc", "")
	desc.add_theme_font_size_override("font_size", 10 if compact_row else 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	var select_button := Button.new()
	select_button.text = "스킬 선택"
	select_button.custom_minimum_size = Vector2(0, 34 if compact_row else 38)
	select_button.disabled = false
	select_button.tooltip_text = "스킬을 선택한 후 원하는 슬롯을 눌러 장착합니다."
	UiStyle.apply_button(select_button)
	select_button.pressed.connect(_on_skill_selected.bind(key))
	vbox.add_child(select_button)
	
	return panel

func _on_upgrade_skill(key: String):
	feedback_label.text = "스킬 강화는 서바이벌 스테이지의 레벨업 카드에서 획득합니다."

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
