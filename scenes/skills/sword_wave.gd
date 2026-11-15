extends Area3D

@export var damage: float = 30.0
@export var speed: float = 18.0
var direction: Vector3 = Vector3.FORWARD
var hit_targets: Array[Node] = []
var lifetime: float = 1.2

func setup(dir: Vector3, dmg_mult: float):
	direction = dir.normalized()
	damage = 30.0 * dmg_mult
	look_at(global_position + direction, Vector3.UP)

func _ready():
	collision_layer = 4 # Layer 3: PlayerAttacks
	collision_mask = 2  # Layer 2: Enemies
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node):
	if body.is_in_group("enemies") and not hit_targets.has(body):
		hit_targets.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage, true)
