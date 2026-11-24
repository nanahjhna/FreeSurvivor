class_name StatManager
extends RefCounted

const STAT_KEYS: Array[String] = ["STR", "AGI", "VIT", "INT", "DEX", "LUK"]
const LEGACY_STATS: Dictionary = {
	"warrior": {"STR": 8, "AGI": 4, "VIT": 7, "INT": 2, "DEX": 3, "LUK": 3},
	"archer": {"STR": 3, "AGI": 7, "VIT": 4, "INT": 3, "DEX": 8, "LUK": 4},
	"mage": {"STR": 2, "AGI": 4, "VIT": 3, "INT": 9, "DEX": 4, "LUK": 3},
	"paladin": {"STR": 7, "AGI": 3, "VIT": 9, "INT": 3, "DEX": 3, "LUK": 2},
	"assassin": {"STR": 5, "AGI": 9, "VIT": 4, "INT": 2, "DEX": 6, "LUK": 6},
	"priest": {"STR": 2, "AGI": 4, "VIT": 5, "INT": 8, "DEX": 3, "LUK": 4}
}

const FIGHTER_STATS := {"STR": 7, "AGI": 7, "VIT": 6, "INT": 3, "DEX": 4, "LUK": 3}

const CLASS_DEFAULTS := {"fighter": FIGHTER_STATS, "fighter_2d": FIGHTER_STATS, "char02": FIGHTER_STATS}

var class_id: String = "fighter"
var base_stats: Dictionary = FIGHTER_STATS.duplicate(true)
var attributes: Dictionary = FIGHTER_STATS.duplicate(true)
var base_hp: float = 120.0
var base_atk: float = 20.0
var base_def: float = 10.0
var base_spd: float = 6.8


static func get_default_stats(cls: String, character_data: Dictionary = {}) -> Dictionary:
	var registered: Variant = character_data.get("base_attributes", {})
	if registered is Dictionary and not registered.is_empty():
		var normalized: Dictionary = {}
		var fallback: Dictionary = CLASS_DEFAULTS.get(cls, FIGHTER_STATS)
		for stat_name in STAT_KEYS:
			normalized[stat_name] = int(registered.get(stat_name, fallback.get(stat_name, 1)))
		return normalized
	return CLASS_DEFAULTS.get(cls, FIGHTER_STATS).duplicate(true)


func setup_from_class(cls: String, character_data: Dictionary = {}):
	class_id = cls
	base_stats = get_default_stats(class_id, character_data)
	var stored_stats: Dictionary = character_data.get("attributes", {})
	attributes.clear()
	for stat_name in STAT_KEYS:
		attributes[stat_name] = max(1, int(stored_stats.get(stat_name, base_stats[stat_name])))
	base_hp = float(character_data.get("base_hp", 120.0))
	base_atk = float(character_data.get("base_atk", 20.0))
	base_def = float(character_data.get("base_def", 10.0))
	base_spd = float(character_data.get("base_spd", 6.8))


func get_stat(stat_name: String) -> int:
	return int(attributes.get(stat_name, 0)) if STAT_KEYS.has(stat_name) else 0


func set_stat(stat_name: String, value: int):
	if STAT_KEYS.has(stat_name):
		attributes[stat_name] = max(1, value)


func max_hp() -> float:
	return base_hp + (get_stat("VIT") - base_stats.VIT) * 8.0


func phys_atk() -> float:
	return maxf(1.0, base_atk + (get_stat("STR") - base_stats.STR) * 2.0)


func mag_atk() -> float:
	return maxf(1.0, get_stat("INT") * 2.5 + base_stats.DEX * 0.5 + base_stats.LUK * 0.3)


func phys_def() -> float:
	return maxf(0.0, base_def)


func mag_def() -> float:
	return maxf(0.0, base_stats.VIT + base_stats.INT + base_stats.DEX * 0.5 + base_stats.LUK * 0.5)


func attack_speed() -> float:
	return maxf(0.25, 1.0 + (get_stat("DEX") - base_stats.DEX) * 0.02)


func move_speed_multiplier() -> float:
	return max(0.5, 1.0 + (get_stat("AGI") - base_stats.AGI) * 0.01)


func hit_rate() -> float:
	return 90.0


func evasion() -> float:
	return clampf(base_stats.AGI * 1.5 + base_stats.LUK * 0.5, 0.0, 75.0)


func perfect_dodge() -> float:
	return clampf(base_stats.LUK * 0.3, 0.0, 15.0)


func crit_rate() -> float:
	return clampf(get_stat("LUK") * 1.0, 0.0, 75.0)


func can_upgrade(stat_name: String) -> bool:
	return STAT_KEYS.has(stat_name) and (stat_name != "LUK" or crit_rate() < 75.0)


func cast_time_reduction() -> float:
	return clampf(base_stats.INT * 0.02 + base_stats.DEX * 0.05, 0.0, 0.8)


func hp_recovery_rate() -> float:
	return base_stats.VIT * 0.05


func carry_capacity() -> float:
	return 50.0 + base_stats.STR * 5.0
