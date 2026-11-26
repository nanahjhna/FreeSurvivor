extends CanvasLayer

const REFERENCE_SCREEN := preload("res://scripts/reference_screen.gd")
var approved: REFERENCE_SCREEN

@onready var settings_ui = $SettingsUI
@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var lobby_button: Button = $CenterContainer/VBoxContainer/LobbyButton
var pause_content: VBoxContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.state_changed.connect(_on_state_changed)
	_style_buttons()
	_build_pause_panel()
	$CenterContainer.hide()

func _style_buttons():
	for button in [resume_button, restart_button, settings_button, lobby_button]:
		UiStyle.apply_button(button, button == resume_button)
		button.custom_minimum_size.y = 60
		button.add_theme_font_size_override("font_size", 21)
	resume_button.text = "전투 계속"
	restart_button.text = "다시 시작"
	settings_button.text = "환경 설정"
	lobby_button.text = "마을 복귀"
	UiStyle.button_icon(resume_button, "play", 27)
	UiStyle.button_icon(restart_button, "restart", 27)
	UiStyle.button_icon(settings_button, "settings", 27)
	UiStyle.button_icon(lobby_button, "home", 27)

func _build_pause_panel() -> void:
	$ColorRect.color = UiStyle.SCRIM
	var center := $CenterContainer as CenterContainer
	var content := $CenterContainer/VBoxContainer as VBoxContainer
	pause_content = content
	var title := content.get_node("Title") as Label
	title.add_theme_color_override("font_color", UiStyle.IVORY)
	title.add_theme_font_size_override("font_size", 34)
	UiStyle.ink_outline(title, 2)
	var band := UiStyle.notice_board()
	content.add_child(band)
	content.move_child(band, 0)
	title.reparent(band, false)
	content.add_theme_constant_override("separation", 12)
	UiStyle.divider(content)
	content.move_child(content.get_child(-1), 1)
	var card := UiStyle.make_panel()
	center.add_child(card)
	content.reparent(UiStyle.make_margin(card, 24), false)
	var fit := func():
		var safe := UiStyle.safe_insets(get_viewport())
		card.custom_minimum_size.x = minf(420, get_viewport().get_visible_rect().size.x - safe.x - safe.z - 48)
		center.offset_left = safe.x
		center.offset_right = -safe.z
		center.offset_top = safe.y
		center.offset_bottom = -safe.w
	get_viewport().size_changed.connect(fit)
	fit.call()

func _input(event: InputEvent):
	if settings_ui and settings_ui.visible:
		return
	if event.is_action_pressed("pause") and not GameActions.is_capturing():
		GameManager.toggle_pause()

func _on_state_changed(new_state):
	if new_state == GameManager.GameState.PAUSED:
		visible = true
		if approved == null:
			approved = REFERENCE_SCREEN.new()
			approved.build(self, "pause", false)
			approved.image(Rect2(75, 219, 419, 519), Rect2(75, 219, 419, 519))
			approved.relay(Rect2(103, 333, 366, 85), resume_button)
			approved.relay(Rect2(103, 430, 366, 80), restart_button)
			approved.relay(Rect2(103, 526, 366, 79), settings_button)
			approved.relay(Rect2(103, 622, 366, 80), lobby_button)
	else:
		visible = false

func _on_resume_button_pressed():
	GameManager.resume_game()

func _on_restart_button_pressed():
	UiFeedback.confirm(
		"다시 시작",
		"현재 전투를 처음부터 다시 시작합니다. 진행 중인 보상은 사라집니다.",
		func(): GameManager.restart()
	)

func _on_settings_button_pressed():
	settings_ui.call("open")

func _on_lobby_button_pressed():
	UiFeedback.confirm(
		"마을로 복귀",
		"전투를 포기하고 마을로 돌아가시겠습니까?",
		func(): GameManager.go_to_lobby()
	)
