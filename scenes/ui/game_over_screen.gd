extends CanvasLayer

@onready var kill_stat: Label = $CenterContainer/VBoxContainer/Stats/KillStat
@onready var time_stat: Label = $CenterContainer/VBoxContainer/Stats/TimeStat
@onready var gold_stat: Label = $CenterContainer/VBoxContainer/Stats/GoldStat
@onready var xp_stat: Label = $CenterContainer/VBoxContainer/Stats/XPStat
@onready var items_stat: Label = $CenterContainer/VBoxContainer/Stats/ItemsStat

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state):
	if new_state == GameManager.GameState.GAME_OVER:
		var mins = int(GameManager.battle_time) / 60
		var secs = int(GameManager.battle_time) % 60
		var result = GameData.last_battle_result
		kill_stat.text = "처치한 몬스터: " + str(result.get("kills", GameManager.kill_count))
		time_stat.text = "생존 시간: %02d:%02d" % [mins, secs]
		gold_stat.text = "획득 골드: +%d" % int(result.get("gold_earned", 0))
		xp_stat.text = "획득 경험치: +%d" % int(result.get("xp_earned", 0))
		var earned_items = result.get("items_earned", [])
		var items_text = ", ".join(PackedStringArray(earned_items)) if not earned_items.is_empty() else "없음"
		items_stat.text = "획득 아이템: " + items_text
		visible = true
	else:
		visible = false

func _on_restart_pressed():
	GameManager.restart()

func _on_lobby_pressed():
	GameManager.go_to_lobby()
