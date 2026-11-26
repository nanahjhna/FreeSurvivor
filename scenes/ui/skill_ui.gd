extends CanvasLayer

signal closed()

const CHARACTER_PORTRAIT := preload("res://scenes/ui/character_portrait.gd")

@onready var skill_cards_box: HBoxContainer = $Panel/Margin/VBox/SkillCardsScroll/CardsContainer
@onready var skill_cards_scroll: ScrollContainer = $Panel/Margin/VBox/SkillCardsScroll
@onready var feedback_label: Label = $Panel/Margin/VBox/FeedbackLabel
@onready var screen_vbox: VBoxContainer = $Panel/Margin/VBox

var selected_slot: String = "q"
var selected_skill: String = ""
var _slot_target_chosen: bool = false
var slot_buttons: Dictionary = {}
var loadout_hint: Label
var passive_info_label: Label
var skill_preview_panel: PanelContainer
var skill_preview: CHARACTER_PORTRAIT
var skill_preview_label: Label
var skill_slide_hint: Label
var skill_page_dots: Label
var _preview_skill_id := ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Panel.add_theme_stylebox_override("panel", UiStyle.frame(Color("#121214"), Color("#8f7650"), 8, 2))
	UiStyle.apply_button($Panel/Margin/VBox/Header/CloseBtn as Button)
	var portrait := UiStyle.fit_modal($Panel, Vector2(980, 1760))
	if portrait:
		var margin := $Panel/Margin as MarginContainer
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		$Panel/Margin/VBox/Header/CloseBtn.custom_minimum_size = Vector2(52, 48)
	_build_skill_preview()
	_build_loadout_controls()
	passive_info_label = UiStyle.make_label("", 13, Color(0.88, 0.83, 0.72))
	passive_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_vbox.add_child(passive_info_label)
	screen_vbox.move_child(passive_info_label, screen_vbox.get_child_count() - 1)
	screen_vbox.move_child(skill_preview_panel, 3)
	skill_slide_hint = UiStyle.make_label("← 좌우로 밀어 다른 스킬 보기 →", 13, UiStyle.MUTED)
	skill_slide_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_vbox.add_child(skill_slide_hint)
	screen_vbox.move_child(skill_slide_hint, 4)
	skill_page_dots = UiStyle.make_label("●  ○  ○  ○", 16, UiStyle.GOLD_BRIGHT)
	skill_page_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_vbox.add_child(skill_page_dots)
	screen_vbox.move_child(skill_page_dots, 6)
	GameData.data_updated.connect(_refresh_ui)
	GameData.skill_shop_updated.connect(_refresh_ui)
	get_viewport().size_changed.connect(_layout_skill_cards)
	skill_cards_scroll.get_h_scroll_bar().value_changed.connect(_on_skill_scroll_changed)

func open():
	visible = true
	selected_skill = ""
	_slot_target_chosen = false
	_preview_skill_id = ""
	feedback_label.text = ""
	_refresh_ui()
	if skill_preview:
		skill_preview.show_character(GameData.get_leader_id())
		skill_preview.set_portrait_active(true)

func close():
	if skill_preview:
		skill_preview.clear_clip_preview()
		skill_preview.set_portrait_active(false)
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
	if not keys.has(_preview_skill_id):
		_preview_skill_id = keys[0] if not keys.is_empty() else ""
	_set_skill_preview(_preview_skill_id)
	skill_cards_scroll.scroll_horizontal = 0
	_layout_skill_cards()
	_update_skill_page_dots()

func _build_skill_preview() -> void:
	skill_preview_panel = UiStyle.make_panel(Color("#171719"))
	var viewport_height := get_viewport().get_visible_rect().size.y
	var preview_height := clampf(viewport_height * 0.32, 360.0, 620.0)
	skill_preview_panel.custom_minimum_size = Vector2(0, preview_height)
	skill_preview_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	skill_preview_panel.clip_contents = true
	skill_preview_panel.add_theme_stylebox_override("panel", UiStyle.frame(Color("#171719"), Color("#8f7650"), 8, 3))
	var margin := UiStyle.make_margin(skill_preview_panel, 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	skill_preview_label = UiStyle.make_title("애니메이션 미리보기", 24)
	skill_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(skill_preview_label)
	skill_preview = CHARACTER_PORTRAIT.new()
	skill_preview.custom_minimum_size = Vector2(0, preview_height - 48.0)
	skill_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(skill_preview)
	screen_vbox.add_child(skill_preview_panel)

func _layout_skill_cards() -> void:
	if skill_cards_box == null:
		return
	var available_width := skill_cards_scroll.size.x
	if available_width <= 0.0:
		available_width = get_viewport().get_visible_rect().size.x - 72.0
	var card_width := clampf(available_width - 8.0, 260.0, 900.0)
	for card in skill_cards_box.get_children():
		(card as Control).custom_minimum_size.x = card_width

func _on_skill_scroll_changed(value: float) -> void:
	if not visible or skill_cards_box.get_child_count() == 0:
		return
	var available_width := skill_cards_scroll.size.x
	if available_width <= 0.0:
		available_width = get_viewport().get_visible_rect().size.x - 72.0
	var card_width := clampf(available_width - 8.0, 260.0, 900.0)
	var index := clampi(roundi(value / (card_width + 12.0)), 0, skill_cards_box.get_child_count() - 1)
	var card := skill_cards_box.get_child(index) as Control
	if card == null:
		return
	var skill_id := str(card.get_meta("skill_id", ""))
	if skill_id != _preview_skill_id:
		_preview_skill_id = skill_id
		_set_skill_preview(skill_id)
	_update_skill_page_dots()

func _update_skill_page_dots() -> void:
	if skill_page_dots == null:
		return
	var count := skill_cards_box.get_child_count()
	if count <= 0:
		skill_page_dots.text = ""
		return
	var active := 0
	for index in range(count):
		var card := skill_cards_box.get_child(index) as Control
		if card != null and str(card.get_meta("skill_id", "")) == _preview_skill_id:
			active = index
			break
	var dots := PackedStringArray()
	for index in range(count):
		dots.append("●" if index == active else "○")
	skill_page_dots.text = "  ".join(dots)

func _set_skill_preview(skill_id: String) -> void:
	if skill_preview == null:
		return
	if skill_id.is_empty():
		skill_preview_label.text = "표시할 액티브 스킬이 없습니다."
		skill_preview.clear_clip_preview()
		return
	var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
	skill_preview_label.text = "%s  ·  애니메이션 미리보기" % str(meta.get("name", "스킬"))
	skill_preview.show_character(GameData.get_leader_id())
	skill_preview.set_portrait_active(true)
	if not skill_preview.preview_skill(skill_id):
		skill_preview_label.text = "%s  ·  애니메이션 준비 중" % str(meta.get("name", "스킬"))

func _on_skill_preview_requested(skill_id: String) -> void:
	_preview_skill_id = skill_id
	_set_skill_preview(skill_id)

func _build_loadout_controls():
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "스킬 선택 → 장착할 슬롯 누르기"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var slots := GridContainer.new()
	slots.columns = 4
	slots.add_theme_constant_override("h_separation", 8)
	slots.add_theme_constant_override("v_separation", 8)
	row.add_child(slots)
	for slot in ["q", "w", "e", "r"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 76)
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
		var slot_number := ["q", "w", "e", "r"].find(str(slot)) + 1
		button.text = "%d\n%s %s" % [slot_number, str(meta.get("icon", "—")), str(meta.get("name", "빈 슬롯"))]
		button.button_pressed = str(slot) == selected_slot
		button.add_theme_font_size_override("font_size", 14)
		UiStyle.skin_button(button, Color("#3a2020") if button.button_pressed else Color("#242326"), UiStyle.GOLD_BRIGHT if button.button_pressed else Color("#655b50"))
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
	var panel := UiStyle.make_panel(Color("#1b1b1d"))
	panel.set_meta("skill_id", key)
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.y >= viewport_size.x
	var compact_row := portrait
	var card_width := maxf(132.0, (viewport_size.x - 64.0) / 2.0)
	panel.custom_minimum_size = Vector2(card_width, 480) if compact_row else Vector2(420, 520)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", UiStyle.frame(Color("#1b1b1d"), Color("#8d2929"), 8, 3))
	
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
	icon.add_theme_font_size_override("font_size", 48 if compact_row else 66)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon)
	
	var name_lbl = Label.new()
	name_lbl.text = meta.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 24 if compact_row else 30)
	name_lbl.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	
	var lvl_lbl = Label.new()
	lvl_lbl.text = "임시 레벨 %d" % lvl
	lvl_lbl.add_theme_font_size_override("font_size", 16 if compact_row else 18)
	lvl_lbl.add_theme_color_override("font_color", UiStyle.IVORY)
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
	stats.add_theme_font_size_override("font_size", 18 if compact_row else 21)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)
	var unlock_level := int(meta.get("unlock_level", 1))
	var unlock_label := Label.new()
	unlock_label.text = "스테이지 시작 시 습득" if unlock_level == 1 else "서바이벌 Lv.%d에 습득" % unlock_level
	unlock_label.add_theme_font_size_override("font_size", 14 if compact_row else 16)
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(unlock_label)
	
	var desc = Label.new()
	desc.text = meta.get("desc", "")
	desc.add_theme_font_size_override("font_size", 17 if compact_row else 19)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	var select_button := Button.new()
	select_button.text = "스킬 선택"
	select_button.custom_minimum_size = Vector2(0, 52 if compact_row else 58)
	select_button.disabled = false
	select_button.tooltip_text = "스킬을 선택한 후 원하는 슬롯을 눌러 장착합니다."
	UiStyle.apply_button(select_button, true)
	select_button.pressed.connect(_on_skill_selected.bind(key))
	vbox.add_child(select_button)
	var preview_button := Button.new()
	preview_button.text = "애니메이션 보기"
	preview_button.custom_minimum_size = Vector2(0, 46 if compact_row else 52)
	preview_button.tooltip_text = "선택한 캐릭터가 이 스킬 동작을 반복 재생합니다."
	UiStyle.apply_button(preview_button)
	preview_button.pressed.connect(_on_skill_preview_requested.bind(key))
	vbox.add_child(preview_button)
	
	return panel

func _on_upgrade_skill(key: String):
	feedback_label.text = "스킬 강화는 서바이벌 스테이지의 레벨업 카드에서 획득합니다."

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
