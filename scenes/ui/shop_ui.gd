extends CanvasLayer

signal closed()

const CHARACTER_PORTRAIT := preload("res://scenes/ui/character_portrait.gd")
const ALL_JOBS := "*"

var _source: AnimationLibrary
var _motion_names: Array[String] = []
var _selected_motion := ""
var _preview_ready := false
var _preview: CHARACTER_PORTRAIT
var _preview_panel: PanelContainer
var _list: ItemList
var _search: LineEdit
var _job_filter: OptionButton
var _owned_only: Button
var _results_label: Label
var _coins_label: Label
var _selected_label: Label
var _status: Label
var _buy: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_build_ui()
	GameData.skill_shop_updated.connect(_refresh_purchase)
	get_viewport().size_changed.connect(_fit_preview)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.68)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var content := UiStyle.dialog_layout(self, "", 760.0)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UiStyle.make_title("스킬 상점", 27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_coins_label = UiStyle.make_label("", 17, UiStyle.GOLD_BRIGHT)
	header.add_child(_coins_label)
	var close := UiStyle.make_button("✕", Vector2(50, 48))
	close.pressed.connect(close_screen)
	header.add_child(close)

	_preview_panel = UiStyle.make_panel(Color("#20242e"))
	_preview_panel.clip_contents = true
	content.add_child(_preview_panel)
	_fit_preview()

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	content.add_child(filters)
	_job_filter = OptionButton.new()
	_job_filter.custom_minimum_size.y = 44
	_job_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.apply_button(_job_filter)
	_job_filter.item_selected.connect(func(_index): _rebuild_results(_search.text))
	filters.add_child(_job_filter)
	_owned_only = UiStyle.make_button("보유만", Vector2(96, 44))
	_owned_only.toggle_mode = true
	_owned_only.toggled.connect(func(_on): _rebuild_results(_search.text))
	filters.add_child(_owned_only)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 10)
	content.add_child(search_row)
	_search = LineEdit.new()
	_search.placeholder_text = "동작 이름 검색"
	_search.clear_button_enabled = true
	_search.custom_minimum_size.y = 46
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_rebuild_results)
	search_row.add_child(_search)
	_results_label = UiStyle.make_label("", 16, UiStyle.MUTED)
	search_row.add_child(_results_label)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size.y = 92
	_list.add_theme_font_size_override("font_size", 17)
	_list.add_theme_constant_override("v_separation", 17)
	_list.add_theme_stylebox_override("panel", UiStyle.sub_panel_style())
	_list.item_selected.connect(_select_motion)
	content.add_child(_list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)
	var selection := VBoxContainer.new()
	selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(selection)
	_selected_label = UiStyle.make_label("", 18)
	_selected_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selection.add_child(_selected_label)
	_status = UiStyle.make_label("", 15, UiStyle.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 22
	selection.add_child(_status)
	_buy = UiStyle.make_button("", Vector2(132, 50), true)
	_buy.pressed.connect(_buy_selected)
	footer.add_child(_buy)


func _fit_preview() -> void:
	_preview_panel.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y * 0.30, 165.0, 380.0)


func open() -> void:
	_source = GameData.get_skill_shop_library()
	_motion_names.assign(_source.get_animation_list() if _source != null else PackedStringArray())
	_motion_names.sort_custom(func(a: String, b: String):
		return GameData.get_skill_shop_motion_name(a).naturalnocasecmp_to(GameData.get_skill_shop_motion_name(b)) < 0
	)
	_selected_motion = ""
	_preview_ready = false
	_search.text = ""
	_owned_only.set_pressed_no_signal(false)
	_populate_job_filter()
	show()
	if _source != null:
		if _preview == null:
			_preview = CHARACTER_PORTRAIT.new()
			_preview_panel.add_child(_preview)
		_preview.show_character(GameData.get_leader_id())
		_preview.set_portrait_active(true)
	_rebuild_results("")
	_refresh_purchase()


func close_screen() -> void:
	if _preview != null:
		_preview.clear_clip_preview()
		_preview.set_portrait_active(false)
	_source = null
	hide()
	closed.emit()

func _populate_job_filter() -> void:
	var player_job := GameData.get_skill_shop_player_role()
	var jobs: Array[String] = []
	for clip in _motion_names:
		var job := GameData.get_skill_shop_motion_role(clip)
		if not job.is_empty() and not jobs.has(job):
			jobs.append(job)
	jobs.sort()
	_job_filter.clear()
	_job_filter.add_item("전체 동작")
	_job_filter.set_item_metadata(0, ALL_JOBS)
	_job_filter.select(0)
	for job in jobs:
		var index := _job_filter.item_count
		_job_filter.add_item("%s (내 직업)" % job if job == player_job else job)
		_job_filter.set_item_metadata(index, job)
		if job == player_job:
			_job_filter.select(index)
	_job_filter.add_item("일반 동작")
	_job_filter.set_item_metadata(_job_filter.item_count - 1, "")

func _rebuild_results(query: String) -> void:
	var term := query.strip_edges().to_lower()
	var job_filter := str(_job_filter.get_selected_metadata())
	var keep_selection := false
	_list.clear()
	for clip_name in _motion_names:
		var job := GameData.get_skill_shop_motion_role(clip_name)
		if job_filter != ALL_JOBS and job != job_filter:
			continue
		if _owned_only.button_pressed and not GameData.has_skill_shop_motion(clip_name):
			continue
		var localized := GameData.get_skill_shop_motion_name(clip_name)
		if not term.is_empty() and not localized.containsn(term) and not clip_name.containsn(term.replace(" ", "_")):
			continue
		var index := _list.add_item(_item_text(clip_name))
		_list.set_item_metadata(index, clip_name)
		if clip_name == _selected_motion:
			_list.select(index)
			keep_selection = true
	if not keep_selection and not _selected_motion.is_empty():
		_selected_motion = ""
		_preview_ready = false
		if _preview != null:
			_preview.clear_clip_preview()
		_refresh_purchase()
	_results_label.text = "%d개" % _list.item_count


func _item_text(clip_name: String) -> String:
	var title := GameData.get_skill_shop_motion_name(clip_name)
	var job := GameData.get_skill_shop_motion_role(clip_name)
	if str(_job_filter.get_selected_metadata()) == ALL_JOBS and not job.is_empty():
		title += "  ·  " + job
	return title + "  ·  보유" if GameData.has_skill_shop_motion(clip_name) else title


func _select_motion(index: int) -> void:
	_selected_motion = str(_list.get_item_metadata(index))
	_preview_ready = _preview != null and _source != null and _preview.preview_clip(_source, StringName(_selected_motion))
	_refresh_purchase()


func _refresh_purchase() -> void:
	if not visible:
		return
	_coins_label.text = "스킬 코인 %d" % GameData.skill_coins
	var owned := GameData.has_skill_shop_motion(_selected_motion)
	var blocked := GameData.get_skill_shop_purchase_error(_selected_motion)
	_selected_label.text = GameData.get_skill_shop_motion_name(_selected_motion) if not _selected_motion.is_empty() else "동작 선택"
	_selected_label.tooltip_text = _selected_label.text
	_buy.text = "보유 중" if owned else "구매 · %d 코인" % GameData.SKILL_MOTION_PRICE
	_buy.disabled = not _preview_ready or not blocked.is_empty()
	if _source == null:
		_status.text = "동작 목록을 불러오지 못했습니다."
	elif _selected_motion.is_empty():
		_status.text = "목록에서 고르면 영웅이 재생합니다."
	elif not _preview_ready:
		_status.text = "현재 영웅이 이 동작을 재생할 수 없습니다."
	elif owned:
		_status.text = ""
	else:
		_status.text = blocked


func _buy_selected() -> void:
	if _buy.disabled:
		return
	var error := GameData.buy_skill_motion(_selected_motion)
	if not error.is_empty():
		_status.text = error
		return
	_status.text = "구매 완료"
	for index in _list.get_selected_items():
		_list.set_item_text(index, _item_text(_selected_motion))


func _unhandled_input(event: InputEvent) -> void:
	if visible and not GameActions.is_capturing() and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()
