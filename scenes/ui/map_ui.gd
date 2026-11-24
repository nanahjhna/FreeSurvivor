extends CanvasLayer

signal closed()
signal landmark_selected(landmark_id: String)

const MINIMAP_SCENE: PackedScene = preload("res://scenes/ui/minimap.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	visible = false
	_build_ui()

func _build_ui():
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.72)
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(860, 660)
	center.add_child(panel)

	var margin := UiStyle.make_margin(panel, 24)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := UiStyle.make_title("🗺️ 마을 지도", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiStyle.make_button("← 닫기 [ESC]", Vector2(150, 42))
	close.pressed.connect(close_screen)
	header.add_child(close)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	vbox.add_child(body)

	var minimap_box := PanelContainer.new()
	minimap_box.custom_minimum_size = Vector2(360, 360)
	minimap_box.add_theme_stylebox_override("panel", UiStyle.sub_panel_style())
	body.add_child(minimap_box)
	var minimap_margin := UiStyle.make_margin(minimap_box, 12)
	var minimap := MINIMAP_SCENE.instantiate()
	minimap.custom_minimum_size = Vector2(330, 330)
	minimap_margin.add_child(minimap)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	right.add_child(UiStyle.make_label("주요 장소", 18, Color(1.0, 0.88, 0.48)))
	right.add_child(UiStyle.make_label("장소를 선택하면 해당 기능이 열립니다.", 12, Color(0.7, 0.8, 0.92)))

	var landmarks := [
		{"id": "forge", "icon": "🔨", "name": "대장간", "desc": "장비 관리 · 헤파이스토"},
		{"id": "shop", "icon": "🪙", "name": "스킬 상점", "desc": "영웅 동작 미리보기·구매"},
		{"id": "inn", "icon": "🏨", "name": "여관", "desc": "골드로 체력 회복 · 엘레나"},
		{"id": "quest", "icon": "📜", "name": "마을 게시판", "desc": "퀘스트 확인 및 보상 수령"},
		{"id": "battle_start", "icon": "⚔️", "name": "북쪽 성문", "desc": "스테이지 선택 및 전투 준비"}
	]
	for lm in landmarks:
		var button := UiStyle.make_button("", Vector2(0, 56))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s  %s\n     %s" % [lm.icon, lm.name, lm.desc]
		var lid: String = lm.id
		button.pressed.connect(func(): _select_landmark(lid))
		right.add_child(button)

func open():
	visible = true

func close_screen():
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

func _select_landmark(landmark_id: String):
	close_screen()
	landmark_selected.emit(landmark_id)
