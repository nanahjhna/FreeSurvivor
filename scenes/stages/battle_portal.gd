extends Area3D

var is_entered: bool = false

@onready var sign_label: Label3D = $SignPost/SignLabel
@onready var glow_mesh: MeshInstance3D = $PortalGate/GlowMesh

func _ready():
	collision_layer = 0
	collision_mask = 1 # Detect Player (Layer 1)
	body_entered.connect(_on_body_entered)

func _process(delta: float):
	if glow_mesh:
		glow_mesh.rotate_y(1.5 * delta)

func _on_body_entered(body: Node):
	if is_entered:
		return
	if body.is_in_group("player"):
		is_entered = true
		_start_transition()

func _start_transition():
	# Transition to battle
	GameManager.go_to_battle()
