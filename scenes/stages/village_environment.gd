extends Node3D
## Modular village scenery. Coordinates here and in the lobby scene are in metres.

const KIT := "res://assets/map/Medieval Village MegaKit[Standard]/glTF/"
const WALKABLE_AREA := Rect2i(-33, -39, 67, 71)
const CLEARANCE := 0.85
const HOUSE_SCALE := Vector3(1.22, 1.55, 1.16)
const FURNITURE_SCALE := Vector3(1.2, 1.38, 1.2)
const LANTERN_SCALE := Vector3(1.45, 1.65, 1.45)
const GATE_SCALE := Vector3(1.0, 1.35, 1.0)
const SIDE_WALL_HEIGHT := 3.6
const NORTH_WALL_HEIGHT := 4.2
const WALL_THICKNESS := 0.95
const GATE_TOWER_OFFSET := 5.5

var preview_only := false
var destinations: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _batches: Dictionary = {}
var _obstacles: Array[Rect2] = []
var _walk_grid := AStarGrid2D.new()
var _rng := RandomNumberGenerator.new()

func build(north_gate: Vector3, report_progress: Callable = Callable()) -> void:
	_rng.seed = 10405
	_build_paving(north_gate)
	_build_boundary(north_gate.x)
	if report_progress.is_valid():
		await report_progress.call(81.0, "마을 건물 배치 중…")
	_build_houses()
	_build_plaza()
	if report_progress.is_valid():
		await report_progress.call(85.0, "마을 소품 배치 중…")
	_build_street_details()
	_build_gate(north_gate)
	if report_progress.is_valid():
		await report_progress.call(88.0, "마을 지형 표시 중…")
	await _flush_batches(report_progress.is_valid())
	if not preview_only:
		_build_walk_grid()

func _build_paving(north_gate: Vector3) -> void:
	# Short UV repeats keep the stones the same size on avenues and in alleys.
	var north_road_length := -8.0 - north_gate.z
	var north_road_center := -8.0 - north_road_length * 0.5
	_pave(Vector2(north_gate.x, north_road_center), Vector2(8, north_road_length))
	_pave(Vector2(0, 19), Vector2(8, 22))
	_pave(Vector2(0, 0), Vector2(22, 16))
	_pave(Vector2(-15, 0), Vector2(8, 6))
	_pave(Vector2(15, 0), Vector2(8, 6))
	_pave(Vector2(9, 14), Vector2(10, 5), "Floor_Brick")
	_pave(Vector2(-9, 15), Vector2(10, 5), "Floor_Brick")
	_pave(Vector2(-14, 20), Vector2(5, 14), "Floor_Brick", 0.042)
	_pave(Vector2(-12, -15), Vector2(16, 4), "Floor_Brick")
	_pave(Vector2(12, -15), Vector2(16, 4), "Floor_Brick")
	for z in [-7.6, 7.6]:
		_pave(Vector2(-7.5, z), Vector2(7, 0.55), "Floor_RedBrick", 0.055)
		_pave(Vector2(7.5, z), Vector2(7, 0.55), "Floor_RedBrick", 0.055)
	for x in [-3.65, 3.65]:
		_pave(Vector2(north_gate.x + x, north_road_center), Vector2(0.45, north_road_length), "Floor_Brick", 0.055)
		_pave(Vector2(x, 19), Vector2(0.45, 22), "Floor_Brick", 0.055)

func _pave(center: Vector2, size: Vector2, piece: String = "Floor_UnevenBrick", y: float = 0.025) -> void:
	var cols := maxi(1, ceili(size.x / 3.0))
	var rows := maxi(1, ceili(size.y / 3.0))
	var tile := size / Vector2(cols, rows)
	for row in range(rows):
		for col in range(cols):
			var point := center - size * 0.5 + tile * (Vector2(col, row) + Vector2(0.5, 0.5))
			_place(piece, Vector3(point.x, y, point.y), 0, Vector3(tile.x * 0.5, 0.5, tile.y * 0.5), false)

func _build_houses() -> void:
	destinations["forge"] = _house("Forge", Vector3(-18, 0, -3), PI * 0.5, 3, 4, 1, true, 0)
	destinations["shop"] = _house("EquipmentShop", Vector3(18, 0, -3), -PI * 0.5, 3, 4, 2, false, 1)
	destinations["inn"] = _house("Inn", Vector3(18, 0, 14), -PI * 0.5, 4, 4, 2, true, 2)
	_house("WestGabledHouse", Vector3(-19, 0, -16), PI * 0.5, 4, 4, 2, true, 3)
	_house("EastGabledHouse", Vector3(19, 0, -17), -PI * 0.5, 3, 4, 2, true, 0)
	_house("WestCottage", Vector3(-20, 0, 10), PI * 0.5, 3, 4, 1, false, 4)
	_house("GardenHouse", Vector3(-23, 0, 23), PI * 0.5, 3, 4, 2, false, 5)
	_house("SouthCottage", Vector3(21, 0, 24), PI, 3, 4, 1, true, 0)
	_house("NorthWestCottage", Vector3(-18, 0, -29), 0, 3, 4, 1, false, 1)
	_house("NorthEastCottage", Vector3(18, 0, -29), 0, 3, 4, 1, true, 3)
	_shop_sign(destinations["forge"], "대장간", Vector3(0, 2.85, 4.23))
	_shop_sign(destinations["shop"], "스킬 상점", Vector3(0, 2.85, 4.23))
	_shop_sign(destinations["inn"], "여관", Vector3(-1, 3.1, 4.23))

func _house(node_name: String, center: Vector3, yaw: float, columns: int, depth: int, floors: int, stone: bool, style: int) -> StaticBody3D:
	var width := float(columns) * 2.0
	var length := float(depth) * 2.0
	var door_x := -width * 0.5 + float((columns - 1) >> 1) * 2.0 + 1.0
	var base_y := 0.5 if style % 3 == 2 else 0.24
	var roof_y := float(floors) * 3.0 + base_y
	var body := _solid(node_name, center, Vector3(width, roof_y, length) * HOUSE_SCALE, yaw)
	var frame := Transform3D(Basis(Vector3.UP, yaw).scaled_local(HOUSE_SCALE), center)
	_add_shape(body, Vector3(0, base_y * 0.5, 0) * HOUSE_SCALE, Vector3(width + 0.35, base_y, length + 0.35) * HOUSE_SCALE)
	for face in range(4):
		var side := face % 2 != 0
		var wall_width := length if side else width
		var wall_depth := width if side else length
		var count := depth if side else columns
		var face_yaw := float(face) * PI * 0.5
		var wall := frame * Transform3D(Basis(Vector3.UP, face_yaw), Vector3.ZERO)
		for i in range(count):
			var x := -wall_width * 0.5 + float(i) * 2.0 + 1.0
			_at(wall, "Wall_UnevenBrick_Straight", Vector3(x, 0, wall_depth * 0.5 + 0.08), 0, Vector3(1, base_y / 3.0, 1))
			for level in range(floors):
				var pos := Vector3(x, base_y + float(level) * 3.0, wall_depth * 0.5)
				var prefix := "Wall_UnevenBrick_" if stone and level == 0 else "Wall_Plaster_"
				var is_door := face == 0 and level == 0 and is_equal_approx(x, door_x)
				var is_window := i > 0 or face == 0 or level > 0
				if is_door:
					_at(wall, prefix + "Door_Round", pos)
					_at(wall, "DoorFrame_Round_Brick" if stone else "DoorFrame_Round_WoodDark", pos + Vector3(0, 0, 0.045))
					_at(wall, "Door_2_Round" if stone else "Door_4_Round", pos + Vector3(-0.51, 0, -0.04), 0, Vector3(1, 1, 1))
				elif is_window:
					var flat := (i + style + level) % 4 == 2
					_at(wall, prefix + ("Window_Wide_Flat" if flat else "Window_Wide_Round"), pos)
					_at(wall, "Window_Wide_Flat1" if flat else "Window_Wide_Round1", pos + Vector3(0, 0, -0.04))
					if (i + style + level) % 3 == 0 or flat:
						_at(wall, "WindowShutters_Wide_Flat_Open" if flat else "WindowShutters_Wide_Round_Open", pos)
				else:
					_at(wall, prefix + "Straight", pos)
			if face == 0 and floors == 2 and i > 0 and i < count - 1:
				var balcony := Vector3(x, base_y + 3.0, length * 0.5)
				_at(wall, "Floor_WoodDark", balcony + Vector3(0, -0.08, 0.5), 0, Vector3(1, 1, 0.53))
				_at(wall, "Balcony_Simple_Straight", balcony)
				_at(wall, "Prop_Support", balcony + Vector3(-0.75, -2.75, -0.04), 0, Vector3(1, 0.92, 0.55))
			if i == count - 1 and (face == 0 or face == 1):
				var vine := "Prop_Vine1" if face == 0 else "Prop_Vine2"
				_at(wall, vine, Vector3(x + 0.35, base_y + 2.5, wall_depth * 0.5 + 0.16), 0, Vector3(0.82, 0.92, 1), false)
		_at(wall, "Corner_Exterior_Brick" if stone else "Corner_Exterior_Wood",
			Vector3(wall_width * 0.5, base_y, wall_depth * 0.5), 0, Vector3(1, float(floors), 1))
	var roof_name := "Roof_RoundTiles_6x8" if columns == 3 else "Roof_RoundTiles_8x8"
	var gable_name := "Roof_Front_Brick6" if columns == 3 else "Roof_Front_Brick8"
	_at(frame, roof_name, Vector3(0, roof_y - 0.12, 0), 0, Vector3(1.0, 0.79, 1.0))
	for front in [-1.0, 1.0]:
		_at(frame, gable_name, Vector3(0, roof_y - 0.08, front * length * 0.5), 0 if front > 0 else PI, Vector3(1, 0.78, 1))
	_at(frame, "Prop_Chimney" if stone else "Prop_Chimney2", Vector3(width * 0.24, roof_y + 0.9, -length * 0.31), 0, Vector3(0.76, 0.9, 0.76))
	if floors == 2:
		_at(frame, "Roof_Dormer_RoundTile", Vector3(width * 0.29, roof_y + 1.28, 1.18), 0, Vector3(0.80, 0.74, 0.85))
	if style % 2 == 0:
		_at(frame, "Roof_Wooden_2x1_Center", Vector3(door_x, base_y + 2.65, length * 0.5), 0, Vector3(1.1, 0.64, 1.02))
	_at(frame, "Stairs_Exterior_Straight", Vector3(door_x, 0, length * 0.5 + 0.74), 0, Vector3(0.93, base_y, 0.74))
	return body

func _shop_sign(building: Node3D, caption: String, position_on_wall: Vector3) -> void:
	var scaled_pos := position_on_wall * HOUSE_SCALE
	_box_mesh(building, scaled_pos, Vector3(1.65, 0.43, 0.12) * HOUSE_SCALE, _kit_material("Floor_WoodDark"))
	var label := Label3D.new()
	label.text = caption
	label.font_size = 28
	label.pixel_size = 0.015
	label.modulate = Color(0.93, 0.87, 0.75)
	label.outline_size = 3
	label.position = scaled_pos + Vector3(0, 0, 0.068 * HOUSE_SCALE.z)
	building.add_child(label)

func _build_gate(center: Vector3) -> void:
	var frame := Transform3D(Basis.from_scale(GATE_SCALE), center)
	for side in [-1.0, 1.0]:
		var tower := center + Vector3(side * GATE_TOWER_OFFSET, 0, 0)
		_solid("GateTower", tower, Vector3(4, 9, 4) * GATE_SCALE)
		for face in range(4):
			var yaw := float(face) * PI * 0.5
			var wall := Transform3D(Basis(Vector3.UP, yaw).scaled_local(GATE_SCALE), tower)
			for x in [-1.0, 1.0]:
				_at(wall, "Wall_UnevenBrick_Straight", Vector3(x, 0, 2))
				_at(wall, "Wall_UnevenBrick_Straight", Vector3(x, 3, 2))
				_at(wall, "Wall_UnevenBrick_Window_Thin_Round", Vector3(x, 6, 2))
				_at(wall, "Window_Thin_Round1", Vector3(x, 6, 1.98))
			_at(wall, "Corner_Exterior_Brick", Vector3(2, 0, 2), 0, Vector3(1, 3, 1))
		_at(frame, "Roof_Tower_RoundTiles", Vector3(side * GATE_TOWER_OFFSET, 8.85, 0), 0, Vector3(1, 0.83, 1))
		_lantern(center + Vector3(side * 3.75, 0, 3.2))
	for z in [-0.58, 0.58]:
		var yaw := 0.0 if z > 0 else PI
		_at(frame, "Wall_Arch", Vector3(0, 0, z), yaw, Vector3(3.65, 1.45, 1))
		for x in [-2.35, 0.0, 2.35]:
			_at(frame, "Wall_UnevenBrick_Straight", Vector3(x, 4.13, z), yaw, Vector3(1.18, 0.45, 1))
	_at(frame, "Roof_RoundTiles_6x4", Vector3(0, 5.45, 0), 0, Vector3(1, 0.53, 0.55))
	_at(frame, "Roof_Front_Brick6", Vector3(0, 5.45, 0.92), 0, Vector3(1, 0.52, 1))
	_at(frame, "Roof_Front_Brick6", Vector3(0, 5.45, -0.92), PI, Vector3(1, 0.52, 1))
	# The portcullis closes the wall opening behind the portal effect.
	var rear_z := float(WALKABLE_AREA.position.y)
	_solid("NorthPortcullis", Vector3(center.x, 0, rear_z), Vector3(7.2, 4.15, 0.4))
	for x in [-2.625, -0.875, 0.875, 2.625]:
		_place("Prop_MetalFence_Simple", Vector3(center.x + x, 0, rear_z), 0, Vector3(0.9, 1.45, 1))
	_pave(Vector2(center.x, center.z + 0.5), Vector2(7, 3), "Floor_Brick", 0.045)

func decorate_portal(portal: Area3D, caption: String, tint: Color) -> void:
	var collision := portal.get_node("CollisionShape3D") as CollisionShape3D
	var shape := collision.shape.duplicate() as BoxShape3D
	shape.size *= GATE_SCALE
	collision.shape = shape
	collision.position *= GATE_SCALE
	var veil := QuadMesh.new()
	veil.size = Vector2(4.35, 3.9 * GATE_SCALE.y)
	var effect := ShaderMaterial.new()
	effect.shader = preload("res://scenes/stages/village_portal.gdshader")
	effect.set_shader_parameter("tint", tint)
	_mesh(portal, veil, Vector3(0, 2 * GATE_SCALE.y, 0), effect, false)
	var label := Label3D.new()
	label.text = caption
	label.font_size = 30
	label.pixel_size = 0.012
	label.modulate = Color(0.94, 0.89, 0.81)
	label.outline_modulate = Color(0.12, 0.08, 0.05)
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.9 * GATE_SCALE.y, 0)
	portal.add_child(label)

func _build_plaza() -> void:
	_bench(Vector3(-8.9, 0, -2.7), PI * 0.5)
	_bench(Vector3(7.8, 0, 5.6), PI)
	_bench(Vector3(-8.9, 0, 3.3), PI * 0.5)

	var board := _solid("NoticeBoard", Vector3(7.5, 0, -4.4), Vector3(2.4, 2.4, 0.48) * FURNITURE_SCALE)
	destinations["quest"] = board
	var sign := _scaled_detail(board, Vector3.ZERO, FURNITURE_SCALE)
	var wood := _kit_material("Floor_WoodDark")
	for x in [-1.0, 1.0]:
		_box_mesh(sign, Vector3(x, 1.12, 0), Vector3(0.14, 2.24, 0.14), wood)
	_box_mesh(sign, Vector3(0, 1.57, 0.02), Vector3(2.17, 1.16, 0.18), wood)
	var paper := _material(Color(0.88, 0.74, 0.51))
	for i in range(3):
		var note := _box_mesh(sign, Vector3(-0.66 + i * 0.65, 1.59, 0.125), Vector3(0.36, 0.61, 0.018), paper)
		note.rotation.z = _rng.randf_range(-0.13, 0.13)
		for row in range(4):
			_box_mesh(note, Vector3(0, 0.15 - row * 0.085, 0.010), Vector3(0.23, 0.019, 0.009), wood)
	_at(Transform3D(Basis.from_scale(FURNITURE_SCALE), board.position),
		"Roof_Wooden_2x1_Center", Vector3(0, 2.14, -0.28), 0, Vector3(1.3, 0.39, 0.75))

func _build_street_details() -> void:
	for p: Vector2 in [Vector2(-9.8, 6.5), Vector2(9.8, 6.5), Vector2(-9.8, -6.5), Vector2(10, -6.5),
		Vector2(4.8, 13), Vector2(-4.8, 13), Vector2(-4.9, -19), Vector2(4.9, -19), Vector2(12, 17)]:
		_lantern(Vector3(p.x, 0, p.y))
	for p: Vector2 in [Vector2(-11.2, -8.5), Vector2(11.2, -8.5), Vector2(-6.8, 10.1), Vector2(7.2, 8.7),
		Vector2(-8, -23), Vector2(8, -23), Vector2(-10.1, 24.7), Vector2(12, 22)]:
		_planter(Vector3(p.x, 0, p.y))
	_supply_corner(Vector3(-15, 0, -8.5), -0.22)
	_supply_corner(Vector3(14.8, 0, 5.1), 0.48)
	_supply_corner(Vector3(14.6, 0, 20.0), -0.4)
	_market_stall(Vector3(-8.3, 0, -11.7), 0.14)
	_market_stall(Vector3(8.5, 0, -11.7), -0.22)
	_wagon(Vector3(-25, 0, -6), 0.5)
	_wagon(Vector3(26, 0, 8), 2.4)
	_wagon(Vector3(-20, 0, 17.1), PI * 0.5)
	for x in [-1.0, 1.0]:
		for z in [-24.0, -22.0, 20.0, 22.0, 24.0, 26.0]:
			_place("Prop_WoodenFence_Single", Vector3(x * 6.0, 0, z), PI * 0.5)
		_solid("StreetFence", Vector3(x * 6.0, 0, -23), Vector3(0.16, 0.8, 4.0))
		_solid("StreetFence", Vector3(x * 6.0, 0, 23), Vector3(0.16, 0.8, 8.0))
		for z in [-12.0, -10.0, 8.3, 10.3]:
			_place("Prop_ExteriorBorder_Straight1", Vector3(x * 11.5, 0, z), PI * 0.5)
	for i in range(42):
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * _rng.randf_range(28.4, 32.2), 0.035, _rng.randf_range(-36.0, 28.0))
		var n := _rng.randf_range(0.6, 1.8)
		_place("Prop_Brick%d" % (i % 4 + 1), p, _rng.randf_range(0, TAU), Vector3.ONE * n)

func _market_stall(pos: Vector3, yaw: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw).scaled_local(FURNITURE_SCALE), pos)
	var stall_body := _solid("MarketStall", pos, Vector3(3.7, 2.3, 1.6) * FURNITURE_SCALE, yaw)
	var stall := _scaled_detail(stall_body, Vector3.ZERO, FURNITURE_SCALE)
	var wood := _kit_material("Floor_WoodDark")
	var light_wood := _kit_material("Floor_WoodLight")
	for side in [-1.0, 1.0]:
		_box_mesh(stall, Vector3(side * 1.68, 1.15, -0.58), Vector3(0.16, 2.3, 0.16), wood)
		_box_mesh(stall, Vector3(side * 1.68, 1.20, 0.66), Vector3(0.14, 2.4, 0.14), wood)
		_at(frame, "Prop_Crate", Vector3(side * 1.06, 0, 0.22), side * 0.1, Vector3.ONE * 0.91)
	_box_mesh(stall, Vector3(0, 0.98, 0.25), Vector3(3.30, 0.14, 1.02), light_wood)
	_box_mesh(stall, Vector3(0, 2.4, 0.62), Vector3(3.62, 0.10, 0.12), wood)
	_at(frame, "Roof_Wooden_2x1_L", Vector3(-0.94, 2.39, -0.73), 0, Vector3(0.94, 0.52, 1.31))
	_at(frame, "Roof_Wooden_2x1_R", Vector3(0.94, 2.39, -0.73), 0, Vector3(0.94, 0.52, 1.31))
	var cloth := _material(Color(0.45, 0.16, 0.10))
	_box_mesh(stall, Vector3(0, 0.90, 0.78), Vector3(1.02, 0.46, 0.028), cloth)

func _build_boundary(gate_x: float) -> void:
	var min_edge := Vector2(WALKABLE_AREA.position)
	var max_edge := Vector2(WALKABLE_AREA.end - Vector2i.ONE)
	var center := (min_edge + max_edge) * 0.5
	var span := max_edge - min_edge
	_edge_run("WestWall", Vector3(min_edge.x, 0, center.y), span.y + WALL_THICKNESS, PI * 0.5, SIDE_WALL_HEIGHT)
	_edge_run("EastWall", Vector3(max_edge.x, 0, center.y), span.y + WALL_THICKNESS, -PI * 0.5, SIDE_WALL_HEIGHT)
	_edge_run("SouthWall", Vector3(center.x, 0, max_edge.y), span.x, PI, 0.8)
	# Each north wall wing ends inside a gate tower, joining it without blocking the arch.
	var west_join := gate_x - GATE_TOWER_OFFSET - 0.75
	var east_join := gate_x + GATE_TOWER_OFFSET + 0.75
	_edge_run("NorthWestWall", Vector3((min_edge.x + west_join) * 0.5, 0, min_edge.y),
		west_join - min_edge.x, 0, NORTH_WALL_HEIGHT)
	_edge_run("NorthEastWall", Vector3((max_edge.x + east_join) * 0.5, 0, min_edge.y),
		max_edge.x - east_join, 0, NORTH_WALL_HEIGHT)

func _edge_run(node_name: String, point: Vector3, span: float, yaw: float, height: float) -> void:
	_solid(node_name, point, Vector3(span, height, WALL_THICKNESS), yaw)
	var frame := Transform3D(Basis(Vector3.UP, yaw), point)
	var pieces := maxi(1, roundi(span / 2.0))
	var width := span / float(pieces)
	var layers := ceili(height / 2.5)
	var course := height / layers
	for i in range(pieces):
		var x := -span * 0.5 + width * (float(i) + 0.5)
		for level in range(layers):
			var y := course * float(level)
			var piece_scale := Vector3(width * 0.5, course / 3.0, 1.6)
			_at(frame, "Wall_UnevenBrick_Straight", Vector3(x, y, 0.40), 0, piece_scale)
			_at(frame, "Wall_UnevenBrick_Straight", Vector3(x, y, -0.40), PI, piece_scale)
		_at(frame, "Floor_Brick", Vector3(x, height + 0.022, 0), 0, Vector3(width * 0.5, 1, 0.57))
		if i % 5 == 2:
			_at(frame, "Prop_Vine9", Vector3(x, height * 0.58, 0.50), 0, Vector3(0.72, minf(height * 0.65, 1.65), 0.23), false)

func _planter(pos: Vector3) -> void:
	_solid("Planter", pos, Vector3(2.1, 0.32, 1.4))
	_place("Prop_ExteriorBorder_Straight2", pos + Vector3(0, 0.075, -0.69), 0, Vector3(1.06, 1.7, 1))
	_place("Prop_ExteriorBorder_Straight1", pos + Vector3(0, 0.075, 0.69), PI, Vector3(1.06, 1.7, 1))
	_box_mesh(self, pos + Vector3(0, 0.17, 0), Vector3(2.04, 0.22, 1.36), _material(Color(0.15, 0.24, 0.09)))
	for x in [-0.5, 0.48]:
		var leaves := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled_local(Vector3(0.62, 0.65, 0.48)), pos + Vector3(x, 0.31, 0.17))
		_queue_mesh("Prop_Vine4", leaves, false)
		var upright := Transform3D(Basis(Vector3.RIGHT, -PI * 0.75).scaled_local(Vector3(0.42, 0.60, 0.54)), pos + Vector3(x, 0.40, 0.11))
		_queue_mesh("Prop_Vine4", upright, false)
		_place("Prop_MetalFence_Simple", pos + Vector3(x, 0.16, -0.67), 0, Vector3(0.48, 0.17, 1.0))

func _wagon(pos: Vector3, yaw: float) -> void:
	_place("Prop_Wagon", pos, yaw, FURNITURE_SCALE)
	var center_offset := Basis(Vector3.UP, yaw) * (Vector3.FORWARD * FURNITURE_SCALE)
	_solid("Wagon", pos + center_offset, Vector3(1.9, 1.55, 3.85) * FURNITURE_SCALE, yaw)

func _supply_corner(pos: Vector3, yaw: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), pos)
	_at(frame, "Prop_Crate", Vector3(-0.62, 0, 0))
	_at(frame, "Prop_Crate", Vector3(0.63, 0, -0.14), 0.18, Vector3.ONE * 0.84)
	_at(frame, "Prop_Crate", Vector3(-0.62, 1.06, 0), -0.15, Vector3.ONE * 0.73)
	_solid("SupplyCrates", pos, Vector3(2.35, 1.15, 1.25), yaw)

func _lantern(pos: Vector3) -> void:
	var lantern := _scaled_detail(self, pos, LANTERN_SCALE)
	var iron := _material(Color(0.19, 0.15, 0.11), 0.65)
	var glass := _material(Color(1, 0.68, 0.29), 0.45)
	glass.emission_enabled = true
	glass.emission = Color(1, 0.54, 0.19)
	glass.emission_energy_multiplier = 0.9
	_place("Prop_Brick4", pos + Vector3(0, 0.12, 0) * LANTERN_SCALE, 0, LANTERN_SCALE * 1.25)
	_round_mesh(lantern, Vector3(0, 1.22, 0), 0.06, 0.09, 2.35, iron)
	_box_mesh(lantern, Vector3(0, 2.53, 0), Vector3(0.34, 0.36, 0.34), glass, false)
	_round_mesh(lantern, Vector3(0, 2.80, 0), 0.07, 0.30, 0.22, iron, 4).rotation.y = PI * 0.25
	_box_mesh(lantern, Vector3(0, 2.31, 0), Vector3(0.42, 0.10, 0.42), iron)

func _bench(pos: Vector3, yaw: float) -> void:
	var body := _solid("Bench", pos, Vector3(2.5, 0.94, 0.78) * FURNITURE_SCALE, yaw)
	var bench := _scaled_detail(body, Vector3.ZERO, FURNITURE_SCALE)
	var wood := _kit_material("Floor_WoodDark")
	_box_mesh(bench, Vector3(0, 0.53, 0), Vector3(2.5, 0.13, 0.73), wood)
	_box_mesh(bench, Vector3(0, 0.93, -0.31), Vector3(2.5, 0.42, 0.13), wood)
	for x in [-0.94, 0.94]:
		_box_mesh(bench, Vector3(x, 0.25, 0), Vector3(0.17, 0.5, 0.57), wood)

func _scaled_detail(parent: Node3D, pos: Vector3, size: Vector3) -> Node3D:
	var detail := Node3D.new()
	detail.position = pos
	detail.scale = size
	parent.add_child(detail)
	return detail

func _solid(node_name: String, pos: Vector3, size: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation.y = yaw
	body.collision_layer = 32
	body.collision_mask = 1
	_add_shape(body, Vector3(0, size.y * 0.5, 0), size)
	add_child(body, true)
	if preview_only:
		return body
	var footprint := body.transform * AABB(-size * 0.5, size) # only X/Z are used for routing
	_obstacles.append(Rect2(Vector2(footprint.position.x, footprint.position.z), Vector2(footprint.size.x, footprint.size.z)))
	return body

func _add_shape(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	if preview_only:
		return
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = pos
	body.add_child(collider)

func _build_walk_grid() -> void:
	_walk_grid.region = WALKABLE_AREA
	_walk_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_walk_grid.update()
	for obstacle in _obstacles:
		var padded := obstacle.grow(CLEARANCE)
		for z in range(ceili(padded.position.y), floori(padded.end.y) + 1):
			for x in range(ceili(padded.position.x), floori(padded.end.x) + 1):
				if _walk_grid.is_in_bounds(x, z):
					_walk_grid.set_point_solid(Vector2i(x, z))

func walking_path(from: Vector3, to: Vector3, occupied: PackedVector2Array = PackedVector2Array()) -> Array[Vector3]:
	# NPCs move independently of static scenery. Mark their current cells only
	# while building this route, so future routes still use the same base grid.
	var temporary_blocks: Array[Vector2i] = []
	for point in occupied:
		for z in range(ceili(point.y - 0.9), floori(point.y + 0.9) + 1):
			for x in range(ceili(point.x - 0.9), floori(point.x + 0.9) + 1):
				var cell := Vector2i(x, z)
				if WALKABLE_AREA.has_point(cell) and not _walk_grid.is_point_solid(cell):
					_walk_grid.set_point_solid(cell)
					temporary_blocks.append(cell)
	var start := _nearest_open_cell(from)
	var finish := _nearest_open_cell(to)
	var path: Array[Vector3] = []
	if WALKABLE_AREA.has_point(start) and WALKABLE_AREA.has_point(finish):
		for point in _walk_grid.get_point_path(start, finish):
			path.append(Vector3(point.x, from.y, point.y))
	for cell in temporary_blocks:
		_walk_grid.set_point_solid(cell, false)
	return path

func _nearest_open_cell(pos: Vector3) -> Vector2i:
	var cell := Vector2i(roundi(pos.x), roundi(pos.z))
	var best := WALKABLE_AREA.end
	var distance := INF
	for z in range(cell.y - 2, cell.y + 3):
		for x in range(cell.x - 2, cell.x + 3):
			var id := Vector2i(x, z)
			if not WALKABLE_AREA.has_point(id) or _walk_grid.is_point_solid(id):
				continue
			var gap := Vector2(pos.x, pos.z).distance_squared_to(Vector2(id))
			if gap < distance:
				distance = gap
				best = id
	return best

func _material(color: Color, roughness: float = 0.87) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _kit_material(piece: String) -> Material:
	var parts := _mesh_parts(piece)
	if not parts.is_empty():
		var template: Mesh = parts[0][0]
		return template.surface_get_material(0)
	return _material(Color(0.45, 0.38, 0.30))

func _box_mesh(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, shadow: bool = true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, pos, mat, shadow)

func _round_mesh(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float, mat: Material, segments: int = 24) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	return _mesh(parent, cylinder, pos, mat)

func _mesh(parent: Node3D, model: Mesh, pos: Vector3, mat: Material, shadow: bool = true) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = model
	visual.position = pos
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual

func _place(piece: String, pos: Vector3, yaw: float = 0.0, size: Vector3 = Vector3.ONE, shadow: bool = true) -> void:
	_at(Transform3D.IDENTITY, piece, pos, yaw, size, shadow)

func _at(parent: Transform3D, piece: String, pos: Vector3, yaw: float = 0.0, size: Vector3 = Vector3.ONE, shadow: bool = true) -> void:
	var basis := Basis(Vector3.UP, yaw).scaled_local(size)
	_queue_mesh(piece, parent * Transform3D(basis, pos), shadow)

func _mesh_parts(piece: String) -> Array:
	if _mesh_cache.has(piece):
		return _mesh_cache[piece]
	var parts := []
	var packed := load(KIT + piece + ".gltf") as PackedScene
	if packed:
		var template := packed.instantiate() as Node3D
		if template:
			_collect_meshes(template, Transform3D.IDENTITY, parts)
			template.free()
	_mesh_cache[piece] = parts
	return parts

func _collect_meshes(node: Node3D, parent: Transform3D, parts: Array) -> void:
	var transform_from_root := parent * node.transform
	if node is MeshInstance3D and node.mesh:
		parts.append([node.mesh, transform_from_root])
	for child in node.get_children():
		if child is Node3D:
			_collect_meshes(child, transform_from_root, parts)

func _queue_mesh(piece: String, placement: Transform3D, shadow: bool) -> void:
	# Local batches preserve frustum culling while reusing repeated walls, tiles and props.
	var block := Vector2i(floori(placement.origin.x / 16.0), floori(placement.origin.z / 16.0))
	for part in _mesh_parts(piece):
		var model: Mesh = part[0]
		var key := "%s/%s/%s" % [model.get_instance_id(), block, shadow]
		if not _batches.has(key):
			_batches[key] = [model, shadow, []]
		_batches[key][2].append(placement * part[1])

func _flush_batches(spread_over_frames: bool) -> void:
	var frame_start := Time.get_ticks_usec()
	for batch in _batches.values():
		var transforms: Array = batch[2]
		var item: GeometryInstance3D
		if transforms.size() == 1:
			var single := MeshInstance3D.new()
			single.mesh = batch[0]
			single.transform = transforms[0]
			item = single
		else:
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.mesh = batch[0]
			instances.instance_count = transforms.size()
			for i in range(transforms.size()):
				instances.set_instance_transform(i, transforms[i])
			var multi := MultiMeshInstance3D.new()
			multi.multimesh = instances
			item = multi
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if batch[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(item)
		if spread_over_frames and Time.get_ticks_usec() - frame_start >= 8000:
			await get_tree().process_frame
			frame_start = Time.get_ticks_usec()
	_batches.clear()
