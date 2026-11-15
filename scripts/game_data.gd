extends Node

# ==========================================
# GameData: Central Persistent Data Store
# ==========================================

signal data_updated()
signal currency_changed(gold: int, gems: int)
signal party_updated()

const SAVE_FILE_PATH = "user://freesurvivor_save.json"
const DEFAULT_INVENTORY: Array[Dictionary] = [
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
const DEFAULT_EQUIPPED_GEAR: Dictionary = {
	"warrior": {"weapon": "wpn_iron_sword", "armor": "arm_leather", "accessory": null},
	"archer": {"weapon": null, "armor": null, "accessory": "acc_ring_speed"},
	"mage": {"weapon": null, "armor": null, "accessory": null},
	"paladin": {"weapon": null, "armor": "arm_plate", "accessory": null},
	"assassin": {"weapon": null, "armor": null, "accessory": null},
	"priest": {"weapon": null, "armor": null, "accessory": null}
}
const DEFAULT_CHARACTER_STATS: Dictionary = {
	"warrior": {"base_hp": 120.0, "base_atk": 20.0, "base_def": 10.0},
	"archer": {"base_hp": 90.0, "base_atk": 24.0, "base_def": 6.0},
	"mage": {"base_hp": 80.0, "base_atk": 30.0, "base_def": 4.0},
	"paladin": {"base_hp": 160.0, "base_atk": 15.0, "base_def": 16.0},
	"assassin": {"base_hp": 95.0, "base_atk": 27.0, "base_def": 7.0},
	"priest": {"base_hp": 105.0, "base_atk": 14.0, "base_def": 8.0}
}
const DEFAULT_CHARACTER_NAMES: Dictionary = {
	"warrior": "카엘",
	"archer": "실피드",
	"mage": "이그니스",
	"paladin": "아르토리우스",
	"assassin": "섀도우",
	"priest": "루나"
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
	"zombie": {
		"name": "좀비", "icon": "🧟", "grade": "일반",
		"desc": "느리지만 끈질기게 몰려오는 언데드. 초원과 숲에서 가장 흔히 마주친다."
	},
	"skeleton": {
		"name": "스켈레톤", "icon": "💀", "grade": "일반",
		"desc": "멀리서 뼈 화살을 쏘는 원거리 언데드. 접근전으로 빠르게 처리하는 편이 좋다."
	},
	"mutant": {
		"name": "뮤턴트", "icon": "👹", "grade": "정예",
		"desc": "거대한 몸집과 강력한 한 방을 가진 돌연변이. 방어 장비가 필수다."
	},
	"mutant_lord": {
		"name": "뮤턴트 군주", "icon": "🐲", "grade": "보스",
		"desc": "심연의 문을 지키는 군주. 전투 후반부에 등장하는 최강의 적."
	}
}

# --- Player Account Stats ---
var player_level: int = 1
var player_current_xp: int = 0
var player_xp_to_next: int = 50
var player_gold: int = 1500
var player_gems: int = 100
var player_current_hp: float = 100.0

# --- UI / Tutorial / Meta state ---
var input_mode: String = "auto" # auto, pc, mobile
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
var skill_loadout: Dictionary = {"q": "q", "w": "w", "e": "e", "r": "r"}

var skill_meta: Dictionary = {
	"q": {
		"name": "검기 방출",
		"icon": "🗡️",
		"desc": "전방으로 검기를 날려 일직선상의 모든 적을 관통 타격합니다.",
		"base_cd": 2.5,
		"base_dmg_ratio": 1.2,
		"cd_step": 0.1,
		"dmg_step": 0.15,
		"cost_base": 100,
		"sp_cost": 8,
		"range": 12.0,
		"unlock_level": 1,
		"effect": "직선 관통"
	},
	"w": {
		"name": "회전 베기",
		"icon": "🌀",
		"desc": "자신을 중심으로 360도 반경의 적들에게 강력한 회전 타격을 가합니다.",
		"base_cd": 4.5,
		"base_dmg_ratio": 1.6,
		"cd_step": 0.15,
		"dmg_step": 0.2,
		"cost_base": 150,
		"sp_cost": 12,
		"range": 4.5,
		"unlock_level": 1,
		"effect": "주변 360도"
	},
	"e": {
		"name": "화염 방사",
		"icon": "🔥",
		"desc": "전방 부채꼴 범위에 맹렬한 불길을 뿜어 다단 히트 피해를 입힙니다.",
		"base_cd": 3.5,
		"base_dmg_ratio": 1.4,
		"cd_step": 0.12,
		"dmg_step": 0.18,
		"cost_base": 200,
		"sp_cost": 16,
		"range": 8.0,
		"unlock_level": 1,
		"effect": "전방 부채꼴"
	},
	"r": {
		"name": "궁극: 대폭발",
		"icon": "💥",
		"desc": "지면에 성스러운 마력을 집중시켜 화면 내 모든 적에게 괴멸적인 폭발 피해를 줍니다.",
		"base_cd": 8.0,
		"base_dmg_ratio": 2.8,
		"cd_step": 0.25,
		"dmg_step": 0.35,
		"cost_base": 350,
		"sp_cost": 24,
		"range": 20.0,
		"unlock_level": 1,
		"effect": "광역 폭발"
	}
}

# --- Consumable Items Stock ---
var item_counts: Dictionary = {
	1: 3, # Potion (Heal 35)
	2: 1, # Screen Bomb (80 Damage)
	3: 2  # Speed Boost (1.5x Speed for 5s)
}

# --- Collectible Characters (6 Full Characters) ---
var characters: Dictionary = {
	"warrior": {
		"id": "warrior",
		"name": "카엘",
		"title": "여명의 검사",
		"grade": "SSR",
		"role": "전사",
		"level": 1,
		"max_level": 50,
		"base_hp": 120.0,
		"base_atk": 20.0,
		"base_def": 10.0,
		"base_spd": 6.8,
		"icon": "⚔️",
		"color": Color(0.9, 0.3, 0.25),
		"unlocked": true,
		"signature_skill": "검기 방출 (Q)",
		"desc": "근접 베기와 검기 공격에 특화된 균형 잡힌 검사."
	},
	"archer": {
		"id": "archer",
		"name": "실피드",
		"title": "바람의 추적자",
		"grade": "SR",
		"role": "궁수",
		"level": 1,
		"max_level": 50,
		"base_hp": 90.0,
		"base_atk": 24.0,
		"base_def": 6.0,
		"base_spd": 7.4,
		"icon": "🏹",
		"color": Color(0.25, 0.75, 0.35),
		"unlocked": true,
		"signature_skill": "바람의 화살 (E)",
		"desc": "원거리 속사 공격과 빠른 이동속도를 자랑하는 명사수."
	},
	"mage": {
		"id": "mage",
		"name": "이그니스",
		"title": "진홍의 마도사",
		"grade": "SSR",
		"role": "마법사",
		"level": 1,
		"max_level": 50,
		"base_hp": 80.0,
		"base_atk": 30.0,
		"base_def": 4.0,
		"base_spd": 6.2,
		"icon": "🔮",
		"color": Color(0.95, 0.45, 0.15),
		"unlocked": true,
		"signature_skill": "대폭발 (R)",
		"desc": "강력한 화염 광역 마법으로 적 무리를 일망타진합니다."
	},
	"paladin": {
		"id": "paladin",
		"name": "아르토리우스",
		"title": "수호의 성기사",
		"grade": "SR",
		"role": "탱커",
		"level": 1,
		"max_level": 50,
		"base_hp": 160.0,
		"base_atk": 15.0,
		"base_def": 16.0,
		"base_spd": 6.0,
		"icon": "🛡️",
		"color": Color(0.9, 0.8, 0.2),
		"unlocked": true,
		"signature_skill": "신성 회전베기 (W)",
		"desc": "단단한 방어력과 체력으로 아군을 보호하고 생존을 책임집니다."
	},
	"assassin": {
		"id": "assassin",
		"name": "섀도우",
		"title": "그림자 암살자",
		"grade": "SR",
		"role": "암살자",
		"level": 1,
		"max_level": 50,
		"base_hp": 95.0,
		"base_atk": 27.0,
		"base_def": 7.0,
		"base_spd": 8.0,
		"icon": "🗡️",
		"color": Color(0.65, 0.3, 0.85),
		"unlocked": true,
		"signature_skill": "암습 섬광 (Q)",
		"desc": "초고속 기동력과 치명타로 보스급 적을 단숨에 베어 넘깁니다."
	},
	"priest": {
		"id": "priest",
		"name": "루나",
		"title": "빛의 성녀",
		"grade": "R",
		"role": "지원가",
		"level": 1,
		"max_level": 50,
		"base_hp": 105.0,
		"base_atk": 14.0,
		"base_def": 8.0,
		"base_spd": 6.5,
		"icon": "✨",
		"color": Color(0.4, 0.75, 1.0),
		"unlocked": true,
		"signature_skill": "성스러운 축복",
		"desc": "파티원들의 체력을 치유하고 능력치 상승 버프를 부여합니다."
	}
}

# --- 6-Person Party Setup ---
var party_slots: Array[String] = ["warrior", "archer", "mage", "paladin", "assassin", "priest"]
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
		"desc": "마을 북쪽 성문 밖 초원에 몬스터들이 출몰하기 시작했습니다. 파티를 이끌고 침략을 저지하세요.",
		"monster_types": ["좀비", "스켈레톤", "뮤턴트 (보스)"],
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
		"monster_types": ["무장 스켈레톤", "맹독 좀비", "고대 뮤턴트 거수"],
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
		"desc": "봉인된 심연의 문에서 쏟아져 나오는 몬스터 군단. 최고 등급 파티의 모든 전력을 동원하세요.",
		"monster_types": ["해골 기사단", "파괴의 뮤턴트 군주"],
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
	"gold_earned": 0,
	"xp_earned": 0,
	"items_earned": []
}

func _ready():
	load_from_disk()
	_migrate_character_attributes()
	_migrate_skill_loadout(skill_loadout)
	recalculate_party_stats()

func _migrate_character_attributes():
	for char_id in characters:
		var character: Dictionary = characters[char_id]
		var defaults := StatManager.get_default_stats(str(char_id))
		var attributes: Dictionary = character.get("attributes", {})
		for stat_name in StatManager.STAT_KEYS:
			attributes[stat_name] = max(1, int(attributes.get(stat_name, defaults[stat_name])))
		character["attributes"] = attributes
		character["stat_points"] = max(0, int(character.get("stat_points", 0)))
		character["stat_points_spent"] = max(0, int(character.get("stat_points_spent", 0)))

# -------------------------------------------------------------
# PARTY & STAT CALCULATIONS
# -------------------------------------------------------------

func get_party_combat_power() -> int:
	var total_power = 0
	for cid in party_slots:
		if characters.has(cid):
			var c = characters[cid]
			var lvl = c.get("level", 1)
			var base_hp = c.get("base_hp", 100.0)
			var base_atk = c.get("base_atk", 15.0)
			var base_def = c.get("base_def", 5.0)
			var power = int(base_hp * 0.5 + base_atk * 3.0 + base_def * 2.0 + (lvl * 15))
			for item_id in equipped_gear.get(cid, {}).values():
				var item = _get_inventory_item(str(item_id))
				power += int(item.get("hp", 0) * 0.5 + item.get("atk", 0) * 3 + item.get("def", 0) * 2)
			total_power += power
	return total_power

func recalculate_party_stats():
	# Party bonus applies to player leader in battle
	var bonus_hp: float = 0.0
	var bonus_atk: float = 0.0
	for cid in party_slots:
		if characters.has(cid):
			var c = characters[cid]
			var lvl = c.get("level", 1)
			bonus_hp += (lvl - 1) * 5.0
			bonus_atk += (lvl - 1) * 0.03
			for item_id in equipped_gear.get(cid, {}).values():
				var item = _get_inventory_item(str(item_id))
				bonus_hp += item.get("hp", 0)
				bonus_atk += float(item.get("atk", 0)) / 100.0

	max_hp_bonus = bonus_hp
	attack_damage_mult = 1.0 + bonus_atk
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("refresh_persistent_stats"):
		player.call("refresh_persistent_stats")

func _get_inventory_item(item_id: String) -> Dictionary:
	for item in inventory:
		if item.get("id", "") == item_id:
			return item
	return {}

func set_party_member(slot_idx: int, char_id: String) -> bool:
	if slot_idx < 0 or slot_idx >= 6:
		return false
	if not characters.has(char_id) or not characters[char_id].get("unlocked", false):
		return false
	# If char already in another slot, swap
	var existing_idx = party_slots.find(char_id)
	if existing_idx != -1 and existing_idx != slot_idx:
		var temp = party_slots[slot_idx]
		party_slots[slot_idx] = char_id
		party_slots[existing_idx] = temp
	else:
		party_slots[slot_idx] = char_id
	recalculate_party_stats()
	party_updated.emit()
	data_updated.emit()
	save_to_disk()
	return true

func level_up_character(char_id: String) -> bool:
	if not characters.has(char_id):
		return false
	var c = characters[char_id]
	var cur_lvl = c.get("level", 1)
	if cur_lvl >= c.get("max_level", 50):
		return false

	var cost = cur_lvl * 250
	if player_gold < cost:
		return false

	player_gold -= cost
	c["level"] = cur_lvl + 1
	c["base_hp"] = c["base_hp"] + 12.0
	c["base_atk"] = c["base_atk"] + 2.5
	c["base_def"] = c["base_def"] + 1.2
	c["stat_points"] = int(c.get("stat_points", 0)) + 1

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

func allocate_character_stat(char_id: String, stat_name: String) -> bool:
	if not characters.has(char_id) or not StatManager.STAT_KEYS.has(stat_name):
		return false
	var character: Dictionary = characters[char_id]
	if int(character.get("stat_points", 0)) <= 0:
		return false
	var attributes: Dictionary = character.get("attributes", StatManager.get_default_stats(char_id))
	attributes[stat_name] = int(attributes.get(stat_name, 1)) + 1
	character["attributes"] = attributes
	character["stat_points"] = int(character.get("stat_points", 0)) - 1
	character["stat_points_spent"] = int(character.get("stat_points_spent", 0)) + 1
	recalculate_party_stats()
	data_updated.emit()
	save_to_disk()
	return true

func reset_character_stats(char_id: String) -> bool:
	if not characters.has(char_id):
		return false
	var character: Dictionary = characters[char_id]
	var spent := int(character.get("stat_points_spent", 0))
	if spent <= 0:
		return false
	character["attributes"] = StatManager.get_default_stats(char_id)
	character["stat_points"] = int(character.get("stat_points", 0)) + spent
	character["stat_points_spent"] = 0
	recalculate_party_stats()
	data_updated.emit()
	save_to_disk()
	return true

func get_character_stat_manager(char_id: String) -> StatManager:
	var stats := StatManager.new()
	if characters.has(char_id):
		stats.setup_from_class(char_id, characters[char_id])
	return stats

func level_up_skill(skill_key: String) -> bool:
	if not skill_levels.has(skill_key) or not skill_meta.has(skill_key):
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

func equip_skill(slot: String, skill_id: String) -> bool:
	var slots: Array[String] = ["q", "w", "e", "r"]
	if not slots.has(slot) or not skill_meta.has(skill_id):
		return false
	if player_level < int(skill_meta[skill_id].get("unlock_level", 1)):
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
	var slots: Array[String] = ["q", "w", "e", "r"]
	var migrated: Dictionary = {}
	var assigned: Dictionary = {}
	for slot in slots:
		var skill_id := str(saved_loadout.get(slot, ""))
		if skill_meta.has(skill_id) and not assigned.has(skill_id):
			migrated[slot] = skill_id
			assigned[skill_id] = true
		else:
			migrated[slot] = ""
	for slot in slots:
		if migrated[slot] != "":
			continue
		for skill_id in skill_meta:
			if not assigned.has(skill_id):
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
	return current_ratio / meta.base_dmg_ratio

# -------------------------------------------------------------
# BATTLE RESULT & REWARDS
# -------------------------------------------------------------

func record_battle_result(won: bool, time_sec: float, kills: int) -> Dictionary:
	var stage = stages.get(current_selected_stage_id, stages["stage_1"])
	var first_clear = won and not stage.get("cleared", false)

	var base_gold = kills * 6 + int(time_sec * 1.5)
	var base_xp = kills * 4 + int(time_sec * 2.0)
	var earned_items: Array[String] = []

	if won:
		if first_clear:
			base_gold += stage.rewards.gold
			base_xp += stage.rewards.xp
			for itm in stage.rewards.items:
				earned_items.append(str(itm))
				_grant_reward_item(str(itm))
		stage["cleared"] = true
	else:
		# Partial rewards
		base_gold += int(stage.rewards.gold * 0.3)
		base_xp += int(stage.rewards.xp * 0.3)
		earned_items.append("소형 치유 물약 x1")
		_grant_reward_item("소형 치유 물약 x1")

	# Give consumables if drops occurred
	if kills >= 20:
		item_counts[1] = item_counts.get(1, 0) + 1
		earned_items.append("체력 물약 x1")
	if kills >= 50:
		item_counts[2] = item_counts.get(2, 0) + 1
		earned_items.append("폭탄 x1")

	# Apply currencies
	player_gold += base_gold
	_add_player_xp(base_xp)

	# Update Quests
	_update_quest_progress("q_first_battle", kills)
	_update_quest_progress("q_slay_50", kills)
	if int(time_sec) >= 120:
		_update_quest_progress("q_reach_time", int(time_sec))

	last_battle_result = {
		"won": won,
		"time": time_sec,
		"kills": kills,
		"gold_earned": base_gold,
		"xp_earned": base_xp,
		"items_earned": earned_items,
		"stage_name": stage.name
	}

	tutorial_flags["first_battle_done"] = true
	tutorial_flags["post_battle_pending"] = true

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
	var stage = stages[stage_id]
	if player_level < int(stage.get("level_req", 1)):
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

func reset_data():
	attack_damage_mult = 1.0
	attack_speed_mult = 1.0
	move_speed_mult = 1.0
	max_hp_bonus = 0.0
	for skill_key in skill_meta:
		var meta = skill_meta[skill_key]
		var level = skill_levels.get(skill_key, 1)
		skill_cooldowns[skill_key] = max(0.5, meta.base_cd - meta.cd_step * (level - 1))
	recalculate_party_stats()

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

# -------------------------------------------------------------
# SAVE & LOAD
# -------------------------------------------------------------

func save_to_disk():
	var save_dict = {
		"player_level": player_level,
		"player_current_xp": player_current_xp,
		"player_xp_to_next": player_xp_to_next,
		"player_gold": player_gold,
		"player_gems": player_gems,
		"party_slots": party_slots,
		"leader_index": leader_index,
		"skill_levels": skill_levels,
		"skill_cooldowns": skill_cooldowns,
		"skill_loadout": skill_loadout,
		"item_counts": item_counts,
		"characters": characters,
		"inventory": inventory,
		"equipped_gear": equipped_gear,
		"quests": quests,
		"stages": stages,
		"input_mode": input_mode,
		"tutorial_flags": tutorial_flags,
		"monster_kill_counts": monster_kill_counts
	}
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Could not open save file for writing (error %d)." % FileAccess.get_open_error())
		return
	var json_str = JSON.stringify(save_dict, "\t")
	file.store_string(json_str)
	file.close()

func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Could not open save file for reading (error %d)." % FileAccess.get_open_error())
		return false
	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_str)
	if error != OK:
		push_error(
			"Could not parse save file at line %d: %s"
			% [json.get_error_line(), json.get_error_message()]
		)
		return false

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false

	player_level = data.get("player_level", player_level)
	player_current_xp = data.get("player_current_xp", player_current_xp)
	player_xp_to_next = data.get("player_xp_to_next", player_xp_to_next)
	player_gold = data.get("player_gold", player_gold)
	player_gems = data.get("player_gems", player_gems)

	if data.has("party_slots"):
		party_slots = Array(data["party_slots"], TYPE_STRING, &"", null)
	leader_index = data.get("leader_index", leader_index)

	if data.has("skill_levels"):
		for k in data["skill_levels"]:
			if skill_levels.has(k):
				skill_levels[k] = data["skill_levels"][k]
				var level = skill_levels[k]
				var meta = skill_meta[k]
				skill_cooldowns[k] = max(0.5, meta.base_cd - meta.cd_step * (level - 1))
	if data.has("skill_loadout") and data["skill_loadout"] is Dictionary:
		skill_loadout = data["skill_loadout"].duplicate(true)
	if data.has("skill_cooldowns"):
		for k in data["skill_cooldowns"]:
			if skill_cooldowns.has(k):
				skill_cooldowns[k] = data["skill_cooldowns"][k]

	if data.has("item_counts"):
		for k in data["item_counts"]:
			item_counts[int(k)] = data["item_counts"][k]

	if data.has("characters"):
		for cid in data["characters"]:
			if characters.has(cid):
				characters[cid].merge(data["characters"][cid], true)
	if data.has("inventory") and data["inventory"] is Array:
		inventory = Array(data["inventory"], TYPE_DICTIONARY, &"", null)
	if data.has("equipped_gear") and data["equipped_gear"] is Dictionary:
		equipped_gear = data["equipped_gear"].duplicate(true)

	if data.has("quests"):
		var loaded_q = data["quests"]
		for i in range(min(quests.size(), loaded_q.size())):
			quests[i]["current"] = loaded_q[i].get("current", 0)
			quests[i]["claimed"] = loaded_q[i].get("claimed", false)

	if data.has("stages"):
		for sid in data["stages"]:
			if stages.has(sid):
				stages[sid]["cleared"] = data["stages"][sid].get("cleared", false)

	if data.has("input_mode"):
		input_mode = str(data["input_mode"])
	if data.has("tutorial_flags") and data["tutorial_flags"] is Dictionary:
		for key in data["tutorial_flags"]:
			tutorial_flags[key] = data["tutorial_flags"][key]
	if data.has("monster_kill_counts") and data["monster_kill_counts"] is Dictionary:
		monster_kill_counts = data["monster_kill_counts"].duplicate(true)

	recalculate_party_stats()
	return true

func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

func reset_save():
	player_level = 1
	player_current_xp = 0
	player_xp_to_next = 50
	player_gold = 1500
	player_gems = 100
	player_current_hp = 100.0
	attack_damage_mult = 1.0
	attack_speed_mult = 1.0
	move_speed_mult = 1.0
	max_hp_bonus = 0.0
	party_slots = ["warrior", "archer", "mage", "paladin", "assassin", "priest"]
	leader_index = 0
	skill_levels = {"q": 1, "w": 1, "e": 1, "r": 1}
	skill_loadout = {"q": "q", "w": "w", "e": "e", "r": "r"}
	for key in skill_meta:
		skill_cooldowns[key] = skill_meta[key].base_cd
	item_counts = {1: 3, 2: 1, 3: 2}
	inventory = DEFAULT_INVENTORY.duplicate(true)
	equipped_gear = DEFAULT_EQUIPPED_GEAR.duplicate(true)
	for char_id in characters:
		characters[char_id]["level"] = 1
		characters[char_id].merge(DEFAULT_CHARACTER_STATS[char_id], true)
		characters[char_id]["name"] = DEFAULT_CHARACTER_NAMES[char_id]
		characters[char_id]["attributes"] = StatManager.get_default_stats(char_id)
		characters[char_id]["stat_points"] = 0
		characters[char_id]["stat_points_spent"] = 0
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
		"gold_earned": 0,
		"xp_earned": 0,
		"items_earned": []
	}
	recalculate_party_stats()
	data_updated.emit()
	currency_changed.emit(player_gold, player_gems)
	party_updated.emit()
	save_to_disk()
