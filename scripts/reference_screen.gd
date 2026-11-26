extends Control
## Places user-approved art and live controls in a common 552 × 940 space.

const SIZE := Vector2(552, 940)
const ART_ROOT := "res://assets/ui/screen_reference_"
const INK := Color("#2a241e")
const IVORY := Color("#f5ead0")
const AMBER := Color("#ffd684")
const SMITHY := ART_ROOT + "smithy.png"
const BACKGROUND_BLEND := preload("res://scripts/reference_background.gdshader")
const SCREENS := {
	"title": ["start", 0], "select": ["start", 1], "create": ["start", 2],
	"profile": ["hero", 0], "growth": ["hero", 1], "skills": ["hero", 2],
	"quest": ["codex", 0], "catalog": ["codex", 1], "card": ["codex", 2],
	"pause": ["options", 0], "settings": ["options", 1], "forge": ["options", 2],
	"stage": ["combat", 0], "hud": ["combat", 1], "result": ["combat", 2],
}

var art: Texture2D
var column := 0
var page: Control
var screen_id := ""
var updates: Array[Callable] = []
var update_elapsed := 0.0

func build(parent: Node, id: String, whole_page: bool = true) -> void:
	screen_id = id
	name = "Approved_" + id
	art = load(ART_ROOT + str(SCREENS[id][0]) + ".png") as Texture2D
	column = int(SCREENS[id][1])
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(self)
	if whole_page:
		var fill := ColorRect.new()
		fill.color = Color("#171411")
		fill.mouse_filter = Control.MOUSE_FILTER_STOP
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fill)
	page = Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.size = SIZE
	add_child(page)
	if whole_page:
		image(Rect2(Vector2.ZERO, SIZE), Rect2(Vector2.ZERO, SIZE))
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var safe := UiStyle.safe_insets(get_viewport())
	var insets := Vector2(safe.x + safe.z, safe.y + safe.w)
	var available := size - insets
	var zoom := maxf(0.01, minf(available.x / SIZE.x, available.y / SIZE.y))
	page.position = Vector2(safe.x, safe.y) + (available - SIZE * zoom) * 0.5
	page.scale = Vector2.ONE * zoom

func _process(delta: float) -> void:
	if not is_visible_in_tree() or (get_parent() is CanvasLayer and not get_parent().visible):
		return
	update_elapsed += delta
	if update_elapsed < 0.05:
		return
	update_elapsed = 0.0
	for callback in updates:
		callback.call()

func place(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size

func native(control: Control, rect: Rect2) -> void:
	control.reparent(page, false)
	control.custom_minimum_size = Vector2.ZERO
	place(control, rect)

func image(rect: Rect2, source: Rect2) -> TextureRect:
	return artwork(rect, crop(source))

func crop(source: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = art
	texture.region = Rect2(source.position + Vector2(2 + 558 * column, 1), source.size)
	texture.filter_clip = true
	return texture

func trim(source: Rect2, margin: float = 16.0, fill_center: bool = true) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = crop(source)
	style.draw_center = fill_center
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, margin)
		style.set_content_margin(side, margin)
	return style

func artwork(rect: Rect2, texture: Texture2D) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(picture)
	place(picture, rect)
	return picture

func mask(rect: Rect2, sample: Rect2) -> void:
	image(rect, sample)

func smithy(rect: Rect2, concealed: Rect2) -> void:
	var patch := artwork(rect, load(SMITHY) as Texture2D)
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_BLEND
	var top_left := (concealed.position - rect.position) / rect.size
	var bottom_right := (concealed.end - rect.position) / rect.size
	material.set_shader_parameter("concealed", Vector4(top_left.x, top_left.y, bottom_right.x, bottom_right.y))
	patch.material = material

func field(rect: Rect2, value: Callable, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, backing: Color = INK, color: Color = IVORY) -> Label:
	solid(rect, backing)
	return live_text(rect, value, font_size, align, color)

func show_label(source: Control, rect: Rect2, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, backing: Color = INK) -> Label:
	return field(rect, func(): return str(source.get("text")), font_size, align, backing)

func styled_button(rect: Rect2, title: String, action: Callable, primary: bool = false) -> Button:
	var button := UiStyle.make_button(title, Vector2.ZERO, primary)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	page.add_child(button)
	place(button, rect)
	return button

func solid(rect: Rect2, color: Color = INK) -> ColorRect:
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(fill)
	place(fill, rect)
	return fill

func text(rect: Rect2, caption: String, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, color: Color = IVORY) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", color)
	label.text = caption
	page.add_child(label)
	place(label, rect)
	return label

func live_text(rect: Rect2, value: Callable, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, color: Color = IVORY) -> Label:
	var label := text(rect, str(value.call()), font_size, align, color)
	updates.append(func():
		var current := str(value.call())
		if label.text != current:
			label.text = current
	)
	return label

func hit(rect: Rect2, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.tooltip_text = caption
	button.accessibility_name = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := UiStyle.frame(Color.TRANSPARENT, UiStyle.AMBER)
	focus.shadow_size = 0
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	page.add_child(button)
	place(button, rect)
	return button

func relay(rect: Rect2, source: Button) -> Button:
	var hit_target := hit(rect, source.text, func(): source.pressed.emit())
	hit_target.disabled = source.disabled
	updates.append(func(): hit_target.disabled = source.disabled)
	return hit_target

func bar(rect: Rect2, ratio: Callable, color: Color) -> void:
	solid(rect, Color("#211914"))
	var fill := solid(rect, color)
	var fit := func(): fill.size.x = rect.size.x * clampf(float(ratio.call()), 0, 1)
	fit.call()
	updates.append(fit)
