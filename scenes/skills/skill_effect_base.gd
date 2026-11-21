extends Area3D
class_name SkillEffectBase

## All active skill scenes share this cast contract so the manager can create
## them from skill data without knowing each concrete effect class.
func cast(
	_caster: Node3D,
	_target: Node3D,
	_direction: Vector3,
	_damage_multiplier: float,
	_definition: Dictionary
) -> void:
	push_warning("SkillEffectBase.cast() must be implemented by a concrete skill effect.")
