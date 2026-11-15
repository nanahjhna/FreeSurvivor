extends Node

# Player stat modifiers
var attack_damage_mult: float = 1.0
var attack_speed_mult: float = 1.0
var move_speed_mult: float = 1.0
var max_hp_bonus: float = 0.0

# Skill cooldown settings (seconds)
var skill_cooldowns: Dictionary = {
	"q": 2.5,
	"w": 4.5,
	"e": 3.5,
	"r": 8.0
}

# Items stock
var item_counts: Dictionary = {
	1: 3, # Potion (Heal 30)
	2: 1, # Bomb (Screen clear)
	3: 2  # Speed Boost
}

# Available upgrades pool
var all_upgrades: Array[Dictionary] = [
	{
		"id": "atk_up",
		"name": "공격력 강화",
		"description": "기본 및 스킬 공격력이 20% 증가합니다.",
		"type": "stat",
		"stat": "attack_damage_mult",
		"value": 0.2
	},
	{
		"id": "aspd_up",
		"name": "공격속도 증가",
		"description": "기본 공격 속도가 20% 빨라집니다.",
		"type": "stat",
		"stat": "attack_speed_mult",
		"value": 0.2
	},
	{
		"id": "mspd_up",
		"name": "이동속도 증가",
		"description": "캐릭터 이동속도가 15% 증가합니다.",
		"type": "stat",
		"stat": "move_speed_mult",
		"value": 0.15
	},
	{
		"id": "max_hp_up",
		"name": "최대 체력 증가",
		"description": "최대 HP가 25 증가하고 체력을 25 회복합니다.",
		"type": "hp",
		"value": 25.0
	},
	{
		"id": "q_cd",
		"name": "검기 쿨타임 감소",
		"description": "Q 스킬 검기 쿨타임이 20% 감소합니다.",
		"type": "cd",
		"skill": "q",
		"value": 0.2
	},
	{
		"id": "r_cd",
		"name": "대폭발 쿨타임 감소",
		"description": "R 스킬 대폭발 쿨타임이 25% 감소합니다.",
		"type": "cd",
		"skill": "r",
		"value": 0.25
	}
]

func reset_data():
	attack_damage_mult = 1.0
	attack_speed_mult = 1.0
	move_speed_mult = 1.0
	max_hp_bonus = 0.0
	skill_cooldowns = {
		"q": 2.5,
		"w": 4.5,
		"e": 3.5,
		"r": 8.0
	}
	item_counts = {1: 3, 2: 1, 3: 2}

func get_random_upgrades(count: int = 3) -> Array[Dictionary]:
	var pool = all_upgrades.duplicate()
	pool.shuffle()
	var selected: Array[Dictionary] = []
	for i in range(min(count, pool.size())):
		selected.append(pool[i])
	return selected

func apply_upgrade(upgrade: Dictionary):
	match upgrade.get("type", ""):
		"stat":
			var stat_name = upgrade.get("stat", "")
			var val = upgrade.get("value", 0.0)
			if stat_name == "attack_damage_mult":
				attack_damage_mult += val
			elif stat_name == "attack_speed_mult":
				attack_speed_mult += val
			elif stat_name == "move_speed_mult":
				move_speed_mult += val
		"hp":
			max_hp_bonus += upgrade.get("value", 0.0)
			var player = Engine.get_main_loop().root.find_child("Player", true, false)
			if player and player.has_method("heal"):
				player.max_hp = 100.0 + max_hp_bonus
				player.heal(upgrade.get("value", 0.0))
		"cd":
			var skill = upgrade.get("skill", "")
			var red = upgrade.get("value", 0.0)
			if skill_cooldowns.has(skill):
				skill_cooldowns[skill] = max(0.5, skill_cooldowns[skill] * (1.0 - red))
