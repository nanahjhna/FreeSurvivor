extends CanvasLayer
## On-screen arrow pad. Movement is arrow-key only on PC; mobile gets the same
## four directions as touch buttons.

var _dir := {
	"up": false, "down": false, "left": false, "right": false
}
var _buttons: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()

func _build():
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	root.offset_left = 24.0
	root.offset_top = -244.0
	root.offset_right = 234.0
	root.offset_bottom = -24.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := UiStyle.panel_style(Color(0.05, 0.07, 0.11, 0.55), Color(0.4, 0.6, 0.9, 0.6), 1)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var pad := Control.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pad)

	_add_direction(pad, "up", "▲", Vector2(72, 8))
	_add_direction(pad, "left", "◀", Vector2(8, 72))
	_add_direction(pad, "right", "▶", Vector2(136, 72))
	_add_direction(pad, "down", "▼", Vector2(72, 136))

	var hint := Label.new()
	hint.text = "이동"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.82, 1.0, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(72, 68)
	hint.size = Vector2(64, 64)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(hint)

func _add_direction(parent: Control, key: String, text: String, pos: Vector2):
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(64, 64)
	button.custom_minimum_size = Vector2(64, 64)
	button.add_theme_font_size_override("font_size", 24)
	UiStyle.apply_button(button)
	button.button_down.connect(func(): _set_dir(key, true))
	button.button_up.connect(func(): _set_dir(key, false))
	button.gui_input.connect(func(event):
		if event is InputEventScreenTouch and not event.pressed:
			_set_dir(key, false)
	)
	parent.add_child(button)
	_buttons[key] = button

func _set_dir(key: String, value: bool):
	_dir[key] = value

func _process(_delta: float):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_touch_move"):
		var vec := Vector2.ZERO
		if _dir.up: vec.y -= 1.0
		if _dir.down: vec.y += 1.0
		if _dir.left: vec.x -= 1.0
		if _dir.right: vec.x += 1.0
		player.call("set_touch_move", vec.limit_length(1.0))

func _exit_tree():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_touch_move"):
		player.call("set_touch_move", Vector2.ZERO)
