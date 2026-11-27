extends "res://scenes/skills/skill_effect_base.gd"

const VFX := preload("res://scenes/skills/sword_skill_visual.gd")

@export var damage: float = 30.0
@export var speed: float = 18.0
var direction: Vector3 = Vector3.FORWARD
var _remaining_range := 0.0
var _hit_size := Vector3.ZERO
var _hit_bodies: Array[RID] = []
var _hit_query := PhysicsShapeQueryParameters3D.new()
var _visual_style := ""
var _hit_flashes_remaining := 0
@onready var _hit_shape: BoxShape3D = ($CollisionShape3D.shape as BoxShape3D).duplicate() as BoxShape3D

func cast(caster: Node3D, _target: Node3D, cast_direction: Vector3, damage_multiplier: float, definition: Dictionary) -> void:
	direction = cast_direction.slide(Vector3.UP).normalized()
	if direction.is_zero_approx():
		direction = -caster.global_basis.z.slide(Vector3.UP).normalized()
	global_position = caster.global_position + Vector3.UP * 0.8
	look_at(global_position + direction, Vector3.UP)
	damage = float(get_meta("resolved_damage", damage * damage_multiplier))
	_remaining_range = maxf(0.1, float(get_meta("effect_range", speed * 1.2)))
	var range_multiplier := maxf(1.0, float(get_meta("range_multiplier", 1.0)))
	var width_multiplier := float(definition.get("wave_width_multiplier", 1.0))
	var visual_scale := Vector3(width_multiplier, 1.0, 1.0) * range_multiplier
	_hit_size = _hit_shape.size * visual_scale
	_hit_query.shape = _hit_shape
	_hit_query.collision_mask = collision_mask
	_visual_style = str(definition.get("effect_visual", "legacy"))
	if VFX.COLORS.has(_visual_style):
		$MeshInstance3D.hide()
		var step := int(definition.get("effect_sequence_index", 0))
		VFX.wave(self, _visual_style, step, visual_scale, _remaining_range / maxf(speed, 0.1))
		var world := get_parent_node_3d()
		if world:
			VFX.spark(world, global_position + direction * 0.5, _visual_style, 1.20 if step == 2 else 0.85)
			_hit_flashes_remaining = 2
	else:
		apply_definition_visual(definition)
		$MeshInstance3D.scale = visual_scale

func _physics_process(delta: float):
	if _remaining_range <= 0.0:
		queue_free()
		return

	# Cover the complete distance travelled this tick, including the sword's starting point.
	var travel := minf(speed * delta, _remaining_range)
	var movement := direction * travel
	_hit_shape.size = _hit_size + Vector3(0.0, 0.0, travel)
	_hit_query.transform = Transform3D(global_basis, global_position + movement * 0.5)
	for result in get_world_3d().direct_space_state.intersect_shape(_hit_query, 64):
		var body := result["collider"] as Node
		var body_rid: RID = result["rid"]
		if is_instance_valid(body) and body.is_in_group("enemies") and not _hit_bodies.has(body_rid):
			_hit_bodies.append(body_rid)
			hit_target(body, damage, true)
			if _hit_flashes_remaining > 0 and is_instance_valid(body) and body is Node3D:
				VFX.spark(get_parent_node_3d(), body.global_position + Vector3.UP * 0.85, _visual_style)
				_hit_flashes_remaining -= 1
	_hit_query.exclude = _hit_bodies
	global_position += movement
	_remaining_range -= travel
