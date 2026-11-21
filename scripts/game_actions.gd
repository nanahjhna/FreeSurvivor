extends Node
## Central action registry.
## Every keyboard shortcut and every on-screen button goes through this node,
## so both input methods always execute the same game logic.

signal action_requested(action_id: String)
signal bindings_changed()
signal input_mode_changed()

const BINDINGS_PATH := "user://keybinds.cfg"

## rebindable: shown in the settings screen and can be changed by the player.
## context: lobby / battle / fixed
const ACTIONS := {
	"character": {
		"label": "캐릭터", "icon": "👥", "key": KEY_C, "input_action": "menu_character",
		"context": "lobby", "rebindable": true,
		"desc": "무도가의 능력치를 확인하고 성장시킵니다."
	},
	"inventory": {
		"label": "장비", "icon": "🎒", "key": KEY_I, "input_action": "menu_inventory",
		"context": "lobby", "rebindable": true,
		"desc": "캐릭터의 무기와 방어구를 관리합니다."
	},
	"skill": {
		"label": "스킬", "icon": "✨", "key": KEY_K, "input_action": "menu_skill",
		"context": "lobby", "rebindable": true,
		"desc": "캐릭터의 전투 스킬을 확인하고 강화합니다."
	},
	"card_deck": {
		"label": "카드/덱", "icon": "🃏", "key": KEY_D, "input_action": "menu_card_deck",
		"context": "lobby", "rebindable": true,
		"desc": "보유 카드를 확인하고 12장 덱을 편성한 뒤 카드 던전에 입장합니다."
	},
	"quest": {
		"label": "퀘스트", "icon": "📜", "key": KEY_J, "input_action": "menu_quest",
		"context": "lobby", "rebindable": true,
		"desc": "진행 가능한 임무와 보상을 확인합니다."
	},
	"collection": {
		"label": "도감", "icon": "📖", "key": KEY_B, "input_action": "menu_collection",
		"context": "lobby", "rebindable": true,
		"desc": "무도가와 마주친 몬스터를 확인합니다."
	},
	"shop": {
		"label": "상점", "icon": "🪙", "key": KEY_O, "input_action": "menu_shop",
		"context": "lobby", "rebindable": true,
		"desc": "골드로 장비와 소모품을 구매합니다."
	},
	"map": {
		"label": "지도", "icon": "🗺️", "key": KEY_M, "input_action": "menu_map",
		"context": "lobby", "rebindable": true,
		"desc": "마을의 주요 장소와 현재 위치를 확인합니다."
	},
	"settings": {
		"label": "설정", "icon": "⚙️", "key": KEY_ESCAPE, "input_action": "menu_settings",
		"context": "lobby", "rebindable": true,
		"desc": "환경 설정과 단축키를 변경합니다."
	},
	"battle_start": {
		"label": "전투 시작", "icon": "⚔️", "key": KEY_F, "input_action": "battle_start",
		"context": "lobby", "rebindable": true,
		"desc": "선택한 스테이지에 입장합니다."
	},
	"interact": {
		"label": "상호작용", "icon": "✋", "key": KEY_E, "input_action": "interact",
		"context": "lobby", "rebindable": true,
		"desc": "가까운 건물이나 NPC와 상호작용합니다."
	},
	"pause": {
		"label": "일시정지", "icon": "⏸", "key": KEY_ESCAPE, "input_action": "pause",
		"context": "battle", "rebindable": true,
		"desc": "전투를 잠시 멈춥니다."
	},
	"skill_q": {
		"label": "Q 스킬", "icon": "🗡️", "key": KEY_Q, "input_action": "skill_q",
		"context": "battle", "rebindable": true, "desc": "쇄도 연권 스킬을 사용합니다."
	},
	"skill_w": {
		"label": "W 스킬", "icon": "🌀", "key": KEY_W, "input_action": "skill_w",
		"context": "battle", "rebindable": true, "desc": "선풍각 스킬을 사용합니다."
	},
	"skill_e": {
		"label": "E 스킬", "icon": "🔥", "key": KEY_E, "input_action": "skill_e",
		"context": "battle", "rebindable": true, "desc": "홍련권 스킬을 사용합니다."
	},
	"skill_r": {
		"label": "R 스킬", "icon": "💥", "key": KEY_R, "input_action": "skill_r",
		"context": "battle", "rebindable": true, "desc": "궁극기 대폭발을 사용합니다."
	},
	"skill_a": {
		"label": "삼연 기공탄", "icon": "✴️", "key": KEY_A, "input_action": "skill_a",
		"context": "battle", "rebindable": true, "desc": "서바이벌 Lv.2에 배우는 관통 검기입니다."
	},
	"skill_s": {
		"label": "기혈 회복", "icon": "✚", "key": KEY_S, "input_action": "skill_s",
		"context": "battle", "rebindable": true, "desc": "서바이벌 Lv.5에 배우는 회복 기술입니다."
	},
	"item_1": {
		"label": "아이템 1", "icon": "🧪", "key": KEY_1, "input_action": "item_1",
		"context": "battle", "rebindable": true, "desc": "치유 물약을 사용합니다."
	},
	"item_2": {
		"label": "아이템 2", "icon": "💣", "key": KEY_2, "input_action": "item_2",
		"context": "battle", "rebindable": true, "desc": "화면 폭탄을 사용합니다."
	},
	"item_3": {
		"label": "아이템 3", "icon": "💨", "key": KEY_3, "input_action": "item_3",
		"context": "battle", "rebindable": true, "desc": "질풍 물약을 사용합니다."
	},
	"attack": {
		"label": "수동 공격", "icon": "⚔️", "key": KEY_SPACE, "input_action": "manual_attack",
		"context": "battle", "rebindable": true, "desc": "가까운 적을 즉시 공격합니다."
	},
	"auto_battle": {
		"label": "자동 스킬 시전", "icon": "🤖", "key": KEY_T, "input_action": "toggle_auto_battle",
		"context": "battle", "rebindable": true, "desc": "스킬을 자동으로 사용합니다."
	},
	# Fixed movement bindings: PC uses arrow keys; mobile uses the virtual joystick.
	"move_up": {
		"label": "위로 이동", "icon": "↑", "key": KEY_UP, "input_action": "move_up",
		"context": "fixed", "rebindable": false, "desc": "방향키 위로 이동합니다."
	},
	"move_down": {
		"label": "아래로 이동", "icon": "↓", "key": KEY_DOWN, "input_action": "move_down",
		"context": "fixed", "rebindable": false, "desc": "방향키 아래로 이동합니다."
	},
	"move_left": {
		"label": "왼쪽 이동", "icon": "←", "key": KEY_LEFT, "input_action": "move_left",
		"context": "fixed", "rebindable": false, "desc": "방향키 왼쪽으로 이동합니다."
	},
	"move_right": {
		"label": "오른쪽 이동", "icon": "→", "key": KEY_RIGHT, "input_action": "move_right",
		"context": "fixed", "rebindable": false, "desc": "방향키 오른쪽으로 이동합니다."
	}
}

var bindings: Dictionary = {}
var capturing_action: String = ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bindings()
	_apply_input_map()

func _load_bindings():
	for id in ACTIONS:
		bindings[id] = ACTIONS[id].key
	var cfg := ConfigFile.new()
	if cfg.load(BINDINGS_PATH) == OK:
		for id in ACTIONS:
			if not ACTIONS[id].rebindable:
				continue
			bindings[id] = int(cfg.get_value("bindings", id, bindings[id]))
	# Move saved shortcuts off arrow keys, which control movement.
	var migrated := false
	var movement_keys: Array[int] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	for action_id in ACTIONS:
		if not ACTIONS[action_id].rebindable:
			continue
		if movement_keys.has(int(bindings.get(action_id, 0))):
			bindings[action_id] = int(ACTIONS[action_id].key)
			migrated = true
	if migrated:
		_save_bindings()

func _save_bindings():
	var cfg := ConfigFile.new()
	for id in bindings:
		if ACTIONS[id].rebindable:
			cfg.set_value("bindings", id, bindings[id])
	cfg.save(BINDINGS_PATH)

func _apply_input_map():
	for id in ACTIONS:
		var action: String = ACTIONS[id].input_action
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = int(bindings[id])
		InputMap.action_add_event(action, ev)

func trigger(action_id: String):
	action_requested.emit(action_id)

func get_action(action_id: String) -> Dictionary:
	return ACTIONS.get(action_id, {})

func get_key_name(action_id: String) -> String:
	return keycode_to_text(int(bindings.get(action_id, ACTIONS.get(action_id, {}).get("key", 0))))

func get_shortcut_text(action_id: String) -> String:
	if is_mobile():
		return ""
	var def: Dictionary = ACTIONS.get(action_id, {})
	if def.is_empty():
		return ""
	return "[%s]" % get_key_name(action_id)

func keycode_to_text(keycode: int) -> String:
	match keycode:
		KEY_ESCAPE:
			return "ESC"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_SPACE:
			return "SPACE"
		KEY_ENTER:
			return "ENTER"
		KEY_TAB:
			return "TAB"
	var text := OS.get_keycode_string(keycode)
	return text.to_upper() if text.length() <= 6 else text

func get_action_for_event(event: InputEvent) -> String:
	if capturing_action != "":
		return ""
	for id in ACTIONS:
		if not ACTIONS[id].rebindable:
			continue
		if event.is_action_pressed(ACTIONS[id].input_action):
			return id
	return ""

func is_battle_action(action_id: String) -> bool:
	return ACTIONS.get(action_id, {}).get("context", "") == "battle"

func is_lobby_action(action_id: String) -> bool:
	return ACTIONS.get(action_id, {}).get("context", "") == "lobby"

func get_rebindable_actions(context: String = "") -> Array[String]:
	var result: Array[String] = []
	for id in ACTIONS:
		if not ACTIONS[id].rebindable:
			continue
		if context != "" and ACTIONS[id].context != context:
			continue
		result.append(id)
	return result

func is_key_used(keycode: int, ignore_action: String = "") -> bool:
	for id in ACTIONS:
		if id == ignore_action:
			continue
		if int(bindings[id]) == keycode and (ACTIONS[id].rebindable or ACTIONS[id].context == "fixed"):
			return true
	return false

func rebind(action_id: String, keycode: int) -> bool:
	if not ACTIONS.has(action_id) or not ACTIONS[action_id].rebindable:
		return false
	if is_key_used(keycode, action_id):
		return false
	bindings[action_id] = keycode
	_save_bindings()
	_apply_input_map()
	bindings_changed.emit()
	return true

func reset_bindings():
	for id in ACTIONS:
		bindings[id] = ACTIONS[id].key
	_save_bindings()
	_apply_input_map()
	bindings_changed.emit()

func begin_capture(action_id: String):
	capturing_action = action_id

func end_capture():
	capturing_action = ""

func is_capturing() -> bool:
	return capturing_action != ""

func is_mobile() -> bool:
	var mode := "auto"
	if GameData:
		mode = GameData.input_mode
	if mode == "mobile":
		return true
	if mode == "pc":
		return false
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func set_input_mode(mode: String):
	if GameData:
		GameData.input_mode = mode
		GameData.save_to_disk()
	input_mode_changed.emit()
	bindings_changed.emit()
