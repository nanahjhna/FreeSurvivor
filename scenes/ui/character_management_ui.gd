extends CanvasLayer

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
	"DEX": ["공격 속도", "%.0f%%"],
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
var upgrade_heading: Label
var feedback_label: Label
var portrait: CHARACTER_PORTRAIT
var stat_rows: Dictionary = {}
var extra_stats: GridContainer
var extra_values: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	$Panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	detail_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var margin := $Panel/Margin as MarginContainer
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	var close_button := $Panel/Margin/VBox/Header/CloseBtn as Button
	UiStyle.apply_button(close_button)
	close_button.custom_minimum_size = Vector2(52, 48)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	UiStyle.fit_modal($Panel, Vector2(680, 840), Vector2(16 + maxf(safe.x, safe.z), 24 + maxf(safe.y, safe.w)))
	extra_stats.columns = 2 if $Panel.custom_minimum_size.x >= 460.0 else 1


func open(show_growth: bool = false) -> void:
	growth_enabled = show_growth
	$Panel/Margin/VBox/Header/Title.text = "영구 강화" if show_growth else "캐릭터 능력치"
	upgrade_heading.text = "골드로 강화" if show_growth else ""
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


func close() -> void:
	if portrait:
		portrait.set_portrait_active(false)
	hide()
	closed.emit()


func _build_stats() -> void:
	var table := GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation", 12)
	table.add_theme_constant_override("v_separation", 8)
	detail_content.add_child(table)
	table.add_child(UiStyle.make_label("기본 능력치", 16, UiStyle.GOLD_BRIGHT))
	table.add_child(UiStyle.make_label("상세 능력치", 16, UiStyle.GOLD_BRIGHT))
	upgrade_heading = UiStyle.make_label("골드로 강화", 15, UiStyle.GOLD_BRIGHT)
	table.add_child(upgrade_heading)
	for stat_name in StatManager.STAT_KEYS:
		var basic := _stat_cell(table, ATTRIBUTE_NAMES[stat_name])
		var linked: Array = LINKED_STATS[stat_name]
		var detail := _stat_cell(table, linked[0])
		var slot := CenterContainer.new()
		table.add_child(slot)
		var buy := UiStyle.make_button("", Vector2(0, 44), true)
		buy.pressed.connect(_on_direct_stat_upgrade.bind(stat_name))
		slot.add_child(buy)
		stat_rows[stat_name] = {"basic": basic, "detail": detail, "buy": buy}

	feedback_label = UiStyle.make_label("", 16, BONUS_COLOR)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(feedback_label)

	UiStyle.divider(detail_content)
	detail_content.add_child(UiStyle.make_label("그 외 전투 수치", 16, UiStyle.GOLD_BRIGHT))
	extra_stats = GridContainer.new()
	extra_stats.add_theme_constant_override("h_separation", 20)
	extra_stats.add_theme_constant_override("v_separation", 6)
	detail_content.add_child(extra_stats)
	for caption in ["물리 방어력", "마법 방어력", "명중률", "회피율", "완전 회피율", "체력 회복"]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		extra_stats.add_child(row)
		var label := UiStyle.make_label(caption, 15, UiStyle.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var value := UiStyle.make_label("", 16)
		row.add_child(value)
		extra_values[caption] = value


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
	name_label.text = character.get("name", "")
	title_label.text = "%s  ·  Lv.%d" % [character.get("role", ""), int(character.get("level", 1))]
	icon_label.text = character.get("icon", "⚔️")
	gold_label.text = "%s G" % String.num_int64(GameData.player_gold)
	gold_label.visible = growth_enabled

	for stat_name in StatManager.STAT_KEYS:
		var row: Dictionary = stat_rows[stat_name]
		var value := stats.get_stat(stat_name)
		var before := _linked_value_text(stats, stat_name)
		var cost := GameData.get_direct_stat_upgrade_cost(selected_char_id, stat_name) if growth_enabled else 0
		var detail: Label = row.detail
		var buy: Button = row.buy
		row.basic.text = str(value)
		detail.text = before
		detail.add_theme_color_override("font_color", UiStyle.IVORY)
		buy.disabled = cost <= 0 or GameData.player_gold < cost
		buy.text = ("+1  ·  %d G" % cost if cost > 0 else "최대") if growth_enabled else ""
		buy.visible = growth_enabled
		if cost > 0:
			stats.set_stat(stat_name, value + 1)
			detail.text = "%s → %s" % [before, _linked_value_text(stats, stat_name)]
			detail.add_theme_color_override("font_color", BONUS_COLOR)
			stats.set_stat(stat_name, value)

	extra_values["물리 방어력"].text = "%.1f" % stats.phys_def()
	extra_values["마법 방어력"].text = "%.1f" % stats.mag_def()
	extra_values["명중률"].text = "%.0f%%" % stats.hit_rate()
	extra_values["회피율"].text = "%.1f%%" % stats.evasion()
	extra_values["완전 회피율"].text = "%.1f%%" % stats.perfect_dodge()
	extra_values["체력 회복"].text = "%.2f /초" % stats.hp_recovery_rate()


func _linked_value_text(stats: StatManager, stat_name: String) -> String:
	var value: float
	match stat_name:
		"STR": value = stats.phys_atk() * GameData.attack_damage_mult
		"AGI": value = stats.base_spd * stats.move_speed_multiplier()
		"VIT": value = stats.max_hp() + GameData.max_hp_bonus
		"INT": value = stats.mag_atk() * GameData.attack_damage_mult
		"DEX": value = stats.attack_speed() * 100.0
		"LUK": value = stats.crit_rate()
	return str(LINKED_STATS[stat_name][1]) % value


func _on_direct_stat_upgrade(stat_name: String) -> void:
	var before := _linked_value_text(GameData.get_character_stat_manager(selected_char_id), stat_name)
	if not GameData.upgrade_character_stat_with_gold(selected_char_id, stat_name):
		return
	var after := _linked_value_text(GameData.get_character_stat_manager(selected_char_id), stat_name)
	feedback_label.text = "%s +1   ·   %s %s → %s" % [
		ATTRIBUTE_NAMES[stat_name], LINKED_STATS[stat_name][0], before, after
	]
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
