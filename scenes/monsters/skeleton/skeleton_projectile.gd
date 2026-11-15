extends Area3D

@export var damage: float = 8.0
@export var speed: float = 12.0
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 4.0

func setup(dir: Vector3, dmg: float):
	direction = dir.normalized()
	damage = dmg
	look_at(global_position + direction, Vector3.UP)

func _ready():
	collision_layer = 8 # Layer 4: EnemyAttacks
	collision_mask = 1  # Layer 1: Player
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
