extends CanvasLayer

const REFERENCE_SCREEN := preload("res://scripts/reference_screen.gd")

signal closed()

const CHARACTER_PORTRAIT := preload("res://scenes/ui/character_portrait.gd")
const ATTRIBUTE_NAMES := {
	"STR": "힘", "AGI": "민첩", "VIT": "체력", "INT": "지능", "DEX": "손재주", "LUK": "행운",
}
const LINKED_STATS := {
	"STR": ["물리 공격력", "%.1f"],
	"AGI": ["이동 속도", "%.2f m/s"],
	"VIT": ["최대 체력", "%.0f"],
	"INT": ["마법 공격력", "%.1f"],
	"DEX": ["시전 속도", "%.0f%%"],
	"LUK": ["치명타 확률", "%.0f%%"],
}
const BONUS_COLOR := Color("#9ae9a7")

@onready var detail_panel: PanelContainer = $Panel/Margin/VBox/Body/RightDetail
@onready var detail_content: VBoxContainer = $Panel/Margin/VBox/Body/RightDetail/Content
@onready var name_label: Label = detail_content.get_node("Header/TextInfo/TopRow/NameLabel")
@onready var title_label: Label = detail_content.get_node("Header/TextInfo/TitleLabel")
@onready var portrait_panel: Panel = detail_content.get_node("Header/Portrait")
@onready var icon_label: Label = portrait_panel.get_node("IconLabel")

var selected_char_id := GameData.FIGHTER_ID
var growth_enabled := false
var gold_label: Label
var feedback_label: Label
var portrait: CHARACTER_PORTRAIT
var stat_rows: Dictionary = {}
var experience_purchase_button: Button
var total_level_label: Label
var character_exp_bar: ProgressBar
var character_exp_label: Label
var stat_table: GridContainer
var growth_preview: PanelContainer
var growth_gain_label: Label
var growth_progress_label: Label
var growth_next_label: Label
var approved_profile: REFERENCE_SCREEN
var approved_growth: REFERENCE_SCREEN


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	$Backdrop.color = UiStyle.SCRIM
	$Panel.add_theme_stylebox_override("panel", UiStyle.art_panel(UiStyle.RUST, Vector2(2, 2)))
	$Panel/Margin/VBox/Header/Title.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	detail_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	portrait_panel.add_theme_stylebox_override("panel", UiStyle.art_panel())
	var margin := $Panel/Margin as MarginContainer
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	var close_button := $Panel/Margin/VBox/Header/CloseBtn as Button
	UiStyle.apply_button(close_button)
	close_button.custom_minimum_size = Vector2(52, 48)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", UiStyle.MUTED)
	name_label.get_parent().get_node("GradeBadge").hide()
	gold_label = UiStyle.make_label("", 17, UiStyle.GOLD_BRIGHT)
	name_label.get_parent().add_child(gold_label)

	_wrap_detail_in_scroll()
	_build_stats()
	_fit_screen()
	GameData.data_updated.connect(_refresh_ui)
	get_viewport().size_changed.connect(_fit_screen)


func _fit_screen() -> void:
	var safe := UiStyle.safe_insets(get_viewport())
	UiStyle.fit_modal($Panel, Vector2(680, 920), Vector2(16 + maxf(safe.x, safe.z), 24 + maxf(safe.y, safe.w)))


func open(show_growth: bool = false) -> void:
	growth_enabled = show_growth
	$Panel/Margin/VBox/Header/Title.text = "캐릭터 성장" if show_growth else "캐릭터 정보"
	feedback_label.hide()
	show()
	if not show_growth and portrait == null:
		portrait = CHARACTER_PORTRAIT.new()
		portrait_panel.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_label.visible = show_growth
	if portrait:
		portrait.visible = not show_growth
		portrait.set_portrait_active(not show_growth)
		if not show_growth:
			portrait.show_character(GameData.get_leader_id())
	_refresh_ui()
	if show_growth and approved_growth == null:
		_build_approved_growth()
	elif not show_growth and approved_profile == null:
		_build_approved_profile()
	if approved_growth:
		approved_growth.visible = show_growth
	if approved_profile:
		approved_profile.visible = not show_growth
	$Panel.hide()


func _build_approved_profile() -> void:
	approved_profile = REFERENCE_SCREEN.new()
	var screen := approved_profile
	screen.build(self, "profile")
	screen.hit(Rect2(483, 28, 55, 52), "닫기", close)
	screen.mask(Rect2(39, 116, 186, 198), Rect2(44, 340, 99, 10))
	screen.native(portrait, Rect2(40, 117, 183, 194))
	portrait.stretch_shrink = 1
	portrait.set_framing(1.22, 2.09, 0.78)
	screen.show_label(name_label, Rect2(312, 145, 220, 56), 33)
	screen.bar(Rect2(253, 224, 268, 24), func(): return character_exp_bar.ratio, Color("#ecac48"))
	screen.show_label(character_exp_label, Rect2(254, 254, 267, 36), 24, HORIZONTAL_ALIGNMENT_CENTER, Color("#23201c"))
	for index in range(StatManager.STAT_KEYS.size()):
		var data: Dictionary = stat_rows[StatManager.STAT_KEYS[index]]
		var stat_name: String = StatManager.STAT_KEYS[index]
		var y := 348 + 52 * index
		screen.mask(Rect2(408, y, 105, 42), Rect2(309, y, 89, 42))
		screen.live_text(Rect2(408, y, 87, 42), func(): return data.basic.text, 35, HORIZONTAL_ALIGNMENT_RIGHT)
	for index in range(3):
		var data: Dictionary = stat_rows[["STR", "VIT", "DEX"][index]]
		var y := 702 + 61 * index
		screen.mask(Rect2(379, y, 136, 48), Rect2(276, y, 91, 48))
		screen.live_text(Rect2(382, y, 118, 48), func(): return data.detail.text, 30, HORIZONTAL_ALIGNMENT_RIGHT)
func _build_approved_growth() -> void:
	approved_growth = REFERENCE_SCREEN.new()
	var screen := approved_growth
	screen.build(self, "growth")
	screen.hit(Rect2(482, 28, 55, 55), "닫기", close)
	screen.show_label(name_label, Rect2(91, 118, 222, 57), 33)
	screen.show_label(gold_label, Rect2(390, 116, 139, 61), 29, HORIZONTAL_ALIGNMENT_RIGHT)
	screen.bar(Rect2(27, 193, 493, 28), func(): return character_exp_bar.ratio, Color("#eaa443"))
	screen.live_text(Rect2(27, 189, 493, 37), func(): return character_exp_label.text, 24, HORIZONTAL_ALIGNMENT_CENTER)
	screen.solid(Rect2(28, 347, 496, 349), Color("#241d18f5"))
	var growth_card := PanelContainer.new()
	growth_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	growth_card.add_theme_stylebox_override("panel", UiStyle.frame(Color("#28211ae8"), UiStyle.RUST, 2))
	screen.page.add_child(growth_card)
	screen.place(growth_card, Rect2(28, 347, 496, 349))
	screen.text(Rect2(54, 370, 444, 30), "이번 구매", 18, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.GOLD_BRIGHT)
	screen.live_text(Rect2(54, 404, 444, 61), func(): return growth_gain_label.text, 38, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.IVORY)
	screen.text(Rect2(54, 477, 444, 29), "현재 EXP  →  구매 후 EXP", 16, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.MUTED)
	screen.live_text(Rect2(54, 510, 444, 58), func(): return growth_progress_label.text, 34, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.GOLD_BRIGHT)
	screen.live_text(Rect2(54, 595, 444, 60), func(): return growth_next_label.text, 18, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.mask(Rect2(52, 823, 448, 57), Rect2(38, 823, 57, 57))
	screen.live_text(Rect2(46, 825, 460, 53), func(): return experience_purchase_button.text, 34, HORIZONTAL_ALIGNMENT_CENTER)
	screen.relay(Rect2(18, 807, 518, 93), experience_purchase_button)
	screen.live_text(Rect2(25, 900, 501, 33), func(): return feedback_label.text if feedback_label.visible else "", 16, HORIZONTAL_ALIGNMENT_CENTER)


func close() -> void:
	if portrait:
		portrait.set_portrait_active(false)
	hide()
	closed.emit()


func _build_stats() -> void:
	var level_panel := PanelContainer.new()
	level_panel.add_theme_stylebox_override("panel", UiStyle.art_panel())
	level_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level_margin := UiStyle.make_margin(level_panel, 12)
	var level_box := VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 4)
	level_margin.add_child(level_box)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	level_box.add_child(level_row)
	total_level_label = UiStyle.make_label("경험치", 21)
	total_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(total_level_label)
	character_exp_label = UiStyle.make_label("", 18, UiStyle.MUTED)
	character_exp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_row.add_child(character_exp_label)
	character_exp_bar = ProgressBar.new()
	character_exp_bar.custom_minimum_size = Vector2(0, 14)
	character_exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_exp_bar.show_percentage = false
	character_exp_bar.add_theme_stylebox_override("background", UiStyle.panel_style(UiStyle.ASPHALT, UiStyle.STEEL, 1))
	character_exp_bar.add_theme_stylebox_override("fill", UiStyle.panel_style(UiStyle.AMBER, UiStyle.GOLD_BRIGHT, 1))
	level_box.add_child(character_exp_bar)
	detail_content.add_child(level_panel)

	var table := GridContainer.new()
	stat_table = table
	table.columns = 2
	table.add_theme_constant_override("h_separation", 12)
	table.add_theme_constant_override("v_separation", 8)
	detail_content.add_child(table)
	table.add_child(UiStyle.make_label("능력치", 16, UiStyle.GOLD_BRIGHT))
	table.add_child(UiStyle.make_label("직업 효과", 16, UiStyle.GOLD_BRIGHT))
	for stat_name in StatManager.STAT_KEYS:
		var basic := _stat_cell(table, ATTRIBUTE_NAMES[stat_name])
		var linked: Array = LINKED_STATS[stat_name]
		var detail := _stat_cell(table, linked[0])
		stat_rows[stat_name] = {"basic": basic, "detail": detail}

	growth_preview = UiStyle.make_panel(UiStyle.INK_SOFT)
	detail_content.add_child(growth_preview)
	var growth_column := VBoxContainer.new()
	growth_column.add_theme_constant_override("separation", 11)
	UiStyle.make_margin(growth_preview, 22).add_child(growth_column)
	growth_gain_label = UiStyle.make_title("", 38)
	growth_progress_label = UiStyle.make_label("", 28, UiStyle.GOLD_BRIGHT)
	growth_next_label = UiStyle.make_label("", 19, UiStyle.MUTED)
	for label in [growth_gain_label, growth_progress_label, growth_next_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		growth_column.add_child(label)
	experience_purchase_button = UiStyle.make_button("경험치 구매", Vector2(0, 54), true)
	experience_purchase_button.add_theme_font_size_override("font_size", 22)
	experience_purchase_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience_purchase_button.pressed.connect(_on_purchase_experience)
	detail_content.add_child(experience_purchase_button)

	feedback_label = UiStyle.make_label("", 16, BONUS_COLOR)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(feedback_label)


func _stat_cell(parent: GridContainer, caption: String) -> Label:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 2)
	parent.add_child(cell)
	cell.add_child(UiStyle.make_label(caption, 15, UiStyle.MUTED))
	var value := UiStyle.make_label("", 20)
	cell.add_child(value)
	return value


func _refresh_ui() -> void:
	if not visible:
		return
	selected_char_id = GameData.get_leader_id()
	if not GameData.characters.has(selected_char_id):
		return
	var character: Dictionary = GameData.characters[selected_char_id]
	var stats := GameData.get_character_stat_manager(selected_char_id)
	var current_level := GameData.get_character_total_level(selected_char_id)
	name_label.text = "%s  LV.%d" % [str(character.get("name", character.get("role", ""))), current_level]
	title_label.text = ""
	icon_label.text = character.get("icon", "⚔️")
	gold_label.text = "%s G" % String.num_int64(GameData.player_gold)
	gold_label.visible = growth_enabled
	var total_level := GameData.get_character_total_level(selected_char_id)
	var current_xp := GameData.get_character_current_xp(selected_char_id)
	var xp_to_next := GameData.get_character_xp_to_next(selected_char_id)
	total_level_label.text = "경험치"
	character_exp_label.text = "%d / %d EXP" % [current_xp, xp_to_next]
	character_exp_bar.max_value = xp_to_next
	character_exp_bar.value = current_xp

	for stat_name in StatManager.STAT_KEYS:
		var row: Dictionary = stat_rows[stat_name]
		var before := _linked_value_text(stats, stat_name)
		var recommended := GameData.is_recommended_growth_stat(selected_char_id, stat_name)
		var detail: Label = row.detail
		row.basic.text = "%d" % stats.get_stat(stat_name)
		detail.text = before
		detail.add_theme_color_override("font_color", UiStyle.IVORY)
		if growth_enabled and recommended:
			detail.add_theme_color_override("font_color", BONUS_COLOR)

	var purchase_cost := GameData.get_character_experience_purchase_cost(selected_char_id)
	stat_table.visible = not growth_enabled
	growth_preview.visible = growth_enabled
	experience_purchase_button.visible = growth_enabled
	experience_purchase_button.disabled = not growth_enabled or purchase_cost <= 0 or GameData.player_gold < purchase_cost
	var xp_gain := GameData.get_character_xp_per_purchase()
	var after_xp := current_xp + xp_gain
	growth_gain_label.text = "+%d EXP" % xp_gain if purchase_cost > 0 else "최대 성장"
	growth_progress_label.text = "%d → %d" % [current_xp, mini(after_xp, xp_to_next)] if purchase_cost > 0 else ""
	growth_next_label.text = ""
	if purchase_cost > 0:
		if after_xp >= xp_to_next:
			growth_next_label.text = "구매 시 Lv.%d 도달" % (total_level + 1)
		else:
			growth_next_label.text = "구매 후 다음 레벨까지 %d EXP" % (xp_to_next - after_xp)
		if GameData.player_gold < purchase_cost:
			growth_next_label.text += "\n골드가 부족합니다"
	experience_purchase_button.text = "경험치 구매  ·  %d G" % purchase_cost if purchase_cost > 0 else "최대 성장"

func _linked_value_text(stats: StatManager, stat_name: String) -> String:
	var value: float
	match stat_name:
		"STR": value = stats.phys_atk() * GameData.attack_damage_mult
		"AGI": value = stats.base_spd * stats.move_speed_multiplier()
		"VIT": value = stats.max_hp() + GameData.max_hp_bonus
		"INT": value = stats.mag_atk() * GameData.attack_damage_mult
		"DEX": value = stats.cast_speed() * 100.0
		"LUK": value = stats.crit_rate()
	return str(LINKED_STATS[stat_name][1]) % value

func _on_purchase_experience() -> void:
	var class_id := selected_char_id
	var before_level := GameData.get_character_total_level(class_id)
	if not GameData.purchase_character_experience(class_id):
		return
	var after_level := GameData.get_character_total_level(class_id)
	var current_xp := GameData.get_character_current_xp(class_id)
	var xp_to_next := GameData.get_character_xp_to_next(class_id)
	if after_level > before_level:
		UiStyle.play_sfx("level_up", -1.0)
		feedback_label.text = "캐릭터 레벨업!  Lv.%d  ·  다음 레벨까지 %d / %d EXP" % [after_level, current_xp, xp_to_next]
	else:
		feedback_label.text = "경험치 +%d  ·  현재 %d / %d EXP  ·  남은 골드 %d G" % [GameData.get_character_xp_per_purchase(), current_xp, xp_to_next, GameData.player_gold]
	feedback_label.show()


func _wrap_detail_in_scroll() -> void:
	detail_panel.remove_child(detail_content)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(scroll)
	scroll.add_child(detail_content)
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _on_close_pressed() -> void:
	close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
