extends Node
## Computes the single most useful next action for the player.

var dismissed: Dictionary = {}

func is_dismissed(hint_id: String) -> bool:
	return bool(dismissed.get(hint_id, false))

func dismiss(hint_id: String):
	dismissed[hint_id] = true

func get_hint() -> Dictionary:
	var flags: Dictionary = GameData.tutorial_flags

	if bool(flags.get("post_battle_pending", false)):
		return _hint(
			"post_battle",
			"마을로 돌아왔습니다. 캐릭터를 성장시켜 보세요.",
			"캐릭터 성장 [C]",
			"character"
		)

	if not bool(flags.get("first_battle_done", false)):
		return _hint(
			"first_battle",
			"성문으로 이동하여 첫 전투를 시작하세요.",
			"전투 준비 [F]",
			"battle_start"
		)

	return _hint(
		"explore",
		"준비가 끝났습니다. 다시 출격해 보세요.",
		"전투 시작 [F]",
		"battle_start"
	)

func _hint(id: String, text: String, button: String, action: String) -> Dictionary:
	return {
		"id": id,
		"text": text,
		"button": button,
		"action": action,
		"visible": not is_dismissed(id)
	}

func _leader_has_gear() -> bool:
	var leader := GameData.get_leader_id()
	var gear: Dictionary = GameData.equipped_gear.get(leader, {})
	return gear.get("weapon", null) != null and gear.get("armor", null) != null

func _claimable_quest() -> String:
	for quest in GameData.quests:
		if not quest.get("claimed", false) and int(quest.get("current", 0)) >= int(quest.get("target", 1)):
			return str(quest.get("id", ""))
	return ""
