extends CanvasLayer

@onready var cards_container: GridContainer = $CenterContainer/VBoxContainer/CardsContainer
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

var current_upgrades: Array[Dictionary] = []
var last_level: int = 1
var rerolls_left: int = 0
var reroll_button: Button
var is_start_draft: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CenterContainer/VBoxContainer/Subtitle.text = "이번 전투에서 사용할 카드 한 장을 고르세요"
	reroll_button = Button.new()
	reroll_button.text = "↻  다시 뽑기"
	reroll_button.custom_minimum_size = Vector2(220, 42)
	UiStyle.apply_button(reroll_button)
	reroll_button.pressed.connect(_on_reroll_pressed)
	$CenterContainer/VBoxContainer.add_child(reroll_button)
	GameManager.state_changed.connect(_on_game_state_changed)
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	if GameManager.starting_draft_picks > 0:
		is_start_draft = true
		GameManager.enter_level_up()

func _on_game_state_changed(new_state):
	if new_state == GameManager.GameState.LEVEL_UP:
		show_upgrades()
	else:
		visible = false

func show_upgrades():
	visible = true
	_apply_layout()
	var learned := PackedStringArray()
	for level in range(last_level + 1, GameData.player_level + 1):
		for skill in GameData.skill_meta.values():
			if int(skill.unlock_level) == level:
				learned.append(str(skill.name))
	last_level = GameData.player_level
	title_label.text = "Lv.%d · 카드 한 장 선택" % last_level
	if is_start_draft:
		title_label.text = "시작 카드 · %d / 10" % (11 - GameManager.starting_draft_picks)
		$CenterContainer/VBoxContainer/Subtitle.text = "전투 전에 사용할 카드를 고르세요 · %d장 남음" % GameManager.starting_draft_picks
	elif GameManager.level_card_picks > 1:
		title_label.text += " · 남은 선택 %d회" % GameManager.level_card_picks
		$CenterContainer/VBoxContainer/Subtitle.text = "원하는 강화를 골라 이번 전투에 적용하세요"
	else:
		$CenterContainer/VBoxContainer/Subtitle.text = "이번 전투에서 사용할 강화 카드를 한 장 고르세요"
	if not learned.is_empty():
		title_label.text += " · %s 습득" % " · ".join(learned)
	rerolls_left = int(GameData.get_survival_bonus("free_reroll"))
	reroll_button.visible = rerolls_left > 0
	reroll_button.text = "↻  다시 뽑기 · %d회" % rerolls_left
	current_upgrades = GameData.get_random_upgrades(3)
	_render_cards()

func _render_cards():
	# Clear old cards
	for child in cards_container.get_children():
		child.queue_free()
	
	# Spawn 3 upgrade cards
	for i in range(current_upgrades.size()):
		var up = current_upgrades[i]
		var card = _create_card(up, i)
		cards_container.add_child(card)

func _on_reroll_pressed():
	if not visible or rerolls_left <= 0:
		return
	rerolls_left -= 1
	reroll_button.visible = rerolls_left > 0
	reroll_button.text = "↻  다시 뽑기 · %d회" % rerolls_left
	current_upgrades = GameData.get_random_upgrades(3)
	_render_cards()

func _create_card(upgrade_data: Dictionary, index: int) -> Button:
	var btn := Button.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var stacked := false
	var card_width := maxf(96.0, (viewport_size.x - 64.0) / 3.0)
	var card_height := clampf(viewport_size.y * 0.43, 400.0, 560.0)
	btn.custom_minimum_size = Vector2(card_width, card_height)
	var grade := str(upgrade_data.get("grade", "일반"))
	var recommendation: Dictionary = SurvivalCardDatabase.get_recommendation(upgrade_data, GameData.get_leader_id())
	var recommendation_score := clampi(int(recommendation.get("score", 3)), 1, 5)
	var recommended := recommendation_score >= 4
	var grade_color := Color(0.78, 0.61, 0.38)
	match grade:
		"희귀": grade_color = Color(0.82, 0.68, 0.45)
		"영웅": grade_color = Color(0.9, 0.48, 0.31)
		"전설": grade_color = UiStyle.GOLD_BRIGHT
	var card_border := Color(1.0, 0.78, 0.2) if recommended else grade_color
	var card_bg := Color(0.16, 0.105, 0.018, 0.99) if recommended else Color(0.055, 0.028, 0.025, 0.98)
	btn.add_theme_stylebox_override("normal", UiStyle.button_style(card_bg, card_border))
	btn.add_theme_stylebox_override("hover", UiStyle.button_style(Color(0.25, 0.17, 0.025, 1.0) if recommended else Color(0.16, 0.045, 0.025, 1.0), card_border.lightened(0.18)))
	btn.add_theme_stylebox_override("pressed", UiStyle.button_style(Color(0.31, 0.2, 0.025, 1.0) if recommended else Color(0.24, 0.035, 0.025, 1.0), card_border))
	btn.add_theme_stylebox_override("focus", UiStyle.button_style(Color(0, 0, 0, 0), card_border))
	btn.add_theme_color_override("font_color", UiStyle.IVORY)
	btn.add_theme_color_override("font_hover_color", UiStyle.GOLD_BRIGHT)
	btn.set_meta("upgrade_grade_color", grade_color)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 12 if stacked else 18)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10 if stacked else 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)
	var card_content: Container
	if stacked:
		card_content = HBoxContainer.new()
		card_content.add_theme_constant_override("separation", 14)
	else:
		card_content = VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 12)
		(card_content as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(card_content)
	var icon := UiStyle.make_label(_card_icon(str(upgrade_data.get("stat", ""))), 44 if stacked else 28, grade_color)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stacked:
		icon.custom_minimum_size = Vector2(72, 72)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_content.add_child(icon)
	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 4)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_content.add_child(text_column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(header)
	if not stacked:
		header.add_child(icon)
	var title_color := Color(1.0, 0.86, 0.28) if recommended else Color(1.0, 0.97, 0.88)
	var title := UiStyle.make_label(str(upgrade_data.get("name", "강화")), 23 if stacked else 24, title_color)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	var badge := UiStyle.make_label(grade, 14, grade_color)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(badge)
	var desc := UiStyle.make_label(str(upgrade_data.get("description", "")), 17 if stacked else 19, Color(0.91, 0.85, 0.76))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(desc)
	var stars := "★".repeat(recommendation_score) + "☆".repeat(5 - recommendation_score)
	var rating_color := Color(1.0, 0.84, 0.24) if recommended else Color(0.92, 0.78, 0.48)
	var rating := UiStyle.make_label("추천도 %s · %s" % [stars, str(recommendation.get("reason", "범용 강화"))], 14 if stacked else 15, rating_color)
	rating.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(rating)
	btn.pressed.connect(_apply_upgrade_at.bind(index))
	return btn

func _card_icon(stat: String) -> String:
	if stat.contains("hp") or stat.contains("heal") or stat.contains("shield"):
		return "✦"
	if stat.contains("speed") or stat.contains("move") or stat.contains("dodge"):
		return "➤"
	if stat.contains("xp") or stat.contains("gold") or stat.contains("luck"):
		return "◆"
	return "⚔"

func _apply_layout():
	var viewport_size := get_viewport().get_visible_rect().size
	cards_container.columns = 3
	cards_container.add_theme_constant_override("h_separation", 8)
	cards_container.add_theme_constant_override("v_separation", 0)
	var panel_box := $CenterContainer/VBoxContainer as VBoxContainer
	panel_box.add_theme_constant_override("separation", 12)
	$ColorRect.color = Color(0.015, 0.008, 0.008, 0.9) if viewport_size.y > viewport_size.x else Color(0.015, 0.03, 0.06, 0.72)

func _apply_upgrade_at(index: int):
	if not visible or GameManager.current_state != GameManager.GameState.LEVEL_UP:
		return
	if index < 0 or index >= current_upgrades.size():
		return
	GameData.apply_upgrade(current_upgrades[index])
	if is_start_draft:
		GameManager.starting_draft_picks = maxi(0, GameManager.starting_draft_picks - 1)
		if GameManager.starting_draft_picks > 0:
			show_upgrades()
			return
		is_start_draft = false
	elif GameManager.level_card_picks > 0:
		GameManager.level_card_picks -= 1
	if GameManager.level_card_picks > 0:
		show_upgrades()
		return
	
	visible = false
	GameManager.exit_level_up()
