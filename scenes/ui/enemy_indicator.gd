extends Control

var margin: float = 45.0

func _draw():
	var cam = get_viewport().get_camera_3d()
	var player = get_tree().get_first_node_in_group("player")
	if cam == null or player == null or not is_instance_valid(player):
		return
	
	var vp_size = get_viewport_rect().size
	var center = vp_size * 0.5
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead"):
			continue
		
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist > 35.0:
			continue
		
		var is_behind = cam.is_position_behind(enemy.global_position)
		var screen_pos = cam.unproject_position(enemy.global_position)
		
		if is_behind:
			screen_pos = center - (screen_pos - center)
		
		var is_on_screen = not is_behind and screen_pos.x >= margin and screen_pos.x <= vp_size.x - margin and screen_pos.y >= margin and screen_pos.y <= vp_size.y - margin
		
		if not is_on_screen:
			# Raycast from center to screen_pos clipped to screen rect
			var dir = (screen_pos - center).normalized()
			if dir.length_squared() < 0.001:
				dir = Vector2.UP
			
			var edge_pos = _get_intersection_with_screen(center, dir, vp_size, margin)
			
			# Intensity based on distance (closer = redder and bigger)
			var urgency = clamp(1.0 - (dist / 30.0), 0.25, 1.0)
			var color = Color(1.0, 0.15, 0.15, urgency * 0.9)
			var arrow_size = lerp(14.0, 26.0, urgency)
			
			_draw_arrow(edge_pos, dir, arrow_size, color)

func _get_intersection_with_screen(center: Vector2, dir: Vector2, vp_size: Vector2, pad: float) -> Vector2:
	var min_bound = Vector2(pad, pad)
	var max_bound = vp_size - Vector2(pad, pad)
	
	var t_x = 999999.0
	if dir.x > 0.0001:
		t_x = (max_bound.x - center.x) / dir.x
	elif dir.x < -0.0001:
		t_x = (min_bound.x - center.x) / dir.x
	
	var t_y = 999999.0
	if dir.y > 0.0001:
		t_y = (max_bound.y - center.y) / dir.y
	elif dir.y < -0.0001:
		t_y = (min_bound.y - center.y) / dir.y
	
	var t = min(t_x, t_y)
	return center + dir * t

func _draw_arrow(pos: Vector2, dir: Vector2, size: float, color: Color):
	var normal = Vector2(-dir.y, dir.x)
	var tip = pos + dir * (size * 0.5)
	var base_left = pos - dir * (size * 0.5) + normal * (size * 0.45)
	var base_right = pos - dir * (size * 0.5) - normal * (size * 0.45)
	
	var points = PackedVector2Array([tip, base_left, base_right])
	draw_colored_polygon(points, color)
