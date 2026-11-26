extends CanvasLayer

@onready var cards_container: GridContainer = $CenterContainer/VBoxContainer/CardsContainer
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

@onready var subtitle: Label = $CenterContainer/VBoxContainer/Subtitle

var cards_scroll: ScrollContainer
var card_size := Vector2(200, 290)

var current_upgrades: Array[Dictionary] = []
var last_level: int = 1
var rerolls_left: int = 0
var reroll_button: Button
var is_start_draft: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var content := $CenterContainer/VBoxContainer as VBoxContainer
	content.add_theme_constant_override("separation", 10)
	var title_band := UiStyle.make_panel()
	title_band.custom_minimum_size.y = 60
	title_band.add_theme_stylebox_override("panel", UiStyle.frame(Color("#e9aa39"), Color("#fff0bd"), 15, 5))
	content.add_child(title_band)
	content.move_child(title_band, 0)
	title_label.reparent(title_band, false)
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color("#4d2b1b"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cards_scroll = ScrollContainer.new()
	cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(cards_scroll)
	cards_container.reparent(cards_scroll, false)
	cards_container.add_theme_constant_override("h_separation", 10)
	cards_container.add_theme_constant_override("v_separation", 10)
	$ColorRect.color = Color(0.07, 0.04, 0.19, 0.72)
	reroll_button = Button.new()
	reroll_button.text = "↻  다시 뽑기"
	reroll_button.custom_minimum_size = Vector2(220, 42)
	UiStyle.apply_button(reroll_button)
	UiStyle.skin_button(reroll_button, Color("#604381"), Color("#c49de0"))
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
	var learned := PackedStringArray()
	for level in range(last_level + 1, GameData.player_level + 1):
		for skill in GameData.skill_meta.values():
			if int(skill.unlock_level) == level:
				learned.append(str(skill.name))
	last_level = GameData.player_level
	title_label.text = "레벨업  ·  Lv.%d" % last_level
	if is_start_draft:
		title_label.text = "시작 카드 · %d / 10" % (11 - GameManager.starting_draft_picks)
		subtitle.text = "전투 전에 사용할 카드를 고르세요 · %d장 남음" % GameManager.starting_draft_picks
	elif GameManager.level_card_picks > 1:
		title_label.text += " · 남은 선택 %d회" % GameManager.level_card_picks
		subtitle.text = "원하는 강화를 골라 이번 전투에 적용하세요"
	else:
		subtitle.text = "이번 전투에서 사용할 강화 카드를 한 장 고르세요"
	if not learned.is_empty():
		subtitle.text += "\n습득  %s" % " · ".join(learned)
	rerolls_left = int(GameData.get_survival_bonus("free_reroll"))
	reroll_button.visible = rerolls_left > 0
	reroll_button.text = "↻  다시 뽑기 · %d회" % rerolls_left
	current_upgrades = GameData.get_random_upgrades(3)
	_render_cards()

func _render_cards():
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
	_apply_layout()
	cards_scroll.scroll_vertical = 0
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
	var card := Button.new()
	card.custom_minimum_size = card_size
	var grade := str(upgrade_data.get("grade", "일반"))
	var palettes := {
		"희귀": [Color("#234986"), Color("#8edaff")],
		"영웅": [Color("#663592"), Color("#e5a8fe")],
		"전설": [Color("#865121"), Color("#ffe39c")],
	}
	var palette: Array = palettes.get(grade, [Color("#1f6650"), Color("#9aefab")])
	var face: Color = palette[0]
	var tint: Color = palette[1]
	UiStyle.apply_button(card)
	UiStyle.skin_button(card, face, tint)
	var recommendation := SurvivalCardDatabase.get_recommendation(upgrade_data, GameData.get_leader_id())
	card.tooltip_text = str(recommendation.get("reason", ""))
	var margin := UiStyle.make_margin(card, 13)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_add_card_plaque(column, UiStyle.plaque(grade, tint, tint.lightened(0.35), face.darkened(0.24), 16))
	var compact := get_viewport().get_visible_rect().size.x < 600.0
	var name := _card_label(column, str(upgrade_data.get("name", "강화")), 18 if compact else 22, Color.WHITE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.ink_outline(name, 3, face.darkened(0.40))
	var icon := UiStyle.plaque(_card_icon(str(upgrade_data.get("stat", ""))), Color("#fff1cf"), tint, face, 66)
	icon.custom_minimum_size.y = 72 if compact else 92
	_add_card_plaque(column, icon)
	var description := _card_label(column, str(upgrade_data.get("description", "")), 14 if compact else 17, Color("#fff7e8"))
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if int(recommendation.get("score", 0)) >= 4:
		_card_label(column, "✦ 추천", 15, UiStyle.GOLD_BRIGHT)
	card.pressed.connect(_apply_upgrade_at.bind(index))
	return card

func _add_card_plaque(parent: Control, plate: PanelContainer) -> void:
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := plate.get_child(0) as Label
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(plate)


func _card_label(parent: Control, caption: String, font_size: int, color: Color) -> Label:
	var label := UiStyle.make_label(caption, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


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
	var safe := UiStyle.safe_insets(get_viewport())
	var center := $CenterContainer as CenterContainer
	center.offset_left = safe.x + 18
	center.offset_right = -safe.z - 18
	center.offset_top = safe.y + 18
	center.offset_bottom = -safe.w - 18
	var target_width := minf(708, viewport_size.x - safe.x - safe.z - 36)
	var compact := viewport_size.x < 600.0
	cards_container.columns = 3 if target_width >= 620 else 2
	var columns := cards_container.columns
	var width := floorf((target_width - 13 - (columns - 1) * 10) / columns)
	var preferred_height := viewport_size.y * (0.245 if compact else 0.29)
	card_size = Vector2(width, clampf(preferred_height, 218.0, 310.0) if compact else clampf(preferred_height, 250.0, 330.0))
	var rows := ceilf(float(maxi(current_upgrades.size(), 1)) / columns)
	var available_height := maxf(220.0, viewport_size.y - (150.0 if compact else 190.0))
	cards_scroll.custom_minimum_size = Vector2(target_width, minf(rows * (card_size.y + 10), available_height))
	for child in cards_container.get_children():
		child.custom_minimum_size = card_size


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
