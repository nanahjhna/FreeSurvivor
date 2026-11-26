extends CanvasLayer
## Global feedback layer: toast messages, tooltips and confirmation dialogs.

var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: Timer

var _tooltip_panel: PanelContainer
var _tooltip_title: Label
var _tooltip_body: Label

var _confirm_root: Control
var _confirm_callback: Callable
var _confirm_title: Label
var _confirm_body: Label
var _save_label: Label
var _save_timer: Timer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_toast()
	_build_tooltip()
	_build_confirm()
	_build_save_status()
	GameData.save_status_changed.connect(_on_save_status_changed)

func _build_save_status():
	_save_label = UiStyle.make_label("", 13, Color(0.8, 0.9, 1.0))
	_save_label.anchor_left = 1.0
	_save_label.anchor_right = 1.0
	_save_label.offset_left = -210.0
	_save_label.offset_right = -24.0
	_save_label.offset_top = 24.0
	_save_label.offset_bottom = 54.0
	_save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_label.visible = false
	add_child(_save_label)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.timeout.connect(func(): _save_label.visible = false)
	add_child(_save_timer)

func _on_save_status_changed(status: String):
	_save_label.visible = true
	match status:
		"saving": _save_label.text = "💾 저장 중..."
		"saved":
			_save_label.text = "✅ 저장 완료"
			_save_timer.start(1.4)
		"failed":
			_save_label.text = "⛔ 저장 실패"
			_save_timer.start(4.0)
			show_error("저장하지 못했습니다. 기존 백업은 유지됩니다. 다시 시도해 주세요.")

# ------------------------------------------------------------
# TOASTS
# ------------------------------------------------------------

func _build_toast():
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.offset_left = -310.0
	_toast_panel.offset_right = 310.0
	_toast_panel.offset_top = 108.0
	_toast_panel.offset_bottom = 176.0
	_toast_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.INK, UiStyle.RUST))
	add_child(_toast_panel)

	var margin := UiStyle.make_margin(_toast_panel, 14)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	_toast_label = UiStyle.make_label("", 15, Color(1.0, 0.96, 0.85))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_toast_label)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 2.6
	_toast_timer.timeout.connect(_hide_toast)
	add_child(_toast_timer)

func toast(text: String, color: Color = Color(1.0, 0.96, 0.85), duration: float = 2.6):
	if _toast_panel == null:
		return
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_panel.visible = true
	_toast_panel.modulate = Color(1, 1, 1, 0.0)
	var tween := create_tween()
	tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.15)
	_toast_timer.wait_time = duration
	_toast_timer.start()

func show_success(text: String):
	toast("✅ " + text, Color(0.55, 1.0, 0.62))

func show_error(text: String):
	toast("⛔ " + text, Color(1.0, 0.55, 0.5), 3.2)

func show_info(text: String):
	toast("💡 " + text, Color(0.85, 0.93, 1.0), 3.2)

func show_reward(title: String, lines: Array = []):
	var body := title
	if not lines.is_empty():
		body += "\n" + "\n".join(PackedStringArray(lines))
	toast("🎁 " + body, Color(1.0, 0.88, 0.4), 4.0)

func _hide_toast():
	if _toast_panel == null:
		return
	var tween := create_tween()
	tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): _toast_panel.visible = false)

# ------------------------------------------------------------
# TOOLTIPS
# ------------------------------------------------------------

func _build_tooltip():
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.custom_minimum_size = Vector2(280, 0)
	_tooltip_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.INK, UiStyle.STEEL, 1))
	add_child(_tooltip_panel)

	var margin := UiStyle.make_margin(_tooltip_panel, 14)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_tooltip_title = UiStyle.make_label("", 16, Color(1.0, 0.87, 0.45))
	vbox.add_child(_tooltip_title)

	_tooltip_body = UiStyle.make_label("", 13, Color(0.88, 0.92, 1.0))
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_body.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(_tooltip_body)

func show_tooltip(title: String, body: String, screen_position: Vector2):
	if _tooltip_panel == null:
		return
	_tooltip_title.text = title
	_tooltip_body.text = body
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(_tooltip_panel) or not _tooltip_panel.visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _tooltip_panel.size
	var pos := screen_position + Vector2(14, 14)
	pos.x = clampf(pos.x, 12.0, maxf(12.0, viewport_size.x - panel_size.x - 12.0))
	pos.y = clampf(pos.y, 12.0, maxf(12.0, viewport_size.y - panel_size.y - 12.0))
	_tooltip_panel.global_position = pos

func hide_tooltip():
	if _tooltip_panel:
		_tooltip_panel.visible = false

# ------------------------------------------------------------
# CONFIRMATION DIALOG
# ------------------------------------------------------------

func _build_confirm():
	_confirm_root = Control.new()
	_confirm_root.visible = false
	_confirm_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = UiStyle.SCRIM
	_confirm_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	center.add_child(panel)

	var margin := UiStyle.make_margin(panel, 26)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_confirm_title = UiStyle.make_title("확인", 24)
	vbox.add_child(_confirm_title)

	_confirm_body = UiStyle.make_label("", 15, Color(0.9, 0.93, 1.0))
	_confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_body.custom_minimum_size = Vector2(460, 0)
	vbox.add_child(_confirm_body)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	var cancel := UiStyle.make_button("취소", Vector2(120, 44))
	cancel.pressed.connect(_cancel_confirm)
	buttons.add_child(cancel)

	var ok := UiStyle.make_button("확인", Vector2(140, 44), true)
	ok.pressed.connect(_accept_confirm)
	buttons.add_child(ok)

func confirm(title: String, body: String, on_confirm: Callable):
	_confirm_title.text = title
	_confirm_body.text = body
	_confirm_callback = on_confirm
	_confirm_root.visible = true
	_confirm_root.move_to_front()

func _accept_confirm():
	_confirm_root.visible = false
	var cb := _confirm_callback
	_confirm_callback = Callable()
	if cb.is_valid():
		cb.call()

func _cancel_confirm():
	_confirm_root.visible = false
	_confirm_callback = Callable()

func _unhandled_input(event: InputEvent):
	if _confirm_root and _confirm_root.visible and event.is_action_pressed("ui_cancel"):
		_cancel_confirm()
		get_viewport().set_input_as_handled()
