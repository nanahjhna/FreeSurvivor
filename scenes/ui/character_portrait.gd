extends SubViewportContainer

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ANIMATION_SOURCE := preload("res://scripts/character_animation_source.gd")

var portrait_view: SubViewport
var actor: PlayerCharacter
var portrait_camera: Camera3D
var active_class := ""
var portrait_active := true
var framing_size := 2.7
var framing_height := 1.12
var framing_width := 0.0


func _ready() -> void:
	stretch = true
	stretch_shrink = 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_view = SubViewport.new()
	portrait_view.own_world_3d = true
	portrait_view.transparent_bg = true
	portrait_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(portrait_view)

	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#e7defe")
	world.environment.ambient_light_energy = 0.8
	portrait_view.add_child(world)

	for spec in [[Vector3(-31, -36, 0), Color("#ffe1b4"), 1.7], [Vector3(-14, 143, 0), Color("#a1baff"), 1.1]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		portrait_view.add_child(light)

	actor = PLAYER_SCENE.instantiate() as PlayerCharacter
	actor.preview_only = true
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor.is_combat_enabled = false
	portrait_view.add_child(actor)
	portrait_camera = Camera3D.new()
	portrait_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	portrait_view.add_child(portrait_camera)
	portrait_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	set_framing(2.7, 1.12)
	resized.connect(_apply_framing)
	portrait_camera.make_current()


func set_framing(ortho_size: float, target_height: float, min_world_width: float = 0.0) -> void:
	framing_size = ortho_size
	framing_height = target_height
	framing_width = min_world_width
	_apply_framing()


func _apply_framing() -> void:
	if portrait_camera == null:
		return
	var world_height_for_width := framing_width * size.y / maxf(1.0, size.x)
	portrait_camera.size = maxf(framing_size, world_height_for_width)
	portrait_camera.look_at_from_position(Vector3(0, framing_height + 0.43, 5), Vector3(0, framing_height, 0))


func show_character(class_id: String) -> void:
	if actor == null or active_class == class_id:
		return
	active_class = class_id
	actor.set_character_appearance(class_id)
	set_portrait_active(portrait_active)
	var visual := actor.get_node("VisualRoot") as Node3D
	visual.rotation.y = deg_to_rad(18)


func set_portrait_active(enabled: bool) -> void:
	portrait_active = enabled
	if portrait_view:
		portrait_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if enabled else SubViewport.UPDATE_DISABLED
	if actor and is_instance_valid(actor.model_animation_player):
		actor.model_animation_player.process_mode = Node.PROCESS_MODE_ALWAYS if enabled else Node.PROCESS_MODE_DISABLED
		actor.model_animation_player.active = enabled


func preview_clip(source: AnimationLibrary, clip_name: StringName) -> bool:
	if actor == null or not is_instance_valid(actor.model_animation_player):
		return false
	return ANIMATION_SOURCE.play_preview(actor.character_model, actor.model_animation_player, source, clip_name)

func preview_skill(skill_id: String, slot_key: String = "") -> bool:
	if actor == null or not is_instance_valid(actor.model_animation_player):
		return false
	var animation_key := PlayerManager.get_skill_animation_key(skill_id, slot_key)
	var clip_name := str(actor.model_clips.get(animation_key, ""))
	if clip_name.is_empty() or not actor.model_animation_player.has_animation(clip_name):
		return false
	var clip := actor.model_animation_player.get_animation(clip_name)
	if clip == null:
		return false
	# The battle actor and preview can share the same cached Animation resource.
	var preview_clip_copy := clip.duplicate() as Animation
	preview_clip_copy.loop_mode = Animation.LOOP_LINEAR
	clear_clip_preview()
	var preview := AnimationLibrary.new()
	preview.add_animation(&"Skill", preview_clip_copy)
	actor.model_animation_player.add_animation_library(&"shop_preview", preview)
	actor.model_animation_player.play(&"shop_preview/Skill", 0.12)
	return true


func clear_clip_preview() -> void:
	if actor == null or not is_instance_valid(actor.model_animation_player):
		return
	var player := actor.model_animation_player
	player.stop()
	if player.has_animation_library(&"shop_preview"):
		player.remove_animation_library(&"shop_preview")
	var idle := StringName(actor.model_clips.get("Idle", &""))
	if player.has_animation(idle):
		player.play(idle)
