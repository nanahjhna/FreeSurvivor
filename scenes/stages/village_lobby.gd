extends Node3D

const NPC_CASTLE_GUARD: PackedScene = preload("res://assets/npc/castle_guard_01.fbx")
const NPC_INNKEEPER: PackedScene = preload("res://assets/npc/Medea By M. Arrebola.fbx")
const NPC_SKILL_MERCHANT: PackedScene = preload("res://assets/npc/Peasant Girl.fbx")
const NPC_BLACKSMITH: PackedScene = preload("res://assets/npc/Peasant Man.fbx")

@onready var player: PlayerCharacter = $Player
@onready var battle_portal: Area3D = $BattlePortal
@onready var battle_prep_ui = $BattlePreparationUI
@onready var hud = $VillageHUD
@onready var environment = $VillageEnvironment

var interactables: Array[Dictionary] = []
var nearest_interaction: Dictionary = {}
var _last_prompt_id: String = ""
var _highlighted_interactable: Node3D = null
var _auto_move_entry: Dictionary = {}
var _auto_move_waypoints: Array[Vector3] = []
var _auto_move_stall_time := 0.0
var _auto_move_last_position := Vector3.ZERO
var _auto_move_goal := Vector3.ZERO
var _auto_move_replanned := false

func _ready():
	GameManager.current_location = GameManager.Location.LOBBY
	GameManager.current_state = GameManager.GameState.PLAYING
	battle_portal.battle_requested.connect(_on_battle_requested)
	
	if player:
		# Start the village character facing the opposite gate/portal. Keep this
		# on the visual root so movement axes and the player collision body stay
		# unchanged.
		var gate_direction := (battle_portal.global_position - player.global_position).slide(Vector3.UP)
		var visual_root := player.get_node_or_null("VisualRoot") as Node3D
		if visual_root != null and not gate_direction.is_zero_approx():
			gate_direction = gate_direction.normalized()
			visual_root.rotation.y = atan2(gate_direction.x, gate_direction.z)
		if player.has_method("set_head_hp_bar_visible"):
			player.call("set_head_hp_bar_visible", false)
		if player.has_method("set_first_person_mode"):
			player.call("set_first_person_mode", false)
		var cam := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
		if cam:
			# The village uses a close over-the-shoulder view. Combat scenes
			# explicitly restore the existing quarter-view camera.
			cam.set("quarter_view_enabled", false)
			cam.set("quarter_distance", GameData.camera_distance)
			cam.set("quarter_elevation_degrees", GameData.camera_elevation_degrees)
			cam.set("quarter_azimuth_degrees", GameData.camera_azimuth_degrees)
			cam.set("back_view_enabled", true)
			cam.set("back_distance", 4.6)
			cam.set("back_elevation_degrees", 28.0)
			cam.set("back_yaw_offset_degrees", 0.0)
			cam.set("back_look_height", 1.55)
			cam.set("back_look_ahead", 0.28)
			cam.set("first_person_enabled", false)
			cam.set("first_person_eye_height", 2.15)
			cam.set("first_person_forward_offset", 0.32)
			cam.set("first_person_fov", 72.0)
			cam.fov = 60.0
			cam.call("snap_to_target")
	
	if not SceneTransition.is_transitioning:
		_build_village_environment()

func prepare_transition(report_progress: Callable) -> void:
	await report_progress.call(77.0, "마을 지형 만드는 중…")
	await _build_village_environment(report_progress)

func _on_battle_requested():
	if is_auto_moving():
		cancel_auto_move()
	if GameManager.current_location == GameManager.Location.LOBBY:
		battle_prep_ui.call("open", GameData.current_selected_stage_id)

# ----------------- INTERACTION SYSTEM -----------------
# Every building / NPC registers itself with a stable id, a prompt label and
# an activation radius. Keyboard [E] and clicking the 3D object both call
# `_interact`, so both paths always perform the same action.

func _register_interactable(node: Node3D, id: String, label: String, radius: float):
	if node == null:
		return
	node.set_meta("interaction_id", id)
	node.set_meta("interaction_label", label)
	node.set_meta("interaction_radius", radius)
	interactables.append({
		"node": node,
		"id": id,
		"label": label,
		"radius": radius
	})

func _physics_process(delta: float) -> void:
	if GameManager.current_location == GameManager.Location.LOBBY and is_instance_valid(player) and is_auto_moving():
		_process_auto_move(delta)

func _process(_delta: float):
	if GameManager.current_location != GameManager.Location.LOBBY:
		return
	if get_tree().paused or hud == null:
		return
	if player == null or not is_instance_valid(player):
		return
	if is_auto_moving():
		return
	var best: Dictionary = {}
	var best_dist := INF
	for entry in interactables:
		var node = entry.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var dist: float = player.global_position.distance_to(node.global_position)
		if dist <= float(entry.get("radius", 6.0)) and dist < best_dist:
			best = entry
			best_dist = dist

	nearest_interaction = best
	if best.is_empty():
		_set_interaction_highlight(null)
		if _last_prompt_id != "":
			_last_prompt_id = ""
			hud.call("clear_interaction_prompt")
		return

	var prompt_id: String = str(best.get("id", ""))
	_set_interaction_highlight(best.get("node") as Node3D)
	if prompt_id != _last_prompt_id:
		_last_prompt_id = prompt_id
		hud.call("set_interaction_prompt", str(best.get("label", "상호작용")), GameActions.is_mobile())

func _set_interaction_highlight(target: Node3D):
	if _highlighted_interactable == target:
		return
	if _highlighted_interactable != null and is_instance_valid(_highlighted_interactable) and _highlighted_interactable.has_method("set_interaction_highlight"):
		_highlighted_interactable.call("set_interaction_highlight", false)
	_highlighted_interactable = target
	if _highlighted_interactable != null and _highlighted_interactable.has_method("set_interaction_highlight"):
		_highlighted_interactable.call("set_interaction_highlight", true)

func try_interact():
	if get_tree().paused:
		return
	if nearest_interaction.is_empty():
		# Re-evaluate once in case the prompt has not ticked yet.
		_process(0.0)
	if nearest_interaction.is_empty():
		UiFeedback.show_info("가까이에 상호작용할 대상이 없습니다. 건물이나 NPC 가까이 이동하세요.")
		return
	_interact(nearest_interaction)

func _interact(entry: Dictionary):
	if is_auto_moving():
		cancel_auto_move()
	var id := str(entry.get("id", ""))
	match id:
		"battle_start":
			battle_prep_ui.call("open", GameData.current_selected_stage_id)
		"forge":
			_open_hud_screen("forge")
		"shop":
			_open_hud_screen("shop")
		"inn":
			_open_hud_screen("growth")
		"quest":
			_open_hud_screen("quest")
		"npc_blacksmith":
			_open_hud_screen("forge")
		"npc_merchant":
			_open_hud_screen("shop")
		"npc_innkeeper":
			_open_hud_screen("growth")
		"npc_guard":
			battle_prep_ui.call("open", GameData.current_selected_stage_id)
		"npc_villager":
			_open_hud_screen("quest")
		_:
			UiFeedback.show_info("아직 사용할 수 없는 대상입니다.")

func _open_hud_screen(screen_id: String):
	if hud and hud.has_method("open_screen"):
		hud.call("open_screen", screen_id)
	else:
		UiFeedback.show_error("화면을 열 수 없습니다.")

func _unhandled_input(event: InputEvent):
	if GameManager.current_location != GameManager.Location.LOBBY:
		return
	if get_tree().paused or GameActions.is_capturing():
		return
	var pressed := false
	var screen_pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		screen_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		screen_pos = event.position
	if not pressed:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 120.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 32)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var entry := _find_interactable_from_collider(hit.get("collider"))
	if entry.is_empty():
		return
	var dist: float = player.global_position.distance_to(entry["node"].global_position)
	if dist > float(entry.get("radius", 6.0)) + 2.5:
		UiFeedback.show_info("조금 더 가까이 이동한 뒤 다시 시도하세요.")
		return
	nearest_interaction = entry
	_interact(entry)
	get_viewport().set_input_as_handled()

func _find_interactable_from_collider(collider) -> Dictionary:
	var current = collider
	while current != null:
		if current.has_meta("interaction_id"):
			var id := str(current.get_meta("interaction_id"))
			for entry in interactables:
				if entry.get("node") == current and str(entry.get("id", "")) == id:
					return entry
			return {
				"node": current,
				"id": id,
				"label": str(current.get_meta("interaction_label", "상호작용")),
				"radius": float(current.get_meta("interaction_radius", 6.0))
			}
		current = current.get_parent()
	return {}

func start_auto_move_to(interaction_id: String) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var closest: Dictionary = {}
	var closest_distance := INF
	for entry in interactables:
		if str(entry.get("id", "")) != interaction_id:
			continue
		var target := entry.get("node") as Node3D
		if target == null or not is_instance_valid(target):
			continue
		var distance := player.global_position.distance_to(target.global_position)
		if distance < closest_distance:
			closest = entry
			closest_distance = distance
	if closest.is_empty():
		return false
	var approach: Vector3 = closest["node"].global_position
	match interaction_id:
		"forge": approach += Vector3(6, 0, 0)
		"shop", "inn": approach += Vector3(-6, 0, 0)
		"quest": approach += Vector3(0, 0, 2)
		"battle_start": approach += Vector3(0, 0, 3)
	var route := _auto_move_route(approach)
	if route.is_empty():
		return false
	if is_auto_moving():
		cancel_auto_move()
	_auto_move_entry = closest
	_auto_move_waypoints = route
	_auto_move_goal = approach
	_auto_move_replanned = false
	_auto_move_last_position = player.global_position
	_auto_move_stall_time = 0.0
	nearest_interaction = {}
	_last_prompt_id = ""
	_set_interaction_highlight(null)
	hud.clear_interaction_prompt()
	return true

func _auto_move_route(goal: Vector3) -> Array[Vector3]:
	var occupied := PackedVector2Array()
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc is Node3D:
			var pos: Vector3 = npc.global_position
			occupied.append(Vector2(pos.x, pos.z))
	return environment.walking_path(player.global_position, goal, occupied)

func is_auto_moving() -> bool:
	return not _auto_move_entry.is_empty()

func get_auto_move_path() -> PackedVector3Array:
	if not is_auto_moving() or not is_instance_valid(player):
		return PackedVector3Array()
	var path := PackedVector3Array([player.global_position])
	path.append_array(PackedVector3Array(_auto_move_waypoints))
	return path

func cancel_auto_move():
	if is_instance_valid(player):
		player.set_auto_move_direction(Vector3.ZERO)
	_auto_move_entry = {}
	_auto_move_waypoints.clear()
	_last_prompt_id = ""
	if hud and hud.has_method("clear_interaction_prompt"):
		hud.call("clear_interaction_prompt")

func _process_auto_move(delta: float):
	if _auto_move_entry.is_empty():
		return
	if get_tree().paused:
		return
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		cancel_auto_move()
		return
	var target := _auto_move_entry.get("node") as Node3D
	if target == null or not is_instance_valid(target):
		cancel_auto_move()
		return
	if player.touch_move_vector.length_squared() > 0.01:
		cancel_auto_move()
		return
	if _auto_move_last_position.distance_to(player.global_position) > 0.45:
		_auto_move_last_position = player.global_position
		_auto_move_stall_time = 0.0
	else:
		_auto_move_stall_time += delta
	if _auto_move_stall_time > 0.75 and not _auto_move_replanned:
		_auto_move_replanned = true
		var detour := _auto_move_route(_auto_move_goal)
		if not detour.is_empty():
			_auto_move_waypoints = detour
	if _auto_move_stall_time > 2.5:
		cancel_auto_move()
		return
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	while not _auto_move_waypoints.is_empty():
		var next := _auto_move_waypoints[0]
		if player_xz.distance_to(Vector2(next.x, next.z)) > 0.56:
			break
		_auto_move_waypoints.pop_front()
	if _auto_move_waypoints.is_empty():
		var arrived_entry := _auto_move_entry
		cancel_auto_move()
		_interact(arrived_entry)
		return
	var target_delta := _auto_move_waypoints[0] - player.global_position
	target_delta.y = 0.0
	player.set_auto_move_direction(target_delta.normalized())

func _build_village_environment(report_progress: Callable = Callable()) -> void:
	await environment.build(battle_portal.position, report_progress)
	battle_portal.get_node("PortalGate").hide()
	battle_portal.get_node("SignPost").hide()
	environment.decorate_portal(battle_portal, "서바이벌 던전", Color(0.23, 0.7, 1.0))
	_register_interactable(battle_portal, "battle_start", "서바이벌 던전 입장", 7.0)

	_register_interactable(environment.destinations["forge"], "forge", "대장간 이용하기", 8.0)
	_register_interactable(environment.destinations["shop"], "shop", "스킬 상점 열기", 8.0)
	_register_interactable(environment.destinations["inn"], "inn", "여관에서 골드로 경험치 구매", 8.0)
	_register_interactable(environment.destinations["quest"], "quest", "게시판 보기", 4.5)
	if report_progress.is_valid():
		await report_progress.call(91.0, "마을 주민 준비 중…")
	await _spawn_npcs(report_progress)

func get_village_landmarks() -> Dictionary:
	var pins := {}
	for entry in interactables:
		var id: String = entry["id"]
		if not id.begins_with("npc_"):
			pins[id] = entry["node"].global_position
	return pins

# ----------------- NPCS -----------------

func _spawn_npcs(report_progress: Callable):
	var npc_scene = load("res://scenes/npc/village_npc.tscn")
	if not npc_scene:
		return
	
	var npc_root = Node3D.new()
	npc_root.name = "NPCs"
	add_child(npc_root)
	
	# 1. Blacksmith
	var bs = npc_scene.instantiate()
	bs.npc_name = "헤파이스토"
	bs.npc_role = "대장장이"
	bs.outfit_color = Color(0.6, 0.35, 0.15)
	bs.model_scene = NPC_BLACKSMITH
	bs.idle_source_clip = &"Weight_Shift"
	bs.model_ground_offset = 0.02
	bs.model_scale = Vector3.ONE * 1.28
	bs.position = Vector3(-12.35, 0, -1.5)
	npc_root.add_child(bs)
	_register_interactable(bs, "npc_blacksmith", "헤파이스토와 대화하기", 3.8)
	if report_progress.is_valid():
		await report_progress.call(92.0, "스킬 상점 준비 중…")
	
	# 2. Skill Merchant
	var shop = npc_scene.instantiate()
	shop.npc_name = "마커스"
	shop.npc_role = "스킬 상인"
	shop.outfit_color = Color(0.25, 0.35, 0.65)
	shop.model_scene = NPC_SKILL_MERCHANT
	shop.idle_source_clip = &"Standing_Idle_01"
	shop.model_ground_offset = 0.05
	shop.model_scale = Vector3.ONE * 1.5625
	shop.overhead_offset = 1.25
	shop.position = Vector3(12.35, 0, -1.5)
	npc_root.add_child(shop)
	_register_interactable(shop, "npc_merchant", "스킬 상점 열기", 3.8)
	if report_progress.is_valid():
		await report_progress.call(93.0, "여관 준비 중…")
	
	# 3. Innkeeper
	var inn = npc_scene.instantiate()
	inn.npc_name = "엘레나"
	inn.npc_role = "여관 주인"
	inn.outfit_color = Color(0.65, 0.25, 0.45)
	inn.model_scene = NPC_INNKEEPER
	inn.model_scale = Vector3.ONE * 17.5
	inn.idle_source_clip = &"Standing_Idle_02_Looking"
	inn.model_ground_offset = 0.025
	inn.overhead_offset = 1.1
	inn.position = Vector3(12.1, 0, 15.6)
	npc_root.add_child(inn)
	_register_interactable(inn, "npc_innkeeper", "엘레나에게 골드로 경험치 구매", 3.8)
	if report_progress.is_valid():
		await report_progress.call(94.0, "던전 입구 준비 중…")
	
	# 4. Gate Guards
	var guard1 = npc_scene.instantiate()
	guard1.npc_name = "경비병 카일"
	guard1.npc_role = "외곽 경비병"
	guard1.outfit_color = Color(0.5, 0.55, 0.6)
	guard1.model_scene = NPC_CASTLE_GUARD
	guard1.idle_source_clip = &"Sword_And_Shield_Idle__c9cc660c-b96c-11e4-a802-0aaa78deedf9"
	guard1.model_ground_offset = 0.0625
	guard1.model_scale = Vector3.ONE * 1.5625
	guard1.overhead_offset = 1.4
	guard1.position = battle_portal.position + Vector3(-3.1, 0, 4)
	npc_root.add_child(guard1)
	_register_interactable(guard1, "npc_guard", "경비병과 대화하기", 3.8)
	
	var guard2 = npc_scene.instantiate()
	guard2.npc_name = "경비병 레오"
	guard2.npc_role = "외곽 경비병"
	guard2.outfit_color = Color(0.5, 0.55, 0.6)
	guard2.model_scene = NPC_CASTLE_GUARD
	guard2.idle_source_clip = &"Sword_And_Shield_Idle__c9cc660c-b96c-11e4-a802-0aaa78deedf9"
	guard2.model_ground_offset = 0.0625
	guard2.model_scale = Vector3.ONE * 1.5625
	guard2.overhead_offset = 1.4
	guard2.position = battle_portal.position + Vector3(3.1, 0, 4)
	npc_root.add_child(guard2)
	_register_interactable(guard2, "npc_guard", "경비병과 대화하기", 3.8)
	if report_progress.is_valid():
		await report_progress.call(97.0, "마을 주민 배치 중…")
	
	# 5. Wandering Villagers (Patrolling)
	var v1 = npc_scene.instantiate()
	v1.npc_name = "토마스"
	v1.npc_role = "산책 중인 주민"
	v1.is_patrolling = true
	v1.patrol_radius = 2.6
	v1.outfit_color = Color(0.3, 0.55, 0.3)
	v1.position = Vector3(-4.5, 0, -5.8)
	npc_root.add_child(v1)
	_register_interactable(v1, "npc_villager", "토마스와 대화하기", 3.2)
	
	var v2 = npc_scene.instantiate()
	v2.npc_name = "클로이"
	v2.npc_role = "여행자"
	v2.is_patrolling = true
	v2.patrol_radius = 2.8
	v2.outfit_color = Color(0.7, 0.45, 0.2)
	v2.position = Vector3(5.1, 0, 3.6)
	npc_root.add_child(v2)
	_register_interactable(v2, "npc_villager", "클로이와 대화하기", 3.2)
