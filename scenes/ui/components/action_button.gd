class_name ActionButton
extends Button
## Reusable button: icon + label + shortcut badge + hover/long-press description.

var action_id: String = ""
var disabled_reason: String = ""
var _hold_timer: Timer
var _connected := false
var _long_pressed := false

func setup(id: String, compact: bool = false):
	action_id = id
	var def := GameActions.get_action(id)
	if def.is_empty():
		return
	UiStyle.apply_button(self)
	custom_minimum_size = Vector2(145, 46) if not compact else Vector2(116, 42)
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = 0.55
	_hold_timer.timeout.connect(func():
		_long_pressed = true
		_show_description()
	)
	add_child(_hold_timer)

	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	if not _connected:
		GameActions.bindings_changed.connect(_refresh_label)
		_connected = true
	_refresh_label()

func _refresh_label():
	var def := GameActions.get_action(action_id)
	if def.is_empty():
		return
	var shortcut := GameActions.get_shortcut_text(action_id)
	var text_value: String = "%s %s" % [def.get("icon", ""), def.get("label", "")]
	if shortcut != "":
		text_value += "  " + shortcut
	text = text_value
	tooltip_text = ""

func _on_pressed():
	UiFeedback.hide_tooltip()
	if _long_pressed:
		_long_pressed = false
		return
	GameActions.trigger(action_id)

func _on_mouse_entered():
	_show_description()

func _on_mouse_exited():
	_hold_timer.stop()
	UiFeedback.hide_tooltip()

func _show_description():
	if not is_visible_in_tree():
		return
	var def := GameActions.get_action(action_id)
	var body: String = def.get("desc", "")
	if disabled_reason != "":
		body += "\n\n⛔ " + disabled_reason
	var pos := get_global_rect().position + Vector2(0, size.y + 6)
	UiFeedback.show_tooltip(def.get("label", ""), body, pos)

func _on_gui_input(event: InputEvent):
	# Mouse users get descriptions on hover, so only touch needs a long press.
	if event is InputEventScreenTouch:
		if event.pressed:
			_long_pressed = false
			_hold_timer.start()
		else:
			_hold_timer.stop()
			UiFeedback.hide_tooltip()
	elif event is InputEventScreenDrag:
		_hold_timer.stop()
		UiFeedback.hide_tooltip()

func set_disabled_reason(reason: String):
	disabled_reason = reason
