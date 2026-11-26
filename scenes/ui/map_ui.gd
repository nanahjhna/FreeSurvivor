extends CanvasLayer

signal closed()
signal landmark_selected(landmark_id: String)

const MINIMAP_SCENE: PackedScene = preload("res://scenes/ui/minimap.tscn")
const LANDMARKS := {
	"forge": ["대장간", "forge"],
	"shop": ["스킬 상점", "skill"],
	"inn": ["여관", "bed"],
	"quest": ["게시판", "quest"],
	"battle_start": ["서바이벌 던전", "gate"],
}

var destination_label: Label
var destination_icon: TextureRect
var chosen_landmark := "battle_start"
var landmark_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	hide()
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = UiStyle.SCRIM
	add_child(backdrop)
	var layout := UiStyle.dialog_layout(self, "", 660)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	header.add_child(UiStyle.icon_view("compass", 29))
	var title := UiStyle.make_title("마을 지도", 29)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := UiStyle.make_button("×", Vector2(52, 48))
	close_button.pressed.connect(close_screen)
	header.add_child(close_button)

	var map_frame := UiStyle.make_panel(UiStyle.ASPHALT)
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.custom_minimum_size.y = 190
	layout.add_child(map_frame)
	var map_view := AspectRatioContainer.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiStyle.make_margin(map_frame, 4).add_child(map_view)
	var minimap := MINIMAP_SCENE.instantiate()
	map_view.add_child(minimap)
	minimap.set_compact_display()
	minimap.radar_range = 80.0

	var choices := GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 8)
	choices.add_theme_constant_override("v_separation", 8)
	layout.add_child(choices)
	for id in LANDMARKS:
		var entry: Array = LANDMARKS[id]
		var button := UiStyle.make_button(entry[0], Vector2(0, 48))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 17)
		UiStyle.button_icon(button, entry[1], 22)
		button.pressed.connect(_set_landmark.bind(id))
		choices.add_child(button)
		landmark_buttons[id] = button

	var selected_row := HBoxContainer.new()
	selected_row.add_theme_constant_override("separation", 9)
	layout.add_child(selected_row)
	destination_icon = UiStyle.icon_view("gate", 27, UiStyle.GOLD_BRIGHT)
	selected_row.add_child(destination_icon)
	destination_label = UiStyle.make_title("", 23)
	destination_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_row.add_child(destination_label)
	var travel_button := UiStyle.make_button("자동 이동   ›", Vector2(0, 56), true)
	travel_button.add_theme_font_size_override("font_size", 22)
	travel_button.pressed.connect(_confirm_landmark)
	layout.add_child(travel_button)

func open() -> void:
	_set_landmark(chosen_landmark)
	show()

func close_screen() -> void:
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

func _set_landmark(landmark_id: String) -> void:
	if not LANDMARKS.has(landmark_id):
		return
	chosen_landmark = landmark_id
	destination_label.text = LANDMARKS[landmark_id][0]
	destination_icon.texture = UiStyle.icon(LANDMARKS[landmark_id][1])
	for id in landmark_buttons:
		var active: bool = id == chosen_landmark
		UiStyle.skin_button(landmark_buttons[id], UiStyle.SELECTED if active else UiStyle.INK_SOFT,
			UiStyle.AMBER if active else UiStyle.STEEL, UiStyle.IVORY)

func _confirm_landmark() -> void:
	close_screen()
	landmark_selected.emit(chosen_landmark)
