extends Area3D

@export var xp_value: int = 1
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


func _ready():
	add_to_group("xp_gems")
	_remaining_lifetime = lifetime_seconds
	collision_layer = 16  # Layer 5: Pickups
	collision_mask = 1  # Detect Layer 1: Player
	bob_offset = randf() * TAU
	base_y = position.y
	body_entered.connect(_on_body_entered)


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
		p.gain_xp(xp_value)
	_play_pickup_sound()

	# Quick scale-down pop
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)


func _play_pickup_sound():
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

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples

	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.volume_db = -4.0
	sound.unit_size = 8.0
	sound.global_position = global_position
	get_tree().current_scene.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
