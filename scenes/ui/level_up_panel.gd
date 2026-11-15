extends CanvasLayer

@onready var cards_container: HBoxContainer = $CenterContainer/VBoxContainer/CardsContainer
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

var current_upgrades: Array[Dictionary] = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state):
	if new_state == GameManager.GameState.LEVEL_UP:
		show_upgrades()
	else:
		visible = false

func show_upgrades():
	visible = true
	current_upgrades = GameData.get_random_upgrades(3)
	
	# Clear old cards
	for child in cards_container.get_children():
		child.queue_free()
	
	# Spawn 3 upgrade cards
	for i in range(current_upgrades.size()):
		var up = current_upgrades[i]
		var card = _create_card(up, i)
		cards_container.add_child(card)

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
	icon.text = "⭐"
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
	if index >= 0 and index < current_upgrades.size():
		var chosen = current_upgrades[index]
		GameData.apply_upgrade(chosen)
	
	visible = false
	GameManager.exit_level_up()
