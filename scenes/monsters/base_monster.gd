extends CharacterBody3D
class_name BaseMonster

signal died(monster)

@export var max_hp: float = 30.0
@export var move_speed: float = 3.2
@export var attack_damage: float = 6.0
@export var attack_range: float = 1.4
@export var attack_interval: float = 1.0
@export var xp_value: int = 1

var current_hp: float
var target: Node3D = null
var can_attack: bool = true
var attack_cooldown_timer: float = 0.0
var is_dead: bool = false

@onready var visual_root: Node3D = $VisualRoot

func _ready():
	add_to_group("enemies")
	collision_layer = 2  # Layer 2: Enemies
	collision_mask = 35 # Layer 1: Player, Layer 2: Enemies, Layer 6: Environment
	current_hp = max_hp

func _physics_process(delta: float):
	if is_dead:
		return
	
	if not can_attack:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0.0:
			can_attack = true
	
	_find_target()
	_update_movement(delta)

func _find_target():
	if target == null or not is_instance_valid(target):
		var p = get_tree().get_first_node_in_group("player")
		if p and is_instance_valid(p):
			target = p

func _update_movement(delta: float):
	if target == null or not is_instance_valid(target):
		return
	
	var to_target = target.global_position - global_position
	to_target.y = 0.0
	var dist = to_target.length()
	
	if dist > 0.1:
		var target_rot = atan2(to_target.x, to_target.z)
		if visual_root:
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rot, 8.0 * delta)
		else:
			rotation.y = lerp_angle(rotation.y, target_rot, 8.0 * delta)
	
	if dist > attack_range:
		var dir = to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		
		# Slight bobbing while walking
		if visual_root:
			visual_root.position.y = sin(Time.get_ticks_msec() * 0.012) * 0.08
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if can_attack:
			perform_attack()
	
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	
	move_and_slide()

func perform_attack():
	can_attack = false
	attack_cooldown_timer = attack_interval
	
	# Attack punch animation
	if visual_root:
		var tween = create_tween()
		tween.tween_property(visual_root, "position:z", -0.4, 0.1)
		tween.tween_property(visual_root, "position:z", 0.0, 0.15)
	
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		var dist = global_position.distance_to(target.global_position)
		if dist <= attack_range + 0.8:
			target.take_damage(attack_damage)

func take_damage(amount: float, is_crit: bool = false):
	if is_dead:
		return
	
	current_hp -= amount
	_show_damage_popup(amount, is_crit)
	_flash_hit()
	
	if current_hp <= 0.0:
		die()

func _flash_hit():
	if visual_root:
		var tween = create_tween()
		tween.tween_property(visual_root, "scale", Vector3(1.2, 0.8, 1.2), 0.06)
		tween.tween_property(visual_root, "scale", Vector3.ONE, 0.1)

func _show_damage_popup(amount: float, is_crit: bool = false):
	var popup_scene = load("res://scenes/effects/damage_number.tscn")
	if popup_scene:
		var popup = popup_scene.instantiate()
		get_tree().current_scene.add_child(popup)
		popup.global_position = global_position + Vector3(0, 1.8, 0)
		popup.setup(amount, is_crit, false)

func die():
	if is_dead:
		return
	is_dead = true
	emit_signal("died", self)
	
	# Remove from group and disable collisions
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	
	# Spawn XP Gem
	_spawn_xp_gem()
	
	# Add Kill count to GameManager
	GameManager.add_kill()
	
	# Death animation: fall and shrink
	if visual_root:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual_root, "rotation:x", PI * 0.5, 0.25)
		tween.tween_property(visual_root, "scale", Vector3.ZERO, 0.3).set_delay(0.1)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _spawn_xp_gem():
	var gem_scene = load("res://scenes/effects/xp_gem.tscn")
	if gem_scene:
		var gem = gem_scene.instantiate()
		gem.xp_value = xp_value
		get_tree().current_scene.add_child(gem)
		gem.global_position = global_position + Vector3(0, 0.5, 0)
