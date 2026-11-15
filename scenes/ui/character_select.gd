extends Control

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CLASS_GROWTH: Dictionary = {
	"warrior": "근접 공격과 안정적인 생존",
	"archer": "원거리 공격과 빠른 명중",
	"mage": "마법 공격과 높은 SP",
	"paladin": "높은 체력과 방어",
	"assassin": "빠른 공격과 치명타",
	"priest": "마법 능력과 균형 잡힌 지원"
}
const CLASS_WEAPONS: Dictionary = {
	"warrior": "장검",
	"archer": "활",
	"mage": "마법 지팡이",
	"paladin": "성검과 방패",
	"assassin": "쌍검",
	"priest": "성물 지팡이"
}
const FIRST_NAMES: Array[String] = ["아린", "시온", "하린", "도윤", "유나", "태오", "세린", "라온"]
const LAST_NAMES: Array[String] = ["빛", "솔", "별", "린", "온", "하늘", "새벽", "바람"]

var selected_character_id: String = "warrior"
var character_list: VBoxContainer
var name_edit: LineEdit
var detail_name: Label
var detail_title: Label
var detail_stats: Label
var detail_description: Label
var skill_label: Label
var weapon_label: Label
var feedback_label: Label
var create_button: Button
var preview_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_player: CharacterBody3D
var preview_visual: Node3D
var _dragging := false
var _last_drag_position := Vector2.ZERO
var _preview_rotation := 0.0
var _idle_time := 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_setup_preview()
	_select_character(selected_character_id)


func _build_ui():
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.035, 0.05, 0.085, 1.0)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UiStyle.make_panel()
	panel.custom_minimum_size = Vector2(1500, 850)
	center.add_child(panel)
	var margin := UiStyle.make_margin(panel, 22)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := UiStyle.make_title("⚔️ 모험가 선택", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back_button := UiStyle.make_button("← 타이틀로", Vector2(160, 46))
	back_button.pressed.connect(func(): GameManager.go_to_title())
	header.add_child(back_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	layout.add_child(body)

	var left_panel := _make_section(body, 270, "직업 선택")
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(list_scroll)
	character_list = VBoxContainer.new()
	character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_list.add_theme_constant_override("separation", 8)
	list_scroll.add_child(character_list)
	_populate_character_list()

	var preview_panel := VBoxContainer.new()
	preview_panel.custom_minimum_size = Vector2(570, 0)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_constant_override("separation", 8)
	body.add_child(preview_panel)
	preview_panel.add_child(UiStyle.make_label("캐릭터 미리보기 · 드래그하여 회전", 15, Color(0.75, 0.85, 1.0)))
	preview_container = SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(560, 650)
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_container.gui_input.connect(_on_preview_input)
	preview_panel.add_child(preview_container)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(560, 650)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(preview_viewport)

	var right_panel := _make_section(body, 430, "직업 정보")
	detail_name = UiStyle.make_title("", 26)
	right_panel.add_child(detail_name)
	detail_title = UiStyle.make_label("", 15, Color(0.78, 0.86, 1.0))
	right_panel.add_child(detail_title)
	right_panel.add_child(HSeparator.new())
	detail_stats = UiStyle.make_label("", 15, Color(0.85, 0.92, 1.0))
	detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_panel.add_child(detail_stats)
	skill_label = UiStyle.make_label("", 15, Color(1.0, 0.84, 0.38))
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_panel.add_child(skill_label)
	weapon_label = UiStyle.make_label("", 15, Color(0.65, 0.9, 1.0))
	right_panel.add_child(weapon_label)
	detail_description = UiStyle.make_label("", 14, Color(0.82, 0.86, 0.93))
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(detail_description)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)
	footer.add_child(UiStyle.make_label("캐릭터 이름", 16, Color(1.0, 0.86, 0.45)))
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(360, 48)
	name_edit.max_length = 20
	name_edit.placeholder_text = "이름을 입력하세요 (최대 20자)"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	footer.add_child(name_edit)
	var random_button := UiStyle.make_button("🎲 이름 랜덤 생성", Vector2(190, 48))
	random_button.pressed.connect(_randomize_name)
	footer.add_child(random_button)
	create_button = UiStyle.make_button("모험 시작", Vector2(210, 48), true)
	create_button.pressed.connect(_on_create_pressed)
	footer.add_child(create_button)

	feedback_label = UiStyle.make_label(
		"직업을 선택하고 이름을 입력하세요. 미리보기는 드래그 또는 터치로 회전할 수 있습니다.", 13, Color(0.74, 0.82, 0.94)
	)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(feedback_label)


func _make_section(parent: Control, width: float, heading: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(width, 0)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)
	parent.add_child(section)
	section.add_child(UiStyle.make_label(heading, 17, Color(1.0, 0.86, 0.44)))
	return section


func _populate_character_list():
	for child in character_list.get_children():
		child.queue_free()
	for char_id in GameData.characters:
		var character: Dictionary = GameData.characters[char_id]
		if not bool(character.get("unlocked", false)):
			continue
		var cid := str(char_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 62)
		button.toggle_mode = true
		button.text = (
			"%s  %s\n%s · %s"
			% [
				str(character.get("icon", "⚔️")),
				str(character.get("name", "")),
				str(character.get("role", "")),
				str(character.get("grade", ""))
			]
		)
		button.tooltip_text = str(character.get("desc", ""))
		button.set_meta("character_id", cid)
		button.pressed.connect(_select_character.bind(cid))
		character_list.add_child(button)


func _setup_preview():
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.09, 0.15, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	preview_viewport.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.5
	preview_viewport.add_child(light)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18, 18)
	floor.mesh = floor_mesh
	floor.position.y = -0.08
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.13, 0.2, 0.23)
	floor_material.roughness = 0.9
	floor.material_override = floor_material
	preview_viewport.add_child(floor)

	preview_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	preview_player.process_mode = Node.PROCESS_MODE_DISABLED
	preview_player.set("is_combat_enabled", false)
	preview_viewport.add_child(preview_player)
	preview_visual = preview_player.get_node("VisualRoot")


func _select_character(char_id: String):
	if not GameData.characters.has(char_id):
		return
	selected_character_id = char_id
	var character: Dictionary = GameData.characters[char_id]
	var stats := GameData.get_character_stat_manager(char_id)
	detail_name.text = (
		"%s · %s" % [str(character.get("icon", "⚔️")), str(character.get("name", ""))]
	)
	detail_title.text = (
		"%s | %s | Lv.%d"
		% [
			str(character.get("title", "")),
			str(character.get("role", "")),
			int(character.get("level", 1))
		]
	)
	detail_stats.text = (
		(
			"기본 능력치\nSTR %d   AGI %d   VIT %d\nINT %d   DEX %d   LUK %d\n\n"
			+ "전투 수치\nHP %d / SP %d   물리 공격 %.1f   마법 공격 %.1f\n"
			+ "물리 방어 %.1f   마법 방어 %.1f\n"
			+ "공격 속도 %.2f/s   명중 %.0f%%   회피 %.1f%%   크리티컬 %.1f%%"
		)
		% [
			stats.get_stat("STR"),
			stats.get_stat("AGI"),
			stats.get_stat("VIT"),
			stats.get_stat("INT"),
			stats.get_stat("DEX"),
			stats.get_stat("LUK"),
			stats.max_hp(),
			stats.max_sp(),
			stats.phys_atk(char_id == "archer"),
			stats.mag_atk(),
			stats.phys_def(),
			stats.mag_def(),
			1.2 * stats.attack_speed(),
			stats.hit_rate(),
			stats.evasion(),
			stats.crit_rate()
		]
	)
	skill_label.text = "대표 스킬: %s" % str(character.get("signature_skill", ""))
	weapon_label.text = "대표 무기: %s" % _get_weapon_name(char_id)
	detail_description.text = (
		"%s\n\n성장 방향: %s"
		% [str(character.get("desc", "")), str(CLASS_GROWTH.get(char_id, "균형 성장"))]
	)
	name_edit.text = str(GameData.DEFAULT_CHARACTER_NAMES.get(char_id, character.get("name", "")))
	_preview_rotation = 0.0
	var preview_color: Color = character.get("color", Color.WHITE)
	_update_preview_color(preview_color)
	_update_preview_weapon(char_id)
	for child in character_list.get_children():
		if child is Button:
			child.button_pressed = str(child.get_meta("character_id", "")) == char_id
	_update_create_button()


func _get_weapon_name(char_id: String) -> String:
	return str(CLASS_WEAPONS.get(char_id, "기본 무기"))


func _update_preview_color(color: Color):
	if preview_visual == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.25
	material.roughness = 0.45
	for node in preview_visual.find_children("*", "MeshInstance3D", true, false):
		if not node.has_meta("preview_prop"):
			(node as MeshInstance3D).material_override = material


func _update_preview_weapon(char_id: String):
	if preview_visual == null:
		return
	for child in preview_visual.get_children():
		if child.has_meta("preview_prop"):
			child.queue_free()
	var existing_sword := preview_visual.get_node_or_null("ArmR/Sword") as MeshInstance3D
	if existing_sword:
		existing_sword.visible = char_id in ["warrior", "paladin"]
	match char_id:
		"archer":
			var bow := TorusMesh.new()
			bow.inner_radius = 0.34
			bow.outer_radius = 0.4
			_add_preview_prop(
				bow, Vector3(0.55, 1.0, -0.16), Vector3(0.0, 0.0, 0.35), Color(0.55, 0.31, 0.12)
			)
			var arrow := BoxMesh.new()
			arrow.size = Vector3(0.035, 0.72, 0.035)
			_add_preview_prop(
				arrow, Vector3(0.5, 1.0, -0.22), Vector3(0.0, 0.0, -0.2), Color(0.9, 0.8, 0.55)
			)
		"mage":
			_add_preview_staff(Color(0.95, 0.35, 0.2))
		"paladin":
			var shield := BoxMesh.new()
			shield.size = Vector3(0.45, 0.66, 0.13)
			_add_preview_prop(
				shield, Vector3(0.58, 0.83, -0.12), Vector3(0.0, 0.0, -0.12), Color(0.85, 0.72, 0.3)
			)
		"assassin":
			var blade := BoxMesh.new()
			blade.size = Vector3(0.07, 0.72, 0.045)
			_add_preview_prop(
				blade, Vector3(-0.49, 0.98, -0.12), Vector3(0.0, 0.0, 0.2), Color(0.7, 0.82, 0.95)
			)
			_add_preview_prop(
				blade, Vector3(0.49, 0.98, -0.12), Vector3(0.0, 0.0, -0.2), Color(0.7, 0.82, 0.95)
			)
		"priest":
			_add_preview_staff(Color(0.45, 0.8, 1.0))


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


func _add_preview_prop(mesh: Mesh, prop_position: Vector3, prop_rotation: Vector3, color: Color):
	var prop := MeshInstance3D.new()
	prop.mesh = mesh
	prop.position = prop_position
	prop.rotation = prop_rotation
	prop.set_meta("preview_prop", true)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.38
	prop.material_override = material
	preview_visual.add_child(prop)


func _process(delta: float):
	if preview_visual == null:
		return
	_idle_time += delta
	preview_visual.rotation.y = _preview_rotation + sin(_idle_time * 0.7) * 0.08
	preview_visual.position.y = sin(_idle_time * 2.0) * 0.025


func _on_preview_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_last_drag_position = event.position
	elif event is InputEventMouseMotion and _dragging:
		_preview_rotation += (event.position.x - _last_drag_position.x) * 0.01
		_last_drag_position = event.position
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_last_drag_position = event.position
	elif event is InputEventScreenDrag and _dragging:
		_preview_rotation += event.relative.x * 0.01


func _randomize_name():
	name_edit.text = FIRST_NAMES.pick_random() + LAST_NAMES.pick_random()


func _on_name_changed(_new_text: String):
	_update_create_button()


func _update_create_button():
	var valid_name := not name_edit.text.strip_edges().is_empty()
	create_button.disabled = not valid_name
	create_button.tooltip_text = "캐릭터 이름을 입력하세요." if not valid_name else "선택한 직업으로 모험을 시작합니다."


func _on_create_pressed():
	var clean_name := name_edit.text.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 20:
		feedback_label.text = "이름을 1~20자로 입력해 주세요."
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		return
	GameData.reset_save()
	if not GameData.create_selected_character(selected_character_id, clean_name):
		feedback_label.text = "캐릭터를 생성하지 못했습니다. 직업과 이름을 확인해 주세요."
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		return
	GameManager.go_to_lobby()


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_title()
		get_viewport().set_input_as_handled()
