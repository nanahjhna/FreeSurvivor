extends Control

@export var radar_range: float = 40.0 # World distance represented from center to edge
@export var is_circular: bool = false

const MAP_SIZE := Vector2(124.0, 124.0)
const MIN_RANGE := 15.0
const MAX_RANGE := 100.0
const ZOOM_STEP := 10.0

var player: Node3D = null
var portal: Node3D = null
var _redraw_timer: float = 0.0
@onready var zoom_label: Label = $ZoomLabel

func _ready():
	custom_minimum_size = Vector2(170, 160)
	_update_zoom_label()

func _process(delta: float):
	_redraw_timer += delta
	if _redraw_timer < 0.15:
		return
	_redraw_timer = 0.0
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	
	if portal == null or not is_instance_valid(portal):
		portal = get_tree().current_scene.find_child("BattlePortal", true, false)
	
	queue_redraw()

func _draw():
	var center := MAP_SIZE * 0.5
	var radius := 56.0
	
	# Square map background and border.
	draw_rect(Rect2(Vector2(4, 4), MAP_SIZE - Vector2(8, 8)), Color(0.06, 0.09, 0.13, 0.92), true)
	draw_rect(Rect2(Vector2(4, 4), MAP_SIZE - Vector2(8, 8)), Color(0.35, 0.58, 0.78, 0.95), false, 3.0)
	draw_rect(Rect2(Vector2(34, 34), Vector2(56, 56)), Color(0.2, 0.3, 0.4, 0.35), false, 1.0)
	
	# Crosshairs (subtle)
	draw_line(Vector2(center.x, center.y - radius), Vector2(center.x, center.y + radius), Color(0.25, 0.35, 0.45, 0.25), 1.0)
	draw_line(Vector2(center.x - radius, center.y), Vector2(center.x + radius, center.y), Color(0.25, 0.35, 0.45, 0.25), 1.0)
	
	# North "N" Indicator at top
	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(center.x - 5, 19), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.9, 0.3, 0.3, 0.95))
	
	if player == null or not is_instance_valid(player):
		return
	
	var p_pos = player.global_position
	
	# 2. Render Map Entities
	if GameManager.current_location == GameManager.Location.LOBBY:
		_draw_village_elements(center, radius, p_pos)
	else:
		_draw_battle_elements(center, radius, p_pos)
	
	# 3. Draw Player Arrow in Center
	_draw_player_arrow(center)

func _draw_village_elements(center: Vector2, radius: float, p_pos: Vector3):
	# Fountain at world (0, 0, 0)
	var f_pos = _world_to_map(Vector3(0, 0, 0), p_pos, center, radius)
	if _inside_map(f_pos):
		draw_circle(f_pos, 4.5, Color(0.2, 0.6, 0.9, 0.9))
	
	# Important Village landmarks
	var landmarks = [
		{"pos": Vector3(-22, 0, 0), "color": Color(0.8, 0.5, 0.2), "size": 5.0}, # Blacksmith
		{"pos": Vector3(22, 0, 0), "color": Color(0.3, 0.7, 0.9), "size": 5.0},  # Weapon Shop
		{"pos": Vector3(18, 0, 20), "color": Color(0.5, 0.4, 0.8), "size": 6.0}, # Inn
		{"pos": Vector3(0, 0, -40), "color": Color(0.7, 0.7, 0.75), "size": 7.0}  # North Gate
	]
	for lm in landmarks:
		var pos_2d = _world_to_map(lm["pos"], p_pos, center, radius)
		if _inside_map(pos_2d):
			draw_rect(Rect2(pos_2d - Vector2(lm["size"]*0.5, lm["size"]*0.5), Vector2(lm["size"], lm["size"])), lm["color"])
	
	# NPCs (Green/Cyan dots)
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if is_instance_valid(npc):
			var n_pos = _world_to_map(npc.global_position, p_pos, center, radius)
			if _inside_map(n_pos):
				draw_circle(n_pos, 2.8, Color(0.25, 0.9, 0.4, 0.9))
	
	# Battle Portal Indicator (Always clamped to circle edge if outside!)
	var portal_world = Vector3(0, 0, -40)
	if portal and is_instance_valid(portal):
		portal_world = portal.global_position
	
	var portal_map_pos = _world_to_map_clamped_square(portal_world, p_pos, center, radius - 6.0)
	# Draw glowing portal diamond
	_draw_diamond(portal_map_pos, 7.0, Color(0.95, 0.2, 0.95, 1.0))
	_draw_diamond(portal_map_pos, 4.0, Color(1.0, 0.85, 1.0, 1.0))

func _draw_battle_elements(center: Vector2, radius: float, p_pos: Vector3):
	# XP Gems (small yellow-green dots)
	var gems = get_tree().get_nodes_in_group("xp_gems")
	for gem in gems:
		if is_instance_valid(gem):
			var g_pos = _world_to_map(gem.global_position, p_pos, center, radius)
			if _inside_map(g_pos):
				draw_circle(g_pos, 2.0, Color(0.3, 1.0, 0.4, 0.85))
	
	# Enemies (Red dots)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var e_pos = _world_to_map(enemy.global_position, p_pos, center, radius)
			if _inside_map(e_pos):
				# Mutants are bigger
				if enemy.get("max_hp") and enemy.max_hp > 50:
					draw_circle(e_pos, 4.2, Color(1.0, 0.15, 0.35, 1.0))
				else:
					draw_circle(e_pos, 2.8, Color(0.95, 0.25, 0.2, 0.9))

func _draw_player_arrow(center: Vector2):
	var rot_y = 0.0
	var visual_root = player.get_node_or_null("VisualRoot")
	if visual_root:
		rot_y = visual_root.rotation.y
	else:
		rot_y = player.rotation.y
	
	# Forward direction in 2D minimap
	var forward = Vector2(sin(rot_y), cos(rot_y)) # In 3D: X is right, Z is down/back
	var normal = Vector2(-forward.y, forward.x)
	
	var tip = center + forward * 8.0
	var left = center - forward * 5.0 + normal * 5.0
	var right = center - forward * 5.0 - normal * 5.0
	var back_indent = center - forward * 2.0
	
	var points = PackedVector2Array([tip, left, back_indent, right])
	draw_colored_polygon(points, Color(0.2, 0.85, 1.0, 1.0))
	draw_polyline(points, Color(1, 1, 1, 0.9), 1.2)

func _world_to_map(world_pos: Vector3, player_pos: Vector3, center: Vector2, radius: float) -> Vector2:
	var delta_3d = world_pos - player_pos
	var map_x = center.x + (delta_3d.x / radar_range) * radius
	var map_y = center.y + (delta_3d.z / radar_range) * radius
	return Vector2(map_x, map_y)

func _world_to_map_clamped(world_pos: Vector3, player_pos: Vector3, center: Vector2, max_radius: float) -> Vector2:
	var delta_3d = world_pos - player_pos
	var unscaled = Vector2(delta_3d.x, delta_3d.z)
	var dist = unscaled.length()
	var scaled_dist = (dist / radar_range) * max_radius
	
	if scaled_dist > max_radius:
		scaled_dist = max_radius
	
	var dir = unscaled.normalized() if dist > 0.001 else Vector2.UP
	return center + dir * scaled_dist

func _world_to_map_clamped_square(world_pos: Vector3, player_pos: Vector3, center: Vector2, half_extent: float) -> Vector2:
	var mapped := _world_to_map(world_pos, player_pos, center, half_extent)
	return Vector2(clampf(mapped.x, center.x - half_extent, center.x + half_extent), clampf(mapped.y, center.y - half_extent, center.y + half_extent))

func _inside_map(point: Vector2) -> bool:
	return point.x >= 6.0 and point.x <= MAP_SIZE.x - 6.0 and point.y >= 6.0 and point.y <= MAP_SIZE.y - 6.0

func _on_zoom_in():
	radar_range = maxf(MIN_RANGE, radar_range - ZOOM_STEP)
	_update_zoom_label()
	queue_redraw()

func _on_zoom_out():
	radar_range = minf(MAX_RANGE, radar_range + ZOOM_STEP)
	_update_zoom_label()
	queue_redraw()

func _update_zoom_label():
	if zoom_label:
		zoom_label.text = "%dm" % int(radar_range)

func _draw_diamond(pos: Vector2, s: float, col: Color):
	var pts = PackedVector2Array([
		pos + Vector2(0, -s),
		pos + Vector2(s, 0),
		pos + Vector2(0, s),
		pos + Vector2(-s, 0)
	])
	draw_colored_polygon(pts, col)
