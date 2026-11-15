extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.state_changed.connect(_on_state_changed)

func _input(event: InputEvent):
	if event.is_action_pressed("pause"):
		GameManager.toggle_pause()

func _on_state_changed(new_state):
	if new_state == GameManager.GameState.PAUSED:
		visible = true
	else:
		visible = false

func _on_resume_button_pressed():
	GameManager.resume_game()

func _on_restart_button_pressed():
	GameManager.restart()
