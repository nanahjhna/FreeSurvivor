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
var _awaiting_action: String = ""
var _awaiting_button: Button = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel.custom_minimum_size = Vector2(660, 760)
	if master_slider:
		master_slider.value = 80
	if bgm_slider:
		bgm_slider.value = 75
	if sfx_slider:
		sfx_slider.value = 85
	_build_controls_section()
	var close_btn = get_node_or_null("CenterContainer/Panel/Margin/VBox/Header/CloseBtn")
	if close_btn:
		close_btn.text = "← 닫기 [ESC]"
		close_btn.custom_minimum_size = Vector2(130, 36)
		UiStyle.apply_button(close_btn)
	var confirm_btn = get_node_or_null("CenterContainer/Panel/Margin/VBox/BottomRow/ConfirmBtn")
	if confirm_btn:
		UiStyle.apply_button(confirm_btn, true)
	var reset_btn = get_node_or_null("CenterContainer/Panel/Margin/VBox/BottomRow/ResetSaveBtn")
	if reset_btn:
		UiStyle.apply_button(reset_btn)
	GameActions.bindings_changed.connect(_refresh_key_list)
	GameActions.input_mode_changed.connect(_refresh_input_mode)

func _build_controls_section():
	if key_guide:
		key_guide.text = "• 이동: 방향키 전용 (PC)\n• 스킬: Q, W, E, R\n• 아이템: 1, 2, 3\n• 메뉴: C, P, I, K, J, B, O, M\n• 상호작용: E / 일시정지: ESC\n• 모바일: 화면 방향키와 버튼 사용"

	var sep := HSeparator.new()
	content_box.add_child(sep)

	var input_box := VBoxContainer.new()
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
	_refresh_key_list()
	_refresh_input_mode()

func close():
	if _awaiting_action != "":
		_end_capture()
	visible = false
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
		"모든 캐릭터 성장, 장비, 퀘스트 진행도가 초기화됩니다.\n정말 초기화하시겠습니까?",
		func():
			GameData.reset_save()
			UiFeedback.show_success("저장 데이터를 초기화했습니다.")
			close()
	)

func _unhandled_input(event: InputEvent):
	if visible and _awaiting_action == "" and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
