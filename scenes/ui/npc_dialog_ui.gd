extends CanvasLayer

signal closed()
signal option_selected(action_id: String)

var _name_label: Label
var _role_label: Label
var _line_label: Label
var _options_box: VBoxContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35
	visible = false
	_build_ui()

func _build_ui():
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)

	var margin := UiStyle.make_margin(panel, 26)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_name_label = UiStyle.make_title("NPC", 26)
	vbox.add_child(_name_label)
	_role_label = UiStyle.make_label("", 14, Color(0.65, 0.82, 1.0))
	vbox.add_child(_role_label)
	vbox.add_child(HSeparator.new())
	_line_label = UiStyle.make_label("", 16, Color(0.92, 0.94, 1.0))
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(540, 80)
	vbox.add_child(_line_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_options_box)

	var close := UiStyle.make_button("← 닫기 [ESC]", Vector2(150, 42))
	close.pressed.connect(close_screen)
	vbox.add_child(close)

func open(npc_name: String, role: String, line: String, options: Array):
	visible = true
	_name_label.text = npc_name
	_role_label.text = role
	_line_label.text = line
	for child in _options_box.get_children():
		child.queue_free()
	for option in options:
		var button := UiStyle.make_button(str(option.get("label", "대화")), Vector2(0, 46), true)
		var action := str(option.get("action", ""))
		button.pressed.connect(func(): _choose(action))
		_options_box.add_child(button)

func close_screen():
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

func _choose(action_id: String):
	close_screen()
	if action_id != "":
		option_selected.emit(action_id)
