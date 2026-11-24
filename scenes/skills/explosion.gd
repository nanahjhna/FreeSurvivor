extends "res://scenes/skills/skill_effect_base.gd"

@export var damage: float = 65.0
var hit_targets: Array[Node] = []
var lifetime: float = 0.55

func cast(caster: Node3D, _target: Node3D, _direction: Vector3, damage_multiplier: float, definition: Dictionary) -> void:
	apply_definition_visual(definition)
	setup(caster.global_position, damage_multiplier)

func setup(origin: Vector3, dmg_mult: float):
	global_position = origin + Vector3(0, 0.5, 0)
	var resolved_damage := float(get_meta("resolved_damage", 0.0))
	damage = resolved_damage if resolved_damage > 0.0 else 65.0 * dmg_mult

func _ready():
	collision_layer = 4 # Layer 3: PlayerAttacks
	collision_mask = 2  # Layer 2: Enemies
	body_entered.connect(_on_body_entered)
	
	var range_multiplier := maxf(1.0, float(get_meta("range_multiplier", 1.0)))
	var effect_range := maxf(0.1, float(get_meta("effect_range", 8.5)))
	var size_multiplier := effect_range / 8.5
	scale = Vector3(0.1, 0.1, 0.1) * size_multiplier
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * size_multiplier, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _physics_process(_delta: float):
	for body in get_overlapping_bodies():
		if body.is_in_group("enemies") and not hit_targets.has(body):
			hit_targets.append(body)
			hit_target(body, damage, true)

func _on_body_entered(body: Node):
	if body.is_in_group("enemies") and not hit_targets.has(body):
		hit_targets.append(body)
		hit_target(body, damage, true)
