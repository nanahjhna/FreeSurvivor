extends CanvasLayer

signal closed()

const STAGE_CARD_TEXTURES := [
	preload("res://assets/ui/stage_grassland.png"),
	preload("res://assets/ui/stage_forest.png"),
	preload("res://assets/ui/stage_crypt.png")
]

@onready var stage_title_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/TopRow/StageTitle
@onready var chapter_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/TopRow/ChapterLabel
@onready var diff_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/TopRow/DiffLabel
@onready var desc_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/DescLabel
@onready var monsters_lbl: Label = $Panel/Margin/VBox/Body/StageInfo/Margin/VBox/MonstersLabel

@onready var power_lbl: Label = $Panel/Margin/VBox/Body/FighterPreview/PowerLabel

@onready var reward_gold_lbl: Label = $Panel/Margin/VBox/Body/RewardBox/Margin/HBox/GoldLabel
@onready var reward_xp_lbl: Label = $Panel/Margin/VBox/Body/RewardBox/Margin/HBox/XPLabel
@onready var reward_items_lbl: Label = $Panel/Margin/VBox/Body/RewardBox/Margin/HBox/ItemsLabel

@onready var stage_tabs: Container = $Panel/Margin/VBox/StageTabs
@onready var start_button: Button = $Panel/Margin/VBox/BottomRow/StartBattleBtn
@onready var stage_tab_buttons: Array[Button] = [
	$Panel/Margin/VBox/StageTabs/Stage1Btn,
	$Panel/Margin/VBox/StageTabs/Stage2Btn,
	$Panel/Margin/VBox/StageTabs/Stage3Btn
]

var current_stage_id: String = "stage_1"
var stage_ids: Array[String] = ["stage_1", "stage_2", "stage_3"]
var stage_scroll: ScrollContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	UiStyle.apply_button(start_button, true)
	UiStyle.apply_button($Panel/Margin/VBox/BottomRow/CancelBtn as Button)
	for tab in stage_tab_buttons:
		UiStyle.apply_button(tab)
	_apply_menu_layout()
	_build_stage_cards()


func _apply_menu_layout():
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.y >= viewport_size.x
	var panel := $Panel as PanelContainer
	if portrait:
		var panel_size := Vector2(minf(viewport_size.x - 24.0, 560.0), minf(viewport_size.y - 48.0, 900.0))
		panel.custom_minimum_size = panel_size
		panel.offset_left = -panel_size.x * 0.5
		panel.offset_right = panel_size.x * 0.5
		panel.offset_top = -panel_size.y * 0.5
		panel.offset_bottom = panel_size.y * 0.5
		var margin := $Panel/Margin as MarginContainer
		for side in ["margin_left", "margin_right"]:
			margin.add_theme_constant_override(side, 12)
		for side in ["margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(side, 12)
		for tab in stage_tab_buttons:
			tab.custom_minimum_size = Vector2(panel_size.x - 40.0, 150.0)
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Put stage title, chapter, and difficulty on separate lines so their
		# combined text widths cannot push the panel beyond a narrow phone screen.
		var stage_info_vbox := $Panel/Margin/VBox/Body/StageInfo/Margin/VBox as VBoxContainer
		var chapter_parent := chapter_lbl.get_parent()
		chapter_parent.remove_child(chapter_lbl)
		chapter_parent.remove_child(diff_lbl)
		stage_info_vbox.add_child(chapter_lbl)
		stage_info_vbox.add_child(diff_lbl)
		stage_info_vbox.move_child(chapter_lbl, 1)
		stage_info_vbox.move_child(diff_lbl, 2)
		chapter_lbl.add_theme_font_size_override("font_size", 12)
		diff_lbl.add_theme_font_size_override("font_size", 12)
		chapter_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Stack reward labels on phones instead of letting a long row get clipped.
		var reward_row := $Panel/Margin/VBox/Body/RewardBox/Margin/HBox as HBoxContainer
		var reward_parent := reward_row.get_parent()
		var reward_column := VBoxContainer.new()
		reward_column.add_theme_constant_override("separation", 6)
		for reward_label in [reward_gold_lbl, reward_xp_lbl, reward_items_lbl]:
			reward_row.remove_child(reward_label)
			reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reward_column.add_child(reward_label)
		reward_parent.remove_child(reward_row)
		reward_parent.add_child(reward_column)
		reward_row.queue_free()
		start_button.custom_minimum_size = Vector2(110, 30)
		start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		$Panel/Margin/VBox/BottomRow/CancelBtn.custom_minimum_size = Vector2(70, 28)
		$Panel/Margin/VBox/BottomRow/StartBattleBtn.add_theme_font_size_override("font_size", 14)
	else:
		var panel_size := Vector2(minf(880.0, viewport_size.x - 48.0), minf(580.0, viewport_size.y - 48.0))
		panel.custom_minimum_size = panel_size
		panel.offset_left = -panel_size.x * 0.5
		panel.offset_right = panel_size.x * 0.5
		panel.offset_top = -panel_size.y * 0.5
		panel.offset_bottom = panel_size.y * 0.5
		for tab in stage_tab_buttons:
			tab.custom_minimum_size = Vector2(190, 184)

func _build_stage_cards():
	var portrait := get_viewport().get_visible_rect().size.y >= get_viewport().get_visible_rect().size.x
	var old_tabs := stage_tabs
	stage_scroll = ScrollContainer.new()
	stage_scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y * 0.35, 360.0, 450.0) if portrait else 192.0
	stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if portrait else ScrollContainer.SCROLL_MODE_AUTO
	stage_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if portrait else ScrollContainer.SCROLL_MODE_DISABLED
	stage_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parent := old_tabs.get_parent()
	var index := old_tabs.get_index()
	parent.add_child(stage_scroll)
	parent.move_child(stage_scroll, index)
	if portrait:
		var vertical_tabs := VBoxContainer.new()
		vertical_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vertical_tabs.add_theme_constant_override("separation", 8)
		for tab in stage_tab_buttons:
			old_tabs.remove_child(tab)
			vertical_tabs.add_child(tab)
		old_tabs.queue_free()
		stage_scroll.add_child(vertical_tabs)
		stage_tabs = vertical_tabs
	else:
		old_tabs.reparent(stage_scroll)
		stage_tabs.add_theme_constant_override("separation", 8)
	for i in range(stage_tab_buttons.size()):
		var tab := stage_tab_buttons[i]
		var stage: Dictionary = GameData.stages.get(stage_ids[i], {})
		tab.text = ""
		tab.clip_contents = true
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var art := TextureRect.new()
		art.name = "StageArt"
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 3.0
		art.offset_top = 3.0
		art.offset_right = -3.0
		art.offset_bottom = -3.0
		art.texture = STAGE_CARD_TEXTURES[i]
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(art)
		var tint := ColorRect.new()
		tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tint.color = Color(0.055, 0.012, 0.008, 0.34)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(tint)
		var content := MarginContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			content.add_theme_constant_override(side, 10)
		tab.add_child(content)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(stack)
		var chapter := UiStyle.make_label("제 %d장" % (i + 1), 13, Color(1.0, 0.87, 0.54))
		chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(chapter)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(spacer)
		var title := UiStyle.make_label(str(stage.get("name", "지역")), 20 if portrait else 18, Color.WHITE)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.9))
		title.add_theme_constant_override("outline_size", 4)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(title)
		var reward_value: Variant = stage.get("rewards", {})
		var reward: Dictionary = reward_value if reward_value is Dictionary else {}
		var gold := UiStyle.make_label("◆  %d 골드" % int(reward.get("gold", 0)), 13, Color(1.0, 0.88, 0.51))
		gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(gold)
		var lock := UiStyle.make_label("🔒 잠김", 13, Color(0.88, 0.9, 0.97))
		lock.name = "LockLabel"
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(lock)
		tab.add_theme_stylebox_override("normal", _stage_card_style(false))
		tab.add_theme_stylebox_override("hover", _stage_card_style(true))
		tab.add_theme_stylebox_override("pressed", _stage_card_style(true))
		tab.add_theme_stylebox_override("disabled", _stage_card_style(false))

func _stage_card_style(selected: bool) -> StyleBoxFlat:
	var border := UiStyle.GOLD_BRIGHT if selected else Color(0.48, 0.34, 0.22, 0.86)
	var style := UiStyle.button_style(Color(0.065, 0.035, 0.03, 0.98), border)
	var width := 3 if selected else 1
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	return style

func open(stage_id: String = "stage_1"):
	current_stage_id = stage_id if GameData.is_stage_unlocked(stage_id) else "stage_1"
	GameData.current_selected_stage_id = current_stage_id
	get_tree().paused = true
	visible = true
	_refresh_ui()

func close():
	visible = false
	get_tree().paused = false
	closed.emit()

func _refresh_ui():
	var stage = GameData.stages.get(current_stage_id, GameData.stages["stage_1"])
	stage_title_lbl.text = stage.name
	chapter_lbl.text = stage.chapter
	diff_lbl.text = "난이도: " + stage.difficulty
	if GameData.is_stage_unlocked(current_stage_id):
		desc_lbl.text = stage.desc + "\n시작 카드 10장 · 5레벨마다 카드 선택"
	else:
		desc_lbl.text = stage.desc + "\n🔒 이전 지역 클리어가 필요합니다."
	monsters_lbl.text = "출현 몬스터  ·  " + ", ".join(stage.monster_types)
	start_button.disabled = not GameData.is_stage_unlocked(current_stage_id)
	if start_button.disabled:
		start_button.text = "🔒 잠긴 스테이지"
		start_button.tooltip_text = "이전 지역을 클리어해야 입장할 수 있습니다."
	else:
		start_button.text = "⚔️ 전투 시작 [F]"
		start_button.tooltip_text = "전투 전에 서바이벌 강화 카드 10장을 고릅니다. 이후 Lv.5마다 새 카드를 선택합니다."
	for i in range(stage_tab_buttons.size()):
		var tab := stage_tab_buttons[i]
		tab.disabled = not GameData.is_stage_unlocked(stage_ids[i])
		tab.button_pressed = stage_ids[i] == current_stage_id
		tab.tooltip_text = "" if not tab.disabled else "이전 지역 클리어 후 해금됩니다."
		var art := tab.get_node_or_null("StageArt") as TextureRect
		if art:
			art.modulate = Color(0.38, 0.42, 0.5, 1.0) if tab.disabled else (Color.WHITE if tab.button_pressed else Color(0.77, 0.82, 0.9, 1.0))
		var lock := tab.find_child("LockLabel", true, false) as Label
		if lock:
			lock.visible = tab.disabled
	call_deferred("_focus_selected_stage_card")
	
	reward_gold_lbl.text = "💰 골드: +" + str(stage.rewards.gold)
	reward_xp_lbl.text = "✨ 성장 재화: 생존 시간·처치·클리어에 따라 지급"
	reward_items_lbl.text = "🎁 클리어 카드 1장 · " + ", ".join(stage.rewards.items)
	
	var power = GameData.get_party_combat_power()
	power_lbl.text = "%s 전투력: %d  (권장: %d)" % [GameData.characters[GameData.get_leader_id()].name, power, stage.level_req * 180]

func _focus_selected_stage_card():
	if stage_scroll == null or not is_instance_valid(stage_scroll):
		return
	var index := stage_ids.find(current_stage_id)
	if index < 0 or index >= stage_tab_buttons.size():
		return
	var tab := stage_tab_buttons[index]
	if get_viewport().get_visible_rect().size.y >= get_viewport().get_visible_rect().size.x:
		stage_scroll.scroll_vertical = maxi(0, int(tab.position.y + tab.size.y * 0.5 - stage_scroll.size.y * 0.5))
	else:
		stage_scroll.scroll_horizontal = maxi(0, int(tab.position.x + tab.size.x * 0.5 - stage_scroll.size.x * 0.5))

func _on_stage_selected(stage_id: String):
	if not GameData.is_stage_unlocked(stage_id):
		return
	current_stage_id = stage_id
	GameData.current_selected_stage_id = stage_id
	_refresh_ui()

func _on_start_battle_pressed():
	if not GameData.is_stage_unlocked(current_stage_id):
		return
	close()
	GameManager.go_to_battle(current_stage_id)

func _on_close_pressed():
	close()

func _unhandled_input(event: InputEvent):
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
