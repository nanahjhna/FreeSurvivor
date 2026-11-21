extends CanvasLayer

signal closed()

@onready var detail_panel: Control = $Panel/Margin/VBox/Body/RightDetail

# Detail views
@onready var name_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/Header/TextInfo/TopRow/NameLabel
@onready var title_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/Header/TextInfo/TitleLabel
@onready var grade_badge: Label = $Panel/Margin/VBox/Body/RightDetail/Content/Header/TextInfo/TopRow/GradeBadge
@onready var icon_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/Header/Portrait/IconLabel

@onready var level_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/StatsGrid/LevelVal
@onready var hp_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/StatsGrid/HPVal
@onready var atk_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/StatsGrid/ATKVal
@onready var def_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/StatsGrid/DEFVal
@onready var spd_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/StatsGrid/SPDVal

@onready var skill_title: Label = $Panel/Margin/VBox/Body/RightDetail/Content/SkillBox/SkillTitle
@onready var desc_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/DescLabel
@onready var detail_content: VBoxContainer = $Panel/Margin/VBox/Body/RightDetail/Content
@onready var feedback_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/Actions/FeedbackLabel

var selected_char_id := GameData.FIGHTER_ID
var attribute_buttons: GridContainer
var gold_label: Label
var detail_toggle_button: Button
var stat_value_labels: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var portrait := UiStyle.fit_modal($Panel, Vector2(680, 1080))
	$Panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	detail_panel.add_theme_stylebox_override("panel", UiStyle.sub_panel_style())
	UiStyle.apply_button($Panel/Margin/VBox/Header/CloseBtn as Button)
	if portrait:
		var margin := $Panel/Margin as MarginContainer
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		$Panel/Margin/VBox/Body.add_theme_constant_override("separation", 8)
		$Panel/Margin/VBox/Header/CloseBtn.custom_minimum_size = Vector2(52, 48)
	_wrap_detail_in_scroll()
	_prepare_simple_layout()
	_build_stat_controls()
	GameData.data_updated.connect(_refresh_ui)

func open():
	visible = true
	feedback_label.text = ""
	_refresh_ui()

func close():
	visible = false
	closed.emit()

func _refresh_ui():
	selected_char_id = GameData.get_leader_id()
	_update_detail(selected_char_id)

func _update_detail(cid: String):
	if not GameData.characters.has(cid):
		return
	var c = GameData.characters[cid]
	var stats := GameData.get_character_stat_manager(cid)
	name_label.text = c.get("name", "")
	title_label.text = c.get("title", "")
	grade_badge.text = " " + c.get("grade", "R") + " • " + c.get("role", "") + " "
	icon_label.text = c.get("icon", "⚔️")
	gold_label.text = "💰 %d 골드" % GameData.player_gold
	
	hp_label.text = str(int(stats.max_hp()))
	atk_label.text = str(int(stats.phys_atk()))
	def_label.text = str(int(stats.phys_def()))
	_refresh_attribute_controls(c, stats)
	
	skill_title.text = "대표 스킬: " + c.get("signature_skill", "")
	desc_label.text = c.get("desc", "")
	

func _prepare_simple_layout():
	var top_row := name_label.get_parent() as HBoxContainer
	gold_label = Label.new()
	gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.3))
	gold_label.add_theme_font_size_override("font_size", 16)
	top_row.add_child(gold_label)
	var stats_grid := hp_label.get_parent() as GridContainer
	stats_grid.columns = 2
	detail_content.get_node("StatsGrid/LevelLbl").visible = false
	level_label.visible = false
	detail_content.get_node("StatsGrid/SPDLbl").visible = false
	spd_label.visible = false
	detail_content.get_node("Spacer").visible = false
	detail_content.get_node("Actions").visible = false
	detail_content.get_node("SkillBox").visible = false
	desc_label.visible = false

func _build_stat_controls():
	var section := VBoxContainer.new()
	section.name = "DirectStatGrowth"
	section.add_theme_constant_override("separation", 8)
	var section_title := Label.new()
	section_title.text = "능력치 강화"
	section_title.add_theme_font_size_override("font_size", 18)
	section_title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	section.add_child(section_title)
	attribute_buttons = GridContainer.new()
	attribute_buttons.columns = 1
	attribute_buttons.add_theme_constant_override("h_separation", 10)
	attribute_buttons.add_theme_constant_override("v_separation", 8)
	section.add_child(attribute_buttons)
	feedback_label.get_parent().remove_child(feedback_label)
	feedback_label.custom_minimum_size = Vector2(0, 24)
	section.add_child(feedback_label)
	detail_content.add_child(section)
	detail_content.move_child(section, detail_content.get_node("SkillBox").get_index())
	detail_toggle_button = Button.new()
	detail_toggle_button.text = "상세 정보 보기"
	detail_toggle_button.custom_minimum_size = Vector2(0, 42)
	UiStyle.apply_button(detail_toggle_button)
	detail_toggle_button.pressed.connect(_toggle_character_details)
	detail_content.add_child(detail_toggle_button)
	detail_content.move_child(detail_toggle_button, detail_content.get_node("SkillBox").get_index())

func _refresh_attribute_controls(character: Dictionary, stats: StatManager):
	stat_value_labels.clear()
	for child in attribute_buttons.get_children():
		child.queue_free()
	for stat_name in StatManager.STAT_KEYS:
		var value := stats.get_stat(stat_name)
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", UiStyle.sub_panel_style())
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attribute_buttons.add_child(row_panel)
		var row_margin := UiStyle.make_margin(row_panel, 8)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_margin.add_child(row)
		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_theme_constant_override("separation", 2)
		row.add_child(identity)
		var stat_label := UiStyle.make_label(stat_name, 17, Color(0.96, 0.97, 1.0))
		identity.add_child(stat_label)
		var effect_label := UiStyle.make_label(_get_stat_short_effect(stat_name), 12, Color(0.68, 0.78, 0.85))
		effect_label.clip_text = true
		effect_label.tooltip_text = _get_stat_effect(stat_name)
		identity.add_child(effect_label)
		var value_label := UiStyle.make_label(str(value), 19, UiStyle.GOLD_BRIGHT)
		value_label.text = str(value)
		value_label.custom_minimum_size = Vector2(32, 48)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(value_label)
		stat_value_labels[stat_name] = value_label
		var cost := GameData.get_direct_stat_upgrade_cost(selected_char_id, stat_name)
		var button := UiStyle.make_button("+1 · %d G" % cost, Vector2(112, 48))
		button.add_theme_font_size_override("font_size", 13)
		button.disabled = GameData.player_gold < cost
		button.tooltip_text = _get_stat_preview(character, stats, stat_name)
		button.pressed.connect(_on_direct_stat_upgrade.bind(stat_name))
		row.add_child(button)

func _get_stat_effect(stat_name: String) -> String:
	match stat_name:
		"STR": return "근접 공격력, HP, 소지 한계"
		"AGI": return "공격 속도, 이동 속도, 회피"
		"VIT": return "최대 HP, HP 회복, 물리·마법 방어"
		"INT": return "마법 공격력과 마법 방어"
		"DEX": return "공격력, 명중률과 공격 속도"
		"LUK": return "크리티컬, 완전 회피와 명중률"
	return ""

func _get_stat_short_effect(stat_name: String) -> String:
	match stat_name:
		"STR": return "공격 · 체력"
		"AGI": return "공속 · 이동"
		"VIT": return "체력 · 방어"
		"INT": return "마법 · 방어"
		"DEX": return "명중 · 공격"
		"LUK": return "치명 · 회피"
	return ""

func _get_stat_preview(character: Dictionary, stats: StatManager, stat_name: String) -> String:
	var projected_data: Dictionary = character.duplicate(true)
	var attributes: Dictionary = projected_data.get("attributes", {})
	attributes[stat_name] = stats.get_stat(stat_name) + 1
	projected_data["attributes"] = attributes
	var projected := StatManager.new()
	projected.setup_from_class(selected_char_id, projected_data)
	var effect := _get_stat_effect(stat_name)
	return "%s %d → %d\n%s\n상승 후: HP %d · 공격 %.1f · 마법 %.1f · 공격 속도 %.2f/s · 회피 %.1f%% · 크리티컬 %.1f%%" % [
		stat_name, stats.get_stat(stat_name), stats.get_stat(stat_name) + 1, effect,
		projected.max_hp(), projected.phys_atk(), projected.mag_atk(),
		1.2 * projected.attack_speed(), projected.evasion(), projected.crit_rate()
	]

func _on_direct_stat_upgrade(stat_name: String):
	if not GameData.upgrade_character_stat_with_gold(selected_char_id, stat_name):
		feedback_label.text = "골드가 부족합니다."
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		return
	feedback_label.text = "%s +1 강화 완료" % stat_name
	feedback_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	var value_label := stat_value_labels.get(stat_name) as Label
	if value_label:
		value_label.pivot_offset = value_label.size * 0.5
		value_label.scale = Vector2(1.22, 1.22)
		value_label.modulate = Color(0.45, 1.0, 0.58)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(value_label, "scale", Vector2.ONE, 0.22)
		tween.tween_property(value_label, "modulate", Color.WHITE, 0.22)

func _toggle_character_details():
	var skill_box := detail_content.get_node("SkillBox") as VBoxContainer
	var detail_visible := not skill_box.visible
	skill_box.visible = detail_visible
	desc_label.visible = detail_visible
	detail_toggle_button.text = "상세 정보 닫기" if detail_visible else "상세 정보 보기"

func _wrap_detail_in_scroll():
	var parent := detail_content.get_parent()
	var child_index := detail_content.get_index()
	parent.remove_child(detail_content)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	parent.move_child(scroll, child_index)
	scroll.add_child(detail_content)
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
