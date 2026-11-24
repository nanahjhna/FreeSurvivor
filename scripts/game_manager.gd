extends Node

signal state_changed(new_state)
signal time_updated(battle_time)
signal kill_count_changed(count)
signal location_changed(new_loc)
signal boss_defeated(defeated_count: int, next_reward_multiplier: float)

const FIRST_BOSS_TIME := 180.0

enum GameState { PLAYING, PAUSED, LEVEL_UP, BOSS_DECISION, GAME_OVER, VICTORY }
enum Location { TITLE, CHARACTER_SELECT, LOBBY, BATTLE, CARD_DECK }

var current_state: GameState = GameState.PLAYING
var current_location: Location = Location.TITLE
var battle_time: float = 0.0
var kill_count: int = 0
var max_battle_time: float = INF
var dungeon_gold: int = 0
var run_settled: bool = false
var boss_defeated_count: int = 0
var boss_decision_pending: bool = false
var boss_reward_multiplier: float = 1.0
var next_boss_time: float = FIRST_BOSS_TIME
var starting_draft_picks: int = 0
var level_card_picks: int = 0
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
		var current_second := int(battle_time)
		if current_second != _last_time_signal_second:
			_last_time_signal_second = current_second
			time_updated.emit(battle_time)

func go_to_title():
	if current_location == Location.BATTLE:
		GameData.end_survival_run()
	starting_draft_picks = 0
	level_card_picks = 0
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
	level_card_picks = 0
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
	starting_draft_picks = 10
	level_card_picks = 0
	dungeon_gold = 0
	run_settled = false
	boss_defeated_count = 0
	boss_decision_pending = false
	boss_reward_multiplier = 1.0
	next_boss_time = FIRST_BOSS_TIME
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
	settle_dungeon(false)
	state_changed.emit(current_state)

func victory():
	if current_state == GameState.GAME_OVER or current_state == GameState.VICTORY:
		return
	current_state = GameState.VICTORY
	get_tree().paused = true
	# Calculate and record result
	GameData.record_battle_result(true, battle_time, kill_count)
	state_changed.emit(current_state)

func add_dungeon_gold(amount: int):
	if run_settled or amount <= 0:
		return
	dungeon_gold += amount
	time_updated.emit(battle_time)

func settle_dungeon(returned_to_town: bool) -> int:
	if run_settled:
		return 0
	run_settled = true
	var paid := dungeon_gold if returned_to_town else int(floor(float(dungeon_gold) * 0.5))
	GameData.record_infinite_dungeon_result(battle_time, kill_count, paid, returned_to_town)
	return paid

func register_boss_defeat():
	if current_location != Location.BATTLE or boss_decision_pending or current_state != GameState.PLAYING:
		return
	if _is_battle_player_dead():
		return
	boss_defeated_count += 1
	boss_reward_multiplier = 1.0 + float(boss_defeated_count) * 0.5
	boss_decision_pending = true
	current_state = GameState.BOSS_DECISION
	get_tree().paused = true
	boss_defeated.emit(boss_defeated_count, boss_reward_multiplier)
	state_changed.emit(current_state)

func continue_boss_chain():
	if not boss_decision_pending or current_state != GameState.BOSS_DECISION:
		return
	boss_decision_pending = false
	next_boss_time = battle_time + 60.0
	current_state = GameState.PLAYING
	get_tree().paused = false
	time_updated.emit(battle_time)
	state_changed.emit(current_state)

func decline_boss_chain():
	if not boss_decision_pending:
		return
	boss_decision_pending = false
	confirm_return_to_town()

func create_return_portal() -> bool:
	if current_location != Location.BATTLE or get_tree().current_scene.find_child("ReturnPortal", true, false):
		return false
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if camera == null or player == null:
		return false
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_end := ray_origin + camera.project_ray_normal(screen_center) * 30.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [player.get_rid()]
	query.collision_mask = 32
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var spawn_pos: Vector3
	if hit.is_empty():
		spawn_pos = player.global_position + -player.global_transform.basis.z * 3.0
		spawn_pos.y = player.global_position.y
	else:
		spawn_pos = hit.position
		if spawn_pos.distance_to(player.global_position) > 12.0:
			spawn_pos = player.global_position + (spawn_pos - player.global_position).normalized() * 8.0
	var portal := preload("res://scenes/stages/return_portal.tscn").instantiate()
	get_tree().current_scene.add_child(portal)
	portal.global_position = spawn_pos
	return true

func confirm_return_to_town():
	if current_location != Location.BATTLE or run_settled or current_state in [GameState.GAME_OVER, GameState.VICTORY]:
		return
	if _is_battle_player_dead():
		return
	current_state = GameState.VICTORY
	get_tree().paused = true
	settle_dungeon(true)
	state_changed.emit(current_state)

func _is_battle_player_dead() -> bool:
	var player := get_tree().get_first_node_in_group("player") as PlayerCharacter
	return player != null and player.is_dead

func restart():
	get_tree().paused = false
	GameData.begin_survival_run()
	starting_draft_picks = 10
	level_card_picks = 0
	dungeon_gold = 0
	run_settled = false
	boss_defeated_count = 0
	boss_decision_pending = false
	boss_reward_multiplier = 1.0
	next_boss_time = FIRST_BOSS_TIME
	current_state = GameState.PLAYING
	battle_time = 0.0
	_last_time_signal_second = 0
	kill_count = 0
	state_changed.emit(current_state)
	time_updated.emit(0.0)
	kill_count_changed.emit(0)
	get_tree().reload_current_scene()
