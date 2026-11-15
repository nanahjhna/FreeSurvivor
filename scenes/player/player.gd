extends CharacterBody3D

signal hp_changed(current_hp, max_hp)
signal exp_changed(current_xp, xp_to_next)
signal leveled_up(new_level)
signal died()

@export var max_hp: float = 100.0
var current_hp: float = 100.0

@export var base_move_speed: float = 6.5
@export var base_attack_damage: float = 15.0
@export var base_attack_speed: float = 1.2
@export var attack_range: float = 3.8

var current_xp: int = 0
var xp_to_next_level: int = 10
var level: int = 1

var is_dead: bool = false
var auto_attack_timer: float = 0.0
var speed_boost_timer: float = 0.0

# References
@onready var visual_root: Node3D = $VisualRoot
@onready var slash_effect: Node3D = $VisualRoot/SlashEffect

var damage_number_scene: PackedScene = preload("res://scenes/effects/damage_number.tscn")

func _ready():
	add_to_group("player")
	collision_layer = 1 # Layer 1: Player
	collision_mask = 34 # Layer 2: Enemies, Layer 6: Environment
	current_hp = max_hp
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("exp_changed", current_xp, xp_to_next_level)
	if slash_effect:
		slash_effect.visible = false

func _physics_process(delta: float):
	if is_dead:
		return
	
	_handle_movement(delta)
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
	
	velocity.x = move_dir.x * effective_speed
	velocity.z = move_dir.z * effective_speed
	
	move_and_slide()
	
	# Smooth rotation toward movement direction
	if move_dir.length_squared() > 0.01:
		var target_angle = atan2(move_dir.x, move_dir.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, 14.0 * delta)
		
		# Slight tilt while running
		visual_root.rotation.z = lerp(visual_root.rotation.z, -input_vec.x * 0.12, 10.0 * delta)

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
	# Face target briefly
	var dir_to_target = (target.global_position - global_position).normalized()
	visual_root.rotation.y = atan2(dir_to_target.x, dir_to_target.z)
	
	# Slash visual
	_show_slash_effect()
	
	# Deal damage
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
		emit_signal("leveled_up", level)
		GameManager.enter_level_up()
	emit_signal("exp_changed", current_xp, xp_to_next_level)

func heal(amount: float):
	current_hp = min(current_hp + amount, max_hp)
	emit_signal("hp_changed", current_hp, max_hp)
	_show_damage_popup(amount, false, true)

func take_damage(amount: float):
	if is_dead:
		return
	
	current_hp = max(0.0, current_hp - amount)
	emit_signal("hp_changed", current_hp, max_hp)
	_show_damage_popup(amount, false, false)
	
	# Flash red
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
	
	# Fall down animation
	var tween = create_tween()
	tween.tween_property(visual_root, "rotation:x", -PI / 2.0, 0.4)
	tween.tween_callback(func(): GameManager.game_over())
