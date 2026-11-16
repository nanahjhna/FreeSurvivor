extends CanvasLayer

@onready var hp_bar: ProgressBar = $TopLeft/Bars/HPBar
@onready var hp_label: Label = $TopLeft/Bars/HPBar/Label
@onready var exp_bar: ProgressBar = $TopLeft/Bars/EXPBar
@onready var level_label: Label = $TopLeft/PortraitPanel/LevelLabel
@onready var time_label: Label = $TopCenter/TimeLabel
@onready var kill_label: Label = $TopRight/KillContainer/KillLabel

# Items
@onready var item1_label: Label = $BottomRight/ItemContainer/Item1/CountLabel
@onready var item2_label: Label = $BottomRight/ItemContainer/Item2/CountLabel
@onready var item3_label: Label = $BottomRight/ItemContainer/Item3/CountLabel

# Offscreen warning overlay
@onready var indicator_overlay: Control = $IndicatorOverlay
@onready var pause_button: Button = $TopRight/PauseButton

var player_node: Node3D = null
var camera_node: Camera3D = null
var skill_manager: Node = null
var dpad: CanvasLayer = null

var auto_battle_button: Button
var _indicator_update_timer: float = 0.0

var _skill_panels: Dictionary = {}
var _item_panels: Dictionary = {}

const VIRTUAL_DPAD: PackedScene = preload("res://scenes/ui/virtual_dpad.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$TopLeft/Bars/SPBar.visible = false
	_connect_signals()
	_style_action_panels()
	_build_battle_action_bar()
	_build_mobile_dpad()
	GameActions.action_requested.connect(_on_action_requested)
	GameActions.input_mode_changed.connect(_build_mobile_dpad)
	_update_item_counts()
	_update_skill_slot_labels()

func _connect_signals():
	GameManager.time_updated.connect(_on_time_updated)
	GameManager.kill_count_changed.connect(_on_kill_count_changed)
	GameData.data_updated.connect(_update_item_counts)
	GameData.data_updated.connect(_update_skill_slot_labels)

	player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		_setup_player(player_node)

	skill_manager = get_tree().root.find_child("SkillManager", true, false)
	if skill_manager and skill_manager.has_signal("skill_cooldown_updated"):
		skill_manager.skill_cooldown_updated.connect(_on_skill_cooldown_updated)

func _setup_player(p: Node3D):
	if p.has_signal("hp_changed"):
		p.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(float(p.get("current_hp")), float(p.get("max_hp")))
	if p.has_signal("exp_changed"):
		p.exp_changed.connect(_on_exp_changed)
	if p.has_signal("leveled_up"):
		p.leveled_up.connect(_on_leveled_up)

func _process(delta: float):
	if player_node == null:
		player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			_setup_player(player_node)

	if skill_manager == null or not is_instance_valid(skill_manager):
		skill_manager = get_tree().root.find_child("SkillManager", true, false)

	if camera_node == null:
		camera_node = get_viewport().get_camera_3d()

	_indicator_update_timer += delta
	if _indicator_update_timer >= 0.12:
		_indicator_update_timer = 0.0
		indicator_overlay.queue_redraw()

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
	var container := $BottomCenter/SkillContainer
	for slot in ["a", "s"]:
		var panel := container.get_node("SkillR").duplicate() as Panel
		panel.name = "Skill" + str(slot).to_upper()
		container.add_child(panel)
		container.move_child(panel, container.get_node("SkillR").get_index())
		_skill_panels[slot] = panel
	_item_panels = {
		1: $BottomRight/ItemContainer/Item1,
		2: $BottomRight/ItemContainer/Item2,
		3: $BottomRight/ItemContainer/Item3
	}
	for key in _skill_panels:
		var action_id: String = "skill_" + str(key)
		_setup_panel(_skill_panels[key], action_id, func(): _cast_skill(str(key)), func(): _skill_tooltip(str(key)))
	for slot in _item_panels:
		var s: int = slot
		_setup_panel(_item_panels[slot], "item_%d" % s, func(): _use_item(s), func(): _item_tooltip(s))

	if pause_button:
		UiStyle.apply_button(pause_button)
		pause_button.text = "⏸"
		pause_button.tooltip_text = "전투 일시정지 [ESC]"

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
		var info: Dictionary = tooltip_builder.call()
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
		var info: Dictionary = tooltip_builder.call()
		UiFeedback.show_tooltip(str(info.get("title", "")), str(info.get("body", "")), panel.get_global_rect().position + Vector2(0, panel.size.y + 8))
	)
	panel.mouse_exited.connect(func(): UiFeedback.hide_tooltip())
	panel.set_meta("action_id", action_id)

func _build_battle_action_bar():
	var bar := PanelContainer.new()
	bar.anchor_left = 1.0
	bar.anchor_top = 1.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -340.0
	bar.offset_top = -258.0
	bar.offset_right = -24.0
	bar.offset_bottom = -150.0
	bar.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.05, 0.07, 0.11, 0.88), Color(0.35, 0.55, 0.85, 0.9), 1))
	add_child(bar)

	var margin := UiStyle.make_margin(bar, 8)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.alignment = FlowContainer.ALIGNMENT_END
	margin.add_child(flow)

	bar.offset_left = -186.0
	bar.offset_top = -76.0
	bar.offset_right = -24.0
	bar.offset_bottom = -24.0
	auto_battle_button = UiStyle.make_button("", Vector2(146, 40))
	auto_battle_button.toggle_mode = true
	_update_auto_battle_label()
	auto_battle_button.pressed.connect(_toggle_auto_battle)
	auto_battle_button.mouse_entered.connect(func(): UiFeedback.show_tooltip("자동 스킬 시전", "사거리 안의 적에게 습득한 스킬을 시전합니다.\n체력이 40% 이하이면 자동으로 물약을 사용합니다.", auto_battle_button.global_position + Vector2(0, 46)))
	auto_battle_button.mouse_exited.connect(func(): UiFeedback.hide_tooltip())
	flow.add_child(auto_battle_button)


func _build_mobile_dpad():
	if not GameActions.is_mobile():
		if dpad and is_instance_valid(dpad):
			dpad.queue_free()
		dpad = null
		return
	if dpad and is_instance_valid(dpad):
		return
	dpad = VIRTUAL_DPAD.instantiate()
	add_child(dpad)

func _cast_skill(key: String):
	if skill_manager == null or not is_instance_valid(skill_manager):
		UiFeedback.show_error("스킬 시스템을 찾을 수 없습니다.")
		return
	skill_manager.call("press_skill", key)

func _use_item(slot: int):
	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("use_item"):
		player_node.call("use_item", slot)

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
	auto_battle_button.text = "자동 스킬 %s %s" % ["ON" if enabled else "OFF", GameActions.get_shortcut_text("auto_battle")]

func _on_action_requested(action_id: String):
	match action_id:
		"skill_q", "skill_w", "skill_e", "skill_a", "skill_s", "skill_r":
			_cast_skill(action_id.trim_prefix("skill_"))
		"item_1":
			_use_item(1)
		"item_2":
			_use_item(2)
		"item_3":
			_use_item(3)
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
	var level := int(GameData.skill_levels.get(skill_id, 1))
	var cd := float(GameData.skill_cooldowns.get(skill_id, meta.get("base_cd", 1.0)))
	var dmg := float(meta.get("base_dmg_ratio", 1.0)) + float(meta.get("dmg_step", 0.0)) * (level - 1)
	var body := "%s\n쿨타임 %.1f초" % [meta.desc, cd]
	if skill_id != "renewal":
		body += "\n위력 x%.2f · 범위 %.1f" % [dmg, float(meta.range)]
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
		var icon := panel.get_node_or_null("Icon") as Label
		if icon:
			icon.text = str(meta.get("icon", "—"))
		var key_label := panel.get_node("KeyLabel") as Label
		key_label.text = GameActions.get_key_name("skill_" + str(slot)) if GameData.is_survival_skill_unlocked(skill_id) else "Lv.%d" % int(meta.unlock_level)
		panel.tooltip_text = str(meta.get("name", "빈 스킬 슬롯"))
	_update_skill_availability()

func _update_skill_availability():
	if _skill_panels.is_empty():
		return
	for slot in _skill_panels:
		var skill_id := GameData.get_equipped_skill(str(slot))
		var panel: Control = _skill_panels[slot]
		panel.visible = GameData.is_survival_skill_unlocked(skill_id)
		if not panel.visible:
			panel.modulate = Color(0.62, 0.64, 0.70)
		else:
			panel.modulate = Color.WHITE

func _item_tooltip(slot: int) -> Dictionary:
	var names := {1: "치유 물약", 2: "화면 폭탄", 3: "질풍 물약"}
	var descs := {
		1: "체력을 35 회복합니다.",
		2: "주변 적에게 큰 피해를 줍니다.",
		3: "5초 동안 이동속도가 50% 증가합니다."
	}
	var count := int(GameData.item_counts.get(slot, 0))
	var body := "%s\n\n보유 수량: %d개" % [descs.get(slot, ""), count]
	if count <= 0:
		body += "\n\n⛔ 아이템이 없습니다. 마을 상점에서 구매하세요."
	return {"title": "%s [%d]" % [names.get(slot, "아이템"), slot], "body": body}

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
	var mins = int(time_sec) / 60
	var secs = int(time_sec) % 60
	time_label.text = "%02d:%02d" % [mins, secs]

func _on_kill_count_changed(count: int):
	kill_label.text = str(count)

func _update_item_counts():
	if item1_label:
		item1_label.text = "x" + str(GameData.item_counts.get(1, 0))
	if item2_label:
		item2_label.text = "x" + str(GameData.item_counts.get(2, 0))
	if item3_label:
		item3_label.text = "x" + str(GameData.item_counts.get(3, 0))
	for slot in _item_panels:
		var panel: Control = _item_panels[slot]
		if panel == null:
			continue
		var count := int(GameData.item_counts.get(slot, 0))
		panel.modulate = Color(1, 1, 1, 1) if count > 0 else Color(0.55, 0.55, 0.6, 0.8)

func _on_skill_cooldown_updated(skill_key: String, current_cd: float, max_cd: float):
	var panel := _skill_panels.get(skill_key) as Control
	if panel == null:
		return
	var overlay := panel.get_node("CDOverlay") as ColorRect
	var label := panel.get_node("CDLabel") as Label

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
