extends CanvasLayer

signal closed()

const GATE_ART := preload("res://assets/ui/dungeon_gate_v2.png")
const STAGE_PREVIEW_SCENE := preload("res://scenes/ui/stage_preview_world.tscn")

var current_stage_id := ""
var stage_buttons := {}
var art: TextureRect
var stage_name: Label
var chapter: Label
var record: Label
var details: Label
var rewards: Label
var start_button: Button
var stage_preview: SubViewportContainer
var stage_preview_viewport: SubViewport


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	var layout := UiStyle.dialog_layout(self, "")
	var frame := layout.get_parent().get_parent() as PanelContainer
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel", UiStyle.frame(Color(0.105, 0.058, 0.052, 0.80), Color("#7c5039"), 18))
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := UiStyle.plaque("던전 선택", Color("#4f2927"), Color("#ad7451"), UiStyle.AMBER, 35)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close_button := UiStyle.make_button("×", Vector2(56, 62))
	close_button.tooltip_text = "닫기"
	UiStyle.skin_button(close_button, Color("#572e27"), Color("#c38757"))
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	UiStyle.divider(layout)

	var selector := ScrollContainer.new()
	selector.custom_minimum_size.y = 96
	selector.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(selector)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_child(tabs)
	for id in GameData.stages:
		var stage: Dictionary = GameData.stages[id]
		var button := UiStyle.make_button(str(stage.get("name", id)), Vector2(172, 78))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var thumbnail := load(str(stage.get("art", ""))) as Texture2D if GameData.is_stage_unlocked(str(id)) else null
		if thumbnail:
			button.icon = thumbnail
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_constant_override("icon_max_width", 52)
			button.add_theme_constant_override("h_separation", 8)
		button.pressed.connect(_select_stage.bind(str(id)))
		tabs.add_child(button)
		stage_buttons[id] = button

	var body := UiStyle.scroll_column(layout)
	var reward_plate := UiStyle.plaque("", Color("#493020"), Color("#a37846"), UiStyle.AMBER, 20)
	body.add_child(reward_plate)
	rewards = reward_plate.get_child(0) as Label
	rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hero := Control.new()
	hero.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y * 0.49, 300, 730)
	hero.clip_contents = true
	body.add_child(hero)
	stage_preview = SubViewportContainer.new()
	stage_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_preview.stretch = true
	if OS.has_feature("android"):
		stage_preview.stretch_shrink = 2
		stage_preview.resized.connect(_refresh_stage_preview)
	stage_preview.visible = false
	hero.add_child(stage_preview)
	art = TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = GATE_ART
	hero.add_child(art)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.03, 0.025, 0.03, 0.0), Color("#22130f")])
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
	details = _paragraph(body)
	UiStyle.divider(body)
	record = _paragraph(body)
	start_button = UiStyle.make_button("던전 입장", Vector2(280, 74), true)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.skin_button(start_button, Color("#913c33"), Color("#edaf70"))
	start_button.add_theme_font_size_override("font_size", 25)
	start_button.pressed.connect(_on_start_battle_pressed)
	layout.add_child(start_button)


func _refresh_stage_preview() -> void:
	if stage_preview_viewport != null and visible and stage_preview.is_visible_in_tree():
		var mode := SubViewport.UPDATE_ONCE if OS.has_feature("android") else SubViewport.UPDATE_WHEN_VISIBLE
		stage_preview_viewport.render_target_update_mode = mode


func _paragraph(parent: Control) -> Label:
	var label := UiStyle.make_label("", 21)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_constant_override("line_spacing", 6)
	parent.add_child(label)
	return label


func open(stage_id: String = "") -> void:
	current_stage_id = stage_id if GameData.stages.has(stage_id) else str(GameData.stages.keys().front())
	get_tree().paused = true
	show()
	_select_stage(current_stage_id)


func close() -> void:
	stage_preview.hide()
	if stage_preview_viewport != null:
		stage_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
	get_tree().paused = false
	closed.emit()


func _select_stage(stage_id: String) -> void:
	current_stage_id = stage_id
	var stage: Dictionary = GameData.stages[stage_id]
	var unlocked := GameData.is_stage_unlocked(stage_id)
	if not unlocked:
		stage_preview.visible = false
		art.visible = false
		chapter.text = ""
		stage_name.text = "업데이트 예정"
		details.text = ""
		rewards.text = ""
		record.text = ""
		start_button.disabled = true
		start_button.text = "업데이트 예정"
	else:
		var art_path := str(stage.get("art", ""))
		var selected_art := load(art_path) as Texture2D if not art_path.is_empty() else null
		art.texture = GATE_ART if selected_art == null else selected_art
		var has_live_preview := not str(stage.get("preview_scene", "")).is_empty()
		if has_live_preview and stage_preview_viewport == null:
			stage_preview_viewport = SubViewport.new()
			stage_preview_viewport.name = "StagePreviewViewport"
			stage_preview_viewport.own_world_3d = true
			stage_preview_viewport.add_child(STAGE_PREVIEW_SCENE.instantiate())
			stage_preview.add_child(stage_preview_viewport)
		stage_preview.visible = has_live_preview
		if stage_preview_viewport != null:
			stage_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_refresh_stage_preview()
		art.visible = not has_live_preview
		stage_name.text = str(stage.get("name", stage_id))
		chapter.text = "%s  ·  %s" % [stage.get("chapter", ""), stage.get("difficulty", "")]
		details.text = "무한 생존  ·  첫 보스 %s\n등장 적  %s\n처치 골드  ·  포탈 귀환 100%% / 사망 50%%" % [
			UiStyle.format_time(GameManager.FIRST_BOSS_TIME), ", ".join(stage.get("monster_types", []))
		]
		rewards.text = "보스 처치 시 보상 장비 획득"
		var best := GameData.get_stage_best_survival(stage_id)
		record.text = "%s  ·  던전 최고 기록 %s" % [
			"클리어" if stage.get("cleared", false) else "미클리어",
			UiStyle.format_time(best) if best > 0.0 else "—"
		]
		start_button.disabled = false
		start_button.text = "던전 입장"
		GameData.current_selected_stage_id = stage_id
	for id in stage_buttons:
		var button: Button = stage_buttons[id]
		var entry: Dictionary = GameData.stages[id]
		if not GameData.is_stage_unlocked(id):
			button.text = "업데이트 예정"
			button.icon = null
			button.tooltip_text = "업데이트 예정인 스테이지입니다."
		else:
			button.text = str(entry.get("name", id))
			var thumbnail := load(str(entry.get("art", ""))) as Texture2D
			button.icon = thumbnail
			button.tooltip_text = ""
		var chosen: bool = id == stage_id
		UiStyle.skin_button(button, Color("#8a5636") if chosen else Color("#3f312e"), UiStyle.AMBER if chosen else Color("#806455"))
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
