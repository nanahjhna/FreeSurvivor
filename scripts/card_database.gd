class_name CardDatabase
extends RefCounted

const CARDS: Dictionary = {
	"strike": {"id":"strike", "name":"베기", "desc":"적에게 물리 피해 8.", "type":"attack", "cost":1, "value":8, "target":"enemy", "grade":"N", "tags":["attack", "physical"]},
	"heavy_strike": {"id":"heavy_strike", "name":"강타", "desc":"적에게 물리 피해 16.", "type":"attack", "cost":2, "value":16, "target":"enemy", "grade":"R", "tags":["attack", "physical"]},
	"double_strike": {"id":"double_strike", "name":"연속 공격", "desc":"물리 피해 4를 2회.", "type":"attack", "cost":1, "value":4, "hits":2, "target":"enemy", "grade":"R", "tags":["attack", "physical", "multi"]},
	"guard": {"id":"guard", "name":"방어", "desc":"방어도 6 획득.", "type":"block", "cost":1, "value":6, "target":"self", "grade":"N", "tags":["block"]},
	"fortress": {"id":"fortress", "name":"철벽", "desc":"방어도 15 획득.", "type":"block", "cost":2, "value":15, "target":"self", "grade":"R", "tags":["block"]},
	"bleed": {"id":"bleed", "name":"출혈 베기", "desc":"피해 5와 출혈 3 부여.", "type":"status_attack", "cost":1, "value":5, "status":"bleed", "stacks":3, "target":"enemy", "grade":"R", "tags":["attack", "physical", "bleed"]},
	"blood_burst": {"id":"blood_burst", "name":"피의 폭발", "desc":"출혈을 소모해 중첩당 피해 5.", "type":"consume_status", "cost":1, "value":5, "status":"bleed", "target":"enemy", "grade":"SR", "tags":["combo", "bleed"]},
	"burn": {"id":"burn", "name":"화염구", "desc":"마법 피해 6과 화상 3 부여.", "type":"status_attack", "cost":1, "value":6, "status":"burn", "stacks":3, "scaling":"magic", "target":"enemy", "grade":"R", "tags":["attack", "magic", "burn"]},
	"flame_burst": {"id":"flame_burst", "name":"화염 폭발", "desc":"화상을 소모해 중첩당 피해 6.", "type":"consume_status", "cost":2, "value":6, "status":"burn", "scaling":"magic", "target":"enemy", "grade":"SR", "tags":["combo", "burn", "magic"]},
	"shield_bash": {"id":"shield_bash", "name":"방패 강타", "desc":"현재 방어도의 80%만큼 추가 피해.", "type":"block_attack", "cost":1, "value":4, "block_ratio":0.8, "target":"enemy", "grade":"R", "tags":["attack", "combo", "block"]},
	"finisher": {"id":"finisher", "name":"마무리 일격", "desc":"이번 턴 사용한 공격 카드마다 추가 피해 4.", "type":"finisher", "cost":2, "value":8, "per_attack":4, "target":"enemy", "grade":"SR", "tags":["attack", "combo"]},
	"focus": {"id":"focus", "name":"전투 집중", "desc":"이번 전투 공격력 +2.", "type":"buff", "cost":1, "value":2, "status":"strength", "target":"self", "grade":"R", "tags":["buff"]},
	"quick_think": {"id":"quick_think", "name":"신속한 판단", "desc":"카드 2장 드로우.", "type":"draw", "cost":1, "value":2, "target":"self", "grade":"R", "tags":["special", "draw"]},
	"adrenaline": {"id":"adrenaline", "name":"아드레날린", "desc":"에너지 2 회복. 소멸.", "type":"energy", "cost":0, "value":2, "target":"self", "grade":"SR", "exhaust":true, "tags":["special", "energy"]}
}

const STARTER_OWNED: Dictionary = {
	"strike": 4, "guard": 4, "bleed": 2, "blood_burst": 1, "shield_bash": 1,
	"heavy_strike": 1, "double_strike": 1, "fortress": 1, "burn": 1,
	"flame_burst": 1, "finisher": 1, "focus": 1, "quick_think": 1, "adrenaline": 1
}
const STARTER_DECK: Array[String] = ["strike", "strike", "strike", "guard", "guard", "guard", "bleed", "bleed", "blood_burst", "shield_bash", "focus", "quick_think"]

const SURVIVAL_EFFECTS := {
	"strike": {"type":"stat", "stat":"attack_damage_mult", "value":0.15, "description":"기본·스킬 공격력 +15%"},
	"heavy_strike": {"type":"stat", "stat":"attack_damage_mult", "value":0.25, "description":"기본·스킬 공격력 +25%"},
	"double_strike": {"type":"stat", "stat":"attack_speed_mult", "value":0.2, "description":"스킬 시전 속도 +20%"},
	"guard": {"type":"hp", "value":18, "description":"최대 HP +18, HP 18 회복"},
	"fortress": {"type":"hp", "value":32, "description":"최대 HP +32, HP 32 회복"},
	"bleed": {"type":"on_hit", "value":2, "description":"기본 공격 적중 시 3초간 매초 출혈 피해 2. 재적중하면 지속시간 갱신"},
	"blood_burst": {"type":"on_hit", "value":10, "description":"이미 출혈 중인 적에게 기본 공격 적중 시 추가 피해 10"},
	"burn": {"type":"on_hit", "value":3, "description":"기본 공격 적중 시 3초간 매초 화상 피해 3. 재적중하면 지속시간 갱신"},
	"flame_burst": {"type":"on_hit", "value":12, "description":"이미 화상 중인 적에게 기본 공격 적중 시 추가 피해 12"},
	"shield_bash": {"type":"on_hit", "value":0.05, "description":"기본 공격에 내 최대 HP의 5%만큼 추가 피해"},
	"finisher": {"type":"on_hit", "value":0.3, "description":"HP가 40% 이하인 적에게 기본 공격 피해 +30%"},
	"focus": {"type":"stat", "stat":"move_speed_mult", "value":0.15, "description":"전투 중 이동 속도 +15%"},
	"quick_think": {"type":"all_cd", "value":0.1, "description":"모든 스킬의 재사용 대기시간 10% 단축"},
	"adrenaline": {"type":"stat", "stat":"attack_speed_mult", "value":0.1, "description":"스킬 시전 속도 +10%"}
}

static func get_survival_upgrade(card_id: String) -> Dictionary:
	var card := get_card(card_id)
	if card.is_empty() or not SURVIVAL_EFFECTS.has(card_id):
		return {}
	var upgrade: Dictionary = SURVIVAL_EFFECTS[card_id].duplicate()
	upgrade.merge({"id": card_id, "name": card.name, "grade": card.grade})
	return upgrade

static func get_card(card_id: String) -> Dictionary:
	return CARDS.get(card_id, {})

static func all_ids() -> Array[String]:
	var result: Array[String] = []
	for card_id in CARDS:
		result.append(str(card_id))
	return result
