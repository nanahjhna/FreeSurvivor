class_name SurvivalCardDatabase
extends RefCounted

# Survival-only run upgrades. The separate 12-card dungeon deck remains in CardDatabase.
# Fields: original number, name, rarity, short effect, bonus key, value.
const CARD_ROWS: Array = [
	["001", "전투 본능", "일반", "모든 피해 +8%", "damage", 0.08],
	["002", "강철의 일격", "일반", "물리 피해 +12%", "physical_damage", 0.12],
	["003", "마력 증폭", "일반", "마법 피해 +12%", "magic_damage", 0.12],
	["004", "급소 포착", "일반", "치명타 확률 +5%p", "crit_chance", 0.05],
	["005", "치명적 일격", "희귀", "치명타 피해 +30%", "crit_damage", 0.30],
	["006", "연속 타격", "희귀", "기본 공격 15% 확률로 추가 공격", "extra_attack", 0.15],
	["007", "처형자", "희귀", "HP 30% 이하 적에게 피해 +25%", "execute_damage", 0.25],
	["008", "거인 사냥꾼", "희귀", "보스 피해 +20%", "boss_damage", 0.20],
	["009", "광전사의 분노", "영웅", "내 HP 50% 이하일 때 피해 +35%", "low_hp_damage", 0.35],
	["010", "파괴의 화신", "전설", "모든 피해 +30%, 받는 피해 +15%", "damage_reckless", 0.30],
	["011", "신속한 손놀림", "일반", "기본 공격 속도 +10%", "attack_speed", 0.10],
	["012", "빠른 준비", "일반", "기본 공격 속도 +8%", "attack_speed", 0.08],
	["013", "정밀 사격", "일반", "기본 공격 속도 +12%", "attack_speed", 0.12],
	["014", "전투 리듬", "일반", "기본 공격 속도 +8%", "attack_speed", 0.08],
	["015", "가속 공격", "희귀", "적 처치 시 공격 속도 +3%", "kill_attack_speed_rate", 0.03],
	["016", "이중 공격", "희귀", "기본 공격 10% 확률로 추가 공격", "extra_attack", 0.10],
	["017", "폭풍 연격", "희귀", "기본 공격 속도 +15%", "attack_speed", 0.15],
	["018", "속사의 달인", "희귀", "기본 공격 속도 +12%", "attack_speed", 0.12],
	["019", "무한 연격", "영웅", "기본 공격 피해 +20%", "physical_damage", 0.20],
	["020", "광란의 춤", "영웅", "적 처치 시 공격 속도 +20%", "kill_attack_speed_rate", 0.20],
	["021", "강인한 육체", "일반", "최대 HP +15%", "max_hp_percent", 0.15],
	["022", "단단한 피부", "일반", "받는 피해 -8%", "damage_reduction", 0.08],
	["023", "마법 저항", "일반", "받는 마법 피해 -10%", "magic_reduction", 0.10],
	["024", "생명 회복", "일반", "매초 최대 HP의 1% 회복", "hp_regen", 0.01],
	["025", "전투 회복", "희귀", "적 처치 시 HP 회복", "kill_heal", 0.03],
	["026", "보호막 생성", "희귀", "30초마다 최대 HP의 10% 보호막 생성", "shield_regen", 0.10],
	["027", "불굴의 의지", "희귀", "HP 30% 이하일 때 받는 피해 감소", "low_hp_reduction", 0.20],
	["028", "생명 흡수", "희귀", "기본 공격 적중 시 HP 회복", "lifesteal", 0.03],
	["029", "최후의 저항", "영웅", "치명적인 피해를 1회 막고 최대 HP의 30% 회복", "last_stand", 1.0],
	["030", "불사의 축복", "전설", "스테이지당 1회 사망 시 HP 50%로 부활", "revive", 1.0],
	["031", "가벼운 발걸음", "일반", "이동 속도 +10%", "move_speed", 0.10],
	["032", "민첩한 회피", "일반", "회피 확률 +5%p", "dodge", 0.05],
	["033", "질주 본능", "일반", "이동 속도 +15%", "move_speed", 0.15],
	["034", "돌파", "일반", "이동 속도 +10%", "move_speed", 0.10],
	["035", "그림자 발걸음", "희귀", "이동 속도 +15%", "move_speed", 0.15],
	["036", "유령 걸음", "희귀", "접촉 피해 -20%", "damage_reduction", 0.20],
	["037", "바람의 가호", "희귀", "받는 피해 -10%", "damage_reduction", 0.10],
	["038", "전술 후퇴", "희귀", "이동 속도 +20%", "move_speed", 0.20],
	["039", "잔상", "영웅", "회피 확률 +8%p", "dodge", 0.08],
	["040", "환영의 몸", "영웅", "받는 피해 -12%", "damage_reduction", 0.12],
	["041", "마력 순환", "일반", "스킬 재사용 대기시간 -8%", "cooldown", 0.08],
	["042", "강화 주문", "일반", "스킬 피해 +10%", "skill_damage", 0.10],
	["043", "넓은 공격", "일반", "공격 범위 +12%", "attack_range", 0.12],
	["044", "집중 시전", "일반", "스킬 재사용 대기시간 -8%", "cooldown", 0.08],
	["045", "연쇄 시전", "희귀", "스킬 피해 +10%", "skill_damage", 0.10],
	["046", "전투 마법사", "희귀", "기본 공격 피해 +15%", "physical_damage", 0.15],
	["047", "기술 숙련", "희귀", "스킬 재사용 대기시간 -10%", "cooldown", 0.10],
	["048", "과충전", "희귀", "스킬 피해 +25%", "skill_damage", 0.25],
	["049", "마력 폭주", "영웅", "스킬 피해 +25%", "skill_damage", 0.25],
	["050", "시간 왜곡", "전설", "스킬 재사용 대기시간 -30%", "cooldown", 0.30],
	["052", "화염 강화", "일반", "화염 계열 직접 피해 +15%", "fire_damage", 0.15],
	["055", "폭발 타격", "희귀", "적 처치 시 폭발 피해 강화", "kill_explosion", 0.10],
	["059", "화염 폭풍", "영웅", "범위 공격 피해 +25%", "area_damage", 0.25],
	["061", "전격 무기", "일반", "기본 공격에 추가 번개 피해", "lightning_proc", 0.10],
	["063", "번개 강화", "일반", "스킬 피해 +15%", "magic_damage", 0.15],
	["064", "냉기 강화", "일반", "스킬 피해 +15%", "magic_damage", 0.15],
	["065", "연쇄 번개", "희귀", "기본 공격 시 15% 확률로 주변 적에게 번개 피해", "chain_lightning", 0.15],
	["069", "천둥의 심판", "영웅", "기본 공격 피해 +20%", "physical_damage", 0.20],
	["081", "관통 사격", "일반", "기본 공격 피해 +10%", "physical_damage", 0.10],
	["082", "사거리 확장", "일반", "기본 공격 사거리 +15%", "attack_range", 0.15],
	["083", "투사체 가속", "일반", "스킬 피해 +10%", "skill_damage", 0.10],
	["084", "폭발 범위", "일반", "범위 스킬 피해 +15%", "area_damage", 0.15],
	["085", "다중 발사", "희귀", "기본 공격 피해 +15%", "physical_damage", 0.15],
	["086", "도탄", "희귀", "기본 공격 피해 +15%", "physical_damage", 0.15],
	["087", "충격파", "희귀", "기본 공격 피해 +20%", "physical_damage", 0.20],
	["088", "회전 칼날", "희귀", "범위 스킬 피해 +15%", "area_damage", 0.15],
	["089", "화살 폭풍", "영웅", "범위 공격 피해 +25%", "area_damage", 0.25],
	["090", "무한 탄막", "전설", "기본 공격 피해 +25%", "physical_damage", 0.25],
	["091", "경험의 지혜", "일반", "획득 경험치 +10%", "xp", 0.10],
	["092", "탐욕", "일반", "스테이지 골드 +15%", "gold", 0.15],
	["093", "행운의 별", "일반", "희귀 카드 등장 확률 증가", "rare_weight", 0.05],
	["094", "숙련된 모험가", "일반", "보스 경험치 +20%", "boss_xp", 0.20],
	["095", "빠른 성장", "희귀", "획득 경험치 +20%", "xp", 0.20],
	["096", "황금 손", "희귀", "스테이지 골드 +30%", "gold", 0.30],
	["097", "성장의 축복", "희귀", "즉시 경험치 획득", "instant_xp", 0.50],
	["098", "운명의 선택", "희귀", "레벨업 선택지 추가", "extra_offer", 1.0],
	["099", "초월 성장", "영웅", "획득 경험치 +35%", "xp", 0.35],
	["100", "운명의 지배자", "영웅", "레벨업 선택지 새로고침", "free_reroll", 1.0]
]

const RARITY_WEIGHTS := {"일반": 55, "희귀": 30, "영웅": 12, "전설": 3}
const MAX_PICKS := {"일반": 5, "희귀": 3, "영웅": 2, "전설": 1}

static func all_ids() -> Array[String]:
	var result: Array[String] = []
	for row in CARD_ROWS:
		result.append(str(row[0]))
	return result

static func get_card(card_id: String) -> Dictionary:
	for row in CARD_ROWS:
		if str(row[0]) == card_id:
			return {"id": row[0], "name": row[1], "grade": row[2], "description": row[3], "type": "survival_bonus", "stat": row[4], "value": row[5]}
	return {}

static func draw_offers(count: int, picked: Dictionary, rare_bonus: float = 0.0) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for row in CARD_ROWS:
		var id := str(row[0])
		var card := get_card(id)
		var cap := int(MAX_PICKS.get(str(row[2]), 1))
		if int(picked.get(id, 0)) < cap:
			available.append(card)
	var result: Array[Dictionary] = []
	while result.size() < count and not available.is_empty():
		var grade := _roll_grade(rare_bonus)
		var grade_pool: Array[Dictionary] = []
		for card in available:
			if str(card.grade) == grade:
				grade_pool.append(card)
		if grade_pool.is_empty():
			grade_pool = available
		var chosen: Dictionary = grade_pool.pick_random()
		result.append(chosen)
		available.erase(chosen)
	return result

static func _roll_grade(rare_bonus: float) -> String:
	var roll := randi_range(1, 100)
	var common_cutoff := 55 - int(rare_bonus * 100.0)
	if roll <= common_cutoff:
		return "일반"
	if roll <= 85:
		return "희귀"
	if roll <= 97:
		return "영웅"
	return "전설"
