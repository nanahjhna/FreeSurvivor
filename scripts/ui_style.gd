class_name UiStyle
extends RefCounted
## Shared visual system for the game's post-apocalyptic interface.

const ART := preload("res://scripts/ui_artwork.gd")
const ASPHALT := Color("#1a1917")
const INK := Color("#23211f")
const INK_SOFT := Color("#302c27")
const STEEL := Color("#8e7762")
const STEEL_DARK := Color("#51453b")
const RUST := Color("#bd9169")
const SELECTED := Color("#40362a")
const WOOD := Color("#2c2824")
const PAPER := Color("#e1c9a0")
const PAPER_EDGE := Color("#b9946c")
const PAPER_INK := Color("#34261c")
const CTA := Color("#ac482b")
const CTA_EDGE := Color("#ed9568")
const DANGER := Color("#52302a")
const DANGER_EDGE := Color("#d47a67")
const SCRIM := Color(0.055, 0.050, 0.044, 0.75)
const GOLD := Color("#bf9154")
const GOLD_BRIGHT := Color("#fac574")
const IVORY := Color("#f5ebd9")
const MUTED := Color("#cbbca9")
const AMBER := Color("#eeb45f")
const ATTACK := Color("#fa9467")
const DEFENSE := Color("#8bc6fc")
const RECOVERY := Color("#a2df99")

const ICON_PATHS := {
	"person": "M12 11a4 4 0 1 0 0-8a4 4 0 0 0 0 8m0 2c-5 0-9 3-9 7v1h18v-1c0-4-4-7-9-7",
	"sword": "M21 2l-2 6L9 18l-3-3L16 5zM3 12l9 9l-2 2l-3-3l-3 3l-3-3l3-3l-3-3z",
	"armor": "M8 3l-5 2l-2 6l5 2l1-3v11h10V10l1 3l5-2l-2-6l-5-2c-1 4-7 4-8 0",
	"shield": "M12 2l9 4v6c0 5-5 9-9 11c-4-2-9-6-9-11V6zm0 3L6 7v5c0 3 3 6 6 8c3-2 6-5 6-8V7z",
	"ring": "M7 3h10l3 4l-4 4h-8L4 7zm5 8a6.5 6.5 0 1 1 0 13a6.5 6.5 0 0 1 0-13m0 3a3.5 3.5 0 1 0 0 7a3.5 3.5 0 0 0 0-7",
	"boots": "M10 2h9v12l2 2v5H3v-4l7-4zm2 2v2h5V4z",
	"skill": "M12 0l3 8l8 4l-8 3l-3 9l-3-9l-8-3l8-4z",
	"speed": "M13 1L3 14h7l-1 9l12-13h-8z",
	"heal": "M8 2h8v6h6v8h-6v6H8v-6H2V8h6z",
	"compass": "M12 1a11 11 0 1 0 0 22a11 11 0 0 0 0-22m0 2a9 9 0 1 1 0 18a9 9 0 0 1 0-18m5 4l-3 7l-7 3l3-7z",
	"gate": "M1 6l4-4l4 4H7v6l5-4l5 4V6h-2l4-4l4 4h-2v15h-7v-5a2 2 0 0 0-4 0v5H3V6z",
	"forge": "M2 5h20v3l-4 4h-4v4l5 2v3H5v-3l5-2v-4H7L2 8z",
	"bed": "M2 4h2v8h2V8h5a3 3 0 0 1 3 3v1h1V9h4a3 3 0 0 1 3 3v8h-2v-3H4v3H2z",
	"quest": "M5 2h14v16h-8l-4 4v-4H5zm3 4v2h8V6zm0 4v2h8v-2zm0 4v2h5v-2z",
	"play": "M5 3l16 9L5 21z",
	"restart": "M20 2v7h-7l2.6-2.6A7 7 0 1 0 19 14h3a10 10 0 1 1-4.2-9.8z",
	"home": "M12 2l11 9h-3v10h-6v-6h-4v6H4V11H1z",
	"settings": "M10 1h4l1 4l3-1l3 3l-2 3l4 1v4l-4 1l1 3l-3 3l-3-2l-1 3h-4l-1-4l-3 1l-3-3l2-3l-3-1v-4l4-1l-1-3l3-3l3 2zm2 7a4 4 0 1 0 0 8a4 4 0 0 0 0-8",
	"coin": "M12 1a11 11 0 1 0 0 22a11 11 0 0 0 0-22m0 2a9 9 0 1 1 0 18a9 9 0 0 1 0-18m-2 3h4l3 6l-5 6l-5-6z",
}

static var _icon_cache: Dictionary = {}

static func icon(kind: String) -> Texture2D:
	if not _icon_cache.has(kind):
		if ART.ICON_REGIONS.has(kind):
			_icon_cache[kind] = ART.icon(kind)
			return _icon_cache[kind]
		var shape: String = ICON_PATHS.get(kind, ICON_PATHS["skill"])
		var source := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24"><path fill="#ffffff" fill-rule="evenodd" d="%s"/></svg>' % shape
		var image := Image.new()
		if image.load_svg_from_string(source) != OK:
			return null
		_icon_cache[kind] = ImageTexture.create_from_image(image)
	return _icon_cache[kind]

static func icon_view(kind: String, pixels: int, tint: Color = IVORY) -> TextureRect:
	var view := TextureRect.new()
	view.texture = icon(kind)
	view.modulate = Color.WHITE if tint == IVORY and ART.ICON_REGIONS.has(kind) else tint
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = Vector2(pixels, pixels)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

static func button_icon(button: Button, kind: String, pixels: int = 24, above: bool = false) -> void:
	button.icon = icon(kind)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", pixels)
	button.add_theme_constant_override("h_separation", 8)
	var ink := Color.WHITE if ART.ICON_REGIONS.has(kind) else IVORY
	button.add_theme_color_override("icon_normal_color", ink)
	button.add_theme_color_override("icon_hover_color", ink)
	button.add_theme_color_override("icon_pressed_color", ink)
	button.add_theme_color_override("icon_disabled_color", MUTED)
	if above:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

static func category_tint(category: String) -> Color:
	match category:
		"attack": return ATTACK
		"defense": return DEFENSE
		"recovery": return RECOVERY
	return GOLD_BRIGHT

static func category_icon(category: String) -> String:
	match category:
		"attack": return "sword"
		"defense": return "shield"
		"recovery": return "heal"
	return "skill"

static func frame(face: Color, edge: Color, radius: int = 10, thickness: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.border_color = edge
	style.set_border_width_all(thickness)
	style.border_width_bottom = thickness + 1
	style.set_corner_radius_all(radius)
	style.corner_detail = 1
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_offset = Vector2(0, 3)
	style.shadow_size = 3
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func art_panel(edge: Color = RUST, padding: Vector2 = Vector2(13, 8), opacity: float = 1.0) -> StyleBoxTexture:
	var variant := "selected" if edge == AMBER else "panel"
	return ART.surface(variant, padding, Color(1, 1, 1, opacity))

static func notice_board() -> PanelContainer:
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", art_panel())
	return board

static func paper_style(edge: Color = PAPER_EDGE) -> StyleBoxFlat:
	return frame(PAPER, edge, 4)

static func metric(parent: Control, caption: String, value: String, on_paper: bool = false) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	parent.add_child(column)
	var label := make_label(caption, 15, PAPER_INK if on_paper else MUTED)
	var number := make_label(value, 20, PAPER_INK if on_paper else IVORY)
	for text in [label, number]:
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(text)

static func skin_button(button: Button, face: Color, edge: Color, ink: Color = Color.WHITE) -> void:
	var art_kind := ""
	if face == CTA:
		art_kind = "primary"
	elif face == SELECTED:
		art_kind = "selected"
	elif face in [INK_SOFT, INK, ASPHALT, WOOD]:
		art_kind = "neutral"
	if art_kind.is_empty():
		button.add_theme_stylebox_override("normal", frame(face, edge))
		button.add_theme_stylebox_override("hover", frame(face.lightened(0.16), edge.lightened(0.18)))
		button.add_theme_stylebox_override("pressed", frame(face.darkened(0.22), edge))
		button.add_theme_stylebox_override("disabled", frame(face.darkened(0.42), edge.darkened(0.34)))
	else:
		var tint := Color.WHITE
		if art_kind == "neutral" and edge in [grade_color("R"), grade_color("SR"), grade_color("SSR")]:
			tint = tint.lerp(edge, 0.20)
		var padding := Vector2(13, 8)
		button.add_theme_stylebox_override("normal", ART.surface(art_kind, padding, tint))
		button.add_theme_stylebox_override("hover", ART.surface(art_kind, padding, tint * Color(1.10, 1.10, 1.10)))
		button.add_theme_stylebox_override("pressed", ART.surface(art_kind, padding, tint.darkened(0.18)))
		button.add_theme_stylebox_override("disabled", ART.surface(art_kind, padding, tint.darkened(0.42)))
	var focus := frame(Color.TRANSPARENT, edge.lightened(0.45))
	focus.shadow_size = 0
	button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", ink.lerp(face, 0.43))

static func ink_outline(label: Label, width: int = 6, tint: Color = ASPHALT) -> void:
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
	panel.add_theme_stylebox_override("panel", frame(face, trim))
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
	line.color = Color(STEEL, 0.72)
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
		var viewport_size := layer.get_viewport().get_visible_rect().size
		var compact := viewport_size.y >= viewport_size.x and viewport_size.x < 600.0
		var side := maxi(14 if compact else 24, int((viewport_size.x - max_width) / 2.0))
		apply_safe_margins(inset, side)
		var safe := safe_insets(layer.get_viewport())
		var vertical_margin := 14 if compact else 24
		inset.add_theme_constant_override("margin_top", vertical_margin + ceili(safe.y))
		inset.add_theme_constant_override("margin_bottom", vertical_margin + ceili(safe.w))
	layer.get_viewport().size_changed.connect(refresh)
	refresh.call()
	var content := VBoxContainer.new()
	var compact := layer.get_viewport().get_visible_rect().size.y >= layer.get_viewport().get_visible_rect().size.x and layer.get_viewport().get_visible_rect().size.x < 600.0
	content.add_theme_constant_override("separation", 8 if compact else 14)
	make_margin(panel, 12 if compact else 20).add_child(content)
	if not title.is_empty():
		content.add_child(make_title(title, 31))
		divider(content)
	return content

static func scroll_column(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.scroll_deadzone = 12
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var viewport_size := parent.get_viewport().get_visible_rect().size
	var compact := viewport_size.y >= viewport_size.x and viewport_size.x < 600.0
	column.add_theme_constant_override("separation", 8 if compact else 12)
	scroll.add_child(column)
	return column

static func color_panel() -> Color:
	return INK

static func panel_style(
	bg: Color = INK,
	border: Color = STEEL,
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
	style.set_corner_radius_all(10)
	style.corner_detail = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 5
	return style

static func sub_panel_style() -> StyleBoxFlat:
	return panel_style(INK_SOFT, STEEL_DARK, 1)

static func apply_button(button: Button, accent: bool = false):
	skin_button(button, CTA if accent else INK_SOFT, CTA_EDGE if accent else STEEL, IVORY)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.22))
	button.add_theme_font_size_override("font_size", 15)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not button.has_meta("_sfx_click_bound"):
		button.pressed.connect(func(): play_sfx("ui_click"))
		button.set_meta("_sfx_click_bound", true)

static func play_sfx(sound_id: String, volume_db: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var sfx := tree.root.get_node_or_null("SfxManager")
	if sfx and sfx.has_method("play"):
		sfx.play(sound_id, volume_db)

static func make_label(text: String, size: int = 14, color: Color = IVORY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func make_title(text: String, size: int = 26) -> Label:
	var label := make_label(text, size, IVORY)
	label.add_theme_color_override("font_outline_color", ASPHALT)
	label.add_theme_constant_override("outline_size", 2)
	return label

static func make_button(text: String, min_size: Vector2 = Vector2(140, 44), accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	apply_button(button, accent)
	return button

static func make_clean_button(text: String, min_size: Vector2 = Vector2(140, 44), selected: bool = false, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	style_clean_button(button, selected, accent)
	if not button.has_meta("_sfx_click_bound"):
		button.pressed.connect(func(): play_sfx("ui_click"))
		button.set_meta("_sfx_click_bound", true)
	return button

static func style_clean_button(button: Button, selected: bool = false, accent: bool = false) -> void:
	var face := CTA if accent else (SELECTED if selected else INK_SOFT)
	var edge := CTA_EDGE if accent else (AMBER if selected else STEEL)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var state_face := face
		if state == "hover":
			state_face = face.lightened(0.10)
		elif state == "pressed":
			state_face = face.darkened(0.12)
		elif state == "disabled":
			state_face = face.darkened(0.35)
		var style := frame(state_face, edge, 7, 1)
		style.shadow_size = 1
		style.shadow_offset = Vector2.ZERO
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, IVORY)
	button.add_theme_color_override("font_disabled_color", MUTED)

static func attention_badge(diameter: float = 30.0) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := frame(Color("#a63f35"), Color("#f6ba70"), 99, 2)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.shadow_size = 2
	style.shadow_color = Color(0.08, 0.01, 0.0, 0.65)
	badge.add_theme_stylebox_override("panel", style)
	var label := make_label("!", maxi(15, roundi(diameter * 0.62)), IVORY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge

static func attention_button(diameter: float = 30.0) -> Button:
	var button := Button.new()
	button.text = "!"
	diameter = maxf(32.0, diameter)
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.tooltip_text = "설명 보기"
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", maxi(17, roundi(diameter * 0.58)))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var face := Color("#30251f") if state != "hover" else Color("#4a3024")
		var state_style := frame(face, Color("#e7a951"), 99, 2)
		state_style.content_margin_left = 0
		state_style.content_margin_top = 0
		state_style.content_margin_right = 0
		state_style.content_margin_bottom = 0
		state_style.shadow_size = 1
		button.add_theme_stylebox_override(state, state_style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, GOLD_BRIGHT)
	return button

static func make_panel(bg: Color = INK) -> PanelContainer:
	var panel := PanelContainer.new()
	if bg in [INK, INK_SOFT, ASPHALT, WOOD]:
		panel.add_theme_stylebox_override("panel", art_panel(RUST, Vector2(2, 2)))
	else:
		panel.add_theme_stylebox_override("panel", panel_style(bg))
	return panel

static func make_margin(panel: Control, amount: int = 24) -> MarginContainer:
	var margin := MarginContainer.new()
	var update_margins := func() -> void:
		var compact_amount := amount
		if panel.is_inside_tree():
			var viewport_size := panel.get_viewport().get_visible_rect().size
			if viewport_size.y >= viewport_size.x and viewport_size.x < 600.0:
				compact_amount = mini(amount, 14)
		margin.add_theme_constant_override("margin_left", compact_amount)
		margin.add_theme_constant_override("margin_top", compact_amount)
		margin.add_theme_constant_override("margin_right", compact_amount)
		margin.add_theme_constant_override("margin_bottom", compact_amount)
	panel.add_child(margin)
	if panel.is_inside_tree():
		panel.get_viewport().size_changed.connect(update_margins)
	update_margins.call()
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

static func fit_centered_panel(panel: Control, maximum_size: Vector2, padding: Vector2 = Vector2(16, 16)) -> bool:
	var viewport_size := panel.get_viewport().get_visible_rect().size
	var safe := safe_insets(panel.get_viewport())
	var target := Vector2(
		minf(maximum_size.x, viewport_size.x - safe.x - safe.z - padding.x * 2.0),
		minf(maximum_size.y, viewport_size.y - safe.y - safe.w - padding.y * 2.0)
	)
	panel.custom_minimum_size = Vector2(maxf(1.0, target.x), maxf(1.0, target.y))
	return viewport_size.y >= viewport_size.x
