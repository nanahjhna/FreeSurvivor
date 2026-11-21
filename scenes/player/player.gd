class_name PlayerCharacter
extends CharacterBody3D

signal hp_changed(current_hp, max_hp)
signal sp_changed(current_sp, max_sp)
signal exp_changed(current_xp, xp_to_next)
signal leveled_up(new_level)
signal died()

@export var is_combat_enabled: bool = true
@export var max_hp: float = 100.0
var current_hp: float = 100.0
@export var max_sp: float = 30.0
var current_sp: float = 30.0

@export var base_move_speed: float = 6.8
@export var base_attack_damage: float = 15.0
@export var base_attack_speed: float = 1.2
@export var attack_range: float = 3.8
@export_range(1.0, 3.0, 0.1) var character_visual_scale: float = 1.5

var current_xp: int = 0
var xp_to_next_level: int = 10
var level: int = 1

var is_dead: bool = false
var auto_attack_timer: float = 0.0
var speed_boost_timer: float = 0.0
var auto_attack_enabled: bool = true
var touch_move_vector: Vector2 = Vector2.ZERO
var current_move_input: Vector2 = Vector2.ZERO
var _moving_by_input: bool = false
var _previous_move_input: bool = false
var _move_camera_right: Vector3 = Vector3.RIGHT
var _move_camera_down: Vector3 = Vector3.BACK
var manual_attack_cooldown: float = 0.0
var _hp_regen_timer: float = 0.0
var _time_since_last_damage: float = 0.0
var _sp_signal_timer: float = 0.0
var card_hit_bonuses: Dictionary = {}
var card_sp_regen: float = 0.0
var survival_shield: float = 0.0
var survival_shield_timer: float = 0.0
var last_stand_used: bool = false
var revive_used: bool = false

# References
@onready var visual_root: Node3D = $VisualRoot
@onready var character_model_root: Node3D = $VisualRoot/CharacterModelRoot
@onready var slash_effect: Node3D = $VisualRoot/SlashEffect
@onready var camera_node: Camera3D = $CameraPivot/SpringArm3D/Camera3D
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
var alternate_attack := false

var damage_number_scene: PackedScene = preload("res://scenes/effects/damage_number.tscn")
var stat_manager: StatManager = StatManager.new()

func _ready():
	add_to_group("player")
	set_character_appearance(GameData.get_leader_id())
	first_person_mode = false
	if character_model:
		character_model.visible = true
	_create_head_hp_bar()
	hp_changed.connect(_update_head_hp_bar)
	refresh_persistent_stats()
	collision_layer = 1 # Layer 1: Player
	collision_mask = 35 # Layer 1: Player, Layer 2: Enemies, Layer 6: Environment
	
	# Load persistent stats from GameData
	level = GameData.player_level
	current_xp = GameData.player_current_xp
	xp_to_next_level = GameData.player_xp_to_next
	max_hp = (stat_manager.max_hp() + GameData.max_hp_bonus) * (1.0 + GameData.get_survival_bonus("max_hp_percent"))
	current_hp = max_hp
	max_sp = stat_manager.max_sp()
	current_sp = max_sp
	GameData.player_current_hp = current_hp
	
	emit_signal("hp_changed", current_hp, max_hp)
	_update_head_hp_bar(current_hp, max_hp)
	emit_signal("sp_changed", current_sp, max_sp)
	emit_signal("exp_changed", current_xp, xp_to_next_level)
	if slash_effect:
		slash_effect.visible = false

func _physics_process(delta: float):
	if is_dead:
		return
	
	if manual_attack_cooldown > 0.0:
		manual_attack_cooldown = max(0.0, manual_attack_cooldown - delta)
	
	_handle_movement(delta)
	_update_hp_regeneration(delta)
	_update_survival_shield(delta)
	_update_sp_regeneration(delta)
	
	if is_combat_enabled:
		_handle_auto_attack(delta)
		_handle_items(delta)

func _process(_delta: float) -> void:
	# Keep the world-space indicator in lockstep even if a system updates HP
	# without emitting the usual signal.
	_update_head_hp_bar(current_hp, max_hp)

func set_touch_move(value: Vector2):
	touch_move_vector = value.limit_length(1.0)

func has_camera_move_input() -> bool:
	return _moving_by_input

func _handle_movement(delta: float):
	# Mobile joystick and PC arrow keys share the same camera-relative movement path.
	var input_vec: Vector2 = touch_move_vector
	if input_vec == Vector2.ZERO:
		if Input.is_action_pressed("move_up"):
			input_vec.y -= 1.0
		if Input.is_action_pressed("move_down"):
			input_vec.y += 1.0
		if Input.is_action_pressed("move_left"):
			input_vec.x -= 1.0
		if Input.is_action_pressed("move_right"):
			input_vec.x += 1.0
	input_vec = input_vec.limit_length(1.0)
	current_move_input = input_vec
	_moving_by_input = input_vec != Vector2.ZERO
	if _moving_by_input and not _previous_move_input:
		var start_right: Vector3 = camera_node.global_basis.x if camera_node != null else Vector3.RIGHT
		var start_down: Vector3 = camera_node.global_basis.z if camera_node != null else Vector3.BACK
		start_right.y = 0.0
		start_down.y = 0.0
		if start_right.length_squared() < 0.001:
			start_right = Vector3.RIGHT
		if start_down.length_squared() < 0.001:
			start_down = Vector3.BACK
		_move_camera_right = start_right.normalized()
		_move_camera_down = start_down.normalized()
	
	var effective_speed = base_move_speed * GameData.move_speed_mult * (1.0 + GameData.get_survival_bonus("move_speed"))
	if Input.is_key_pressed(KEY_SHIFT) and _moving_by_input:
		effective_speed *= 1.45
	if speed_boost_timer > 0.0:
		effective_speed *= 1.5
		speed_boost_timer -= delta
	
	var move_dir := Vector3.ZERO
	if _moving_by_input:
		move_dir = (_move_camera_right * input_vec.x + _move_camera_down * input_vec.y).normalized()
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	
	# Smooth acceleration and deceleration
	var target_vel_x = move_dir.x * effective_speed
	var target_vel_z = move_dir.z * effective_speed
	var acceleration_weight: float = 1.0 - exp(-14.0 * delta)
	velocity.x = lerpf(velocity.x, target_vel_x, acceleration_weight)
	velocity.z = lerpf(velocity.z, target_vel_z, acceleration_weight)
	
	move_and_slide()
	
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var is_moving = horizontal_speed > 0.2
	
	# Face the camera-relative movement direction without snapping.
	if _moving_by_input:
		var desired_angle: float = atan2(move_dir.x, move_dir.z)
		var turn_error: float = wrapf(desired_angle - visual_root.rotation.y, -PI, PI)
		if is_equal_approx(absf(turn_error), PI):
			turn_error = PI if input_vec.x >= 0.0 else -PI
		visual_root.rotation.y = wrapf(visual_root.rotation.y + turn_error * (1.0 - exp(-12.0 * delta)), -PI, PI)
		visual_root.rotation.z = lerpf(visual_root.rotation.z, -input_vec.x * 0.1, 1.0 - exp(-10.0 * delta))
	else:
		visual_root.rotation.z = lerpf(visual_root.rotation.z, 0.0, 1.0 - exp(-10.0 * delta))
	
	# Procedural Animation: Walk / Idle
	_animate_character(delta, is_moving, horizontal_speed / base_move_speed)
	_previous_move_input = _moving_by_input

func _animate_character(_delta: float, is_moving: bool, speed_ratio: float):
	var movement_clip := "Run" if speed_ratio > 1.15 else "Walk"
	_play_model_animation(movement_clip if is_moving else "Idle")

func set_character_appearance(character_id: String):
	var definition := PlayerManager.get_definition(character_id)
	if definition.is_empty():
		push_warning("등록되지 않은 플레이어 ID입니다: %s" % character_id)
		return
	current_appearance = character_id
	model_animation_player = null
	model_clips.clear()
	active_action_clip = ""
	for child in character_model_root.get_children():
		child.queue_free()
	character_model = PlayerManager.create_model(character_id, character_model_root)
	if character_model:
		# Match the player silhouette to the enlarged standard monsters while
		# keeping movement and combat collision sizes unchanged.
		character_model.scale *= Vector3.ONE * character_visual_scale
		character_model.visible = not first_person_mode
	if is_node_ready():
		_setup_model_animations()

func set_first_person_mode(enabled: bool) -> void:
	first_person_mode = enabled
	if character_model:
		character_model.visible = not enabled
	_update_head_hp_bar(current_hp, max_hp)

func set_head_hp_bar_visible(enabled: bool) -> void:
	_head_hp_bar_enabled = enabled
	_update_head_hp_bar(current_hp, max_hp)

func sync_head_hp_bar(current: float, maximum: float) -> void:
	_update_head_hp_bar(current, maximum)

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
	_head_hp_fill.scale.x = ratio
	_head_hp_fill.position.x = -(HEAD_HP_BAR_WIDTH * (1.0 - ratio) * 0.5)
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
	if not auto_attack_enabled:
		return
	var speed_multiplier := clampf(GameData.attack_speed_mult * (1.0 + GameData.get_survival_bonus("attack_speed") + GameData.get_survival_bonus("kill_attack_speed")), 0.5, 2.5)
	var effective_aspd = base_attack_speed * speed_multiplier
	auto_attack_timer += delta * effective_aspd
	
	if auto_attack_timer >= 1.0:
		var target = _find_closest_enemy(attack_range * (1.0 + GameData.get_survival_bonus("attack_range")))
		if target:
			_perform_auto_attack(target)
			auto_attack_timer = 0.0

func try_manual_attack() -> bool:
	if is_dead or not is_combat_enabled:
		UiFeedback.show_info("지금은 공격할 수 없습니다.")
		return false
	if manual_attack_cooldown > 0.0:
		return false
	var target = _find_closest_enemy(attack_range * (1.0 + GameData.get_survival_bonus("attack_range")))
	if target == null:
		UiFeedback.show_info("공격 범위에 적이 없습니다. 조금 더 가까이 이동하세요.")
		return false
	_perform_auto_attack(target)
	manual_attack_cooldown = 0.25
	return true

func set_auto_attack(enabled: bool):
	auto_attack_enabled = enabled
	UiFeedback.show_info("자동 공격을 %s했습니다." % ("켜" if enabled else "꺼"))

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

func _perform_auto_attack(target: Node3D):
	var dir_to_target = (target.global_position - global_position).normalized()
	if not _moving_by_input:
		visual_root.rotation.y = atan2(dir_to_target.x, dir_to_target.z)
	_play_model_animation("AttackAlt" if alternate_attack else "Attack", true)
	alternate_attack = not alternate_attack
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
		target.take_damage(dmg, is_critical)
		if randf() < GameData.get_survival_bonus("extra_attack"):
			target.take_damage(dmg * 0.8, false)
		if randf() < GameData.get_survival_bonus("lightning_proc"):
			target.take_damage(dmg * 0.5, false)
		if randf() < GameData.get_survival_bonus("chain_lightning"):
			var bounced := 0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy != target and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= 8.0:
					enemy.take_damage(dmg * 0.5)
					bounced += 1
					if bounced >= 2:
						break

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
				enemy.take_damage(base_attack_damage)

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

func _handle_items(_delta: float):
	if Input.is_action_just_pressed("item_1"):
		use_item(1)
	elif Input.is_action_just_pressed("item_2"):
		use_item(2)
	elif Input.is_action_just_pressed("item_3"):
		use_item(3)

func use_item(slot: int) -> bool:
	if GameData.item_counts.get(slot, 0) <= 0:
		var names := {1: "치유 물약", 2: "화면 폭탄", 3: "질풍 물약"}
		UiFeedback.show_error("%s이(가) 없습니다." % names.get(slot, "아이템"))
		return false
	
	match slot:
		1: # Heal Potion
			GameData.item_counts[1] -= 1
			heal(35.0)
		2: # Screen Bomb
			GameData.item_counts[2] -= 1
			_use_bomb()
		3: # Speed boost
			GameData.item_counts[3] -= 1
			speed_boost_timer = 5.0
			_show_damage_popup(0, false, false, "Speed Up!")
	GameData.data_updated.emit()
	return true

func _use_bomb():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.get("is_dead"):
			if global_position.distance_to(e.global_position) <= 16.0:
				if e.has_method("take_damage"):
					e.take_damage(80.0 * GameData.attack_damage_mult)
	_show_damage_popup(0, true, false, "BOMB!")

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
	base_attack_speed = 1.2 * stat_manager.attack_speed()
	var old_max_hp = max_hp
	var old_max_sp = max_sp
	max_hp = stat_manager.max_hp() + GameData.max_hp_bonus
	max_sp = stat_manager.max_sp()
	if old_max_hp > 0.0:
		current_hp = min(max_hp, current_hp + max_hp - old_max_hp)
	else:
		current_hp = max_hp
	if old_max_sp > 0.0:
		current_sp = min(max_sp, current_sp + max_sp - old_max_sp)
	else:
		current_sp = max_sp
	GameData.player_current_hp = current_hp
	if is_inside_tree():
		emit_signal("hp_changed", current_hp, max_hp)
		emit_signal("sp_changed", current_sp, max_sp)

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

func _update_sp_regeneration(delta: float):
	if current_sp >= max_sp:
		_sp_signal_timer = 0.0
		return
	current_sp = min(max_sp, current_sp + (stat_manager.sp_recovery_rate() + card_sp_regen) * delta)
	_sp_signal_timer += delta
	if _sp_signal_timer >= 0.1:
		_sp_signal_timer = 0.0
		emit_signal("sp_changed", current_sp, max_sp)

func use_sp(amount: float) -> bool:
	if amount < 0.0 or current_sp + 0.001 < amount:
		return false
	current_sp = max(0.0, current_sp - amount)
	_sp_signal_timer = 0.0
	emit_signal("sp_changed", current_sp, max_sp)
	return true

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
	_show_damage_popup(reduced_damage, false, false)
	_flash_red()
	if current_hp > 0.0:
		_play_model_animation("Hit", true)
	
	if current_hp <= 0.0:
		die()

func _flash_red():
	var tween = create_tween()
	tween.tween_property(visual_root, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.12)

func _show_damage_popup(amount: float, is_crit: bool = false, is_heal: bool = false, custom_text: String = ""):
	var popup_scene = load("res://scenes/effects/damage_number.tscn")
	if popup_scene:
		var popup = popup_scene.instantiate()
		get_tree().current_scene.add_child(popup)
		popup.global_position = global_position + Vector3(0, 1.8, 0)
		if custom_text != "":
			var lbl = popup.get_node_or_null("Label3D")
			if lbl:
				lbl.text = custom_text
				lbl.modulate = Color(1.0, 0.8, 0.1)
		else:
			popup.setup(amount, is_crit, is_heal)

func die():
	if is_dead:
		return
	is_dead = true
	emit_signal("died")
	if _play_model_animation("Death", true):
		var death_wait := create_tween()
		death_wait.tween_interval(2.0)
		death_wait.tween_callback(func(): GameManager.game_over())
	else:
		var tween = create_tween()
		tween.tween_property(visual_root, "rotation:x", -PI / 2.0, 0.4)
		tween.tween_callback(func(): GameManager.game_over())


func _setup_model_animations():
	if character_model == null:
		return
	var players := character_model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	model_animation_player = players[0] as AnimationPlayer
	if model_animation_player == null:
		return
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
	for clip_key in ["Idle", "Walk", "Run"]:
		if model_clips.has(clip_key):
			var clip := model_animation_player.get_animation(model_clips[clip_key])
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
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
	if str(animation_name) == active_action_clip:
		active_action_clip = ""


func _play_model_animation(clip_key: String, action: bool = false) -> bool:
	if model_animation_player == null or not model_clips.has(clip_key):
		return false
	var clip_name := str(model_clips[clip_key])
	if action:
		active_action_clip = clip_name
		model_animation_player.play(clip_name, 0.12)
		return true
	if not active_action_clip.is_empty() and model_animation_player.is_playing():
		return true
	if str(model_animation_player.current_animation) != clip_name or not model_animation_player.is_playing():
		model_animation_player.play(clip_name, 0.16)
	return true


func play_skill_animation(skill_key: String, skill_id: String = ""):
	var animation_key := PlayerManager.get_skill_animation_key(skill_id, skill_key) if not skill_id.is_empty() else ("Kick" if skill_key == "w" else "AttackAlt")
	_play_model_animation(animation_key, true)
