extends CanvasLayer

const CHARACTER_UI: PackedScene = preload("res://scenes/ui/character_management_ui.tscn")
const INVENTORY_UI: PackedScene = preload("res://scenes/ui/inventory_ui.tscn")
const SKILL_UI: PackedScene = preload("res://scenes/ui/skill_ui.tscn")
const SETTINGS_UI: PackedScene = preload("res://scenes/ui/settings_ui.tscn")
const QUEST_UI: PackedScene = preload("res://scenes/ui/quest_ui.tscn")
const COLLECTION_UI: PackedScene = preload("res://scenes/ui/collection_ui.tscn")
const SHOP_UI: PackedScene = preload("res://scenes/ui/shop_ui.tscn")
const MAP_UI: PackedScene = preload("res://scenes/ui/map_ui.tscn")
const NPC_DIALOG_UI: PackedScene = preload("res://scenes/ui/npc_dialog_ui.tscn")
const VIRTUAL_DPAD: PackedScene = preload("res://scenes/ui/virtual_dpad.tscn")

@onready var hp_bar: ProgressBar = $TopLeft/Bars/HPBar
@onready var hp_label: Label = $TopLeft/Bars/HPBar/Label
@onready var level_label: Label = $TopLeft/PortraitPanel/LevelLabel
@onready var status_label: Label = $BottomCenter/Panel/Margin/StatusLabel

var player_node: Node3D = null
var screens: Dictionary = {}
var active_screen_id: String = ""
var _switching := false

var gold_label: Label
var action_bar: PanelContainer
var hint_panel: PanelContainer
var hint_label: Label
var hint_action_button: Button
var hint_close_button: Button
var current_hint: Dictionary = {}

var interaction_panel: PanelContainer
var interaction_label: Label
var interaction_button: Button

var battle_prep_ui: CanvasLayer = null
var dpad: CanvasLayer = null
var _last_interaction_target: String = ""
var fast_travel_root: Control
var main_menu_root: Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_resource_panel()
	_build_hint_panel()
	_build_action_bar()
	_build_main_menu()
	_build_fast_travel_menu()
	_build_interaction_prompt()
	_build_mobile_dpad()
	_load_screens()
	_hide_legacy_status()

	battle_prep_ui = get_parent().get_node_or_null("BattlePreparationUI")
	GameActions.action_requested.connect(_on_action_requested)
	GameActions.bindings_changed.connect(_on_bindings_changed)
	GameActions.input_mode_changed.connect(_on_input_mode_changed)
	GameData.data_updated.connect(_update_stats)
	GameData.data_updated.connect(_refresh_hint)
	GameData.currency_changed.connect(_on_currency_changed)
	_update_stats()
	_refresh_hint()
	call_deferred("_open_main_menu")

func _process(_delta: float):
	if player_node == null:
		player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			if player_node.has_signal("hp_changed"):
				player_node.hp_changed.connect(_on_hp_changed)
			if player_node.has_signal("leveled_up"):
				player_node.leveled_up.connect(_on_leveled_up)
			_update_stats()

func _hide_legacy_status():
	if status_label:
		var bottom_center := status_label.get_parent().get_parent()
		if bottom_center:
			bottom_center.visible = false

# ------------------------------------------------------------
# BUILD UI
# ------------------------------------------------------------

func _build_resource_panel():
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 24.0
	panel.offset_top = 98.0
	panel.offset_right = 330.0
	panel.offset_bottom = 140.0
	panel.add_theme_stylebox_override("panel", UiStyle.sub_panel_style())
	add_child(panel)
	var margin := UiStyle.make_margin(panel, 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	gold_label = UiStyle.make_label("", 14, Color(1.0, 0.87, 0.45))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(gold_label)

func _build_hint_panel():
	hint_panel = PanelContainer.new()
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.offset_left = -380.0
	hint_panel.offset_right = 380.0
	hint_panel.offset_top = 82.0
	hint_panel.offset_bottom = 150.0
	hint_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.06, 0.1, 0.16, 0.94), Color(0.45, 0.75, 1.0, 0.9), 1))
	add_child(hint_panel)

	var margin := UiStyle.make_margin(hint_panel, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var icon := UiStyle.make_label("💡", 22, Color(1.0, 0.86, 0.4))
	row.add_child(icon)

	hint_label = UiStyle.make_label("", 15, Color(0.92, 0.96, 1.0))
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hint_label)

	hint_action_button = UiStyle.make_button("바로가기", Vector2(150, 38), true)
	hint_action_button.pressed.connect(_on_hint_action_pressed)
	row.add_child(hint_action_button)

	hint_close_button = UiStyle.make_button("✕", Vector2(40, 38))
	hint_close_button.pressed.connect(_on_hint_dismissed)
	row.add_child(hint_close_button)
	hint_panel.visible = false

func _build_action_bar():
	action_bar = PanelContainer.new()
	action_bar.anchor_left = 0.0
	action_bar.anchor_top = 1.0
	action_bar.anchor_right = 1.0
	action_bar.anchor_bottom = 1.0
	action_bar.offset_left = 24.0
	action_bar.offset_top = -136.0
	action_bar.offset_right = -24.0
	action_bar.offset_bottom = -18.0
	action_bar.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.05, 0.07, 0.11, 0.93), Color(0.75, 0.65, 0.35, 0.9), 2))
	add_child(action_bar)

	var margin := UiStyle.make_margin(action_bar, 10)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	margin.add_child(flow)

	var menu_button := UiStyle.make_button("📖 게임 메뉴", Vector2(210, 52), true)
	menu_button.pressed.connect(_open_main_menu)
	flow.add_child(menu_button)
	if GameActions.is_mobile():
		action_bar.offset_left = 246.0

func _build_main_menu():
	main_menu_root = Control.new()
	main_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	main_menu_root.visible = false
	main_menu_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(main_menu_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.05, 0.72)
	main_menu_root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_root.add_child(center)

	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(760, 590)
	center.add_child(panel)
	var margin := UiStyle.make_margin(panel, 28)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var title := UiStyle.make_title("🥋 모험 준비", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var fighter: Dictionary = GameData.characters[GameData.FIGHTER_ID]
	var summary := UiStyle.make_label(
		"%s  ·  골드 %d  ·  성장 재화 %d" % [
			str(fighter.get("name", "무도가")), GameData.player_gold, GameData.player_growth_currency
		],
		20, Color(1.0, 0.87, 0.52)
	)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(summary)

	var launch := UiStyle.make_button("⚔️  바로 출격", Vector2(0, 82), true)
	launch.add_theme_font_size_override("font_size", 30)
	launch.pressed.connect(_on_launch_pressed)
	content.add_child(launch)

	var caption := UiStyle.make_label("하고 싶은 일을 눌러 보세요", 18, Color(0.82, 0.88, 0.98))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(caption)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)

	var options := [
		["🥋  성장", "character"],
		["🎒  장비", "inventory"],
		["✨  스킬", "skill"],
		["🃏  카드", "card_deck"],
		["🌄  지역 선택", "stage_select"],
		["🛍️  상점", "shop"],
		["📜  퀘스트", "quest"],
		["⚙️  설정", "settings"]
	]
	for option in options:
		var button := UiStyle.make_button(str(option[0]), Vector2(300, 76))
		button.add_theme_font_size_override("font_size", 21)
		button.pressed.connect(_on_main_menu_option.bind(str(option[1])))
		grid.add_child(button)

	var close := UiStyle.make_button("닫기", Vector2(0, 48))
	close.pressed.connect(_close_main_menu)
	content.add_child(close)

func _open_main_menu():
	main_menu_root.visible = true
	main_menu_root.move_to_front()
	get_tree().paused = true

func _close_main_menu():
	main_menu_root.visible = false
	get_tree().paused = false

func _on_launch_pressed():
	_close_main_menu()
	GameManager.go_to_battle(GameData.current_selected_stage_id)

func _on_main_menu_option(action_id: String):
	main_menu_root.visible = false
	if action_id == "stage_select":
		_open_battle_prep()
		return
	if action_id == "card_deck":
		get_tree().paused = false
		GameManager.go_to_deck_builder()
		return
	open_screen(action_id)

func _build_fast_travel_menu():
	fast_travel_root = Control.new()
	fast_travel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fast_travel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	fast_travel_root.visible = false
	add_child(fast_travel_root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.66)
	fast_travel_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fast_travel_root.add_child(center)
	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var margin := UiStyle.make_margin(panel, 24)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(UiStyle.make_title("📍 마을 빠른 이동", 25))
	var destinations := [
		["🔨 대장간", Vector3(-14, 0.2, 4)], ["🪙 장비 상점", Vector3(14, 0.2, 4)],
		["📜 퀘스트 게시판", Vector3(6, 0.2, 5)], ["🃏 카드 상점", Vector3(-14, 0.2, 14)],
		["⚔️ 서바이벌 입구", Vector3(0, 0.2, -40)], ["🎴 카드 덱 던전 입구", Vector3(-23, 0.2, 25)]
	]
	for destination in destinations:
		var button := UiStyle.make_button(str(destination[0]), Vector2(0, 48))
		button.pressed.connect(_fast_travel.bind(destination[1], str(destination[0])))
		box.add_child(button)
	var close := UiStyle.make_button("닫기 [ESC]", Vector2(0, 46))
	close.pressed.connect(func(): fast_travel_root.visible = false)
	box.add_child(close)

func _open_fast_travel():
	fast_travel_root.visible = true
	fast_travel_root.move_to_front()

func _fast_travel(destination: Vector3, label: String):
	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
	if player_node == null:
		UiFeedback.show_error("플레이어를 찾을 수 없습니다.")
		return
	player_node.global_position = destination
	player_node.set("velocity", Vector3.ZERO)
	fast_travel_root.visible = false
	UiFeedback.show_success("%s 앞으로 이동했습니다." % label)

func _build_interaction_prompt():
	interaction_panel = PanelContainer.new()
	interaction_panel.anchor_left = 0.5
	interaction_panel.anchor_right = 0.5
	interaction_panel.offset_left = -230.0
	interaction_panel.offset_right = 230.0
	interaction_panel.offset_top = -204.0
	interaction_panel.offset_bottom = -152.0
	interaction_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.12, 0.18, 0.1, 0.95), Color(0.55, 0.95, 0.45, 0.95), 2))
	add_child(interaction_panel)

	var margin := UiStyle.make_margin(interaction_panel, 10)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	interaction_label = UiStyle.make_label("", 15, Color(0.9, 1.0, 0.85))
	interaction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(interaction_label)

	interaction_button = UiStyle.make_button("이용하기", Vector2(120, 38), true)
	interaction_button.pressed.connect(func(): GameActions.trigger("interact"))
	row.add_child(interaction_button)
	interaction_panel.visible = false

func _build_mobile_dpad():
	if dpad and is_instance_valid(dpad):
		dpad.queue_free()
		dpad = null
	if not GameActions.is_mobile():
		return
	dpad = VIRTUAL_DPAD.instantiate()
	add_child(dpad)

func _load_screens():
	var screen_scenes := {
		"character": CHARACTER_UI,
		"inventory": INVENTORY_UI,
		"skill": SKILL_UI,
		"settings": SETTINGS_UI,
		"quest": QUEST_UI,
		"collection": COLLECTION_UI,
		"shop": SHOP_UI,
		"map": MAP_UI
	}
	for screen_id in screen_scenes:
		var screen = screen_scenes[screen_id].instantiate() as CanvasLayer
		screen.layer = 30
		screen.connect("closed", _on_screen_closed.bind(screen_id))
		add_child(screen)
		screens[screen_id] = screen

	var dialog = NPC_DIALOG_UI.instantiate()
	dialog.layer = 35
	dialog.connect("closed", _on_dialog_closed)
	dialog.connect("option_selected", _on_dialog_option)
	add_child(dialog)
	screens["npc_dialog"] = dialog

	var map_screen = screens.get("map")
	if map_screen:
		map_screen.connect("landmark_selected", _on_landmark_selected)

# ------------------------------------------------------------
# ACTIONS
# ------------------------------------------------------------

func _on_action_requested(action_id: String):
	if action_id == "interact":
		if active_screen_id == "":
			_interact_nearest()
		return
	if action_id == "battle_start":
		_open_battle_prep()
		return
	if action_id == "card_deck":
		GameManager.go_to_deck_builder()
		return
	if not screens.has(action_id):
		return
	open_screen(action_id)

func open_screen(screen_id: String):
	if not screens.has(screen_id):
		return
	if active_screen_id == screen_id:
		return
	_switching = true
	if active_screen_id != "" and screens.has(active_screen_id):
		var old_screen = screens[active_screen_id]
		if old_screen.visible:
			_close_screen_instance(old_screen)
	active_screen_id = screen_id
	main_menu_root.visible = false
	var screen = screens[screen_id]
	screen.call("open")
	get_tree().paused = true
	_switching = false
	if screen_id == "character":
		GameData.mark_tutorial("seen_character")
	elif screen_id == "inventory":
		GameData.mark_tutorial("seen_inventory")
	elif screen_id == "skill":
		GameData.mark_tutorial("seen_skill")
	_refresh_hint()

func close_active_screen():
	if active_screen_id == "":
		return
	var screen = screens.get(active_screen_id)
	active_screen_id = ""
	if screen and screen.visible:
		_close_screen_instance(screen)
	get_tree().paused = false
	_refresh_hint()

func _close_screen_instance(screen) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if screen.has_method("close"):
		screen.call("close")
	elif screen.has_method("close_screen"):
		screen.call("close_screen")

func _on_screen_closed(screen_id: String):
	if _switching:
		return
	if active_screen_id == screen_id:
		active_screen_id = ""
		get_tree().paused = false
	_refresh_hint()
	if main_menu_root:
		_open_main_menu()

func _on_dialog_closed():
	if _switching:
		return
	if active_screen_id == "npc_dialog":
		active_screen_id = ""
		get_tree().paused = false
		_refresh_hint()

func _on_dialog_option(action_id: String):
	active_screen_id = ""
	get_tree().paused = false
	if action_id == "":
		_refresh_hint()
		return
	if action_id == "rest":
		_rest_at_inn()
		return
	_on_action_requested(action_id)

func _open_battle_prep():
	if battle_prep_ui == null:
		battle_prep_ui = get_parent().get_node_or_null("BattlePreparationUI")
	_switching = true
	if active_screen_id != "":
		var old_screen = screens.get(active_screen_id)
		if old_screen and old_screen.visible:
			_close_screen_instance(old_screen)
		active_screen_id = ""
	_switching = false
	if battle_prep_ui:
		battle_prep_ui.call("open", GameData.current_selected_stage_id)
	else:
		UiFeedback.show_error("전투 준비 화면을 찾을 수 없습니다.")

func _interact_nearest():
	var lobby = get_parent()
	if lobby and lobby.has_method("try_interact"):
		lobby.call("try_interact")

func show_npc_dialog(npc_name: String, role: String, line: String, options: Array):
	if not screens.has("npc_dialog"):
		return
	_switching = true
	if active_screen_id != "":
		var old_screen = screens.get(active_screen_id)
		if old_screen and old_screen.visible:
			_close_screen_instance(old_screen)
	active_screen_id = "npc_dialog"
	var dialog = screens["npc_dialog"]
	dialog.call("open", npc_name, role, line, options)
	get_tree().paused = true
	_switching = false

func _on_landmark_selected(landmark_id: String):
	match landmark_id:
		"forge":
			open_screen("inventory")
		"shop":
			open_screen("shop")
		"inn":
			_rest_at_inn()
		"quest":
			open_screen("quest")
		"battle_start":
			_open_battle_prep()

func _rest_at_inn():
	UiFeedback.confirm(
		"여관에서 휴식",
		"50 골드를 지불하고 체력을 모두 회복하시겠습니까?\n현재 체력: %d / %d" % [
			int(GameData.player_current_hp), int(GameData.get_max_player_hp())
		],
		func():
			var result := GameData.rest_at_inn()
			if bool(result.get("ok", false)):
				UiFeedback.show_success(str(result.get("message", "체력을 회복했습니다.")))
				_update_stats()
			else:
				UiFeedback.show_error(str(result.get("message", "휴식할 수 없습니다.")))
	)

# ------------------------------------------------------------
# HINTS / PROMPTS
# ------------------------------------------------------------

func _refresh_hint():
	if hint_panel == null:
		return
	current_hint = HintManager.get_hint()
	if current_hint.is_empty() or not bool(current_hint.get("visible", true)):
		hint_panel.visible = false
		return
	hint_panel.visible = true
	hint_label.text = str(current_hint.get("text", ""))
	hint_action_button.text = str(current_hint.get("button", "바로가기"))

func _on_hint_action_pressed():
	var action := str(current_hint.get("action", ""))
	if action != "":
		GameActions.trigger(action)
	_refresh_hint()

func _on_hint_dismissed():
	HintManager.dismiss(str(current_hint.get("id", "")))
	hint_panel.visible = false

func set_interaction_prompt(text: String, allow_mobile_button: bool = true):
	if interaction_panel == null:
		return
	_last_interaction_target = text
	var key_text := GameActions.get_shortcut_text("interact")
	var prefix := (key_text + " ") if key_text != "" else ""
	interaction_label.text = prefix + text
	interaction_button.visible = allow_mobile_button
	interaction_panel.visible = true

func clear_interaction_prompt():
	if interaction_panel:
		interaction_panel.visible = false
	_last_interaction_target = ""

# ------------------------------------------------------------
# STATS / INPUT
# ------------------------------------------------------------

func _unhandled_input(event: InputEvent):
	if GameActions.is_capturing():
		return
	if fast_travel_root and fast_travel_root.visible and event.is_action_pressed("ui_cancel"):
		fast_travel_root.visible = false
		get_viewport().set_input_as_handled()
		return
	if main_menu_root and main_menu_root.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_main_menu()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu_settings"):
		if active_screen_id != "":
			close_active_screen()
		else:
			open_screen("settings")
		get_viewport().set_input_as_handled()
		return
	var action_id := GameActions.get_action_for_event(event)
	if action_id != "" and GameActions.is_lobby_action(action_id):
		GameActions.trigger(action_id)
		get_viewport().set_input_as_handled()

func _update_stats():
	var max_h := GameData.get_max_player_hp()
	var cur_h := GameData.player_current_hp
	hp_bar.max_value = max_h
	hp_bar.value = cur_h
	hp_label.text = str(int(cur_h)) + " / " + str(int(max_h))
	level_label.text = "영구 성장"
	if gold_label:
		gold_label.text = "💰 %d 골드     💎 %d 젬     ✨ %d 성장 재화" % [GameData.player_gold, GameData.player_gems, GameData.player_growth_currency]

func _on_currency_changed(_gold: int, _gems: int):
	_update_stats()

func _on_hp_changed(curr: float, maximum: float):
	hp_bar.max_value = maximum
	hp_bar.value = curr
	hp_label.text = str(int(curr)) + " / " + str(int(maximum))

func _on_leveled_up(lvl: int):
	level_label.text = "Lv." + str(lvl)

func _on_bindings_changed():
	_refresh_hint()
	if interaction_panel and interaction_panel.visible:
		var target := _last_interaction_target
		set_interaction_prompt(target)

func _on_input_mode_changed():
	_build_mobile_dpad()
	if action_bar:
		action_bar.offset_left = 246.0 if GameActions.is_mobile() else 24.0
