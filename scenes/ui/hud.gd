extends CanvasLayer

@onready var hp_bar: ProgressBar = $TopLeft/Bars/HPBar
@onready var hp_label: Label = $TopLeft/Bars/HPBar/Label
@onready var exp_bar: ProgressBar = $TopLeft/Bars/EXPBar
@onready var level_label: Label = $TopLeft/PortraitPanel/LevelLabel
@onready var time_label: Label = $TopCenter/TimeLabel
@onready var stage_label: Label = $TopCenter/StageLabel
@onready var kill_label: Label = $TopRight/KillContainer/KillLabel

# Offscreen warning overlay
@onready var indicator_overlay: Control = $IndicatorOverlay
@onready var pause_button: Button = $TopRight/PauseButton

var player_node: Node3D = null
var skill_manager: Node = null
var dpad: CanvasLayer = null

var auto_battle_button: Button
var dungeon_gold_label: Label
var top_status_panel: PanelContainer
var action_dock: PanelContainer
var bottom_stats_panel: PanelContainer
var camera_zoom_control: HBoxContainer
var encounter_strip: VBoxContainer
var encounter_label: Label
var boss_health: ProgressBar
var boss_target: Node3D
var _boss_scan_timer := 0.0
var _indicator_update_timer: float = 0.0
var _hud_editor: PanelContainer
var _hud_target: Control
var _hud_controls: Dictionary = {}
var _hud_defaults: Dictionary = {}
var _hud_before_edit: Dictionary = {}
var _hud_dragging := false
var _hud_drag_offset := Vector2.ZERO
var _hud_old_layer := 0
var _hud_preset := 0
var _hud_size_slider: HSlider
var _hud_alpha_slider: HSlider
var _hud_visible_check: CheckButton
var _hud_overlap_label: Label
const HUD_CONFIG_PATH := "user://hud_layout.cfg"

var _skill_panels: Dictionary = {}
var boss_choice_dialog: ConfirmationDialog

const VIRTUAL_DPAD: PackedScene = preload("res://scenes/ui/virtual_dpad.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_signals()
	_style_action_panels()
	_build_infinite_dungeon_controls()
	_build_encounter_strip()
	_build_battle_action_bar()
	_build_boss_choice_dialog()
	_build_mobile_dpad()
	_layout_battle_hud()
	_register_hud_controls()
	_load_active_hud_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)
	GameActions.action_requested.connect(_on_action_requested)
	GameActions.input_mode_changed.connect(_build_mobile_dpad)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	_update_skill_slot_labels()
	_on_time_updated(GameManager.battle_time)
	_on_leveled_up(GameData.player_level)

func _connect_signals():
	GameManager.time_updated.connect(_on_time_updated)
	GameManager.kill_count_changed.connect(_on_kill_count_changed)
	GameData.data_updated.connect(_update_skill_slot_labels)

	player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		_setup_player(player_node)

func _setup_player(p: Node3D):
	if p.has_signal("hp_changed"):
		p.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(float(p.get("current_hp")), float(p.get("max_hp")))
	if p.has_signal("exp_changed"):
		p.exp_changed.connect(_on_exp_changed)
	if p.has_signal("leveled_up"):
		p.leveled_up.connect(_on_leveled_up)
	skill_manager = p.get_node_or_null("SkillManager")
	if skill_manager and skill_manager.has_signal("skill_cooldown_updated"):
		skill_manager.skill_cooldown_updated.connect(_on_skill_cooldown_updated)

func _process(delta: float):
	_boss_scan_timer = maxf(0.0, _boss_scan_timer - delta)
	if not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			_setup_player(player_node)

	_indicator_update_timer += delta
	if _indicator_update_timer >= 0.12:
		_indicator_update_timer = 0.0
		indicator_overlay.queue_redraw()
		_update_encounter_strip()

func _build_infinite_dungeon_controls():
	dungeon_gold_label = Label.new()
	dungeon_gold_label.name = "DungeonGoldLabel"
	dungeon_gold_label.add_theme_font_size_override("font_size", 14)
	dungeon_gold_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	dungeon_gold_label.text = "💰 0"
	add_child(dungeon_gold_label)

func _register_hud_controls():
	_hud_controls.clear()
	_hud_defaults.clear()
	_hud_controls["상단 상태 HUD"] = top_status_panel
	_hud_controls["보스 진행"] = encounter_strip
	_hud_controls["미니맵"] = $MinimapContainer
	_hud_controls["카메라 확대"] = camera_zoom_control
	_hud_controls["우측 스킬"] = action_dock
	_hud_controls["하단 처치·골드"] = bottom_stats_panel
	for control_name in _hud_controls:
		var control: Control = _hud_controls[control_name]
		_hud_defaults[control_name] = _capture_hud_control(control)

func _capture_hud_control(control: Control) -> Dictionary:
	return {"position": control.position, "size": control.size, "scale": control.scale, "modulate": control.modulate, "visible": control.visible, "mouse_filter": control.mouse_filter, "anchors": [control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom], "offsets": [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom]}

func begin_hud_edit():
	_hud_before_edit.clear()
	for key in _hud_controls:
		_hud_before_edit[key] = _capture_hud_control(_hud_controls[key])
	if _hud_editor:
		_hud_old_layer = layer
		layer = 30
		get_tree().paused = true
		_hud_editor.visible = true
		return
	_hud_old_layer = layer
	layer = 30
	get_tree().paused = true
	_hud_editor = PanelContainer.new()
	_hud_editor.name = "HudLayoutEditor"
	_hud_editor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud_editor.position = Vector2(16, 150)
	_hud_editor.custom_minimum_size = Vector2(300, 420)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_hud_editor.add_child(box)
	box.add_child(UiStyle.make_label("HUD 배치 편집 · 요소를 드래그하세요", 16, Color(1, 0.85, 0.35)))
	var select := OptionButton.new()
	for name in _hud_controls.keys(): select.add_item(str(name))
	select.item_selected.connect(_on_hud_target_selected)
	box.add_child(select)
	_hud_size_slider = _make_hud_slider(box, "크기", 0.6, 1.6, 1.0)
	_hud_size_slider.value_changed.connect(_on_hud_size_changed)
	_hud_alpha_slider = _make_hud_slider(box, "투명도", 0.2, 1.0, 1.0)
	_hud_alpha_slider.value_changed.connect(_on_hud_alpha_changed)
	_hud_visible_check = CheckButton.new()
	_hud_visible_check.text = "선택한 요소 표시"
	_hud_visible_check.button_pressed = true
	_hud_visible_check.toggled.connect(_on_hud_visibility_changed)
	box.add_child(_hud_visible_check)
	var presets := HBoxContainer.new()
	box.add_child(presets)
	for i in range(4):
		var b := Button.new()
		b.text = "기본" if i == 0 else "프리셋 %d" % i
		b.pressed.connect(_select_hud_preset.bind(i))
		presets.add_child(b)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var save_button := Button.new()
	save_button.text = "저장"
	save_button.pressed.connect(_save_hud_preset)
	actions.add_child(save_button)
	var reset_button := Button.new()
	reset_button.text = "기본 배치"
	reset_button.pressed.connect(_reset_hud_layout)
	actions.add_child(reset_button)
	var cancel_button := Button.new()
	cancel_button.text = "취소"
	cancel_button.pressed.connect(_cancel_hud_edit)
	actions.add_child(cancel_button)
	_hud_overlap_label = UiStyle.make_label("겹침 확인 중", 12, Color(1, 0.7, 0.5))
	box.add_child(_hud_overlap_label)
	add_child(_hud_editor)
	select.select(0)
	_on_hud_target_selected(0)
	_update_hud_overlap_warning()

func _make_hud_slider(parent: VBoxContainer, caption: String, minimum: float, maximum: float, initial: float) -> HSlider:
	parent.add_child(UiStyle.make_label(caption, 13))
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = initial
	parent.add_child(slider)
	return slider

func _on_hud_target_selected(index: int):
	if index < 0 or index >= _hud_controls.size(): return
	var key: String = _hud_controls.keys()[index]
	_hud_target = _hud_controls[key]
	_hud_target.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_size_slider.value = _hud_target.scale.x
	_hud_alpha_slider.value = _hud_target.modulate.a
	_hud_visible_check.button_pressed = _hud_target.visible

func _move_hud_target(position: Vector2):
	var screen := get_viewport().get_visible_rect().size
	var scaled_size := _hud_target.size * _hud_target.scale
	_hud_target.global_position = Vector2(clampf(position.x, 0.0, maxf(0.0, screen.x - scaled_size.x)), clampf(position.y, 0.0, maxf(0.0, screen.y - scaled_size.y)))
	_hud_target.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_update_hud_overlap_warning()

func _input(event: InputEvent):
	if _hud_editor == null or not _hud_editor.visible or _hud_target == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := get_viewport().get_mouse_position()
		if event.pressed and not _hud_editor.get_global_rect().has_point(mouse) and _hud_target.get_global_rect().has_point(mouse):
			_hud_dragging = true
			_hud_drag_offset = mouse - _hud_target.global_position
		elif not event.pressed:
			_hud_dragging = false
	elif event is InputEventMouseMotion and _hud_dragging:
		_move_hud_target(get_viewport().get_mouse_position() - _hud_drag_offset)
	elif event is InputEventScreenTouch:
		if event.pressed and not _hud_editor.get_global_rect().has_point(event.position) and _hud_target.get_global_rect().has_point(event.position):
			_hud_dragging = true
			_hud_drag_offset = event.position - _hud_target.global_position
		else:
			_hud_dragging = false
	elif event is InputEventScreenDrag and _hud_dragging:
		_move_hud_target(event.position - _hud_drag_offset)

func _on_hud_size_changed(value: float):
	if _hud_target: _hud_target.scale = Vector2.ONE * value
	_update_hud_overlap_warning()

func _on_hud_alpha_changed(value: float):
	if _hud_target: _hud_target.modulate.a = value

func _on_hud_visibility_changed(value: bool):
	if _hud_target: _hud_target.visible = value

func _select_hud_preset(index: int):
	_hud_preset = index
	if index == 0:
		_reset_hud_layout()
	else:
		_load_hud_layout(index)

func _save_hud_preset():
	var config := ConfigFile.new()
	config.load(HUD_CONFIG_PATH)
	config.set_value("meta", "active_preset", _hud_preset)
	if _hud_preset == 0:
		config.save(HUD_CONFIG_PATH)
		_hud_editor.visible = false
		_restore_hud_mouse_filters()
		layer = _hud_old_layer
		return
	for key in _hud_controls:
		var c: Control = _hud_controls[key]
		var screen := get_viewport().get_visible_rect().size
		config.set_value("preset_%d" % _hud_preset, str(key), {"x": c.global_position.x / screen.x, "y": c.global_position.y / screen.y, "scale": c.scale.x, "alpha": c.modulate.a, "visible": c.visible})
	config.save(HUD_CONFIG_PATH)
	_hud_editor.visible = false
	_restore_hud_mouse_filters()
	layer = _hud_old_layer

func _load_active_hud_layout():
	var config := ConfigFile.new()
	if config.load(HUD_CONFIG_PATH) != OK:
		return
	_hud_preset = clampi(int(config.get_value("meta", "active_preset", 0)), 0, 3)
	if _hud_preset > 0:
		_load_hud_layout(_hud_preset)

func _on_viewport_resized() -> void:
	if _hud_preset == 0:
		_layout_battle_hud()
		_register_hud_controls()

func _layout_battle_hud() -> void:
	var safe := UiStyle.safe_insets(get_viewport())
	var screen := get_viewport().get_visible_rect().size
	var compact := screen.x < 600.0
	top_status_panel.offset_left = 22 + safe.x
	top_status_panel.offset_right = -22 - safe.z
	top_status_panel.offset_top = 14 + safe.y
	top_status_panel.offset_bottom = 93 + safe.y
	bottom_stats_panel.offset_left = -200 - safe.z
	bottom_stats_panel.offset_right = -22 - safe.z
	bottom_stats_panel.offset_top = 36 + safe.y
	bottom_stats_panel.offset_bottom = 91 + safe.y
	var visible_skill_count := 0
	for skill_panel in _skill_panels.values():
		if (skill_panel as Control).visible:
			visible_skill_count += 1
	var dock_width := clampf(screen.x - safe.x - safe.z - 24.0, 260.0, 520.0)
	var skill_gap := 4.0 if compact else 8.0
	var slot_width := clampf((dock_width - maxf(0.0, float(visible_skill_count - 1)) * skill_gap) / maxf(1.0, float(visible_skill_count)), 54.0, 87.0)
	var slot_height := 66.0 if compact else 83.0
	var skill_list := action_dock.get_node_or_null("Controls/SkillList") as HBoxContainer
	if skill_list:
		skill_list.add_theme_constant_override("separation", int(skill_gap))
	for skill_panel in _skill_panels.values():
		(skill_panel as Control).custom_minimum_size = Vector2(slot_width, slot_height)
	var dock_height := slot_height + (48.0 if not compact else 44.0) + 12.0
	action_dock.offset_left = -dock_width * 0.5
	action_dock.offset_right = dock_width * 0.5
	action_dock.offset_top = -dock_height - safe.w
	action_dock.offset_bottom = -20 - safe.w
	encounter_strip.offset_top = 30 + safe.y
	encounter_strip.offset_bottom = 114 + safe.y
	$MinimapContainer.offset_top = 112 + safe.y
	$MinimapContainer.offset_bottom = 272 + safe.y
	$MinimapContainer.offset_left = -176 - safe.z
	$MinimapContainer.offset_right = -16 - safe.z
	camera_zoom_control.offset_top = 112 + safe.y
	camera_zoom_control.offset_bottom = 156 + safe.y

func _load_hud_layout(index: int):
	var config := ConfigFile.new()
	if config.load(HUD_CONFIG_PATH) != OK: return
	var section := "preset_%d" % index
	var screen := get_viewport().get_visible_rect().size
	var has_group_layout := config.has_section_key(section, "상단 상태 HUD") or config.has_section_key(section, "우측 스킬") or config.has_section_key(section, "하단 처치·골드")
	for key in _hud_controls:
		var value: Variant = config.get_value(section, str(key), {})
		if value is Dictionary and not value.is_empty():
			var c: Control = _hud_controls[key]
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.position = Vector2(float(value.get("x", 0.0)) * screen.x, float(value.get("y", 0.0)) * screen.y)
			c.scale = Vector2.ONE * float(value.get("scale", 1.0))
			c.modulate.a = float(value.get("alpha", 1.0))
			c.visible = bool(value.get("visible", true))
	if not has_group_layout:
		_load_legacy_hud_layout(config, section, screen)

func _load_legacy_hud_layout(config: ConfigFile, section: String, screen: Vector2):
	var legacy_map := {
			"TopLeft": "상단 상태 HUD",
		"MinimapContainer": "미니맵",
		"BottomCenter": "우측 스킬"
	}
	for legacy_key in legacy_map:
		var value: Variant = config.get_value(section, legacy_key, {})
		if not (value is Dictionary) or value.is_empty():
			continue
		var control: Control = _hud_controls[legacy_map[legacy_key]]
		control.set_anchors_preset(Control.PRESET_TOP_LEFT)
		control.position = Vector2(float(value.get("x", 0.0)) * screen.x, float(value.get("y", 0.0)) * screen.y)
		control.scale = Vector2.ONE * float(value.get("scale", 1.0))
		control.modulate.a = float(value.get("alpha", 1.0))
		control.visible = bool(value.get("visible", true))

func _reset_hud_layout():
	for key in _hud_controls:
		var c: Control = _hud_controls[key]
		var d: Dictionary = _hud_defaults[key]
		c.anchor_left = d.anchors[0]; c.anchor_top = d.anchors[1]; c.anchor_right = d.anchors[2]; c.anchor_bottom = d.anchors[3]
		c.offset_left = d.offsets[0]; c.offset_top = d.offsets[1]; c.offset_right = d.offsets[2]; c.offset_bottom = d.offsets[3]
		c.scale = d.scale; c.modulate = d.modulate; c.visible = d.visible
		c.mouse_filter = d.mouse_filter
	_update_hud_overlap_warning()

func _cancel_hud_edit():
	for key in _hud_controls:
		var c: Control = _hud_controls[key]
		var d: Dictionary = _hud_before_edit[key]
		c.anchor_left = d.anchors[0]; c.anchor_top = d.anchors[1]; c.anchor_right = d.anchors[2]; c.anchor_bottom = d.anchors[3]
		c.offset_left = d.offsets[0]; c.offset_top = d.offsets[1]; c.offset_right = d.offsets[2]; c.offset_bottom = d.offsets[3]
		c.scale = d.scale; c.modulate = d.modulate; c.visible = d.visible; c.mouse_filter = d.mouse_filter
	_hud_editor.queue_free()
	_hud_editor = null
	layer = _hud_old_layer

func _restore_hud_mouse_filters():
	for key in _hud_controls:
		_hud_controls[key].mouse_filter = _hud_defaults[key].mouse_filter

func _update_hud_overlap_warning():
	if _hud_overlap_label == null: return
	var overlap := false
	for a in _hud_controls.values():
		if not a.visible: continue
		for b in _hud_controls.values():
			if a == b or not b.visible: continue
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			if Rect2(a.global_position, a.size * a.scale).intersects(Rect2(b.global_position, b.size * b.scale)):
				overlap = true
	_hud_overlap_label.text = "⚠ HUD 요소가 겹칩니다" if overlap else "배치 정상"

# ------------------------------------------------------------
# ACTION BUTTONS (skills / items / combat controls)
# ------------------------------------------------------------

func _style_action_panels():
	_skill_panels = {
		"q": $BottomCenter/SkillContainer/SkillQ,
		"w": $BottomCenter/SkillContainer/SkillW,
		"e": $BottomCenter/SkillContainer/SkillE,
		"r": $BottomCenter/SkillContainer/SkillR
	}
	for key in _skill_panels:
		var skill_panel := _skill_panels[key] as Control
		skill_panel.custom_minimum_size = Vector2(87, 83)
		if skill_panel is Panel:
			skill_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.07, 0.13, 0.25, 0.93), Color("#80b8ef"), 3, 13))
		var action_id: String = "skill_" + str(key)
		_setup_panel(skill_panel, action_id, func(): _cast_skill(str(key)), _skill_tooltip.bind(str(key)))
	if pause_button:
		UiStyle.apply_button(pause_button)
		pause_button.text = "⏸"
		pause_button.tooltip_text = "전투 일시정지 [ESC]"

func _create_runtime_skill_panel(key: String) -> Panel:
	var panel := Panel.new()
	panel.name = "Skill" + key.to_upper()
	panel.custom_minimum_size = Vector2(48, 48)
	panel.add_theme_stylebox_override("panel", _flat_style(Color(0.045, 0.03, 0.028, 0.96), Color(0.65, 0.44, 0.23, 0.86), 1, 8))
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)
	var icon := Label.new()
	icon.name = "Icon"
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 20)
	stack.add_child(icon)
	var key_label := Label.new()
	key_label.name = "KeyLabel"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 10)
	stack.add_child(key_label)
	$BottomCenter/SkillContainer.add_child(panel)
	return panel

func _setup_panel(panel: Control, action_id: String, on_activate: Callable, tooltip_builder: Callable):
	if panel == null:
		return
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for child in panel.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hold_timer := Timer.new()
	hold_timer.one_shot = true
	hold_timer.wait_time = 0.55
	hold_timer.timeout.connect(func():
		panel.set_meta("long_pressed", true)
		var info_value: Variant = tooltip_builder.call()
		var info: Dictionary = info_value if info_value is Dictionary else {}
		UiFeedback.show_tooltip(str(info.get("title", "")), str(info.get("body", "")), panel.get_global_rect().position + Vector2(0, panel.size.y + 8))
	)
	panel.add_child(hold_timer)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			on_activate.call()
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch:
			if event.pressed:
				panel.set_meta("long_pressed", false)
				hold_timer.start()
				get_viewport().set_input_as_handled()
			else:
				hold_timer.stop()
				UiFeedback.hide_tooltip()
				if not bool(panel.get_meta("long_pressed", false)):
					on_activate.call()
				panel.set_meta("long_pressed", false)
				get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			hold_timer.stop()
			UiFeedback.hide_tooltip()
	)
	panel.mouse_entered.connect(func():
		var info_value: Variant = tooltip_builder.call()
		var info: Dictionary = info_value if info_value is Dictionary else {}
		UiFeedback.show_tooltip(str(info.get("title", "")), str(info.get("body", "")), panel.get_global_rect().position + Vector2(0, panel.size.y + 8))
	)
	panel.mouse_exited.connect(func(): UiFeedback.hide_tooltip())
	panel.set_meta("action_id", action_id)

func _build_battle_action_bar():
	_build_top_status_panel()
	_build_bottom_stats_panel()
	action_dock = PanelContainer.new()
	action_dock.name = "ActionDock"
	action_dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	action_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_dock.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(action_dock)
	var controls := VBoxContainer.new()
	controls.name = "Controls"
	controls.add_theme_constant_override("separation", 12)
	controls.alignment = BoxContainer.ALIGNMENT_END
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_dock.add_child(controls)
	var skill_list := HBoxContainer.new()
	skill_list.name = "SkillList"
	skill_list.add_theme_constant_override("separation", 8)
	skill_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_list.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_child(skill_list)
	for skill_panel in _skill_panels.values():
		_reparent_control(skill_panel as Control, skill_list)
	auto_battle_button = Button.new()
	auto_battle_button.name = "AutoBattleButton"
	auto_battle_button.custom_minimum_size = Vector2(112, 48)
	auto_battle_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	auto_battle_button.toggle_mode = true
	auto_battle_button.pressed.connect(_toggle_auto_battle)
	auto_battle_button.mouse_entered.connect(func(): UiFeedback.show_tooltip("자동 전투", "스킬 우선 · 쓸 수 없으면 기본공격\nHP 40% 이하일 때 보유한 물약 사용", auto_battle_button.global_position + Vector2(0, 46)))
	auto_battle_button.mouse_exited.connect(func(): UiFeedback.hide_tooltip())
	controls.add_child(auto_battle_button)
	controls.move_child(auto_battle_button, 0)
	$BottomRight.visible = false
	var old_containers: Array[Control] = [$TopLeft, $TopRight, $BottomCenter, $BottomRight]
	for old_container in old_containers:
		old_container.visible = false
	_style_hud_buttons()
	auto_battle_button.add_theme_font_size_override("font_size", 16)
	_update_auto_battle_label()
	_layout_minimap()
	_build_camera_zoom_control()
	_layout_encounter_strip()
	_layout_dungeon_gold()

func _build_camera_zoom_control():
	camera_zoom_control = HBoxContainer.new()
	camera_zoom_control.name = "CameraZoomControl"
	camera_zoom_control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	camera_zoom_control.offset_left = 22.0
	camera_zoom_control.offset_top = 184.0
	camera_zoom_control.offset_right = 190.0
	camera_zoom_control.offset_bottom = 222.0
	camera_zoom_control.add_theme_constant_override("separation", 4)
	camera_zoom_control.alignment = BoxContainer.ALIGNMENT_END
	camera_zoom_control.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var caption := UiStyle.make_label("시점", 12, UiStyle.IVORY)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	camera_zoom_control.add_child(caption)
	var zoom_out := UiStyle.make_button("−", Vector2(36, 34))
	zoom_out.tooltip_text = "카메라 축소"
	zoom_out.pressed.connect(_adjust_game_camera_zoom.bind(-1))
	camera_zoom_control.add_child(zoom_out)
	var zoom_reset := UiStyle.make_button("기본", Vector2(48, 34))
	zoom_reset.tooltip_text = "카메라 시점을 기본 거리로 되돌립니다."
	zoom_reset.pressed.connect(_reset_game_camera_zoom)
	camera_zoom_control.add_child(zoom_reset)
	var zoom_in := UiStyle.make_button("+", Vector2(36, 34))
	zoom_in.tooltip_text = "카메라 확대"
	zoom_in.pressed.connect(_adjust_game_camera_zoom.bind(1))
	camera_zoom_control.add_child(zoom_in)
	add_child(camera_zoom_control)

func _adjust_game_camera_zoom(steps: int):
	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
	if player_node == null:
		return
	var camera := player_node.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
	if camera and camera.has_method("adjust_zoom"):
		camera.call("adjust_zoom", steps)

func _reset_game_camera_zoom():
	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
	if player_node == null:
		return
	var camera := player_node.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
	if camera and camera.has_method("reset_zoom"):
		camera.call("reset_zoom")
func _build_top_status_panel():
	top_status_panel = PanelContainer.new()
	top_status_panel.name = "TopStatusPanel"
	top_status_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_status_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	top_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_status_panel)
	var stats := VBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 3)
	top_status_panel.add_child(stats)
	_reparent_control(exp_bar, stats)
	exp_bar.show_percentage = false
	exp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_bar.custom_minimum_size = Vector2(0, 13)
	exp_bar.add_theme_stylebox_override("background", _flat_style(Color(0.04, 0.09, 0.17, 0.94), Color("#435578"), 2, 6))
	exp_bar.add_theme_stylebox_override("fill", _flat_style(Color("#f5bb3e"), Color("#ffe19c"), 1, 6))
	for label in [level_label, dungeon_gold_label]:
		_reparent_control(label, stats)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.add_theme_font_size_override("font_size", 21)
		label.add_theme_color_override("font_color", Color.WHITE if label == level_label else Color("#ffe293"))
		UiStyle.ink_outline(label, 6, Color("#152644"))
	$TopCenter.visible = false

func _build_bottom_stats_panel():
	bottom_stats_panel = PanelContainer.new()
	bottom_stats_panel.name = "KillPausePanel"
	bottom_stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bottom_stats_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bottom_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_stats_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	bottom_stats_panel.add_child(row)
	_reparent_control(kill_label, row)
	kill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kill_label.add_theme_font_size_override("font_size", 21)
	kill_label.add_theme_color_override("font_outline_color", Color("#151019"))
	kill_label.add_theme_constant_override("outline_size", 5)
	_on_kill_count_changed(GameManager.kill_count)
	_reparent_control(pause_button, row)
	pause_button.custom_minimum_size = Vector2(58, 52)
	pause_button.text = "Ⅱ"

func _layout_dungeon_gold():
	if dungeon_gold_label:
		dungeon_gold_label.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)

func _build_boss_choice_dialog():
	boss_choice_dialog = ConfirmationDialog.new()
	boss_choice_dialog.name = "BossContinueDialog"
	boss_choice_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	boss_choice_dialog.title = "보스 처치!"
	boss_choice_dialog.ok_button_text = "다음 보스 도전"
	boss_choice_dialog.cancel_button_text = "마을로 귀환"
	boss_choice_dialog.confirmed.connect(GameManager.continue_boss_chain)
	boss_choice_dialog.canceled.connect(GameManager.decline_boss_chain)
	add_child(boss_choice_dialog)

func _on_boss_defeated(defeated_count: int, next_reward_multiplier: float):
	if boss_choice_dialog == null:
		_build_boss_choice_dialog()
	boss_choice_dialog.dialog_text = "보스 %d마리를 처치했습니다.\n\n다음 보스를 쓰러뜨리면 보상이 %.1f배로 증가합니다.\n계속 도전할까요?" % [defeated_count, next_reward_multiplier]
	boss_choice_dialog.popup_centered(Vector2i(440, 220))

func _build_encounter_strip():
	encounter_strip = VBoxContainer.new()
	encounter_strip.name = "EncounterStrip"
	encounter_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	encounter_strip.add_theme_constant_override("separation", 2)
	add_child(encounter_strip)
	var timer_plate := PanelContainer.new()
	timer_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	timer_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_plate.custom_minimum_size.x = 150
	timer_plate.add_theme_stylebox_override("panel", _flat_style(Color(0.04, 0.09, 0.19, 0.87), Color("#546d9d"), 2, 18))
	encounter_strip.add_child(timer_plate)
	_reparent_control(time_label, timer_plate)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 32)
	time_label.add_theme_color_override("font_outline_color", Color("#151019"))
	time_label.add_theme_constant_override("outline_size", 6)
	encounter_label = UiStyle.make_label("", 15)
	encounter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encounter_label.add_theme_color_override("font_outline_color", Color("#151019"))
	encounter_label.add_theme_constant_override("outline_size", 5)
	encounter_strip.add_child(encounter_label)
	boss_health = ProgressBar.new()
	boss_health.custom_minimum_size.y = 9
	boss_health.show_percentage = false
	boss_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health.add_theme_stylebox_override("background", _flat_style(Color("#221521"), Color.TRANSPARENT, 0, 4))
	boss_health.add_theme_stylebox_override("fill", _flat_style(Color("#cb595a"), Color.TRANSPARENT, 0, 4))
	encounter_strip.add_child(boss_health)
	_update_encounter_strip()

func _layout_encounter_strip():
	encounter_strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	encounter_strip.offset_left = -126
	encounter_strip.offset_right = 126

func _update_encounter_strip():
	if (boss_target == null or not is_instance_valid(boss_target) or bool(boss_target.get("is_dead"))) and _boss_scan_timer <= 0.0:
		boss_target = null
		_boss_scan_timer = 0.6
		if GameManager.battle_time >= maxf(0.0, GameManager.next_boss_time - 1.0):
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
					continue
				var monster_id := str(enemy.get("monster_id"))
				if bool(MonsterManager.get_definition(monster_id).get("is_boss", false)):
					boss_target = enemy as Node3D
					break
	var remaining := maxf(0.0, GameManager.next_boss_time - GameManager.battle_time)
	var active := is_instance_valid(boss_target) and not bool(boss_target.get("is_dead"))
	boss_health.visible = active
	if active:
		var definition := MonsterManager.get_definition(str(boss_target.get("monster_id")))
		encounter_label.text = str(definition.get("name", "보스"))
		boss_health.max_value = float(boss_target.get("max_hp"))
		boss_health.value = float(boss_target.get("current_hp"))
	elif GameManager.boss_decision_pending:
		encounter_label.text = "보스 처치"
	else:
		encounter_label.text = "다음 보스  %s" % UiStyle.format_time(ceilf(remaining))

func _layout_minimap():
	var minimap_container := $MinimapContainer as Control
	minimap_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_container.offset_left = -176.0
	minimap_container.offset_top = 20.0
	minimap_container.offset_right = -16.0
	minimap_container.offset_bottom = 180.0
	minimap_container.visible = false

func _style_hud_buttons():
	UiStyle.skin_button(pause_button, Color("#182a4c"), Color("#788db4"))
	pause_button.add_theme_font_size_override("font_size", 27)

func _flat_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _reparent_control(control: Control, new_parent: Control):
	var old_parent := control.get_parent()
	if old_parent:
		old_parent.remove_child(control)
	new_parent.add_child(control)


func _build_mobile_dpad():
	if not GameActions.is_mobile():
		if dpad and is_instance_valid(dpad):
			dpad.queue_free()
		dpad = null
		return
	if dpad and is_instance_valid(dpad):
		return
	dpad = VIRTUAL_DPAD.instantiate()
	dpad.set("use_combat_layout", true)
	add_child(dpad)

func _cast_skill(key: String):
	if skill_manager == null or not is_instance_valid(skill_manager):
		UiFeedback.show_error("스킬 시스템을 찾을 수 없습니다.")
		return
	skill_manager.call("press_skill", key)

func _manual_attack():
	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("try_manual_attack"):
		player_node.call("try_manual_attack")

func _toggle_auto_battle():
	var enabled: bool = not bool(skill_manager.get("auto_battle_enabled")) if skill_manager else true
	if skill_manager and skill_manager.has_method("set_auto_battle"):
		skill_manager.call("set_auto_battle", enabled)
	_update_auto_battle_label()

func _update_auto_battle_label():
	var enabled := bool(skill_manager.get("auto_battle_enabled")) if skill_manager else true
	auto_battle_button.set_pressed_no_signal(enabled)
	auto_battle_button.text = "자동 전투 %s" % ("켜짐" if enabled else "꺼짐")
	UiStyle.skin_button(auto_battle_button, Color("#256b8a") if enabled else Color("#25334a"), Color("#74d3ff") if enabled else Color("#889aba"))

func _on_action_requested(action_id: String):
	match action_id:
		"skill_q", "skill_w", "skill_e", "skill_a", "skill_s", "skill_r", "skill_d", "skill_f":
			_cast_skill(action_id.trim_prefix("skill_"))
		"attack":
			_manual_attack()
		"auto_battle":
			_toggle_auto_battle()
		"pause":
			GameManager.toggle_pause()

# ------------------------------------------------------------
# TOOLTIPS
# ------------------------------------------------------------

func _skill_tooltip(key: String) -> Dictionary:
	var skill_id := GameData.get_equipped_skill(key)
	var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
	if meta.is_empty():
		return {"title": "빈 스킬 슬롯", "body": ""}
	var level := int(GameData.skill_levels.get(skill_id, 1))
	var cd := float(GameData.skill_cooldowns.get(skill_id, meta.get("base_cd", 1.0)))
	var dmg := float(meta.get("base_dmg_ratio", 1.0)) + float(meta.get("dmg_step", 0.0)) * (level - 1)
	var body := "%s\n쿨타임 %.1f초" % [meta.get("desc", ""), cd]
	if str(meta.get("cast_type", "")) != "heal" and str(meta.get("cast_type", "")) != "passive":
		body += "\n피해 계수 x%.2f · 범위 %.1f" % [dmg, float(meta.get("range", 0.0))]
	if not GameData.is_survival_skill_unlocked(skill_id):
		body += "\n서바이벌 Lv.%d에 습득" % int(meta.unlock_level)
	var current := 0.0
	if skill_manager and is_instance_valid(skill_manager):
		current = float(skill_manager.call("get_cooldown", key))
	if current > 0.05:
		body += "\n\n⏳ 쿨타임 %.1f초 남음" % current
	return {"title": "%s %s" % [meta.name, GameActions.get_shortcut_text("skill_" + key)], "body": body}

func _update_skill_slot_labels():
	for slot in _skill_panels:
		var panel: Control = _skill_panels[slot]
		var skill_id := GameData.get_equipped_skill(str(slot))
		var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
		var icon := panel.find_child("Icon", true, false) as Label
		if icon:
			icon.text = str(meta.get("icon", "—"))
		var key_label := panel.find_child("KeyLabel", true, false) as Label
		if key_label:
			if skill_id.is_empty():
				key_label.text = "—"
			elif not GameData.is_survival_skill_unlocked(skill_id):
				key_label.text = "잠김 · Lv.%d" % int(meta.get("unlock_level", 1))
			else:
				key_label.text = GameActions.get_key_name("skill_" + str(slot))
		panel.tooltip_text = str(meta.get("name", "빈 스킬 슬롯"))
	_update_skill_availability()

func _update_skill_availability():
	if _skill_panels.is_empty():
		return
	for slot in _skill_panels:
		var skill_id := GameData.get_equipped_skill(str(slot))
		var panel: Control = _skill_panels[slot]
		var unlocked := GameData.is_survival_skill_unlocked(skill_id)
		panel.visible = not skill_id.is_empty() and (slot in ["q", "w", "e", "r"] or unlocked)
		panel.modulate = Color.WHITE if unlocked else Color(0.58, 0.59, 0.67)
	if action_dock != null:
		_layout_battle_hud()

# ------------------------------------------------------------
# SIGNALS / INPUT
# ------------------------------------------------------------

func _unhandled_input(event: InputEvent):
	if GameActions.is_capturing():
		return
	if get_tree().paused:
		return
	var action_id := GameActions.get_action_for_event(event)
	if action_id in ["attack", "auto_battle"] and GameActions.is_battle_action(action_id):
		GameActions.trigger(action_id)
		get_viewport().set_input_as_handled()

func _on_hp_changed(curr: float, maximum: float):
	hp_bar.max_value = maximum
	hp_bar.value = curr
	hp_label.text = str(int(curr)) + " / " + str(int(maximum))

func _on_exp_changed(curr: int, needed: int):
	exp_bar.max_value = needed
	exp_bar.value = curr

func _on_leveled_up(lvl: int):
	level_label.text = "Lv." + str(lvl)
	_update_skill_slot_labels()

func _on_time_updated(time_sec: float):
	var mins := int(time_sec / 60.0)
	var secs = int(time_sec) % 60
	var difficulty := 1 + int(floor(time_sec / 180.0))
	time_label.text = "%02d:%02d" % [mins, secs]
	stage_label.text = "난이도 %d" % difficulty
	dungeon_gold_label.text = "💰 %d" % GameManager.dungeon_gold

func _on_kill_count_changed(count: int):
	kill_label.text = "⚔ %d" % count

func _on_skill_cooldown_updated(skill_key: String, current_cd: float, max_cd: float):
	var panel := _skill_panels.get(skill_key) as Control
	if panel == null:
		return
	var overlay := panel.get_node_or_null("CDOverlay") as ColorRect
	var label := panel.get_node_or_null("CDLabel") as Label

	if overlay and label:
		if current_cd > 0.05:
			overlay.visible = true
			var ratio = current_cd / max_cd
			overlay.anchor_top = 1.0 - ratio
			label.visible = true
			label.text = "%.1f" % current_cd
		else:
			overlay.visible = false
			label.visible = false

func _on_pause_button_pressed():
	GameManager.toggle_pause()
