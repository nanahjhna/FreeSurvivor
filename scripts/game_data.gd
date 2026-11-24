extends Node

# ==========================================
# GameData: Central Persistent Data Store
# ==========================================

signal data_updated()
signal currency_changed(gold: int, gems: int)
signal party_updated()
signal save_status_changed(status: String)

const SAVE_FILE_PATH = "user://freesurvivor_save.json"
const SAVE_TEMP_PATH = "user://freesurvivor_save.tmp"
const SAVE_BACKUP_PATH = "user://freesurvivor_save.backup.json"
const SAVE_SCHEMA_VERSION = 3
const FIGHTER_ID := "char01"
const CHARACTER_SKILL_DATABASE = preload("res://scripts/character_skill_database.gd")
const CHARACTER_NAME_MAX_LENGTH = 20
const DEFAULT_INVENTORY: Array[Dictionary] = [
	{
		"id": "wpn_handwraps", "type": "weapon", "name": "수련용 권갑", "grade": "N",
		"atk": 8, "def": 0, "hp": 0, "spd": 0.0, "icon": "🥊",
		"desc": "손목과 주먹을 보호하는 수련용 권갑."
	},
	{
		"id": "wpn_iron_sword", "type": "weapon", "name": "철제 장검", "grade": "N",
		"atk": 8, "def": 0, "hp": 0, "spd": 0.0, "icon": "🗡️",
		"desc": "기본적인 단단한 쇠 검."
	},
	{
		"id": "wpn_flame_blade", "type": "weapon", "name": "작열의 검", "grade": "SR",
		"atk": 25, "def": 0, "hp": 30, "spd": 0.2, "icon": "🔥",
		"desc": "화염의 기운이 깃든 명검."
	},
	{
		"id": "arm_leather", "type": "armor", "name": "가죽 갑옷", "grade": "N",
		"atk": 0, "def": 6, "hp": 25, "spd": 0.1, "icon": "🥋",
		"desc": "가볍고 질긴 기본 가죽 갑옷."
	},
	{
		"id": "arm_plate", "type": "armor", "name": "기사단 판금 갑옷", "grade": "SSR",
		"atk": 5, "def": 22, "hp": 100, "spd": -0.2, "icon": "🛡️",
		"desc": "왕실 수호 기사단의 견고한 갑옷."
	},
	{
		"id": "acc_ring_speed", "type": "accessory", "name": "바람의 반지", "grade": "R",
		"atk": 4, "def": 2, "hp": 10, "spd": 0.6, "icon": "💍",
		"desc": "착용자의 발걸음을 가볍게 합니다."
	},
	{
		"id": "mat_stone", "type": "material", "name": "장비 강화석", "count": 15,
		"icon": "💎", "desc": "캐릭터 및 장비를 성장시킬 때 쓰이는 마법 원석."
	}
]
const DEFAULT_EQUIPPED_GEAR := {
	"char01": {"weapon": null, "armor": null, "accessory": null},
	"char02": {"weapon": "wpn_iron_sword", "armor": "arm_leather", "accessory": null}
}
const DEFAULT_CHARACTER_STATS := {
	"char01": {"base_hp": 105.0, "base_atk": 18.0, "base_def": 7.0},
	"char02": {"base_hp": 120.0, "base_atk": 20.0, "base_def": 10.0}
}
const DEFAULT_CHARACTER_NAMES := {"fighter": "무도가", "fighter_2d": "화염권객", "char01": "검사", "char02": "마법사"}
const PERMANENT_STAT_UPGRADE_CONFIG := {
	"base_cost": 800,
	"growth_rate": 1.18,
	"round_to": 50
}

# -------------------------------------------------------------
# SHOP CATALOG & BESTIARY
# -------------------------------------------------------------

const SHOP_CATALOG: Dictionary = {
	"shop_spear": {
		"id": "shop_spear", "type": "weapon", "name": "은빛 창", "grade": "R",
		"atk": 16, "def": 0, "hp": 10, "spd": 0.1, "icon": "🔱", "price": 780,
		"desc": "긴 사거리와 안정적인 공격력을 갖춘 창."
	},
	"shop_robe": {
		"id": "shop_robe", "type": "armor", "name": "현자의 로브", "grade": "R",
		"atk": 3, "def": 10, "hp": 45, "spd": 0.2, "icon": "🥼", "price": 860,
		"desc": "마법의 흐름을 돕는 가벼운 로브."
	},
	"shop_charm": {
		"id": "shop_charm", "type": "accessory", "name": "행운의 부적", "grade": "R",
		"atk": 6, "def": 4, "hp": 20, "spd": 0.3, "icon": "🍀", "price": 640,
		"desc": "모험가에게 행운을 가져다주는 작은 부적."
	}
}

const SHOP_CONSUMABLES: Array[Dictionary] = [
	{"slot": 1, "name": "치유 물약", "icon": "🧪", "price": 100, "desc": "HP를 35 회복합니다."},
	{"slot": 2, "name": "화면 폭탄", "icon": "💣", "price": 260, "desc": "주변 적에게 큰 피해를 줍니다."},
	{"slot": 3, "name": "질풍 물약", "icon": "💨", "price": 180, "desc": "5초 동안 이동속도가 증가합니다."}
]

const MONSTER_BESTIARY: Dictionary = {
	"infected": {
		"name": "감염자", "icon": "🧟", "grade": "일반",
		"desc": "스테이지에 무리를 지어 나타나는 감염자."
	},
	"infected_boss": {
		"name": "거대 감염자", "icon": "🧟", "grade": "보스",
		"desc": "전투 중 일정 시간이 지나면 나타나는 거대한 감염자."
	}
}

# --- Survival run state (never persisted as permanent growth) ---
var player_level: int = 1
var player_current_xp: int = 0
var player_xp_to_next: int = 10
var player_gold: int = 1500
var player_gems: int = 100
var player_growth_currency: int = 0
var player_current_hp: float = 100.0
var survival_bonuses: Dictionary = {}
var survival_card_counts: Dictionary = {}
var survival_kills: int = 0

# --- UI / Tutorial / Meta state ---
var input_mode: String = "auto" # auto, pc, mobile
var camera_view_mode: String = "quarter"
var camera_elevation_degrees: float = 35.0
var camera_azimuth_degrees: float = 0.0
var camera_distance: float = 18.0
var tutorial_flags: Dictionary = {
	"seen_character": false,
	"seen_party": false,
	"seen_inventory": false,
	"seen_skill": false,
	"first_battle_done": false,
	"post_battle_pending": false
}
var monster_kill_counts: Dictionary = {}

# --- Stat Multipliers (Applied in combat) ---
var attack_damage_mult: float = 1.0
var attack_speed_mult: float = 1.0
var move_speed_mult: float = 1.0
var max_hp_bonus: float = 0.0

# --- Combat Skill Cooldowns (Base Seconds) ---
var skill_cooldowns: Dictionary = {
	"q": 2.5,
	"w": 4.5,
	"e": 3.5,
	"r": 8.0
}

# --- Skill Progression ---
var skill_levels: Dictionary = {
	"q": 1,
	"w": 1,
	"e": 1,
	"r": 1
}
var skill_loadout: Dictionary = CHARACTER_SKILL_DATABASE.get_default_loadout(FIGHTER_ID)
var skill_meta: Dictionary = CHARACTER_SKILL_DATABASE.get_skill_set(FIGHTER_ID)

# --- Consumable Items Stock ---
var item_counts: Dictionary = {
	1: 3, # Potion (Heal 35)
	2: 1, # Screen Bomb (80 Damage)
	3: 2  # Speed Boost (1.5x Speed for 5s)
}

# Character creation reads the playable classes from this catalog.
var characters: Dictionary = {
	"char02": {
		"id": "char02", "name": "마법사", "title": "원소 술사", "role": "마법사",
		"grade": "R", "icon": "⚔️", "color": Color(0.3, 0.52, 0.72), "unlocked": true,
		"model_scene": "res://assets/char/char02/char02.glb", "model_scale": Vector3.ONE, "animation_profile": "char02",
		"base_attributes": {"STR": 7, "AGI": 8, "VIT": 5, "INT": 3, "DEX": 6, "LUK": 4},
		"base_hp": 112.0, "base_atk": 21.0, "base_def": 8.0, "base_spd": 7.2,
		"signature_skill": "원소 폭발", "weapon_name": "지팡이", "combat_style": "원소 마법과 광역 공격",
		"appearance": "char02", "desc": "원소 마법을 사용하는 마법사."
	},
	"char01": {
		"id": "char01", "name": "검사", "title": "황야의 검사", "role": "검사",
		"grade": "R", "icon": "⚔️", "color": Color(0.35, 0.66, 0.39), "unlocked": true,
		"model_scene": "res://assets/char/char01/char01.glb", "model_scale": Vector3.ONE, "animation_profile": "swordsman",
		"base_attributes": {"STR": 4, "AGI": 8, "VIT": 4, "INT": 3, "DEX": 9, "LUK": 5},
		"base_hp": 105.0, "base_atk": 18.0, "base_def": 7.0, "base_spd": 7.4,
		"signature_skill": "검기 난무", "weapon_name": "검", "combat_style": "근접 검술",
		"desc": "char01 모델을 사용하는 검사."
	},
}

var party_slots: Array[String] = [FIGHTER_ID]
var leader_index: int = 0

# --- Inventory & Equipment ---
var inventory: Array[Dictionary] = DEFAULT_INVENTORY.duplicate(true)

# Character equipped slots: { char_id: { "weapon": null, "armor": null, "accessory": null } }
var equipped_gear: Dictionary = DEFAULT_EQUIPPED_GEAR.duplicate(true)

# --- Stage Database ---
var stages: Dictionary = {
	"stage_1": {
		"id": "stage_1",
		"name": "평화로운 초원 외곽",
		"chapter": "제 1장 : 모험의 서막",
		"level_req": 1,
		"difficulty": "★☆☆☆☆",
		"desc": "마을 북쪽 성문 밖 초원에 몬스터들이 출몰하기 시작했습니다. 성문 밖으로 나가 침략을 저지하세요.",
		"monster_types": ["감염자", "거대 감염자 (보스)"],
		"rewards": {"gold": 400, "xp": 60, "items": ["강화석 x2", "치유 물약 x2"]},
		"scene": "res://scenes/stages/stage_grassland.tscn",
		"cleared": false
	},
	"stage_2": {
		"id": "stage_2",
		"name": "어둠의 안개 숲",
		"chapter": "제 2장 : 음산한 숲길",
		"level_req": 5,
		"difficulty": "★★★☆☆",
		"desc": "짙은 안개 속에서 고대의 언데드들이 끝없이 몰려옵니다. 강력한 화력과 방어 전략이 요구됩니다.",
		"monster_types": ["감염자", "거대 감염자 (보스)"],
		"rewards": {"gold": 900, "xp": 140, "items": ["강화석 x5", "폭탄 x2", "작열의 검"]},
		"scene": "res://scenes/stages/stage_grassland.tscn",
		"cleared": false
	},
	"stage_3": {
		"id": "stage_3",
		"name": "망자의 지하 묘지",
		"chapter": "제 3장 : 심연의 군주",
		"level_req": 10,
		"difficulty": "★★★★★",
		"desc": "봉인된 심연의 문에서 쏟아져 나오는 몬스터 군단. 수련한 무공으로 군단을 돌파하세요.",
		"monster_types": ["감염자", "거대 감염자 (보스)"],
		"rewards": {"gold": 2500, "xp": 350, "items": ["기사단 판금 갑옷", "다이아몬드 x50"]},
		"scene": "res://scenes/stages/stage_grassland.tscn",
		"cleared": false
	}
}

var current_selected_stage_id: String = "stage_1"

# --- In-Game Roguelite Upgrade Pool ---
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
		"description": "최대 HP가 30 증가하고 체력을 30 회복합니다.",
		"type": "hp",
		"value": 30.0
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

# --- Quests & Achievements ---
var quests: Array[Dictionary] = [
	{"id": "q_first_battle", "title": "첫 출격 준비", "desc": "전투 스테이지에 1회 출격하여 몬스터 10마리 처치", "target": 10, "current": 0, "reward_gold": 300, "reward_gems": 20, "claimed": false},
	{"id": "q_slay_50", "title": "몬스터 사냥꾼", "desc": "누적 몬스터 50마리 처치", "target": 50, "current": 0, "reward_gold": 800, "reward_gems": 40, "claimed": false},
	{"id": "q_upgrade_char", "title": "성장의 첫걸음", "desc": "캐릭터 1회 레벨업 진행하기", "target": 1, "current": 0, "reward_gold": 500, "reward_gems": 30, "claimed": false},
	{"id": "q_reach_time", "title": "생존의 달인", "desc": "전투에서 2분 이상 생존하기", "target": 120, "current": 0, "reward_gold": 1000, "reward_gems": 50, "claimed": false}
]

# --- Last Battle Summary Cache ---
var last_battle_result: Dictionary = {
	"won": false,
	"time": 0.0,
	"kills": 0,
	"survival_level": 1,
	"gold_earned": 0,
	"growth_currency_earned": 0,
	"items_earned": []
}

# --- Diablo-style character profiles ---
# Slots only reference IDs. Each profile owns a complete snapshot of the legacy
# runtime state so the existing combat/growth/UI systems can continue to use the
# same GameData fields without leaking data between characters.
var character_slot_manager: CharacterSlotManager = CharacterSlotManager.new()
var character_profiles: Dictionary = {}
var last_selected_character_id: String = ""
var active_character_id: String = ""
var _default_runtime_template: Dictionary = {}
var _profile_playtime_accumulator: float = 0.0
var _save_in_progress := false
var _direct_growth_migration_pending := false

func _ready():
	_migrate_character_attributes()
	_migrate_direct_gold_growth()
	_migrate_skill_loadout(skill_loadout)
	_ensure_character_equipment_entries()
	_set_character_skill_set(get_leader_id())
	_default_runtime_template = _serialize_runtime_state()
	add_child(character_slot_manager)
	_direct_growth_migration_pending = false
	var loaded_existing_save := load_from_disk()
	_migrate_character_attributes()
	_migrate_direct_gold_growth()
	_migrate_skill_loadout(skill_loadout)
	_ensure_character_equipment_entries()
	recalculate_party_stats()
	if loaded_existing_save and _direct_growth_migration_pending:
		call_deferred("save_to_disk")

func _process(delta: float):
	if active_character_id.is_empty() or not character_profiles.has(active_character_id):
		return
	if not is_instance_valid(GameManager):
		return
	if GameManager.current_location not in [GameManager.Location.LOBBY, GameManager.Location.BATTLE, GameManager.Location.CARD_DECK]:
		return
	_profile_playtime_accumulator += delta
	if _profile_playtime_accumulator >= 1.0:
		var whole_seconds := int(_profile_playtime_accumulator)
		_profile_playtime_accumulator -= whole_seconds
		var profile: Dictionary = character_profiles[active_character_id]
		profile["play_time_seconds"] = int(profile.get("play_time_seconds", 0)) + whole_seconds

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not active_character_id.is_empty():
		save_to_disk()

func _migrate_character_attributes():
	for char_id in characters:
		var character: Dictionary = characters[char_id]
		var defaults := StatManager.get_default_stats(str(char_id), character)
		var attributes: Dictionary = character.get("attributes", {})
		for stat_name in StatManager.STAT_KEYS:
			attributes[stat_name] = max(1, int(attributes.get(stat_name, defaults[stat_name])))
		character["attributes"] = attributes
		character["stat_points"] = max(0, int(character.get("stat_points", 0)))
		character["stat_points_spent"] = max(0, int(character.get("stat_points_spent", 0)))
		# Legacy character levels granted raw base stats. Convert each old level
		# into one unspent permanent attribute point exactly once.
		if not bool(character.get("growth_migration_v2", false)):
			character["stat_points"] += max(0, int(character.get("level", 1)) - 1)
			character["growth_migration_v2"] = true
		character["level"] = 1

func _migrate_direct_gold_growth():
	for char_id in characters:
		var character: Dictionary = characters[char_id]
		if bool(character.get("direct_gold_growth_migration_v3", false)):
			continue
		var unused_points := maxi(0, int(character.get("stat_points", 0)))
		var historical_spent := maxi(0, int(character.get("stat_points_spent", 0)))
		var legacy_point_value := 100 + floori(float(historical_spent) / 12.0) * 100
		if unused_points > 0:
			player_gold += unused_points * legacy_point_value
		character["stat_points"] = 0
		var defaults := StatManager.get_default_stats(str(char_id), character)
		var attributes: Dictionary = character.get("attributes", defaults)
		var total_upgrades := 0
		for stat_name in StatManager.STAT_KEYS:
			total_upgrades += maxi(0, int(attributes.get(stat_name, defaults[stat_name])) - int(defaults[stat_name]))
		character["stat_points_spent"] = total_upgrades
		character["direct_gold_growth_migration_v3"] = true
		_direct_growth_migration_pending = true

# -------------------------------------------------------------
# ACTIVE CHARACTER STATS
# -------------------------------------------------------------

func get_party_combat_power() -> int:
	var class_id := get_leader_id()
	var character: Dictionary = characters[class_id]
	var stats := get_character_stat_manager(class_id)
	var power := int(character.base_hp * 0.5 + character.base_atk * 3.0 + character.base_def * 2.0)
	power += int(character_stat_delta(stats, class_id) * 10.0)
	for item_id in equipped_gear.get(class_id, {}).values():
		var item := _get_inventory_item(str(item_id))
		power += int(item.get("hp", 0) * 0.5 + item.get("atk", 0) * 3 + item.get("def", 0) * 2)
	return power

func recalculate_party_stats():
	max_hp_bonus = 0.0
	attack_damage_mult = 1.0
	for item_id in equipped_gear.get(get_leader_id(), {}).values():
		var item := _get_inventory_item(str(item_id))
		max_hp_bonus += float(item.get("hp", 0))
		attack_damage_mult += float(item.get("atk", 0)) / 100.0
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("refresh_persistent_stats"):
		player.refresh_persistent_stats()

func character_stat_delta(stats: StatManager, class_id: String) -> float:
	var defaults := StatManager.get_default_stats(class_id, characters.get(class_id, {}))
	var total := 0.0
	for stat_name in StatManager.STAT_KEYS:
		total += max(0, stats.get_stat(stat_name) - int(defaults[stat_name]))
	return total

func _get_inventory_item(item_id: String) -> Dictionary:
	for item in inventory:
		if item.get("id", "") == item_id:
			return item
	return {}

func set_party_member(_slot_idx: int, _char_id: String) -> bool:
	return false

func get_direct_stat_upgrade_cost(char_id: String, stat_name: String) -> int:
	if not characters.has(char_id) or not StatManager.STAT_KEYS.has(stat_name):
		return 0
	var stats := get_character_stat_manager(char_id)
	var defaults := StatManager.get_default_stats(char_id, characters.get(char_id, {}))
	var upgrade_count := maxi(0, stats.get_stat(stat_name) - int(defaults[stat_name]))
	var base_cost := int(PERMANENT_STAT_UPGRADE_CONFIG.base_cost)
	var growth_rate := float(PERMANENT_STAT_UPGRADE_CONFIG.growth_rate)
	var round_to := int(PERMANENT_STAT_UPGRADE_CONFIG.round_to)
	var raw_cost := float(base_cost) * pow(growth_rate, upgrade_count)
	return ceili(raw_cost / float(round_to)) * round_to

func upgrade_character_stat_with_gold(char_id: String, stat_name: String) -> bool:
	if not characters.has(char_id) or not StatManager.STAT_KEYS.has(stat_name):
		return false
	var cost := get_direct_stat_upgrade_cost(char_id, stat_name)
	if cost <= 0 or player_gold < cost:
		return false
	var character: Dictionary = characters[char_id]
	var attributes: Dictionary = character.get("attributes", StatManager.get_default_stats(char_id, character)).duplicate(true)
	player_gold -= cost
	attributes[stat_name] = int(attributes.get(stat_name, 1)) + 1
	character["attributes"] = attributes
	character["stat_points"] = 0
	character["stat_points_spent"] = int(character.get("stat_points_spent", 0)) + 1
	_update_quest_progress("q_upgrade_char", 1)
	recalculate_party_stats()
	currency_changed.emit(player_gold, player_gems)
	data_updated.emit()
	save_to_disk()
	return true

func create_selected_character(char_id: String, character_name: String) -> bool:
	var clean_name := character_name.strip_edges()
	if not characters.has(char_id) or not characters[char_id].get("unlocked", false):
		return false
	if not PlayerManager.has_model_definition(char_id) or not CHARACTER_SKILL_DATABASE.has_skill_assignment(char_id):
		return false
	if clean_name.is_empty() or clean_name.length() > 20:
		return false
	var party_index := party_slots.find(char_id)
	if party_index < 0:
		return false
	characters[char_id]["name"] = clean_name
	leader_index = party_index
	player_current_hp = get_max_player_hp()
	recalculate_party_stats()
	party_updated.emit()
	data_updated.emit()
	save_to_disk()
	return true

func get_character_stat_manager(char_id: String) -> StatManager:
	var stats := StatManager.new()
	if characters.has(char_id):
		stats.setup_from_class(char_id, characters[char_id])
	return stats


func _ensure_character_equipment_entries() -> void:
	for character_id in characters:
		if equipped_gear.has(character_id):
			continue
		var default_gear: Dictionary = {"weapon": null, "armor": null, "accessory": null}
		var starting_gear: Variant = characters[character_id].get("starting_gear", {})
		if starting_gear is Dictionary:
			default_gear.merge(starting_gear, true)
		equipped_gear[character_id] = default_gear

func _set_character_skill_set(character_class_id: String):
	skill_meta = CHARACTER_SKILL_DATABASE.get_skill_set(character_class_id)
	skill_levels = CHARACTER_SKILL_DATABASE.get_default_levels(character_class_id)
	skill_loadout = CHARACTER_SKILL_DATABASE.get_default_loadout(character_class_id)
	skill_cooldowns.clear()
	for skill_id in skill_meta:
		skill_cooldowns[skill_id] = float(skill_meta[skill_id].get("base_cd", 1.0))

func level_up_skill(skill_key: String) -> bool:
	if not skill_levels.has(skill_key) or not skill_meta.get(skill_key, {}).has("cost_base"):
		return false
	var cur_lvl = skill_levels[skill_key]
	if cur_lvl >= 10:
		return false

	var meta = skill_meta[skill_key]
	var cost = meta.cost_base * cur_lvl
	if player_gold < cost:
		return false

	player_gold -= cost
	skill_levels[skill_key] = cur_lvl + 1

	# update cooldown in dictionary
	var new_cd = max(0.5, meta.base_cd - (meta.cd_step * (skill_levels[skill_key] - 1)))
	skill_cooldowns[skill_key] = new_cd

	currency_changed.emit(player_gold, player_gems)
	data_updated.emit()
	save_to_disk()
	return true

func get_equipped_skill(slot: String) -> String:
	return str(skill_loadout.get(slot, ""))

func is_survival_skill_unlocked(skill_id: String) -> bool:
	return skill_meta.has(skill_id) and player_level >= int(skill_meta[skill_id].unlock_level)

func equip_skill(slot: String, skill_id: String) -> bool:
	var slots: Array[String] = ["q", "w", "e", "r", "a", "s"]
	if not slots.has(slot) or not skill_meta.has(skill_id):
		return false
	if str(skill_meta[skill_id].get("cast_type", "passive")) == "passive":
		return false
	if GameManager.current_location == GameManager.Location.BATTLE:
		return false
	if get_equipped_skill(slot) == skill_id:
		return true
	var other_slot := ""
	for equipped_slot in slots:
		if equipped_slot != slot and get_equipped_skill(equipped_slot) == skill_id:
			other_slot = equipped_slot
			break
	if other_slot != "":
		skill_loadout[other_slot] = get_equipped_skill(slot)
	skill_loadout[slot] = skill_id
	data_updated.emit()
	save_to_disk()
	return true

func _migrate_skill_loadout(saved_loadout: Dictionary):
	var slots: Array[String] = ["q", "w", "e", "r", "a", "s"]
	var defaults := CHARACTER_SKILL_DATABASE.get_default_loadout(get_leader_id())
	var migrated: Dictionary = {}
	var assigned: Dictionary = {}
	for slot in slots:
		var skill_id := str(saved_loadout.get(slot, ""))
		if skill_meta.has(skill_id) and str(skill_meta[skill_id].get("cast_type", "passive")) != "passive" and not assigned.has(skill_id):
			migrated[slot] = skill_id
			assigned[skill_id] = true
	for slot in slots:
		if migrated.has(slot):
			continue
		var current_skill := str(defaults.get(slot, ""))
		if skill_meta.has(current_skill) and not assigned.has(current_skill):
			migrated[slot] = current_skill
			assigned[current_skill] = true
			continue
		for skill_id in skill_meta:
			if str(skill_meta[skill_id].get("cast_type", "passive")) != "passive" and not assigned.has(skill_id):
				migrated[slot] = skill_id
				assigned[skill_id] = true
				break
	skill_loadout = migrated

func get_skill_damage_multiplier(skill_key: String) -> float:
	if not skill_meta.has(skill_key):
		return 1.0
	var meta = skill_meta[skill_key]
	var level = skill_levels.get(skill_key, 1)
	var current_ratio = meta.base_dmg_ratio + meta.dmg_step * (level - 1)
	return current_ratio

# -------------------------------------------------------------
# BATTLE RESULT & REWARDS
# -------------------------------------------------------------

func record_battle_result(won: bool, time_sec: float, kills: int) -> Dictionary:
	var stage = stages.get(current_selected_stage_id, stages["stage_1"])
	var first_clear = won and not stage.get("cleared", false)

	var base_gold = int(round((kills * 12 + int(time_sec * 3.0)) * (1.0 + get_survival_bonus("gold"))))
	var growth_earned: int = int(kills / 10.0) + int(time_sec / 60.0)
	var earned_items: Array[String] = []
	var earned_cards: Array[String] = []

	if won:
		var reward_id: String = CardDatabase.all_ids().pick_random()
		GameManager.card_manager.add_card(reward_id)
		earned_cards.append(str(CardDatabase.get_card(reward_id).name))
		growth_earned += 1
		if first_clear:
			base_gold += stage.rewards.gold
			growth_earned += 2
			for itm in stage.rewards.items:
				earned_items.append(str(itm))
				_grant_reward_item(str(itm))
		stage["cleared"] = true
	else:
		# Partial rewards
		base_gold += int(stage.rewards.gold * 0.3)
		earned_items.append("소형 치유 물약 x1")
		_grant_reward_item("소형 치유 물약 x1")

	# Give consumables if drops occurred
	if kills >= 5:
		item_counts[1] = item_counts.get(1, 0) + 1
		earned_items.append("체력 물약 x1")
	if kills >= 15:
		item_counts[2] = item_counts.get(2, 0) + 1
		earned_items.append("폭탄 x1")

	# Apply currencies
	player_gold += base_gold
	player_growth_currency += growth_earned

	# Update Quests
	_update_quest_progress("q_first_battle", kills)
	_update_quest_progress("q_slay_50", kills)
	if int(time_sec) >= 120:
		_update_quest_progress("q_reach_time", int(time_sec))

	var previous_best_time := 0.0
	var previous_best_level := 1
	if not active_character_id.is_empty() and character_profiles.has(active_character_id):
		var active_profile: Dictionary = character_profiles[active_character_id]
		previous_best_time = float(active_profile.get("best_survival_time", 0.0))
		previous_best_level = int(active_profile.get("best_survival_level", 1))
		active_profile["best_survival_time"] = max(previous_best_time, time_sec)
		active_profile["best_survival_level"] = max(previous_best_level, player_level)
	last_battle_result = {
		"won": won,
		"time": time_sec,
		"kills": kills,
		"survival_level": player_level,
		"gold_earned": base_gold,
		"growth_currency_earned": growth_earned,
		"cards_earned": earned_cards,
		"items_earned": earned_items,
		"stage_name": stage.name,
		"new_best_time": time_sec > previous_best_time,
		"new_best_level": player_level > previous_best_level
	}

	tutorial_flags["first_battle_done"] = true
	tutorial_flags["post_battle_pending"] = true

	currency_changed.emit(player_gold, player_gems)
	data_updated.emit()
	save_to_disk()
	return last_battle_result

func record_infinite_dungeon_result(time_sec: float, kills: int, paid_gold: int, returned_to_town: bool) -> Dictionary:
	var previous_best := 0.0
	var previous_level := 1
	if not active_character_id.is_empty() and character_profiles.has(active_character_id):
		var profile: Dictionary = character_profiles[active_character_id]
		previous_best = float(profile.get("best_survival_time", 0.0))
		previous_level = int(profile.get("best_survival_level", 1))
		profile["best_survival_time"] = maxf(previous_best, time_sec)
		profile["best_survival_level"] = maxi(previous_level, player_level)
	player_gold += paid_gold
	last_battle_result = {
		"won": returned_to_town, "returned": returned_to_town, "time": time_sec,
		"kills": kills, "survival_level": player_level, "gold_earned": paid_gold,
		"gold_found": GameManager.dungeon_gold, "growth_currency_earned": 0,
		"cards_earned": [], "items_earned": [], "stage_name": "무한 던전",
		"new_best_time": time_sec > previous_best, "new_best_level": player_level > previous_level
	}
	_update_quest_progress("q_first_battle", kills)
	_update_quest_progress("q_slay_50", kills)
	currency_changed.emit(player_gold, player_gems)
	data_updated.emit()
	save_to_disk()
	return last_battle_result

func _grant_reward_item(reward: String):
	var split_at = reward.rfind(" x")
	var item_name = reward if split_at == -1 else reward.substr(0, split_at)
	var count = 1 if split_at == -1 else max(1, int(reward.substr(split_at + 2)))
	match item_name:
		"강화석":
			for item in inventory:
				if item.get("id", "") == "mat_stone":
					item["count"] = item.get("count", 0) + count
					return
		"치유 물약", "체력 물약", "소형 치유 물약":
			item_counts[1] = item_counts.get(1, 0) + count
			return
		"폭탄":
			item_counts[2] = item_counts.get(2, 0) + count
			return
		"다이아몬드":
			player_gems += count
			return
	for item in inventory:
		if item.get("name", "") == item_name:
			if item.has("count"):
				item["count"] += count
				return
			var duplicate_item = item.duplicate(true)
			duplicate_item["id"] = "%s_%d" % [item.get("id", "reward"), Time.get_ticks_msec()]
			for _copy in range(count):
				inventory.append(duplicate_item.duplicate(true))
			return
	inventory.append({
		"id": "reward_%s" % item_name,
		"type": "material",
		"name": item_name,
		"grade": "N",
		"count": count,
		"icon": "🎁",
		"desc": "전투 보상으로 획득한 아이템."
	})

func is_stage_unlocked(stage_id: String) -> bool:
	if not stages.has(stage_id):
		return false
	match stage_id:
		"stage_1":
			return true
		"stage_2":
			return stages.get("stage_1", {}).get("cleared", false)
		"stage_3":
			return stages.get("stage_2", {}).get("cleared", false)
	return false

func _add_player_xp(amount: int):
	player_current_xp += amount
	while player_current_xp >= player_xp_to_next:
		player_current_xp -= player_xp_to_next
		player_level += 1
		player_xp_to_next = int(player_xp_to_next * 1.4) + 20
		player_gems += 15 # Level up reward

func _update_quest_progress(quest_id: String, amount: int):
	for q in quests:
		if q.id == quest_id and not q.claimed:
			q.current = min(q.target, q.current + amount)

func claim_quest(quest_id: String) -> bool:
	for q in quests:
		if q.id == quest_id and not q.claimed:
			if q.current >= q.target:
				q.claimed = true
				player_gold += q.reward_gold
				player_gems += q.reward_gems
				currency_changed.emit(player_gold, player_gems)
				data_updated.emit()
				save_to_disk()
				return true
	return false

# -------------------------------------------------------------
# SHOP / INN / TUTORIAL / BESTIARY
# -------------------------------------------------------------

func get_leader_id() -> String:
	if party_slots.is_empty():
		return ""
	var idx = clampi(leader_index, 0, party_slots.size() - 1)
	return party_slots[idx]

func get_max_player_hp() -> float:
	var stats := get_character_stat_manager(get_leader_id())
	return stats.max_hp() + max_hp_bonus

func get_active_character_equipment_hp() -> float:
	var class_id := get_leader_id()
	var total := 0.0
	for item_id in equipped_gear.get(class_id, {}).values():
		var item := _get_inventory_item(str(item_id))
		total += float(item.get("hp", 0.0))
	return total

func mark_tutorial(flag: String):
	tutorial_flags[flag] = true
	if flag == "seen_character":
		tutorial_flags["post_battle_pending"] = false
	save_to_disk()

func is_tutorial_done(flag: String) -> bool:
	return bool(tutorial_flags.get(flag, false))

func buy_shop_item(key: String) -> Dictionary:
	if key.begins_with("consumable:"):
		var slot := int(key.get_slice(":", 1))
		var entry: Dictionary = {}
		for c in SHOP_CONSUMABLES:
			if int(c.get("slot", -1)) == slot:
				entry = c
				break
		if entry.is_empty():
			return {"ok": false, "message": "판매하지 않는 상품입니다."}
		var price := int(entry.get("price", 0))
		if player_gold < price:
			return {
				"ok": false,
				"message": "골드가 부족합니다. (필요 %d / 보유 %d)" % [price, player_gold]
			}
		player_gold -= price
		item_counts[slot] = int(item_counts.get(slot, 0)) + 1
		currency_changed.emit(player_gold, player_gems)
		data_updated.emit()
		save_to_disk()
		return {
			"ok": true,
			"message": "%s을(를) 구매했습니다." % entry.get("name", "아이템"),
			"reward": ["%s x1" % entry.get("name", "아이템")]
		}

	var gear: Dictionary = SHOP_CATALOG.get(key, {})
	if gear.is_empty():
		return {"ok": false, "message": "판매하지 않는 상품입니다."}
	for item in inventory:
		if item.get("id", "") == key:
			return {"ok": false, "message": "이미 보유 중인 장비입니다."}
	var price := int(gear.get("price", 0))
	if player_gold < price:
		return {
			"ok": false,
			"message": "골드가 부족합니다. (필요 %d / 보유 %d)" % [price, player_gold]
		}
	player_gold -= price
	var bought := gear.duplicate(true)
	bought.erase("price")
	inventory.append(bought)
	currency_changed.emit(player_gold, player_gems)
	data_updated.emit()
	save_to_disk()
	return {
		"ok": true,
		"message": "%s을(를) 구매했습니다." % gear.get("name", "장비"),
		"reward": ["%s x1" % gear.get("name", "장비")]
	}

func rest_at_inn() -> Dictionary:
	var cost := 50
	if player_gold < cost:
		return {
			"ok": false,
			"message": "골드가 부족합니다. (필요 %d / 보유 %d)" % [cost, player_gold]
		}
	player_gold -= cost
	player_current_hp = get_max_player_hp()
	currency_changed.emit(player_gold, player_gems)
	data_updated.emit()
	save_to_disk()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("heal"):
		player.call("heal", 99999.0)
	return {"ok": true, "message": "여관에서 휴식하여 체력을 모두 회복했습니다."}

func record_monster_kill(monster_id: String):
	monster_kill_counts[monster_id] = int(monster_kill_counts.get(monster_id, 0)) + 1

func get_bestiary_entry(monster_id: String) -> Dictionary:
	return MONSTER_BESTIARY.get(monster_id, {})

func is_bestiary_unlocked(monster_id: String) -> bool:
	return int(monster_kill_counts.get(monster_id, 0)) > 0


# -------------------------------------------------------------
# UPGRADE CARDS (ROGUELITE)
# -------------------------------------------------------------

func begin_survival_run():
	player_level = 1
	player_current_xp = 0
	player_xp_to_next = 10
	attack_damage_mult = 1.0
	attack_speed_mult = 1.0
	move_speed_mult = 1.0
	max_hp_bonus = 0.0
	survival_bonuses.clear()
	survival_card_counts.clear()
	survival_kills = 0
	for skill_key in skill_meta:
		var meta = skill_meta[skill_key]
		skill_levels[skill_key] = 1
		skill_cooldowns[skill_key] = float(meta.base_cd)
	recalculate_party_stats()

func end_survival_run():
	begin_survival_run()
	player_current_hp = get_max_player_hp()

func reset_data():
	# Compatibility entry point used by older scenes.
	begin_survival_run()

func get_random_upgrades(count: int = 3, run_deck: Array = []) -> Array[Dictionary]:
	var offer_count := count + int(get_survival_bonus("extra_offer"))
	return SurvivalCardDatabase.draw_offers(offer_count, survival_card_counts, get_survival_bonus("rare_weight"))

func get_survival_bonus(stat: String) -> float:
	return float(survival_bonuses.get(stat, 0.0))

func apply_upgrade(upgrade: Dictionary):
	var player = get_tree().get_first_node_in_group("player")
	match upgrade.get("type", ""):
		"survival_bonus":
			var id := str(upgrade.get("id", ""))
			var stat := str(upgrade.get("stat", "damage"))
			var value := float(upgrade.get("value", 0.0))
			survival_card_counts[id] = int(survival_card_counts.get(id, 0)) + 1
			survival_bonuses[stat] = get_survival_bonus(stat) + value
			if stat == "damage_reckless":
				survival_bonuses["damage_reduction"] = get_survival_bonus("damage_reduction") - 0.15
			if stat in ["last_stand", "revive"]:
				survival_bonuses[stat] = 1.0
			if stat == "max_hp_percent" and player and player.has_method("refresh_persistent_stats"):
				player.refresh_persistent_stats()
			if stat == "cooldown":
				for skill in skill_cooldowns:
					skill_cooldowns[skill] = maxf(0.5, float(skill_cooldowns[skill]) * (1.0 - value))
			if stat == "instant_xp" and player and player.has_method("gain_xp"):
				player.gain_xp(maxi(1, int(player.xp_to_next_level * value)))
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
			if player:
				player.refresh_persistent_stats()
		"on_hit":
			if player:
				var id := str(upgrade.id)
				player.card_hit_bonuses[id] = float(player.card_hit_bonuses.get(id, 0.0)) + float(upgrade.value)
		"sp_regen":
			if player:
				player.card_sp_regen += float(upgrade.value)
		"all_cd":
			for skill in skill_cooldowns:
				skill_cooldowns[skill] = maxf(0.5, float(skill_cooldowns[skill]) * (1.0 - float(upgrade.value)))
		"cd":
			var skill = upgrade.get("skill", "")
			var red = upgrade.get("value", 0.0)
			if skill_cooldowns.has(skill):
				skill_cooldowns[skill] = max(0.5, skill_cooldowns[skill] * (1.0 - red))

# -------------------------------------------------------------
# SAVE & LOAD
# -------------------------------------------------------------

func _serialize_runtime_state() -> Dictionary:
	var state := {
		"player_gold": player_gold,
		"player_gems": player_gems,
		"player_growth_currency": player_growth_currency,
		"growth_system_version": 2,
		"class_id": get_leader_id(),
		"skill_loadout": skill_loadout,
		"item_counts": item_counts,
		"characters": characters,
		"inventory": inventory,
		"equipped_gear": equipped_gear,
		"quests": quests,
		"stages": stages,
		"current_selected_stage_id": current_selected_stage_id,
		"last_battle_result": last_battle_result,
		"input_mode": input_mode,
		"camera_view_mode": camera_view_mode,
		"camera_elevation_degrees": camera_elevation_degrees,
		"camera_azimuth_degrees": camera_azimuth_degrees,
		"camera_distance": camera_distance,
		"tutorial_flags": tutorial_flags,
		"monster_kill_counts": monster_kill_counts
	}
	var manager := get_node_or_null("/root/GameManager")
	if manager != null:
		var card_manager_value: Variant = manager.get("card_manager")
		if card_manager_value is CardManager:
			state["cards"] = {
				"owned": card_manager_value.owned.duplicate(true),
				"equipped": card_manager_value.equipped.duplicate(true)
			}
		var deck_manager_value: Variant = manager.get("deck_manager")
		if deck_manager_value is DeckManager:
			state["deck"] = {
				"cards": deck_manager_value.deck.duplicate(true),
				"hand": deck_manager_value.hand.duplicate(true),
				"name": deck_manager_value.deck_name
			}
	return state.duplicate(true)

func _apply_runtime_state(data: Dictionary):
	begin_survival_run()
	player_gold = int(data.get("player_gold", player_gold))
	player_gems = int(data.get("player_gems", player_gems))
	player_growth_currency = int(data.get("player_growth_currency", 0))
	if int(data.get("growth_system_version", 1)) < 2:
		# Legacy account level no longer grants combat power. Preserve its earned
		# value as growth currency that can be exchanged for attribute points.
		player_growth_currency += max(0, int(data.get("player_level", 1)) - 1)
	player_current_hp = get_max_player_hp()

	party_slots.assign([str(data.get("class_id", FIGHTER_ID))])
	leader_index = 0
	_set_character_skill_set(get_leader_id())

	if data.has("skill_loadout") and data["skill_loadout"] is Dictionary:
		skill_loadout = data["skill_loadout"].duplicate(true)

	if data.has("item_counts") and data["item_counts"] is Dictionary:
		item_counts.clear()
		for key in data["item_counts"]:
			item_counts[int(key)] = int(data["item_counts"][key])

	if data.has("characters") and data["characters"] is Dictionary:
		for character_id in data["characters"]:
			if characters.has(character_id) and data["characters"][character_id] is Dictionary:
				if not data["characters"][character_id].has("growth_migration_v2"):
					characters[character_id].erase("growth_migration_v2")
				if not data["characters"][character_id].has("direct_gold_growth_migration_v3"):
					characters[character_id].erase("direct_gold_growth_migration_v3")
				characters[character_id].merge(data["characters"][character_id], true)
				if str(character_id) == "char01":
					_refresh_swordsman_identity(characters[character_id])
	if data.has("inventory") and data["inventory"] is Array:
		inventory = Array(data["inventory"], TYPE_DICTIONARY, &"", null)
	equipped_gear = DEFAULT_EQUIPPED_GEAR.duplicate(true)
	if data.has("equipped_gear") and data["equipped_gear"] is Dictionary:
		for character_id in data["equipped_gear"]:
			if data["equipped_gear"][character_id] is Dictionary:
				equipped_gear[character_id] = data["equipped_gear"][character_id].duplicate(true)
	_ensure_character_equipment_entries()

	if data.has("quests") and data["quests"] is Array:
		var loaded_quests: Array = data["quests"]
		for i in range(min(quests.size(), loaded_quests.size())):
			quests[i]["current"] = int(loaded_quests[i].get("current", 0))
			quests[i]["claimed"] = bool(loaded_quests[i].get("claimed", false))
	if data.has("stages") and data["stages"] is Dictionary:
		for stage_id in data["stages"]:
			if stages.has(stage_id):
				stages[stage_id]["cleared"] = bool(data["stages"][stage_id].get("cleared", false))
	current_selected_stage_id = str(data.get("current_selected_stage_id", current_selected_stage_id))
	if data.has("last_battle_result") and data["last_battle_result"] is Dictionary:
		last_battle_result = data["last_battle_result"].duplicate(true)

	input_mode = str(data.get("input_mode", input_mode))
	camera_view_mode = str(data.get("camera_view_mode", camera_view_mode))
	camera_elevation_degrees = clampf(float(data.get("camera_elevation_degrees", camera_elevation_degrees)), 20.0, 75.0)
	camera_azimuth_degrees = wrapf(float(data.get("camera_azimuth_degrees", camera_azimuth_degrees)), -180.0, 180.0)
	camera_distance = clampf(float(data.get("camera_distance", camera_distance)), 8.0, 24.0)
	if data.has("tutorial_flags") and data["tutorial_flags"] is Dictionary:
		for key in data["tutorial_flags"]:
			tutorial_flags[key] = data["tutorial_flags"][key]
	if data.has("monster_kill_counts") and data["monster_kill_counts"] is Dictionary:
		monster_kill_counts = data["monster_kill_counts"].duplicate(true)
	_apply_auxiliary_profile_state(data)
	_migrate_character_attributes()
	_migrate_direct_gold_growth()
	_migrate_skill_loadout(skill_loadout)
	recalculate_party_stats()

func _apply_auxiliary_profile_state(data: Dictionary):
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		return
	var card_manager_value: Variant = manager.get("card_manager")
	var card_state: Dictionary = data.get("cards", {})
	if card_manager_value is CardManager:
		card_manager_value.owned = card_state.get("owned", {}).duplicate(true)
		card_manager_value.equipped = card_state.get("equipped", []).duplicate(true)
	var deck_manager_value: Variant = manager.get("deck_manager")
	var deck_state: Dictionary = data.get("deck", {})
	if deck_manager_value is DeckManager:
		deck_manager_value.deck = deck_state.get("cards", []).duplicate(true)
		deck_manager_value.hand = deck_state.get("hand", []).duplicate(true)
		deck_manager_value.deck_name = str(deck_state.get("name", "기본 덱"))
	if card_manager_value is CardManager and deck_manager_value is DeckManager:
		card_manager_value.ensure_starter_collection()
		deck_manager_value.ensure_starter_deck(card_manager_value.owned)

func restore_active_auxiliary_state():
	if active_character_id.is_empty() or not character_profiles.has(active_character_id):
		return
	var profile: Dictionary = character_profiles[active_character_id]
	_apply_auxiliary_profile_state(profile.get("state", {}))

func get_character_profile(character_id: String) -> Dictionary:
	if not character_profiles.has(character_id):
		return {}
	return character_profiles[character_id]

func get_profile_at_slot(slot_index: int) -> Dictionary:
	var character_id: Variant = character_slot_manager.get_slot(slot_index)
	if character_id == null:
		return {}
	return get_character_profile(str(character_id))

func get_character_slot_count() -> int:
	return character_slot_manager.get_slot_count()

func find_empty_character_slot() -> int:
	return character_slot_manager.find_empty_slot()

func get_profile_class_data(profile: Dictionary) -> Dictionary:
	var class_id := str(profile.get("class_id", FIGHTER_ID))
	var state: Dictionary = profile.get("state", {})
	var state_characters: Dictionary = state.get("characters", {})
	if state_characters.has(class_id) and state_characters[class_id] is Dictionary:
		var saved_character: Dictionary = state_characters[class_id].duplicate(true)
		if class_id == "char01":
			_refresh_swordsman_identity(saved_character)
		return saved_character
	return characters.get(class_id, {})

func _refresh_swordsman_identity(character: Dictionary) -> void:
	var definition := CharacterRegistry.get_by_id("char01")
	if definition == null:
		return
	var current := definition.to_legacy_dictionary()
	for key in ["name", "title", "role", "icon", "model_scene", "model_scale", "animation_profile",
		"animation_aliases", "signature_skill", "weapon_name", "weapon_scene", "weapon_bone_name",
		"weapon_mount_position", "weapon_mount_rotation_degrees", "weapon_mount_scale", "combat_style", "desc"]:
		character[key] = current[key]

func get_profile_stat_manager(profile: Dictionary) -> StatManager:
	var stats := StatManager.new()
	var class_id := str(profile.get("class_id", FIGHTER_ID))
	stats.setup_from_class(class_id, get_profile_class_data(profile))
	return stats

func get_class_template_data(class_id: String) -> Dictionary:
	var template_characters: Dictionary = _default_runtime_template.get("characters", {})
	if template_characters.has(class_id):
		return template_characters[class_id]
	return characters.get(class_id, {})

func get_class_template_stat_manager(class_id: String) -> StatManager:
	var stats := StatManager.new()
	stats.setup_from_class(class_id, get_class_template_data(class_id))
	return stats

func get_character_name_error(candidate: String, _ignored_character_id: String = "") -> String:
	var clean_name := candidate.strip_edges()
	if clean_name.is_empty():
		return "이름을 입력해 주세요."
	if clean_name.length() > CHARACTER_NAME_MAX_LENGTH:
		return "이름은 %d자 이하로 입력해 주세요." % CHARACTER_NAME_MAX_LENGTH
	var allowed_name := RegEx.new()
	if allowed_name.compile("^[\\p{L}\\p{N}_ -]+$") != OK or allowed_name.search(clean_name) == null:
		return "한글, 영문, 숫자, 공백, -, _ 문자만 사용할 수 있습니다."
	return ""

func create_character_profile(slot_index: int, class_id: String, character_name: String = "") -> String:
	if slot_index < 0 or slot_index >= character_slot_manager.get_slot_count():
		return ""
	if character_slot_manager.get_slot(slot_index) != null:
		return ""
	if not characters.has(class_id) or not bool(characters[class_id].get("unlocked", false)):
		return ""
	if not PlayerManager.has_model_definition(class_id):
		push_warning("캐릭터 모델이 등록되지 않았습니다: %s" % class_id)
		return ""
	if not CHARACTER_SKILL_DATABASE.has_skill_assignment(class_id):
		push_warning("캐릭터 스킬 배정이 등록되지 않았습니다: %s" % class_id)
		return ""
	var clean_name := character_name.strip_edges()
	if clean_name.is_empty():
		var template := get_class_template_data(class_id)
		clean_name = str(template.get("name", template.get("role", "무도가")))
	_commit_active_profile()
	_apply_runtime_state(_default_runtime_template.duplicate(true))
	party_slots.assign([class_id])
	_set_character_skill_set(class_id)
	_ensure_character_equipment_entries()
	characters[class_id]["name"] = clean_name
	player_current_hp = get_max_player_hp()
	var character_id := _generate_character_id()
	var now := Time.get_datetime_string_from_system(false, true)
	var profile := {
		"id": character_id,
		"name": clean_name,
		"class_id": class_id,
		"created_at": now,
		"last_played_at": "아직 접속하지 않음",
		"play_time_seconds": 0,
		"last_location": "마을",
		"best_survival_time": 0.0,
		"best_survival_level": 1,
		"card_dungeon_best_floor": 0,
		"card_dungeon_unlocked": true,
		"state": _serialize_runtime_state()
	}
	character_profiles[character_id] = profile
	character_slot_manager.set_slot(slot_index, character_id)
	active_character_id = character_id
	last_selected_character_id = character_id
	_profile_playtime_accumulator = 0.0
	save_to_disk()
	data_updated.emit()
	return character_id

func select_character_profile(character_id: String) -> bool:
	if not character_profiles.has(character_id):
		return false
	last_selected_character_id = character_id
	return save_to_disk()

func activate_character_profile(character_id: String) -> bool:
	if not character_profiles.has(character_id):
		return false
	if not active_character_id.is_empty() and active_character_id != character_id:
		_commit_active_profile()
	var profile: Dictionary = character_profiles[character_id]
	var state: Dictionary = profile.get("state", {})
	if state.is_empty():
		return false
	_apply_runtime_state(state.duplicate(true))
	var class_id := str(profile.get("class_id", FIGHTER_ID))
	party_slots.assign([class_id])
	_set_character_skill_set(class_id)
	active_character_id = character_id
	last_selected_character_id = character_id
	profile["last_played_at"] = Time.get_datetime_string_from_system(false, true)
	profile["last_location"] = "마을"
	_profile_playtime_accumulator = 0.0
	player_current_hp = get_max_player_hp()
	recalculate_party_stats()
	data_updated.emit()
	party_updated.emit()
	save_to_disk()
	return true

func delete_character_profile(character_id: String) -> bool:
	if not character_profiles.has(character_id):
		return false
	character_slot_manager.remove_character(character_id)
	character_profiles.erase(character_id)
	if active_character_id == character_id:
		active_character_id = ""
		_profile_playtime_accumulator = 0.0
		_apply_runtime_state(_default_runtime_template.duplicate(true))
	if last_selected_character_id == character_id:
		last_selected_character_id = _get_first_slotted_character_id()
	data_updated.emit()
	return save_to_disk()

func _generate_character_id() -> String:
	var character_id := "character_%d_%06d" % [int(Time.get_unix_time_from_system()), randi_range(0, 999999)]
	while character_profiles.has(character_id):
		character_id = "character_%d_%06d" % [int(Time.get_unix_time_from_system()), randi_range(0, 999999)]
	return character_id

func _get_first_slotted_character_id() -> String:
	for slot_value in character_slot_manager.slots:
		if slot_value != null and character_profiles.has(str(slot_value)):
			return str(slot_value)
	return ""

func _commit_active_profile():
	if active_character_id.is_empty() or not character_profiles.has(active_character_id):
		return
	var profile: Dictionary = character_profiles[active_character_id]
	var class_id := str(profile.get("class_id", get_leader_id()))
	if characters.has(class_id):
		profile["name"] = str(characters[class_id].get("name", profile.get("name", "")))
	profile["state"] = _serialize_runtime_state()
	var manager := get_node_or_null("/root/GameManager")
	if manager != null:
		match int(manager.get("current_location")):
			GameManager.Location.BATTLE:
				profile["last_location"] = "전투"
			GameManager.Location.LOBBY:
				profile["last_location"] = "마을"
			GameManager.Location.CARD_DECK:
				profile["last_location"] = "카드 덱 던전"

func save_to_disk() -> bool:
	if _save_in_progress:
		return false
	_save_in_progress = true
	save_status_changed.emit("saving")
	_commit_active_profile()
	var save_dict := _serialize_runtime_state()
	save_dict["schema_version"] = SAVE_SCHEMA_VERSION
	save_dict["character_slots"] = character_slot_manager.to_array()
	save_dict["character_profiles"] = character_profiles
	save_dict["last_selected_character_id"] = last_selected_character_id
	save_dict["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var json_str := JSON.stringify(save_dict, "\t")
	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if not file:
		# Direct write fallback if temporary path cannot be opened
		file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
		if not file:
			push_error("Could not write save file (error %d)." % FileAccess.get_open_error())
			_save_in_progress = false
			save_status_changed.emit("failed")
			return false
		file.store_string(json_str)
		file.close()
		_save_in_progress = false
		save_status_changed.emit("saved")
		return true
	file.store_string(json_str)
	file.close()
	var temp_global := ProjectSettings.globalize_path(SAVE_TEMP_PATH)
	var save_global := ProjectSettings.globalize_path(SAVE_FILE_PATH)
	var backup_global := ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	if FileAccess.file_exists(SAVE_BACKUP_PATH):
		DirAccess.remove_absolute(backup_global)
		if FileAccess.file_exists(SAVE_BACKUP_PATH):
			DirAccess.remove_absolute(SAVE_BACKUP_PATH)
	if FileAccess.file_exists(SAVE_FILE_PATH):
		if DirAccess.rename_absolute(save_global, backup_global) != OK:
			DirAccess.rename_absolute(SAVE_FILE_PATH, SAVE_BACKUP_PATH)
	if DirAccess.rename_absolute(temp_global, save_global) != OK and DirAccess.rename_absolute(SAVE_TEMP_PATH, SAVE_FILE_PATH) != OK:
		# Direct write fallback if atomic rename is blocked (common in mobile scoped storage)
		var direct_file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
		if direct_file:
			direct_file.store_string(json_str)
			direct_file.close()
		DirAccess.remove_absolute(temp_global)
		DirAccess.remove_absolute(SAVE_TEMP_PATH)
	_save_in_progress = false
	save_status_changed.emit("saved")
	return true

func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	var save_data := _read_save_dictionary(SAVE_FILE_PATH)
	if save_data.is_empty() and FileAccess.file_exists(SAVE_BACKUP_PATH):
		push_warning("Primary save is invalid. Loading the protected backup.")
		save_data = _read_save_dictionary(SAVE_BACKUP_PATH)
	if save_data.is_empty():
		return false

	character_profiles.clear()
	if int(save_data.get("schema_version", 1)) >= 2 and save_data.get("character_profiles", {}) is Dictionary:
		character_profiles = save_data.get("character_profiles", {}).duplicate(true)
		for profile_id in character_profiles:
			var profile: Dictionary = character_profiles[profile_id]
			var class_id := str(profile.get("class_id", FIGHTER_ID))
			if not characters.has(class_id):
				var state: Dictionary = profile.get("state", {}).duplicate(true)
				_migrate_to_fighter(state, class_id, str(profile.get("name", "무도가")))
				profile["state"] = state
				profile["class_id"] = FIGHTER_ID
		character_slot_manager.load_slots(save_data.get("character_slots", []))
		_sanitize_character_slots()
		last_selected_character_id = str(save_data.get("last_selected_character_id", ""))
		if not character_profiles.has(last_selected_character_id):
			last_selected_character_id = _get_first_slotted_character_id()
		if not last_selected_character_id.is_empty():
			active_character_id = last_selected_character_id
			var profile: Dictionary = character_profiles[active_character_id]
			_apply_runtime_state(profile.get("state", save_data).duplicate(true))
		else:
			active_character_id = ""
			_apply_runtime_state(_default_runtime_template.duplicate(true))
	else:
		# Version 1 stored one global hero. Preserve it as the first v2 profile.
		var old_party: Array = save_data.get("party_slots", [])
		var old_index := clampi(int(save_data.get("leader_index", 0)), 0, maxi(0, old_party.size() - 1))
		var old_class := "warrior" if old_party.is_empty() else str(old_party[old_index])
		var old_hero: Dictionary = save_data.get("characters", {}).get(old_class, {})
		_migrate_to_fighter(save_data, old_class, str(old_hero.get("name", "무도가")))
		_apply_runtime_state(save_data)
		var legacy_class_id := get_leader_id()
		if not characters.has(legacy_class_id):
			legacy_class_id = FIGHTER_ID
		var legacy_name := str(characters[legacy_class_id].get("name", DEFAULT_CHARACTER_NAMES[legacy_class_id]))
		var legacy_id := _generate_character_id()
		var legacy_time := Time.get_datetime_string_from_system(false, true)
		character_profiles[legacy_id] = {
			"id": legacy_id,
			"name": legacy_name,
			"class_id": legacy_class_id,
			"created_at": legacy_time,
			"last_played_at": legacy_time,
			"play_time_seconds": 0,
			"last_location": "마을",
			"best_survival_time": 0.0,
			"best_survival_level": 1,
			"card_dungeon_best_floor": 0,
			"card_dungeon_unlocked": true,
			"state": save_data.duplicate(true)
		}
		character_slot_manager.initialize()
		character_slot_manager.set_slot(0, legacy_id)
		active_character_id = legacy_id
		last_selected_character_id = legacy_id
	return true

func _migrate_to_fighter(state: Dictionary, old_class: String, saved_name: String):
	var old_hero: Dictionary = state.get("characters", {}).get(old_class, {})
	var hero: Dictionary = _default_runtime_template.characters[FIGHTER_ID].duplicate(true)
	hero.name = saved_name
	hero.stat_points = int(old_hero.get("stat_points", 0))
	hero.stat_points_spent = int(old_hero.get("stat_points_spent", 0))
	hero.erase("direct_gold_growth_migration_v3")
	if not bool(old_hero.get("growth_migration_v2", false)):
		hero.stat_points += maxi(0, int(old_hero.get("level", 1)) - 1)
	var old_base: Dictionary = StatManager.LEGACY_STATS.get(old_class, StatManager.FIGHTER_STATS)
	var invested: Dictionary = old_hero.get("attributes", {})
	for stat in StatManager.STAT_KEYS:
		hero.attributes[stat] = int(StatManager.FIGHTER_STATS[stat]) + maxi(0, int(invested.get(stat, old_base[stat])) - int(old_base[stat]))
	state["characters"] = {FIGHTER_ID: hero}
	state["class_id"] = FIGHTER_ID
	state.erase("party_slots")
	state.erase("leader_index")
	var gear: Dictionary = state.get("equipped_gear", {}).get(old_class, DEFAULT_EQUIPPED_GEAR[FIGHTER_ID]).duplicate()
	state["equipped_gear"] = {FIGHTER_ID: gear}

func _read_save_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open save file '%s' (error %d)." % [path, FileAccess.get_open_error()])
		return {}
	var json_str := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(json_str)
	if error != OK:
		push_error("Could not parse '%s' at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data if json.data is Dictionary else {}

func _sanitize_character_slots():
	var assigned: Dictionary = {}
	for i in range(character_slot_manager.get_slot_count()):
		var value: Variant = character_slot_manager.get_slot(i)
		if value == null:
			continue
		var character_id := str(value)
		if not character_profiles.has(character_id) or assigned.has(character_id):
			character_slot_manager.clear_slot(i)
		else:
			assigned[character_id] = true
	for character_id in character_profiles:
		if assigned.has(character_id):
			continue
		var empty_slot := character_slot_manager.find_empty_slot()
		if empty_slot >= 0:
			character_slot_manager.set_slot(empty_slot, str(character_id))
			assigned[character_id] = true

func has_save_data() -> bool:
	return not character_profiles.is_empty()

func reset_save():
	player_level = 1
	player_current_xp = 0
	player_xp_to_next = 10
	player_gold = 1500
	player_gems = 100
	player_growth_currency = 0
	player_current_hp = 100.0
	attack_damage_mult = 1.0
	attack_speed_mult = 1.0
	move_speed_mult = 1.0
	max_hp_bonus = 0.0
	party_slots.assign([get_leader_id()])
	leader_index = 0
	_set_character_skill_set(get_leader_id())
	skill_loadout = CHARACTER_SKILL_DATABASE.get_default_loadout(get_leader_id())
	item_counts = {1: 3, 2: 1, 3: 2}
	inventory = DEFAULT_INVENTORY.duplicate(true)
	equipped_gear = DEFAULT_EQUIPPED_GEAR.duplicate(true)
	_ensure_character_equipment_entries()
	for char_id in characters:
		characters[char_id]["level"] = 1
		characters[char_id].merge(DEFAULT_CHARACTER_STATS.get(char_id, {}), true)
		characters[char_id]["name"] = DEFAULT_CHARACTER_NAMES.get(char_id, characters[char_id].get("name", str(char_id)))
		characters[char_id]["attributes"] = StatManager.get_default_stats(str(char_id), characters[char_id])
		characters[char_id]["stat_points"] = 0
		characters[char_id]["stat_points_spent"] = 0
		characters[char_id]["growth_migration_v2"] = true
	for quest in quests:
		quest["current"] = 0
		quest["claimed"] = false
	for stage_id in stages:
		stages[stage_id]["cleared"] = false
	current_selected_stage_id = "stage_1"
	input_mode = "auto"
	tutorial_flags = {
		"seen_character": false,
		"seen_party": false,
		"seen_inventory": false,
		"seen_skill": false,
		"first_battle_done": false,
		"post_battle_pending": false
	}
	monster_kill_counts = {}
	last_battle_result = {
		"won": false,
		"time": 0.0,
		"kills": 0,
		"survival_level": 1,
		"gold_earned": 0,
		"growth_currency_earned": 0,
		"cards_earned": [],
		"items_earned": []
	}
	recalculate_party_stats()
	data_updated.emit()
	currency_changed.emit(player_gold, player_gems)
	party_updated.emit()
	save_to_disk()
