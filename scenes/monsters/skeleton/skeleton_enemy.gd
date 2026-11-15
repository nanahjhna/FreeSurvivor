extends "res://scenes/monsters/base_monster.gd"

var projectile_scene: PackedScene = preload("res://scenes/monsters/skeleton/skeleton_projectile.tscn")

func _ready():
	monster_id = "skeleton"
	max_hp = 25.0
	move_speed = 2.6
	attack_damage = 8.0
	attack_range = 8.0
	attack_interval = 2.0
	xp_value = 2
	super._ready()

func _update_movement(delta: float):
	if target == null or not is_instance_valid(target):
		return
	
	var to_target = target.global_position - global_position
	to_target.y = 0.0
	var dist = to_target.length()
	
	if dist > 0.1:
		var target_rot = atan2(to_target.x, to_target.z)
		if visual_root:
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rot, 7.0 * delta)
		else:
			rotation.y = lerp_angle(rotation.y, target_rot, 7.0 * delta)
	
	var dir = to_target.normalized()
	if dist > attack_range:
		# Approach
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	elif dist < 3.2:
		# Back away slowly
		velocity.x = -dir.x * (move_speed * 0.6)
		velocity.z = -dir.z * (move_speed * 0.6)
	else:
		# In shooting sweet spot
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
	
	if target and is_instance_valid(target):
		var proj = projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position + Vector3(0, 1.2, 0)
		var fire_dir = (target.global_position + Vector3(0, 0.8, 0) - proj.global_position).normalized()
		proj.setup(fire_dir, attack_damage)
