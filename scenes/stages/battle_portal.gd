extends Area3D
## Opens battle preparation both on contact and through the village's
## click/touch/E interaction path.

signal battle_requested

var is_entered: bool = false

@onready var sign_label: Label3D = $SignPost/SignLabel
@onready var glow_mesh: MeshInstance3D = $PortalGate/GlowMesh

func _ready():
	collision_layer = 32
	collision_mask = 1
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float):
	if glow_mesh:
		glow_mesh.rotate_y(1.5 * delta)

func _on_body_entered(body: Node3D):
	if is_entered or not body.is_in_group("player"):
		return
	is_entered = true
	battle_requested.emit()

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		is_entered = false
