extends Node3D
## Live 3D stage preview for the dungeon selection panel.

const STAGE_MAP_SCRIPT := preload("res://scenes/stages/stage_grassland.gd")
const GROUND_COLOR := Color(0.4, 0.68, 0.2)

func _ready() -> void:
	_create_environment()
	_create_ground()
	_create_lighting()
	_create_camera()
	var map_root := Node3D.new()
	map_root.name = "StageGrasslandPreview"
	map_root.set_script(STAGE_MAP_SCRIPT)
	map_root.set("preview_only", true)
	add_child(map_root)

func _create_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.65, 0.95)
	sky_material.sky_horizon_color = Color(0.8, 0.9, 0.98)
	sky_material.ground_bottom_color = Color(0.22, 0.42, 0.12)
	sky_material.ground_horizon_color = Color(0.62, 0.8, 0.36)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.72, 0.82, 0.7)
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

func _create_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "StagePreviewGround"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(180, 180)
	ground.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = GROUND_COLOR
	material.roughness = 0.85
	ground.material_override = material
	add_child(ground)

func _create_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

func _create_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "StagePreviewCamera"
	camera.position = Vector3(0, 9.5, 22.0)
	camera.fov = 53.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 1.0, -10.0), Vector3.UP)
