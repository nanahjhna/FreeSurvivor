extends CanvasLayer

@onready var kill_stat: Label = $CenterContainer/VBoxContainer/Stats/KillStat
@onready var time_stat: Label = $CenterContainer/VBoxContainer/Stats/TimeStat

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state):
	if new_state == GameManager.GameState.VICTORY:
		kill_stat.text = "처치한 몬스터: " + str(GameManager.kill_count)
		time_stat.text = "생존 시간: 05:00 (클리어!)"
		visible = true
	else:
		visible = false

func _on_restart_pressed():
	GameManager.restart()
