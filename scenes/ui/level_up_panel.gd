extends CanvasLayer

const AUGMENT_PREVIEW := preload("res://scripts/augment_preview.gd")

@onready var cards_container: GridContainer = $CenterContainer/VBoxContainer/CardsContainer
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

@onready var subtitle: Label = $CenterContainer/VBoxContainer/Subtitle

var cards_scroll: ScrollContainer
var card_width := 200.0

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
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", UiStyle.IVORY)
	UiStyle.ink_outline(title_label, 4)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", UiStyle.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cards_scroll = ScrollContainer.new()
	cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(cards_scroll)
	cards_container.reparent(cards_scroll, false)
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("h_separation", 10)
	cards_container.add_theme_constant_override("v_separation", 10)
	cards_container.minimum_size_changed.connect(func(): _fit_card_scroll.call_deferred())
	subtitle.minimum_size_changed.connect(func(): _fit_card_scroll.call_deferred())
	$ColorRect.color = UiStyle.SCRIM
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
	var learned := PackedStringArray()
	for level in range(last_level + 1, GameData.player_level + 1):
		for skill in GameData.skill_meta.values():
			if int(skill.unlock_level) == level:
				learned.append(str(skill.name))
	last_level = GameData.player_level
	title_label.text = "증강 선택"
	subtitle.text = "카드 한 장을 고르세요"
	if is_start_draft:
		title_label.text = "시작 카드 · %d / 10" % (11 - GameManager.starting_draft_picks)
		subtitle.text = "카드 한 장을 고르세요"
	elif GameManager.level_card_picks > 1:
		title_label.text += " · 남은 선택 %d회" % GameManager.level_card_picks
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
	_fit_card_scroll.call_deferred()

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
	card.custom_minimum_size = Vector2(card_width, 122)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grade := str(upgrade_data.get("grade", "일반"))
	var category := SurvivalCardDatabase.get_category(str(upgrade_data.get("stat", "")))
	var color := UiStyle.category_tint(category)
	UiStyle.apply_button(card)
	UiStyle.skin_button(card, UiStyle.INK_SOFT, UiStyle.RUST, UiStyle.IVORY)
	var recommendation := SurvivalCardDatabase.get_recommendation(upgrade_data, GameData.get_leader_id())
	card.tooltip_text = str(recommendation.get("reason", ""))
	var margin := UiStyle.make_margin(card, 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 7)
	column.add_child(heading)
	var emblem := VBoxContainer.new()
	emblem.custom_minimum_size.x = 66
	emblem.alignment = BoxContainer.ALIGNMENT_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(emblem)
	emblem.add_child(UiStyle.icon_view(UiStyle.category_icon(category), 34, color))
	var category_label := _card_label(emblem, SurvivalCardDatabase.get_category_name(str(upgrade_data.get("stat", ""))), 16, color)
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(copy)
	_card_label(copy, str(upgrade_data.get("name", "강화")), 25, UiStyle.IVORY)
	_card_label(copy, str(upgrade_data.get("description", "")), 18, UiStyle.MUTED)
	var chevron := _card_label(heading, "›", 28, UiStyle.RUST)
	chevron.autowrap_mode = TextServer.AUTOWRAP_OFF
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if grade != "일반":
		_card_label(copy, grade, 15, UiStyle.GOLD_BRIGHT)
	var application := AUGMENT_PREVIEW.describe(upgrade_data)
	if not application.is_empty():
		UiStyle.divider(column)
		_card_label(column, application, 20, UiStyle.IVORY)
	margin.minimum_size_changed.connect(func():
		card.custom_minimum_size.y = maxf(122.0, margin.get_combined_minimum_size().y)
	)
	card.pressed.connect(_apply_upgrade_at.bind(index))
	return card

func _card_label(parent: Control, caption: String, font_size: int, color: Color) -> Label:
	var label := UiStyle.make_label(caption, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _apply_layout():
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UiStyle.safe_insets(get_viewport())
	var center := $CenterContainer as CenterContainer
	center.offset_left = safe.x + 18
	center.offset_right = -safe.z - 18
	center.offset_top = safe.y + 18
	center.offset_bottom = -safe.w - 18
	var target_width := minf(650, viewport_size.x - safe.x - safe.z - 32)
	cards_container.columns = 1
	card_width = floorf(target_width - 16)
	cards_scroll.custom_minimum_size.x = target_width
	for child in cards_container.get_children():
		(child as Control).custom_minimum_size.x = card_width
	_fit_card_scroll.call_deferred()


func _fit_card_scroll() -> void:
	var content := cards_scroll.get_parent() as VBoxContainer
	var available := ($CenterContainer as Control).size.y
	for child in content.get_children():
		if child != cards_scroll and (child as Control).visible:
			available -= (child as Control).get_combined_minimum_size().y + content.get_theme_constant("separation")
	var cards_height := cards_container.get_combined_minimum_size().y
	cards_scroll.custom_minimum_size.y = minf(cards_height, maxf(1.0, available))


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
