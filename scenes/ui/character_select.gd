extends Control

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CLASS_GROWTH := {
	"fighter": "기동성과 근접 타격", "char02": "빠른 근접 전투와 연속 베기",
	"archer": "원거리 관통과 빠른 연사", "mage": "마법 광역 공격과 원소 폭발",
	"paladin": "높은 체력과 방어, 자가 회복"
}
const CLASS_WEAPONS := {
	"fighter": "권갑", "char02": "쌍검", "archer": "장궁", "mage": "원소 지팡이",
	"paladin": "성검과 방패"
}
const FIRST_NAMES: Array[String] = ["아린", "시온", "하린", "도윤", "유나", "태오", "세린", "라온"]
const LAST_NAMES: Array[String] = ["빛", "솔", "별", "린", "온", "하늘", "새벽", "바람"]

enum ScreenMode { SELECT, CREATE }

var screen_mode := ScreenMode.SELECT
var screen_root: Control
var selected_character_id := ""
var selected_class_id := GameData.FIGHTER_ID
var creation_slot := -1

var slot_list: HBoxContainer
var class_list: VBoxContainer
var detail_name: Label
var detail_subtitle: Label
var detail_stats: Label
var detail_equipment: Label
var detail_progress: Label
var feedback_label: Label
var delete_button: Button
var delete_dialog: ConfirmationDialog
var name_edit: LineEdit
var create_button: Button

var preview_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_player: CharacterBody3D
var preview_camera: Camera3D
var preview_visual: Node3D
var preview_camera_base_offset: Vector3 = Vector3(0.0, 4.5, 5.5)
var preview_zoom: float = 1.0
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
	var layout := _build_shell("캐릭터 선택", "← 타이틀", GameManager.go_to_title)
	var body := _new_body(layout)

	if _is_portrait_layout():
		var hero_row := HBoxContainer.new()
		hero_row.add_theme_constant_override("separation", 10)
		hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(hero_row)
		var preview_section := _make_section(hero_row, 352, "캐릭터")
		preview_section.custom_minimum_size.x = minf(352.0, get_viewport_rect().size.x * 0.53)
		_build_preview(preview_section)
		var details_section := _make_section(hero_row, 270, "정보")
		details_section.custom_minimum_size.x = minf(270.0, get_viewport_rect().size.x * 0.40)
		var detail_card := UiStyle.make_panel(UiStyle.INK_SOFT)
		detail_card.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.INK_SOFT, Color(0.62, 0.42, 0.23, 0.8), 1))
		detail_card.custom_minimum_size = Vector2(0, clampf(get_viewport_rect().size.y * 0.28, 270.0, 360.0))
		detail_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details_section.add_child(detail_card)
		var detail_margin := UiStyle.make_margin(detail_card, 10)
		var detail_content := VBoxContainer.new()
		detail_content.add_theme_constant_override("separation", 6)
		detail_margin.add_child(detail_content)
		_build_detail_panel(detail_content)
		delete_button = _create_delete_button()
		details_section.add_child(delete_button)
		_build_slot_section(body)
	else:
		_build_slot_section(body)
		_build_preview(_make_section(body, 560, "선택한 캐릭터 · 드래그하여 회전"))
		var info_section := _make_section(body, 430, "캐릭터 정보")
		_build_detail_panel(info_section)
		delete_button = _create_delete_button()
		info_section.add_child(delete_button)
	feedback_label = _add_feedback(layout, "캐릭터 슬롯을 누르면 바로 게임을 시작합니다.")

	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "캐릭터 영구 삭제"
	delete_dialog.ok_button_text = "삭제"
	delete_dialog.cancel_button_text = "취소"
	delete_dialog.confirmed.connect(_confirm_delete)
	screen_root.add_child(delete_dialog)

	selected_character_id = preferred_id
	if not GameData.character_profiles.has(selected_character_id):
		selected_character_id = GameData.last_selected_character_id
	if not GameData.character_profiles.has(selected_character_id):
		selected_character_id = _first_profile_id()
	_populate_slots()
	_update_selected_profile()


func _show_creation(slot_index: int):
	if slot_index < 0 or slot_index >= GameData.get_character_slot_count():
		return
	if not GameData.get_profile_at_slot(slot_index).is_empty():
		return
	screen_mode = ScreenMode.CREATE
	creation_slot = slot_index
	selected_class_id = GameData.FIGHTER_ID
	_clear_screen()
	var layout := _build_shell("새 캐릭터 만들기", "← 슬롯 선택", _show_selection)
	var instructions := UiStyle.make_label(
		"직업을 고르고 이름을 입력하면 빈 슬롯에 저장됩니다.\n직업 선택  →  이름 입력  →  캐릭터 생성",
		14,
		UiStyle.MUTED
	)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(instructions)
	var body := _new_body(layout)

	var left := _make_section(body, 330, "1. 직업 선택")
	var scroll := ScrollContainer.new()
	# Keep the nested class list tall enough to receive taps inside the outer
	# portrait-page ScrollContainer. Without a minimum height the section can
	# collapse and leave the class buttons clipped or covered on mobile layouts.
	if _is_portrait_layout():
		scroll.custom_minimum_size.y = clampf(get_viewport_rect().size.y * 0.30, 360.0, 400.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	class_list = VBoxContainer.new()
	class_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_list.add_theme_constant_override("separation", 8)
	scroll.add_child(class_list)
	_build_preview(_make_section(body, 560, "캐릭터 미리보기 · 드래그/터치로 회전"))
	_build_detail_panel(_make_section(body, 440, "선택한 직업 정보"))

	var footer: Container = VBoxContainer.new() if _is_portrait_layout() else HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)
	footer.add_child(UiStyle.make_label("2. 캐릭터 이름", 16, Color(1.0, 0.86, 0.45)))
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(360, 50)
	name_edit.max_length = GameData.CHARACTER_NAME_MAX_LENGTH
	name_edit.placeholder_text = "한글/영문/숫자, 최대 %d자" % GameData.CHARACTER_NAME_MAX_LENGTH
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.text_submitted.connect(func(_value): _create_character())
	footer.add_child(name_edit)
	var random_button := UiStyle.make_button("🎲 랜덤 이름", Vector2(180, 50))
	random_button.pressed.connect(_randomize_name)
	footer.add_child(random_button)
	create_button = UiStyle.make_button("캐릭터 생성", Vector2(220, 50), true)
	create_button.pressed.connect(_create_character)
	footer.add_child(create_button)
	if _is_portrait_layout():
		name_edit.custom_minimum_size = Vector2(0, 56)
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for action in [random_button, create_button]:
			action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action.custom_minimum_size.y = 58
	feedback_label = _add_feedback(layout, "생성 후 선택 화면으로 돌아오며 자동 접속하지 않습니다.")
	_populate_classes()
	_select_class(selected_class_id)
	name_edit.grab_focus()


func _clear_screen():
	preview_player = null
	preview_camera = null
	preview_visual = null
	preview_viewport = null
	preview_container = null
	_dragging = false
	if is_instance_valid(screen_root):
		screen_root.free()


func _build_shell(title_text: String, back_text: String, back_action: Callable) -> VBoxContainer:
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.014, 0.014, 1.0)
	screen_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(center)
	var panel := UiStyle.make_panel()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.035, 0.025, 0.024, 0.96), Color(0.76, 0.52, 0.27, 0.8), 2))
	var viewport_size := get_viewport_rect().size
	if _is_portrait_layout():
		panel.custom_minimum_size = Vector2(minf(viewport_size.x - 32.0, 680.0), viewport_size.y - 48.0)
	else:
		panel.custom_minimum_size = Vector2(minf(1540.0, viewport_size.x - 48.0), minf(880.0, viewport_size.y - 48.0))
	center.add_child(panel)
	var margin := UiStyle.make_margin(panel, 16 if _is_portrait_layout() else 22)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var header: Container = VBoxContainer.new() if _is_portrait_layout() else HBoxContainer.new()
	layout.add_child(header)
	var title := UiStyle.make_title(title_text, 23 if _is_portrait_layout() else 29)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := UiStyle.make_button(back_text, Vector2(170, 48))
	back.tooltip_text = "이전 화면으로 돌아갑니다. [Esc]"
	back.pressed.connect(back_action)
	header.add_child(back)
	return layout


func _new_body(layout: VBoxContainer) -> Control:
	if _is_portrait_layout():
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		layout.add_child(scroll)
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 14)
		scroll.add_child(body)
		return body
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	layout.add_child(body)
	return body


func _make_section(parent: Control, width: float, heading: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(0 if _is_portrait_layout() else width, 0)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if _is_portrait_layout() else Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)
	parent.add_child(section)
	section.add_child(UiStyle.make_label(heading, 17, Color(1.0, 0.86, 0.44)))
	return section


func _build_slot_section(parent: Control):
	var section := _make_section(parent, 350, "캐릭터 슬롯 · %d개" % GameData.get_character_slot_count())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 142.0 if _is_portrait_layout() else 160.0
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if _is_portrait_layout() else Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	section.add_child(scroll)
	slot_list = HBoxContainer.new()
	slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_list.add_theme_constant_override("separation", 8)
	scroll.add_child(slot_list)


func _create_delete_button() -> Button:
	var button := UiStyle.make_button("🗑 캐릭터 삭제", Vector2(0, 44))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "선택한 캐릭터의 저장 데이터만 삭제합니다."
	button.pressed.connect(_request_delete)
	return button


func _build_detail_panel(panel: VBoxContainer):
	var name_parent: Container = panel
	var stats_parent: Container = panel
	detail_name = UiStyle.make_title("", 20 if _is_portrait_layout() else 27)
	detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_parent.add_child(detail_name)
	detail_subtitle = UiStyle.make_label("", 14 if _is_portrait_layout() else 15, Color(0.82, 0.72, 0.58))
	detail_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_parent.add_child(detail_subtitle)
	if not _is_portrait_layout():
		panel.add_child(HSeparator.new())
	detail_stats = UiStyle.make_label("", 15, UiStyle.IVORY)
	detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_parent.add_child(detail_stats)
	detail_equipment = UiStyle.make_label("", 14, Color(1.0, 0.84, 0.42))
	detail_equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(detail_equipment)
	detail_progress = UiStyle.make_label("", 13, UiStyle.MUTED)
	detail_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_progress.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(detail_progress)


func _add_feedback(layout: VBoxContainer, text: String) -> Label:
	var label := UiStyle.make_label(text, 13, UiStyle.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(label)
	return label


func _is_portrait_layout() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.y >= viewport_size.x


func _populate_slots():
	for child in slot_list.get_children():
		child.queue_free()
	for slot_index in range(GameData.get_character_slot_count()):
		var profile := GameData.get_profile_at_slot(slot_index)
		var viewport_width := get_viewport_rect().size.x
		var card_width := clampf((viewport_width - 112.0) / 5.0, 104.0, 136.0)
		var button := UiStyle.make_button("", Vector2(card_width, 128 if _is_portrait_layout() else 144))
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 13 if _is_portrait_layout() else 14)
		if profile.is_empty():
			button.text = "[%02d]\n＋\n새 캐릭터" % (slot_index + 1)
			button.tooltip_text = "이 슬롯에 새 캐릭터를 생성합니다."
		else:
			var class_data := GameData.get_profile_class_data(profile)
			button.text = "[%02d] %s\n%s\n%s · Lv.%d" % [
				slot_index + 1, str(class_data.get("icon", "⚔️")), str(profile.get("name", "이름 없음")),
				str(class_data.get("role", profile.get("class_id", ""))), int(profile.get("best_survival_level", 1))]
			button.tooltip_text = "누르면 이 캐릭터로 게임을 시작합니다."
			button.button_pressed = str(profile.get("id", "")) == selected_character_id
			if button.button_pressed:
				button.add_theme_stylebox_override("normal", UiStyle.button_style(Color(0.22, 0.045, 0.028, 0.98), UiStyle.GOLD_BRIGHT))
		button.pressed.connect(_on_slot_pressed.bind(slot_index))
		slot_list.add_child(button)


func _on_slot_pressed(slot_index: int):
	var profile := GameData.get_profile_at_slot(slot_index)
	if profile.is_empty():
		_show_creation(slot_index)
		return
	selected_character_id = str(profile.get("id", ""))
	GameData.select_character_profile(selected_character_id)
	_enter_selected_character()


func _update_selected_profile():
	var profile := GameData.get_character_profile(selected_character_id)
	var exists := not profile.is_empty()
	delete_button.disabled = not exists
	if not exists:
		detail_name.text = "저장된 캐릭터 없음"
		detail_subtitle.text = "빈 슬롯을 눌러 생성하세요."
		detail_stats.text = "캐릭터를 만들면\n능력치가 표시됩니다."
		detail_equipment.text = ""
		detail_progress.text = "생성 직후에는 이 화면으로 돌아옵니다."
		_set_preview_class(GameData.FIGHTER_ID, {})
		return
	var class_id := str(profile.get("class_id", GameData.FIGHTER_ID))
	var class_data := GameData.get_profile_class_data(profile)
	var stats := GameData.get_profile_stat_manager(profile)
	detail_name.text = "%s  %s" % [str(class_data.get("icon", "⚔️")), str(profile.get("name", ""))]
	detail_subtitle.text = "%s · %s" % [str(class_data.get("role", class_id)), str(class_data.get("title", ""))]
	if _is_portrait_layout():
		detail_stats.text = "STR %d  AGI %d  VIT %d\nINT %d  DEX %d  LUK %d" % [
			stats.get_stat("STR"), stats.get_stat("AGI"), stats.get_stat("VIT"),
			stats.get_stat("INT"), stats.get_stat("DEX"), stats.get_stat("LUK")]
	else:
		detail_stats.text = (
			"영구 능력치\nSTR %d   AGI %d   VIT %d\nINT %d   DEX %d   LUK %d\n\nHP %d\n물리 공격 %.1f   마법 공격 %.1f\n물리 방어 %.1f   마법 방어 %.1f"
			% [stats.get_stat("STR"), stats.get_stat("AGI"), stats.get_stat("VIT"), stats.get_stat("INT"), stats.get_stat("DEX"), stats.get_stat("LUK"),
			stats.max_hp(), stats.phys_atk(class_id == "archer"), stats.mag_atk(), stats.phys_def(), stats.mag_def()])
	var equipment := _get_profile_equipment(profile)
	if _is_portrait_layout():
		detail_equipment.text = "HP %d · 공격 %.1f · 방어 %.1f\n무기 %s · 방어구 %s" % [stats.max_hp(), stats.phys_atk(class_id == "archer"), stats.phys_def(), equipment.weapon, equipment.armor]
		detail_progress.text = "최고 생존 %s · 서바이벌 Lv.%d\n마지막 접속 %s" % [
			_format_survival_time(float(profile.get("best_survival_time", 0.0))), int(profile.get("best_survival_level", 1)),
			str(profile.get("last_played_at", "아직 접속하지 않음"))]
	else:
		detail_equipment.text = "장착 무기  %s\n장착 방어구  %s" % [equipment.weapon, equipment.armor]
		detail_progress.text = "최고 생존 시간  %s\n최고 서바이벌 레벨  %d\n총 플레이 시간  %s\n마지막 접속  %s" % [
			_format_survival_time(float(profile.get("best_survival_time", 0.0))), int(profile.get("best_survival_level", 1)),
			_format_play_time(int(profile.get("play_time_seconds", 0))), str(profile.get("last_played_at", "아직 접속하지 않음"))]
	_set_preview_class(class_id, class_data)


func _get_profile_equipment(profile: Dictionary) -> Dictionary:
	var state_value: Variant = profile.get("state", {})
	var state: Dictionary = state_value if state_value is Dictionary else {}
	var class_id := str(profile.get("class_id", GameData.FIGHTER_ID))
	var gear_value: Variant = state.get("equipped_gear", {})
	var gear_by_class: Dictionary = gear_value if gear_value is Dictionary else {}
	var equipped_value: Variant = gear_by_class.get(class_id, {})
	var equipped: Dictionary = equipped_value if equipped_value is Dictionary else {}
	var result := {"weapon": "없음", "armor": "없음"}
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
	if selected_character_id.is_empty() or not GameData.activate_character_profile(selected_character_id):
		feedback_label.text = "캐릭터 데이터를 불러오지 못했습니다."
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		return
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
	for key in GameData.characters:
		var class_id := str(key)
		var character := GameData.get_class_template_data(class_id)
		if not bool(character.get("unlocked", false)):
			continue
		var button := UiStyle.make_button("%s  %s\n%s" % [str(character.get("icon", "⚔️")), str(character.get("role", class_id)), str(character.get("title", ""))], Vector2(0, 70))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = str(character.get("desc", ""))
		button.set_meta("class_id", class_id)
		button.pressed.connect(_select_class.bind(class_id))
		class_list.add_child(button)


func _select_class(class_id: String):
	var character := GameData.get_class_template_data(class_id)
	if character.is_empty():
		return
	selected_class_id = class_id
	var stats := GameData.get_class_template_stat_manager(class_id)
	detail_name.text = "%s  %s" % [str(character.get("icon", "⚔️")), str(character.get("role", class_id))]
	detail_subtitle.text = str(character.get("title", ""))
	if _is_portrait_layout():
		detail_stats.text = "STR %d  AGI %d  VIT %d\nINT %d  DEX %d  LUK %d" % [
			stats.get_stat("STR"), stats.get_stat("AGI"), stats.get_stat("VIT"),
			stats.get_stat("INT"), stats.get_stat("DEX"), stats.get_stat("LUK")]
	else:
		detail_stats.text = (
			"기본 능력치\nSTR %d   AGI %d   VIT %d\nINT %d   DEX %d   LUK %d\n\n초기 전투 수치\nHP %d\n물리 공격 %.1f   마법 공격 %.1f\n물리 방어 %.1f   마법 방어 %.1f"
			% [stats.get_stat("STR"), stats.get_stat("AGI"), stats.get_stat("VIT"), stats.get_stat("INT"), stats.get_stat("DEX"), stats.get_stat("LUK"),
			stats.max_hp(), stats.phys_atk(class_id == "archer"), stats.mag_atk(), stats.phys_def(), stats.mag_def()])
	detail_equipment.text = "대표 무기  %s\n대표 스킬  %s" % [str(character.get("weapon_name", CLASS_WEAPONS.get(class_id, "기본 무기"))), str(character.get("signature_skill", ""))]
	detail_progress.text = "%s\n\n전투 스타일: %s" % [str(character.get("desc", "")), str(character.get("combat_style", CLASS_GROWTH.get(class_id, "균형 성장")))]
	for child in class_list.get_children():
		if child is Button:
			var is_selected := str(child.get_meta("class_id", "")) == class_id
			child.button_pressed = is_selected
			if is_selected:
				child.add_theme_stylebox_override("normal", UiStyle.button_style(Color(0.24, 0.07, 0.035, 1.0), UiStyle.GOLD_BRIGHT))
			else:
				child.add_theme_stylebox_override("normal", UiStyle.button_style(UiStyle.INK_SOFT, Color(0.62, 0.43, 0.23, 0.86)))
	_set_preview_class(class_id, character)
	_update_create_button()


func _randomize_name():
	for _attempt in range(32):
		var candidate: String = str(FIRST_NAMES.pick_random()) + str(LAST_NAMES.pick_random())
		if GameData.get_character_name_error(candidate).is_empty():
			name_edit.text = candidate
			return
	feedback_label.text = "사용 가능한 랜덤 이름을 찾지 못했습니다."


func _on_name_changed(_new_text: String):
	_update_create_button()


func _update_create_button():
	if not is_instance_valid(create_button) or not is_instance_valid(name_edit):
		return
	var error := GameData.get_character_name_error(name_edit.text)
	create_button.disabled = not error.is_empty()
	create_button.tooltip_text = error if not error.is_empty() else "캐릭터를 슬롯에 저장합니다."
	if name_edit.text.strip_edges().is_empty():
		feedback_label.text = "이름을 입력하면 생성할 수 있습니다."
	elif not error.is_empty():
		feedback_label.text = error
	else:
		feedback_label.text = "사용 가능한 이름입니다."


func _create_character():
	var error := GameData.get_character_name_error(name_edit.text)
	if not error.is_empty():
		feedback_label.text = error
		return
	var new_id := GameData.create_character_profile(creation_slot, selected_class_id, name_edit.text)
	if new_id.is_empty():
		feedback_label.text = "캐릭터를 저장하지 못했습니다."
		return
	_show_selection(new_id)
	feedback_label.text = "캐릭터를 생성했습니다. 슬롯을 누르면 게임을 시작합니다."


func _build_preview(parent: VBoxContainer):
	preview_zoom = 1.0
	preview_container = SubViewportContainer.new()
	var preview_height := clampf(get_viewport_rect().size.y * 0.28, 270.0, 360.0) if _is_portrait_layout() else 670.0
	var preview_width := minf(get_viewport_rect().size.x * 0.53 - 16.0, 352.0) if _is_portrait_layout() else 550.0
	preview_container.custom_minimum_size = Vector2(preview_width, preview_height)
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_container.gui_input.connect(_on_preview_input)
	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(preview_width + 4.0, preview_height + 4.0)
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.045, 0.025, 0.023, 0.98), UiStyle.GOLD, 1))
	parent.add_child(preview_frame)
	preview_frame.add_child(preview_container)
	var zoom_row := HBoxContainer.new()
	zoom_row.alignment = BoxContainer.ALIGNMENT_END
	zoom_row.add_theme_constant_override("separation", 6)
	parent.add_child(zoom_row)
	zoom_row.add_child(UiStyle.make_label("미리보기 확대", 13, UiStyle.MUTED))
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
	preview_viewport.size = Vector2i(int(preview_width), int(preview_height))
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(preview_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.025, 0.025)
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
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18, 18)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.075, 0.045, 0.04)
	floor.material_override = floor_material
	preview_viewport.add_child(floor)
	preview_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	preview_player.process_mode = Node.PROCESS_MODE_DISABLED
	preview_player.set("is_combat_enabled", false)
	preview_viewport.add_child(preview_player)
	preview_visual = preview_player.get_node("VisualRoot")
	preview_camera = preview_player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if preview_camera != null:
		preview_camera.set("camera_offset", preview_camera_base_offset)
		preview_camera.call("snap_to_target")
	var preview_animation := preview_player.get("model_animation_player") as AnimationPlayer
	if preview_animation:
		preview_animation.process_mode = Node.PROCESS_MODE_ALWAYS


func _set_preview_class(class_id: String, character: Dictionary):
	if preview_visual == null:
		return
	var fallback := GameData.get_class_template_data(class_id)
	var color_value: Variant = character.get("color", fallback.get("color", Color(0.25, 0.55, 0.9)))
	if preview_player.has_method("set_character_appearance"):
		preview_player.call("set_character_appearance", class_id)
		var selected_animation := preview_player.get("model_animation_player") as AnimationPlayer
		if selected_animation:
			selected_animation.process_mode = Node.PROCESS_MODE_ALWAYS
	elif preview_player.has_method("set_character_2d_mode"):
		preview_player.call("set_character_2d_mode", class_id == "fighter_2d")
	# Registered 3D characters keep their authored textures and materials in the preview.
	if class_id == "fighter_2d":
		_update_preview_color(color_value if color_value is Color else Color(0.25, 0.55, 0.9))
	else:
		for mesh in preview_visual.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = null
	_update_preview_weapon(class_id)
	_preview_rotation = 0.0
	_idle_time = 0.0


func _update_preview_color(color: Color):
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.25
	material.roughness = 0.45
	for node in preview_visual.find_children("*", "MeshInstance3D", true, false):
		if not node.has_meta("preview_prop"):
			(node as MeshInstance3D).material_override = material


func _update_preview_weapon(class_id: String):
	for child in preview_visual.get_children():
		if child.has_meta("preview_prop"):
			child.queue_free()
	var sword := preview_visual.get_node_or_null("ArmR/Sword") as MeshInstance3D
	if sword:
		sword.visible = class_id in ["warrior", "paladin"]
	match class_id:
		"archer":
			var bow := TorusMesh.new()
			bow.inner_radius = 0.34
			bow.outer_radius = 0.4
			_add_preview_prop(bow, Vector3(0.55, 1.0, -0.16), Vector3(0, 0, 0.35), Color(0.55, 0.31, 0.12))
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
	preview_camera.set("camera_offset", preview_camera_base_offset * preview_zoom)
	preview_camera.call("snap_to_target")


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
