extends CanvasLayer

@onready var cards_container: HBoxContainer = $CenterContainer/VBoxContainer/CardsContainer
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
	$CenterContainer/VBoxContainer/Subtitle.text = "서바이벌 전용 강화 · 한 장을 선택하세요 · 이번 스테이지에서만 유지"
	reroll_button = Button.new()
	reroll_button.text = "🔄 무료로 다시 뽑기"
	reroll_button.custom_minimum_size = Vector2(220, 42)
	reroll_button.pressed.connect(_on_reroll_pressed)
	$CenterContainer/VBoxContainer.add_child(reroll_button)
	GameManager.state_changed.connect(_on_game_state_changed)
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
	title_label.text = "레벨 %d" % last_level
	if is_start_draft:
		title_label.text = "시작 강화 선택 · %d / 5" % (6 - GameManager.starting_draft_picks)
	if not learned.is_empty():
		title_label.text += " · %s 습득" % " · ".join(learned)
	rerolls_left = int(GameData.get_survival_bonus("free_reroll"))
	reroll_button.visible = rerolls_left > 0
	reroll_button.text = "🔄 무료 다시 뽑기 (%d회)" % rerolls_left
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
	reroll_button.text = "🔄 무료 다시 뽑기 (%d회)" % rerolls_left
	current_upgrades = GameData.get_random_upgrades(3)
	_render_cards()

func _create_card(upgrade_data: Dictionary, index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(240, 320)
	btn.flat = false
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	
	# Icon or header
	var icon = Label.new()
	icon.text = str(upgrade_data.get("grade", "기본"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 42)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)
	
	# Title
	var title = Label.new()
	title.text = upgrade_data.get("name", "강화")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)
	
	# Description
	var desc = Label.new()
	desc.text = upgrade_data.get("description", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc)
	
	btn.pressed.connect(func(): _on_card_selected(index))
	return btn

func _on_card_selected(index: int):
	if not visible or GameManager.current_state != GameManager.GameState.LEVEL_UP:
		return
	if index >= 0 and index < current_upgrades.size():
		var chosen = current_upgrades[index]
		GameData.apply_upgrade(chosen)
		if is_start_draft:
			GameManager.starting_draft_picks = maxi(0, GameManager.starting_draft_picks - 1)
			if GameManager.starting_draft_picks > 0:
				show_upgrades()
				return
			is_start_draft = false
	
	visible = false
	GameManager.exit_level_up()
