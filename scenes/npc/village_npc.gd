extends CharacterBody3D

@export var npc_name: String = "주민"
@export var npc_role: String = "마을 주민"
@export var is_patrolling: bool = false
@export var patrol_radius: float = 6.0
@export var outfit_color: Color = Color(0.2, 0.5, 0.4)
@export var hair_color: Color = Color(0.3, 0.2, 0.1)

var spawn_pos: Vector3
var target_pos: Vector3
var wait_timer: float = 0.0
var move_speed: float = 2.0
var walk_cycle: float = 0.0

@onready var visual_root: Node3D = $VisualRoot
@onready var arm_l: Node3D = $VisualRoot.get_node_or_null("ArmL")
@onready var arm_r: Node3D = $VisualRoot.get_node_or_null("ArmR")
@onready var leg_l: Node3D = $VisualRoot.get_node_or_null("LegL")
@onready var leg_r: Node3D = $VisualRoot.get_node_or_null("LegR")
@onready var name_label: Label3D = $NameLabel3D
@onready var interaction_bubble: Label3D = $InteractionBubble
var _bubble_time := 0.0
var _interaction_highlighted := false

func _ready():
	add_to_group("npcs")
	collision_layer = 32 # Layer 6: Environment / Static
	collision_mask = 33  # Layer 1: Player, Layer 6: Environment
	spawn_pos = global_position
	target_pos = spawn_pos
	
	if name_label:
		name_label.text = npc_name + "\n[" + npc_role + "]"
	
	# Apply custom color if body mesh exists
	var body = $VisualRoot.get_node_or_null("Body")
	if body and body is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = outfit_color
		body.material_override = mat

func _physics_process(delta: float):
	_bubble_time += delta
	if interaction_bubble:
		interaction_bubble.position.y = 2.82 + sin(_bubble_time * 2.2) * 0.06
		var target_scale := Vector3.ONE * (1.16 if _interaction_highlighted else 1.0)
		interaction_bubble.scale = interaction_bubble.scale.lerp(target_scale, minf(1.0, delta * 8.0))
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	
	if not is_patrolling:
		# Idle breathing
		visual_root.position.y = sin(Time.get_ticks_msec() * 0.003 + spawn_pos.x) * 0.03
		return
	
	# Patrol logic
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		visual_root.position.y = sin(Time.get_ticks_msec() * 0.003 + spawn_pos.x) * 0.03
		_reset_limbs(delta)
	else:
		var to_target = target_pos - global_position
		to_target.y = 0.0
		if to_target.length() < 0.6:
			wait_timer = randf_range(3.0, 6.0)
			_pick_new_patrol_target()
		else:
			var dir = to_target.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			
			var target_angle = atan2(dir.x, dir.z)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, 6.0 * delta)
			
			# Walk animation
			walk_cycle += delta * 7.0
			var swing = sin(walk_cycle) * 0.5
			if arm_l: arm_l.rotation.x = swing
			if arm_r: arm_r.rotation.x = -swing
			if leg_l: leg_l.rotation.x = -swing
			if leg_r: leg_r.rotation.x = swing
			visual_root.position.y = abs(sin(walk_cycle)) * 0.05
	
	move_and_slide()

func set_interaction_highlight(highlighted: bool):
	_interaction_highlighted = highlighted
	if interaction_bubble:
		interaction_bubble.modulate = Color(1.0, 0.86, 0.3, 1.0) if highlighted else Color(0.82, 0.92, 1.0, 0.95)
		interaction_bubble.text = "💬  지금 대화하기!\n[E / 터치]" if highlighted else "💬  대화하기\n[E / 터치]"

func _pick_new_patrol_target():
	var angle = randf() * TAU
	var dist = randf_range(2.0, patrol_radius)
	target_pos = spawn_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

func _reset_limbs(delta: float):
	if arm_l: arm_l.rotation.x = lerp_angle(arm_l.rotation.x, 0.0, 8.0 * delta)
	if arm_r: arm_r.rotation.x = lerp_angle(arm_r.rotation.x, 0.0, 8.0 * delta)
	if leg_l: leg_l.rotation.x = lerp_angle(leg_l.rotation.x, 0.0, 8.0 * delta)
	if leg_r: leg_r.rotation.x = lerp_angle(leg_r.rotation.x, 0.0, 8.0 * delta)
