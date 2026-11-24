class_name UiStyle
extends RefCounted
## Shared visual system for the game's dark gothic fantasy screens.

const INK := Color(0.035, 0.027, 0.03, 0.96)
const INK_SOFT := Color(0.075, 0.052, 0.047, 0.94)
const WINE := Color(0.27, 0.035, 0.03, 0.98)
const WINE_HOVER := Color(0.42, 0.065, 0.04, 1.0)
const GOLD := Color(0.86, 0.62, 0.29, 0.95)
const GOLD_BRIGHT := Color(1.0, 0.82, 0.43, 1.0)
const IVORY := Color(0.96, 0.91, 0.81, 1.0)
const MUTED := Color(0.70, 0.64, 0.56, 1.0)
const PAPER := Color("#f7e5b8")
const PAPER_INK := Color("#392519")
const AMBER := Color("#ffd275")
const BLUE := Color("#2456a2")
const BLUE_EDGE := Color("#8dd2ff")

static func frame(face: Color, edge: Color, radius: int = 12, thickness: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.border_color = edge
	style.set_border_width_all(thickness)
	style.border_width_bottom = thickness + 2
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.033, 0.018, 0.027, 0.58)
	style.shadow_offset = Vector2(0, 5)
	style.shadow_size = 5
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func skin_button(button: Button, face: Color, edge: Color, ink: Color = Color.WHITE) -> void:
	button.add_theme_stylebox_override("normal", frame(face, edge))
	button.add_theme_stylebox_override("hover", frame(face.lightened(0.16), edge.lightened(0.18)))
	button.add_theme_stylebox_override("pressed", frame(face.darkened(0.22), edge))
	button.add_theme_stylebox_override("focus", frame(Color.TRANSPARENT, edge.lightened(0.45)))
	button.add_theme_stylebox_override("disabled", frame(face.darkened(0.42), edge.darkened(0.34)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", ink.lerp(face, 0.43))

static func ink_outline(label: Label, width: int = 6, tint: Color = Color("#151122")) -> void:
	label.add_theme_color_override("font_outline_color", tint)
	label.add_theme_constant_override("outline_size", width)

static func tint_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([top, bottom])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.width = 8
	texture.height = 256
	texture.fill_to = Vector2(0, 1)
	return texture

static func plaque(text: String, face: Color, trim: Color, ink: Color, font_size: int = 30) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame(face, trim, 9, 3))
	var label := make_label(text, font_size, ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel

static func safe_insets(viewport: Viewport) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var area := DisplayServer.get_display_safe_area()
	if not area.has_area():
		return Vector4.ZERO
	var to_viewport := viewport.get_screen_transform().affine_inverse()
	var start := to_viewport * Vector2(area.position)
	var end := to_viewport * Vector2(area.end)
	var rect := viewport.get_visible_rect()
	return Vector4(
		maxf(0.0, start.x - rect.position.x), maxf(0.0, start.y - rect.position.y),
		maxf(0.0, rect.end.x - end.x), maxf(0.0, rect.end.y - end.y)
	)

static func apply_safe_margins(margin: MarginContainer, base: int = 24) -> void:
	var safe := safe_insets(margin.get_viewport())
	margin.add_theme_constant_override("margin_left", base + ceili(safe.x))
	margin.add_theme_constant_override("margin_top", base + ceili(safe.y))
	margin.add_theme_constant_override("margin_right", base + ceili(safe.z))
	margin.add_theme_constant_override("margin_bottom", base + ceili(safe.w))

static func divider(parent: Control) -> void:
	var line := ColorRect.new()
	line.color = Color(GOLD, 0.45)
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

static func format_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%02d:%02d" % [int(whole / 60.0), whole % 60]

static func grade_color(grade: String) -> Color:
	match grade:
		"SSR": return GOLD_BRIGHT
		"SR": return Color("#c7a0ed")
		"R": return Color("#8fb9e6")
	return Color("#a49a8d")

static func dialog_layout(layer: CanvasLayer, title: String, max_width: float = 700.0) -> VBoxContainer:
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(inset)
	var panel := make_panel()
	inset.add_child(panel)
	var refresh := func():
		var side := maxi(24, int((layer.get_viewport().get_visible_rect().size.x - max_width) / 2.0))
		apply_safe_margins(inset, side)
		var safe := safe_insets(layer.get_viewport())
		inset.add_theme_constant_override("margin_top", 24 + ceili(safe.y))
		inset.add_theme_constant_override("margin_bottom", 24 + ceili(safe.w))
	layer.get_viewport().size_changed.connect(refresh)
	refresh.call()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	make_margin(panel, 20).add_child(content)
	if not title.is_empty():
		content.add_child(make_title(title, 31))
		divider(content)
	return content

static func scroll_column(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	return column

static func color_panel() -> Color:
	return INK

static func panel_style(
	bg: Color = INK,
	border: Color = GOLD,
	border_width: int = 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg.r, bg.g, bg.b, minf(bg.a, 0.97))
	style.border_color = Color(border.r, border.g, border.b, minf(border.a, 0.92))
	var trim := clampi(border_width, 0, 2)
	style.border_width_left = trim
	style.border_width_top = trim
	style.border_width_right = trim
	style.border_width_bottom = trim
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 5
	return style

static func sub_panel_style() -> StyleBoxFlat:
	return panel_style(INK_SOFT, Color(0.48, 0.32, 0.18, 0.72), 1)

static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = 3
	return style

static func apply_button(button: Button, accent: bool = false):
	var normal_bg := INK_SOFT
	var normal_border := Color(0.62, 0.43, 0.23, 0.86)
	if accent:
		normal_bg = WINE
		normal_border = GOLD_BRIGHT
	button.add_theme_stylebox_override("normal", button_style(normal_bg, normal_border))
	button.add_theme_stylebox_override("hover", button_style(WINE_HOVER if accent else Color(0.16, 0.09, 0.065, 1.0), GOLD_BRIGHT))
	button.add_theme_stylebox_override("pressed", button_style(Color(0.16, 0.025, 0.025, 1.0), GOLD))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.09, 0.075, 0.07, 0.86), Color(0.32, 0.27, 0.21, 0.62)))
	button.add_theme_stylebox_override("focus", button_style(Color(0, 0, 0, 0), GOLD_BRIGHT))
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_pressed_color", IVORY)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.51, 0.46, 0.8))
	button.add_theme_font_size_override("font_size", 15)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func make_label(text: String, size: int = 14, color: Color = IVORY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func make_title(text: String, size: int = 26) -> Label:
	var label := make_label(text, size, GOLD_BRIGHT)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.025, 0.015, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	return label

static func make_button(text: String, min_size: Vector2 = Vector2(140, 44), accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	apply_button(button, accent)
	return button

static func make_panel(bg: Color = INK) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(bg))
	return panel

static func make_margin(panel: Control, amount: int = 24) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	panel.add_child(margin)
	return margin

static func fit_modal(panel: Control, maximum_size: Vector2, padding: Vector2 = Vector2(16, 24)) -> bool:
	var viewport_size := panel.get_viewport().get_visible_rect().size
	var portrait := viewport_size.y >= viewport_size.x
	var target := Vector2(
		minf(maximum_size.x, viewport_size.x - padding.x * 2.0),
		minf(maximum_size.y, viewport_size.y - padding.y * 2.0)
	)
	panel.custom_minimum_size = target
	if panel.get_parent() is CanvasLayer:
		panel.offset_left = -target.x * 0.5
		panel.offset_right = target.x * 0.5
		panel.offset_top = -target.y * 0.5
		panel.offset_bottom = target.y * 0.5
	return portrait
