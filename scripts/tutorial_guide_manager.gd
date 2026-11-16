extends Node
class_name TutorialGuideManager

var hints: Dictionary = {
	"stat_growth": "능력치 포인트를 사용하여 캐릭터를 강화하세요.",
	"skill_manage": "보유한 스킬을 전투 슬롯에 장착하세요.",
	"battle_prep": "카드를 선택하고 전투를 시작하세요.",
	"xp_pickup": "바닥에 떨어진 경험치 구슬에 접근하세요.",
	"card_shop": "전투에서 얻은 재화로 새로운 카드를 수집하세요."
}

func get_hint(key: String) -> String:
	return hints.get(key, "")