extends Node
## Computes the single most useful next action for the player.

var dismissed: Dictionary = {}

func is_dismissed(hint_id: String) -> bool:
	return bool(dismissed.get(hint_id, false))

func dismiss(hint_id: String):
	dismissed[hint_id] = true

func get_hint() -> Dictionary:
	var flags: Dictionary = GameData.tutorial_flags

	if not bool(flags.get("seen_character", false)):
		return _hint(
			"first_character",
			"캐릭터를 확인하고 모험을 준비하세요.",
			"캐릭터 [C]",
			"character"
		)

	if not _has_party_member():
		return _hint(
			"empty_party",
			"전투에 참여할 캐릭터를 편성하세요.",
			"파티 편성 [P]",
			"party"
		)

	if not _leader_has_gear():
		return _hint(
			"no_gear",
			"캐릭터에게 장비를 장착해 보세요.",
			"장비 관리 [I]",
			"inventory"
		)

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

	var claimable := _claimable_quest()
	if claimable != "":
		return _hint(
			"claim_quest",
			"완료한 퀘스트의 보상을 받을 수 있습니다.",
			"퀘스트 [J]",
			"quest"
		)

	return _hint(
		"explore",
		"도감을 채우고 더 강한 장비를 준비해 보세요.",
		"도감 [B]",
		"collection"
	)

func _hint(id: String, text: String, button: String, action: String) -> Dictionary:
	return {
		"id": id,
		"text": text,
		"button": button,
		"action": action,
		"visible": not is_dismissed(id)
	}

func _has_party_member() -> bool:
	for cid in GameData.party_slots:
		if str(cid) != "":
			return true
	return false

func _leader_has_gear() -> bool:
	var leader := GameData.get_leader_id()
	if leader == "":
		return false
	var gear: Dictionary = GameData.equipped_gear.get(leader, {})
	return gear.get("weapon", null) != null and gear.get("armor", null) != null

func _claimable_quest() -> String:
	for quest in GameData.quests:
		if not quest.get("claimed", false) and int(quest.get("current", 0)) >= int(quest.get("target", 1)):
			return str(quest.get("id", ""))
	return ""
