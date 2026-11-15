extends CanvasLayer

@onready var settings_ui = $SettingsUI
@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var lobby_button: Button = $CenterContainer/VBoxContainer/LobbyButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.state_changed.connect(_on_state_changed)
	_style_buttons()

func _style_buttons():
	for button in [resume_button, restart_button, settings_button, lobby_button]:
		if button:
			UiStyle.apply_button(button, button == resume_button)
	if resume_button:
		resume_button.text = "▶ 계속하기 [ESC]"
	if restart_button:
		restart_button.text = "🔄 다시 시작"
	if settings_button:
		settings_button.text = "⚙️ 설정"
	if lobby_button:
		lobby_button.text = "🏰 마을로 복귀"

func _input(event: InputEvent):
	if settings_ui and settings_ui.visible:
		return
	if event.is_action_pressed("pause") and not GameActions.is_capturing():
		GameManager.toggle_pause()

func _on_state_changed(new_state):
	if new_state == GameManager.GameState.PAUSED:
		visible = true
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
