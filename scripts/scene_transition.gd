extends CanvasLayer

const FADE_OUT_DURATION := 0.18
const FADE_IN_DURATION := 0.20
const LOAD_TIMEOUT_MSEC := 45000

var color_rect: ColorRect
var loading_center: CenterContainer
var loading_label: Label
var loading_bar: ProgressBar
var is_transitioning: bool = false
var _unfinished_loads: Dictionary = {}
var _prepared_shared_resources: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_rect)

	# Keep the loading feedback inside the persistent autoload so it is visible
	# while the previous scene is being freed and the next scene is loaded.
	loading_center = CenterContainer.new()
	loading_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_center.visible = false
	add_child(loading_center)

	var loading_box := VBoxContainer.new()
	loading_box.custom_minimum_size = Vector2(260, 0)
	loading_box.add_theme_constant_override("separation", 12)
	loading_center.add_child(loading_box)

	loading_label = Label.new()
	loading_label.text = "불러오는 중…"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_color_override("font_color", Color.WHITE)
	loading_label.add_theme_font_size_override("font_size", 22)
	loading_box.add_child(loading_label)

	loading_bar = ProgressBar.new()
	loading_bar.custom_minimum_size = Vector2(260, 12)
	loading_bar.show_percentage = false
	loading_bar.max_value = 100.0
	loading_box.add_child(loading_bar)
	set_process(false)

func _input(_event: InputEvent) -> void:
	if is_transitioning:
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	for path in _unfinished_loads.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_unfinished_loads.erase(path)
			if status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_get(path)
	set_process(not _unfinished_loads.is_empty())

func change_scene(target_path: String, before_scene_ready: Callable = Callable(), shared_resource_path: String = "") -> void:
	if is_transitioning:
		return
	if target_path.is_empty() or not ResourceLoader.exists(target_path):
		_show_load_failure(target_path)
		return

	is_transitioning = true
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_center.visible = true
	loading_bar.value = 0.0
	_set_loading_step(0.0, "화면 불러오는 중…")

	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "color:a", 1.0, FADE_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	var shared_key := [target_path, shared_resource_path]
	var load_shared := not shared_resource_path.is_empty() and not _prepared_shared_resources.has(shared_key)
	load_shared = load_shared and ResourceLoader.exists(shared_resource_path)
	var packed_scene := await _load_packed(target_path, 0.0, 52.0 if load_shared else 72.0)
	# Keep the shared source alive until the new scene has extracted its clips.
	var shared_source: PackedScene
	if packed_scene != null and load_shared:
		_set_loading_step(52.0, "캐릭터 동작 불러오는 중…")
		shared_source = await _load_packed(shared_resource_path, 52.0, 72.0)
		if shared_source == null:
			packed_scene = null

	if packed_scene == null:
		tree.paused = was_paused
		await _finish_transition()
		_show_load_failure(target_path)
		return

	await _show_loading_step(72.0, "새 화면 준비 중…")
	# SceneTree keeps the old scene intact if instantiation fails.
	var change_error := tree.change_scene_to_packed(packed_scene)
	if change_error != OK:
		tree.paused = was_paused
		await _finish_transition()
		_show_load_failure(target_path)
		return
	tree.paused = false
	if before_scene_ready.is_valid():
		before_scene_ready.call()
	await tree.scene_changed

	var next_scene := tree.current_scene
	if next_scene.has_method("prepare_transition"):
		var next_paused := tree.paused
		tree.paused = true
		await next_scene.call("prepare_transition", _show_loading_step)
		tree.paused = next_paused
	if shared_source != null:
		_prepared_shared_resources[shared_key] = true
		shared_source = null
	await _show_loading_step(100.0, "준비 완료")
	await _finish_transition()

func _load_packed(path: String, start: float, end: float) -> PackedScene:
	# A timed-out load can still finish in the background. A retry takes over
	# that request instead of starting a duplicate.
	if not _unfinished_loads.erase(path):
		if ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
			return null
	var deadline := Time.get_ticks_msec() + LOAD_TIMEOUT_MSEC
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(path)
			return null
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		if not progress.is_empty():
			loading_bar.value = maxf(loading_bar.value, lerpf(start, end, clampf(float(progress[0]), 0.0, 1.0)))
		if Time.get_ticks_msec() >= deadline:
			_unfinished_loads[path] = true
			set_process(true)
			return null
		await get_tree().process_frame
	return null

func _set_loading_step(progress: float, caption: String) -> void:
	loading_bar.value = maxf(loading_bar.value, progress)
	loading_label.text = caption

func _show_loading_step(progress: float, caption: String) -> void:
	_set_loading_step(progress, caption)
	# process_frame fires before drawing. Give the new caption a rendered frame.
	await get_tree().process_frame
	await get_tree().process_frame

func _finish_transition() -> void:
	loading_center.hide()
	var tween_in := create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_in.tween_property(color_rect, "color:a", 0.0, FADE_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween_in.finished
	
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false

func _show_load_failure(path: String) -> void:
	push_warning("SceneTransition: could not load %s" % path)
	UiFeedback.show_error("화면을 불러오지 못했습니다. 다시 시도해 주세요.")
