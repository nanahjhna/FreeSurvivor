extends CanvasLayer

@onready var kill_stat: Label = $CenterContainer/VBoxContainer/Stats/KillStat
@onready var time_stat: Label = $CenterContainer/VBoxContainer/Stats/TimeStat
@onready var gold_stat: Label = $CenterContainer/VBoxContainer/Stats/GoldStat
@onready var xp_stat: Label = $CenterContainer/VBoxContainer/Stats/XPStat
@onready var items_stat: Label = $CenterContainer/VBoxContainer/Stats/ItemsStat
@onready var subtitle: Label = $CenterContainer/VBoxContainer/Sub

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state):
	if new_state == GameManager.GameState.VICTORY:
		_refresh_result()
		visible = true
	else:
		visible = false

func _refresh_result():
	var result = GameData.last_battle_result
	var mins = int(result.get("time", 0.0)) / 60
	var secs = int(result.get("time", 0.0)) % 60
	subtitle.text = str(result.get("stage_name", "전투 지역")) + " 전투를 완료했습니다!"
	kill_stat.text = "처치한 몬스터: " + str(result.get("kills", 0))
	time_stat.text = "전투 시간: %02d:%02d" % [mins, secs]
	gold_stat.text = "획득 골드: +%d" % int(result.get("gold_earned", 0))
	xp_stat.text = "획득 경험치: +%d" % int(result.get("xp_earned", 0))
	var earned_items: Array = result.get("items_earned", [])
	var items_text = ", ".join(PackedStringArray(earned_items)) if not earned_items.is_empty() else "없음"
	items_stat.text = "획득 아이템: " + items_text

func _on_restart_pressed():
	GameManager.restart()

func _on_lobby_pressed():
	GameManager.go_to_lobby()
