extends Node3D

const BATTLE_CAMERA_FOV: float = 60.0
const KIT_GLTF_ROOT := "res://assets/map/Stylized Nature MegaKit[Standard]/glTF/"
const PLAYABLE_HALF_SIZE := 88.0

@export var preview_only: bool = false
var _kit_scene_cache: Dictionary = {}

func _ready():
	if preview_only:
		_generate_environment()
		return
	process_physics_priority = 100
	GameManager.current_location = GameManager.Location.BATTLE
	# LevelUpPanel opens the ten-pick starting draft from its _ready().
	# Do not overwrite its LEVEL_UP state while that draft is active.
	if GameManager.starting_draft_picks <= 0:
		GameManager.current_state = GameManager.GameState.PLAYING
	var player = find_child("Player", true, false)
	if player:
		player.is_combat_enabled = true
		if player.has_method("set_head_hp_bar_visible"):
			player.call("set_head_hp_bar_visible", true)
		var player_visual := player.get_node_or_null("VisualRoot") as Node3D
		if player_visual:
			player_visual.rotation.y = PI
		if player.has_method("set_first_person_mode"):
			player.call("set_first_person_mode", false)
		var camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
		if camera:
			camera.set("quarter_view_enabled", true)
			camera.set("quarter_distance", GameData.camera_distance)
			camera.set("quarter_elevation_degrees", GameData.camera_elevation_degrees)
			camera.set("quarter_azimuth_degrees", GameData.camera_azimuth_degrees)
			camera.set("back_view_enabled", false)
			camera.set("first_person_enabled", false)
			camera.fov = BATTLE_CAMERA_FOV
			camera.call("snap_to_target")
	_generate_environment()

func _physics_process(_delta: float) -> void:
	if preview_only:
		return
	var player := get_node_or_null("Player") as Node3D
	if player == null or not is_instance_valid(player):
		return
	var position := player.global_position
	var clamped := constrain_spawn_position(position)
	if position.is_equal_approx(clamped):
		return
	player.global_position = clamped
	var velocity_value = player.get("velocity")
	if velocity_value is Vector3:
		var velocity: Vector3 = velocity_value
		if not is_equal_approx(position.x, clamped.x):
			velocity.x = 0.0
		if not is_equal_approx(position.z, clamped.z):
			velocity.z = 0.0
		player.set("velocity", velocity)

func constrain_spawn_position(world_position: Vector3) -> Vector3:
	world_position.x = clampf(world_position.x, -PLAYABLE_HALF_SIZE, PLAYABLE_HALF_SIZE)
	world_position.z = clampf(world_position.z, -PLAYABLE_HALF_SIZE, PLAYABLE_HALF_SIZE)
	return world_position

func _generate_environment():
	var decor_root = Node3D.new()
	decor_root.name = "Decorations"
	add_child(decor_root)
	# Keep the layout repeatable so combat and screenshots remain easy to reproduce.
	seed(42)
	_build_kit_ground_path(decor_root)

	# The player and the first wave need a clear combat circle around the origin.
	var tree_pool := ["CommonTree_1", "CommonTree_3", "CommonTree_5", "Pine_1", "Pine_3", "DeadTree_2"]
	for i in range(28):
		var pos := _get_random_pos(15.0, 74.0)
		var tree_name: String = tree_pool[i % tree_pool.size()]
		_spawn_kit(decor_root, tree_name, pos, randf_range(1.22, 1.52), randf() * TAU, "tree")

	var rock_pool := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
	for i in range(22):
		var pos := _get_random_pos(11.0, 72.0)
		_spawn_kit(decor_root, rock_pool[i % rock_pool.size()], pos, randf_range(0.82, 1.18), randf() * TAU, "rock")

	# Low foliage uses fewer nodes than the old 180-node flower field while keeping
	# the warm, saturated look from the kit preview.
	var foliage_pool := ["Bush_Common", "Bush_Common_Flowers", "Grass_Common_Tall", "Grass_Wispy_Tall", "Flower_3_Group", "Flower_4_Group", "Mushroom_Common"]
	for i in range(34):
		var pos := _get_random_pos(8.0, 64.0)
		_spawn_kit(decor_root, foliage_pool[i % foliage_pool.size()], pos, randf_range(0.62, 0.88), randf() * TAU)

	# Small path stones guide the eye toward the north side of the arena.
	var path_pool := ["RockPath_Round_Wide", "RockPath_Round_Thin", "RockPath_Square_Wide", "RockPath_Square_Thin"]
	for i in range(12):
		var path_pos := Vector3(sin(float(i) * 0.45) * 3.5, 0.02, -8.0 - float(i) * 5.5)
		_spawn_kit(decor_root, path_pool[i % path_pool.size()], path_pos, randf_range(0.9, 1.15), randf_range(-0.18, 0.18))

func _build_kit_ground_path(parent: Node3D):
	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color(0.68, 0.58, 0.28, 1.0)
	path_material.roughness = 1.0
	for i in range(9):
		var strip := MeshInstance3D.new()
		strip.name = "KitPath_%02d" % i
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(7.5, 12.0)
		strip.mesh = mesh
		strip.material_override = path_material
		strip.position = Vector3(sin(float(i) * 0.45) * 3.5, 0.008, -8.0 - float(i) * 5.5)
		strip.rotation.y = sin(float(i) * 0.45) * 0.08
		parent.add_child(strip)

func _kit_scene(asset_name: String) -> PackedScene:
	if not _kit_scene_cache.has(asset_name):
		var scene := load(KIT_GLTF_ROOT + asset_name + ".gltf") as PackedScene
		if scene:
			_kit_scene_cache[asset_name] = scene
	return _kit_scene_cache.get(asset_name) as PackedScene

func _spawn_kit(parent: Node3D, asset_name: String, pos: Vector3, scale_factor: float, yaw: float, collision_kind: String = ""):
	var packed := _kit_scene(asset_name)
	if packed == null:
		push_warning("Missing Stylized Nature kit asset: " + asset_name)
		return
	var instance := packed.instantiate() as Node3D
	instance.name = "Kit_%s_%d" % [asset_name, parent.get_child_count()]
	instance.position = pos
	instance.rotation.y = yaw
	instance.scale = Vector3.ONE * scale_factor
	parent.add_child(instance)

	if collision_kind != "":
		var body := StaticBody3D.new()
		body.name = instance.name + "_Collision"
		body.collision_layer = 32
		body.collision_mask = 3
		var shape_node := CollisionShape3D.new()
		if collision_kind == "tree":
			var shape := CylinderShape3D.new()
			shape.radius = 0.55 * scale_factor
			shape.height = 4.2 * scale_factor
			shape_node.shape = shape
			shape_node.position = pos + Vector3(0.0, 2.1 * scale_factor, 0.0)
		else:
			var shape := BoxShape3D.new()
			shape.size = Vector3(2.4, 1.3, 2.4) * scale_factor
			shape_node.shape = shape
			shape_node.position = pos + Vector3(0.0, 0.65 * scale_factor, 0.0)
		body.add_child(shape_node)
		parent.add_child(body)

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
