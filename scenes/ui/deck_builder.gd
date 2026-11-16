extends Control

var working_deck: Array[String] = []
var owned_list: VBoxContainer
var deck_list: VBoxContainer
var detail_label: Label
var count_label: Label
var feedback_label: Label
var start_button: Button
var search_edit: LineEdit
var type_filter: OptionButton
var deck_name_edit: LineEdit

func _ready():
	GameManager.current_location = GameManager.Location.CARD_DECK
	GameManager.card_manager.ensure_starter_collection()
	GameManager.deck_manager.ensure_starter_deck(GameManager.card_manager.owned)
	working_deck = Array(GameManager.deck_manager.deck.duplicate(), TYPE_STRING, &"", null)
	_build_ui()
	_refresh()

func _build_ui():
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.025, 0.04, 0.07)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var profile := GameData.get_character_profile(GameData.active_character_id)
	var title := UiStyle.make_title("🃏 카드 덱 관리 · %s" % profile.get("name", "모험가"), 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	deck_name_edit = LineEdit.new()
	deck_name_edit.custom_minimum_size = Vector2(240, 44)
	deck_name_edit.max_length = 20
	deck_name_edit.text = GameManager.deck_manager.deck_name
	deck_name_edit.placeholder_text = "덱 이름"
	header.add_child(deck_name_edit)
	var back := UiStyle.make_button("← 마을", Vector2(150, 46))
	back.pressed.connect(GameManager.go_to_lobby)
	header.add_child(back)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	root.add_child(filters)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "🔎 카드 이름 검색"
	search_edit.custom_minimum_size = Vector2(360, 44)
	search_edit.text_changed.connect(func(_text): _refresh())
	filters.add_child(search_edit)
	type_filter = OptionButton.new()
	type_filter.custom_minimum_size = Vector2(220, 44)
	for item in ["전체 유형", "공격", "방어", "상태/연계", "버프/특수"]: type_filter.add_item(item)
	type_filter.item_selected.connect(func(_index): _refresh())
	filters.add_child(type_filter)
	var auto_button := UiStyle.make_button("✨ 자동 추천 미리보기", Vector2(240, 44))
	auto_button.tooltip_text = "공격·방어·상태 연계와 에너지 분포를 고려해 12장을 추천합니다. 확인 전에는 기존 덱을 바꾸지 않습니다."
	auto_button.pressed.connect(_preview_auto_deck)
	filters.add_child(auto_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	owned_list = _make_list_panel(body, "보유 카드 (클릭하여 추가)", 610)
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(390, 0)
	center.add_child(UiStyle.make_label("카드 상세", 18, Color(1, 0.86, 0.4)))
	detail_label = UiStyle.make_label("카드를 선택하세요.", 16)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(detail_label)
	body.add_child(center)
	deck_list = _make_list_panel(body, "현재 덱 (클릭하여 제거)", 610)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	count_label = UiStyle.make_label("", 18, Color(1, 0.86, 0.4))
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(count_label)
	var reset := UiStyle.make_button("초기 덱", Vector2(150, 48))
	reset.pressed.connect(_reset_deck)
	footer.add_child(reset)
	var save := UiStyle.make_button("덱 저장", Vector2(150, 48))
	save.pressed.connect(_save_deck)
	footer.add_child(save)
	start_button = UiStyle.make_button("던전 입장", Vector2(190, 48), true)
	start_button.pressed.connect(_start_dungeon)
	footer.add_child(start_button)
	feedback_label = UiStyle.make_label("저장한 12장으로 카드 던전에 도전하고, 서바이벌 레벨업 때마다 강화 카드를 뽑습니다.", 14, Color(0.75, 0.84, 0.95))
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(feedback_label)

func _make_list_panel(parent: HBoxContainer, heading: String, width: float) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_child(UiStyle.make_label(heading, 18, Color(1, 0.86, 0.4)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	parent.add_child(panel)
	return list

func _refresh():
	for child in owned_list.get_children(): child.queue_free()
	for child in deck_list.get_children(): child.queue_free()
	var used := _count_cards(working_deck)
	for card_id in CardDatabase.all_ids():
		var owned := GameManager.card_manager.get_owned_count(card_id)
		if owned <= 0: continue
		var card := CardDatabase.get_card(card_id)
		if not search_edit.text.strip_edges().is_empty() and not str(card.name).containsn(search_edit.text.strip_edges()): continue
		if not _matches_type_filter(card): continue
		var button := UiStyle.make_button("[%s] %s · ⚡%d     %d/%d" % [card.grade, card.name, card.cost, int(used.get(card_id, 0)), owned], Vector2(0, 54))
		button.tooltip_text = "%s\n서바이벌 · %s" % [card.desc, CardDatabase.SURVIVAL_EFFECTS[card_id].description]
		button.disabled = working_deck.size() >= GameManager.deck_manager.deck_size or int(used.get(card_id, 0)) >= owned
		button.pressed.connect(_add_card.bind(card_id))
		button.mouse_entered.connect(_show_detail.bind(card_id))
		owned_list.add_child(button)
	for index in range(working_deck.size()):
		var card_id := working_deck[index]
		var card := CardDatabase.get_card(card_id)
		var button := UiStyle.make_button("%02d. [%s] %s · ⚡%d" % [index + 1, card.grade, card.name, card.cost], Vector2(0, 48))
		button.tooltip_text = "%s\n클릭하여 덱에서 제거" % card.desc
		button.pressed.connect(_remove_card.bind(index))
		button.mouse_entered.connect(_show_detail.bind(card_id))
		deck_list.add_child(button)
	count_label.text = "덱 %d / %d장" % [working_deck.size(), GameManager.deck_manager.deck_size]
	start_button.disabled = working_deck.size() != GameManager.deck_manager.deck_size

func _count_cards(cards: Array[String]) -> Dictionary:
	var counts := {}
	for card_id in cards: counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts

func _matches_type_filter(card: Dictionary) -> bool:
	match type_filter.selected:
		1: return card.get("tags", []).has("attack")
		2: return card.get("tags", []).has("block")
		3: return card.get("tags", []).has("combo") or str(card.get("type", "")).contains("status")
		4: return card.get("tags", []).has("buff") or card.get("tags", []).has("special")
	return true

func _show_detail(card_id: String):
	var card := CardDatabase.get_card(card_id)
	detail_label.text = "%s  [%s]\n\n카드 던전 · 에너지 %d\n%s\n\n서바이벌 · 레벨업 강화\n%s" % [card.name, card.grade, card.cost, card.desc, CardDatabase.SURVIVAL_EFFECTS[card_id].description]

func _add_card(card_id: String):
	working_deck.append(card_id)
	_refresh()

func _remove_card(index: int):
	if index >= 0 and index < working_deck.size(): working_deck.remove_at(index)
	_refresh()

func _reset_deck():
	working_deck = CardDatabase.STARTER_DECK.duplicate()
	_refresh()

func _preview_auto_deck():
	var recommendation: Array[String] = []
	var preferred: Array[String] = ["strike", "guard", "bleed", "blood_burst", "shield_bash", "focus", "quick_think", "double_strike", "fortress", "finisher", "burn", "flame_burst", "adrenaline"]
	var used: Dictionary = {}
	for card_id in preferred:
		while recommendation.size() < GameManager.deck_manager.deck_size and int(used.get(card_id, 0)) < GameManager.card_manager.get_owned_count(card_id):
			recommendation.append(card_id)
			used[card_id] = int(used.get(card_id, 0)) + 1
			if int(used[card_id]) >= 2: break
	if recommendation.size() < GameManager.deck_manager.deck_size:
		for card_id in CardDatabase.all_ids():
			while recommendation.size() < GameManager.deck_manager.deck_size and int(used.get(card_id, 0)) < GameManager.card_manager.get_owned_count(card_id):
				recommendation.append(card_id)
				used[card_id] = int(used.get(card_id, 0)) + 1
	var names: Array[String] = []
	for card_id in recommendation: names.append(str(CardDatabase.get_card(card_id).name))
	UiFeedback.confirm("자동 덱 추천", "추천 덱:\n%s\n\n현재 편성을 이 추천안으로 교체할까요?" % ", ".join(PackedStringArray(names)), func():
		working_deck = recommendation.duplicate()
		_refresh()
		feedback_label.text = "추천 덱을 미리 적용했습니다. 저장 전까지 영구 반영되지 않습니다."
	)

func _save_deck() -> bool:
	if not GameManager.deck_manager.set_deck_checked(working_deck, GameManager.card_manager.owned):
		feedback_label.text = "보유 수량을 지키면서 12장을 정확히 편성해 주세요."
		return false
	GameManager.deck_manager.deck_name = deck_name_edit.text.strip_edges() if not deck_name_edit.text.strip_edges().is_empty() else "기본 덱"
	if not GameData.save_to_disk():
		feedback_label.text = "덱을 파일에 저장하지 못했습니다. 다시 저장해 주세요."
		return false
	feedback_label.text = "카드 던전과 서바이벌에 사용할 덱을 저장했습니다."
	return true

func _start_dungeon():
	if _save_deck(): GameManager.go_to_card_dungeon()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_lobby()
		get_viewport().set_input_as_handled()
