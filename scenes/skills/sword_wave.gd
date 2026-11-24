extends "res://scenes/skills/skill_effect_base.gd"

@export var damage: float = 30.0
@export var speed: float = 18.0
var direction: Vector3 = Vector3.FORWARD
var hit_targets: Array[Node] = []
var lifetime: float = 1.2

func cast(caster: Node3D, _target: Node3D, cast_direction: Vector3, damage_multiplier: float, definition: Dictionary) -> void:
	apply_definition_visual(definition)
	global_position = caster.global_position + Vector3(0.0, 0.8, 0.0) + cast_direction * 0.5
	setup(cast_direction, damage_multiplier)

func setup(dir: Vector3, dmg_mult: float):
	direction = dir.normalized()
	var resolved_damage := float(get_meta("resolved_damage", 0.0))
	damage = resolved_damage if resolved_damage > 0.0 else 30.0 * dmg_mult
	look_at(global_position + direction, Vector3.UP)

func _ready():
	collision_layer = 4 # Layer 3: PlayerAttacks
	collision_mask = 2  # Layer 2: Enemies
	body_entered.connect(_on_body_entered)
	var range_multiplier := maxf(1.0, float(get_meta("range_multiplier", 1.0)))
	scale = Vector3.ONE * range_multiplier
	var effect_range := maxf(0.1, float(get_meta("effect_range", speed * lifetime)))
	lifetime = effect_range / speed

func _physics_process(delta: float):
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node):
	if body.is_in_group("enemies") and not hit_targets.has(body):
		hit_targets.append(body)
		hit_target(body, damage, true)
