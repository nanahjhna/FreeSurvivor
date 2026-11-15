extends Node

signal skill_cooldown_updated(skill_key: String, current_cd: float, max_cd: float)

var sword_wave_scene: PackedScene = preload("res://scenes/skills/sword_wave.tscn")
var spin_attack_scene: PackedScene = preload("res://scenes/skills/spin_attack.tscn")
var flame_attack_scene: PackedScene = preload("res://scenes/skills/flame_attack.tscn")
var explosion_scene: PackedScene = preload("res://scenes/skills/explosion.tscn")

var cooldowns: Dictionary = {
	"q": 0.0,
	"w": 0.0,
	"e": 0.0,
	"r": 0.0
}

var player: Node3D = null

func _ready():
	player = get_parent() as Node3D

func _process(delta: float):
	if GameManager.current_location != GameManager.Location.BATTLE:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	
	# Update cooldowns
	for key in cooldowns:
		if cooldowns[key] > 0.0:
			cooldowns[key] = max(0.0, cooldowns[key] - delta)
			var max_cd = GameData.skill_cooldowns.get(key, 1.0)
			emit_signal("skill_cooldown_updated", key, cooldowns[key], max_cd)
	
	# Check skill activations
	if Input.is_action_just_pressed("skill_q") and cooldowns["q"] <= 0.0:
		_cast_q()
	elif Input.is_action_just_pressed("skill_w") and cooldowns["w"] <= 0.0:
		_cast_w()
	elif Input.is_action_just_pressed("skill_e") and cooldowns["e"] <= 0.0:
		_cast_e()
	elif Input.is_action_just_pressed("skill_r") and cooldowns["r"] <= 0.0:
		_cast_r()

func _get_player_facing() -> Vector3:
	var visual_root = player.get_node_or_null("VisualRoot")
	if visual_root:
		var rot_y = visual_root.rotation.y
		return Vector3(sin(rot_y), 0, cos(rot_y))
	return -player.global_transform.basis.z

func _cast_q():
	var max_cd = GameData.skill_cooldowns.get("q", 2.5)
	cooldowns["q"] = max_cd
	emit_signal("skill_cooldown_updated", "q", max_cd, max_cd)
	
	var facing = _get_player_facing()
	var wave = sword_wave_scene.instantiate()
	get_tree().current_scene.add_child(wave)
	wave.global_position = player.global_position + Vector3(0, 0.8, 0) + facing * 0.5
	wave.setup(facing, GameData.attack_damage_mult)

func _cast_w():
	var max_cd = GameData.skill_cooldowns.get("w", 4.5)
	cooldowns["w"] = max_cd
	emit_signal("skill_cooldown_updated", "w", max_cd, max_cd)
	
	var spin = spin_attack_scene.instantiate()
	get_tree().current_scene.add_child(spin)
	spin.setup(player, GameData.attack_damage_mult)

func _cast_e():
	var max_cd = GameData.skill_cooldowns.get("e", 3.5)
	cooldowns["e"] = max_cd
	emit_signal("skill_cooldown_updated", "e", max_cd, max_cd)
	
	var facing = _get_player_facing()
	var flame = flame_attack_scene.instantiate()
	get_tree().current_scene.add_child(flame)
	flame.setup(player.global_position, facing, GameData.attack_damage_mult)

func _cast_r():
	var max_cd = GameData.skill_cooldowns.get("r", 8.0)
	cooldowns["r"] = max_cd
	emit_signal("skill_cooldown_updated", "r", max_cd, max_cd)
	
	var boom = explosion_scene.instantiate()
	get_tree().current_scene.add_child(boom)
	boom.setup(player.global_position, GameData.attack_damage_mult)
