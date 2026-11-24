extends "res://scenes/ui/game_over_screen.gd"


func _result_state() -> int:
	return GameManager.GameState.VICTORY
