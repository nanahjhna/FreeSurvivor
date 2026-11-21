extends Camera3D

@export var follow_target: Node3D
@export_range(1.0, 20.0, 0.1) var follow_smoothness: float = 8.0
@export var camera_offset: Vector3 = Vector3(0.0, 12.0, 10.0)
@export var look_ahead_offset: Vector3 = Vector3(0.0, 0.8, -1.0)

# Optional fixed quarter-view mode, kept for compatibility with preview scenes.
@export var quarter_view_enabled: bool = false
@export_range(4.0, 30.0, 0.5) var quarter_distance: float = 16.0
@export_range(20.0, 70.0, 1.0) var quarter_elevation_degrees: float = 45.0
@export_range(-180.0, 180.0, 1.0) var quarter_azimuth_degrees: float = 45.0
@export_range(0.5, 2.0, 0.05) var quarter_look_height: float = 1.2
@export_range(40.0, 80.0, 1.0) var quarter_view_fov: float = 60.0

# Perspective 3D quarter-back view.
@export var back_view_enabled: bool = false
@export_range(3.0, 10.0, 0.1) var back_distance: float = 5.5
@export_range(25.0, 55.0, 0.5) var back_elevation_degrees: float = 40.0
@export_range(-180.0, 180.0, 0.5) var back_yaw_offset_degrees: float = 180.0
@export_range(0.8, 2.2, 0.05) var back_look_height: float = 1.6
@export_range(0.0, 1.0, 0.05) var back_look_ahead: float = 0.3
@export_range(0.0, 2.0, 0.05) var back_view_recenter_delay: float = 0.5
@export_range(0.2, 8.0, 0.1) var back_view_recenter_speed: float = 5.0
@export_range(0.001, 0.02, 0.001) var orbit_sensitivity: float = 0.006
@export_range(0.001, 0.02, 0.001) var orbit_pitch_sensitivity: float = 0.004
@export_range(0.0, 10.0, 0.5) var manual_orbit_hold_seconds: float = 5.0
@export_range(2.0, 8.0, 0.1) var min_back_distance: float = 2.5
@export_range(4.0, 12.0, 0.1) var max_back_distance: float = 8.0
@export_range(50.0, 80.0, 1.0) var back_view_fov: float = 60.0

# Temporary first-person mode, used in both town and battle.
@export var first_person_enabled: bool = false
@export_range(1.2, 2.0, 0.05) var first_person_eye_height: float = 1.6
@export_range(0.0, 0.5, 0.025) var first_person_forward_offset: float = 0.12
@export_range(60.0, 90.0, 1.0) var first_person_fov: float = 72.0

@export_flags_3d_physics var camera_collision_mask: int = 32
@export_range(0.05, 1.0, 0.05) var collision_margin: float = 0.3
@export_range(0.5, 4.0, 0.1) var zoom_step: float = 1.0

@onready var _camera_pivot: Node3D = get_node("../..") as Node3D
@onready var _spring_arm: SpringArm3D = get_parent() as SpringArm3D

var _smoothed_focus: Vector3 = Vector3.ZERO
var _target_quarter_distance: float = 16.0
var _target_back_distance: float = 5.5
var _camera_yaw: float = 0.0
var _back_idle_time: float = 0.0
var _rig_mode: String = ""
var _manual_orbit_timer: float = 0.0
var _orbit_touch_id: int = -1
var _orbit_mouse_active: bool = false


func _ready() -> void:
	if follow_target == null:
		follow_target = get_node_or_null("../../..") as Node3D
	_target_quarter_distance = quarter_distance
	_target_back_distance = back_distance
	_configure_rig()
	if follow_target:
		snap_to_target()


func _configure_rig() -> void:
	_rig_mode = _current_rig_mode()
	if first_person_enabled:
		top_level = false
		_camera_pivot.top_level = true
		transform = Transform3D.IDENTITY
		_spring_arm.collision_mask = camera_collision_mask
		_spring_arm.spring_length = 0.0
		fov = first_person_fov
	elif back_view_enabled:
		top_level = false
		_camera_pivot.top_level = true
		transform = Transform3D.IDENTITY
		# SpringArm3D extends along local +Z; turn it around so the camera sits behind.
		_spring_arm.rotation = Vector3(0.0, PI, 0.0)
		_spring_arm.collision_mask = camera_collision_mask
		_spring_arm.margin = collision_margin
		_spring_arm.spring_length = back_distance
		fov = back_view_fov
	elif quarter_view_enabled:
		top_level = false
		_camera_pivot.top_level = true
		transform = Transform3D.IDENTITY
		_spring_arm.rotation = Vector3(-deg_to_rad(quarter_elevation_degrees), deg_to_rad(quarter_azimuth_degrees), 0.0)
		_spring_arm.collision_mask = camera_collision_mask
		_spring_arm.margin = collision_margin
		_spring_arm.spring_length = quarter_distance
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = quarter_view_fov
	else:
		_camera_pivot.top_level = false
		top_level = true
		_spring_arm.spring_length = 0.0


func _current_rig_mode() -> String:
	if first_person_enabled:
		return "first_person"
	if back_view_enabled:
		return "back_view"
	if quarter_view_enabled:
		return "quarter_view"
	return "legacy"


func snap_to_target() -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	if _rig_mode != _current_rig_mode():
		_configure_rig()
	_smoothed_focus = follow_target.global_position
	_target_quarter_distance = quarter_distance
	_target_back_distance = back_distance
	if first_person_enabled:
		_camera_yaw = _player_yaw()
		_back_idle_time = 0.0
		_camera_pivot.rotation = Vector3(0.0, _camera_yaw, 0.0)
		_camera_pivot.global_position = _first_person_position(_smoothed_focus)
		_spring_arm.spring_length = 0.0
		rotation = Vector3.ZERO
		fov = first_person_fov
	elif back_view_enabled:
		_camera_yaw = _player_yaw() + deg_to_rad(back_yaw_offset_degrees)
		_back_idle_time = 0.0
		_apply_back_rotation()
		_camera_pivot.global_position = _pivot_target_position(_smoothed_focus, back_distance)
		_spring_arm.spring_length = back_distance
	elif quarter_view_enabled:
		_camera_pivot.rotation = Vector3.ZERO
		_camera_pivot.global_position = _smoothed_focus + Vector3.UP * quarter_look_height
		_spring_arm.rotation = Vector3(-deg_to_rad(quarter_elevation_degrees), deg_to_rad(quarter_azimuth_degrees), 0.0)
		_spring_arm.spring_length = quarter_distance
		rotation = Vector3.ZERO
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = quarter_view_fov
	else:
		global_position = _smoothed_focus + _legacy_view_offset()
		look_at(_smoothed_focus + look_ahead_offset, Vector3.UP)


func _player_forward() -> Vector3:
	var visual_root := follow_target.get_node_or_null("VisualRoot") as Node3D
	var forward: Vector3 = visual_root.global_basis.z if visual_root else follow_target.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return Vector3.FORWARD
	return forward.normalized()


func _player_yaw() -> float:
	var forward: Vector3 = _player_forward()
	return atan2(forward.x, forward.z)


func _pivot_target_position(focus: Vector3, arm_distance: float) -> Vector3:
	var elevation: float = deg_to_rad(back_elevation_degrees)
	var camera_height: float = back_look_height + arm_distance * tan(elevation)
	return focus + Vector3.UP * camera_height + _player_forward() * back_look_ahead


func _first_person_position(focus: Vector3) -> Vector3:
	var camera_forward := Vector3(sin(_camera_yaw), 0.0, cos(_camera_yaw))
	return focus + Vector3.UP * first_person_eye_height + camera_forward * first_person_forward_offset


func _apply_back_rotation() -> void:
	var pitch: float = deg_to_rad(back_elevation_degrees)
	# Keep the arm horizontal behind the player and aim the lens down toward the target.
	_camera_pivot.rotation = Vector3(0.0, _camera_yaw, 0.0)
	_spring_arm.rotation = Vector3(0.0, PI, 0.0)
	rotation = Vector3(-pitch, 0.0, 0.0)


func _legacy_view_offset() -> Vector3:
	return camera_offset


func _physics_process(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	if _rig_mode != _current_rig_mode():
		_configure_rig()
	var position_weight: float = 1.0 - exp(-follow_smoothness * delta)
	_smoothed_focus = _smoothed_focus.lerp(follow_target.global_position, position_weight)
	if first_person_enabled:
		_update_back_yaw(delta, 0.0)
		_camera_pivot.rotation = Vector3(0.0, _camera_yaw, 0.0)
		_camera_pivot.global_position = _camera_pivot.global_position.lerp(
			_first_person_position(_smoothed_focus), position_weight
		)
		_spring_arm.spring_length = 0.0
		rotation = Vector3.ZERO
		fov = first_person_fov
		return
	if back_view_enabled:
		_update_back_yaw(delta, back_yaw_offset_degrees)
		_apply_back_rotation()
		_target_back_distance = clampf(_target_back_distance, min_back_distance, max_back_distance)
		_spring_arm.spring_length = lerpf(
			_spring_arm.spring_length, _target_back_distance, 1.0 - exp(-6.0 * delta)
		)
		back_distance = _spring_arm.spring_length
		_camera_pivot.global_position = _camera_pivot.global_position.lerp(
			_pivot_target_position(_smoothed_focus, back_distance), position_weight
		)
		fov = back_view_fov
		return
	if quarter_view_enabled:
		quarter_distance = lerpf(quarter_distance, _target_quarter_distance, 1.0 - exp(-6.0 * delta))
		# Lock the camera to world axes: only its position follows the player.
		_camera_pivot.rotation = Vector3.ZERO
		_spring_arm.rotation = Vector3(-deg_to_rad(quarter_elevation_degrees), deg_to_rad(quarter_azimuth_degrees), 0.0)
		_spring_arm.spring_length = quarter_distance
		_camera_pivot.global_position = _camera_pivot.global_position.lerp(
			_smoothed_focus + Vector3.UP * quarter_look_height, position_weight
		)
		rotation = Vector3.ZERO
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = quarter_view_fov
		return
	var desired_position: Vector3 = _smoothed_focus + _legacy_view_offset()
	var aim_position: Vector3 = _smoothed_focus + look_ahead_offset
	global_position = global_position.lerp(desired_position, position_weight)
	look_at(aim_position, Vector3.UP)


func _update_back_yaw(delta: float, yaw_offset_degrees: float) -> void:
	if _manual_orbit_timer > 0.0:
		_manual_orbit_timer = maxf(0.0, _manual_orbit_timer - delta)
		_back_idle_time = 0.0
		return
	var has_move_input := false
	if follow_target.has_method("has_camera_move_input"):
		has_move_input = bool(follow_target.call("has_camera_move_input"))
	if has_move_input:
		_back_idle_time = 0.0
		_rotate_back_yaw(delta, yaw_offset_degrees)
		return
	_back_idle_time += delta
	if _back_idle_time < back_view_recenter_delay:
		return
	_rotate_back_yaw(delta, yaw_offset_degrees)


func _rotate_back_yaw(delta: float, yaw_offset_degrees: float) -> void:
	var desired_yaw: float = _player_yaw() + deg_to_rad(yaw_offset_degrees)
	var yaw_error: float = wrapf(desired_yaw - _camera_yaw, -PI, PI)
	var recenter_weight: float = 1.0 - exp(-back_view_recenter_speed * delta)
	_camera_yaw += yaw_error * recenter_weight


func adjust_zoom(steps: int) -> void:
	if steps == 0:
		return
	if back_view_enabled:
		_target_back_distance = clampf(
			_target_back_distance - float(steps) * zoom_step,
			min_back_distance,
			max_back_distance
		)
	elif quarter_view_enabled:
		_target_quarter_distance = clampf(
			_target_quarter_distance - float(steps) * zoom_step,
			4.0,
			24.0
		)


func reset_zoom() -> void:
	_target_quarter_distance = 16.0
	_target_back_distance = 5.5


func _unhandled_input(event: InputEvent) -> void:
	if first_person_enabled:
		return
	if event is InputEventScreenTouch and back_view_enabled:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var view_size: Vector2 = get_viewport().get_visible_rect().size
			if not get_tree().paused and _orbit_touch_id < 0 and touch.position.x >= view_size.x * 0.45:
				_orbit_touch_id = touch.index
				get_viewport().set_input_as_handled()
		elif touch.index == _orbit_touch_id:
			_orbit_touch_id = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and back_view_enabled:
		var drag := event as InputEventScreenDrag
		if drag.index == _orbit_touch_id:
			_apply_orbit_drag(drag.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if back_view_enabled and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_orbit_mouse_active = mouse_event.pressed
			get_viewport().set_input_as_handled()
		elif (quarter_view_enabled or back_view_enabled) and mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				adjust_zoom(1)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				adjust_zoom(-1)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _orbit_mouse_active:
		_apply_orbit_drag((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()


func _apply_orbit_drag(relative: Vector2) -> void:
	_camera_yaw -= relative.x * orbit_sensitivity
	back_elevation_degrees = clampf(
		back_elevation_degrees + relative.y * orbit_pitch_sensitivity,
		25.0,
		55.0
	)
	_manual_orbit_timer = manual_orbit_hold_seconds
	_back_idle_time = 0.0


