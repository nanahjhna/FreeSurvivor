extends SceneTree

func _init() -> void:
	var root := Node3D.new()
	root.name = "Char01Reference"
	get_root().add_child(root)

	var model_scene := load("res://assets/char/char01/char01.glb") as PackedScene
	if model_scene == null:
		printerr("CHAR01_REFERENCE_LOAD_FAILED")
		quit(1)
		return
	var model := model_scene.instantiate()
	root.add_child(model)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#071326")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9ab7d5")
	environment.ambient_light_energy = 0.75
	env.environment = environment
	root.add_child(env)

	var camera := Camera3D.new()
	camera.position = Vector3(2.6, 1.9, 4.8)
	camera.fov = 42.0
	root.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)

	_add_light(root, Vector3(2.8, 4.0, 2.4), Color("#ffd38a"), 5.0, 4.0)
	_add_light(root, Vector3(-3.0, 2.3, 1.0), Color("#4ba9ff"), 3.0, 3.0)
	_add_light(root, Vector3(0.0, 3.5, -2.5), Color("#63f0c3"), 4.0, 3.0)

	await process_frame
	await process_frame
	var image := get_root().get_viewport().get_texture().get_image()
	image.save_png("C:/Users/nanah/Documents/FreeSurvivor/assets/ui/char01_reference.png")
	print("CHAR01_REFERENCE_SAVED ", image.get_width(), "x", image.get_height())
	quit()

func _add_light(parent: Node3D, position: Vector3, color: Color, energy: float, indirect: float) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 8.0
	light.shadow_enabled = true
	parent.add_child(light)
