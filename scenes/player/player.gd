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

var current_xp: int = 0
var xp_to_next_level: int = 10
var level: int = 1

var is_dead: bool = false
var auto_attack_timer: float = 0.0
var speed_boost_timer: float = 0.0
var walk_cycle: float = 0.0
var auto_attack_enabled: bool = true
var touch_move_vector: Vector2 = Vector2.ZERO
var manual_attack_cooldown: float = 0.0
var _hp_regen_timer: float = 0.0
var _sp_signal_timer: float = 0.0
var card_hit_bonuses: Dictionary = {}
var card_sp_regen: float = 0.0
var survival_shield: float = 0.0
var survival_shield_timer: float = 0.0
var last_stand_used: bool = false
var revive_used: bool = false

# References
@onready var visual_root: Node3D = $VisualRoot
@onready var slash_effect: Node3D = $VisualRoot/SlashEffect
@onready var arm_l: Node3D = $VisualRoot.get_node_or_null("ArmL")
@onready var arm_r: Node3D = $VisualRoot.get_node_or_null("ArmR")
@onready var leg_l: Node3D = $VisualRoot.get_node_or_null("LegL")
@onready var leg_r: Node3D = $VisualRoot.get_node_or_null("LegR")

var damage_number_scene: PackedScene = preload("res://scenes/effects/damage_number.tscn")
var stat_manager: StatManager = StatManager.new()

func _ready():
	add_to_group("player")
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

func set_touch_move(value: Vector2):
	touch_move_vector = value.limit_length(1.0)

func _handle_movement(delta: float):
	var input_vec = touch_move_vector
	if Input.is_action_pressed("move_up"):
		input_vec.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vec.y += 1.0
	if Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vec.x += 1.0
	
	input_vec = input_vec.limit_length(1.0)
	
	var effective_speed = base_move_speed * GameData.move_speed_mult * (1.0 + GameData.get_survival_bonus("move_speed"))
	if speed_boost_timer > 0.0:
		effective_speed *= 1.5
		speed_boost_timer -= delta
	
	var move_dir = Vector3(input_vec.x, 0.0, input_vec.y)
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	
	# Smooth acceleration and deceleration
	var target_vel_x = move_dir.x * effective_speed
	var target_vel_z = move_dir.z * effective_speed
	velocity.x = lerp(velocity.x, target_vel_x, 15.0 * delta)
	velocity.z = lerp(velocity.z, target_vel_z, 15.0 * delta)
	
	move_and_slide()
	
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var is_moving = horizontal_speed > 0.2
	
	# Smooth rotation toward movement direction
	if move_dir.length_squared() > 0.01:
		var target_angle = atan2(move_dir.x, move_dir.z) + PI
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, 14.0 * delta)
		visual_root.rotation.z = lerp(visual_root.rotation.z, -input_vec.x * 0.1, 10.0 * delta)
	else:
		visual_root.rotation.z = lerp(visual_root.rotation.z, 0.0, 10.0 * delta)
	
	# Procedural Animation: Walk / Idle
	_animate_character(delta, is_moving, horizontal_speed / base_move_speed)

func _animate_character(delta: float, is_moving: bool, speed_ratio: float):
	if is_moving:
		walk_cycle += delta * 11.0 * clamp(speed_ratio, 0.5, 1.5)
		var swing = sin(walk_cycle) * 0.65
		if arm_l: arm_l.rotation.x = swing
		if arm_r: arm_r.rotation.x = -swing
		if leg_l: leg_l.rotation.x = -swing
		if leg_r: leg_r.rotation.x = swing
		visual_root.position.y = abs(sin(walk_cycle)) * 0.07
	else:
		walk_cycle = 0.0
		if arm_l: arm_l.rotation.x = lerp_angle(arm_l.rotation.x, 0.0, 10.0 * delta)
		if arm_r: arm_r.rotation.x = lerp_angle(arm_r.rotation.x, 0.0, 10.0 * delta)
		if leg_l: leg_l.rotation.x = lerp_angle(leg_l.rotation.x, 0.0, 10.0 * delta)
		if leg_r: leg_r.rotation.x = lerp_angle(leg_r.rotation.x, 0.0, 10.0 * delta)
		visual_root.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.03

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
	visual_root.rotation.y = atan2(dir_to_target.x, dir_to_target.z) + PI
	_show_slash_effect()
	if randf() * 100.0 >= stat_manager.hit_rate():
		_show_damage_popup(0, false, false, "MISS")
		return
	var is_critical := randf() * 100.0 < minf(80.0, stat_manager.crit_rate() + GameData.get_survival_bonus("crit_chance") * 100.0)
	var dmg = base_attack_damage * GameData.attack_damage_mult * (1.0 + GameData.get_survival_bonus("damage") + GameData.get_survival_bonus("damage_reckless") + GameData.get_survival_bonus("physical_damage"))
	var monster_target: BaseMonster = target as BaseMonster
	if monster_target != null and monster_target.monster_id == "mutant_lord":
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
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(xp_to_next_level * 1.2) + 2
		gained_level = true
	GameData.player_level = level
	GameData.player_current_xp = current_xp
	GameData.player_xp_to_next = xp_to_next_level
	if gained_level:
		emit_signal("leveled_up", level)
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
	_hp_regen_timer += delta
	if _hp_regen_timer < 1.0:
		return
	var elapsed := _hp_regen_timer
	_hp_regen_timer = 0.0
	current_hp = min(max_hp, current_hp + (stat_manager.hp_recovery_rate() + max_hp * GameData.get_survival_bonus("hp_regen")) * elapsed)
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
	
	var tween = create_tween()
	tween.tween_property(visual_root, "rotation:x", -PI / 2.0, 0.4)
	tween.tween_callback(func(): GameManager.game_over())
