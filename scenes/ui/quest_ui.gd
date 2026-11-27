extends CanvasLayer

const REFERENCE_SCREEN := preload("res://scripts/reference_screen.gd")

signal closed()

var _list: VBoxContainer
var _summary: Label
var _approved: REFERENCE_SCREEN
var _legacy_root: Control
var _approved_quests: Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	visible = false
	_build_ui()
	GameData.data_updated.connect(_refresh)

func _build_ui():
	var root := Control.new()
	_legacy_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = UiStyle.SCRIM
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := UiStyle.make_panel()
	center.add_child(panel)
	var portrait := UiStyle.fit_modal(panel, Vector2(700, 1050))
	get_viewport().size_changed.connect(func():
		var safe := UiStyle.safe_insets(get_viewport())
		UiStyle.fit_modal(panel, Vector2(700, 1050), Vector2(16 + maxf(safe.x, safe.z), 24 + maxf(safe.y, safe.w)))
	)

	var margin := UiStyle.make_margin(panel, 16 if portrait else 24)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	header.add_child(UiStyle.icon_view("quest", 28))
	var title := UiStyle.make_title("퀘스트", 29)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiStyle.make_button("✕", Vector2(52, 48))
	close.pressed.connect(close_screen)
	header.add_child(close)

	_summary = UiStyle.make_label("", 16, UiStyle.MUTED)
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
	if _approved == null:
		_build_approved_quest_screen()
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
		_list.remove_child(child)
		child.queue_free()

	var claimable := 0
	var claimed_count := 0
	var in_progress := 0
	var display_quests := GameData.quests.filter(_can_claim)
	display_quests.append_array(GameData.quests.filter(func(quest: Dictionary): return not _can_claim(quest)))
	for quest in display_quests:
		if bool(quest.get("claimed", false)):
			claimed_count += 1
		if not quest.get("claimed", false) and int(quest.get("current", 0)) >= int(quest.get("target", 1)):
			claimable += 1
		elif not quest.get("claimed", false):
			in_progress += 1
		_list.add_child(_make_quest_card(quest))
	_summary.text = "진행 중 %d개  ·  수령 가능 %d개  ·  수령 완료 %d개" % [
		in_progress, claimable, claimed_count
	]
	_refresh_approved_quests(display_quests)


func _build_approved_quest_screen() -> void:
	_approved = REFERENCE_SCREEN.new()
	_approved.build(self, "quest")
	_approved.smithy(Rect2(0, 103, 552, 831), Rect2(20, 231, 518, 597))
	_approved.solid(Rect2(9, 218, 534, 650), Color("#14110ed1"))
	_approved.hit(Rect2(487, 31, 57, 62), "닫기", close_screen)
	_approved.live_text(Rect2(30, 158, 492, 40), func(): return _summary.text, 24, HORIZONTAL_ALIGNMENT_CENTER)
	_legacy_root.hide()


func _refresh_approved_quests(quests: Array) -> void:
	if not _approved:
		return
	if _approved_quests:
		_approved.page.remove_child(_approved_quests)
		_approved_quests.queue_free()
	_approved_quests = Control.new()
	_approved_quests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_approved.page.add_child(_approved_quests)
	_approved.place(_approved_quests, Rect2(23, 223, 508, 637))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_approved_quests.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 13)
	scroll.add_child(rows)
	for quest in quests:
		var claimable := _can_claim(quest)
		var claimed := bool(quest.get("claimed", false))
		var target := maxi(1, int(quest.get("target", 1)))
		var current := clampi(int(quest.get("current", 0)), 0, target)
		var card := Panel.new()
		card.custom_minimum_size.y = 144
		rows.add_child(card)
		var band := Rect2(22, 241, 508, 248) if claimable else Rect2(22, 515, 508, 140)
		card.add_theme_stylebox_override("panel", _approved.trim(band, 13, false))
		var inside := ColorRect.new()
		inside.color = Color("#29231d")
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside.offset_left = 16
		inside.offset_right = -16
		inside.offset_top = 13
		inside.offset_bottom = -13
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inside)
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_left = 21
		stack.offset_right = -21
		stack.offset_top = 15
		stack.add_theme_constant_override("separation", 2)
		card.add_child(stack)
		var row := HBoxContainer.new()
		stack.add_child(row)
		var icon_name := "skill" if str(quest.get("id")) in ["q_slay_50", "q_first_battle"] else "quest"
		row.add_child(UiStyle.icon_view(icon_name, 32))
		var heading := UiStyle.make_label(str(quest.get("title", "")), 29)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(heading)
		var status_text := "수령 완료" if claimed else ("수령 가능" if claimable else "%d / %d" % [current, target])
		var status_color := UiStyle.GOLD_BRIGHT if claimable else (UiStyle.RECOVERY if claimed else UiStyle.MUTED)
		row.add_child(UiStyle.make_label(status_text, 22, status_color))
		var description := UiStyle.make_label(str(quest.get("desc", "")), 17, UiStyle.MUTED)
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stack.add_child(description)
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 11
		progress.show_percentage = false
		progress.max_value = target
		progress.value = current
		progress.add_theme_stylebox_override("background", UiStyle.frame(UiStyle.ASPHALT, UiStyle.RUST))
		progress.add_theme_stylebox_override("fill", UiStyle.frame(UiStyle.RECOVERY if current >= target else UiStyle.AMBER, Color.TRANSPARENT))
		stack.add_child(progress)
		var reward := HBoxContainer.new()
		stack.add_child(reward)
		var coins := UiStyle.make_label("%d G  ·  젬 %d" % [int(quest.get("reward_gold", 0)), int(quest.get("reward_gems", 0))], 20)
		coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reward.add_child(coins)
		if claimable:
			var claim := UiStyle.make_button("보상 받기", Vector2(135, 41), true)
			claim.pressed.connect(_claim_quest.bind(str(quest.get("id", ""))))
			reward.add_child(claim)

func _can_claim(quest: Dictionary) -> bool:
	return not bool(quest.get("claimed", false)) and int(quest.get("current", 0)) >= int(quest.get("target", 1))

func _make_quest_card(quest: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.art_panel(UiStyle.AMBER if _can_claim(quest) else UiStyle.STEEL))

	var margin := UiStyle.make_margin(panel, 14)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	top.add_child(UiStyle.icon_view("quest", 25))
	var title := UiStyle.make_title(str(quest.get("title", "퀘스트")), 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var claimed: bool = quest.get("claimed", false)
	var current: int = int(quest.get("current", 0))
	var target: int = int(quest.get("target", 1))
	var complete := current >= target
	var status_text := "수령 완료" if claimed else ("수령 가능" if complete else "%d / %d" % [min(current, target), target])
	var status_color := UiStyle.GOLD_BRIGHT if complete and not claimed else (UiStyle.RECOVERY if claimed else Color(0.65, 0.78, 0.95))
	var status := UiStyle.make_label(status_text, 13, status_color)
	top.add_child(status)

	var description := UiStyle.make_label(str(quest.get("desc", "")), 16, UiStyle.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(description)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 18)
	progress.max_value = target
	progress.value = min(current, target)
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", UiStyle.panel_style(UiStyle.ASPHALT, UiStyle.STEEL_DARK, 1))
	progress.add_theme_stylebox_override("fill", UiStyle.panel_style(UiStyle.RECOVERY if complete else UiStyle.AMBER, UiStyle.STEEL, 1))
	vbox.add_child(progress)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom)

	bottom.add_child(UiStyle.icon_view("coin", 23, UiStyle.GOLD_BRIGHT))
	var reward := UiStyle.make_label(
		"%d G · 💎 %d" % [int(quest.get("reward_gold", 0)), int(quest.get("reward_gems", 0))],
		16, UiStyle.GOLD_BRIGHT
	)
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(reward)
	if _can_claim(quest):
		var claim := UiStyle.make_button("보상 받기", Vector2(110, 48), true)
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
