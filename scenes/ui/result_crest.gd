extends PanelContainer

var successful := false


func _ready() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var mid := size.x * 0.5
	var width := minf(size.x * 0.46, 280.0)
	var bottom := size.y - 8.0
	var silhouette := PackedVector2Array([
		Vector2(mid, 3), Vector2(mid + width, 57), Vector2(mid + width - 21, bottom - 65),
		Vector2(mid, bottom), Vector2(mid - width + 21, bottom - 65), Vector2(mid - width, 57),
	])
	draw_colored_polygon(silhouette, Color("#d5a156"))
	var inner := PackedVector2Array([
		Vector2(mid, 15), Vector2(mid + width - 12, 63), Vector2(mid + width - 31, bottom - 74),
		Vector2(mid, bottom - 12), Vector2(mid - width + 31, bottom - 74), Vector2(mid - width + 12, 63),
	])
	var main := Color("#315cb0") if successful else Color("#394279")
	draw_colored_polygon(inner, main)
	draw_colored_polygon(PackedVector2Array([inner[0], inner[1], inner[3], inner[5]]), main.lightened(0.13))
	draw_colored_polygon(PackedVector2Array([inner[1], inner[2], inner[3]]), main.darkened(0.16))
	draw_colored_polygon(PackedVector2Array([inner[3], inner[4], inner[5]]), main.darkened(0.25))
	for corner in [Vector2(mid - width + 14, 60), Vector2(mid + width - 14, 60)]:
		draw_set_transform(corner, PI / 4.0)
		draw_rect(Rect2(-10, -10, 20, 20), Color("#ffe2a1"))
	draw_set_transform(Vector2.ZERO)
