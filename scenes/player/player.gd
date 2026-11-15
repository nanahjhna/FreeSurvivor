extends CharacterBody3D

signal hp_changed(current_hp, max_hp)
signal exp_changed(current_xp, xp_to_next)
signal leveled_up(new_level)
signal died()

@export var is_combat_enabled: bool = true
@export var max_hp: float = 100.0
var current_hp: float = 100.0

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

# References
@onready var visual_root: Node3D = $VisualRoot
@onready var slash_effect: Node3D = $VisualRoot/SlashEffect
@onready var arm_l: Node3D = $VisualRoot.get_node_or_null("ArmL")
@onready var arm_r: Node3D = $VisualRoot.get_node_or_null("ArmR")
@onready var leg_l: Node3D = $VisualRoot.get_node_or_null("LegL")
@onready var leg_r: Node3D = $VisualRoot.get_node_or_null("LegR")

var damage_number_scene: PackedScene = preload("res://scenes/effects/damage_number.tscn")

func _ready():
	add_to_group("player")
	collision_layer = 1 # Layer 1: Player
	collision_mask = 35 # Layer 1: Player, Layer 2: Enemies, Layer 6: Environment
	
	# Load persistent stats from GameData
	level = GameData.player_level
	current_xp = GameData.player_current_xp
	xp_to_next_level = GameData.player_xp_to_next
	max_hp = 100.0 + GameData.max_hp_bonus
	current_hp = max_hp
	GameData.player_current_hp = current_hp
	
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("exp_changed", current_xp, xp_to_next_level)
	if slash_effect:
		slash_effect.visible = false

func _physics_process(delta: float):
	if is_dead:
		return
	
	_handle_movement(delta)
	
	if is_combat_enabled:
		_handle_auto_attack(delta)
		_handle_items(delta)

func _handle_movement(delta: float):
	var input_vec = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		input_vec.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vec.y += 1.0
	if Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vec.x += 1.0
	
	input_vec = input_vec.normalized()
	
	var effective_speed = base_move_speed * GameData.move_speed_mult
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
		var target_angle = atan2(move_dir.x, move_dir.z)
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
	var effective_aspd = base_attack_speed * GameData.attack_speed_mult
	auto_attack_timer += delta * effective_aspd
	
	if auto_attack_timer >= 1.0:
		var target = _find_closest_enemy(attack_range)
		if target:
			_perform_auto_attack(target)
			auto_attack_timer = 0.0

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
	visual_root.rotation.y = atan2(dir_to_target.x, dir_to_target.z)
	_show_slash_effect()
	
	var dmg = base_attack_damage * GameData.attack_damage_mult
	if target.has_method("take_damage"):
		target.take_damage(dmg)

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

func use_item(slot: int):
	if GameData.item_counts.get(slot, 0) <= 0:
		return
	
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
	if current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(xp_to_next_level * 1.35) + 5
		GameData.player_level = level
		GameData.player_current_xp = current_xp
		GameData.player_xp_to_next = xp_to_next_level
		emit_signal("leveled_up", level)
		GameManager.enter_level_up()
	
	GameData.player_current_xp = current_xp
	emit_signal("exp_changed", current_xp, xp_to_next_level)

func heal(amount: float):
	current_hp = min(current_hp + amount, max_hp)
	GameData.player_current_hp = current_hp
	emit_signal("hp_changed", current_hp, max_hp)
	_show_damage_popup(amount, false, true)

func take_damage(amount: float):
	if is_dead:
		return
	
	current_hp = max(0.0, current_hp - amount)
	GameData.player_current_hp = current_hp
	emit_signal("hp_changed", current_hp, max_hp)
	_show_damage_popup(amount, false, false)
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
