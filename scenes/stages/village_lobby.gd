extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var battle_portal: Area3D = $BattlePortal
@onready var battle_prep_ui = $BattlePreparationUI
@onready var hud = $VillageHUD

var interactables: Array[Dictionary] = []
var nearest_interaction: Dictionary = {}
var _last_prompt_id: String = ""

func _ready():
	GameManager.current_location = GameManager.Location.LOBBY
	GameManager.current_state = GameManager.GameState.PLAYING
	battle_portal.battle_requested.connect(_on_battle_requested)
	
	if player:
		# Disable combat features in town
		player.is_combat_enabled = false
		# Set player at town central plaza
		player.global_position = Vector3(0, 0.2, 5.0)
		# Zoom out camera in village
		var cam = player.get_node_or_null("Camera3D")
		if cam:
			cam.camera_offset = Vector3(0.0, 14.0, 12.0)
	
	_build_village_environment()
	_register_interactable(battle_portal, "battle_start", "성문으로 이동하여 전투 준비", 8.0)

func _on_battle_requested():
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

func _process(_delta: float):
	if GameManager.current_location != GameManager.Location.LOBBY:
		return
	if get_tree().paused or hud == null:
		return
	if player == null or not is_instance_valid(player):
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
		if _last_prompt_id != "":
			_last_prompt_id = ""
			hud.call("clear_interaction_prompt")
		return

	var prompt_id: String = str(best.get("id", ""))
	if prompt_id != _last_prompt_id:
		_last_prompt_id = prompt_id
		hud.call("set_interaction_prompt", str(best.get("label", "상호작용")), GameActions.is_mobile())

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
	var id := str(entry.get("id", ""))
	var node = entry.get("node")
	match id:
		"battle_start":
			battle_prep_ui.call("open", GameData.current_selected_stage_id)
		"forge":
			_open_hud_screen("inventory")
			UiFeedback.show_info("대장간에서 장비를 관리합니다.")
		"shop":
			_open_hud_screen("shop")
		"inn":
			_open_hud_screen("shop")
			UiFeedback.show_info("여관 주인 엘레나에게 말을 걸어 휴식할 수 있습니다.")
		"quest":
			_open_hud_screen("quest")
		"npc_blacksmith":
			_show_npc_dialog(node, "대장간에서 장비를 손볼 수 있습니다.", [
				{"label": "🔨 장비 관리 열기", "action": "inventory"},
				{"label": "📖 도감 보기", "action": "collection"}
			])
		"npc_merchant":
			_show_npc_dialog(node, "필요한 장비와 물약이 있으면 말씀하세요.", [
				{"label": "🪙 상점 열기", "action": "shop"},
				{"label": "🎒 장비 관리 열기", "action": "inventory"}
			])
		"npc_innkeeper":
			_show_npc_dialog(node, "따뜻한 침대와 식사가 준비되어 있어요. 50 골드면 체력을 회복할 수 있습니다.", [
				{"label": "🏨 휴식하기 (50 골드)", "action": "rest"},
				{"label": "💬 그냥 대화하기", "action": ""}
			])
		"npc_guard":
			_show_npc_dialog(node, "북쪽 성문 밖은 위험합니다. 준비가 되셨나요?", [
				{"label": "⚔️ 전투 준비 열기", "action": "battle_start"},
				{"label": "🗺️ 지도 보기", "action": "map"}
			])
		"npc_villager":
			_show_npc_dialog(node, "마을 소식을 들려드릴게요.", [
				{"label": "📜 퀘스트 확인", "action": "quest"},
				{"label": "📖 도감 보기", "action": "collection"}
			])
		_:
			UiFeedback.show_info("아직 사용할 수 없는 대상입니다.")

func _open_hud_screen(screen_id: String):
	if hud and hud.has_method("open_screen"):
		hud.call("open_screen", screen_id)
	else:
		UiFeedback.show_error("화면을 열 수 없습니다.")

func _show_npc_dialog(node, line: String, options: Array):
	var npc_name := "마을 주민"
	var role := ""
	if node != null and is_instance_valid(node):
		npc_name = str(node.get("npc_name")) if node.get("npc_name") != null else npc_name
		role = str(node.get("npc_role")) if node.get("npc_role") != null else ""
	if hud and hud.has_method("show_npc_dialog"):
		hud.call("show_npc_dialog", npc_name, role, line, options)
	else:
		UiFeedback.show_info(line)

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

func _build_village_environment():
	var root = Node3D.new()
	root.name = "VillageProps"
	add_child(root)
	
	# 1. Central Fountain
	_build_fountain(root, Vector3(0, 0, 0))
	
	# 2. Street Lamps around plaza
	_create_lamp(root, Vector3(-9, 0, -9))
	_create_lamp(root, Vector3(9, 0, -9))
	_create_lamp(root, Vector3(-9, 0, 9))
	_create_lamp(root, Vector3(9, 0, 9))
	
	# 3. Benches around plaza
	_create_bench(root, Vector3(-6, 0, 0), 0.0)
	_create_bench(root, Vector3(6, 0, 0), PI)
	_create_bench(root, Vector3(0, 0, -6), PI * 0.5)
	
	# 4. Notice Board
	_create_notice_board(root, Vector3(8, 0, 4), -PI * 0.25)
	
	# 5. Blacksmith Shop (West: X=-20, Z=0)
	_create_building(root, Vector3(-22, 0, 0), Vector3(10, 5, 8), Color(0.4, 0.42, 0.45), Color(0.2, 0.2, 0.25), "대장간\n[Blacksmith]", true, "forge", "대장간 이용하기", 9.0)
	
	# 6. Weapon & Equipment Shop (East: X=20, Z=0)
	_create_building(root, Vector3(22, 0, 0), Vector3(10, 5, 8), Color(0.7, 0.65, 0.55), Color(0.65, 0.2, 0.18), "무기 상점\n[Equipment Shop]", false, "shop", "무기 상점 열기", 9.0)
	
	# 7. Inn / Tavern (South-East: X=18, Z=18)
	_create_building(root, Vector3(18, 0, 20), Vector3(12, 7, 10), Color(0.55, 0.42, 0.3), Color(0.2, 0.35, 0.55), "여관\n[Tavern & Inn]", false, "inn", "여관에서 휴식하기", 10.0)
	
	# 8. Residential Houses
	_create_building(root, Vector3(-18, 0, 18), Vector3(8, 4.5, 7), Color(0.75, 0.72, 0.65), Color(0.75, 0.3, 0.15), "마을 주택 A")
	_create_building(root, Vector3(-20, 0, -18), Vector3(8, 4.5, 7), Color(0.7, 0.7, 0.65), Color(0.25, 0.45, 0.25), "마을 주택 B")
	_create_building(root, Vector3(20, 0, -18), Vector3(8, 4.5, 7), Color(0.72, 0.68, 0.6), Color(0.5, 0.25, 0.4), "마을 주택 C")
	
	# 9. Small Pond in peaceful park corner (South-West)
	_create_pond(root, Vector3(-8, 0, 18))
	
	# 10. North Gate (출구 / 성문: Z=-32)
	_create_castle_gate(root, Vector3(0, 0, -32))
	
	# 11. Crates & Barrels
	_create_crate_stack(root, Vector3(-16, 0, -4))
	_create_crate_stack(root, Vector3(16, 0, -4))
	_create_crate_stack(root, Vector3(14, 0, 15))
	
	# 12. Trees & Flowers along roads
	_populate_nature(root)
	
	# 13. Spawn NPCs
	_spawn_npcs()

# ----------------- BUILDINGS & STRUCTURES -----------------

func _build_fountain(parent: Node3D, pos: Vector3):
	var f = StaticBody3D.new()
	f.position = pos
	f.collision_layer = 32
	f.collision_mask = 3
	
	# Outer Basin (Ring / Cylinder)
	var basin = MeshInstance3D.new()
	var basin_mesh = CylinderMesh.new()
	basin_mesh.top_radius = 3.2
	basin_mesh.bottom_radius = 3.4
	basin_mesh.height = 0.8
	basin.mesh = basin_mesh
	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.65, 0.65, 0.68)
	stone_mat.roughness = 0.8
	basin.material_override = stone_mat
	basin.position.y = 0.4
	f.add_child(basin)
	
	# Water surface
	var water = MeshInstance3D.new()
	var water_mesh = CylinderMesh.new()
	water_mesh.top_radius = 2.9
	water_mesh.bottom_radius = 2.9
	water_mesh.height = 0.1
	water.mesh = water_mesh
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.2, 0.6, 0.9, 0.8)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.1
	water.material_override = water_mat
	water.position.y = 0.65
	f.add_child(water)
	
	# Center Pillar & Top Spout
	var pillar = MeshInstance3D.new()
	var p_mesh = CylinderMesh.new()
	p_mesh.top_radius = 0.6
	p_mesh.bottom_radius = 0.8
	p_mesh.height = 2.2
	pillar.mesh = p_mesh
	pillar.material_override = stone_mat
	pillar.position.y = 1.1
	f.add_child(pillar)
	
	var spout = MeshInstance3D.new()
	var sp_mesh = SphereMesh.new()
	sp_mesh.radius = 0.5
	sp_mesh.height = 0.8
	spout.mesh = sp_mesh
	var spout_mat = StandardMaterial3D.new()
	spout_mat.albedo_color = Color(0.4, 0.8, 1.0, 0.9)
	spout_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spout_mat.emission_enabled = true
	spout_mat.emission = Color(0.3, 0.7, 1.0)
	spout_mat.emission_energy_multiplier = 1.5
	spout.material_override = spout_mat
	spout.position.y = 2.3
	f.add_child(spout)
	
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 3.3
	shape.height = 1.2
	col.shape = shape
	col.position.y = 0.6
	f.add_child(col)
	
	parent.add_child(f)

func _create_building(parent: Node3D, pos: Vector3, size: Vector3, wall_color: Color, roof_color: Color, title: String, is_forge: bool = false, interaction_id: String = "", interaction_label: String = "", interaction_radius: float = 8.0) -> StaticBody3D:
	var b = StaticBody3D.new()
	b.position = pos
	b.collision_layer = 32
	b.collision_mask = 3
	
	# Walls
	var walls = MeshInstance3D.new()
	var w_mesh = BoxMesh.new()
	w_mesh.size = size
	walls.mesh = w_mesh
	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = wall_color
	w_mat.roughness = 0.8
	walls.material_override = w_mat
	walls.position.y = size.y * 0.5
	b.add_child(walls)
	
	# Roof (Prism / Pyramid / Box)
	var roof = MeshInstance3D.new()
	var r_mesh = BoxMesh.new()
	r_mesh.size = Vector3(size.x + 0.8, 1.6, size.z + 0.8)
	roof.mesh = r_mesh
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = roof_color
	r_mat.roughness = 0.7
	roof.material_override = r_mat
	roof.position.y = size.y + 0.8
	b.add_child(roof)
	
	# Door & Windows
	var door = MeshInstance3D.new()
	var d_mesh = BoxMesh.new()
	d_mesh.size = Vector3(1.6, 2.4, 0.2)
	door.mesh = d_mesh
	var d_mat = StandardMaterial3D.new()
	d_mat.albedo_color = Color(0.3, 0.2, 0.1)
	door.material_override = d_mat
	door.position = Vector3(0, 1.2, size.z * 0.5 + 0.05)
	b.add_child(door)
	
	# Signboard with 3D Text
	var sign_lbl = Label3D.new()
	sign_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_lbl.no_depth_test = true
	sign_lbl.text = title
	sign_lbl.font_size = 32
	sign_lbl.outline_size = 8
	sign_lbl.outline_modulate = Color(0, 0, 0, 1)
	sign_lbl.position = Vector3(0, size.y + 1.2, size.z * 0.5 + 1.0)
	b.add_child(sign_lbl)
	
	if is_forge:
		# Chimney
		var chim = MeshInstance3D.new()
		var ch_mesh = BoxMesh.new()
		ch_mesh.size = Vector3(1.2, size.y + 2.5, 1.2)
		chim.mesh = ch_mesh
		var ch_mat = StandardMaterial3D.new()
		ch_mat.albedo_color = Color(0.3, 0.3, 0.32)
		chim.material_override = ch_mat
		chim.position = Vector3(-size.x * 0.35, (size.y + 2.5) * 0.5, -size.z * 0.3)
		b.add_child(chim)
		
		# Anvil
		var anvil = MeshInstance3D.new()
		var a_mesh = BoxMesh.new()
		a_mesh.size = Vector3(0.8, 0.7, 0.5)
		anvil.mesh = a_mesh
		var a_mat = StandardMaterial3D.new()
		a_mat.albedo_color = Color(0.15, 0.15, 0.18)
		a_mat.metallic = 0.9
		anvil.material_override = a_mat
		anvil.position = Vector3(2.5, 0.35, size.z * 0.5 + 1.5)
		b.add_child(anvil)
	
	# Collision
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y * 0.5
	b.add_child(col)
	
	parent.add_child(b)
	if interaction_id != "":
		_register_interactable(b, interaction_id, interaction_label, interaction_radius)
	return b

func _create_lamp(parent: Node3D, pos: Vector3):
	var lamp = StaticBody3D.new()
	lamp.position = pos
	lamp.collision_layer = 32
	lamp.collision_mask = 3
	
	# Pole
	var pole = MeshInstance3D.new()
	var p_mesh = CylinderMesh.new()
	p_mesh.top_radius = 0.1
	p_mesh.bottom_radius = 0.15
	p_mesh.height = 3.6
	pole.mesh = p_mesh
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.2, 0.2, 0.22)
	p_mat.metallic = 0.8
	pole.material_override = p_mat
	pole.position.y = 1.8
	lamp.add_child(pole)
	
	# Lantern Head
	var head = MeshInstance3D.new()
	var h_mesh = BoxMesh.new()
	h_mesh.size = Vector3(0.5, 0.6, 0.5)
	head.mesh = h_mesh
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(1.0, 0.85, 0.4)
	h_mat.emission_enabled = true
	h_mat.emission = Color(1.0, 0.85, 0.4)
	h_mat.emission_energy_multiplier = 2.5
	head.material_override = h_mat
	head.position.y = 3.6
	lamp.add_child(head)
	
	# Warm Light
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 1.5
	light.omni_range = 9.0
	light.position.y = 3.5
	lamp.add_child(light)
	
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.2
	shape.height = 3.6
	col.shape = shape
	col.position.y = 1.8
	lamp.add_child(col)
	
	parent.add_child(lamp)

func _create_bench(parent: Node3D, pos: Vector3, rot_y: float):
	var b = StaticBody3D.new()
	b.position = pos
	b.rotation.y = rot_y
	b.collision_layer = 32
	b.collision_mask = 3
	
	var seat = MeshInstance3D.new()
	var s_mesh = BoxMesh.new()
	s_mesh.size = Vector3(2.2, 0.15, 0.6)
	seat.mesh = s_mesh
	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.48, 0.32, 0.18)
	seat.material_override = w_mat
	seat.position.y = 0.5
	b.add_child(seat)
	
	var back = MeshInstance3D.new()
	var bk_mesh = BoxMesh.new()
	bk_mesh.size = Vector3(2.2, 0.6, 0.1)
	back.mesh = bk_mesh
	back.material_override = w_mat
	back.position = Vector3(0, 0.9, -0.25)
	b.add_child(back)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.2, 0.9, 0.6)
	col.shape = shape
	col.position.y = 0.45
	b.add_child(col)
	
	parent.add_child(b)

func _create_notice_board(parent: Node3D, pos: Vector3, rot_y: float) -> StaticBody3D:
	var nb = StaticBody3D.new()
	nb.position = pos
	nb.rotation.y = rot_y
	nb.collision_layer = 32
	nb.collision_mask = 3
	
	var board = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(2.5, 1.8, 0.2)
	board.mesh = b_mesh
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.45, 0.3, 0.18)
	board.material_override = b_mat
	board.position.y = 1.8
	nb.add_child(board)
	
	var post1 = MeshInstance3D.new()
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.2, 2.0, 0.2)
	post1.mesh = p_mesh
	post1.material_override = b_mat
	post1.position = Vector3(-1.0, 1.0, 0)
	nb.add_child(post1)
	
	var post2 = MeshInstance3D.new()
	post2.mesh = p_mesh
	post2.material_override = b_mat
	post2.position = Vector3(1.0, 1.0, 0)
	nb.add_child(post2)
	
	var lbl = Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.text = "📜 마을 게시판 📜\n\"최근 북쪽 숲에 몬스터가 출몰 중!\n모험가들의 활약을 기대합니다.\""
	lbl.font_size = 24
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	lbl.position = Vector3(0, 2.0, 0.15)
	nb.add_child(lbl)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.5, 2.2, 0.4)
	col.shape = shape
	col.position.y = 1.1
	nb.add_child(col)
	
	parent.add_child(nb)
	_register_interactable(nb, "quest", "게시판 보기", 4.5)
	return nb

func _create_pond(parent: Node3D, pos: Vector3):
	var pond = Node3D.new()
	pond.position = pos
	
	var water = MeshInstance3D.new()
	var w_mesh = CylinderMesh.new()
	w_mesh.top_radius = 5.0
	w_mesh.bottom_radius = 4.8
	w_mesh.height = 0.1
	water.mesh = w_mesh
	var w_mat = StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.15, 0.55, 0.75, 0.8)
	w_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	w_mat.roughness = 0.15
	water.material_override = w_mat
	water.position.y = 0.05
	pond.add_child(water)
	
	# Surrounding stones
	for i in range(16):
		var stone = MeshInstance3D.new()
		var s_mesh = BoxMesh.new()
		var sz = randf_range(0.6, 1.2)
		s_mesh.size = Vector3(sz, sz * 0.6, sz)
		stone.mesh = s_mesh
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.5, 0.52, 0.55)
		stone.material_override = s_mat
		var a = (float(i) / 16.0) * TAU
		stone.position = Vector3(cos(a) * 5.2, sz * 0.3, sin(a) * 5.2)
		pond.add_child(stone)
	
	parent.add_child(pond)

func _create_castle_gate(parent: Node3D, pos: Vector3) -> StaticBody3D:
	var gate = StaticBody3D.new()
	gate.position = pos
	gate.collision_layer = 32
	gate.collision_mask = 3
	
	var s_mat = StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.48, 0.48, 0.52)
	s_mat.roughness = 0.9
	
	# Left Tower
	var tower_l = MeshInstance3D.new()
	var t_mesh = BoxMesh.new()
	t_mesh.size = Vector3(4.0, 9.0, 4.0)
	tower_l.mesh = t_mesh
	tower_l.material_override = s_mat
	tower_l.position = Vector3(-6.0, 4.5, 0)
	gate.add_child(tower_l)
	
	# Right Tower
	var tower_r = MeshInstance3D.new()
	tower_r.mesh = t_mesh
	tower_r.material_override = s_mat
	tower_r.position = Vector3(6.0, 4.5, 0)
	gate.add_child(tower_r)
	
	# Top Arch Span
	var arch = MeshInstance3D.new()
	var a_mesh = BoxMesh.new()
	a_mesh.size = Vector3(12.0, 2.0, 3.5)
	arch.mesh = a_mesh
	arch.material_override = s_mat
	arch.position = Vector3(0, 7.5, 0)
	gate.add_child(arch)
	
	# Sign on the gate
	var lbl = Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.text = "⚔️ 북쪽 외곽 성문 ⚔️\n[밖으로 나가면 숲길과 전투 지역]"
	lbl.font_size = 32
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0, 0, 0, 1)
	lbl.position = Vector3(0, 5.0, 2.2)
	gate.add_child(lbl)
	
	# Perimeter walls extending left and right
	var wall_l = MeshInstance3D.new()
	var w_mesh = BoxMesh.new()
	w_mesh.size = Vector3(30.0, 5.5, 2.0)
	wall_l.mesh = w_mesh
	wall_l.material_override = s_mat
	wall_l.position = Vector3(-23.0, 2.75, 0)
	gate.add_child(wall_l)
	
	var wall_r = MeshInstance3D.new()
	wall_r.mesh = w_mesh
	wall_r.material_override = s_mat
	wall_r.position = Vector3(23.0, 2.75, 0)
	gate.add_child(wall_r)
	
	# Collisions
	var col_l = CollisionShape3D.new()
	var col_l_shape = BoxShape3D.new()
	col_l_shape.size = Vector3(34.0, 8.0, 4.0)
	col_l.shape = col_l_shape
	col_l.position = Vector3(-21.0, 4.0, 0)
	gate.add_child(col_l)
	
	var col_r = CollisionShape3D.new()
	col_r.shape = col_l_shape
	col_r.position = Vector3(21.0, 4.0, 0)
	gate.add_child(col_r)
	
	parent.add_child(gate)
	_register_interactable(gate, "battle_start", "성문으로 이동하여 전투 준비", 8.0)
	return gate

func _create_crate_stack(parent: Node3D, pos: Vector3):
	var stack = StaticBody3D.new()
	stack.position = pos
	stack.collision_layer = 32
	stack.collision_mask = 3
	
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.55, 0.38, 0.22)
	
	var c1 = MeshInstance3D.new()
	var m = BoxMesh.new()
	m.size = Vector3(1.2, 1.2, 1.2)
	c1.mesh = m
	c1.material_override = c_mat
	c1.position = Vector3(-0.6, 0.6, 0)
	stack.add_child(c1)
	
	var c2 = MeshInstance3D.new()
	c2.mesh = m
	c2.material_override = c_mat
	c2.position = Vector3(0.6, 0.6, 0)
	stack.add_child(c2)
	
	var c3 = MeshInstance3D.new()
	c3.mesh = m
	c3.material_override = c_mat
	c3.position = Vector3(0, 1.8, 0)
	stack.add_child(c3)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.4, 2.4, 1.4)
	col.shape = shape
	col.position.y = 1.2
	stack.add_child(col)
	
	parent.add_child(stack)

func _populate_nature(parent: Node3D):
	seed(101)
	for i in range(25):
		var tree = _create_village_tree()
		var pos = Vector3(randf_range(-35, 35), 0, randf_range(-55, 35))
		# Avoid plaza and main north road
		if pos.length() < 13.0 or (abs(pos.x) < 4.5 and pos.z < 0 and pos.z > -45):
			continue
		tree.position = pos
		parent.add_child(tree)
	
	for i in range(40):
		var flower = _create_village_flower()
		var pos = Vector3(randf_range(-30, 30), 0, randf_range(-40, 30))
		flower.position = pos
		parent.add_child(flower)

func _create_village_tree() -> StaticBody3D:
	var tree = StaticBody3D.new()
	tree.collision_layer = 32
	tree.collision_mask = 3
	
	var trunk = MeshInstance3D.new()
	var t_mesh = CylinderMesh.new()
	t_mesh.top_radius = 0.25
	t_mesh.bottom_radius = 0.35
	t_mesh.height = 2.4
	trunk.mesh = t_mesh
	var t_mat = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.42, 0.28, 0.16)
	trunk.material_override = t_mat
	trunk.position.y = 1.2
	tree.add_child(trunk)
	
	var foliage = MeshInstance3D.new()
	var f_mesh = BoxMesh.new()
	var s = randf_range(2.2, 3.0)
	f_mesh.size = Vector3(s, s * 0.9, s)
	foliage.mesh = f_mesh
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.2, 0.6 + randf() * 0.1, 0.25)
	foliage.material_override = f_mat
	foliage.position.y = 2.8
	tree.add_child(foliage)
	
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 2.4
	col.shape = shape
	col.position.y = 1.2
	tree.add_child(col)
	return tree

func _create_village_flower() -> Node3D:
	var flower = Node3D.new()
	var f_mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(0.25, 0.25, 0.25)
	f_mesh.mesh = b_mesh
	var f_mat = StandardMaterial3D.new()
	var colors = [Color(1, 0.4, 0.4), Color(1, 0.85, 0.2), Color(0.8, 0.4, 1), Color(0.3, 0.8, 1)]
	f_mat.albedo_color = colors[randi() % colors.size()]
	f_mesh.material_override = f_mat
	f_mesh.position.y = 0.12
	flower.add_child(f_mesh)
	return flower

# ----------------- NPCS -----------------

func _spawn_npcs():
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
	bs.position = Vector3(-16, 0, 2)
	npc_root.add_child(bs)
	_register_interactable(bs, "npc_blacksmith", "헤파이스토와 대화하기", 3.8)
	
	# 2. Weapon Merchant
	var shop = npc_scene.instantiate()
	shop.npc_name = "마커스"
	shop.npc_role = "무기 상인"
	shop.outfit_color = Color(0.25, 0.35, 0.65)
	shop.position = Vector3(16, 0, 2)
	npc_root.add_child(shop)
	_register_interactable(shop, "npc_merchant", "마커스와 대화하기", 3.8)
	
	# 3. Innkeeper
	var inn = npc_scene.instantiate()
	inn.npc_name = "엘레나"
	inn.npc_role = "여관 주인"
	inn.outfit_color = Color(0.65, 0.25, 0.45)
	inn.position = Vector3(14, 0, 16)
	npc_root.add_child(inn)
	_register_interactable(inn, "npc_innkeeper", "엘레나와 대화하기", 3.8)
	
	# 4. Gate Guards
	var guard1 = npc_scene.instantiate()
	guard1.npc_name = "경비병 카일"
	guard1.npc_role = "외곽 경비병"
	guard1.outfit_color = Color(0.5, 0.55, 0.6)
	guard1.position = Vector3(-3.2, 0, -30)
	npc_root.add_child(guard1)
	_register_interactable(guard1, "npc_guard", "경비병과 대화하기", 3.8)
	
	var guard2 = npc_scene.instantiate()
	guard2.npc_name = "경비병 레오"
	guard2.npc_role = "외곽 경비병"
	guard2.outfit_color = Color(0.5, 0.55, 0.6)
	guard2.position = Vector3(3.2, 0, -30)
	npc_root.add_child(guard2)
	_register_interactable(guard2, "npc_guard", "경비병과 대화하기", 3.8)
	
	# 5. Wandering Villagers (Patrolling)
	var v1 = npc_scene.instantiate()
	v1.npc_name = "토마스"
	v1.npc_role = "산책 중인 주민"
	v1.is_patrolling = true
	v1.patrol_radius = 7.0
	v1.outfit_color = Color(0.3, 0.55, 0.3)
	v1.position = Vector3(-4, 0, -3)
	npc_root.add_child(v1)
	_register_interactable(v1, "npc_villager", "토마스와 대화하기", 3.2)
	
	var v2 = npc_scene.instantiate()
	v2.npc_name = "클로이"
	v2.npc_role = "여행자"
	v2.is_patrolling = true
	v2.patrol_radius = 8.0
	v2.outfit_color = Color(0.7, 0.45, 0.2)
	v2.position = Vector3(4, 0, -3)
	npc_root.add_child(v2)
	_register_interactable(v2, "npc_villager", "클로이와 대화하기", 3.2)
