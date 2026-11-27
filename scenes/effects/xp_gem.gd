extends Area3D
class_name PickupGem

@export var xp_value: int = 1
@export_enum("경험치", "골드") var reward_type: String = "경험치"
@export var reward_value: int = 0
@export var gold_reward: int = 0
@export_range(0.0, 600.0, 0.5) var lifetime_seconds: float = 0.0
var player: Node3D = null
var magnet_speed: float = 0.0
var max_magnet_speed: float = 24.0
var is_attracted: bool = false
var bob_offset: float = 0.0
var base_y: float = 0.0
var _remaining_lifetime: float = 0.0
var _collected: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
var pickup_label: Label3D


func _ready():
	add_to_group("xp_gems")
	_remaining_lifetime = lifetime_seconds
	collision_layer = 16  # Layer 5: Pickups
	collision_mask = 1  # Detect Layer 1: Player
	bob_offset = randf() * TAU
	base_y = position.y
	body_entered.connect(_on_body_entered)
	if reward_type != "경험치":
		# XP is already communicated by the bottom EXP bar.  A Label3D on every
		# gem becomes a stack of overlapping "EXP" labels when a crowd is
		# collected at once, so only the rarer non-XP pickups get floating text.
		pickup_label = Label3D.new()
		pickup_label.position = Vector3(0.0, 0.65, 0.0)
		pickup_label.font_size = 36
		pickup_label.pixel_size = 0.009
		pickup_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pickup_label.no_depth_test = true
		add_child(pickup_label)
		var material := mesh_instance.get_active_material(0).duplicate() as StandardMaterial3D
		mesh_instance.material_override = material
		mesh_instance.mesh = SphereMesh.new()
		if reward_type == "골드":
			pickup_label.text = "GOLD"
			pickup_label.modulate = Color(1.0, 0.82, 0.2)
			material.albedo_color = Color(1.0, 0.72, 0.12)
			material.emission = Color(1.0, 0.54, 0.05)
			material.emission_enabled = true
		else:
			pickup_label.text = "HP 물약"
			pickup_label.modulate = Color(1.0, 0.48, 0.48)
			mesh_instance.mesh = CylinderMesh.new()
			material.albedo_color = Color(0.9, 0.15, 0.18)
			material.emission = Color(0.65, 0.04, 0.06)
			material.emission_enabled = true
	else:
		# XP pickups intentionally have no floating label; the HUD EXP bar is
		# the single readable source of experience feedback.
		pass

func refresh_label():
	if pickup_label and reward_type == "경험치":
		pickup_label.text = "EXP"


func _physics_process(delta: float):
	if _remaining_lifetime > 0.0:
		_remaining_lifetime -= delta
		if _remaining_lifetime <= 0.0:
			queue_free()
			return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	var magnet_range := 0.0
	if reward_type == "경험치":
		magnet_range = GameData.get_survival_bonus("xp_magnet_range")
	if player and magnet_range > 0.0:
		var target_position := player.global_position + Vector3(0.0, 0.55, 0.0)
		if global_position.distance_to(target_position) <= magnet_range:
			is_attracted = true
			magnet_speed = move_toward(magnet_speed, max_magnet_speed, 48.0 * delta)
			global_position = global_position.move_toward(target_position, magnet_speed * delta)
			if global_position.distance_to(target_position) <= 0.7:
				collect()
			return
	is_attracted = false
	magnet_speed = 0.0
	# Idle pickups bob and rotate until a matching magnet card attracts them.
	mesh_instance.rotate_y(3.0 * delta)
	position.y = base_y + sin(Time.get_ticks_msec() * 0.005 + bob_offset) * 0.15


func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		collect()


func collect():
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("gain_xp"):
		if reward_type == "경험치":
			var xp_multiplier := 1.0 + GameData.get_survival_bonus("xp")
			p.gain_xp(maxi(1, int(round(xp_value * xp_multiplier))))
			if gold_reward > 0:
				GameData.player_gold += int(round(gold_reward * (1.0 + GameData.get_survival_bonus("gold"))))
				GameData.currency_changed.emit(GameData.player_gold, GameData.player_gems)
		elif reward_type == "골드":
			GameData.player_gold += int(round(reward_value * (1.0 + GameData.get_survival_bonus("gold"))))
			GameData.currency_changed.emit(GameData.player_gold, GameData.player_gems)
	_play_pickup_sound()

	# Quick scale-down pop
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)


func _play_pickup_sound():
	# Sound is intentionally disabled.  Do not allocate an AudioStreamPlayer3D
	# for every pickup; a dense wave can otherwise create hundreds of short-lived
	# nodes and audio buffers.
	return
