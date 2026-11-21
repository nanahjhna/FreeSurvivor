extends Area3D

var _confirm_dialog: ConfirmationDialog

func _ready():
	name = "ReturnPortal"
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "마을로 귀환"
	_confirm_dialog.dialog_text = "던전을 마치고 마을로 돌아갈까요?"
	_confirm_dialog.ok_button_text = "귀환"
	_confirm_dialog.cancel_button_text = "계속 전투"
	_confirm_dialog.confirmed.connect(GameManager.confirm_return_to_town)
	add_child(_confirm_dialog)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player") and GameManager.current_state == GameManager.GameState.PLAYING:
		_confirm_dialog.popup_centered()
