class_name PlayerCharacter
extends CharacterBody3D

signal hp_changed(current_hp, max_hp)
signal exp_changed(current_xp, xp_to_next)
signal leveled_up(new_level)
signal died()

@export var is_combat_enabled: bool = true
var preview_only: bool = false
@export var max_hp: float = 100.0
var current_hp: float = 100.0

@export var base_move_speed: float = 6.8
@export var base_attack_damage: float = 15.0
@export var base_attack_speed: float = 1.2
@export var attack_range: float = 3.8
@export_range(1.0, 3.0, 0.1) var character_visual_scale: float = 1.5
@export_range(0.0, 1.0, 0.05) var ranged_attack_move_multiplier: float = 0.5

var current_xp: int = 0
var xp_to_next_level: int = 10
var level: int = 1

var is_dead: bool = false
var auto_attack_timer: float = 0.0
var auto_attack_enabled: bool = false
var touch_move_vector: Vector2 = Vector2.ZERO
var current_move_input: Vector2 = Vector2.ZERO
var _moving_by_input: bool = false
var _auto_move_direction := Vector3.ZERO
var _standing_attack_direction := Vector3.ZERO
var _ranged_aim_direction := Vector3.ZERO
var _ranged_aim_target: Node3D
var _ranged_aim_hold := 0.0
var _pending_ranged_shots: Array[Callable] = []
var manual_attack_cooldown: float = 0.0
var _hp_regen_timer: float = 0.0
var _time_since_last_damage: float = 0.0
var card_hit_bonuses: Dictionary = {}
var survival_shield: float = 0.0
var survival_shield_timer: float = 0.0
var last_stand_used: bool = false
var revive_used: bool = false

# References
@onready var visual_root: Node3D = $VisualRoot
@onready var character_model_root: Node3D = $VisualRoot/CharacterModelRoot
@onready var slash_effect: Node3D = $VisualRoot/SlashEffect
const PlayerCamera = preload("res://scenes/player/player_camera.gd")
const MovingAttackLegs = preload("res://scenes/player/moving_attack_legs.gd")
@onready var camera_node: PlayerCamera = $CameraPivot/SpringArm3D/Camera3D
var _head_hp_fill: MeshInstance3D
var _head_hp_background: MeshInstance3D
var _head_hp_fill_material: StandardMaterial3D
var _head_hp_bar_enabled: bool = true
const HEAD_HP_BAR_WIDTH: float = 0.775

var model_animation_player: AnimationPlayer
var model_clips: Dictionary = {}
var character_model: Node3D
var current_appearance := "fighter"
var first_person_mode: bool = false
var active_action_clip := ""
const DEFAULT_BASIC_ATTACK_ANIMATION_KEYS := ["Attack", "AttackAlt"]
var _basic_attack_animation_keys := PackedStringArray(DEFAULT_BASIC_ATTACK_ANIMATION_KEYS)
var _basic_attack_index := 0
var _skill_animation_busy := false
var _skill_animation_sequence := PackedStringArray()
var _skill_animation_sequence_index: int = -1
var _skill_clip_start_time := 0.0
var _skill_clip_duration := 0.0
var _skill_impact_times := PackedFloat32Array()
var _next_skill_impact := 0
var _skill_impact_callback := Callable()
var _skill_playback_rate := 1.0
var _skill_facing_direction := Vector3.ZERO
var _skill_gait_phase := 0.0
var _hit_flash_tween: Tween
var _ranged_attack_busy: bool = false
var _attack_animation_recovery_remaining: float = 0.0
@export_range(0.0, 0.6, 0.01) var rifle_attack_recovery_time: float = 0.18
var equipped_weapon_animation_player: AnimationPlayer
var _weapon_fire_animation_busy: bool = false
var _character_attack_animation_finished: bool = false
const WEAPON_IDLE_ANIMATION := "akidle"
const WEAPON_FIRE_ANIMATION := ""
const LOCOMOTION_BLEND_TIME := 0.22
const ATTACK_BLEND_TIME := 0.14
const SKILL_BLEND_TIME := 0.08
const ACTION_RETURN_BLEND_TIME := 0.18
const HIT_BLEND_TIME := 0.05
const DEATH_BLEND_TIME := 0.10
const SKILL_TURN_SPEED := TAU * 2.5
const HIT_REACTION_TIME := 0.28
const RANGED_ACTIONS := ["Attack", "AttackAlt", "AttackBase", "Cast", "Kick"]
const RANGED_AIM_TURN_SPEED := 17.0
var _has_ranged_weapon := false
var _gait := "Idle"
var _gait_rate := 1.0
var _last_requested_gait := ""
var _walk_reference_speed := 2.7
var _run_reference_speed := 6.8
var _attack_legs: MovingAttackLegs

var damage_number_scene: PackedScene = preload("res://scenes/effects/damage_number.tscn")
const RIFLE_PROJECTILE_SCENE: PackedScene = preload("res://scenes/skills/rifle_projectile.tscn")
var stat_manager: StatManager = StatManager.new()

func _ready():
	if preview_only:
		return
	add_to_group("player")
	set_character_appearance(GameData.get_leader_id())
	first_person_mode = false
	if character_model:
		character_model.visible = true
		# 임시 비활성화: 영웅 머리 위 HP바는 전투 화면 확인 후 다시 활성화합니다.
		# _create_head_hp_bar()
		# hp_changed.connect(_update_head_hp_bar)
	refresh_persistent_stats()
	collision_layer = 1 # Layer 1: Player
	collision_mask = 35 # Layer 1: Player, Layer 2: Enemies, Layer 6: Environment
	
	# Load persistent stats from GameData
	level = GameData.player_level
	current_xp = GameData.player_current_xp
	xp_to_next_level = GameData.player_xp_to_next
	current_hp = max_hp
	GameData.player_current_hp = current_hp
	
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("exp_changed", current_xp, xp_to_next_level)
	if slash_effect:
		slash_effect.visible = false

func _physics_process(delta: float):
	if is_dead:
		return
	if _attack_animation_recovery_remaining > 0.0:
		_attack_animation_recovery_remaining = maxf(0.0, _attack_animation_recovery_remaining - delta)
		if _attack_animation_recovery_remaining <= 0.0:
			_ranged_attack_busy = false
	
	if manual_attack_cooldown > 0.0:
		manual_attack_cooldown = max(0.0, manual_attack_cooldown - delta)
	
	_handle_movement(delta)
	if _skill_animation_busy and is_instance_valid(model_animation_player):
		_dispatch_skill_impacts(model_animation_player.current_animation_position)
	_release_aimed_shots()
	_update_hp_regeneration(delta)
	_update_survival_shield(delta)
	
	# 전투 피해는 액티브 스킬을 통해서만 발생합니다. 기존 기본공격 자동 경로는 비활성화합니다.

func set_touch_move(value: Vector2):
	touch_move_vector = value.limit_length(1.0)

func set_auto_move_direction(direction: Vector3) -> void:
	_auto_move_direction = direction.limit_length(1.0)

func has_camera_move_input() -> bool:
	return _moving_by_input

func get_facing_direction() -> Vector3:
	var forward := visual_root.global_basis.z.slide(Vector3.UP)
	return forward.normalized() if not forward.is_zero_approx() else Vector3.BACK

func queue_ranged_shot(direction: Vector3, target: Node3D, release: Callable) -> bool:
	if is_dead or not is_combat_enabled:
		return false
	var aim := direction.slide(Vector3.UP).normalized()
	if aim.is_zero_approx():
		aim = get_facing_direction()
	if not _pending_ranged_shots.is_empty():
		if _ranged_aim_target != target or _ranged_aim_direction.dot(aim) < 0.99:
			return false
	else:
		_ranged_aim_direction = aim
		_ranged_aim_target = target
	_pending_ranged_shots.append(release)
	return true

func _release_aimed_shots() -> void:
	if _pending_ranged_shots.is_empty() or get_facing_direction().dot(_ranged_aim_direction) < 0.9999:
		return
	var shots := _pending_ranged_shots
	var direction := _ranged_aim_direction
	var target := _ranged_aim_target
	_pending_ranged_shots = []
	_ranged_aim_target = null
	_ranged_aim_hold = 0.16
	for release in shots:
		if release.is_valid():
			release.call(direction, target if is_instance_valid(target) else null)

func _handle_movement(delta: float):
	# Mobile joystick and PC arrow keys share the same camera-relative movement path.
	var input_vec: Vector2 = touch_move_vector
	if input_vec == Vector2.ZERO:
		input_vec = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# In character-follow view the camera must finish turning before a new
	# direction is accepted. This prevents the screen-relative left/right axis
	# from flipping while the camera is still catching up.
	if camera_node and camera_node.has_method("is_movement_input_locked") and camera_node.is_movement_input_locked():
		input_vec = Vector2.ZERO
	current_move_input = input_vec
	var move_direction := _auto_move_direction
	if input_vec != Vector2.ZERO:
		var right := camera_node.get_movement_right() if camera_node else Vector3.RIGHT
		var down := Vector3(-right.z, 0.0, right.x)
		move_direction = right * input_vec.x + down * input_vec.y
	_moving_by_input = move_direction.length_squared() > 0.0001
	var effective_speed: float = base_move_speed * GameData.move_speed_mult * (1.0 + GameData.get_survival_bonus("move_speed"))
	if Input.is_key_pressed(KEY_SHIFT) and _moving_by_input:
		effective_speed *= 1.45
	if _ranged_attack_busy:
		effective_speed *= ranged_attack_move_multiplier

	# Gravity
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	
	# Smooth acceleration and deceleration
	var target_velocity := move_direction * effective_speed
	var acceleration_weight: float = 1.0 - exp(-14.0 * delta)
	velocity.x = lerpf(velocity.x, target_velocity.x, acceleration_weight)
	velocity.z = lerpf(velocity.z, target_velocity.z, acceleration_weight)
	move_and_slide()

	if _moving_by_input:
		_standing_attack_direction = Vector3.ZERO
	var facing := move_direction if _moving_by_input else _standing_attack_direction
	var aiming := not _pending_ranged_shots.is_empty()
	_ranged_aim_hold = maxf(0.0, _ranged_aim_hold - delta)
	if aiming and is_instance_valid(_ranged_aim_target):
		var to_target := (_ranged_aim_target.global_position - global_position).slide(Vector3.UP)
		if not to_target.is_zero_approx():
			_ranged_aim_direction = to_target.normalized()
	if _ranged_aim_direction != Vector3.ZERO and (aiming or _ranged_attack_busy or _ranged_aim_hold > 0.0):
		facing = _ranged_aim_direction
	elif _skill_animation_busy and _skill_facing_direction != Vector3.ZERO:
		facing = _skill_facing_direction
	if facing.length_squared() > 0.0001:
		var local_facing := global_basis.transposed() * facing
		var heading := atan2(local_facing.x, local_facing.z)
		if aiming:
			visual_root.rotation.y = rotate_toward(visual_root.rotation.y, heading, RANGED_AIM_TURN_SPEED * delta)
		elif _skill_animation_busy and _skill_facing_direction != Vector3.ZERO:
			visual_root.rotation.y = rotate_toward(visual_root.rotation.y, heading, SKILL_TURN_SPEED * delta)
		else:
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, heading, 1.0 - exp(-9.0 * delta))
	visual_root.rotation.z = lerpf(visual_root.rotation.z, -input_vec.x * 0.075, 1.0 - exp(-10.0 * delta))

	# Actual post-collision movement, so the gait also slows when walking into walls.
	var actual_velocity := get_real_velocity()
	_animate_character(delta, Vector2(actual_velocity.x, actual_velocity.z).length())

func _animate_character(delta: float, horizontal_speed: float) -> void:
	if not is_instance_valid(model_animation_player):
		return
	var was_moving := _gait != "Idle"
	var motion_threshold := 0.16 if was_moving else 0.28
	if horizontal_speed < motion_threshold:
		_gait = "Idle"
	else:
		var run_threshold := _run_reference_speed * (0.46 if _gait == "Run" else 0.56)
		_gait = "Run" if horizontal_speed >= run_threshold and model_clips.has("Run") else "Walk"
		if not model_clips.has(_gait):
			_gait = "Run" if model_clips.has("Run") else "Idle"
	var clip: StringName = model_clips.get(_gait, &"")
	var gait_reference := _walk_reference_speed if _gait == "Walk" else _run_reference_speed
	var target_rate := 1.0 if _gait == "Idle" else clampf(horizontal_speed / gait_reference, 0.25, 1.85)
	_gait_rate = lerpf(_gait_rate, target_rate, 1.0 - exp(-14.0 * delta))
	if _gait == "Idle":
		_skill_gait_phase = 0.0
	var in_action := not active_action_clip.is_empty()
	var moving_attack := _ranged_attack_busy and in_action and _gait != "Idle"
	if is_instance_valid(_attack_legs) and (moving_attack or _attack_legs.active):
		_attack_legs.update_motion(delta, clip, _gait_rate, moving_attack)
	if in_action:
		return
	var playback_rate := _gait_rate if _gait != "Idle" else 1.0
	if not is_equal_approx(model_animation_player.speed_scale, playback_rate):
		model_animation_player.speed_scale = playback_rate
	var desired_clip := str(model_clips.get(_gait, ""))
	if _last_requested_gait != _gait or str(model_animation_player.current_animation) != desired_clip or not model_animation_player.is_playing():
		_last_requested_gait = _gait
		_play_model_animation(_gait)


func set_character_appearance(character_id: String):
	var definition := PlayerManager.get_definition(character_id)
	if definition.is_empty():
		push_warning("등록되지 않은 플레이어 ID입니다: %s" % character_id)
		return
	current_appearance = character_id
	var character_data := CharacterRegistry.get_by_id(character_id)
	_has_ranged_weapon = character_data.attack_style == "ranged" if character_data != null else character_id == "archer"
	if is_instance_valid(model_animation_player) and model_animation_player.animation_finished.is_connected(_on_model_animation_finished):
		model_animation_player.animation_finished.disconnect(_on_model_animation_finished)
	_clear_skill_animation()
	model_animation_player = null
	model_clips.clear()
	active_action_clip = ""
	_basic_attack_animation_keys = PackedStringArray(DEFAULT_BASIC_ATTACK_ANIMATION_KEYS)
	if character_data != null and not character_data.basic_attack_animation_keys.is_empty():
		_basic_attack_animation_keys = character_data.basic_attack_animation_keys
	_basic_attack_index = 0
	_skill_gait_phase = 0.0
	_ranged_attack_busy = false
	_gait = "Idle"
	_gait_rate = 1.0
	_last_requested_gait = ""
	_attack_legs = null
	_standing_attack_direction = Vector3.ZERO
	_pending_ranged_shots.clear()
	_ranged_aim_target = null
	_ranged_aim_direction = Vector3.ZERO
	_ranged_aim_hold = 0.0
	_attack_animation_recovery_remaining = 0.0
	if is_instance_valid(equipped_weapon_animation_player) and equipped_weapon_animation_player.animation_finished.is_connected(_on_equipped_weapon_animation_finished):
		equipped_weapon_animation_player.animation_finished.disconnect(_on_equipped_weapon_animation_finished)
	equipped_weapon_animation_player = null
	_weapon_fire_animation_busy = false
	_character_attack_animation_finished = false
	character_model = null
	for child in character_model_root.get_children():
		character_model_root.remove_child(child)
		child.queue_free()
	character_model = PlayerManager.create_model(character_id, character_model_root)
	if character_model:
		# Match the player silhouette to the enlarged standard monsters while
		# keeping movement and combat collision sizes unchanged.
		character_model.scale *= Vector3.ONE * character_visual_scale
		character_model.visible = not first_person_mode
		_setup_model_animations()
		if is_combat_enabled or preview_only:
			_attach_character_weapon(character_id)
		_setup_gait(character_data, float(definition.get("base_spd", base_move_speed)))

func _setup_gait(data: CharacterData, class_speed: float) -> void:
	_walk_reference_speed = maxf(0.1, class_speed * 0.42)
	_run_reference_speed = maxf(0.1, class_speed)
	if data == null:
		return
	var model_scale := absf(character_model.scale.y)
	if data.walk_animation_speed > 0.0:
		_walk_reference_speed = maxf(0.1, data.walk_animation_speed * model_scale)
	if data.run_animation_speed > 0.0:
		_run_reference_speed = maxf(0.1, data.run_animation_speed * model_scale)
	if model_clips.get("Walk", "") == model_clips.get("Run", ""):
		_walk_reference_speed = _run_reference_speed
	if not _has_ranged_weapon or preview_only or data.moving_attack_leg_roots.is_empty() or model_animation_player == null:
		return
	var walk_clip: StringName = model_clips.get("Walk", &"")
	var run_clip: StringName = model_clips.get("Run", &"")
	for node in character_model.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		if skeleton.find_bone(data.moving_attack_leg_roots[0]) < 0:
			continue
		var layer := MovingAttackLegs.new()
		if layer.configure(skeleton, model_animation_player, data.moving_attack_leg_roots, walk_clip, run_clip):
			skeleton.add_child(layer)
			_attack_legs = layer
			return
		layer.free()


func _attach_character_weapon(character_id: String) -> void:
	if character_model == null:
		return
	var character_data := CharacterRegistry.get_by_id(character_id)
	if character_data == null or character_data.weapon_scene == null:
		return
	var weapon_scene := character_data.weapon_scene
	var weapon_bone_name := character_data.weapon_bone_name
	var skeleton_nodes := character_model.find_children("*", "Skeleton3D", true, false)
	var skeleton: Skeleton3D = null
	var resolved_bone_index := -1
	for skeleton_node in skeleton_nodes:
		if not is_instance_valid(skeleton_node):
			continue
		var candidate := skeleton_node as Skeleton3D
		if candidate == null:
			continue
		var bone_index := candidate.find_bone(weapon_bone_name)
		if bone_index < 0:
			for index in range(candidate.get_bone_count()):
				var candidate_bone := candidate.get_bone_name(index).to_lower()
				if candidate_bone.ends_with("_r_hand") or candidate_bone.ends_with("right_hand") or candidate_bone.ends_with("righthand"):
					bone_index = index
					break
		if bone_index >= 0:
			skeleton = candidate
			resolved_bone_index = bone_index
			break

	var weapon_node := weapon_scene.instantiate()
	var weapon := weapon_node as Node3D
	if weapon == null:
		weapon_node.queue_free()
		push_warning("캐릭터 무기 씬의 루트가 Node3D가 아닙니다: %s" % weapon_scene.resource_path)
		return

	var attachment_parent: Node3D
	var inherited_bone_scale := Vector3.ONE
	var model_units_per_rig_unit := 1.0
	if skeleton != null:
		if preview_only:
			skeleton.process_mode = Node.PROCESS_MODE_ALWAYS
		# Use model space so the weapon follows the actor's display scale,
		# without inheriting the rig's unit conversion (0.01 on char01).
		var skeleton_to_model := character_model.global_transform.affine_inverse() * skeleton.global_transform
		model_units_per_rig_unit = absf(skeleton_to_model.basis.get_scale().x)
		var hand_rest := skeleton_to_model * skeleton.get_bone_global_rest(resolved_bone_index)
		inherited_bone_scale = hand_rest.basis.get_scale().abs()
		var attachment := BoneAttachment3D.new()
		attachment.name = "CharacterWeaponAttachment"
		attachment.bone_name = skeleton.get_bone_name(resolved_bone_index)
		skeleton.add_child(attachment)
		attachment_parent = attachment
	else:
		push_warning("손 뼈를 찾지 못해 캐릭터 손 위치에 무기를 고정합니다: %s (%s)" % [character_id, weapon_bone_name])
		var fallback_mount := Node3D.new()
		fallback_mount.name = "CharacterWeaponFallbackMount"
		fallback_mount.position = Vector3(0.36, 1.08, -0.04)
		character_model.add_child(fallback_mount)
		attachment_parent = fallback_mount
	weapon.name = "EquippedWeapon"
	attachment_parent.add_child(weapon)
	weapon.visible = true
	for hidden_node_name in character_data.weapon_hidden_nodes:
		var unwanted_mesh := weapon.find_child(hidden_node_name, true, false) as VisualInstance3D
		if unwanted_mesh != null:
			unwanted_mesh.visible = false

	var grip_local_position := character_data.weapon_grip_position
	var grip_point := weapon.find_child("GripPoint", true, false) as Node3D
	if grip_point != null:
		grip_local_position = weapon.to_local(grip_point.global_position)
	var inverse_bone_scale := Vector3.ONE / inherited_bone_scale.maxf(0.0001)
	var rotation_basis := Basis.from_euler(character_data.weapon_mount_rotation_degrees * PI / 180.0)
	var mount_basis := Basis.from_scale(inverse_bone_scale) * rotation_basis * Basis.from_scale(character_data.weapon_mount_scale)
	var palm_position := character_data.weapon_mount_position * inverse_bone_scale
	weapon.transform = Transform3D(mount_basis, palm_position - mount_basis * grip_local_position)
	if skeleton != null and not character_data.weapon_support_bone_name.is_empty():
		var support := preload("res://scenes/player/weapon_support_hand.gd").new()
		if support.configure(skeleton, resolved_bone_index, weapon, model_animation_player, character_data, model_units_per_rig_unit):
			skeleton.add_child(support)
		else:
			support.free()

	var weapon_animation_nodes := weapon.find_children("*", "AnimationPlayer", true, false)
	for animation_node in weapon_animation_nodes:
		if not is_instance_valid(animation_node):
			continue
		var weapon_player := animation_node as AnimationPlayer
		if weapon_player != null and weapon_player.has_animation(WEAPON_IDLE_ANIMATION):
			equipped_weapon_animation_player = weapon_player
			if preview_only:
				weapon_player.process_mode = Node.PROCESS_MODE_ALWAYS
			var idle_animation := weapon_player.get_animation(WEAPON_IDLE_ANIMATION)
			if idle_animation != null:
				idle_animation.loop_mode = Animation.LOOP_LINEAR
			weapon_player.play(WEAPON_IDLE_ANIMATION, 0.12)
			break


func set_first_person_mode(enabled: bool) -> void:
	first_person_mode = enabled
	if character_model:
		# Keep the registered character model rendered in the village so the
		# camera can catch the forearms and equipped weapon at the bottom of the
		# view. Combat explicitly restores the regular third-person presentation.
		character_model.visible = true
	_update_head_hp_bar(current_hp, max_hp)

func set_head_hp_bar_visible(enabled: bool) -> void:
	_head_hp_bar_enabled = enabled
	_update_head_hp_bar(current_hp, max_hp)

func _create_head_hp_bar() -> void:
	var bar_root := Node3D.new()
	bar_root.name = "HeadHPBar"
	bar_root.position = Vector3(0.0, 2.85, 0.0)
	add_child(bar_root)
	_head_hp_background = _make_head_hp_mesh(Color(0.055, 0.025, 0.03, 0.9))
	bar_root.add_child(_head_hp_background)
	_head_hp_fill = _make_head_hp_mesh(Color(0.9, 0.12, 0.12, 1.0))
	bar_root.add_child(_head_hp_fill)
	_head_hp_fill.position.z = 0.01
	_head_hp_fill_material = _head_hp_fill.material_override as StandardMaterial3D

func _make_head_hp_mesh(color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(HEAD_HP_BAR_WIDTH, 0.08)
	mesh_instance.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color
	material.no_depth_test = true
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance

func _update_head_hp_bar(current: float, maximum: float) -> void:
	if _head_hp_fill == null or _head_hp_background == null:
		return
	var ratio := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	var gauge := _head_hp_fill.mesh as QuadMesh
	var width := HEAD_HP_BAR_WIDTH * ratio
	gauge.size.x = maxf(0.001, width)
	gauge.center_offset.x = (width - HEAD_HP_BAR_WIDTH) * 0.5
	if _head_hp_fill_material != null:
		if ratio <= 0.3:
			_head_hp_fill_material.albedo_color = Color(0.9, 0.12, 0.12, 1.0)
		elif ratio <= 0.6:
			_head_hp_fill_material.albedo_color = Color(0.95, 0.8, 0.1, 1.0)
		else:
			_head_hp_fill_material.albedo_color = Color(0.15, 0.85, 0.25, 1.0)
	_head_hp_background.visible = _head_hp_bar_enabled and not first_person_mode
	_head_hp_fill.visible = _head_hp_bar_enabled and ratio > 0.0 and not first_person_mode

func set_character_2d_mode(enabled: bool):
	set_character_appearance("fighter_2d" if enabled else "fighter")

func _handle_auto_attack(delta: float):
	if not auto_attack_enabled or _ranged_attack_busy:
		if _ranged_attack_busy:
			auto_attack_timer = 0.0
		return
	if _skill_animation_busy or not active_action_clip.is_empty():
		return
	var skill_manager := get_node_or_null("SkillManager")
	if skill_manager and skill_manager.has_method("should_use_basic_attack") and not skill_manager.call("should_use_basic_attack"):
		return
	if not _pending_ranged_shots.is_empty():
		return
	var speed_multiplier := clampf(GameData.attack_speed_mult * (1.0 + GameData.get_survival_bonus("attack_speed") + GameData.get_survival_bonus("kill_attack_speed")), 0.5, 2.5)
	var effective_aspd = base_attack_speed * speed_multiplier
	auto_attack_timer += delta * effective_aspd
	
	if auto_attack_timer >= 1.0:
		var target = _find_closest_enemy(attack_range * (1.0 + GameData.get_survival_bonus("attack_range")))
		if target and _perform_auto_attack(target):
			auto_attack_timer = 0.0

func try_manual_attack() -> bool:
	# 기본공격은 제거되었으며 모든 공격은 스킬 슬롯으로 사용합니다.
	return false

func set_auto_attack(enabled: bool):
	# 저장 데이터와 기존 호출 호환용입니다. 기본공격 자동 시전은 항상 비활성화합니다.
	auto_attack_enabled = false

func _find_closest_enemy(max_dist: float) -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest: Node3D = null
	var min_d: float = max_dist
	
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var d = global_position.distance_to(enemy.global_position)
			if d < min_d:
				min_d = d
				closest = enemy
	return closest

func _perform_auto_attack(target: Node3D) -> bool:
	var dir_to_target := (target.global_position - global_position).normalized()
	if _has_ranged_weapon:
		return queue_ranged_shot(dir_to_target, target, _release_basic_attack)
	_release_basic_attack(dir_to_target, target)
	return true

func _release_basic_attack(dir_to_target: Vector3, target: Node3D) -> void:
	if not is_instance_valid(target) or bool(target.get("is_dead")):
		return
	if not _has_ranged_weapon and not _moving_by_input:
		_standing_attack_direction = Vector3(dir_to_target.x, 0.0, dir_to_target.z)
	if not _skill_animation_busy:
		_play_model_animation(_basic_attack_animation_keys[_basic_attack_index], true)
		_basic_attack_index = (_basic_attack_index + 1) % _basic_attack_animation_keys.size()
	# Put the slash and damage on the swing's contact frame instead of the
	# animation's starting frame. This keeps the visual and hit response together.
	await get_tree().create_timer(0.22).timeout
	if is_dead or not is_instance_valid(target) or bool(target.get("is_dead")):
		return
	if _has_ranged_weapon:
		_spawn_ranged_attack_visual(target, dir_to_target)
	else:
		_show_slash_effect()
	if randf() * 100.0 >= stat_manager.hit_rate():
		_show_damage_popup(0, false, false, "MISS")
		return
	var is_critical := randf() * 100.0 < minf(80.0, stat_manager.crit_rate() + GameData.get_survival_bonus("crit_chance") * 100.0)
	var dmg = base_attack_damage * GameData.attack_damage_mult * (1.0 + GameData.get_survival_bonus("damage") + GameData.get_survival_bonus("damage_reckless") + GameData.get_survival_bonus("physical_damage"))
	var monster_target: BaseMonster = target as BaseMonster
	if monster_target != null and bool(MonsterManager.get_definition(monster_target.monster_id).get("is_boss", false)):
		dmg *= 1.0 + GameData.get_survival_bonus("boss_damage")
	if current_hp <= max_hp * 0.5:
		dmg *= 1.0 + GameData.get_survival_bonus("low_hp_damage")
	if monster_target != null and monster_target.current_hp <= monster_target.max_hp * 0.3:
		dmg *= 1.0 + GameData.get_survival_bonus("execute_damage")
	if is_critical:
		dmg *= 1.5 + GameData.get_survival_bonus("crit_damage")
	if monster_target != null and not card_hit_bonuses.is_empty():
		dmg = _apply_card_hit_effects(monster_target, dmg)
	if target.has_method("take_damage"):
		target.take_damage(dmg, is_critical, "basic")
		if randf() < GameData.get_survival_bonus("extra_attack"):
			target.take_damage(dmg * 0.8, false, "basic")
		if randf() < GameData.get_survival_bonus("lightning_proc"):
			target.take_damage(dmg * 0.5, false, "basic")
		if randf() < GameData.get_survival_bonus("chain_lightning"):
			var bounced := 0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy != target and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= 8.0:
					enemy.take_damage(dmg * 0.5, false, "basic")
					bounced += 1
					if bounced >= 2:
						break


func _spawn_ranged_attack_visual(target: Node3D, direction: Vector3) -> void:
	var effect := RIFLE_PROJECTILE_SCENE.instantiate() as SkillEffectBase
	if effect == null:
		return
	get_tree().current_scene.add_child(effect)
	effect.cast(self, target, direction, 0.0, {
		"visual_color": Color(1.0, 0.58, 0.16, 1.0).to_html(false),
		"projectile_pierce": 1,
		"visual_only": true
	})

func on_monster_killed(_monster: Node):
	GameData.survival_kills += 1
	if GameData.get_survival_bonus("kill_attack_speed_rate") > 0.0:
		var speed_cap := 0.15 if GameData.survival_card_counts.has("015") else 0.20
		GameData.survival_bonuses["kill_attack_speed"] = minf(speed_cap, GameData.get_survival_bonus("kill_attack_speed") + GameData.get_survival_bonus("kill_attack_speed_rate"))
	var heal_amount := max_hp * GameData.get_survival_bonus("kill_heal") if GameData.survival_kills % 15 == 0 else 0.0
	if heal_amount > 0.0:
		heal(heal_amount)
	if GameData.get_survival_bonus("kill_explosion") > 0.0 and randf() < GameData.get_survival_bonus("kill_explosion"):
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= 4.0:
				enemy.take_damage(base_attack_damage, false, "card_effect")

func _apply_card_hit_effects(monster: BaseMonster, damage: float) -> float:
	if monster.current_hp <= monster.max_hp * 0.4:
		damage *= 1.0 + float(card_hit_bonuses.get("finisher", 0.0))
	damage += max_hp * float(card_hit_bonuses.get("shield_bash", 0.0))
	if monster.card_statuses.has("bleed"):
		damage += float(card_hit_bonuses.get("blood_burst", 0.0))
	if monster.card_statuses.has("burn"):
		damage += float(card_hit_bonuses.get("flame_burst", 0.0))
	for status in ["bleed", "burn"]:
		if card_hit_bonuses.has(status):
			monster.apply_card_status(status, float(card_hit_bonuses[status]))
	return damage

func _show_slash_effect():
	if slash_effect:
		slash_effect.visible = true
		slash_effect.scale = Vector3(0.5, 0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(slash_effect, "scale", Vector3(1.3, 1.3, 1.3), 0.15)
		tween.tween_callback(func(): slash_effect.visible = false)

func gain_xp(amount: int):
	if is_dead:
		return
	current_xp += amount
	var gained_level = false
	var new_card_picks := 0
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(xp_to_next_level * 1.2) + 2
		gained_level = true
		if level % 5 == 0:
			new_card_picks += 1
	GameData.player_level = level
	GameData.player_current_xp = current_xp
	GameData.player_xp_to_next = xp_to_next_level
	if gained_level:
		emit_signal("leveled_up", level)
	if new_card_picks > 0:
		GameManager.level_card_picks += new_card_picks
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.enter_level_up()
	
	emit_signal("exp_changed", current_xp, xp_to_next_level)

func heal(amount: float):
	if is_dead:
		return
	current_hp = min(current_hp + amount, max_hp)
	GameData.player_current_hp = current_hp
	emit_signal("hp_changed", current_hp, max_hp)
	_show_damage_popup(amount, false, true)

func refresh_persistent_stats():
	var char_id := GameData.get_leader_id()
	var character: Dictionary = GameData.characters.get(char_id, {})
	stat_manager.setup_from_class(char_id, character)
	base_move_speed = stat_manager.base_spd * stat_manager.move_speed_multiplier()
	base_attack_damage = stat_manager.phys_atk()
	# Legacy basic-attack compatibility value; active skills use cast_speed().
	base_attack_speed = 1.2 * stat_manager.cast_speed()
	var old_max_hp := max_hp
	max_hp = GameData.get_max_player_hp(stat_manager)
	if old_max_hp > 0.0:
		current_hp = clampf(current_hp + max_hp - old_max_hp, 0.0, max_hp)
	else:
		current_hp = max_hp
	GameData.player_current_hp = current_hp
	if is_inside_tree():
		emit_signal("hp_changed", current_hp, max_hp)

func _update_hp_regeneration(delta: float):
	if current_hp >= max_hp:
		_hp_regen_timer = 0.0
		return
	_time_since_last_damage += delta
	_hp_regen_timer += delta
	var elapsed := _hp_regen_timer
	if _hp_regen_timer < 1.0:
		elapsed = delta
	else:
		_hp_regen_timer = 0.0
	var healing_rate := stat_manager.hp_recovery_rate() + max_hp * GameData.get_survival_bonus("hp_regen")
	var skill_manager := get_node_or_null("SkillManager")
	if skill_manager != null and skill_manager.has_method("get_passive_regen_amount"):
		healing_rate += float(skill_manager.call("get_passive_regen_amount", elapsed)) / maxf(elapsed, 0.001)
	if _hp_regen_timer == 0.0:
		current_hp = minf(max_hp, current_hp + healing_rate * elapsed)
	else:
		return
	GameData.player_current_hp = current_hp
	emit_signal("hp_changed", current_hp, max_hp)

func _update_survival_shield(delta: float):
	var shield_rate := GameData.get_survival_bonus("shield_regen")
	if shield_rate <= 0.0:
		return
	survival_shield_timer += delta
	if survival_shield_timer >= 30.0:
		survival_shield_timer = 0.0
		survival_shield = minf(max_hp * 0.5, survival_shield + max_hp * shield_rate)

func take_damage(amount: float):
	_apply_incoming_damage(amount, stat_manager.phys_def())

func take_magic_damage(amount: float):
	_apply_incoming_damage(amount, stat_manager.mag_def(), true)

func _apply_incoming_damage(amount: float, defense: float, is_magic: bool = false):
	if is_dead:
		return
	if randf() * 100.0 < stat_manager.perfect_dodge():
		_show_damage_popup(0, false, false, "PERFECT DODGE")
		return
	if randf() * 100.0 < stat_manager.evasion():
		_show_damage_popup(0, false, false, "MISS")
		return
	var reduction := GameData.get_survival_bonus("damage_reduction")
	if is_magic:
		reduction += GameData.get_survival_bonus("magic_reduction")
	if current_hp <= max_hp * 0.3:
		reduction += GameData.get_survival_bonus("low_hp_reduction")
	var reduced_damage := amount * 100.0 / (100.0 + maxf(0.0, defense)) * (1.0 - clampf(reduction, -0.5, 0.75))
	if reduced_damage > 0.0:
		_time_since_last_damage = 0.0
	var absorbed := minf(survival_shield, reduced_damage)
	survival_shield -= absorbed
	reduced_damage -= absorbed
	current_hp = max(0.0, current_hp - reduced_damage)
	if current_hp <= 0.0 and GameData.get_survival_bonus("last_stand") > 0.0 and not last_stand_used:
		last_stand_used = true
		current_hp = max_hp * 0.3
	elif current_hp <= 0.0 and GameData.get_survival_bonus("revive") > 0.0 and not revive_used:
		revive_used = true
		current_hp = max_hp * 0.5
	GameData.player_current_hp = current_hp
	emit_signal("hp_changed", current_hp, max_hp)
	_show_damage_popup(reduced_damage, false, false, "", true)
	if current_hp <= 0.0:
		die()
	elif reduced_damage > 0.0:
		_flash_red()
		_play_model_animation("Hit", true)

func _flash_red():
	if _hit_flash_tween != null and _hit_flash_tween.is_running():
		return
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(visual_root, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
	_hit_flash_tween.tween_property(visual_root, "scale", Vector3.ONE, 0.12)

func _show_damage_popup(amount: float, is_crit: bool = false, is_heal: bool = false, custom_text: String = "", is_incoming: bool = false):
	if damage_number_scene:
		var popup = damage_number_scene.instantiate()
		get_tree().current_scene.add_child(popup)
		popup.global_position = global_position + Vector3(0, 1.8, 0)
		if custom_text != "":
			var lbl = popup.get_node_or_null("Label3D")
			if lbl:
				lbl.text = custom_text
				lbl.modulate = Color(1.0, 0.8, 0.1)
			else:
				popup.setup(amount, is_crit, is_heal)
				if is_incoming:
					var incoming_label := popup.get_node_or_null("Label3D") as Label3D
					if incoming_label:
						incoming_label.modulate = Color(1.0, 0.08, 0.08)

func die():
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	_moving_by_input = false
	_pending_ranged_shots.clear()
	_ranged_aim_target = null
	_clear_skill_animation()
	if _hit_flash_tween != null and _hit_flash_tween.is_running():
		_hit_flash_tween.kill()
		visual_root.scale = Vector3.ONE
	emit_signal("died")
	if not _play_model_animation("Death", true):
		var tween = create_tween()
		tween.tween_property(visual_root, "rotation:x", -PI / 2.0, 0.4)
		tween.tween_callback(GameManager.game_over)


func _setup_model_animations():
	if character_model == null:
		return
	var players := character_model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	model_animation_player = players[0] as AnimationPlayer
	if model_animation_player == null:
		return
	var character_data := CharacterRegistry.get_by_id(current_appearance)
	if character_data != null and not character_data.animation_source_path.is_empty():
		var loader := preload("res://scripts/character_animation_source.gd")
		loader.apply_to(character_model, model_animation_player, character_data)
	if preview_only:
		model_animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	model_clips.clear()
	var configured_aliases := PlayerManager.get_animation_aliases(current_appearance)
	if not configured_aliases.is_empty():
		for alias in configured_aliases:
			_map_animation_alias(str(alias), configured_aliases[alias])
	else:
		_map_animation_alias("Idle", ["Idle"])
		_map_animation_alias("Walk", ["Walk", "Run"])
		_map_animation_alias("Run", ["Run", "Walk"])
		_map_animation_alias("AttackAlt", ["Attack"])
		_map_animation_alias("Death", ["Death"])
	for clip_key in ["Idle", "Walk", "Run"]:
		var unarmed_key: String = "Unarmed" + clip_key
		if not is_combat_enabled and not preview_only and model_clips.has(unarmed_key):
			model_clips[clip_key] = model_clips[unarmed_key]
		if model_clips.has(clip_key):
			var clip := model_animation_player.get_animation(model_clips[clip_key])
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
	var action_keys := ["Attack", "AttackAlt", "AttackBase", "Cast", "Kick", "Hit", "Death"]
	action_keys.append_array(_basic_attack_animation_keys)
	if is_combat_enabled:
		for skill: Dictionary in CharacterSkillDatabase.get_skill_set(current_appearance).values():
			action_keys.append(str(skill.get("animation_key", "")))
			for sequence_key in skill.get("animation_sequence", PackedStringArray()):
				action_keys.append(str(sequence_key))
	var gait_clips := [model_clips.get("Idle"), model_clips.get("Walk"), model_clips.get("Run")]
	for clip_key in action_keys:
		if model_clips.has(clip_key) and model_clips[clip_key] not in gait_clips:
			var action_clip := model_animation_player.get_animation(model_clips[clip_key])
			if action_clip:
				action_clip.loop_mode = Animation.LOOP_NONE
	if not model_animation_player.animation_finished.is_connected(_on_model_animation_finished):
		model_animation_player.animation_finished.connect(_on_model_animation_finished)
	_play_model_animation("Idle")


func _map_animation_alias(alias: String, candidates: Variant):
	var candidate_list: Array = candidates if candidates is Array else [str(candidates)]
	for candidate in candidate_list:
		if model_animation_player != null and model_animation_player.has_animation(candidate):
			model_clips[alias] = candidate
			return


func _on_model_animation_finished(animation_name: StringName):
	if str(animation_name) != active_action_clip:
		return
	if _skill_animation_busy:
		var has_next_clip := _skill_animation_sequence_index + 1 < _skill_animation_sequence.size()
		_dispatch_skill_impacts(_skill_clip_duration, not has_next_clip)
		if has_next_clip:
			_skill_clip_start_time += _skill_clip_duration
			_skill_animation_sequence_index += 1
			if _play_skill_animation_sequence_clip():
				return
		_clear_skill_animation()
	active_action_clip = ""
	if is_dead and str(animation_name) == str(model_clips.get("Death", "")):
		GameManager.game_over()
		return
	if _ranged_attack_busy:
		_character_attack_animation_finished = true
		if not _weapon_fire_animation_busy:
			_begin_attack_animation_recovery()


func _on_equipped_weapon_animation_finished(animation_name: StringName) -> void:
	if str(animation_name) != WEAPON_FIRE_ANIMATION:
		return
	_weapon_fire_animation_busy = false
	if _character_attack_animation_finished and _ranged_attack_busy:
		_begin_attack_animation_recovery()


func _begin_attack_animation_recovery() -> void:
	if equipped_weapon_animation_player != null and equipped_weapon_animation_player.has_animation(WEAPON_IDLE_ANIMATION):
		equipped_weapon_animation_player.play(WEAPON_IDLE_ANIMATION, 0.14)
	_attack_animation_recovery_remaining = rifle_attack_recovery_time
	if _attack_animation_recovery_remaining <= 0.0:
		_ranged_attack_busy = false


func _play_model_animation(clip_key: String, action: bool = false, animation_duration: float = 0.0) -> bool:
	if is_dead and clip_key != "Death":
		return false
	if model_animation_player == null or not model_clips.has(clip_key):
		return false
	var clip_name := str(model_clips[clip_key])
	if action:
		if clip_key == "Hit" and (not active_action_clip.is_empty() or _ranged_attack_busy):
			return false
		var firing := not is_dead and _has_ranged_weapon and clip_key in RANGED_ACTIONS
		if is_instance_valid(_attack_legs):
			if firing:
				_attack_legs.sync_phase(model_animation_player.current_animation, model_animation_player.current_animation_position)
			elif clip_key == "Death":
				_attack_legs.active = false
				_attack_legs.influence = 0.0
		active_action_clip = clip_name
		_ranged_attack_busy = firing
		_attack_animation_recovery_remaining = 0.0
		if _ranged_attack_busy:
			_character_attack_animation_finished = false
			_weapon_fire_animation_busy = _play_equipped_weapon_fire_animation()
		model_animation_player.speed_scale = _skill_playback_rate if _skill_animation_busy else 1.0
		var clip := model_animation_player.get_animation(clip_name)
		var blend_time := SKILL_BLEND_TIME if _skill_animation_busy else ATTACK_BLEND_TIME
		if clip_key == "Hit":
			blend_time = HIT_BLEND_TIME
		elif clip_key == "Death":
			blend_time = DEATH_BLEND_TIME
		if clip_key == "Hit" and clip.length > HIT_REACTION_TIME:
			model_animation_player.play_section(clip_name, 0.0, HIT_REACTION_TIME, blend_time)
		elif animation_duration > 0.0 and animation_duration < clip.length:
			model_animation_player.play_section(clip_name, 0.0, animation_duration, blend_time)
		else:
			model_animation_player.play(clip_name, blend_time)
		return true
	if not active_action_clip.is_empty() and model_animation_player.is_playing():
		return true
	if str(model_animation_player.current_animation) != clip_name or not model_animation_player.is_playing():
		var phase := 0.0
		var previous := model_animation_player.assigned_animation
		var returning_from_action := not previous.is_empty() and previous not in [model_clips.get("Idle", ""), model_clips.get("Walk", ""), model_clips.get("Run", "")]
		if clip_key != "Idle":
			if previous == model_clips.get("Walk", "") or previous == model_clips.get("Run", ""):
				if model_animation_player.is_playing() and model_animation_player.current_animation_length > 0.0:
					phase = model_animation_player.current_animation_position / model_animation_player.current_animation_length
			elif is_instance_valid(_attack_legs) and _attack_legs.active:
				phase = _attack_legs.gait_phase()
			elif returning_from_action:
				phase = _skill_gait_phase
		_skill_gait_phase = 0.0
		model_animation_player.play(clip_name, ACTION_RETURN_BLEND_TIME if returning_from_action else LOCOMOTION_BLEND_TIME)
		if phase > 0.0:
			model_animation_player.seek(fposmod(phase, 1.0) * model_animation_player.get_animation(clip_name).length)
	return true


func _play_equipped_weapon_fire_animation() -> bool:
	if not is_instance_valid(equipped_weapon_animation_player):
		return false
	if WEAPON_FIRE_ANIMATION.is_empty():
		return false
	if not equipped_weapon_animation_player.has_animation(WEAPON_FIRE_ANIMATION):
		return false
	equipped_weapon_animation_player.play(WEAPON_FIRE_ANIMATION, 0.06)
	return true


func is_skill_animation_busy() -> bool:
	return _skill_animation_busy or _ranged_attack_busy


func _clear_skill_animation() -> void:
	_skill_animation_busy = false
	_skill_animation_sequence = PackedStringArray()
	_skill_animation_sequence_index = -1
	_skill_clip_start_time = 0.0
	_skill_clip_duration = 0.0
	_skill_impact_times = PackedFloat32Array()
	_next_skill_impact = 0
	_skill_impact_callback = Callable()
	_skill_playback_rate = 1.0
	_skill_facing_direction = Vector3.ZERO


func _dispatch_skill_impacts(clip_position: float, final_frame: bool = false) -> void:
	var elapsed := _skill_clip_start_time + clip_position
	while _next_skill_impact < _skill_impact_times.size():
		var index := _next_skill_impact
		if not final_frame and _skill_impact_times[index] > elapsed:
			break
		_next_skill_impact += 1
		if _skill_impact_callback.is_valid():
			_skill_impact_callback.call(index)


func _play_skill_animation_sequence_clip(duration: float = 0.0) -> bool:
	var clip_key := _skill_animation_sequence[_skill_animation_sequence_index]
	var clip := model_animation_player.get_animation(model_clips[clip_key])
	if clip == null:
		return false
	_skill_clip_duration = minf(duration, clip.length) if duration > 0.0 else clip.length
	return _play_model_animation(clip_key, true, _skill_clip_duration)


func get_skill_playback_rate() -> float:
	var bonus := GameData.get_survival_bonus("attack_speed") + GameData.get_survival_bonus("kill_attack_speed_rate")
	return clampf(stat_manager.cast_speed() * GameData.attack_speed_mult * (1.0 + bonus), 0.5, 2.5)


func set_skill_facing_direction(direction: Vector3) -> void:
	_skill_facing_direction = direction.slide(Vector3.UP).normalized()


func play_skill_animation(
	skill_key: String, skill_id: String, impact_times: PackedFloat32Array,
	on_impact: Callable, playback_rate: float, facing_direction: Vector3
) -> bool:
	if is_dead or is_skill_animation_busy() or not is_instance_valid(model_animation_player):
		return false
	var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
	var sequence_value: Variant = meta.get("animation_sequence", PackedStringArray())
	var sequence := PackedStringArray()
	if sequence_value is PackedStringArray or sequence_value is Array:
		for clip in sequence_value:
			if not str(clip).is_empty():
				sequence.append(str(clip))
	if sequence.is_empty():
		sequence.append(PlayerManager.get_skill_animation_key(skill_id, skill_key))
	for clip_key in sequence:
		if not model_clips.has(clip_key):
			return false
		var clip := model_animation_player.get_animation(model_clips[clip_key])
		if clip == null or clip.loop_mode != Animation.LOOP_NONE:
			return false
	var previous := model_animation_player.current_animation
	if previous == model_clips.get("Walk", "") or previous == model_clips.get("Run", ""):
		if model_animation_player.is_playing() and model_animation_player.current_animation_length > 0.0:
			_skill_gait_phase = model_animation_player.current_animation_position / model_animation_player.current_animation_length
	_skill_animation_sequence = sequence
	_skill_animation_sequence_index = 0
	_skill_impact_times = impact_times
	_skill_impact_callback = on_impact
	_skill_playback_rate = playback_rate
	set_skill_facing_direction(facing_direction)
	_skill_animation_busy = true
	var duration := float(meta.get("animation_duration", 0.0)) if sequence.size() == 1 else 0.0
	if _play_skill_animation_sequence_clip(duration):
		return true
	_clear_skill_animation()
	return false
