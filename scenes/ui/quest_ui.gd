extends CanvasLayer

signal closed()

var _list: VBoxContainer
var _summary: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	visible = false
	_build_ui()
	GameData.data_updated.connect(_refresh)

func _build_ui():
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.72)
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(880, 660)
	center.add_child(panel)

	var margin := UiStyle.make_margin(panel, 24)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := UiStyle.make_title("📜 퀘스트", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiStyle.make_button("← 닫기 [ESC]", Vector2(150, 42))
	close.pressed.connect(close_screen)
	header.add_child(close)

	_summary = UiStyle.make_label("", 14, Color(0.72, 0.82, 0.95))
	vbox.add_child(_summary)
	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

func open():
	visible = true
	_refresh()

func close_screen():
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

func _refresh():
	if not visible:
		return
	for child in _list.get_children():
		child.queue_free()

	var claimable := 0
	var completed := 0
	for quest in GameData.quests:
		if bool(quest.get("claimed", false)):
			completed += 1
		if not quest.get("claimed", false) and int(quest.get("current", 0)) >= int(quest.get("target", 1)):
			claimable += 1
		_list.add_child(_make_quest_card(quest))
	_summary.text = "완료 %d / 전체 %d   ·   수령 가능 %d개" % [
		completed, GameData.quests.size(), claimable
	]

func _make_quest_card(quest: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.sub_panel_style())

	var margin := UiStyle.make_margin(panel, 14)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var title := UiStyle.make_label(str(quest.get("title", "퀘스트")), 18, Color(1.0, 0.9, 0.55))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var claimed: bool = quest.get("claimed", false)
	var current: int = int(quest.get("current", 0))
	var target: int = int(quest.get("target", 1))
	var complete := current >= target
	var status := UiStyle.make_label(
		"수령 완료" if claimed else ("✅ 완료" if complete else "진행 중"),
		13,
		Color(0.5, 1.0, 0.6) if complete and not claimed else (Color(0.6, 0.62, 0.7) if claimed else Color(0.65, 0.78, 0.95))
	)
	top.add_child(status)

	vbox.add_child(UiStyle.make_label(str(quest.get("desc", "")), 13, Color(0.86, 0.9, 0.98)))

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 18)
	progress.max_value = target
	progress.value = min(current, target)
	progress.show_percentage = false
	vbox.add_child(progress)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom)

	var progress_label := UiStyle.make_label("%d / %d" % [min(current, target), target], 12, Color(0.7, 0.82, 0.95))
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(progress_label)

	var reward := UiStyle.make_label(
		"보상: 💰 %d  💎 %d" % [int(quest.get("reward_gold", 0)), int(quest.get("reward_gems", 0))],
		13,
		Color(1.0, 0.85, 0.4)
	)
	bottom.add_child(reward)

	var claim := UiStyle.make_button("보상 받기", Vector2(120, 38), true)
	claim.disabled = claimed or not complete
	if claimed:
		claim.text = "수령 완료"
	elif not complete:
		claim.text = "진행 중"
	claim.pressed.connect(func(): _claim_quest(str(quest.get("id", ""))))
	bottom.add_child(claim)
	return panel

func _claim_quest(quest_id: String):
	var quest: Dictionary = {}
	for q in GameData.quests:
		if str(q.get("id", "")) == quest_id:
			quest = q
			break
	if quest.is_empty():
		return
	var gold := int(quest.get("reward_gold", 0))
	var gems := int(quest.get("reward_gems", 0))
	if GameData.claim_quest(quest_id):
		UiFeedback.show_reward("퀘스트 보상 획득!", ["💰 골드 +%d" % gold, "💎 젬 +%d" % gems])
		_refresh()
	else:
		UiFeedback.show_error("아직 보상을 받을 수 없습니다.")
