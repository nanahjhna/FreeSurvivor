extends CanvasLayer

signal closed()

const CHARACTER_PORTRAIT := preload("res://scenes/ui/character_portrait.gd")

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
var growth_section: VBoxContainer
var stats_section: VBoxContainer
var info_tab: Button
var growth_tab: Button
var summary: HBoxContainer
var portrait_holder: CenterContainer
var portrait: CHARACTER_PORTRAIT
var stat_value_labels: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var portrait := UiStyle.fit_modal($Panel, Vector2(680, 1080))
	$Panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	detail_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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
	_build_view_tabs()
	GameData.data_updated.connect(_refresh_ui)
	get_viewport().size_changed.connect(_fit_screen)

func _fit_screen() -> void:
	var safe := UiStyle.safe_insets(get_viewport())
	UiStyle.fit_modal($Panel, Vector2(680, 1080), Vector2(16 + maxf(safe.x, safe.z), 24 + maxf(safe.y, safe.w)))
	var width: float = $Panel.custom_minimum_size.x
	attribute_buttons.columns = 3 if width >= 570 else (2 if width >= 410 else 1)

func open(show_growth: bool = false):
	visible = true
	_fit_screen()
	feedback_label.text = ""
	_switch_view(show_growth)
	_refresh_ui()

func close():
	if portrait:
		portrait.set_portrait_active(false)
	visible = false
	closed.emit()

func _refresh_ui():
	if not visible:
		return
	selected_char_id = GameData.get_leader_id()
	_update_detail(selected_char_id)

func _update_detail(cid: String):
	if not GameData.characters.has(cid):
		return
	var c = GameData.characters[cid]
	var stats := GameData.get_character_stat_manager(cid)
	name_label.text = c.get("name", "")
	title_label.text = "%s  ·  Lv.%d" % [c.get("role", ""), int(c.get("level", 1))]
	grade_badge.hide()
	icon_label.text = c.get("icon", "⚔️")
	gold_label.text = "💰 %d 골드" % GameData.player_gold
	
	hp_label.text = str(int(GameData.get_max_player_hp()))
	atk_label.text = str(int(stats.phys_atk()))
	def_label.text = str(int(stats.phys_def()))
	_refresh_attribute_controls(c, stats)
	_refresh_detailed_stats(stats)
	
	skill_title.text = "대표 스킬: " + c.get("signature_skill", "")
	desc_label.text = c.get("desc", "")
	

func _prepare_simple_layout():
	var top_row := name_label.get_parent() as HBoxContainer
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_label = Label.new()
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
	stats_section = VBoxContainer.new()
	stats_section.add_theme_constant_override("separation", 9)
	detail_content.add_child(stats_section)
	detail_content.move_child(stats_section, stats_grid.get_index() + 1)
	_build_summary_model(stats_grid)

func _build_summary_model(grid: GridContainer) -> void:
	var index := grid.get_index()
	summary = HBoxContainer.new()
	summary.add_theme_constant_override("separation", 18)
	detail_content.add_child(summary)
	detail_content.move_child(summary, index)
	portrait_holder = CenterContainer.new()
	portrait_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(portrait_holder)
	grid.reparent(summary, false)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _build_stat_controls():
	growth_section = VBoxContainer.new()
	growth_section.name = "DirectStatGrowth"
	growth_section.add_theme_constant_override("separation", 10)
	attribute_buttons = GridContainer.new()
	attribute_buttons.columns = 3
	attribute_buttons.add_theme_constant_override("h_separation", 10)
	attribute_buttons.add_theme_constant_override("v_separation", 8)
	growth_section.add_child(attribute_buttons)
	feedback_label.get_parent().remove_child(feedback_label)
	feedback_label.custom_minimum_size = Vector2(0, 24)
	growth_section.add_child(feedback_label)
	detail_content.add_child(growth_section)

func _build_view_tabs() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	detail_content.add_child(tabs)
	detail_content.move_child(tabs, 2)
	info_tab = UiStyle.make_button("상세 능력치", Vector2(0, 54))
	growth_tab = UiStyle.make_button("영구 강화", Vector2(0, 54))
	for button in [info_tab, growth_tab]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	info_tab.pressed.connect(_switch_view.bind(false))
	growth_tab.pressed.connect(_switch_view.bind(true))

func _switch_view(growth: bool) -> void:
	$Panel/Margin/VBox/Header/Title.text = "영구 능력치 강화" if growth else "캐릭터 정보"
	summary.visible = not growth
	if not growth and portrait == null:
		portrait = CHARACTER_PORTRAIT.new()
		portrait.custom_minimum_size = Vector2(217, 260)
		portrait_holder.add_child(portrait)
	if portrait:
		portrait.set_portrait_active(not growth)
		if not growth:
			portrait.show_character(GameData.get_leader_id())
	detail_content.get_node("SkillBox").visible = not growth
	desc_label.visible = not growth
	stats_section.visible = not growth
	growth_section.visible = growth
	UiStyle.skin_button(info_tab, Color("#79492c") if not growth else Color("#30251f"), Color("#d09b65"))
	UiStyle.skin_button(growth_tab, Color("#316c9f") if growth else Color("#30251f"), Color("#88c9ef") if growth else Color("#b28b62"))
	info_tab.add_theme_font_size_override("font_size", 18)
	growth_tab.add_theme_font_size_override("font_size", 18)

func _refresh_detailed_stats(stats: StatManager) -> void:
	for child in stats_section.get_children():
		stats_section.remove_child(child)
		child.queue_free()
	UiStyle.divider(stats_section)
	stats_section.add_child(UiStyle.make_title("전투 능력치", 23))
	for pair in [
		["마법 공격력", "%.1f" % stats.mag_atk()],
		["마법 방어력", "%.1f" % stats.mag_def()],
		["공격 속도", "%.2f×" % stats.attack_speed()],
		["치명타 확률", "%.1f%%" % stats.crit_rate()],
		["회피율", "%.1f%%" % stats.evasion()]
	]:
		_add_stat_line(pair[0], pair[1])
	UiStyle.divider(stats_section)
	stats_section.add_child(UiStyle.make_title("기본 능력치", 23))
	for stat in StatManager.STAT_KEYS:
		_add_stat_line(stat, str(stats.get_stat(stat)))

func _add_stat_line(caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 30
	stats_section.add_child(row)
	var label := UiStyle.make_label(caption, 18, UiStyle.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(UiStyle.make_label(value, 20, UiStyle.IVORY))

func _refresh_attribute_controls(character: Dictionary, stats: StatManager):
	stat_value_labels.clear()
	for child in attribute_buttons.get_children():
		attribute_buttons.remove_child(child)
		child.queue_free()
	for stat_name in StatManager.STAT_KEYS:
		var value := stats.get_stat(stat_name)
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", UiStyle.frame(Color("#f3dca4"), Color("#ca9961"), 15, 3))
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attribute_buttons.add_child(row_panel)
		var row_margin := UiStyle.make_margin(row_panel, 8)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row_margin.add_child(row)
		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_theme_constant_override("separation", 2)
		row.add_child(identity)
		var stat_label := UiStyle.make_label(stat_name, 20, UiStyle.PAPER_INK)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		identity.add_child(stat_label)
		var effect_label := UiStyle.make_label(_get_stat_short_effect(stat_name), 14, Color("#5c4032"))
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.clip_text = true
		effect_label.tooltip_text = _get_stat_effect(stat_name)
		identity.add_child(effect_label)
		var marks := {"STR": "⚔", "AGI": "➤", "VIT": "♥", "INT": "✦", "DEX": "◎", "LUK": "◆"}
		var badge := UiStyle.plaque("%s  %d" % [marks.get(stat_name, ""), value], Color("#394365"), Color("#88aada"), Color("#fff0c3"), 27)
		badge.custom_minimum_size.y = 57
		row.add_child(badge)
		var value_label := badge.get_child(0) as Label
		stat_value_labels[stat_name] = value_label
		var cost := GameData.get_direct_stat_upgrade_cost(selected_char_id, stat_name)
		var button := UiStyle.make_button("+1 · %d G" % cost, Vector2(112, 48))
		UiStyle.skin_button(button, Color("#db9c3d"), Color("#fff2b4"), UiStyle.PAPER_INK)
		button.add_theme_font_size_override("font_size", 16)
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
