extends Area3D
class_name SkillEffectBase

var damage_source := "other"

func hit_target(body: Node, amount: float, critical: bool) -> void:
	if body is BaseMonster:
		body.take_damage(amount, critical, damage_source)
	elif body.has_method("take_damage"):
		body.call("take_damage", amount, critical)

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


func apply_definition_visual(definition: Dictionary) -> void:
	var color_text := str(definition.get("visual_color", ""))
	if color_text.is_empty():
		return
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	var effect_color := Color.from_string(color_text, Color.WHITE)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(effect_color.r, effect_color.g, effect_color.b, 0.62)
	material.emission_enabled = true
	material.emission = effect_color
	material.emission_energy_multiplier = 2.7
	mesh.material_override = material
