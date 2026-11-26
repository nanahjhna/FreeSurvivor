extends CanvasLayer

signal closed()

@onready var master_slider: HSlider = $CenterContainer/Panel/Margin/VBox/Content/VolumeBox/MasterRow/MasterSlider
@onready var bgm_slider: HSlider = $CenterContainer/Panel/Margin/VBox/Content/VolumeBox/BGMRow/BGMSlider
@onready var sfx_slider: HSlider = $CenterContainer/Panel/Margin/VBox/Content/VolumeBox/SFXRow/SFXSlider
@onready var fullscreen_check: CheckBox = $CenterContainer/Panel/Margin/VBox/Content/DisplayBox/FullscreenCheck
@onready var content_box: VBoxContainer = $CenterContainer/Panel/Margin/VBox/Content
@onready var key_guide: Label = $CenterContainer/Panel/Margin/VBox/Content/DisplayBox/KeyGuide
@onready var panel: PanelContainer = $CenterContainer/Panel

var _input_mode_option: OptionButton
var _key_list: VBoxContainer
var _advanced_box: VBoxContainer
var _advanced_button: Button
var _portrait_layout := false
var _awaiting_action: String = ""
var _awaiting_button: Button = null
var _camera_box: VBoxContainer
var _camera_mode_option: OptionButton
var _camera_angle_slider: HSlider
var _camera_direction_slider: HSlider
var _camera_distance_slider: HSlider
var _camera_angle_value: Label
var _camera_direction_value: Label
var _camera_distance_value: Label
var _camera_settings_changed := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel.add_theme_stylebox_override("panel", UiStyle.frame(UiStyle.PAPER, Color("#bd8b58"), 24, 6))
	$Backdrop.color = Color(0.025, 0.02, 0.028, 0.75)
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.y >= viewport_size.x
	_portrait_layout = portrait
	panel.custom_minimum_size = Vector2(
		minf(viewport_size.x - 32.0, 660.0) if portrait else 660.0,
		minf(viewport_size.y - 48.0, 700.0) if portrait else 760.0
	)
	var margin := get_node_or_null("CenterContainer/Panel/Margin") as MarginContainer
	if margin and portrait:
		for side in ["margin_left", "margin_right"]:
			margin.add_theme_constant_override(side, 16)
		for side in ["margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(side, 18)
	_style_audio_slider(master_slider, "Master", false)
	_style_audio_slider(bgm_slider, "BGM")
	_style_audio_slider(sfx_slider, "SFX")
	_build_controls_section()
	_build_camera_section()
	_build_hud_section()
	if portrait:
		fullscreen_check.visible = false
	var close_btn := get_node_or_null("CenterContainer/Panel/Margin/VBox/Header/CloseBtn") as Button
	if close_btn:
		close_btn.text = "✕"
		close_btn.custom_minimum_size = Vector2(52, 48)
		UiStyle.apply_button(close_btn)
		UiStyle.skin_button(close_btn, Color("#34678d"), Color("#bcdded"))
	var confirm_btn := get_node_or_null("CenterContainer/Panel/Margin/VBox/BottomRow/ConfirmBtn") as Button
	if confirm_btn:
		UiStyle.apply_button(confirm_btn, true)
		UiStyle.skin_button(confirm_btn, UiStyle.BLUE, UiStyle.BLUE_EDGE)
		confirm_btn.text = "완료"
	var reset_btn := get_node_or_null("CenterContainer/Panel/Margin/VBox/BottomRow/ResetSaveBtn") as Button
	if reset_btn:
		UiStyle.apply_button(reset_btn)
		reset_btn.get_parent().remove_child(reset_btn)
		_advanced_box.add_child(reset_btn)
		reset_btn.custom_minimum_size = Vector2(0, 48)
		reset_btn.text = "저장 데이터 초기화"
	if confirm_btn:
		confirm_btn.custom_minimum_size = Vector2(0, 56 if portrait else 46)
		confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		confirm_btn.add_theme_font_size_override("font_size", 20)
	var title := $CenterContainer/Panel/Margin/VBox/Header/TitleLabel as Label
	title.text = "환경 설정"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.ink_outline(title, 7, Color("#24446f"))
	var header := title.get_parent()
	var header_parent := header.get_parent()
	var banner := UiStyle.make_panel()
	banner.add_theme_stylebox_override("panel", UiStyle.frame(Color("#3c83b1"), Color("#b3e2f7"), 12, 4))
	header_parent.add_child(banner)
	header_parent.move_child(banner, header.get_index())
	header.reparent(banner, false)
	_set_paper_text(content_box)
	var layout := content_box.get_parent()
	var content_index := content_box.get_index()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	layout.move_child(scroll, content_index)
	content_box.reparent(scroll, false)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	_set_advanced_open(not portrait)
	_advanced_button.visible = portrait
	GameActions.bindings_changed.connect(_refresh_key_list)
	GameActions.input_mode_changed.connect(_refresh_input_mode)

func _set_paper_text(parent: Node) -> void:
	for child in parent.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", UiStyle.PAPER_INK)
		elif child is CheckBox:
			child.add_theme_color_override("font_color", UiStyle.PAPER_INK)
			child.add_theme_color_override("font_hover_color", UiStyle.PAPER_INK)
		_set_paper_text(child)

func _fit_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UiStyle.safe_insets(get_viewport())
	var center := $CenterContainer as CenterContainer
	center.offset_left = safe.x + 20
	center.offset_top = safe.y + 20
	center.offset_right = -safe.z - 20
	center.offset_bottom = -safe.w - 20
	panel.custom_minimum_size = Vector2(
		minf(660, viewport_size.x - safe.x - safe.z - 40),
		minf(760, viewport_size.y - safe.y - safe.w - 40)
	)

func _style_audio_slider(slider: HSlider, bus: String, connect_change: bool = true) -> void:
	var row := slider.get_parent() as HBoxContainer
	var bus_index := AudioServer.get_bus_index(bus)
	if bus_index < 0:
		row.hide()
		return
	row.custom_minimum_size.y = 52
	row.add_theme_constant_override("separation", 12)
	(row.get_node("Lbl") as Label).add_theme_font_size_override("font_size", 19)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#c29d6f")
	track.set_corner_radius_all(5)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color("#5f9c58")
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100)
	var amount := UiStyle.make_label("%d%%" % int(slider.value), 16, UiStyle.MUTED)
	amount.custom_minimum_size.x = 52
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(amount)
	slider.value_changed.connect(func(value: float):
		amount.text = "%d%%" % int(value)
		if connect_change:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))
	)

func _build_controls_section():
	if key_guide:
		key_guide.text = "이동과 스킬은 게임 화면의 터치 버튼을 사용합니다." if _portrait_layout else "• 이동: 방향키 (PC)\n• 스킬: Q, W, E, R\n• 아이템: 1, 2, 3\n• 메뉴: C, P, I, K, J, B, O, M\n• 상호작용: E / 일시정지: ESC"

	var sep := HSeparator.new()
	content_box.add_child(sep)

	_advanced_button = UiStyle.make_button("PC 단축키 · 고급 설정 보기", Vector2(0, 52))
	_advanced_button.pressed.connect(func(): _set_advanced_open(not _advanced_box.visible))
	content_box.add_child(_advanced_button)

	var input_box := VBoxContainer.new()
	_advanced_box = input_box
	input_box.add_theme_constant_override("separation", 10)
	content_box.add_child(input_box)

	input_box.add_child(UiStyle.make_label("⌨️ 입력 및 단축키", 16, Color(0.9, 0.94, 1.0)))

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	input_box.add_child(mode_row)
	var mode_label := UiStyle.make_label("입력 모드", 14)
	mode_label.custom_minimum_size = Vector2(100, 0)
	mode_row.add_child(mode_label)
	_input_mode_option = OptionButton.new()
	_input_mode_option.custom_minimum_size = Vector2(220, 38)
	_input_mode_option.add_item("자동 감지")
	_input_mode_option.add_item("PC (키보드/마우스)")
	_input_mode_option.add_item("모바일 (터치)")
	mode_row.add_child(_input_mode_option)
	_input_mode_option.item_selected.connect(_on_input_mode_selected)
	var reset_keys := UiStyle.make_button("단축키 초기화", Vector2(150, 38))
	reset_keys.pressed.connect(func():
		GameActions.reset_bindings()
		UiFeedback.show_success("단축키를 기본값으로 되돌렸습니다.")
	)
	mode_row.add_child(reset_keys)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	input_box.add_child(scroll)

	_key_list = VBoxContainer.new()
	_key_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_key_list)

	_refresh_input_mode()
	_refresh_key_list()

func _build_hud_section():
	var sep := HSeparator.new()
	content_box.add_child(sep)
	var title := UiStyle.make_label("전투 HUD 배치", 16, Color(0.9, 0.94, 1.0))
	content_box.add_child(title)
	var edit_button := UiStyle.make_button("HUD 위치·크기 편집", Vector2(0, 48))
	edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_button.pressed.connect(_open_hud_editor)
	content_box.add_child(edit_button)

func _build_camera_section():
	var separator := HSeparator.new()
	content_box.add_child(separator)
	_camera_box = VBoxContainer.new()
	_camera_box.add_theme_constant_override("separation", 8)
	content_box.add_child(_camera_box)
	_camera_box.add_child(UiStyle.make_label("🎥 카메라 시점", 16, Color(0.9, 0.94, 1.0)))
	var mode_row := HBoxContainer.new()
	_camera_box.add_child(mode_row)
	mode_row.add_child(UiStyle.make_label("시점 방식", 14))
	_camera_mode_option = OptionButton.new()
	_camera_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camera_mode_option.custom_minimum_size.y = 40
	_camera_mode_option.add_item("고정 쿼터뷰", 0)
	_camera_mode_option.item_selected.connect(_on_camera_settings_changed)
	mode_row.add_child(_camera_mode_option)
	_camera_angle_slider = _add_camera_slider("기울기", 20.0, 75.0, 1.0)
	_camera_direction_slider = _add_camera_slider("좌우 방향", -180.0, 180.0, 5.0)
	_camera_distance_slider = _add_camera_slider("거리 / 줌", 4.0, 24.0, 0.5)
	_refresh_camera_controls()

func _add_camera_slider(title: String, min_value: float, max_value: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_camera_box.add_child(row)
	var title_label := UiStyle.make_label(title, 13)
	title_label.custom_minimum_size.x = 90.0
	row.add_child(title_label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 32.0
	slider.value_changed.connect(_on_camera_slider_changed)
	row.add_child(slider)
	var value_label := UiStyle.make_label("", 13, Color(1.0, 0.86, 0.45))
	value_label.custom_minimum_size.x = 54.0
	row.add_child(value_label)
	match title:
		"기울기":
			_camera_angle_value = value_label
		"좌우 방향":
			_camera_direction_value = value_label
		"거리 / 줌":
			_camera_distance_value = value_label
	return slider

func _refresh_camera_controls():
	var player := _get_camera_player()
	if _camera_box == null:
		return
	# The village intentionally stays first-person. Camera tuning is only
	# exposed in combat, where the existing quarter-view camera is used.
	_camera_box.visible = player != null and GameManager.current_location != GameManager.Location.LOBBY
	if player == null:
		return
	# 캐릭터 추적뷰는 임시 비활성화 상태다.
	GameData.camera_view_mode = "quarter"
	_camera_mode_option.select(0)
	_camera_angle_slider.set_value_no_signal(GameData.camera_elevation_degrees)
	_camera_direction_slider.set_value_no_signal(GameData.camera_azimuth_degrees)
	_camera_distance_slider.set_value_no_signal(GameData.camera_distance)
	_update_camera_value_labels()

func _get_camera_player() -> Node:
	var scene := get_tree().current_scene
	return scene.find_child("Player", true, false) if scene else null

func _on_camera_settings_changed(_index: int):
	_apply_camera_settings()

func _on_camera_slider_changed(_value: float):
	_update_camera_value_labels()
	_apply_camera_settings()

func _update_camera_value_labels():
	if _camera_angle_value: _camera_angle_value.text = "%d°" % roundi(_camera_angle_slider.value)
	if _camera_direction_value: _camera_direction_value.text = "%d°" % roundi(_camera_direction_slider.value)
	if _camera_distance_value: _camera_distance_value.text = "%.1fm" % _camera_distance_slider.value

func _apply_camera_settings():
	var player := _get_camera_player()
	if player == null:
		return
	var camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if camera == null:
		return
	if GameManager.current_location == GameManager.Location.LOBBY:
		camera.set("quarter_view_enabled", false)
		camera.set("back_view_enabled", false)
		camera.set("first_person_enabled", true)
		camera.set("first_person_fov", 72.0)
		camera.call("snap_to_target")
		return
	# 캐릭터 추적뷰는 다시 활성화하기 전까지 설정할 수 없게 한다.
	GameData.camera_view_mode = "quarter"
	GameData.camera_elevation_degrees = _camera_angle_slider.value
	GameData.camera_azimuth_degrees = _camera_direction_slider.value
	GameData.camera_distance = _camera_distance_slider.value
	camera.set("quarter_view_enabled", true)
	camera.set("back_view_enabled", false)
	camera.set("first_person_enabled", false)
	camera.set("quarter_elevation_degrees", GameData.camera_elevation_degrees)
	camera.set("back_elevation_degrees", GameData.camera_elevation_degrees)
	camera.set("quarter_azimuth_degrees", GameData.camera_azimuth_degrees)
	camera.set("back_yaw_offset_degrees", 180.0 + GameData.camera_azimuth_degrees)
	camera.set("quarter_distance", GameData.camera_distance)
	camera.set("back_distance", GameData.camera_distance)
	camera.set("min_back_distance", 4.0)
	camera.set("max_back_distance", 24.0)
	camera.call("snap_to_target")
	_camera_settings_changed = true

func _open_hud_editor():
	var hud := get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("begin_hud_edit"):
		close()
		hud.begin_hud_edit()
	else:
		UiFeedback.show_info("전투 중 일시정지 메뉴에서 HUD 편집을 열어주세요.")


func _set_advanced_open(is_open: bool):
	if _advanced_box == null:
		return
	_advanced_box.visible = is_open
	_advanced_button.text = "PC 단축키 · 고급 설정 닫기" if is_open else "PC 단축키 · 고급 설정 보기"
	if _portrait_layout:
		var viewport_height := get_viewport().get_visible_rect().size.y
		panel.custom_minimum_size.y = minf(viewport_height - 48.0, 900.0 if is_open else 700.0)

func _refresh_input_mode():
	if _input_mode_option == null:
		return
	var idx := 0
	match GameData.input_mode:
		"pc": idx = 1
		"mobile": idx = 2
	_input_mode_option.select(idx)

func _on_input_mode_selected(index: int):
	var mode := "auto"
	if index == 1:
		mode = "pc"
	elif index == 2:
		mode = "mobile"
	GameActions.set_input_mode(mode)
	UiFeedback.show_info("입력 모드를 변경했습니다. 화면을 다시 열면 적용됩니다.")

func _refresh_key_list():
	if _key_list == null:
		return
	for child in _key_list.get_children():
		child.queue_free()
	_key_list.add_child(UiStyle.make_label("변경할 기능의 [변경]을 누른 뒤 새 키를 누르세요.", 12, Color(0.68, 0.8, 0.95)))
	for action_id in GameActions.get_rebindable_actions():
		var def := GameActions.get_action(action_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_key_list.add_child(row)

		var name_label := UiStyle.make_label("%s %s" % [def.get("icon", ""), def.get("label", action_id)], 14)
		name_label.custom_minimum_size = Vector2(190, 0)
		row.add_child(name_label)

		var key_label := UiStyle.make_label(GameActions.get_key_name(action_id), 14, Color(1.0, 0.86, 0.45))
		key_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(key_label)

		var change := UiStyle.make_button("변경", Vector2(90, 34))
		var capture_id: String = action_id
		change.pressed.connect(func(): _start_capture(capture_id, change))
		row.add_child(change)

func _start_capture(action_id: String, button: Button):
	if _awaiting_button and is_instance_valid(_awaiting_button):
		_awaiting_button.text = "변경"
	_awaiting_action = action_id
	_awaiting_button = button
	button.text = "키 입력..."
	GameActions.begin_capture(action_id)
	UiFeedback.show_info("새로 사용할 키를 누르세요. (ESC: 취소)")

func _input(event: InputEvent):
	if not visible or _awaiting_action == "":
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var keycode := int(event.physical_keycode)
	if keycode == KEY_ESCAPE:
		_end_capture()
		UiFeedback.show_info("단축키 변경을 취소했습니다.")
		return
	if GameActions.rebind(_awaiting_action, keycode):
		UiFeedback.show_success("단축키를 %s(으)로 변경했습니다." % GameActions.keycode_to_text(keycode))
	else:
		UiFeedback.show_error("이미 다른 기능에서 사용 중인 키입니다.")
	_end_capture()

func _end_capture():
	if _awaiting_button and is_instance_valid(_awaiting_button):
		_awaiting_button.text = "변경"
	_awaiting_action = ""
	_awaiting_button = null
	GameActions.end_capture()
	_refresh_key_list()

func open():
	visible = true
	_refresh_camera_controls()
	if _portrait_layout:
		_set_advanced_open(false)
	_refresh_key_list()
	_refresh_input_mode()

func close():
	if _awaiting_action != "":
		_end_capture()
	visible = false
	if _camera_settings_changed:
		GameData.save_to_disk()
		_camera_settings_changed = false
	closed.emit()

func _on_close_button_pressed():
	close()

func _on_fullscreen_toggled(button_pressed: bool):
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_master_slider_value_changed(value: float):
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _on_reset_save_pressed():
	UiFeedback.confirm(
		"저장 데이터 초기화",
		"무도가의 성장, 장비, 퀘스트 진행도가 초기화됩니다.\n정말 초기화하시겠습니까?",
		func():
			GameData.reset_save()
			UiFeedback.show_success("저장 데이터를 초기화했습니다.")
			close()
	)

func _unhandled_input(event: InputEvent):
	if visible and _awaiting_action == "" and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
