extends Area3D

@export var xp_value: int = 1
var player: Node3D = null
var magnet_speed: float = 0.0
var max_magnet_speed: float = 24.0
var is_attracted: bool = false
var bob_offset: float = 0.0
var base_y: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready():
	add_to_group("xp_gems")
	collision_layer = 16 # Layer 5: Pickups
	collision_mask = 1  # Detect Layer 1: Player
	bob_offset = randf() * TAU
	base_y = position.y
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
	# Bobbing and rotating idle animation
	mesh_instance.rotate_y(3.0 * delta)
	
	if not is_attracted:
		# Check distance to player for magnet
		if player == null:
			var p = get_tree().get_first_node_in_group("player")
			if p:
				player = p
		
		if player and is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist <= 5.5:
				is_attracted = true
		else:
			position.y = base_y + sin(Time.get_ticks_msec() * 0.005 + bob_offset) * 0.15
	else:
		if player and is_instance_valid(player):
			var target_pos = player.global_position + Vector3(0, 0.8, 0)
			var dir = (target_pos - global_position).normalized()
			magnet_speed = move_toward(magnet_speed, max_magnet_speed, 35.0 * delta)
			global_position += dir * magnet_speed * delta
			
			if global_position.distance_to(target_pos) < 0.8:
				collect()
		else:
			is_attracted = false

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		collect()

func collect():
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("gain_xp"):
		p.gain_xp(xp_value)
	
	# Quick scale-down pop
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)
