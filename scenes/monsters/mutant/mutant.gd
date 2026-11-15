extends "res://scenes/monsters/base_monster.gd"

func _ready():
	monster_id = "mutant"
	max_hp = 110.0
	move_speed = 2.1
	attack_damage = 16.0
	attack_range = 1.8
	attack_interval = 1.4
	xp_value = 5
	super._ready()
