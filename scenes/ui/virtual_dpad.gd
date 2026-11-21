extends CanvasLayer
## One-touch analog stick. Diagonal input is represented directly by the drag angle.

var _root: Control
var _base: Panel
var _knob: Panel
var _base_style: StyleBoxFlat
var _knob_idle_style: StyleBoxFlat
var _knob_active_style: StyleBoxFlat
var _stick_center: Vector2 = Vector2.ZERO
var _stick_radius: float = 1.0
var _deadzone: float = 0.14
var _active_touch_id: int = -1
var _mouse_pressed: bool = false
var _move_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_base_style = _make_round_style(Color(0.025, 0.028, 0.035, 0.56), Color(0.77, 0.60, 0.38, 0.68), 2)
	_knob_idle_style = _make_round_style(Color(0.24, 0.19, 0.15, 0.82), Color(0.95, 0.77, 0.51, 0.88), 2)
	_knob_active_style = _make_round_style(Color(0.54, 0.27, 0.12, 0.94), Color(1.0, 0.84, 0.55, 1.0), 3)
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _make_round_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(999)
	return style


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_base = Panel.new()
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.add_theme_stylebox_override("panel", _base_style)
	_root.add_child(_base)
	_knob = Panel.new()
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.add_theme_stylebox_override("panel", _knob_idle_style)
	_base.add_child(_knob)


func _relayout() -> void:
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	var viewport_size: Vector2 = visible_rect.size
	var side: float = clampf(viewport_size.x * 0.31, 170.0, 220.0)
	var safe_left: float = 0.0
	var safe_top: float = 0.0
	var safe_bottom: float = 0.0
	if OS.has_feature("mobile"):
		var safe_area: Rect2i = DisplayServer.get_display_safe_area()
		if safe_area.size.x > 0 and safe_area.size.y > 0:
			var screen_to_viewport: Transform2D = get_viewport().get_screen_transform().affine_inverse()
			var safe_start: Vector2 = screen_to_viewport * Vector2(safe_area.position)
			var safe_end: Vector2 = screen_to_viewport * Vector2(safe_area.end)
			safe_left = maxf(0.0, safe_start.x - visible_rect.position.x)
			safe_top = maxf(0.0, safe_start.y - visible_rect.position.y)
			safe_bottom = maxf(0.0, visible_rect.end.y - safe_end.y)
	var left_margin: float = maxf(16.0, viewport_size.x * 0.035)
	var bottom_margin: float = clampf(viewport_size.y * 0.12, 100.0, 175.0)
	_base.position = Vector2(
		visible_rect.position.x + safe_left + left_margin,
		maxf(visible_rect.position.y + safe_top + 16.0, visible_rect.end.y - safe_bottom - bottom_margin - side)
	)
	_base.size = Vector2.ONE * side
	_stick_center = _base.size * 0.5
	_stick_radius = side * 0.32
	var knob_side: float = side * 0.36
	_knob.size = Vector2.ONE * knob_side
	_update_visual()


func _base_contains(viewport_position: Vector2) -> bool:
	return _base.get_global_rect().has_point(viewport_position)


func _update_from_position(viewport_position: Vector2) -> void:
	var local_position: Vector2 = _base.make_canvas_position_local(viewport_position)
	var displacement: Vector2 = local_position - _stick_center
	var distance: float = displacement.length()
	if distance <= _stick_radius * _deadzone:
		_move_vector = Vector2.ZERO
	else:
		var clamped_distance: float = minf(distance, _stick_radius)
		var strength: float = (clamped_distance / _stick_radius - _deadzone) / (1.0 - _deadzone)
		_move_vector = displacement.normalized() * clampf(strength, 0.0, 1.0)
	_update_visual()


func _update_visual() -> void:
	if _knob == null or not is_instance_valid(_knob):
		return
	var max_offset: float = maxf(0.0, _stick_radius - _knob.size.x * 0.5 - 3.0)
	var knob_center: Vector2 = _stick_center + _move_vector * max_offset
	_knob.position = knob_center - _knob.size * 0.5
	_knob.add_theme_stylebox_override("panel", _knob_active_style if _move_vector.length_squared() > 0.0 else _knob_idle_style)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if not get_tree().paused and _active_touch_id < 0 and _base_contains(touch.position):
				_active_touch_id = touch.index
				_update_from_position(touch.position)
				get_viewport().set_input_as_handled()
		elif touch.index == _active_touch_id:
			_active_touch_id = -1
			_move_vector = Vector2.ZERO
			_update_visual()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _active_touch_id:
			_update_from_position(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not GameActions.is_mobile():
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed and not get_tree().paused and not _mouse_pressed and _base_contains(mouse_event.position):
			_mouse_pressed = true
			_update_from_position(mouse_event.position)
			get_viewport().set_input_as_handled()
		elif not mouse_event.pressed and _mouse_pressed:
			_mouse_pressed = false
			_move_vector = Vector2.ZERO
			_update_visual()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_pressed:
		_update_from_position((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if get_tree().paused and (_active_touch_id >= 0 or _mouse_pressed):
		_active_touch_id = -1
		_mouse_pressed = false
		_move_vector = Vector2.ZERO
		_update_visual()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_touch_move"):
		player.call("set_touch_move", _move_vector)


func _exit_tree() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_touch_move"):
		player.call("set_touch_move", Vector2.ZERO)
