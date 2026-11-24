extends CanvasLayer

const CHARACTER_UI: PackedScene = preload("res://scenes/ui/character_management_ui.tscn")
const INVENTORY_UI: PackedScene = preload("res://scenes/ui/inventory_ui.tscn")
const SKILL_UI: PackedScene = preload("res://scenes/ui/skill_ui.tscn")
const SETTINGS_UI: PackedScene = preload("res://scenes/ui/settings_ui.tscn")
const QUEST_UI: PackedScene = preload("res://scenes/ui/quest_ui.tscn")
const SHOP_UI: PackedScene = preload("res://scenes/ui/shop_ui.tscn")
const MAP_UI: PackedScene = preload("res://scenes/ui/map_ui.tscn")
const VIRTUAL_DPAD: PackedScene = preload("res://scenes/ui/virtual_dpad.tscn")
const ROUTE_COLOR := Color("#ffd47e")
const ROUTE_OUTLINE := Color("#342419")
const TRAVEL_DESTINATIONS := [
	["대장간", "forge", "장비 강화·교체"],
	["스킬 상점", "shop", "영웅 동작 미리보기·구매"],
	["여관", "inn", "골드로 능력치 영구 강화"],
	["퀘스트 게시판", "quest", "임무 확인·보상 받기"],
	["서바이벌 던전", "battle_start", "골드 획득·보스 장비"],
	["카드 덱 던전", "card_dungeon", "덱 편성·카드 전투"],
]

@onready var status_label: Label = $BottomCenter/Panel/Margin/StatusLabel

var screens: Dictionary = {}
var active_screen_id: String = ""
var _switching := false

var interaction_panel: PanelContainer
var interaction_label: Label
var interaction_button: Button

var battle_prep_ui: CanvasLayer = null
var dpad: CanvasLayer = null
var _last_interaction_target: String = ""
var fast_travel_root: Control
var auto_move_button: Button
var route_overlay: Control
var route_label: Label
var _attention_badges: Dictionary = {}
var _travel_attention_badges: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$TopLeft.visible = false
	$TopRight.offset_top = 16.0
	$TopRight.offset_bottom = 196.0
	_build_route_overlay()
	_build_bottom_menu()
	_build_fast_travel_menu()
	_build_auto_move_button()
	_build_interaction_prompt()
	_build_mobile_dpad()
	_load_screens()
	_hide_legacy_status()
	_refresh_attention_badges()

	battle_prep_ui = get_parent().get_node_or_null("BattlePreparationUI")
	GameActions.action_requested.connect(_on_action_requested)
	GameActions.bindings_changed.connect(_on_bindings_changed)
	GameActions.input_mode_changed.connect(_on_input_mode_changed)

func _process(_delta: float):
	var lobby := get_parent()
	var moving := lobby.has_method("is_auto_moving") and bool(lobby.call("is_auto_moving"))
	auto_move_button.text = "이동 취소" if moving else "자동 이동"
	var show_route := moving and not get_tree().paused
	route_overlay.visible = show_route
	route_label.visible = show_route
	if show_route:
		route_overlay.queue_redraw()
	_refresh_attention_badges()

func _hide_legacy_status():
	if status_label:
		var bottom_center := status_label.get_parent().get_parent()
		if bottom_center:
			bottom_center.visible = false

# ------------------------------------------------------------
# BUILD UI
# ------------------------------------------------------------

func _build_bottom_menu():
	var panel := PanelContainer.new()
	panel.name = "VillageBottomMenu"
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12.0
	panel.offset_top = -82.0
	panel.offset_right = -12.0
	panel.offset_bottom = -18.0
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.025, 0.02, 0.023, 0.88), Color(0.42, 0.31, 0.22, 0.65), 1))
	add_child(panel)
	var margin := UiStyle.make_margin(panel, 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	for item in [["캐릭터", "character"], ["장비", "equipment"], ["스킬", "skill"], ["퀘스트", "quest"]]:
		var entry := HBoxContainer.new()
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_constant_override("separation", 3)
		row.add_child(entry)
		var button := UiStyle.make_button(str(item[0]), Vector2(0, 48))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(open_screen.bind(str(item[1])))
		entry.add_child(button)
		_attention_badges[str(item[1])] = _make_attention_badge()
		entry.add_child(_attention_badges[str(item[1])])
	var dungeon := UiStyle.make_button("던전 선택", Vector2(0, 48), true)
	dungeon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dungeon.pressed.connect(_open_battle_prep)
	row.add_child(dungeon)

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
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.y >= viewport_size.x
	panel.custom_minimum_size = Vector2(minf(viewport_size.x - 32.0, 620.0), 0)
	center.add_child(panel)
	var margin := UiStyle.make_margin(panel, 18 if portrait else 24)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(UiStyle.make_title("자동 이동", 24))
	for destination in TRAVEL_DESTINATIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var button := UiStyle.make_button(destination[0], Vector2(146, 54 if portrait else 48))
		button.pressed.connect(_auto_move_to.bind(destination[1], destination[0]))
		row.add_child(button)
		_travel_attention_badges[destination[1]] = _make_attention_badge()
		row.add_child(_travel_attention_badges[destination[1]])
		var description := UiStyle.make_label(destination[2], 16, UiStyle.MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(description)
	var close := UiStyle.make_button("닫기 [ESC]", Vector2(0, 46))
	close.pressed.connect(func(): fast_travel_root.visible = false)
	box.add_child(close)

func _make_attention_badge() -> PanelContainer:
	var badge := UiStyle.plaque("!", Color("#a92b2b"), Color("#ff786e"), Color.WHITE, 20)
	badge.custom_minimum_size = Vector2(28, 32)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	return badge

func _refresh_attention_badges() -> void:
	if _attention_badges.is_empty():
		return
	var attention := {
		"character": false,
		"skill": false,
		"quest": GameData.has_claimable_quest(),
		"equipment": false,
	}
	for id in _attention_badges:
		_attention_badges[id].visible = bool(attention.get(id, false))
	for id in _travel_attention_badges:
		_travel_attention_badges[id].visible = _has_destination_attention(str(id))

func _has_destination_attention(destination_id: String) -> bool:
	match destination_id:
		"inn": return GameData.has_permanent_upgrade_available()
		"quest": return GameData.has_claimable_quest()
		"shop": return GameData.has_skill_shop_purchase_available()
	return false

func _build_auto_move_button():
	auto_move_button = UiStyle.make_button("자동 이동", Vector2(104, 40), true)
	auto_move_button.anchor_left = 0.0
	auto_move_button.anchor_top = 0.0
	auto_move_button.anchor_right = 0.0
	auto_move_button.anchor_bottom = 0.0
	auto_move_button.offset_left = 12.0
	auto_move_button.offset_top = 16.0
	auto_move_button.offset_right = 116.0
	auto_move_button.offset_bottom = 56.0
	auto_move_button.add_theme_font_size_override("font_size", 13)
	auto_move_button.pressed.connect(_on_auto_move_button_pressed)
	add_child(auto_move_button)

func _on_auto_move_button_pressed():
	var lobby := get_parent()
	if lobby.has_method("is_auto_moving") and bool(lobby.call("is_auto_moving")):
		lobby.call("cancel_auto_move")
		return
	_open_fast_travel()

func _open_fast_travel():
	fast_travel_root.visible = true
	fast_travel_root.move_to_front()

func _auto_move_to(destination_id: String, label: String):
	var lobby := get_parent()
	if not lobby.has_method("start_auto_move_to") or not bool(lobby.call("start_auto_move_to", destination_id)):
		UiFeedback.show_error("이동할 장소를 찾을 수 없습니다.")
		return
	route_label.text = "%s까지 이동 중" % label
	fast_travel_root.visible = false

func _build_route_overlay() -> void:
	route_overlay = Control.new()
	route_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	route_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_overlay.draw.connect(_draw_auto_move_route)
	route_overlay.hide()
	add_child(route_overlay)
	move_child(route_overlay, 0)
	route_label = UiStyle.make_label("", 16, ROUTE_COLOR)
	UiStyle.ink_outline(route_label, 5)
	route_label.position = Vector2(14, 63)
	route_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_label.hide()
	add_child(route_label)

func _draw_auto_move_route() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var path: PackedVector3Array = get_parent().get_auto_move_path()
	var distance_to_arrow := 20.0
	for i in range(1, path.size()):
		var from_world := path[i - 1] + Vector3.UP * 0.10
		var to_world := path[i] + Vector3.UP * 0.10
		if camera.is_position_behind(from_world) or camera.is_position_behind(to_world):
			continue
		var start := camera.unproject_position(from_world)
		var finish := camera.unproject_position(to_world)
		var length := start.distance_to(finish)
		if length < 1.0:
			continue
		route_overlay.draw_line(start, finish, ROUTE_OUTLINE, 6.0, true)
		route_overlay.draw_line(start, finish, ROUTE_COLOR, 2.5, true)
		var direction := (finish - start) / length
		if i == path.size() - 1:
			distance_to_arrow = minf(distance_to_arrow, length)
		while distance_to_arrow <= length:
			var tip := start + direction * distance_to_arrow
			var tail := tip - direction * 10.0
			var side := direction.orthogonal() * 6.0
			var arrow := PackedVector2Array([tail + side, tip, tail - side])
			route_overlay.draw_polyline(arrow, ROUTE_OUTLINE, 7.0, true)
			route_overlay.draw_polyline(arrow, ROUTE_COLOR, 3.0, true)
			distance_to_arrow += 42.0
		distance_to_arrow -= length

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
		"shop": SHOP_UI,
		"map": MAP_UI
	}
	for screen_id in screen_scenes:
		var screen = screen_scenes[screen_id].instantiate() as CanvasLayer
		screen.layer = 30
		screen.connect("closed", _on_screen_closed.bind(screen_id))
		add_child(screen)
		screens[screen_id] = screen

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
	if action_id in ["equipment", "forge"]:
		open_screen(action_id)
		return
	if not screens.has(action_id):
		return
	open_screen(action_id)

func open_screen(screen_id: String):
	var growth := screen_id == "growth"
	if growth:
		screen_id = "character"
	var at_forge := screen_id == "forge"
	var equipment := at_forge or screen_id == "equipment"
	if equipment:
		screen_id = "inventory"
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
	var screen = screens[screen_id]
	if equipment:
		screen.call("open", true, at_forge)
	elif growth:
		screen.call("open", true)
	else:
		screen.call("open")
	get_tree().paused = true
	_switching = false
	if screen_id == "character":
		GameData.mark_tutorial("seen_character")
	elif screen_id == "inventory":
		GameData.mark_tutorial("seen_inventory")
	elif screen_id == "skill":
		GameData.mark_tutorial("seen_skill")

func close_active_screen():
	if active_screen_id == "":
		return
	var screen = screens.get(active_screen_id)
	active_screen_id = ""
	if screen and screen.visible:
		_close_screen_instance(screen)
	get_tree().paused = false

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

func _on_landmark_selected(landmark_id: String):
	match landmark_id:
		"forge":
			open_screen("forge")
		"shop":
			open_screen("shop")
		"inn":
			open_screen("growth")
		"quest":
			open_screen("quest")
		"battle_start":
			_open_battle_prep()

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

func _on_bindings_changed():
	if interaction_panel and interaction_panel.visible:
		var target := _last_interaction_target
		set_interaction_prompt(target)

func _on_input_mode_changed():
	_build_mobile_dpad()
