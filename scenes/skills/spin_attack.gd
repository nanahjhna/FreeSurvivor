extends "res://scenes/skills/skill_effect_base.gd"

const VFX := preload("res://scenes/skills/sword_skill_visual.gd")

@export var damage: float = 26.0
var hit_targets: Array[Node] = []
var duration: float = 0.45
var player_ref: Node3D = null
var _hit_flashes_remaining := 0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var hitbox: CollisionShape3D = $CollisionShape3D

func cast(caster: Node3D, _target: Node3D, _direction: Vector3, damage_multiplier: float, definition: Dictionary) -> void:
	setup(caster, damage_multiplier)
	if str(definition.get("cast_pattern", "")) == "ground_impact":
		player_ref = null
	var world := get_parent_node_3d()
	if str(definition.get("effect_visual", "")) == "sword_impact" and world:
		mesh.hide()
		var radius := (hitbox.shape as CylinderShape3D).radius
		VFX.ground(world, global_position - Vector3.UP * 0.74, radius)
		_hit_flashes_remaining = 3
	else:
		apply_definition_visual(definition)

func setup(player: Node3D, dmg_mult: float):
	player_ref = player
	damage = float(get_meta("resolved_damage", damage * dmg_mult))
	global_position = player.global_position + Vector3(0, 0.8, 0)

func _ready():
	collision_layer = 4 # Layer 3: PlayerAttacks
	collision_mask = 2  # Layer 2: Enemies
	body_entered.connect(_on_body_entered)
	
	var effect_range := maxf(0.1, float(get_meta("effect_range", 4.2)))
	var size_multiplier := effect_range / 4.2
	var shape := hitbox.shape.duplicate() as CylinderShape3D
	shape.radius = effect_range
	hitbox.shape = shape
	mesh.scale = Vector3(0.2 * size_multiplier, 1.0, 0.2 * size_multiplier)
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3(size_multiplier, 1.0, size_multiplier), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)

func _physics_process(delta: float):
	if player_ref and is_instance_valid(player_ref):
		global_position = player_ref.global_position + Vector3(0, 0.8, 0)
	if mesh.visible:
		mesh.rotate_y(22.0 * delta)

func _on_body_entered(body: Node):
	if body.is_in_group("enemies") and not hit_targets.has(body):
		hit_targets.append(body)
		hit_target(body, damage, false)
		if _hit_flashes_remaining > 0 and is_instance_valid(body) and body is Node3D:
			VFX.spark(get_parent_node_3d(), body.global_position + Vector3.UP * 0.75, "sword_impact", 0.9)
			_hit_flashes_remaining -= 1
