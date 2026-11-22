extends "res://scenes/skills/skill_effect_base.gd"

@export var speed: float = 28.0
@export var lifetime: float = 1.4

var _direction: Vector3 = Vector3.FORWARD
var _damage: float = 0.0
var _remaining_hits: int = 1
var _hit_targets: Array[Node] = []
var _visual_only: bool = false


func cast(caster: Node3D, _target: Node3D, cast_direction: Vector3, damage_multiplier: float, definition: Dictionary) -> void:
	var direction := Vector3(cast_direction.x, 0.0, cast_direction.z).normalized()
	if direction.is_zero_approx():
		direction = -caster.global_basis.z
	_direction = direction.normalized()
	_damage = float(caster.get("base_attack_damage")) * damage_multiplier
	_remaining_hits = maxi(1, int(definition.get("projectile_pierce", 1)))
	_visual_only = bool(definition.get("visual_only", false))
	apply_definition_visual(definition)
	var muzzle := caster.find_child("Muzzle", true, false) as Node3D
	if muzzle != null:
		global_position = muzzle.global_position
	else:
		global_position = caster.global_position + Vector3.UP * 1.0 + _direction * 0.8
	look_at(global_position + _direction, Vector3.UP)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies") or _hit_targets.has(body):
		return
	_hit_targets.append(body)
	if _visual_only:
		queue_free()
		return
	if body.has_method("take_damage"):
		body.take_damage(_damage, true)
	_remaining_hits -= 1
	if _remaining_hits <= 0:
		queue_free()
