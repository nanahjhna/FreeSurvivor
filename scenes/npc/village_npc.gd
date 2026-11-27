extends CharacterBody3D

@export var npc_name: String = "주민"
@export var npc_role: String = "마을 주민"
@export var is_patrolling: bool = false
@export var patrol_radius: float = 6.0
@export var outfit_color: Color = Color(0.2, 0.5, 0.4)
@export var hair_color: Color = Color(0.3, 0.2, 0.1)
@export var model_scene: PackedScene
@export var model_scale: Vector3 = Vector3.ONE
@export var model_ground_offset: float = 0.0
@export var overhead_offset: float = 0.0
@export_file("*.glb", "*.gltf") var idle_animation_source: String = "res://assets/rig/exported-model.glb"
@export var idle_source_clip: StringName = &"Standing_Idle"
@export var idle_animation: StringName = &"mixamo_com"

var spawn_pos: Vector3
var target_pos: Vector3
var wait_timer: float = 0.0
var move_speed: float = 2.0
var walk_cycle: float = 0.0

@onready var visual_root: Node3D = $VisualRoot
@onready var arm_l: Node3D = $VisualRoot.get_node_or_null("ArmL")
@onready var arm_r: Node3D = $VisualRoot.get_node_or_null("ArmR")
@onready var leg_l: Node3D = $VisualRoot.get_node_or_null("LegL")
@onready var leg_r: Node3D = $VisualRoot.get_node_or_null("LegR")
@onready var name_label: Label3D = $NameLabel3D
@onready var interaction_bubble: Label3D = $InteractionBubble
@onready var attention_mark: Label3D = $AttentionMark
var model_instance: Node3D
var model_animation_player: AnimationPlayer
var _idle_animation_name: StringName = &""
var _bubble_base_y := 0.0
var _bubble_time := 0.0
var _interaction_highlighted := false

func _ready():
	add_to_group("npcs")
	collision_layer = 32 # Layer 6: Environment / Static
	collision_mask = 33  # Layer 1: Player, Layer 6: Environment
	spawn_pos = global_position
	target_pos = spawn_pos
	_setup_model()
	
	if name_label:
		name_label.text = npc_name + "\n[" + npc_role + "]"
		name_label.position.y += overhead_offset
	if interaction_bubble:
		_bubble_base_y = interaction_bubble.position.y + overhead_offset
		interaction_bubble.position.y = _bubble_base_y
	if attention_mark:
		attention_mark.visible = false
		attention_mark.text = "!"
		attention_mark.font_size = 64
		attention_mark.modulate = Color("#f05b46")
		attention_mark.outline_size = 14
		attention_mark.outline_modulate = Color("#3b1713")
		attention_mark.position.y += overhead_offset
	
	# Apply custom color if body mesh exists
	var body = $VisualRoot.get_node_or_null("Body")
	if model_instance == null and body and body is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = outfit_color
		body.material_override = mat

func _setup_model() -> void:
	if model_scene == null:
		return
	model_instance = model_scene.instantiate() as Node3D
	if model_instance == null:
		push_warning("NPC 모델 루트가 Node3D가 아닙니다: %s" % model_scene.resource_path)
		return
	model_instance.name = "CharacterModel"
	model_instance.scale = model_scale
	model_instance.position.y += model_ground_offset
	for child in visual_root.get_children():
		child.visible = false
	visual_root.add_child(model_instance)
	for node in model_instance.find_children("*", "AnimationPlayer", true, false):
		model_animation_player = node as AnimationPlayer
		if model_animation_player != null:
			break
	if model_animation_player == null:
		return
	var animation_source := preload("res://scripts/character_animation_source.gd")
	if not idle_animation_source.is_empty() and not idle_source_clip.is_empty() and animation_source.apply_source_clip(model_instance, model_animation_player, idle_animation_source, idle_source_clip):
		_idle_animation_name = &"npc_source/Idle"
	else:
		_idle_animation_name = _resolve_animation_name(model_animation_player, idle_animation)
	if not _idle_animation_name.is_empty():
		model_animation_player.play(_idle_animation_name)

func _resolve_animation_name(player: AnimationPlayer, requested: StringName) -> StringName:
	if not requested.is_empty() and player.has_animation(requested):
		return requested
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			var qualified := StringName("%s/%s" % [str(library_name), str(animation_name)])
			if requested.is_empty() or animation_name == requested or qualified == requested:
				return qualified
	return &""

func _keep_idle_animation_playing() -> void:
	if model_animation_player == null or _idle_animation_name.is_empty():
		return
	if not model_animation_player.is_playing():
		model_animation_player.play(_idle_animation_name)

func _physics_process(delta: float):
	_bubble_time += delta
	if interaction_bubble:
		interaction_bubble.position.y = _bubble_base_y + sin(_bubble_time * 2.2) * 0.06
		var target_scale := Vector3.ONE * (1.16 if _interaction_highlighted else 1.0)
		interaction_bubble.scale = interaction_bubble.scale.lerp(target_scale, minf(1.0, delta * 8.0))
	if not is_patrolling:
		_keep_idle_animation_playing()
		return

	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	
	# Patrol logic
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		_keep_idle_animation_playing()
		_reset_limbs(delta)
	else:
		var to_target = target_pos - global_position
		to_target.y = 0.0
		if to_target.length() < 0.6:
			wait_timer = randf_range(3.0, 6.0)
			_pick_new_patrol_target()
		else:
			var dir = to_target.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			
			var target_angle = atan2(dir.x, dir.z)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, 6.0 * delta)
			
			# Walk animation
			walk_cycle += delta * 7.0
			var swing = sin(walk_cycle) * 0.5
			if arm_l: arm_l.rotation.x = swing
			if arm_r: arm_r.rotation.x = -swing
			if leg_l: leg_l.rotation.x = -swing
			if leg_r: leg_r.rotation.x = swing
	
	move_and_slide()

func set_interaction_highlight(highlighted: bool):
	_interaction_highlighted = highlighted
	if interaction_bubble:
		interaction_bubble.modulate = Color(1.0, 0.86, 0.3, 1.0) if highlighted else Color(0.82, 0.92, 1.0, 0.95)
		interaction_bubble.text = "💬  지금 대화하기!\n[E / 터치]" if highlighted else "💬  대화하기\n[E / 터치]"

func set_attention_visible(attention_visible: bool) -> void:
	if attention_mark:
		attention_mark.visible = attention_visible

func _pick_new_patrol_target():
	var angle = randf() * TAU
	var dist = randf_range(2.0, patrol_radius)
	target_pos = spawn_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

func _reset_limbs(delta: float):
	if arm_l: arm_l.rotation.x = lerp_angle(arm_l.rotation.x, 0.0, 8.0 * delta)
	if arm_r: arm_r.rotation.x = lerp_angle(arm_r.rotation.x, 0.0, 8.0 * delta)
	if leg_l: leg_l.rotation.x = lerp_angle(leg_l.rotation.x, 0.0, 8.0 * delta)
	if leg_r: leg_r.rotation.x = lerp_angle(leg_r.rotation.x, 0.0, 8.0 * delta)
