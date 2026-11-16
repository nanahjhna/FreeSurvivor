extends Area3D

@export var xp_value: int = 1
@export_enum("경험치", "골드", "치유 물약") var reward_type: String = "경험치"
@export var reward_value: int = 0
@export var gold_reward: int = 0
@export var potion_reward: int = 0
@export_range(0.0, 600.0, 0.5) var lifetime_seconds: float = 0.0
var player: Node3D = null
var magnet_speed: float = 0.0
var max_magnet_speed: float = 24.0
var is_attracted: bool = false
var bob_offset: float = 0.0
var base_y: float = 0.0
var _remaining_lifetime: float = 0.0
var _collected: bool = false
static var _pickup_stream: AudioStreamWAV

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready():
	add_to_group("xp_gems")
	_remaining_lifetime = lifetime_seconds
	collision_layer = 16  # Layer 5: Pickups
	collision_mask = 1  # Detect Layer 1: Player
	bob_offset = randf() * TAU
	base_y = position.y
	body_entered.connect(_on_body_entered)
	if reward_type != "경험치":
		var material := mesh_instance.get_active_material(0).duplicate() as StandardMaterial3D
		mesh_instance.material_override = material
		mesh_instance.mesh = SphereMesh.new()
		if reward_type == "골드":
			material.albedo_color = Color(1.0, 0.72, 0.12)
			material.emission = Color(1.0, 0.54, 0.05)
			material.emission_enabled = true
		else:
			mesh_instance.mesh = CylinderMesh.new()
			material.albedo_color = Color(0.9, 0.15, 0.18)
			material.emission = Color(0.65, 0.04, 0.06)
			material.emission_enabled = true
	elif gold_reward > 0:
		var material := mesh_instance.get_active_material(0).duplicate() as StandardMaterial3D
		material.albedo_color = Color(0.72, 0.9, 0.28)
		material.emission = Color(0.85, 0.8, 0.12)
		mesh_instance.material_override = material


func _physics_process(delta: float):
	if _remaining_lifetime > 0.0:
		_remaining_lifetime -= delta
		if _remaining_lifetime <= 0.0:
			queue_free()
			return
	# Bobbing and rotating idle animation only (no magnet/auto-attract)
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
			if potion_reward > 0:
				GameData.item_counts[1] = int(GameData.item_counts.get(1, 0)) + potion_reward
				GameData.data_updated.emit()
		elif reward_type == "골드":
			GameData.player_gold += int(round(reward_value * (1.0 + GameData.get_survival_bonus("gold"))))
			GameData.currency_changed.emit(GameData.player_gold, GameData.player_gems)
		else:
			GameData.item_counts[1] = int(GameData.item_counts.get(1, 0)) + 1
			GameData.data_updated.emit()
	_play_pickup_sound()

	# Quick scale-down pop
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)


func _play_pickup_sound():
	if _pickup_stream == null:
		var sample_rate := 22050
		var sample_count := int(sample_rate * 0.18)
		var samples := PackedByteArray()
		samples.resize(sample_count * 2)
		for i in range(sample_count):
			var phase := float(i) / sample_rate
			var progress := float(i) / sample_count
			var frequency := lerpf(980.0, 520.0, progress)
			var envelope := sin(PI * progress) * (1.0 - progress) * 0.45
			var sample := int(sin(TAU * frequency * phase) * envelope * 32767.0)
			samples.encode_s16(i * 2, sample)

		_pickup_stream = AudioStreamWAV.new()
		_pickup_stream.format = AudioStreamWAV.FORMAT_16_BITS
		_pickup_stream.mix_rate = sample_rate
		_pickup_stream.stereo = false
		_pickup_stream.data = samples

	var sound := AudioStreamPlayer3D.new()
	sound.stream = _pickup_stream
	sound.volume_db = -4.0
	sound.unit_size = 8.0
	sound.global_position = global_position
	get_tree().current_scene.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
