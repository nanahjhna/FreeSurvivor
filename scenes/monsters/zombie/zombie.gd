extends "res://scenes/monsters/base_monster.gd"

func _ready():
	max_hp = 35.0
	move_speed = 3.2
	attack_damage = 7.0
	attack_range = 1.4
	attack_interval = 1.0
	xp_value = 1
	super._ready()
