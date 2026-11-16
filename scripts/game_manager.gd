extends Node

signal state_changed(new_state)
signal time_updated(battle_time)
signal kill_count_changed(count)
signal location_changed(new_loc)

enum GameState { PLAYING, PAUSED, LEVEL_UP, GAME_OVER, VICTORY }
enum Location { TITLE, CHARACTER_SELECT, LOBBY, BATTLE, CARD_DECK }

var current_state: GameState = GameState.PLAYING
var current_location: Location = Location.TITLE
var battle_time: float = 0.0
var kill_count: int = 0
var max_battle_time: float = 300.0 # 5 minutes
var starting_draft_picks: int = 0
var _last_time_signal_second: int = -1

var stat_manager: StatManager = StatManager.new()
var skill_loadout: SkillLoadoutManager = SkillLoadoutManager.new()
var card_manager: CardManager = CardManager.new()
var deck_manager: DeckManager = DeckManager.new()
var tutorial: TutorialGuideManager = TutorialGuideManager.new()
var character_slots: CharacterSlotManager

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for manager in [skill_loadout, card_manager, deck_manager, tutorial]:
		add_child(manager)
	# Character slots are persisted by GameData. Keep this public reference for
	# existing systems that access the manager through GameManager.
	character_slots = GameData.character_slot_manager
	GameData.restore_active_auxiliary_state()
	card_manager.ensure_starter_collection()
	deck_manager.ensure_starter_deck(card_manager.owned)
	if GameData.character_profiles.is_empty() and not FileAccess.file_exists(GameData.SAVE_FILE_PATH) and not FileAccess.file_exists(GameData.SAVE_BACKUP_PATH):
		GameData.create_character_profile(0, GameData.FIGHTER_ID, "무도가")

func _process(delta: float):
	if current_location == Location.BATTLE and current_state == GameState.PLAYING:
		battle_time += delta
		if battle_time >= max_battle_time:
			victory()
			return
		var current_second := int(battle_time)
		if current_second != _last_time_signal_second:
			_last_time_signal_second = current_second
			time_updated.emit(battle_time)

func go_to_title():
	if current_location == Location.BATTLE:
		GameData.end_survival_run()
	starting_draft_picks = 0
	GameData.save_to_disk()
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
	if GameData.active_character_id.is_empty():
		go_to_character_select()
		return
	if current_location == Location.BATTLE:
		GameData.end_survival_run()
	starting_draft_picks = 0
	GameData.save_to_disk()
	current_location = Location.LOBBY
	current_state = GameState.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)
	location_changed.emit(current_location)
	SceneTransition.change_scene("res://scenes/stages/village_lobby.tscn")

func go_to_deck_builder():
	if GameData.active_character_id.is_empty():
		go_to_character_select()
		return
	current_location = Location.CARD_DECK
	current_state = GameState.PLAYING
	get_tree().paused = false
	SceneTransition.change_scene("res://scenes/ui/deck_builder.tscn")

func go_to_card_dungeon():
	if not deck_manager.validate_deck(card_manager.owned):
		return
	GameData.save_to_disk()
	current_location = Location.CARD_DECK
	current_state = GameState.PLAYING
	get_tree().paused = false
	SceneTransition.change_scene("res://scenes/ui/card_dungeon.tscn")

func go_to_battle(stage_id: String = "") -> bool:
	if stage_id != "":
		if not GameData.is_stage_unlocked(stage_id):
			return false
		GameData.current_selected_stage_id = stage_id
	elif not GameData.is_stage_unlocked(GameData.current_selected_stage_id):
		return false
	GameData.begin_survival_run()
	starting_draft_picks = 5
	battle_time = 0.0
	_last_time_signal_second = 0
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
	GameData.begin_survival_run()
	starting_draft_picks = 5
	current_state = GameState.PLAYING
	battle_time = 0.0
	_last_time_signal_second = 0
	kill_count = 0
	state_changed.emit(current_state)
	time_updated.emit(0.0)
	kill_count_changed.emit(0)
	get_tree().reload_current_scene()
