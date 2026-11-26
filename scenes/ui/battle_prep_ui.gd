extends CanvasLayer

const REFERENCE_SCREEN := preload("res://scripts/reference_screen.gd")

signal closed()

const GATE_ART := preload("res://assets/ui/dungeon_gate_v2.png")
const STAGE_TAB_NAMES := {"stage_1": "초원 외곽", "stage_2": "안개 숲", "stage_3": "지하 묘지"}

var current_stage_id := ""
var stage_buttons := {}
var art: TextureRect
var stage_name: Label
var chapter: Label
var record: Label
var briefing: PanelContainer
var objective: Label
var enemies: Label
var rewards: Label
var start_button: Button
var hero_container: Control
var approved: REFERENCE_SCREEN
var legacy_frame: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	$Backdrop.color = UiStyle.SCRIM
	var layout := UiStyle.dialog_layout(self, "")
	var frame := layout.get_parent().get_parent() as PanelContainer
	legacy_frame = frame
	frame.clip_contents = true
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := UiStyle.notice_board()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(UiStyle.make_title("던전 선택", 31))
	var close_button := UiStyle.make_button("×", Vector2(56, 62))
	close_button.tooltip_text = "닫기"
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	UiStyle.divider(layout)

	var selector := ScrollContainer.new()
	selector.custom_minimum_size.y = 61
	selector.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	selector.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(selector)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_child(tabs)
	for id in GameData.stages:
		var stage: Dictionary = GameData.stages[id]
		var button := UiStyle.make_button(str(STAGE_TAB_NAMES.get(id, stage.get("name", id))), Vector2(0, 58))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_select_stage.bind(str(id)))
		tabs.add_child(button)
		stage_buttons[id] = button

	var hero := Control.new()
	hero_container = hero
	hero.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y * 0.28, 210, 460)
	hero.clip_contents = true
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(hero)
	art = TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = GATE_ART
	hero.add_child(art)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(UiStyle.ASPHALT, 0.0), UiStyle.ASPHALT])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0.48)
	texture.fill_to = Vector2(0, 1)
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(shade)
	var caption := VBoxContainer.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 18
	caption.offset_right = -18
	caption.offset_bottom = -16
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hero.add_child(caption)
	chapter = UiStyle.make_label("", 17, UiStyle.GOLD_BRIGHT)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.ink_outline(chapter)
	caption.add_child(chapter)
	stage_name = UiStyle.make_title("", 36)
	stage_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.ink_outline(stage_name, 6)
	stage_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_child(stage_name)
	briefing = PanelContainer.new()
	briefing.add_theme_stylebox_override("panel", UiStyle.art_panel())
	layout.add_child(briefing)
	var report := VBoxContainer.new()
	report.add_theme_constant_override("separation", 6)
	briefing.add_child(report)
	objective = _briefing_row(report, "목표")
	enemies = _briefing_row(report, "등장 적")
	rewards = _briefing_row(report, "보상")
	record = _briefing_row(report, "최고 기록")
	start_button = UiStyle.make_button("던전 입장", Vector2(280, 58), true)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.add_theme_font_size_override("font_size", 21)
	start_button.pressed.connect(_on_start_battle_pressed)
	layout.add_child(start_button)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()


func _briefing_row(parent: Control, caption: String) -> Label:
	if parent.get_child_count() > 0:
		UiStyle.divider(parent)
	var compact := get_viewport().get_visible_rect().size.x < 600.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var title := UiStyle.make_label(caption, 16 if compact else 19, UiStyle.MUTED)
	title.custom_minimum_size.x = 76 if compact else 94
	row.add_child(title)
	var label := UiStyle.make_label("", 18 if compact else 20, UiStyle.IVORY)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	return label


func _fit_layout() -> void:
	if hero_container == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 600.0
	hero_container.custom_minimum_size.y = clampf(viewport_size.y * (0.24 if compact else 0.28), 190.0, 460.0)
	if stage_name:
		stage_name.add_theme_font_size_override("font_size", 27 if compact else 32)


func open(stage_id: String = "") -> void:
	current_stage_id = stage_id if GameData.stages.has(stage_id) else str(GameData.stages.keys().front())
	get_tree().paused = true
	show()
	_select_stage(current_stage_id)
	if approved == null:
		_build_approved_stages()
	legacy_frame.hide()


func _build_approved_stages() -> void:
	approved = REFERENCE_SCREEN.new()
	var screen := approved
	screen.build(self, "stage")
	screen.hit(Rect2(483, 13, 60, 65), "닫기", close)
	screen.mask(Rect2(13, 103, 533, 72), Rect2(14, 92, 70, 11))
	var index := 0
	for id in stage_buttons:
		var source: Button = stage_buttons[id]
		var stage_id := str(id)
		var tab := screen.styled_button(Rect2(17 + index * 178, 108, 169, 60), source.text, func(): source.pressed.emit())
		screen.updates.append(func():
			var selected := stage_id == current_stage_id
			tab.text = source.text
			tab.tooltip_text = source.tooltip_text
			if not tab.has_meta("selected") or bool(tab.get_meta("selected")) != selected:
				tab.set_meta("selected", selected)
				UiStyle.skin_button(tab, UiStyle.SELECTED if selected else UiStyle.INK_SOFT, UiStyle.AMBER if selected else UiStyle.STEEL, UiStyle.IVORY)
		)
		index += 1
	var hero := screen.artwork(Rect2(0, 183, 552, 346), null)
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var first := str(GameData.stages.keys().front())
	screen.updates.append(func():
		hero.visible = current_stage_id != first
		hero.texture = art.texture if GameData.is_stage_unlocked(current_stage_id) else GATE_ART
	)
	screen.show_label(stage_name, Rect2(36, 536, 480, 65), 39, HORIZONTAL_ALIGNMENT_CENTER)
	screen.field(Rect2(179, 629, 334, 52), func():
		return chapter.text if start_button.disabled else objective.text
	, 24, HORIZONTAL_ALIGNMENT_RIGHT)
	screen.field(Rect2(177, 704, 339, 56), func():
		return "—" if start_button.disabled else rewards.text
	, 20, HORIZONTAL_ALIGNMENT_RIGHT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.field(Rect2(99, 702, 84, 49), func(): return "보상", 25)
	screen.live_text(Rect2(35, 767, 482, 29), func(): return "" if start_button.disabled else "최고 기록  %s" % record.text, 19, HORIZONTAL_ALIGNMENT_CENTER)
	screen.mask(Rect2(47, 818, 455, 65), Rect2(35, 818, 67, 65))
	screen.live_text(Rect2(46, 820, 459, 61), func(): return start_button.text, 39, HORIZONTAL_ALIGNMENT_CENTER)
	screen.relay(Rect2(21, 799, 511, 99), start_button)


func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()


func _select_stage(stage_id: String) -> void:
	current_stage_id = stage_id
	var stage: Dictionary = GameData.stages[stage_id]
	var unlocked := GameData.is_stage_unlocked(stage_id)
	briefing.visible = unlocked
	if not unlocked:
		art.visible = false
		stage_name.text = str(stage.get("name", stage_id))
		chapter.text = GameData.get_stage_lock_reason(stage_id)
		start_button.disabled = true
		start_button.text = "잠긴 던전"
	else:
		var art_path := str(stage.get("art", ""))
		var selected_art := load(art_path) as Texture2D if not art_path.is_empty() else null
		art.texture = GATE_ART if selected_art == null else selected_art
		art.show()
		stage_name.text = str(stage.get("name", stage_id))
		chapter.text = "%s  ·  %s" % [stage.get("chapter", ""), stage.get("difficulty", "")]
		objective.text = "무한 생존 · 첫 보스 %s" % UiStyle.format_time(GameManager.FIRST_BOSS_TIME)
		enemies.text = ", ".join(stage.get("monster_types", []))
		rewards.text = "보스 장비 · 처치 골드\n포탈 귀환 100% / 사망 50%"
		var best := GameData.get_stage_best_survival(stage_id)
		record.text = "%s  ·  %s" % [
			UiStyle.format_time(best) if best > 0.0 else "—",
			"클리어" if stage.get("cleared", false) else "미클리어"
		]
		start_button.disabled = false
		start_button.text = "던전 입장"
		GameData.current_selected_stage_id = stage_id
	for id in stage_buttons:
		var button: Button = stage_buttons[id]
		var entry: Dictionary = GameData.stages[id]
		button.text = str(STAGE_TAB_NAMES.get(id, entry.get("name", id)))
		if not GameData.is_stage_unlocked(id):
			button.text = "🔒 " + button.text
			button.tooltip_text = GameData.get_stage_lock_reason(id)
		else:
			button.tooltip_text = str(entry.get("name", id))
		var chosen: bool = id == stage_id
		UiStyle.skin_button(button, UiStyle.SELECTED if chosen else UiStyle.INK_SOFT,
			UiStyle.AMBER if chosen else UiStyle.STEEL, UiStyle.IVORY)
		button.add_theme_font_size_override("font_size", 17)


func _on_start_battle_pressed() -> void:
	if GameData.is_stage_unlocked(current_stage_id):
		close()
		GameManager.go_to_battle(current_stage_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or GameActions.is_capturing():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif GameActions.get_action_for_event(event) == "battle_start":
		_on_start_battle_pressed()
		get_viewport().set_input_as_handled()
