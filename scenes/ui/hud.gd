extends CanvasLayer

@onready var hp_bar: ProgressBar = $TopLeft/Bars/HPBar
@onready var hp_label: Label = $TopLeft/Bars/HPBar/Label
@onready var sp_bar: ProgressBar = $TopLeft/Bars/SPBar
@onready var sp_label: Label = $TopLeft/Bars/SPBar/Label
@onready var exp_bar: ProgressBar = $TopLeft/Bars/EXPBar
@onready var level_label: Label = $TopLeft/PortraitPanel/LevelLabel
@onready var time_label: Label = $TopCenter/TimeLabel
@onready var kill_label: Label = $TopRight/KillContainer/KillLabel

# Skills
@onready var skill_q_cd: ColorRect = $BottomCenter/SkillContainer/SkillQ/CDOverlay
@onready var skill_q_label: Label = $BottomCenter/SkillContainer/SkillQ/CDLabel
@onready var skill_w_cd: ColorRect = $BottomCenter/SkillContainer/SkillW/CDOverlay
@onready var skill_w_label: Label = $BottomCenter/SkillContainer/SkillW/CDLabel
@onready var skill_e_cd: ColorRect = $BottomCenter/SkillContainer/SkillE/CDOverlay
@onready var skill_e_label: Label = $BottomCenter/SkillContainer/SkillE/CDLabel
@onready var skill_r_cd: ColorRect = $BottomCenter/SkillContainer/SkillR/CDOverlay
@onready var skill_r_label: Label = $BottomCenter/SkillContainer/SkillR/CDLabel

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
var auto_attack_button: Button
var attack_button: Button

var _skill_panels: Dictionary = {}
var _item_panels: Dictionary = {}

const VIRTUAL_DPAD: PackedScene = preload("res://scenes/ui/virtual_dpad.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if p.has_signal("sp_changed"):
		p.sp_changed.connect(_on_sp_changed)
		_on_sp_changed(float(p.get("current_sp")), float(p.get("max_sp")))
	if p.has_signal("exp_changed"):
		p.exp_changed.connect(_on_exp_changed)
	if p.has_signal("leveled_up"):
		p.leveled_up.connect(_on_leveled_up)
	_update_auto_attack_label()

func _process(_delta: float):
	if player_node == null:
		player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			_setup_player(player_node)

	if skill_manager == null or not is_instance_valid(skill_manager):
		skill_manager = get_tree().root.find_child("SkillManager", true, false)

	if camera_node == null:
		camera_node = get_viewport().get_camera_3d()

	_update_item_counts()
	_update_skill_availability()
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

	attack_button = UiStyle.make_button("⚔️ 공격 [SPACE]", Vector2(150, 40), true)
	attack_button.pressed.connect(_manual_attack)
	attack_button.mouse_entered.connect(func(): UiFeedback.show_tooltip("수동 공격", "가까운 적을 즉시 공격합니다.\n자동 공격이 꺼져 있어도 사용할 수 있습니다.", attack_button.global_position + Vector2(0, 46)))
	attack_button.mouse_exited.connect(func(): UiFeedback.hide_tooltip())
	flow.add_child(attack_button)

	auto_battle_button = UiStyle.make_button("🤖 자동 전투 [T]", Vector2(150, 40))
	auto_battle_button.toggle_mode = true
	auto_battle_button.pressed.connect(_toggle_auto_battle)
	auto_battle_button.mouse_entered.connect(func(): UiFeedback.show_tooltip("자동 전투", "사거리 안에 적이 있으면 쿨타임마다 스킬을 자동으로 사용합니다.\n체력이 40% 이하이면 자동으로 물약을 사용합니다.", auto_battle_button.global_position + Vector2(0, 46)))
	auto_battle_button.mouse_exited.connect(func(): UiFeedback.hide_tooltip())
	flow.add_child(auto_battle_button)

	auto_attack_button = UiStyle.make_button("🗡️ 자동 공격: 켜짐", Vector2(170, 40))
	auto_attack_button.toggle_mode = true
	auto_attack_button.button_pressed = true
	auto_attack_button.pressed.connect(_toggle_auto_attack)
	auto_attack_button.mouse_entered.connect(func(): UiFeedback.show_tooltip("자동 공격", "사거리 안의 적을 자동으로 공격합니다.\n끄면 [공격] 버튼이나 SPACE 키로 직접 공격합니다.", auto_attack_button.global_position + Vector2(0, 46)))
	auto_attack_button.mouse_exited.connect(func(): UiFeedback.hide_tooltip())
	flow.add_child(auto_attack_button)

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
	if not skill_manager.call("try_cast", key):
		var cd := float(skill_manager.call("get_cooldown", key))
		if cd > 0.05:
			UiFeedback.show_info("%s 스킬 쿨타임이 %.1f초 남았습니다." % [key.to_upper(), cd])
		else:
			var skill_id := GameData.get_equipped_skill(key)
			var cost := int(GameData.skill_meta.get(skill_id, {}).get("sp_cost", 0))
			var current_sp := float(player_node.get("current_sp")) if player_node else 0.0
			if current_sp < cost:
				UiFeedback.show_info("SP가 부족합니다. (%d / %d)" % [int(current_sp), cost])
			else:
				UiFeedback.show_info("%s 스킬을 지금은 사용할 수 없습니다." % key.to_upper())

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
	if auto_battle_button:
		auto_battle_button.button_pressed = enabled
		auto_battle_button.text = "🤖 자동 전투: 켜짐" if enabled else "🤖 자동 전투: 꺼짐"

func _toggle_auto_attack():
	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
	if player_node == null:
		return
	var enabled: bool = not bool(player_node.get("auto_attack_enabled"))
	if player_node.has_method("set_auto_attack"):
		player_node.call("set_auto_attack", enabled)
	_update_auto_attack_label()

func _update_auto_attack_label():
	if auto_attack_button == null:
		return
	var enabled := true
	if player_node and is_instance_valid(player_node):
		enabled = bool(player_node.get("auto_attack_enabled"))
	auto_attack_button.button_pressed = enabled
	auto_attack_button.text = "🗡️ 자동 공격: 켜짐" if enabled else "🗡️ 자동 공격: 꺼짐"

func _on_action_requested(action_id: String):
	match action_id:
		"skill_q":
			_cast_skill("q")
		"skill_w":
			_cast_skill("w")
		"skill_e":
			_cast_skill("e")
		"skill_r":
			_cast_skill("r")
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
	var body := "%s\n%s\n\n위력 x%.2f · 쿨타임 %.1f초 · 범위 %.1f · SP %d\n레벨 %d / 10" % [
		str(meta.get("name", key.to_upper() + " 스킬")),
		str(meta.get("desc", "")),
		dmg, cd, float(meta.get("range", 6.0)), int(meta.get("sp_cost", 0)), level
	]
	var current := 0.0
	if skill_manager and is_instance_valid(skill_manager):
		current = float(skill_manager.call("get_cooldown", key))
	if current > 0.05:
		body += "\n\n⏳ 쿨타임 %.1f초 남음" % current
	return {"title": "%s [%s]" % [str(meta.get("name", key.to_upper())), key.to_upper()], "body": body}

func _update_skill_slot_labels():
	for slot in _skill_panels:
		var panel: Control = _skill_panels[slot]
		var skill_id := GameData.get_equipped_skill(str(slot))
		var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
		var icon := panel.get_node_or_null("Icon") as Label
		if icon:
			icon.text = str(meta.get("icon", "—"))
		panel.tooltip_text = str(meta.get("name", "빈 스킬 슬롯"))
	_update_skill_availability()

func _update_skill_availability():
	if _skill_panels.is_empty():
		return
	var current_sp := float(player_node.get("current_sp")) if player_node and is_instance_valid(player_node) else 0.0
	for slot in _skill_panels:
		var skill_id := GameData.get_equipped_skill(str(slot))
		var cost := int(GameData.skill_meta.get(skill_id, {}).get("sp_cost", 0))
		var panel: Control = _skill_panels[slot]
		panel.modulate = Color.WHITE if current_sp >= cost else Color(0.58, 0.58, 0.65, 0.8)

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

func _on_sp_changed(curr: float, maximum: float):
	sp_bar.max_value = maximum
	sp_bar.value = curr
	sp_label.text = "%d / %d SP" % [int(curr), int(maximum)]
	_update_skill_availability()

func _on_exp_changed(curr: int, needed: int):
	exp_bar.max_value = needed
	exp_bar.value = curr

func _on_leveled_up(lvl: int):
	level_label.text = "Lv." + str(lvl)

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
	var overlay: ColorRect = null
	var label: Label = null
	match skill_key:
		"q":
			overlay = skill_q_cd
			label = skill_q_label
		"w":
			overlay = skill_w_cd
			label = skill_w_label
		"e":
			overlay = skill_e_cd
			label = skill_e_label
		"r":
			overlay = skill_r_cd
			label = skill_r_label

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
