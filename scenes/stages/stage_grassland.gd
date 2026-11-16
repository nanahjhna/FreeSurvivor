extends Node3D

func _ready():
	GameManager.current_location = GameManager.Location.BATTLE
	# LevelUpPanel opens the five-card starting draft from its _ready().
	# Do not overwrite its LEVEL_UP state while that draft is active.
	if GameManager.starting_draft_picks <= 0:
		GameManager.current_state = GameManager.GameState.PLAYING
	var player = find_child("Player", true, false)
	if player:
		player.is_combat_enabled = true
	_generate_environment()

func _generate_environment():
	var decor_root = Node3D.new()
	decor_root.name = "Decorations"
	add_child(decor_root)
	
	# Seed for deterministic yet organic scenery
	seed(42)
	
	# Trees (avoid spawn radius within 12m of center)
	for i in range(35):
		var tree = _create_tree()
		var pos = _get_random_pos(14.0, 85.0)
		tree.position = pos
		decor_root.add_child(tree)
	
	# Rocks
	for i in range(25):
		var rock = _create_rock()
		var pos = _get_random_pos(10.0, 85.0)
		rock.position = pos
		decor_root.add_child(rock)
	
	# Ruined Stone Pillars
	for i in range(12):
		var pillar = _create_pillar()
		var pos = _get_random_pos(16.0, 75.0)
		pillar.position = pos
		decor_root.add_child(pillar)
	
	# Wooden Fences
	for i in range(10):
		var fence = _create_fence()
		var pos = _get_random_pos(18.0, 70.0)
		fence.position = pos
		fence.rotation.y = randf() * TAU
		decor_root.add_child(fence)
	
	# Batch the decorative flowers into one MultiMesh instead of 180 scene nodes.
	_create_flowers_multimesh(decor_root, 90)

func _get_random_pos(min_r: float, max_r: float) -> Vector3:
	var angle = randf() * TAU
	var dist = randf_range(min_r, max_r)
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

func _create_tree() -> StaticBody3D:
	var tree = StaticBody3D.new()
	tree.collision_layer = 32 # Layer 6: Environment
	tree.collision_mask = 3   # Player & Enemies
	
	# Trunk
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 2.2
	trunk.mesh = trunk_mesh
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.26, 0.14)
	trunk_mat.roughness = 0.8
	trunk.material_override = trunk_mat
	trunk.position.y = 1.1
	tree.add_child(trunk)
	
	# Foliage
	var leaves = MeshInstance3D.new()
	var leaves_mesh = BoxMesh.new()
	var s = randf_range(2.0, 2.8)
	leaves_mesh.size = Vector3(s, s * 0.9, s)
	leaves.mesh = leaves_mesh
	var leaves_mat = StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.18 + randf() * 0.1, 0.58 + randf() * 0.15, 0.22)
	leaves_mat.roughness = 0.6
	leaves.material_override = leaves_mat
	leaves.position.y = 2.6
	leaves.rotation.y = randf() * 0.8
	tree.add_child(leaves)
	
	# Collision
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 2.2
	col.shape = shape
	col.position.y = 1.1
	tree.add_child(col)
	
	return tree

func _create_rock() -> StaticBody3D:
	var rock = StaticBody3D.new()
	rock.collision_layer = 32
	rock.collision_mask = 3
	
	var r_mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	var sx = randf_range(1.0, 2.0)
	var sy = randf_range(0.6, 1.4)
	var sz = randf_range(1.0, 2.0)
	b_mesh.size = Vector3(sx, sy, sz)
	r_mesh.mesh = b_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.52, 0.55)
	mat.roughness = 0.9
	r_mesh.material_override = mat
	r_mesh.position.y = sy * 0.5
	r_mesh.rotation = Vector3(randf_range(-0.1, 0.1), randf() * TAU, randf_range(-0.1, 0.1))
	rock.add_child(r_mesh)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(sx, sy, sz)
	col.shape = shape
	col.position.y = sy * 0.5
	rock.add_child(col)
	
	return rock

func _create_pillar() -> StaticBody3D:
	var pillar = StaticBody3D.new()
	pillar.collision_layer = 32
	pillar.collision_mask = 3
	
	var p_mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	var h = randf_range(2.8, 4.2)
	b_mesh.size = Vector3(0.8, h, 0.8)
	p_mesh.mesh = b_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.67, 0.65)
	mat.roughness = 0.8
	p_mesh.material_override = mat
	p_mesh.position.y = h * 0.5
	p_mesh.rotation.z = randf_range(-0.12, 0.12)
	pillar.add_child(p_mesh)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.8, h, 0.8)
	col.shape = shape
	col.position.y = h * 0.5
	pillar.add_child(col)
	
	return pillar

func _create_fence() -> StaticBody3D:
	var fence = StaticBody3D.new()
	fence.collision_layer = 32
	fence.collision_mask = 3
	
	var f_mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(2.4, 0.7, 0.15)
	f_mesh.mesh = b_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.35, 0.2)
	f_mesh.material_override = mat
	f_mesh.position.y = 0.4
	fence.add_child(f_mesh)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.4, 0.7, 0.15)
	col.shape = shape
	col.position.y = 0.4
	fence.add_child(col)
	
	return fence

func _create_flowers_multimesh(parent: Node3D, count: int):
	var flower_mesh := BoxMesh.new()
	flower_mesh.size = Vector3(0.25, 0.25, 0.25)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	flower_mesh.material = material
	var flowers := MultiMesh.new()
	flowers.transform_format = MultiMesh.TRANSFORM_3D
	flowers.use_colors = true
	flowers.mesh = flower_mesh
	flowers.instance_count = count
	var colors := [
		Color(1.0, 0.3, 0.4), Color(1.0, 0.85, 0.2),
		Color(0.8, 0.3, 1.0), Color(0.2, 0.8, 1.0)
	]
	for i in range(count):
		var pos := _get_random_pos(3.0, 80.0) + Vector3(0.0, 0.12, 0.0)
		flowers.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		flowers.set_instance_color(i, colors[randi_range(0, colors.size() - 1)])
	var flower_batch := MultiMeshInstance3D.new()
	flower_batch.multimesh = flowers
	flower_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flower_batch)
