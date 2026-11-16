extends CanvasLayer

@onready var kill_stat: Label = $CenterContainer/VBoxContainer/Stats/KillStat
@onready var time_stat: Label = $CenterContainer/VBoxContainer/Stats/TimeStat
@onready var level_stat: Label = $CenterContainer/VBoxContainer/Stats/LevelStat
@onready var gold_stat: Label = $CenterContainer/VBoxContainer/Stats/GoldStat
@onready var xp_stat: Label = $CenterContainer/VBoxContainer/Stats/XPStat
@onready var cards_stat: Label = $CenterContainer/VBoxContainer/Stats/CardsStat
@onready var items_stat: Label = $CenterContainer/VBoxContainer/Stats/ItemsStat
@onready var record_stat: Label = $CenterContainer/VBoxContainer/Stats/RecordStat

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
		level_stat.text = "도달 서바이벌 레벨: Lv.%d" % int(result.get("survival_level", 1))
		gold_stat.text = "획득 골드: +%d" % int(result.get("gold_earned", 0))
		xp_stat.text = "획득 성장 재화: +%d" % int(result.get("growth_currency_earned", 0))
		var earned_cards: Array = result.get("cards_earned", [])
		cards_stat.text = "획득 카드: " + (", ".join(PackedStringArray(earned_cards)) if not earned_cards.is_empty() else "없음")
		var earned_items = result.get("items_earned", [])
		var items_text = ", ".join(PackedStringArray(earned_items)) if not earned_items.is_empty() else "없음"
		items_stat.text = "획득 아이템: " + items_text
		var new_records: Array[String] = []
		if bool(result.get("new_best_time", false)): new_records.append("최고 생존 시간")
		if bool(result.get("new_best_level", false)): new_records.append("최고 서바이벌 레벨")
		record_stat.text = "🏆 최고 기록 갱신: " + (", ".join(PackedStringArray(new_records)) if not new_records.is_empty() else "없음")
		visible = true
	else:
		visible = false

func _on_restart_pressed():
	GameManager.restart()

func _on_lobby_pressed():
	GameManager.go_to_lobby()
