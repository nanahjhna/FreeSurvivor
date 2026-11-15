extends Node

signal state_changed(new_state)
signal time_updated(battle_time)
signal kill_count_changed(count)
signal location_changed(new_loc)

enum GameState { PLAYING, PAUSED, LEVEL_UP, GAME_OVER, VICTORY }
enum Location { TITLE, CHARACTER_SELECT, LOBBY, BATTLE }

var current_state: GameState = GameState.PLAYING
var current_location: Location = Location.TITLE
var battle_time: float = 0.0
var kill_count: int = 0
var max_battle_time: float = 300.0 # 5 minutes

var stat_manager: StatManager = StatManager.new()
var skill_loadout: SkillLoadoutManager = SkillLoadoutManager.new()
var card_manager: CardManager = CardManager.new()
var deck_manager: DeckManager = DeckManager.new()
var tutorial: TutorialGuideManager = TutorialGuideManager.new()
var character_slots: CharacterSlotManager = CharacterSlotManager.new()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float):
	if current_location == Location.BATTLE and current_state == GameState.PLAYING:
		battle_time += delta
		time_updated.emit(battle_time)
		if battle_time >= max_battle_time:
			victory()

func go_to_title():
	current_location = Location.TITLE
	current_state = GameState.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)
	location_changed.emit(current_location)
	SceneTransition.change_scene("res://scenes/ui/title_screen.tscn")

func go_to_character_select():
	current_location = Location.CHARACTER_SELECT
	current_state = GameState.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)
	location_changed.emit(current_location)
	SceneTransition.change_scene("res://scenes/ui/character_select.tscn")

func go_to_lobby():
	current_location = Location.LOBBY
	current_state = GameState.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)
	location_changed.emit(current_location)
	SceneTransition.change_scene("res://scenes/stages/village_lobby.tscn")

func go_to_battle(stage_id: String = "") -> bool:
	if stage_id != "":
		if not GameData.is_stage_unlocked(stage_id):
			return false
		GameData.current_selected_stage_id = stage_id
	elif not GameData.is_stage_unlocked(GameData.current_selected_stage_id):
		return false
	GameData.reset_data()
	battle_time = 0.0
	kill_count = 0
	current_location = Location.BATTLE
	current_state = GameState.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)
	location_changed.emit(current_location)
	time_updated.emit(0.0)
	kill_count_changed.emit(0)

	var stage_info = GameData.stages.get(GameData.current_selected_stage_id, GameData.stages["stage_1"])
	var scene_path = stage_info.get("scene", "res://scenes/stages/stage_grassland.tscn")
	SceneTransition.change_scene(scene_path)
	return true

func add_kill():
	kill_count += 1
	kill_count_changed.emit(kill_count)

func toggle_pause():
	if current_location != Location.BATTLE:
		return
	if current_state == GameState.PLAYING:
		pause_game()
	elif current_state == GameState.PAUSED:
		resume_game()

func pause_game():
	if current_state != GameState.PLAYING:
		return
	current_state = GameState.PAUSED
	get_tree().paused = true
	state_changed.emit(current_state)

func resume_game():
	if current_state != GameState.PAUSED:
		return
	current_state = GameState.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)

func enter_level_up():
	if current_state != GameState.PLAYING:
		return
	current_state = GameState.LEVEL_UP
	get_tree().paused = true
	state_changed.emit(current_state)

func exit_level_up():
	if current_state != GameState.LEVEL_UP:
		return
	current_state = GameState.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)

func game_over():
	if current_state == GameState.GAME_OVER or current_state == GameState.VICTORY:
		return
	current_state = GameState.GAME_OVER
	get_tree().paused = true
	# Calculate and record result
	GameData.record_battle_result(false, battle_time, kill_count)
	state_changed.emit(current_state)

func victory():
	if current_state == GameState.GAME_OVER or current_state == GameState.VICTORY:
		return
	current_state = GameState.VICTORY
	get_tree().paused = true
	# Calculate and record result
	GameData.record_battle_result(true, battle_time, kill_count)
	state_changed.emit(current_state)

func restart():
	get_tree().paused = false
	GameData.reset_data()
	current_state = GameState.PLAYING
	battle_time = 0.0
	kill_count = 0
	state_changed.emit(current_state)
	time_updated.emit(0.0)
	kill_count_changed.emit(0)
	get_tree().reload_current_scene()
