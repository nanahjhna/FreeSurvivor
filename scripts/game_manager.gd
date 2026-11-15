extends Node

signal state_changed(new_state)
signal time_updated(battle_time)
signal kill_count_changed(count)

enum GameState { PLAYING, PAUSED, LEVEL_UP, GAME_OVER, VICTORY }
enum Location { LOBBY, BATTLE }

var current_state: GameState = GameState.PLAYING
var current_location: Location = Location.LOBBY
var battle_time: float = 0.0
var kill_count: int = 0
var max_battle_time: float = 300.0 # 5 minutes

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()

func _setup_inputs():
	var bindings = {
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"skill_q": [KEY_Q],
		"skill_w": [KEY_W],
		"skill_e": [KEY_E],
		"skill_r": [KEY_R],
		"item_1": [KEY_1],
		"item_2": [KEY_2],
		"item_3": [KEY_3],
		"pause": [KEY_ESCAPE]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var ev = InputEventKey.new()
			ev.physical_keycode = key
			# Check if already added
			var already_has = false
			for existing in InputMap.action_get_events(action):
				if existing is InputEventKey and existing.physical_keycode == key:
					already_has = true
					break
			if not already_has:
				InputMap.action_add_event(action, ev)


func _process(delta: float):
	if current_location == Location.BATTLE and current_state == GameState.PLAYING:
		battle_time += delta
		time_updated.emit(battle_time)
		if battle_time >= max_battle_time:
			victory()

func go_to_battle():
	battle_time = 0.0
	kill_count = 0
	current_location = Location.BATTLE
	current_state = GameState.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)
	time_updated.emit(0.0)
	kill_count_changed.emit(0)
	SceneTransition.change_scene("res://scenes/stages/stage_grassland.tscn")

func go_to_lobby():
	current_location = Location.LOBBY
	current_state = GameState.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)
	SceneTransition.change_scene("res://scenes/stages/village_lobby.tscn")

func add_kill():
	kill_count += 1
	kill_count_changed.emit(kill_count)

func toggle_pause():
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
	state_changed.emit(current_state)

func victory():
	if current_state == GameState.GAME_OVER or current_state == GameState.VICTORY:
		return
	current_state = GameState.VICTORY
	get_tree().paused = true
	state_changed.emit(current_state)

func restart():
	get_tree().paused = false
	current_state = GameState.PLAYING
	battle_time = 0.0
	kill_count = 0
	state_changed.emit(current_state)
	time_updated.emit(0.0)
	kill_count_changed.emit(0)
	get_tree().reload_current_scene()
