extends Area3D
## The gate no longer teleports the player automatically.
## It is a clickable / interactable target on collision layer 32 so the
## village interaction system can open the battle preparation screen.

signal battle_requested

var is_entered: bool = false

@onready var sign_label: Label3D = $SignPost/SignLabel
@onready var glow_mesh: MeshInstance3D = $PortalGate/GlowMesh

func _ready():
	collision_layer = 32
	collision_mask = 0
	monitoring = false
	monitorable = true

func _process(delta: float):
	if glow_mesh:
		glow_mesh.rotate_y(1.5 * delta)
