extends CanvasLayer

@onready var hp_bar: ProgressBar = $TopLeft/Bars/HPBar
@onready var hp_label: Label = $TopLeft/Bars/HPBar/Label
@onready var level_label: Label = $TopLeft/PortraitPanel/LevelLabel
@onready var status_label: Label = $BottomCenter/Panel/Margin/StatusLabel

var player_node: Node3D = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_stats()

func _process(_delta: float):
	if player_node == null:
		player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			if player_node.has_signal("hp_changed"):
				player_node.hp_changed.connect(_on_hp_changed)
			if player_node.has_signal("leveled_up"):
				player_node.leveled_up.connect(_on_leveled_up)
			_update_stats()

func _update_stats():
	var max_h = 100.0 + GameData.max_hp_bonus
	var cur_h = GameData.player_current_hp
	hp_bar.max_value = max_h
	hp_bar.value = cur_h
	hp_label.text = str(int(cur_h)) + " / " + str(int(max_h))
	level_label.text = "Lv." + str(GameData.player_level)

func _on_hp_changed(curr: float, maximum: float):
	hp_bar.max_value = maximum
	hp_bar.value = curr
	hp_label.text = str(int(curr)) + " / " + str(int(maximum))

func _on_leveled_up(lvl: int):
	level_label.text = "Lv." + str(lvl)
