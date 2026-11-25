extends SubViewportContainer
## Lightweight 3D village backdrop used only by the title screen.

const VILLAGE_ENVIRONMENT_SCRIPT := preload("res://scenes/stages/village_environment.gd")
const GROUND_SHADER := preload("res://scenes/stages/village_ground.gdshader")

var _viewport: SubViewport
var _village_map: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	var android := OS.has_feature("android")
	if android:
		stretch_shrink = 2
	_viewport = SubViewport.new()
	_viewport.name = "VillageTitleViewport"
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.transparent_bg = false
	add_child(_viewport)

	var world := Node3D.new()
	world.name = "VillageTitleWorld"
	_viewport.add_child(world)
	_create_environment(world)
	_create_ground(world)
	_create_village_map(world)
	_create_lighting(world)
	_create_camera(world)
	if android:
		resized.connect(_refresh_background)
		visibility_changed.connect(_refresh_background)
		_refresh_background()

func _refresh_background() -> void:
	if is_visible_in_tree():
		_viewport.set_deferred("render_target_update_mode", SubViewport.UPDATE_ONCE)

func _create_environment(parent: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.52, 0.78)
	sky_material.sky_horizon_color = Color(0.77, 0.87, 0.91)
	sky_material.ground_bottom_color = Color(0.18, 0.29, 0.15)
	sky_material.ground_horizon_color = Color(0.64, 0.74, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.73, 0.81, 0.93)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	parent.add_child(world_environment)

func _create_ground(parent: Node3D) -> void:
	var ground := MeshInstance3D.new()
	ground.name = "VillageTitleGround"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(130, 140)
	ground.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	ground.material_override = material
	parent.add_child(ground)

func _create_lighting(parent: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_color = Color(1.0, 0.86, 0.70)
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 52.0
	parent.add_child(sun)

func _create_camera(parent: Node3D) -> void:
	var camera := Camera3D.new()
	camera.name = "VillageTitleCamera"
	camera.position = Vector3(0, 8.2, 20.0)
	camera.fov = 52.0
	camera.current = true
	parent.add_child(camera)
	camera.look_at(Vector3(0, 1.25, 1.0), Vector3.UP)

func _create_village_map(parent: Node3D) -> void:
	_village_map = Node3D.new()
	_village_map.name = "VillageEnvironment"
	_village_map.set_script(VILLAGE_ENVIRONMENT_SCRIPT)
	_village_map.set("preview_only", true)
	parent.add_child(_village_map)
	if not SceneTransition.is_transitioning:
		_village_map.call("build", Vector3(0, 0, -38))

func prepare_transition(report_progress: Callable) -> void:
	await report_progress.call(77.0, "타이틀 배경 준비 중…")
	await _village_map.call("build", Vector3(0, 0, -38), report_progress)
	if OS.has_feature("android"):
		_refresh_background()
