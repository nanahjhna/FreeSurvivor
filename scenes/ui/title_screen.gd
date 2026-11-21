extends Control

@onready var start_button: Button = $Center/VBox/Buttons/StartBtn
@onready var settings_button: Button = $Center/VBox/Buttons/SettingsBtn
@onready var quit_button: Button = $Center/VBox/Buttons/QuitBtn
@onready var settings_ui: CanvasLayer = $SettingsUI
@onready var version_label: Label = $BottomLeft/VersionLabel
@onready var notice_label: Label = $Center/VBox/NoticeLabel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.current_location = GameManager.Location.TITLE
	_apply_portrait_menu_layout()
	
	if start_button:
		start_button.text = "게임 시작"
		start_button.tooltip_text = "캐릭터를 만들거나 저장된 캐릭터를 선택합니다. 기존 데이터는 유지됩니다."
	if settings_button:
		settings_button.text = "설정"
	if quit_button:
		quit_button.text = "종료"
	
	if version_label:
		version_label.text = "FreeSurvivor  ·  v1.0.0"


func _apply_portrait_menu_layout():
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.y > viewport_size.x
	var buttons := $Center/VBox/Buttons as VBoxContainer
	buttons.custom_minimum_size.x = minf(viewport_size.x - 48.0, 620.0) if compact else 360.0
	buttons.add_theme_constant_override("separation", 12 if compact else 14)
	var title := $Center/VBox/TitleGroup/MainTitle as Label
	title.text = "FREE SURVIVOR"
	title.add_theme_font_size_override("font_size", 39 if compact else 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.25))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 1)
	var subtitle := $Center/VBox/TitleGroup/SubTitle as Label
	subtitle.text = "혼자 시작하는 판타지 생존 RPG"
	subtitle.add_theme_font_size_override("font_size", 16 if compact else 20)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.79, 0.64))
	var content := $Center/VBox as VBoxContainer
	content.add_theme_constant_override("separation", 0)
	$Center.add_theme_constant_override("margin_bottom", 180 if compact else 82)
	var spacer := $Center/VBox/Spacer as Control
	spacer.custom_minimum_size.y = 140 if compact else 70
	start_button.text = "게임 시작"
	start_button.custom_minimum_size = Vector2(0, 82 if compact else 72)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.add_theme_font_size_override("font_size", 27 if compact else 24)
	UiStyle.apply_button(start_button, true)
	if settings_button.get_parent() != buttons:
		settings_button.reparent(buttons)
	buttons.move_child(start_button, 0)
	buttons.move_child(settings_button, 1)
	buttons.move_child(quit_button, 2)
	for button in [start_button, settings_button, quit_button]:
		button.custom_minimum_size = Vector2(0, 70 if compact else 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 23 if compact else 20)
		UiStyle.apply_button(button, button == start_button)
	settings_button.text = "설정"
	var version_parent := version_label.get_parent()
	version_parent.remove_child(version_label)
	add_child(version_label)
	version_label.anchor_left = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -180.0
	version_label.offset_top = -32.0
	version_label.offset_right = -18.0
	version_label.offset_bottom = -8.0
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if notice_label:
		notice_label.add_theme_font_size_override("font_size", 13)

func _unhandled_input(event: InputEvent):
	if settings_ui and settings_ui.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_settings_btn_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_start_btn_pressed()
		get_viewport().set_input_as_handled()

func _on_start_btn_pressed():
	GameManager.go_to_character_select()

func _on_settings_btn_pressed():
	if settings_ui:
		settings_ui.call("open")

func _on_quit_btn_pressed():
	get_tree().quit()
