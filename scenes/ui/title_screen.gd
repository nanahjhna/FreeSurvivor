extends Control

const REFERENCE_SCREEN := preload("res://scripts/reference_screen.gd")

@onready var start_button: Button = $Center/VBox/Buttons/StartBtn
@onready var settings_button: Button = $Center/VBox/Buttons/SettingsBtn
@onready var quit_button: Button = $Center/VBox/Buttons/QuitBtn
@onready var settings_ui: CanvasLayer = $SettingsUI
@onready var version_label: Label = $BottomLeft/VersionLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.current_location = GameManager.Location.TITLE
	start_button.text = "게스트로 시작"
	settings_button.text = "환경 설정"
	quit_button.text = "종료"
	version_label.text = "v1.0.0"
	UiStyle.skin_button(start_button, UiStyle.CTA, UiStyle.CTA_EDGE, UiStyle.IVORY)
	start_button.add_theme_font_size_override("font_size", 30)
	$Center/VBox/TitleGroup/MainTitle.add_theme_color_override("font_color", UiStyle.IVORY)
	$Center/VBox/TitleGroup/SecondTitle.add_theme_color_override("font_color", UiStyle.IVORY)
	for label in [$Center/VBox/TitleGroup/MainTitle, $Center/VBox/TitleGroup/SecondTitle]:
		label.add_theme_color_override("font_outline_color", UiStyle.ASPHALT)
		label.add_theme_color_override("font_shadow_color", UiStyle.ASPHALT)
	for button in [settings_button, quit_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiStyle.skin_button(button, UiStyle.INK_SOFT, UiStyle.RUST, UiStyle.IVORY)
		button.add_theme_font_size_override("font_size", 25)
	get_viewport().size_changed.connect(_layout)
	_layout()
	var approved := REFERENCE_SCREEN.new()
	approved.build(self, "title")
	approved.relay(Rect2(72, 604, 414, 86), start_button)
	approved.relay(Rect2(72, 705, 414, 76), settings_button)
	approved.relay(Rect2(72, 798, 414, 76), quit_button)
	$Center.hide()
	$BottomLeft.hide()


func prepare_transition(report_progress: Callable) -> void:
	await report_progress.call(77.0, "타이틀 화면 준비 중…")


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	var safe := UiStyle.safe_insets(get_viewport())
	var title_box := $Center/VBox as VBoxContainer
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var spacer := $Center/VBox/Spacer as Control
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spacer.custom_minimum_size.y = clampf(viewport_size.y * 0.028, 20.0, 42.0)
	UiStyle.apply_safe_margins($Center, 24)
	$Center.add_theme_constant_override("margin_top", ceili(safe.y + viewport_size.y * 0.053))
	$Center.add_theme_constant_override("margin_bottom", ceili(safe.w + viewport_size.y * 0.065))
	$Center/VBox/Buttons.custom_minimum_size.x = minf(viewport_size.x - 48 - safe.x - safe.z, 432)
	$Center/VBox/TitleGroup/MainTitle.add_theme_font_size_override("font_size", int(clampf(viewport_size.x * 0.155, 56, 106)))
	$Center/VBox/TitleGroup/SecondTitle.add_theme_font_size_override("font_size", int(clampf(viewport_size.x * 0.116, 42, 82)))
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
