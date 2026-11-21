extends CharacterBody3D
class_name BaseMonster

signal died(monster)

@export var max_hp: float = 30.0
@export var move_speed: float = 3.2
@export var attack_damage: float = 6.0
@export var attack_range: float = 1.4
@export var attack_interval: float = 1.0
@export var xp_value: int = 1
@export var monster_id: String = "zombie"
@export var death_visual_duration: float = 0.4
@export var model_faces_negative_z: bool = false

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/effects/damage_number.tscn")

var current_hp: float
var target: Node3D = null
var can_attack: bool = true
var attack_cooldown_timer: float = 0.0
var is_dead: bool = false
var card_statuses: Dictionary = {}
var damage_popup_cooldown: float = 0.0
var hit_flash_cooldown: float = 0.0

@onready var visual_root: Node3D = $VisualRoot

func _ready():
	add_to_group("enemies")
	collision_layer = 2  # Layer 2: Enemies
	collision_mask = 33 # Layer 1: Player and Layer 6: Environment; enemies don't collide with each other.
	current_hp = max_hp

func _physics_process(delta: float):
	damage_popup_cooldown = maxf(0.0, damage_popup_cooldown - delta)
	hit_flash_cooldown = maxf(0.0, hit_flash_cooldown - delta)
	if is_dead:
		return
	if not card_statuses.is_empty():
		_tick_card_statuses(delta)
		if is_dead:
			return
	
	if not can_attack:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0.0:
			can_attack = true
	
	_find_target()
	_update_movement(delta)

func apply_card_status(status: String, damage: float):
	var effect: Dictionary = card_statuses.get(status, {"until_tick": 1.0})
	effect.damage = damage
	effect.ticks = 3
	card_statuses[status] = effect

func _tick_card_statuses(delta: float):
	for status in card_statuses.keys():
		var effect: Dictionary = card_statuses[status]
		effect.until_tick -= delta
		if effect.until_tick <= 0.0:
			effect.until_tick += 1.0
			effect.ticks -= 1
			take_damage(float(effect.damage))
			if effect.ticks == 0:
				card_statuses.erase(status)
			if is_dead:
				return

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
		var target_rot: float = atan2(to_target.x, to_target.z) + (PI if model_faces_negative_z else 0.0)
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
	if hit_flash_cooldown > 0.0:
		return
	hit_flash_cooldown = 0.10
	if visual_root:
		var rest_scale := visual_root.scale
		var tween = create_tween()
		tween.tween_property(visual_root, "scale", rest_scale * Vector3(1.2, 0.8, 1.2), 0.06)
		tween.tween_property(visual_root, "scale", rest_scale, 0.1)

func _show_damage_popup(amount: float, is_crit: bool = false):
	if damage_popup_cooldown > 0.0:
		return
	damage_popup_cooldown = 0.10
	var popup = DAMAGE_NUMBER_SCENE.instantiate()
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
	var monster_definition := MonsterManager.get_definition(monster_id)
	var is_boss := bool(monster_definition.get("is_boss", false))
	var boss_reward_multiplier := float(get_meta("boss_reward_multiplier", 1.0)) if is_boss else 1.0
	var gold_drop := int(monster_definition.get("gold", 25))
	GameManager.add_dungeon_gold(int(round(gold_drop * (1.0 + GameData.get_survival_bonus("gold")) * boss_reward_multiplier)))
	GameData.record_monster_kill(monster_id)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("on_monster_killed"):
		player.on_monster_killed(self)
	if is_boss:
		GameManager.register_boss_defeat()
	
	# Keep the imported death animation visible before removing the monster.
	if visual_root:
		var tween = create_tween()
		tween.set_parallel(true)
		if bool(monster_definition.get("fall_on_death", true)):
			tween.tween_property(visual_root, "rotation:x", PI * 0.5, 0.25)
		tween.tween_property(visual_root, "scale", Vector3.ZERO, 0.2).set_delay(death_visual_duration - 0.2)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _spawn_xp_gem():
	var gem_scene = load("res://scenes/effects/xp_gem.tscn")
	if gem_scene:
		var monster_definition := MonsterManager.get_definition(monster_id)
		var is_boss := bool(monster_definition.get("is_boss", false))
		var gem := gem_scene.instantiate() as PickupGem
		var boss_bonus := 1.0 + GameData.get_survival_bonus("boss_xp") if is_boss else 1.0
		if is_boss:
			boss_bonus *= float(get_meta("boss_reward_multiplier", 1.0))
		gem.xp_value = int(round(xp_value * 8 * boss_bonus))
		gem.gold_reward = 0
		gem.lifetime_seconds = 45.0
		_place_pickup(gem, Vector3(0.0, 0.5, 0.0))
		if is_boss or randf() < float(monster_definition.get("potion_chance", 0.0)):
			var potion := gem_scene.instantiate() as PickupGem
			potion.reward_type = "치유 물약"
			potion.reward_value = 1
			potion.lifetime_seconds = 45.0
			_place_pickup(potion, Vector3(0.7, 0.5, 0.0))

func _place_pickup(new_pickup: PickupGem, offset: Vector3):
	var existing_pickups := get_tree().get_nodes_in_group("xp_gems")
	if existing_pickups.size() >= 120:
		for existing in existing_pickups:
			var pickup := existing as PickupGem
			if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
				continue
			if str(pickup.get("reward_type")) != str(new_pickup.get("reward_type")):
				continue
			if new_pickup.get("reward_type") == "경험치":
				pickup.xp_value += new_pickup.xp_value
				pickup.gold_reward += new_pickup.gold_reward
			else:
				pickup.reward_value += new_pickup.reward_value
			new_pickup.free()
			return
		# Keep a potion reward even when the pickup cap is full of experience gems.
		if new_pickup.get("reward_type") == "치유 물약":
			for existing in existing_pickups:
				var pickup := existing as PickupGem
				if is_instance_valid(pickup) and not pickup.is_queued_for_deletion() and pickup.reward_type == "경험치":
					pickup.potion_reward += new_pickup.reward_value
					pickup.refresh_label()
					new_pickup.free()
					return
	get_tree().current_scene.add_child(new_pickup)
	new_pickup.global_position = global_position + offset
