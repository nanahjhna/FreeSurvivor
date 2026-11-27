extends CanvasLayer

const CHARACTER_UI: PackedScene = preload("res://scenes/ui/character_management_ui.tscn")
const INVENTORY_UI: PackedScene = preload("res://scenes/ui/inventory_ui.tscn")
const SKILL_UI: PackedScene = preload("res://scenes/ui/skill_ui.tscn")
const SETTINGS_UI: PackedScene = preload("res://scenes/ui/settings_ui.tscn")
const QUEST_UI: PackedScene = preload("res://scenes/ui/quest_ui.tscn")
const SHOP_UI: PackedScene = preload("res://scenes/ui/shop_ui.tscn")
const MAP_UI: PackedScene = preload("res://scenes/ui/map_ui.tscn")
const VIRTUAL_DPAD: PackedScene = preload("res://scenes/ui/virtual_dpad.tscn")
const ROUTE_COLOR := Color("#edbd71")
const TRAVEL_DESTINATIONS := [
	["대장간", "forge", "forge"],
	["스킬 상점", "shop", "skill"],
	["여관", "inn", "bed"],
	["퀘스트 게시판", "quest", "quest"],
	["서바이벌 던전", "battle_start", "gate"],
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
var _travel_buttons: Dictionary = {}
var _travel_attention_badges: Dictionary = {}
var auto_move_attention_badge: Control
var hud_dock: VBoxContainer
var profile_label: Label
var objective_panel: PanelContainer
var objective_title: Label
var objective_button: Button
var objective_stage := ""
var _attention_refresh_remaining := 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$TopLeft.hide()
	_build_profile_badge()
	_build_route_overlay()
	_build_bottom_menu()
	_build_fast_travel_menu()
	_build_interaction_prompt()
	_build_mobile_dpad()
	_load_screens()
	_hide_legacy_status()
	_refresh_attention_badges()

	battle_prep_ui = get_parent().get_node_or_null("BattlePreparationUI")
	GameActions.action_requested.connect(_on_action_requested)
	GameActions.bindings_changed.connect(_on_bindings_changed)
	GameActions.input_mode_changed.connect(_on_input_mode_changed)
	GameData.data_updated.connect(_refresh_village_character)
	_refresh_village_character()

func _refresh_village_character() -> void:
	var leader_id := GameData.get_leader_id()
	var character: Dictionary = GameData.characters.get(leader_id, {})
	var profile := GameData.get_character_profile(GameData.active_character_id)
	profile_label.text = "%s LV.%d" % [profile.get("name", character.get("name", "모험가")), GameData.get_character_total_level(leader_id)]
	_refresh_objective()

func _process(delta: float):
	var lobby := get_parent()
	var moving := lobby.has_method("is_auto_moving") and bool(lobby.call("is_auto_moving"))
	auto_move_button.text = "이동 취소" if moving else "자동 이동"
	objective_panel.visible = not moving and active_screen_id.is_empty()
	var show_route := moving and not get_tree().paused
	route_overlay.visible = show_route
	route_label.visible = show_route
	if show_route:
		route_overlay.queue_redraw()
	_attention_refresh_remaining -= delta
	if _attention_refresh_remaining <= 0.0:
		_attention_refresh_remaining = 0.25
		_refresh_attention_badges()

func _hide_legacy_status():
	if status_label:
		var bottom_center := status_label.get_parent().get_parent()
		if bottom_center:
			bottom_center.visible = false

# ------------------------------------------------------------
# BUILD UI
# ------------------------------------------------------------

func _build_profile_badge() -> void:
	$TopRight/Minimap.set_compact_display()
	var map_hit := Button.new()
	map_hit.tooltip_text = "마을 지도"
	map_hit.flat = true
	map_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_hit.pressed.connect(open_screen.bind("map"))
	$TopRight.add_child(map_hit)
	var badge := UiStyle.make_panel()
	add_child(badge)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	UiStyle.make_margin(badge, 8).add_child(row)
	row.add_child(UiStyle.icon_view("sword", 29))
	profile_label = UiStyle.make_title("", 22)
	profile_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	profile_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(profile_label)
	var fit := func():
		var safe := UiStyle.safe_insets(get_viewport())
		var width := get_viewport().get_visible_rect().size.x - safe.x - safe.z
		var map_side := clampf(width * 0.22, 104.0, 152.0)
		badge.position = Vector2(16 + safe.x, 16 + safe.y)
		badge.size.x = minf(252.0, width - map_side - 52.0)
		$TopRight.offset_left = -16.0 - safe.z - map_side
		$TopRight.offset_right = -16.0 - safe.z
		$TopRight.offset_top = 16.0 + safe.y
		$TopRight.offset_bottom = 16.0 + safe.y + map_side
	get_viewport().size_changed.connect(fit)
	fit.call()

func _build_bottom_menu():
	hud_dock = VBoxContainer.new()
	hud_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hud_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_dock.add_theme_constant_override("separation", 8)
	add_child(hud_dock)
	_build_objective_card()
	var panel := PanelContainer.new()
	panel.name = "VillageBottomMenu"
	panel.add_theme_stylebox_override("panel", UiStyle.art_panel())
	hud_dock.add_child(panel)
	var margin := UiStyle.make_margin(panel, 4)
	var row := GridContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	margin.add_child(row)
	for item in [["캐릭터", "character", "person"], ["장비", "equipment", "shield"], ["스킬", "skill", "skill"]]:
		var button := UiStyle.make_button(str(item[0]), Vector2(64, 76))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		UiStyle.button_icon(button, item[2], 25, true)
		button.pressed.connect(open_screen.bind(str(item[1])))
		row.add_child(button)
	_build_auto_move_button(row)
	auto_move_attention_badge = UiStyle.attention_badge(30)
	auto_move_attention_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	auto_move_attention_badge.offset_left = -38
	auto_move_attention_badge.offset_right = -8
	auto_move_attention_badge.offset_top = -8
	auto_move_attention_badge.offset_bottom = 22
	auto_move_button.add_child(auto_move_attention_badge)
	var button_min_width := 64.0
	for child in row.get_children():
		button_min_width = maxf(button_min_width, (child as Button).get_combined_minimum_size().x)
	for child in row.get_children():
		(child as Button).custom_minimum_size.x = button_min_width
	var frame_width := panel.get_theme_stylebox("panel").get_minimum_size().x
	var four_button_width := 24.0 + frame_width + 8.0 + 3.0 * 8.0 + 4.0 * button_min_width
	var fit := func():
		var safe := UiStyle.safe_insets(get_viewport())
		var width := get_viewport().get_visible_rect().size.x - safe.x - safe.z
		row.columns = 4 if width >= four_button_width else 2
		var inset := maxf(12, (width - 680.0) * 0.5)
		hud_dock.offset_left = inset + safe.x
		hud_dock.offset_right = -inset - safe.z
		hud_dock.offset_bottom = -14 - safe.w
		hud_dock.offset_top = hud_dock.offset_bottom - hud_dock.get_combined_minimum_size().y
	hud_dock.minimum_size_changed.connect(fit)
	get_viewport().size_changed.connect(fit)
	fit.call()

func _build_objective_card() -> void:
	objective_panel = UiStyle.make_panel()
	objective_panel.add_theme_stylebox_override("panel", UiStyle.art_panel())
	hud_dock.add_child(objective_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	UiStyle.make_margin(objective_panel, 10).add_child(column)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 13)
	column.add_child(summary)
	summary.add_child(UiStyle.icon_view("gate", 45, UiStyle.GOLD_BRIGHT))
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(labels)
	labels.add_child(UiStyle.make_label("다음 목표", 17, UiStyle.MUTED))
	objective_title = UiStyle.make_title("", 24)
	objective_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(objective_title)
	objective_button = UiStyle.make_button("던전으로 이동   ›", Vector2(0, 58), true)
	objective_button.add_theme_font_size_override("font_size", 23)
	objective_button.pressed.connect(_on_objective_pressed)
	column.add_child(objective_button)

func _refresh_objective() -> void:
	objective_stage = GameData.current_selected_stage_id
	for stage_id in GameData.stages:
		if GameData.is_stage_unlocked(stage_id) and not bool(GameData.stages[stage_id].get("cleared", false)):
			objective_stage = stage_id
			break
	if objective_stage == "stage_1" and not bool(GameData.stages["stage_1"].get("cleared", false)):
		objective_title.text = "첫 던전 도전"
	else:
		objective_title.text = str(GameData.stages.get(objective_stage, {}).get("name", "던전")) + " 도전"

func _on_objective_pressed() -> void:
	if _auto_move_to("battle_start", "서바이벌 던전"):
		GameData.current_selected_stage_id = objective_stage

func _build_fast_travel_menu():
	fast_travel_root = Control.new()
	fast_travel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fast_travel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	fast_travel_root.visible = false
	add_child(fast_travel_root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = UiStyle.SCRIM
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
	var header := HBoxContainer.new()
	box.add_child(header)
	var heading := UiStyle.make_title("자동 이동", 29)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := UiStyle.make_button("×", Vector2(52, 49))
	close.pressed.connect(func(): fast_travel_root.visible = false)
	header.add_child(close)
	for destination in TRAVEL_DESTINATIONS:
		var button := UiStyle.make_button(destination[0] + "   ›", Vector2(0, 63))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 22)
		UiStyle.button_icon(button, destination[2], 27)
		button.pressed.connect(_auto_move_to.bind(destination[1], destination[0]))
		box.add_child(button)
		_travel_buttons[destination[1]] = button
		var attention := UiStyle.attention_badge(30)
		attention.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		attention.offset_left = -38.0
		attention.offset_top = -15.0
		attention.offset_right = -8.0
		attention.offset_bottom = 15.0
		attention.visible = false
		button.add_child(attention)
		_travel_attention_badges[destination[1]] = attention

func _refresh_attention_badges() -> void:
	var any_destination_attention := false
	var attention_by_destination := {
		"shop": GameData.has_skill_shop_purchase_available(),
		"inn": GameData.has_permanent_upgrade_available(),
		"quest": GameData.has_claimable_quest(),
	}
	for id in _travel_buttons:
		var needs_attention := bool(attention_by_destination.get(id, false))
		any_destination_attention = any_destination_attention or needs_attention
		var attention_mark := _travel_attention_badges.get(id) as Control
		if attention_mark:
			attention_mark.visible = needs_attention
	if auto_move_attention_badge != null:
		auto_move_attention_badge.visible = any_destination_attention
	var npc_destinations := {
		"npc_merchant": "shop",
		"npc_innkeeper": "inn",
		"npc_villager": "quest",
	}
	for npc in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(npc) or not npc.has_method("set_attention_visible"):
			continue
		var interaction_id := str(npc.get_meta("interaction_id", ""))
		npc.call("set_attention_visible", bool(attention_by_destination.get(npc_destinations.get(interaction_id, ""), false)))

func _build_auto_move_button(parent: Control = null):
	auto_move_button = UiStyle.make_button("자동 이동", Vector2(64, 76))
	auto_move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_move_button.add_theme_font_size_override("font_size", 18)
	UiStyle.button_icon(auto_move_button, "compass", 25, true)
	auto_move_button.pressed.connect(_on_auto_move_button_pressed)
	if parent == null:
		add_child(auto_move_button)
	else:
		parent.add_child(auto_move_button)

func _on_auto_move_button_pressed():
	var lobby := get_parent()
	if lobby.has_method("is_auto_moving") and bool(lobby.call("is_auto_moving")):
		lobby.call("cancel_auto_move")
		return
	_open_fast_travel()

func _open_fast_travel():
	fast_travel_root.visible = true
	fast_travel_root.move_to_front()

func _auto_move_to(destination_id: String, label: String) -> bool:
	var lobby := get_parent()
	if not lobby.has_method("start_auto_move_to") or not bool(lobby.call("start_auto_move_to", destination_id)):
		UiFeedback.show_error("이동할 장소를 찾을 수 없습니다.")
		return false
	route_label.text = "%s까지 이동 중" % label
	fast_travel_root.visible = false
	return true

func _build_route_overlay() -> void:
	route_overlay = Control.new()
	route_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	route_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_overlay.draw.connect(_draw_auto_move_route)
	route_overlay.hide()
	add_child(route_overlay)
	move_child(route_overlay, 0)
	route_label = UiStyle.make_label("", 18, ROUTE_COLOR)
	UiStyle.ink_outline(route_label, 5)
	route_label.position = Vector2(16, 83)
	route_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_label.hide()
	add_child(route_label)

func _draw_auto_move_route() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var path: PackedVector3Array = get_parent().get_auto_move_path()
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
		var dot_distance := 8.0
		var dot_spacing := 16.0
		var direction := (finish - start) / length
		while dot_distance < length:
			var dot_position := start + direction * dot_distance
			route_overlay.draw_circle(dot_position, 3.0, ROUTE_COLOR)
			dot_distance += dot_spacing

func _build_interaction_prompt():
	interaction_panel = PanelContainer.new()
	interaction_panel.add_theme_stylebox_override("panel", UiStyle.art_panel(UiStyle.AMBER, Vector2.ONE))
	hud_dock.add_child(interaction_panel)
	hud_dock.move_child(interaction_panel, 0)

	var margin := UiStyle.make_margin(interaction_panel, 10)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	interaction_label = UiStyle.make_label("", 17)
	interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(interaction_label)

	interaction_button = UiStyle.make_button("이용하기", Vector2(96, 48))
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
	# Village movement uses the floating virtual stick across the safe screen;
	# combat keeps its left-side joystick layout in hud.gd.
	dpad.set("use_combat_layout", false)
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
	for entry in TRAVEL_DESTINATIONS:
		if entry[1] == landmark_id:
			_auto_move_to(landmark_id, entry[0])
			return

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
