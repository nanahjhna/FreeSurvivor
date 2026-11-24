extends "res://scenes/skills/skill_effect_base.gd"

@export var damage: float = 38.0
var direction: Vector3 = Vector3.FORWARD
var hit_targets: Array[Node] = []
var lifetime: float = 0.65

func cast(caster: Node3D, _target: Node3D, cast_direction: Vector3, damage_multiplier: float, definition: Dictionary) -> void:
	apply_definition_visual(definition)
	setup(caster.global_position, cast_direction, damage_multiplier)

func setup(origin: Vector3, dir: Vector3, dmg_mult: float):
	global_position = origin + Vector3(0, 0.8, 0)
	direction = dir.normalized()
	damage = 38.0 * dmg_mult
	look_at(global_position + direction, Vector3.UP)

func _ready():
	collision_layer = 4 # Layer 3: PlayerAttacks
	collision_mask = 2  # Layer 2: Enemies
	body_entered.connect(_on_body_entered)
	
	# Scale expands forward
	scale = Vector3(0.5, 0.5, 0.2)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(2.5, 1.2, 2.8), lifetime * 0.7).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(queue_free)

func _physics_process(_delta: float):
	# Damage any enemies in the overlapping bodies
	for body in get_overlapping_bodies():
		if body.is_in_group("enemies") and not hit_targets.has(body):
			hit_targets.append(body)
			hit_target(body, damage, true)

func _on_body_entered(body: Node):
	if body.is_in_group("enemies") and not hit_targets.has(body):
		hit_targets.append(body)
		hit_target(body, damage, true)
