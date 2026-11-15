extends Node3D

@onready var player: CharacterBody3D = $Player

func _ready():
	GameManager.current_location = GameManager.Location.LOBBY
	GameManager.current_state = GameManager.GameState.PLAYING
	
	if player:
		# Disable combat features in town
		player.is_combat_enabled = false
		# Set player at town central plaza
		player.global_position = Vector3(0, 0.2, 5.0)
	
	_build_village_environment()

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
	_create_building(root, Vector3(-22, 0, 0), Vector3(10, 5, 8), Color(0.4, 0.42, 0.45), Color(0.2, 0.2, 0.25), "대장간\n[Blacksmith]", true)
	
	# 6. Weapon & Equipment Shop (East: X=20, Z=0)
	_create_building(root, Vector3(22, 0, 0), Vector3(10, 5, 8), Color(0.7, 0.65, 0.55), Color(0.65, 0.2, 0.18), "무기 상점\n[Equipment Shop]")
	
	# 7. Inn / Tavern (South-East: X=18, Z=18)
	_create_building(root, Vector3(18, 0, 20), Vector3(12, 7, 10), Color(0.55, 0.42, 0.3), Color(0.2, 0.35, 0.55), "여관\n[Tavern & Inn]")
	
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

func _create_building(parent: Node3D, pos: Vector3, size: Vector3, wall_color: Color, roof_color: Color, title: String, is_forge: bool = false):
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

func _create_notice_board(parent: Node3D, pos: Vector3, rot_y: float):
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

func _create_castle_gate(parent: Node3D, pos: Vector3):
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
	
	# 2. Weapon Merchant
	var shop = npc_scene.instantiate()
	shop.npc_name = "마커스"
	shop.npc_role = "무기 상인"
	shop.outfit_color = Color(0.25, 0.35, 0.65)
	shop.position = Vector3(16, 0, 2)
	npc_root.add_child(shop)
	
	# 3. Innkeeper
	var inn = npc_scene.instantiate()
	inn.npc_name = "엘레나"
	inn.npc_role = "여관 주인"
	inn.outfit_color = Color(0.65, 0.25, 0.45)
	inn.position = Vector3(14, 0, 16)
	npc_root.add_child(inn)
	
	# 4. Gate Guards
	var guard1 = npc_scene.instantiate()
	guard1.npc_name = "경비병 카일"
	guard1.npc_role = "외곽 경비병"
	guard1.outfit_color = Color(0.5, 0.55, 0.6)
	guard1.position = Vector3(-3.2, 0, -30)
	npc_root.add_child(guard1)
	
	var guard2 = npc_scene.instantiate()
	guard2.npc_name = "경비병 레오"
	guard2.npc_role = "외곽 경비병"
	guard2.outfit_color = Color(0.5, 0.55, 0.6)
	guard2.position = Vector3(3.2, 0, -30)
	npc_root.add_child(guard2)
	
	# 5. Wandering Villagers (Patrolling)
	var v1 = npc_scene.instantiate()
	v1.npc_name = "토마스"
	v1.npc_role = "산책 중인 주민"
	v1.is_patrolling = true
	v1.patrol_radius = 7.0
	v1.outfit_color = Color(0.3, 0.55, 0.3)
	v1.position = Vector3(-4, 0, -3)
	npc_root.add_child(v1)
	
	var v2 = npc_scene.instantiate()
	v2.npc_name = "클로이"
	v2.npc_role = "여행자"
	v2.is_patrolling = true
	v2.patrol_radius = 8.0
	v2.outfit_color = Color(0.7, 0.45, 0.2)
	v2.position = Vector3(4, 0, -3)
	npc_root.add_child(v2)
