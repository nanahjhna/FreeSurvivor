extends Camera3D

@export var follow_target: Node3D
@export var follow_smoothness: float = 8.0
@export var camera_offset: Vector3 = Vector3(0.0, 12.0, 10.0)
@export var look_ahead_offset: Vector3 = Vector3(0.0, 0.8, -1.0)

func _ready():
	top_level = true
	fov = 38.0
	if follow_target == null:
		follow_target = get_parent() as Node3D
	
	if follow_target:
		global_position = follow_target.global_position + camera_offset
		look_at(follow_target.global_position + look_ahead_offset, Vector3.UP)

func _process(delta: float):
	if follow_target and is_instance_valid(follow_target):
		var target_pos = follow_target.global_position + camera_offset
		global_position = global_position.lerp(target_pos, follow_smoothness * delta)
		look_at(follow_target.global_position + look_ahead_offset, Vector3.UP)
