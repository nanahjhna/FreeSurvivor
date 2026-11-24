extends Control

@onready var start_button: Button = $Center/VBox/Buttons/StartBtn
@onready var settings_button: Button = $Center/VBox/Buttons/SettingsBtn
@onready var quit_button: Button = $Center/VBox/Buttons/QuitBtn
@onready var settings_ui: CanvasLayer = $SettingsUI
@onready var version_label: Label = $BottomLeft/VersionLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.current_location = GameManager.Location.TITLE
	start_button.text = "게임 시작"
	settings_button.text = "환경 설정"
	quit_button.text = "종료"
	version_label.text = "v1.0.0"
	UiStyle.skin_button(start_button, Color("#ffbe43"), Color("#ffe9a8"), Color("#4e2a1e"))
	start_button.add_theme_font_size_override("font_size", 30)
	var buttons := $Center/VBox/Buttons as VBoxContainer
	var utilities := HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 10)
	buttons.add_child(utilities)
	for button in [settings_button, quit_button]:
		button.reparent(utilities, false)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiStyle.skin_button(button, Color("#27254e"), Color("#827ab2"))
		button.add_theme_font_size_override("font_size", 20)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	var safe := UiStyle.safe_insets(get_viewport())
	var portrait := viewport_size.y >= viewport_size.x
	UiStyle.apply_safe_margins($Center, 24)
	$Center.add_theme_constant_override("margin_top", ceili(safe.y + viewport_size.y * 0.053))
	$Center.add_theme_constant_override("margin_bottom", ceili(safe.w + viewport_size.y * 0.065))
	$Center/VBox/Buttons.custom_minimum_size.x = minf(viewport_size.x - 48 - safe.x - safe.z, 432)
	$Center/VBox/TitleGroup/MainTitle.add_theme_font_size_override("font_size", 106 if portrait else 74)
	$Center/VBox/TitleGroup/SecondTitle.add_theme_font_size_override("font_size", 82 if portrait else 56)
	$BottomLeft.offset_left = 24 + safe.x
	$BottomLeft.offset_top = -38 - safe.w

func _unhandled_input(event: InputEvent) -> void:
	if settings_ui.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_settings_btn_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_start_btn_pressed()
		get_viewport().set_input_as_handled()


func _on_start_btn_pressed() -> void:
	GameManager.go_to_character_select()


func _on_settings_btn_pressed() -> void:
	settings_ui.call("open")


func _on_quit_btn_pressed() -> void:
	get_tree().quit()
