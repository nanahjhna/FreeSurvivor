extends Area3D

func _ready():
	name = "ReturnPortal"
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player") and GameManager.current_state == GameManager.GameState.PLAYING:
		UiFeedback.confirm_with_cancel(
			"마을로 귀환",
			"던전을 마치고 마을로 돌아갈까요?",
			GameManager.confirm_return_to_town,
			Callable()
		)
