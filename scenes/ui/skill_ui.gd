extends CanvasLayer

const REFERENCE_SCREEN := preload("res://scripts/reference_screen.gd")

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
var _approved: REFERENCE_SCREEN
var _swipe_start := Vector2.INF

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Panel.add_theme_stylebox_override("panel", UiStyle.art_panel(UiStyle.RUST, Vector2(2, 2)))
	$Backdrop.color = UiStyle.SCRIM
	$Panel/Margin/VBox/Header/Title.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	UiStyle.apply_button($Panel/Margin/VBox/Header/CloseBtn as Button)
	$Panel/Margin/VBox/Header/CloseBtn.custom_minimum_size = Vector2(58, 54)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var header := $Panel/Margin/VBox/Header as HBoxContainer
	var board := UiStyle.notice_board()
	screen_vbox.add_child(board)
	screen_vbox.move_child(board, 0)
	header.reparent(board, false)
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
	get_viewport().size_changed.connect(_fit_layout)
	skill_cards_scroll.resized.connect(_layout_skill_cards)
	skill_cards_scroll.get_h_scroll_bar().value_changed.connect(_on_skill_scroll_changed)
	_fit_layout()

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
	if _approved == null:
		_build_approved_skills()
	$Panel.hide()


func _build_approved_skills() -> void:
	_approved = REFERENCE_SCREEN.new()
	var screen := _approved
	screen.build(self, "skills")
	screen.hit(Rect2(482, 27, 56, 55), "닫기", close)
	screen.smithy(Rect2(0, 89, 552, 291), Rect2(171, 90, 225, 287))
	screen.native(skill_preview, Rect2(89, 92, 374, 283))
	skill_preview.set_framing(3.0, 1.20, 2.6)
	skill_preview.stretch_shrink = 1 if not OS.has_feature("android") else 2
	var swipe := Control.new()
	swipe.mouse_filter = Control.MOUSE_FILTER_STOP
	swipe.gui_input.connect(_on_approved_skill_swipe)
	screen.page.add_child(swipe)
	screen.place(swipe, Rect2(78, 90, 396, 289))
	screen.styled_button(Rect2(22, 215, 50, 62), "‹", _change_approved_skill.bind(-1))
	screen.styled_button(Rect2(480, 215, 50, 62), "›", _change_approved_skill.bind(1))
	screen.field(Rect2(40, 410, 98, 92), func(): return _approved_skill_value("icon"), 61, HORIZONTAL_ALIGNMENT_CENTER, Color("#2e241e"))
	screen.field(Rect2(169, 394, 350, 41), func(): return _approved_skill_value("name"), 32)
	for index in range(3):
		var key: String = ["cooldown", "ratio", "range"][index]
		screen.field(Rect2(166 + index * 122, 475, 109, 37), _approved_skill_value.bind(key), 27, HORIZONTAL_ALIGNMENT_CENTER)
	var formula := screen.field(Rect2(81, 539, 437, 46), _approved_skill_value.bind("damage"), 20, HORIZONTAL_ALIGNMENT_CENTER)
	formula.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	formula.max_lines_visible = 2
	var slot_feedback := screen.field(Rect2(144, 606, 261, 38), func():
		if feedback_label.text.is_empty():
			return "장착할 슬롯 선택"
		return feedback_label.text
	, 22, HORIZONTAL_ALIGNMENT_CENTER, Color("#221d18"))
	slot_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_feedback.max_lines_visible = 2
	for index in range(4):
		var slot: String = ["q", "w", "e", "r"][index]
		var rect := Rect2(34 + index * 126, 666, 96, 82)
		screen.field(Rect2(rect.position, Vector2(rect.size.x, 46)), func():
			var equipped: Dictionary = GameData.skill_meta.get(GameData.get_equipped_skill(slot), {})
			return str(equipped.get("icon", "—"))
		, 39, HORIZONTAL_ALIGNMENT_CENTER)
		screen.solid(Rect2(rect.position + Vector2(0, 46), Vector2(rect.size.x, 36)), Color("#241d18"))
		screen.text(Rect2(rect.position + Vector2(0, 46), Vector2(rect.size.x, 17)), slot.to_upper(), 14, HORIZONTAL_ALIGNMENT_CENTER)
		screen.live_text(Rect2(rect.position + Vector2(0, 61), Vector2(rect.size.x, 20)), _approved_slot_damage.bind(slot), 17, HORIZONTAL_ALIGNMENT_CENTER, REFERENCE_SCREEN.AMBER)
		var touch := screen.hit(Rect2(rect.position.x - 1, 653, 118, 138), "%s 슬롯" % slot.to_upper(), _on_loadout_slot_pressed.bind(slot))
		var highlight := UiStyle.frame(Color.TRANSPARENT, UiStyle.AMBER, 9, 3)
		highlight.shadow_size = 0
		screen.updates.append(func():
			if selected_slot == slot and _slot_target_chosen:
				touch.add_theme_stylebox_override("normal", highlight)
			elif touch.get_theme_stylebox("normal") == highlight:
				touch.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		)
	# The approved artwork already contains the CTA label. Drawing a second
	# live label here caused "스킬 선택" to render twice and overlap.
	screen.hit(Rect2(18, 807, 518, 90), "스킬 선택", func(): _on_skill_selected(_preview_skill_id))
	var passive := screen.live_text(Rect2(21, 899, 509, 32), func():
		return passive_info_label.text if passive_info_label.visible else ""
	, 16, HORIZONTAL_ALIGNMENT_CENTER)
	var passive_help := screen.hit(Rect2(20, 898, 512, 34), "패시브 설명", func():
		UiFeedback.show_reward("패시브 스킬", [passive_info_label.text])
	)
	screen.updates.append(func(): passive_help.visible = not passive.text.is_empty())


func _change_approved_skill(step: int) -> void:
	var cards := skill_cards_box.get_children()
	if cards.size() <= 1:
		return
	for index in range(cards.size()):
		if str(cards[index].get_meta("skill_id", "")) == _preview_skill_id:
			_preview_skill_id = str(cards[posmod(index + step, cards.size())].get_meta("skill_id"))
			_set_skill_preview(_preview_skill_id)
			feedback_label.text = ""
			return


func _on_approved_skill_swipe(event: InputEvent) -> void:
	var touch: bool = event is InputEventScreenTouch and event.index == 0
	var mouse: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	if not touch and not mouse:
		return
	if event.pressed:
		_swipe_start = event.position
	elif _swipe_start != Vector2.INF:
		var displacement: Vector2 = event.position - _swipe_start
		_swipe_start = Vector2.INF
		if absf(displacement.x) >= 55.0 and absf(displacement.x) > absf(displacement.y):
			_change_approved_skill(1 if displacement.x < 0.0 else -1)


func _approved_skill_value(key: String) -> String:
	var meta: Dictionary = GameData.skill_meta.get(_preview_skill_id, {})
	if meta.is_empty():
		return "—"
	var level := int(GameData.skill_levels.get(_preview_skill_id, 1))
	match key:
		"icon", "name": return str(meta.get(key, "—"))
		"cooldown": return "%.1f초" % maxf(0.5, float(meta.base_cd) - float(meta.cd_step) * (level - 1))
		"ratio": return "×%.2f" % (float(meta.base_dmg_ratio) + float(meta.dmg_step) * (level - 1))
		"range": return "%.1fm" % float(meta.get("range", 0.0))
		"damage": return _damage_summary_text(meta, level).replace("피해 공식: ", "").replace(" 공격력", "")
	return "—"

func _approved_slot_damage(slot: String) -> String:
	var skill_id := GameData.get_equipped_skill(slot)
	var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
	if meta.is_empty():
		return "—"
	var level := int(GameData.skill_levels.get(skill_id, 1))
	if str(meta.get("cast_type", "")) == "heal":
		return "회복 %.0f%%" % (float(meta.get("heal_ratio", 0.2)) * 100.0)
	var stats := GameData.get_character_stat_manager(GameData.get_leader_id())
	var base_power := stats.mag_atk() if bool(meta.get("uses_magic_power", false)) else stats.phys_atk()
	var power := base_power * GameData.attack_damage_mult
	var ratio := float(meta.get("base_dmg_ratio", 0.0)) + float(meta.get("dmg_step", 0.0)) * float(level - 1)
	var multiplier := _preview_skill_bonus_multiplier(meta)
	var sequence := PackedFloat32Array(meta.get("effect_sequence_damage_ratios", PackedFloat32Array()))
	var damage := power * ratio * multiplier
	if not sequence.is_empty():
		var base_ratio := maxf(0.001, float(meta.get("base_dmg_ratio", 1.0)))
		var total_ratio := 0.0
		for hit_ratio in sequence:
			total_ratio += float(hit_ratio) * ratio / base_ratio
		damage = power * total_ratio * multiplier
	return "%.0f" % damage

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
	skill_preview_panel = UiStyle.make_panel(UiStyle.ASPHALT)
	skill_preview_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	skill_preview_panel.clip_contents = true
	skill_preview_panel.add_theme_stylebox_override("panel", UiStyle.art_panel())
	var margin := UiStyle.make_margin(skill_preview_panel, 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	skill_preview_label = UiStyle.make_title("애니메이션 미리보기", 24)
	skill_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(skill_preview_label)
	skill_preview = CHARACTER_PORTRAIT.new()
	skill_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(skill_preview)
	skill_preview.set_framing(3.35, 1.35, 2.2)
	screen_vbox.add_child(skill_preview_panel)

func _fit_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UiStyle.safe_insets(get_viewport())
	var portrait := UiStyle.fit_modal($Panel, Vector2(900, 1760),
		Vector2(16 + maxf(safe.x, safe.z), 20 + maxf(safe.y, safe.w)))
	var margin := $Panel/Margin as MarginContainer
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14 if portrait else 20)
	screen_vbox.add_theme_constant_override("separation", 8 if portrait else 12)
	var usable_height := viewport_size.y - safe.y - safe.w
	skill_preview_panel.custom_minimum_size.y = clampf(usable_height * 0.25, 120.0, 350.0)
	skill_cards_scroll.custom_minimum_size.y = 126
	_layout_skill_cards()

func _layout_skill_cards() -> void:
	if skill_cards_box == null:
		return
	var available_width := skill_cards_scroll.size.x
	if available_width <= 0.0:
		available_width = get_viewport().get_visible_rect().size.x - 72.0
	var card_width := _skill_card_width(available_width)
	for card in skill_cards_box.get_children():
		(card as Control).custom_minimum_size.x = card_width
		var heading := card.get_meta("heading") as BoxContainer
		heading.vertical = card_width < 520.0

func _on_skill_scroll_changed(value: float) -> void:
	if not visible or skill_cards_box.get_child_count() == 0:
		return
	var available_width := skill_cards_scroll.size.x
	if available_width <= 0.0:
		available_width = get_viewport().get_visible_rect().size.x - 72.0
	var card_width := _skill_card_width(available_width)
	var index := clampi(roundi(value / (card_width + 12.0)), 0, skill_cards_box.get_child_count() - 1)
	var card := skill_cards_box.get_child(index) as Control
	if card == null:
		return
	var skill_id := str(card.get_meta("skill_id", ""))
	if skill_id != _preview_skill_id:
		_preview_skill_id = skill_id
		_set_skill_preview(skill_id)
	_update_skill_page_dots()

func _skill_card_width(available_width: float) -> float:
	return maxf(1.0, available_width - 30.0)

func _update_skill_page_dots() -> void:
	if skill_page_dots == null:
		return
	var count := skill_cards_box.get_child_count()
	skill_slide_hint.visible = count > 1
	skill_page_dots.visible = count > 1
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
	var plate := UiStyle.notice_board()
	screen_vbox.add_child(plate)
	var row := VBoxContainer.new()
	plate.add_child(row)
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
	loadout_hint = Label.new()
	loadout_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loadout_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_vbox.add_child(loadout_hint)

func _update_loadout_controls():
	for slot in slot_buttons:
		var skill_id := GameData.get_equipped_skill(str(slot))
		var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
		var button: Button = slot_buttons[slot]
		button.text = "%s\n%s" % [str(meta.get("icon", "—")), str(slot).to_upper()]
		button.button_pressed = str(slot) == selected_slot
		button.add_theme_font_size_override("font_size", 21)
		UiStyle.skin_button(button, UiStyle.SELECTED if button.button_pressed else UiStyle.INK_SOFT,
			UiStyle.AMBER if button.button_pressed else UiStyle.STEEL, UiStyle.IVORY)
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
	var panel := UiStyle.make_panel(UiStyle.INK_SOFT)
	panel.set_meta("skill_id", key)
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.y >= viewport_size.x
	var compact_row := portrait
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", UiStyle.art_panel())
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8 if compact_row else 14)
	margin.add_theme_constant_override("margin_top", 10 if compact_row else 16)
	margin.add_theme_constant_override("margin_right", 8 if compact_row else 14)
	margin.add_theme_constant_override("margin_bottom", 10 if compact_row else 16)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6 if compact_row else 12)
	margin.add_child(vbox)
	
	var heading := BoxContainer.new()
	panel.set_meta("heading", heading)
	heading.add_theme_constant_override("separation", 6)
	vbox.add_child(heading)
	var identity_row := HBoxContainer.new()
	identity_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_row.add_theme_constant_override("separation", 8)
	heading.add_child(identity_row)
	identity_row.add_child(UiStyle.plaque(str(meta.get("icon", "⚡")), UiStyle.SELECTED, UiStyle.RUST, UiStyle.IVORY, 30))
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 1)
	identity_row.add_child(identity)
	var name_lbl := UiStyle.make_title(str(meta.get("name", "")), 22 if compact_row else 25)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(name_lbl)
	identity.add_child(UiStyle.make_label("임시 Lv.%d" % lvl, 12 if compact_row else 14, UiStyle.MUTED))

	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 3)
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(metrics)
	var cd = max(0.5, meta.base_cd - (meta.cd_step * (lvl - 1)))
	var dmg = meta.base_dmg_ratio + (meta.dmg_step * (lvl - 1))
	UiStyle.metric(metrics, "재사용", "%.1f초" % cd)
	if str(meta.get("cast_type", "")) == "heal":
		UiStyle.metric(metrics, "최대 HP 회복", "%.0f%%" % (float(meta.get("heal_ratio", 0.2)) * 100.0))
	else:
		UiStyle.metric(metrics, "계수", "× %.2f" % dmg)
		UiStyle.metric(metrics, "사거리", "%.1fm" % float(meta.get("range", 0.0)))
	var damage_summary := UiStyle.make_label(_damage_summary_text(meta, lvl), 15 if compact_row else 18, UiStyle.GOLD_BRIGHT)
	damage_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	damage_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var formula := UiStyle.make_panel(UiStyle.ASPHALT)
	UiStyle.make_margin(formula, 8).add_child(damage_summary)
	vbox.add_child(formula)
	UiStyle.divider(vbox)
	var unlock_level := int(meta.get("unlock_level", 1))
	var unlock_label := Label.new()
	unlock_label.text = "스테이지 시작 시 습득" if unlock_level == 1 else "서바이벌 Lv.%d에 습득" % unlock_level
	unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	select_button.add_theme_font_size_override("font_size", 21)
	select_button.pressed.connect(_on_skill_selected.bind(key))
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(select_button)
	
	return panel

func _damage_summary_text(meta: Dictionary, lvl: int) -> String:
	if str(meta.get("cast_type", "")) == "heal":
		return "최대 HP의 %.0f%% 회복" % (float(meta.get("heal_ratio", 0.2)) * 100.0)
	var stats := GameData.get_character_stat_manager(GameData.get_leader_id())
	var uses_magic := bool(meta.get("uses_magic_power", false))
	var base_power := stats.mag_atk() if uses_magic else stats.phys_atk()
	var effective_power := base_power * GameData.attack_damage_mult
	var current_ratio := float(meta.get("base_dmg_ratio", 0.0)) + float(meta.get("dmg_step", 0.0)) * float(lvl - 1)
	var damage_multiplier := _preview_skill_bonus_multiplier(meta)
	var sequence := PackedFloat32Array(meta.get("effect_sequence_damage_ratios", PackedFloat32Array()))
	var power_name := "마법 공격력" if uses_magic else "물리 공격력"

	if sequence.size() > 0:
		var base_ratio := maxf(0.001, float(meta.get("base_dmg_ratio", 1.0)))
		var sequence_total := 0.0
		var ratio_text := PackedStringArray()
		for ratio in sequence:
			var resolved_ratio := float(ratio) * current_ratio / base_ratio
			sequence_total += resolved_ratio
			ratio_text.append("%.2f" % resolved_ratio)
		var total_damage := effective_power * sequence_total * damage_multiplier
		var bonus_text := " × 보너스 %.2f" % damage_multiplier if not is_equal_approx(damage_multiplier, 1.0) else ""
		return "%d회 · 피해 공식: %s %.1f × 계수(%s)%s = 총 %.1f" % [
			sequence.size(), power_name, effective_power, " / ".join(ratio_text), bonus_text, total_damage
		]

	var total_damage := effective_power * current_ratio * damage_multiplier
	var bonus_text := " × 보너스 %.2f" % damage_multiplier if not is_equal_approx(damage_multiplier, 1.0) else ""
	return "피해 공식: %s %.1f × %.2f%s = %.1f" % [
		power_name, effective_power, current_ratio, bonus_text, total_damage
	]

func _preview_skill_bonus_multiplier(meta: Dictionary) -> float:
	var multiplier := 1.0
	multiplier += GameData.get_survival_bonus("damage")
	multiplier += GameData.get_survival_bonus("damage_reckless")
	multiplier += GameData.get_survival_bonus("skill_damage")
	if bool(meta.get("uses_magic_power", false)):
		multiplier += GameData.get_survival_bonus("magic_damage")
	else:
		multiplier += GameData.get_survival_bonus("physical_damage")
	if str(meta.get("bonus_type", "")) == "fire":
		multiplier += GameData.get_survival_bonus("fire_damage")
	if str(meta.get("bonus_type", "")) == "area":
		multiplier += GameData.get_survival_bonus("area_damage")
	return multiplier

func _on_upgrade_skill(key: String):
	feedback_label.text = "스킬 강화는 서바이벌 스테이지의 레벨업 카드에서 획득합니다."

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
