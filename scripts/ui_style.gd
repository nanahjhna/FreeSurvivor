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
	var trim := clampi(border_width, 1, 2)
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
