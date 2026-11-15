class_name UiStyle
extends RefCounted
## Shared visual helpers so every new screen looks and behaves like a button.

static func color_panel() -> Color:
	return Color(0.07, 0.09, 0.14, 0.97)

static func panel_style(
	bg: Color = Color(0.07, 0.09, 0.14, 0.97),
	border: Color = Color(0.85, 0.72, 0.35, 1.0),
	border_width: int = 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	return style

static func sub_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 0.85)
	style.border_color = Color(0.28, 0.38, 0.52, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func apply_button(button: Button, accent: bool = false):
	var normal_bg := Color(0.16, 0.23, 0.34, 0.96)
	var normal_border := Color(0.38, 0.58, 0.88, 0.9)
	if accent:
		normal_bg = Color(0.72, 0.32, 0.10, 0.98)
		normal_border = Color(1.0, 0.85, 0.35, 1.0)
	button.add_theme_stylebox_override("normal", button_style(normal_bg, normal_border))
	button.add_theme_stylebox_override("hover", button_style(normal_bg.lightened(0.14), Color(1.0, 0.85, 0.35, 1.0)))
	button.add_theme_stylebox_override("pressed", button_style(normal_bg.darkened(0.16), Color(1.0, 0.92, 0.55, 1.0)))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.12, 0.13, 0.16, 0.85), Color(0.25, 0.27, 0.30, 0.7)))
	button.add_theme_stylebox_override("focus", button_style(Color(0, 0, 0, 0), Color(1.0, 0.88, 0.45, 1.0)))
	button.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.65))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.97, 0.8))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.62))
	button.add_theme_font_size_override("font_size", 15)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func make_label(text: String, size: int = 14, color: Color = Color(0.92, 0.94, 1.0)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func make_title(text: String, size: int = 26) -> Label:
	return make_label(text, size, Color(1.0, 0.87, 0.45))

static func make_button(text: String, min_size: Vector2 = Vector2(140, 44), accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	apply_button(button, accent)
	return button

static func make_panel(bg: Color = Color(0.07, 0.09, 0.14, 0.97)) -> PanelContainer:
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
