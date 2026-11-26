extends PanelContainer

var successful := false


func _ready() -> void:
	var trim := UiStyle.AMBER if successful else UiStyle.DANGER_EDGE
	add_theme_stylebox_override("panel", UiStyle.art_panel(trim))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 100.0 or size.y < 40.0:
		return
	var rule := Color(UiStyle.RUST, 0.40)
	draw_line(Vector2(20, 16), Vector2(size.x - 20, 16), rule, 1.0)
	draw_line(Vector2(20, size.y - 16), Vector2(size.x - 20, size.y - 16), rule, 1.0)
