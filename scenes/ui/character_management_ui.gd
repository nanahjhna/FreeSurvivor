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

@onready var levelup_btn: Button = $Panel/Margin/VBox/Body/RightDetail/Content/Actions/LevelUpBtn
@onready var levelup_cost_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/Actions/CostLabel
@onready var feedback_label: Label = $Panel/Margin/VBox/Body/RightDetail/Content/Actions/FeedbackLabel

var selected_char_id := GameData.FIGHTER_ID
var attribute_points_label: Label
var attribute_buttons: GridContainer
var reset_attributes_button: Button
var combat_stats_label: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_wrap_detail_in_scroll()
	_build_stat_controls()
	GameData.data_updated.connect(_refresh_ui)

func open():
	visible = true
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
	
	level_label.text = "영구 성장"
	hp_label.text = str(int(stats.max_hp()))
	atk_label.text = str(int(stats.phys_atk()))
	def_label.text = str(int(stats.phys_def()))
	spd_label.text = "%.1f" % (stats.base_spd * stats.move_speed_multiplier())
	combat_stats_label.text = (
		"마법 공격 %.1f  ·  공격 속도 %.2f/s\n명중 %.0f%%  ·  회피 %.1f%%  ·  크리티컬 %.1f%%\n물리 방어 %.1f  ·  마법 방어 %.1f  ·  HP 회복 %.2f/s"
		% [stats.mag_atk(), 1.2 * stats.attack_speed(), stats.hit_rate(),
			stats.evasion(), stats.crit_rate(), stats.phys_def(), stats.mag_def(), stats.hp_recovery_rate()]
	)
	_refresh_attribute_controls(c, stats)
	
	skill_title.text = "대표 스킬: " + c.get("signature_skill", "")
	desc_label.text = c.get("desc", "")
	
	var cost := GameData.get_stat_point_gold_cost(cid)
	levelup_cost_label.text = "보유 골드: %d · 포인트 구매 비용: %d 골드" % [GameData.player_gold, cost]
	levelup_btn.disabled = GameData.player_gold < cost
	levelup_btn.text = "＋ 영구 능력치 포인트 획득"
	if GameData.player_gold < cost:
		feedback_label.text = "⛔ 골드가 %d 더 필요합니다." % (cost - GameData.player_gold)
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	else:
		feedback_label.text = ""

func _on_level_up_pressed():
	if GameData.level_up_character(selected_char_id):
		feedback_label.text = "🎉 영구 능력치 포인트를 1개 획득했습니다."
		feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		feedback_label.text = "❌ 골드가 부족합니다!"
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_update_detail(selected_char_id)

func _build_stat_controls():
	combat_stats_label = Label.new()
	combat_stats_label.add_theme_font_size_override("font_size", 12)
	combat_stats_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	combat_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(combat_stats_label)

	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	attribute_points_label = Label.new()
	attribute_points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	section.add_child(attribute_points_label)
	attribute_buttons = GridContainer.new()
	attribute_buttons.columns = 3
	attribute_buttons.add_theme_constant_override("h_separation", 6)
	attribute_buttons.add_theme_constant_override("v_separation", 4)
	section.add_child(attribute_buttons)
	reset_attributes_button = Button.new()
	reset_attributes_button.text = "↺ 능력치 투자 초기화"
	reset_attributes_button.custom_minimum_size = Vector2(0, 34)
	reset_attributes_button.pressed.connect(_on_reset_attributes_pressed)
	section.add_child(reset_attributes_button)
	detail_content.add_child(section)

	var skill_box_index := detail_content.get_node("SkillBox").get_index()
	detail_content.move_child(combat_stats_label, skill_box_index)
	detail_content.move_child(section, detail_content.get_node("SkillBox").get_index())

func _refresh_attribute_controls(character: Dictionary, stats: StatManager):
	attribute_points_label.text = "능력치 투자 포인트: %d" % int(character.get("stat_points", 0))
	for child in attribute_buttons.get_children():
		child.queue_free()
	for stat_name in StatManager.STAT_KEYS:
		var value := stats.get_stat(stat_name)
		var button := Button.new()
		button.text = "%s %d  +" % [stat_name, value]
		button.custom_minimum_size = Vector2(104, 38)
		button.disabled = int(character.get("stat_points", 0)) <= 0
		button.tooltip_text = _get_stat_preview(character, stats, stat_name)
		button.pressed.connect(_on_attribute_invested.bind(stat_name))
		attribute_buttons.add_child(button)
	var invested := int(character.get("stat_points_spent", 0))
	reset_attributes_button.disabled = invested <= 0
	reset_attributes_button.tooltip_text = "사용한 포인트 %d개를 돌려받고 직업 기본 능력치로 초기화합니다." % invested

func _get_stat_preview(character: Dictionary, stats: StatManager, stat_name: String) -> String:
	var projected_data: Dictionary = character.duplicate(true)
	var attributes: Dictionary = projected_data.get("attributes", {})
	attributes[stat_name] = stats.get_stat(stat_name) + 1
	projected_data["attributes"] = attributes
	var projected := StatManager.new()
	projected.setup_from_class(selected_char_id, projected_data)
	var effect := ""
	match stat_name:
		"STR": effect = "근접 공격력, HP, 소지 한계"
		"AGI": effect = "공격 속도, 이동 속도, 회피"
		"VIT": effect = "최대 HP, HP 회복, 물리·마법 방어"
		"INT": effect = "마법 공격력, SP, 마법 방어"
		"DEX": effect = "공격력, 명중, 공격 속도, 마법 공격"
		"LUK": effect = "크리티컬, 완전 회피, 명중"
	return "%s %d → %d\n%s\n상승 후: HP %d · 공격 %.1f · 마법 %.1f · 공격 속도 %.2f/s · 회피 %.1f%% · 크리티컬 %.1f%%" % [
		stat_name, stats.get_stat(stat_name), stats.get_stat(stat_name) + 1, effect,
		projected.max_hp(), projected.phys_atk(), projected.mag_atk(),
		1.2 * projected.attack_speed(), projected.evasion(), projected.crit_rate()
	]

func _on_attribute_invested(stat_name: String):
	if not GameData.allocate_character_stat(selected_char_id, stat_name):
		UiFeedback.show_error("능력치 포인트가 없거나 올바른 능력치를 선택하지 않았습니다.")

func _on_reset_attributes_pressed():
	if not GameData.reset_character_stats(selected_char_id):
		UiFeedback.show_info("초기화할 능력치 포인트가 없습니다.")

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
