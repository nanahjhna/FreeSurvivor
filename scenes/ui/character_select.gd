extends Control

const REFERENCE_SCREEN := preload("res://scripts/reference_screen.gd")

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CLASS_GROWTH := {
	"fighter": "기동성과 근접 타격", "char01": "근접 검술", "char02": "원소 마법과 광역 공격",
	"archer": "라이플 단발, 연사, 관통 사격", "mage": "마법 광역 공격과 원소 폭발",
	"paladin": "높은 체력과 방어, 자가 회복"
}
const CLASS_WEAPONS := {
	"fighter": "권갑", "char01": "검", "char02": "지팡이", "archer": "쌍드럼 라이플", "mage": "원소 지팡이",
	"paladin": "성검과 방패"
}
const STAT_EXPLANATIONS := {
	"STR": "물리 스킬 피해를 높입니다. 현재 능력치가 직업 기본값보다 1 높아질 때 물리 공격력이 2 증가합니다.",
	"AGI": "이동 속도를 높입니다. 전투에서 캐릭터가 더 빠르게 움직일 수 있습니다.",
	"VIT": "최대 HP를 높입니다. 직업 기본값보다 1 높아질 때 최대 HP가 8 증가합니다.",
	"INT": "마법 스킬 공격력을 높입니다. 마법 계열 스킬의 피해 계산에 사용됩니다.",
	"DEX": "스킬 시전 속도를 높입니다. 액티브 스킬 애니메이션과 타격 시점이 빨라지며, 쿨다운은 줄이지 않습니다.",
	"LUK": "치명타 확률을 높입니다. 현재 치명타 확률은 최대 75%까지 적용됩니다."
}

enum ScreenMode { SELECT, CREATE }

var screen_mode := ScreenMode.SELECT
var screen_root: Control
var selected_character_id := ""
var selected_class_id := GameData.FIGHTER_ID
var creation_slot := -1

var slot_list: HBoxContainer
var class_list: BoxContainer
var detail_name: Label
var detail_subtitle: Label
var detail_name_row: HBoxContainer
var detail_stats_grid: GridContainer
var detail_stat_cells: Array[Control] = []
var detail_equipment_row: HBoxContainer
var detail_equipment_cells: Array[Label] = []
var detail_progress: Label
var detail_progress_block: VBoxContainer
var feedback_label: Label
var delete_button: Button
var new_character_button: Button
var delete_dialog: ConfirmationDialog
var stat_info_dialog: AcceptDialog
var create_button: Button

var preview_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_player: PlayerCharacter
var preview_camera: Camera3D
var preview_visual: Node3D
const PREVIEW_CAMERA_SIZE := 3.35
var preview_zoom: float = 1.0
var creation_name: LineEdit
var creation_roster: VBoxContainer
const PREVIEW_ZOOM_MIN := 0.55
const PREVIEW_ZOOM_MAX := 1.55
const PREVIEW_ZOOM_STEP := 0.12
var _dragging := false
var _last_drag_position := Vector2.ZERO
var _preview_rotation := 0.0
var _idle_time := 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.current_location = GameManager.Location.CHARACTER_SELECT
	_show_selection(GameData.last_selected_character_id)


func _show_selection(preferred_id: String = ""):
	screen_mode = ScreenMode.SELECT
	_clear_screen()
	var layout := _build_shell("캐릭터 선택", "", GameManager.go_to_title)
	var body := _new_body(layout)

	if _is_portrait_layout():
		_build_preview(body)
		_build_portrait_details(body)
		_build_slot_section(body)
		var management := HBoxContainer.new()
		management.add_theme_constant_override("separation", 8)
		body.add_child(management)
		new_character_button = _create_new_character_button()
		management.add_child(new_character_button)
		delete_button = _create_delete_button()
		management.add_child(delete_button)

	else:
		_build_slot_section(body)
		_build_preview(_make_section(body, 560, "선택한 캐릭터 · 드래그하여 회전"))
		var info_section := _make_section(body, 430, "캐릭터 정보")
		_build_detail_panel(info_section)
		new_character_button = _create_new_character_button()
		info_section.add_child(new_character_button)
		delete_button = _create_delete_button()
		info_section.add_child(delete_button)

	feedback_label = _add_feedback(layout, "")
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "캐릭터 영구 삭제"
	delete_dialog.ok_button_text = "삭제"
	delete_dialog.cancel_button_text = "취소"
	delete_dialog.confirmed.connect(_confirm_delete)
	screen_root.add_child(delete_dialog)
	stat_info_dialog = AcceptDialog.new()
	stat_info_dialog.title = "능력치 설명"
	stat_info_dialog.ok_button_text = "확인"
	screen_root.add_child(stat_info_dialog)

	selected_character_id = preferred_id
	if not GameData.character_profiles.has(selected_character_id):
		selected_character_id = GameData.last_selected_character_id
	if not GameData.character_profiles.has(selected_character_id):
		selected_character_id = _first_profile_id()
	_populate_slots()
	_update_selected_profile()
	_build_approved_selection(layout)


func _show_creation(slot_index: int):
	if slot_index < 0 or slot_index >= GameData.get_character_slot_count():
		return
	if not GameData.get_profile_at_slot(slot_index).is_empty():
		return
	screen_mode = ScreenMode.CREATE
	creation_slot = slot_index
	selected_class_id = ""
	for character in CharacterRegistry.all():
		if GameData.get_character_class_error(character.id).is_empty():
			selected_class_id = character.id
			break
	_clear_screen()
	var layout := _build_shell("캐릭터 생성", "뒤로", _show_selection)
	var body := _new_body(layout)

	if _is_portrait_layout():
		_build_preview(body)
		_build_portrait_details(body)
		_build_creation_roster(_make_section(body, 0, "직업 선택"))
	else:
		_build_detail_panel(_make_section(body, 330, ""))
		_build_preview(_make_section(body, 480, ""))
		_build_creation_roster(_make_section(body, 216, "직업 선택"))

	creation_name = LineEdit.new()
	creation_name.placeholder_text = "캐릭터 이름"
	creation_name.max_length = GameData.CHARACTER_NAME_MAX_LENGTH
	creation_name.custom_minimum_size.y = 51
	creation_name.add_theme_font_size_override("font_size", 21)
	creation_name.add_theme_color_override("font_color", UiStyle.IVORY)
	creation_name.add_theme_color_override("font_placeholder_color", UiStyle.MUTED)
	creation_name.add_theme_stylebox_override("normal", UiStyle.art_panel())
	creation_name.add_theme_stylebox_override("focus", UiStyle.frame(Color.TRANSPARENT, UiStyle.AMBER))
	layout.add_child(creation_name)

	create_button = UiStyle.make_button("캐릭터 생성", Vector2(0, 60), true)
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_button.add_theme_font_size_override("font_size", 22 if _is_portrait_layout() else 18)
	create_button.tooltip_text = "선택한 직업으로 새 캐릭터를 생성합니다."
	create_button.pressed.connect(_create_character)
	layout.add_child(create_button)

	feedback_label = _add_feedback(layout, "")
	_populate_classes()
	creation_roster.visible = class_list.get_child_count() > 1 or selected_class_id.is_empty()
	if _is_portrait_layout():
		detail_stats_grid.hide()
	if selected_class_id.is_empty():
		_update_create_button()
		feedback_label.text = "생성 가능한 직업을 불러올 수 없습니다."
	else:
		_select_class(selected_class_id)
	_build_approved_creation(layout)


func _approved_preview(approved: REFERENCE_SCREEN, region: Rect2, layout: VBoxContainer) -> void:
	approved.smithy(region, Rect2(146, 90, 259, 372))
	preview_viewport.transparent_bg = true
	(preview_viewport.get_child(0) as WorldEnvironment).environment.background_mode = Environment.BG_CLEAR_COLOR
	(preview_viewport.get_child(3) as MeshInstance3D).hide()
	preview_camera.look_at_from_position(Vector3(0, 1.89, 5), Vector3(0, 1.36, 0))
	preview_zoom = 0.91
	_apply_preview_zoom()
	approved.native(preview_container, region)
	(layout.get_parent().get_parent().get_parent() as Control).hide()


func _approved_profile_name(profile: Dictionary) -> String:
	if profile.is_empty():
		return "빈 슬롯"
	var character: Dictionary = profile.get("state", {}).get("characters", {}).get(str(profile.get("class_id", "")), {})
	var level := int(character.get("level", int(character.get("growth_level", 0)) + 1))
	return "%s LV.%d" % [str(profile.get("name", character.get("role", ""))), maxi(1, level)]


func _build_approved_selection(layout: VBoxContainer) -> void:
	var approved := REFERENCE_SCREEN.new()
	approved.build(screen_root, "select")
	_approved_preview(approved, Rect2(0, 73, 552, 403), layout)
	approved.mask(Rect2(222, 476, 292, 51), Rect2(18, 485, 90, 43))
	approved.live_text(Rect2(220, 478, 315, 50), func():
		var profile := GameData.get_character_profile(selected_character_id)
		return "저장된 캐릭터 없음" if profile.is_empty() else _approved_profile_name(profile)
	, 39)
	for index in range(StatManager.STAT_KEYS.size()):
		var x := [119, 285, 457][index % 3] as int
		var y := 546 + floori(index / 3.0) * 49
		approved.field(Rect2(x, y, 34, 37), func():
			if index >= detail_stat_cells.size():
				return "—"
			var source := detail_stat_cells[index].get_child(0) as Label
			return source.text.get_slice(" ", 1)
		, 27, HORIZONTAL_ALIGNMENT_CENTER)
		approved.hit(Rect2(x + 31, y - 7, 41, 50), "능력치 설명", func():
			if index < detail_stat_cells.size():
				(detail_stat_cells[index].get_child(1) as Button).pressed.emit()
		)
	approved.solid(Rect2(19, 662, 514, 128), Color("#201b17"))
	var slots := ScrollContainer.new()
	slots.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	approved.page.add_child(slots)
	slots.add_child(row)
	approved.place(slots, Rect2(22, 665, 508, 123))
	for index in range(GameData.get_character_slot_count()):
		var button := UiStyle.make_button("", Vector2(245, 110))
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(func():
			if GameData.get_profile_at_slot(index).is_empty():
				_on_empty_slot_pressed(index)
			else:
				_on_slot_pressed(index)
		)
		row.add_child(button)
		var standard := approved.trim(Rect2(281, 669, 242, 107), 17, false)
		var sync := func():
			var profile := GameData.get_profile_at_slot(index)
			var caption := ("＋  " if profile.is_empty() else "⚔  ") + _approved_profile_name(profile)
			var active := not profile.is_empty() and str(profile.get("id", "")) == selected_character_id
			if caption == button.text and active == button.has_meta("active_slot"):
				return
			button.text = caption
			if active:
				button.set_meta("active_slot", true)
			elif button.has_meta("active_slot"):
				button.remove_meta("active_slot")
			UiStyle.skin_button(button, UiStyle.SELECTED if active else UiStyle.INK_SOFT, UiStyle.AMBER if active else UiStyle.STEEL, UiStyle.IVORY)
			if not active:
				button.add_theme_stylebox_override("normal", standard)
		sync.call()
		approved.updates.append(sync)
	approved.relay(Rect2(24, 811, 236, 78), delete_button)
	approved.relay(Rect2(272, 811, 256, 78), new_character_button)
	approved.live_text(Rect2(19, 897, 514, 31), func(): return feedback_label.text, 19, HORIZONTAL_ALIGNMENT_CENTER)


func _build_approved_creation(layout: VBoxContainer) -> void:
	var approved := REFERENCE_SCREEN.new()
	approved.build(screen_root, "create")
	_approved_preview(approved, Rect2(0, 73, 552, 419), layout)
	approved.hit(Rect2(17, 17, 56, 55), "뒤로", _show_selection)
	approved.mask(Rect2(266, 498, 225, 66), Rect2(399, 502, 95, 61))
	approved.live_text(Rect2(260, 499, 245, 65), func():
		var character := GameData.get_class_template_data(selected_class_id)
		return str(character.get("name", character.get("role", "")))
	, 45)
	if creation_roster.visible:
		approved.native(creation_roster, Rect2(34, 583, 482, 70))
	approved.mask(Rect2(123, 670, 223, 60), Rect2(389, 670, 107, 60))
	creation_name.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	creation_name.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	creation_name.add_theme_font_size_override("font_size", 31)
	approved.native(creation_name, Rect2(123, 663, 373, 71))
	approved.relay(Rect2(27, 792, 504, 89), create_button)
	approved.live_text(Rect2(19, 895, 514, 35), func(): return feedback_label.text, 20, HORIZONTAL_ALIGNMENT_CENTER)

func _build_creation_roster(section: VBoxContainer) -> void:
	creation_roster = section
	var portrait := _is_portrait_layout()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 96) if portrait else Vector2(132, 304)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if portrait else Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if portrait else ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if portrait else ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 24
	section.add_child(scroll)
	class_list = HBoxContainer.new() if portrait else VBoxContainer.new()
	class_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_list.add_theme_constant_override("separation", 12)
	scroll.add_child(class_list)

func _clear_screen():
	preview_player = null
	preview_camera = null
	preview_visual = null
	preview_viewport = null
	preview_container = null
	new_character_button = null
	delete_button = null
	create_button = null
	creation_name = null
	creation_roster = null
	stat_info_dialog = null
	_dragging = false
	if is_instance_valid(screen_root):
		remove_child(screen_root)
		screen_root.queue_free()


func _build_shell(title_text: String, back_text: String, back_action: Callable) -> VBoxContainer:
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = UiStyle.ASPHALT
	screen_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(center)
	var panel := UiStyle.make_panel()
	var safe := UiStyle.safe_insets(get_viewport())
	center.offset_left = safe.x
	center.offset_top = safe.y
	center.offset_right = -safe.z
	center.offset_bottom = -safe.w
	var viewport_size := get_viewport_rect().size
	if _is_portrait_layout():
		panel.custom_minimum_size = Vector2(minf(viewport_size.x - safe.x - safe.z - 26.0, 710.0), viewport_size.y - safe.y - safe.w - 42.0)
	else:
		panel.custom_minimum_size = Vector2(minf(1540.0, viewport_size.x - 48.0), minf(880.0, viewport_size.y - 48.0))
	center.add_child(panel)
	var margin := UiStyle.make_margin(panel, 16 if _is_portrait_layout() else 22)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10 if _is_portrait_layout() else 14)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var header_plate := UiStyle.notice_board()
	layout.add_child(header_plate)
	header_plate.add_child(header)
	if not title_text.is_empty():
		var title := UiStyle.make_title(title_text, 32)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.add_child(title)
	if not back_text.is_empty():
		var back := UiStyle.make_button(back_text, Vector2(96, 52))
		back.tooltip_text = "이전 화면으로 돌아갑니다. [Esc]"
		back.pressed.connect(back_action)
		header.add_child(back)
		header.move_child(back, 0)
	if not title_text.is_empty():
		UiStyle.divider(layout)
	return layout


func _new_body(layout: VBoxContainer) -> Control:
	if _is_portrait_layout():
		# Keep the screen itself fixed. Only data-heavy lists may scroll.
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 8)
		layout.add_child(body)
		return body
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	layout.add_child(body)
	return body


func _make_section(parent: Control, width: float, heading: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(0 if _is_portrait_layout() else width, 0)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if _is_portrait_layout() else Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)
	parent.add_child(section)
	if not heading.is_empty():
		section.add_child(UiStyle.make_label(heading, 19, UiStyle.GOLD_BRIGHT))
	return section


func _build_slot_section(parent: Control):
	var section := _make_section(parent, 350, "")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 74.0 if _is_portrait_layout() else 120.0
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if _is_portrait_layout() else Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 24
	section.add_child(scroll)
	slot_list = HBoxContainer.new()
	slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_list.add_theme_constant_override("separation", 8)
	scroll.add_child(slot_list)


func _create_delete_button() -> Button:
	var button := UiStyle.make_button("🗑 캐릭터 삭제", Vector2(0, 44))
	UiStyle.skin_button(button, UiStyle.DANGER, UiStyle.DANGER_EDGE, UiStyle.IVORY)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "선택한 캐릭터의 저장 데이터만 삭제합니다."
	button.pressed.connect(_request_delete)
	return button

func _create_new_character_button() -> Button:
	var button := UiStyle.make_button("새 캐릭터", Vector2(0, 48), true)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_create_in_first_empty_slot)
	return button


func _build_portrait_details(parent: Control) -> void:
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiStyle.art_panel())
	parent.add_child(sheet)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	sheet.add_child(content)
	_build_detail_panel(content)


func _build_detail_panel(panel: VBoxContainer):
	var portrait := _is_portrait_layout()
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	panel.add_child(name_row)
	detail_name_row = name_row
	detail_name = UiStyle.make_title("", 27 if portrait else 31)
	detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(detail_name)
	detail_subtitle = UiStyle.make_label("", 16, UiStyle.MUTED)
	detail_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(detail_subtitle)
	UiStyle.divider(panel)
	var stats_grid := GridContainer.new()
	stats_grid.add_theme_constant_override("h_separation", 6)
	stats_grid.add_theme_constant_override("v_separation", 2)
	stats_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_child(stats_grid)
	detail_stats_grid = stats_grid
	detail_stats_grid.columns = 3
	var equipment_row := HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 12)
	# Equipment text is intentionally hidden on the character selection screen;
	# equipment is managed from the village equipment menu.
	equipment_row.visible = false
	panel.add_child(equipment_row)
	detail_equipment_row = equipment_row
	var detail_equipment_weapon := UiStyle.make_label("", 14, Color(1.0, 0.84, 0.42))
	var detail_equipment_armor := UiStyle.make_label("", 14, Color(1.0, 0.84, 0.42))
	var detail_equipment_skill := UiStyle.make_label("", 14, Color(1.0, 0.84, 0.42))
	detail_equipment_cells.clear()
	detail_equipment_cells.append(detail_equipment_weapon)
	detail_equipment_cells.append(detail_equipment_armor)
	detail_equipment_cells.append(detail_equipment_skill)
	for detail_equipment_cell in detail_equipment_cells:
		detail_equipment_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_equipment_cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_equipment_row.add_child(detail_equipment_cell)
	var progress_block := VBoxContainer.new()
	progress_block.add_theme_constant_override("separation", 2)
	panel.add_child(progress_block)
	detail_progress_block = progress_block
	detail_progress = UiStyle.make_label("", 15, UiStyle.MUTED)
	detail_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_progress.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progress_block.add_child(detail_progress)

func _populate_stat_grid(stats: StatManager, class_id: String) -> void:
	for child in detail_stats_grid.get_children():
		detail_stats_grid.remove_child(child)
		child.queue_free()
	detail_stat_cells.clear()
	var stat_cell_texts: Array = [
		"STR %d" % stats.get_stat("STR"),
		"AGI %d" % stats.get_stat("AGI"),
		"VIT %d" % stats.get_stat("VIT"),
		"INT %d" % stats.get_stat("INT"),
		"DEX %d" % stats.get_stat("DEX"),
		"LUK %d" % stats.get_stat("LUK"),
	]
	var stat_keys := ["STR", "AGI", "VIT", "INT", "DEX", "LUK"]
	for index in range(stat_cell_texts.size()):
		var stat_cell := HBoxContainer.new()
		stat_cell.add_theme_constant_override("separation", 2)
		stat_cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var stat_label := UiStyle.make_label(str(stat_cell_texts[index]), 16, UiStyle.IVORY)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stat_cell.add_child(stat_label)
		var info_button := UiStyle.make_button("!", Vector2(24, 24))
		info_button.add_theme_font_size_override("font_size", 14)
		info_button.tooltip_text = "%s 능력치 설명" % stat_keys[index]
		info_button.pressed.connect(_show_stat_info.bind(stat_keys[index], stats))
		stat_cell.add_child(info_button)
		detail_stats_grid.add_child(stat_cell)
		detail_stat_cells.append(stat_cell)


func _show_stat_info(stat_name: String, stats: StatManager) -> void:
	if not is_instance_valid(stat_info_dialog):
		return
	var value := stats.get_stat(stat_name)
	var current_effect := ""
	match stat_name:
		"STR": current_effect = "현재 물리 공격력: %d" % int(round(stats.phys_atk()))
		"AGI": current_effect = "현재 이동 속도 배율: %d%%" % int(round(stats.move_speed_multiplier() * 100.0))
		"VIT": current_effect = "현재 최대 HP: %d" % int(round(stats.max_hp()))
		"INT": current_effect = "현재 마법 공격력: %d" % int(round(stats.mag_atk()))
		"DEX": current_effect = "현재 시전 속도: %d%%" % int(round(stats.cast_speed() * 100.0))
		"LUK": current_effect = "현재 치명타 확률: %d%%" % int(round(stats.crit_rate()))
	stat_info_dialog.title = "%s  %d · 능력치 설명" % [stat_name, value]
	stat_info_dialog.dialog_text = "%s\n\n%s" % [str(STAT_EXPLANATIONS.get(stat_name, "이 능력치의 설명이 준비되지 않았습니다.")), current_effect]
	var width := mini(560, int(get_viewport_rect().size.x) - 26)
	stat_info_dialog.popup_centered(Vector2i(width, 250))


func _add_feedback(layout: VBoxContainer, text: String) -> Label:
	var label := UiStyle.make_label(text, 13, UiStyle.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(label)
	return label


func _is_portrait_layout() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.y >= viewport_size.x


func _populate_slots():
	new_character_button.disabled = GameData.find_empty_character_slot() < 0
	for child in slot_list.get_children():
		slot_list.remove_child(child)
		child.queue_free()
	for index in range(GameData.get_character_slot_count()):
		var profile := GameData.get_profile_at_slot(index)
		if profile.is_empty():
			var empty_button := UiStyle.make_button("＋ 빈 슬롯", Vector2(144, 62))
			empty_button.add_theme_font_size_override("font_size", 17)
			empty_button.tooltip_text = "새 캐릭터를 만들 수 있는 슬롯입니다."
			empty_button.pressed.connect(_on_empty_slot_pressed.bind(index))
			slot_list.add_child(empty_button)
			continue
		var class_data := GameData.get_profile_class_data(profile)
		var id := str(profile.get("id", ""))
		var caption := "%s  %s" % [class_data.get("icon", "⚔"), profile.get("name", class_data.get("role", ""))]
		var button := UiStyle.make_button(caption, Vector2(144, 62), id == selected_character_id)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_on_slot_pressed.bind(index))
		slot_list.add_child(button)


func _on_empty_slot_pressed(index: int) -> void:
	_show_creation(index)


func _on_slot_pressed(index: int):
	var profile := GameData.get_profile_at_slot(index)
	if profile.is_empty():
		return
	var id := str(profile.get("id", ""))
	if selected_character_id == id:
		_enter_selected_character()
		return
	selected_character_id = id
	if not GameData.select_character_profile(id):
		feedback_label.text = "캐릭터 선택을 저장하지 못했습니다."
		return
	_populate_slots()
	_update_selected_profile()
	if feedback_label:
		feedback_label.text = "선택한 캐릭터를 다시 누르면 마을에 입장합니다."


func _update_selected_profile():
	var profile := GameData.get_character_profile(selected_character_id)
	var exists := not profile.is_empty()
	if is_instance_valid(preview_visual):
		preview_visual.visible = exists
	if is_instance_valid(delete_button):
		delete_button.disabled = not exists
	if not exists:
		detail_name.text = "저장된 캐릭터 없음"
		detail_subtitle.text = "새 캐릭터를 생성하세요."
		detail_subtitle.visible = true
		for detail_stat_grid_child in detail_stats_grid.get_children():
			detail_stats_grid.remove_child(detail_stat_grid_child)
			detail_stat_grid_child.queue_free()
		detail_stat_cells.clear()
		detail_equipment_cells[0].text = ""
		detail_equipment_cells[1].text = ""
		detail_equipment_cells[2].text = ""
		detail_progress.text = ""
		_set_preview_class(GameData.FIGHTER_ID, {})
		return
	var class_id := str(profile.get("class_id", GameData.FIGHTER_ID))
	var class_data := GameData.get_profile_class_data(profile)
	var stats := GameData.get_profile_stat_manager(profile)
	var state: Dictionary = profile.get("state", {})
	var saved: Dictionary = state.get("characters", {}).get(class_id, {})
	var saved_level := int(saved.get("level", int(saved.get("growth_level", 0)) + 1))
	if _is_portrait_layout():
		detail_name.text = "%s  %s  ·  LV.%d" % [str(class_data.get("icon", "⚔️")), str(profile.get("name", "")), maxi(1, saved_level)]
		detail_subtitle.text = ""
		detail_subtitle.visible = false
	else:
		detail_name.text = "%s  %s" % [str(class_data.get("icon", "⚔️")), str(profile.get("name", ""))]
		detail_subtitle.text = "캐릭터 Lv.%d" % maxi(1, saved_level)
		detail_subtitle.visible = true
	_populate_stat_grid(stats, class_id)
	var equipment := _get_profile_equipment(profile)
	detail_equipment_cells[0].text = str(equipment.weapon)
	detail_equipment_cells[1].text = str(equipment.armor)
	detail_equipment_cells[2].text = str(class_data.get("signature_skill", ""))
	if _is_portrait_layout():
		detail_progress.text = _passive_text(class_id)
	else:
		detail_progress.text = "최고 생존 시간  %s\n최고 서바이벌 레벨  %d\n총 플레이 시간  %s\n마지막 접속  %s" % [
			_format_survival_time(float(profile.get("best_survival_time", 0.0))), int(profile.get("best_survival_level", 1)),
			_format_play_time(int(profile.get("play_time_seconds", 0))), str(profile.get("last_played_at", "아직 접속하지 않음"))]
	_set_preview_class(class_id, class_data)


func _passive_text(class_id: String) -> String:
	for skill in CharacterSkillDatabase.get_skill_set(class_id).values():
		if skill.get("cast_type") == "passive":
			return "고유 패시브  %s" % str(skill.get("name", ""))
	return ""


func _get_profile_equipment(profile: Dictionary) -> Dictionary:
	var state_value: Variant = profile.get("state", {})
	var state: Dictionary = state_value if state_value is Dictionary else {}
	var class_id := str(profile.get("class_id", GameData.FIGHTER_ID))
	var gear_value: Variant = state.get("equipped_gear", {})
	var gear_by_class: Dictionary = gear_value if gear_value is Dictionary else {}
	var equipped_value: Variant = gear_by_class.get(class_id, {})
	var equipped: Dictionary = equipped_value if equipped_value is Dictionary else {}
	var registered_character := CharacterRegistry.get_by_id(class_id)
	var default_weapon := "없음"
	if registered_character != null and registered_character.weapon_scene != null:
		default_weapon = registered_character.weapon_name
	var result := {"weapon": default_weapon, "armor": "없음"}
	for item in state.get("inventory", []):
		if not item is Dictionary:
			continue
		if str(item.get("id", "")) == str(equipped.get("weapon", "__none__")):
			result.weapon = str(item.get("name", "없음"))
		if str(item.get("id", "")) == str(equipped.get("armor", "__none__")):
			result.armor = str(item.get("name", "없음"))
	return result


func _format_play_time(total_seconds: int) -> String:
	return "%d시간 %02d분" % [int(total_seconds / 3600.0), int((total_seconds % 3600) / 60.0)]

func _format_survival_time(total_seconds: float) -> String:
	return "%02d:%02d" % [int(total_seconds / 60.0), int(total_seconds) % 60]


func _first_profile_id() -> String:
	for index in range(GameData.get_character_slot_count()):
		var profile := GameData.get_profile_at_slot(index)
		if not profile.is_empty():
			return str(profile.get("id", ""))
	return ""


func _create_in_first_empty_slot():
	var empty_slot := GameData.find_empty_character_slot()
	if empty_slot < 0:
		feedback_label.text = "사용 가능한 슬롯이 없습니다."
		return
	_show_creation(empty_slot)


func _enter_selected_character():
	if selected_character_id.is_empty():
		if feedback_label:
			feedback_label.text = "선택된 캐릭터가 없습니다."
		return
	var profile := GameData.get_character_profile(selected_character_id)
	if profile.is_empty():
		if feedback_label:
			feedback_label.text = "캐릭터 데이터를 찾을 수 없습니다."
		return
	if not GameData.activate_character_profile(selected_character_id):
		if feedback_label:
			feedback_label.text = "캐릭터 데이터를 불러오지 못했습니다."
			feedback_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		return
	if feedback_label:
		feedback_label.text = "마을로 입장 중..."
		feedback_label.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	GameManager.go_to_lobby()


func _request_delete():
	var profile := GameData.get_character_profile(selected_character_id)
	if profile.is_empty():
		return
	delete_dialog.dialog_text = (
		"캐릭터를 삭제하시겠습니까?\n\n캐릭터: %s\n직업: %s\n\n영구 능력치, 기록, 장비, 인벤토리가 모두 삭제되며 복구할 수 없습니다.\n다른 캐릭터 데이터에는 영향을 주지 않습니다."
		% [str(profile.get("name", "")), str(profile.get("class_id", ""))])
	delete_dialog.popup_centered(Vector2i(620, 340))


func _confirm_delete():
	var deleted_name := str(GameData.get_character_profile(selected_character_id).get("name", ""))
	if not GameData.delete_character_profile(selected_character_id):
		feedback_label.text = "캐릭터를 삭제하지 못했습니다."
		return
	selected_character_id = GameData.last_selected_character_id
	_populate_slots()
	_update_selected_profile()
	feedback_label.text = "'%s' 캐릭터를 삭제했습니다." % deleted_name


func _populate_classes():
	for child in class_list.get_children():
		child.queue_free()
	for data in CharacterRegistry.all():
		var class_id := data.id
		var character := GameData.get_class_template_data(class_id)
		var class_error := GameData.get_character_class_error(class_id)
		var button := UiStyle.make_button("%s\n%s" % [character.get("icon", "⚔"), character.get("role", class_id)], Vector2(118, 74 if _is_portrait_layout() else 92))
		button.add_theme_font_size_override("font_size", 22)
		button.disabled = not class_error.is_empty()
		if button.disabled:
			button.text += " · 잠김"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = class_error if button.disabled else str(character.get("desc", ""))
		button.set_meta("class_id", class_id)
		button.pressed.connect(_select_class.bind(class_id))
		class_list.add_child(button)


func _select_class(class_id: String):
	var character := GameData.get_class_template_data(class_id)
	if character.is_empty():
		return
	selected_class_id = class_id
	var stats := GameData.get_class_template_stat_manager(class_id)
	var display_class_name := str(character.get("name", character.get("role", class_id)))
	var class_level := maxi(1, int(character.get("level", 1)))
	if _is_portrait_layout():
		detail_name.text = "%s  %s  ·  LV.%d" % [str(character.get("icon", "⚔️")), display_class_name, class_level]
		detail_subtitle.text = ""
		detail_subtitle.visible = false
	else:
		detail_name.text = "%s  %s" % [str(character.get("icon", "⚔️")), display_class_name]
		detail_subtitle.text = "캐릭터 Lv.%d" % class_level
		detail_subtitle.visible = true
	_populate_stat_grid(stats, class_id)
	var registered_character := CharacterRegistry.get_by_id(class_id)
	var weapon_name := str(character.get("weapon_name", CLASS_WEAPONS.get(class_id, "기본 무기")))
	if registered_character != null and registered_character.weapon_scene != null:
		weapon_name = registered_character.weapon_name
	detail_equipment_cells[0].text = weapon_name
	detail_equipment_cells[1].text = "없음"
	detail_equipment_cells[2].text = str(character.get("signature_skill", ""))
	detail_progress.text = str(character.get("desc", ""))
	for child in class_list.get_children():
		if child is Button:
			var is_selected := str(child.get_meta("class_id", "")) == class_id
			child.button_pressed = is_selected
			UiStyle.skin_button(child, UiStyle.SELECTED if is_selected else UiStyle.INK_SOFT,
				UiStyle.AMBER if is_selected else UiStyle.STEEL, UiStyle.IVORY)
	_set_preview_class(class_id, character)
	_update_create_button()


func _update_create_button():
	if not is_instance_valid(create_button):
		return
	var creation_error := GameData.get_character_creation_error(creation_slot, selected_class_id)
	create_button.disabled = not creation_error.is_empty()
	if create_button.disabled:
		create_button.tooltip_text = creation_error
		return
	var character_template := GameData.get_class_template_data(selected_class_id)
	var job_name := str(character_template.get("name", character_template.get("role", "무도가")))
	create_button.text = "캐릭터 생성"
	create_button.tooltip_text = "'%s' 캐릭터를 생성합니다." % job_name


func _create_character():
	var creation_error := GameData.get_character_creation_error(creation_slot, selected_class_id)
	if not creation_error.is_empty():
		feedback_label.text = creation_error
		return
	var character_template := GameData.get_class_template_data(selected_class_id)
	var job_name := str(character_template.get("name", character_template.get("role", "무도가")))
	var profile_name := creation_name.text.strip_edges() if is_instance_valid(creation_name) else ""
	if profile_name.is_empty():
		profile_name = job_name
	var name_error := GameData.get_character_name_error(profile_name)
	if not name_error.is_empty():
		feedback_label.text = name_error
		return
	var new_id := GameData.create_character_profile(creation_slot, selected_class_id, profile_name)
	if new_id.is_empty():
		if feedback_label:
			feedback_label.text = "캐릭터를 저장하지 못했습니다."
		return
	_show_selection(new_id)
	if feedback_label:
		feedback_label.text = "'%s' 캐릭터를 생성했습니다." % profile_name
		feedback_label.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)


func _build_preview(parent: Control):
	preview_zoom = 1.0
	preview_container = SubViewportContainer.new()
	var viewport_size := get_viewport_rect().size
	var portrait := _is_portrait_layout()
	var preview_height := clampf(viewport_size.y * 0.36, 220.0, 490.0) if portrait else 570.0
	var preview_width := 200.0 if portrait else 550.0
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.stretch = true
	if OS.has_feature("android"):
		preview_container.stretch_shrink = 2
	preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_container.gui_input.connect(_on_preview_input)
	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(preview_width + 4.0, preview_height + 4.0)
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.add_theme_stylebox_override("panel", UiStyle.art_panel())
	parent.add_child(preview_frame)
	var preview_stack := Control.new()
	preview_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_frame.add_child(preview_stack)
	preview_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_stack.add_child(preview_container)
	var zoom_box := PanelContainer.new()
	zoom_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom_box.offset_left = -156.0
	zoom_box.offset_top = -52.0
	zoom_box.offset_right = -8.0
	zoom_box.offset_bottom = -8.0
	zoom_box.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(UiStyle.ASPHALT, 0.88), UiStyle.STEEL, 1))
	preview_stack.add_child(zoom_box)
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 4)
	zoom_box.add_child(zoom_row)
	var zoom_out := UiStyle.make_button("−", Vector2(42, 38))
	zoom_out.tooltip_text = "캐릭터 미리보기 축소"
	zoom_out.pressed.connect(_adjust_preview_zoom.bind(1.0 + PREVIEW_ZOOM_STEP))
	zoom_row.add_child(zoom_out)
	var zoom_reset := UiStyle.make_button("기본", Vector2(54, 38))
	zoom_reset.tooltip_text = "미리보기 배율을 기본값으로 되돌립니다."
	zoom_reset.pressed.connect(_reset_preview_zoom)
	zoom_row.add_child(zoom_reset)
	var zoom_in := UiStyle.make_button("+", Vector2(42, 38), true)
	zoom_in.tooltip_text = "캐릭터 미리보기 확대"
	zoom_in.pressed.connect(_adjust_preview_zoom.bind(1.0 / (1.0 + PREVIEW_ZOOM_STEP)))
	zoom_row.add_child(zoom_in)
	preview_viewport = SubViewport.new()
	preview_viewport.own_world_3d = true
	preview_viewport.size = Vector2i(int(preview_width), int(preview_height))
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	preview_container.add_child(preview_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = UiStyle.INK_SOFT
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.96, 0.78, 0.58)
	environment.ambient_light_energy = 0.9
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	preview_viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -28, 0)
	light.light_color = Color(1.0, 0.77, 0.48)
	light.light_energy = 1.35
	preview_viewport.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 149, 0)
	rim.light_color = Color("#df9f61")
	rim.light_energy = 1.3
	preview_viewport.add_child(rim)
	var floor := MeshInstance3D.new()
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 1.25
	floor_mesh.bottom_radius = 1.34
	floor_mesh.height = 0.12
	floor.mesh = floor_mesh
	floor.position.y = -0.06
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = UiStyle.WOOD
	floor_material.roughness = 0.94
	floor.material_override = floor_material
	preview_viewport.add_child(floor)
	preview_player = PLAYER_SCENE.instantiate() as PlayerCharacter
	preview_player.preview_only = true
	preview_player.process_mode = Node.PROCESS_MODE_DISABLED
	preview_player.is_combat_enabled = false
	preview_viewport.add_child(preview_player)
	preview_visual = preview_player.get_node("VisualRoot")
	preview_camera = Camera3D.new()
	preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	preview_viewport.add_child(preview_camera)
	preview_camera.look_at_from_position(Vector3(0, 1.9, 5), Vector3(0, 1.25, 0))
	preview_camera.make_current()
	_apply_preview_zoom()


func _set_preview_class(class_id: String, character: Dictionary):
	if not is_instance_valid(preview_visual) or not is_instance_valid(preview_player):
		return
	var fallback := GameData.get_class_template_data(class_id)
	var color_value: Variant = character.get("color", fallback.get("color", Color(0.25, 0.55, 0.9)))
	preview_player.set_character_appearance(class_id)
	if is_instance_valid(preview_player.model_animation_player):
		preview_player.model_animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if class_id == "fighter_2d":
		_update_preview_color(color_value if color_value is Color else Color(0.25, 0.55, 0.9))
	_update_preview_weapon(class_id)
	_preview_rotation = deg_to_rad(28.0) if class_id in ["archer", "char01"] else 0.0
	_idle_time = 0.0


func _update_preview_color(color: Color):
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.25
	material.roughness = 0.45
	for node in preview_visual.find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(node) and not node.has_meta("preview_prop"):
			(node as MeshInstance3D).material_override = material


func _update_preview_weapon(class_id: String):
	if not is_instance_valid(preview_visual):
		return
	for child in preview_visual.get_children():
		if child.has_meta("preview_prop"):
			child.queue_free()
	var sword_node := preview_visual.get_node_or_null("ArmR/Sword")
	var sword: MeshInstance3D = sword_node as MeshInstance3D if is_instance_valid(sword_node) else null
	if sword:
		sword.visible = class_id in ["warrior", "paladin"]
	match class_id:
		"mage": _add_preview_staff(Color(0.95, 0.35, 0.2))
		"paladin":
			var shield := BoxMesh.new()
			shield.size = Vector3(0.45, 0.66, 0.13)
			_add_preview_prop(shield, Vector3(0.58, 0.83, -0.12), Vector3(0, 0, -0.12), Color(0.85, 0.72, 0.3))
		"assassin":
			var blade := BoxMesh.new()
			blade.size = Vector3(0.07, 0.72, 0.045)
			_add_preview_prop(blade, Vector3(-0.49, 0.98, -0.12), Vector3(0, 0, 0.2), Color(0.7, 0.82, 0.95))
			_add_preview_prop(blade, Vector3(0.49, 0.98, -0.12), Vector3(0, 0, -0.2), Color(0.7, 0.82, 0.95))
		"priest": _add_preview_staff(Color(0.45, 0.8, 1.0))


func _add_preview_staff(crystal_color: Color):
	var staff := CylinderMesh.new()
	staff.top_radius = 0.035
	staff.bottom_radius = 0.055
	staff.height = 1.2
	_add_preview_prop(staff, Vector3(0.56, 0.86, -0.1), Vector3.ZERO, Color(0.48, 0.31, 0.2))
	var crystal := SphereMesh.new()
	crystal.radius = 0.16
	crystal.height = 0.32
	_add_preview_prop(crystal, Vector3(0.56, 1.57, -0.1), Vector3.ZERO, crystal_color)


func _add_preview_prop(mesh: Mesh, pos: Vector3, rotation_value: Vector3, color: Color):
	var prop := MeshInstance3D.new()
	prop.mesh = mesh
	prop.position = pos
	prop.rotation = rotation_value
	prop.set_meta("preview_prop", true)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	prop.material_override = material
	preview_visual.add_child(prop)


func _process(delta: float):
	if preview_visual == null:
		return
	_idle_time += delta
	preview_visual.rotation.y = _preview_rotation + sin(_idle_time * 0.7) * 0.08
	preview_visual.position.y = sin(_idle_time * 2.0) * 0.025


func _adjust_preview_zoom(multiplier: float):
	preview_zoom = clampf(preview_zoom * multiplier, PREVIEW_ZOOM_MIN, PREVIEW_ZOOM_MAX)
	_apply_preview_zoom()


func _reset_preview_zoom():
	preview_zoom = 1.0
	_apply_preview_zoom()


func _apply_preview_zoom():
	if preview_camera == null:
		return
	preview_camera.size = PREVIEW_CAMERA_SIZE * preview_zoom


func _on_preview_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_last_drag_position = event.position
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_preview_zoom(1.0 / (1.0 + PREVIEW_ZOOM_STEP))
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_preview_zoom(1.0 + PREVIEW_ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		_preview_rotation += (event.position.x - _last_drag_position.x) * 0.01
		_last_drag_position = event.position
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_last_drag_position = event.position
	elif event is InputEventScreenDrag and _dragging:
		_preview_rotation += event.relative.x * 0.01


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if screen_mode == ScreenMode.CREATE:
			_show_selection(GameData.last_selected_character_id)
		else:
			GameManager.go_to_title()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if screen_mode == ScreenMode.CREATE:
			_create_character()
		else:
			_enter_selected_character()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and screen_mode == ScreenMode.SELECT:
		if event.keycode == KEY_N:
			_create_in_first_empty_slot()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DELETE and not selected_character_id.is_empty():
			_request_delete()
			get_viewport().set_input_as_handled()
