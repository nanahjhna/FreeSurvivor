extends CanvasLayer

@onready var hp_bar: ProgressBar = $TopLeft/Bars/HPBar
@onready var hp_label: Label = $TopLeft/Bars/HPBar/Label
@onready var exp_bar: ProgressBar = $TopLeft/Bars/EXPBar
@onready var level_label: Label = $TopLeft/PortraitPanel/LevelLabel
@onready var time_label: Label = $TopCenter/TimeLabel
@onready var kill_label: Label = $TopRight/KillContainer/KillLabel

# Skills
@onready var skill_q_cd: ColorRect = $BottomCenter/SkillContainer/SkillQ/CDOverlay
@onready var skill_q_label: Label = $BottomCenter/SkillContainer/SkillQ/CDLabel
@onready var skill_w_cd: ColorRect = $BottomCenter/SkillContainer/SkillW/CDOverlay
@onready var skill_w_label: Label = $BottomCenter/SkillContainer/SkillW/CDLabel
@onready var skill_e_cd: ColorRect = $BottomCenter/SkillContainer/SkillE/CDOverlay
@onready var skill_e_label: Label = $BottomCenter/SkillContainer/SkillE/CDLabel
@onready var skill_r_cd: ColorRect = $BottomCenter/SkillContainer/SkillR/CDOverlay
@onready var skill_r_label: Label = $BottomCenter/SkillContainer/SkillR/CDLabel

# Items
@onready var item1_label: Label = $BottomRight/ItemContainer/Item1/CountLabel
@onready var item2_label: Label = $BottomRight/ItemContainer/Item2/CountLabel
@onready var item3_label: Label = $BottomRight/ItemContainer/Item3/CountLabel

# Offscreen warning overlay
@onready var indicator_overlay: Control = $IndicatorOverlay

var player_node: Node3D = null
var camera_node: Camera3D = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_signals()
	_update_item_counts()

func _connect_signals():
	GameManager.time_updated.connect(_on_time_updated)
	GameManager.kill_count_changed.connect(_on_kill_count_changed)
	
	# Connect to player
	player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		_setup_player(player_node)
	
	# Connect to SkillManager
	var sm = get_tree().root.find_child("SkillManager", true, false)
	if sm and sm.has_signal("skill_cooldown_updated"):
		sm.skill_cooldown_updated.connect(_on_skill_cooldown_updated)

func _setup_player(p: Node3D):
	if p.has_signal("hp_changed"):
		p.hp_changed.connect(_on_hp_changed)
	if p.has_signal("exp_changed"):
		p.exp_changed.connect(_on_exp_changed)
	if p.has_signal("leveled_up"):
		p.leveled_up.connect(_on_leveled_up)

func _process(_delta: float):
	if player_node == null:
		player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			_setup_player(player_node)
	
	if camera_node == null:
		camera_node = get_viewport().get_camera_3d()
	
	_update_item_counts()
	indicator_overlay.queue_redraw()

func _on_hp_changed(curr: float, maximum: float):
	hp_bar.max_value = maximum
	hp_bar.value = curr
	hp_label.text = str(int(curr)) + " / " + str(int(maximum))

func _on_exp_changed(curr: int, needed: int):
	exp_bar.max_value = needed
	exp_bar.value = curr

func _on_leveled_up(lvl: int):
	level_label.text = "Lv." + str(lvl)

func _on_time_updated(time_sec: float):
	var mins = int(time_sec) / 60
	var secs = int(time_sec) % 60
	time_label.text = "%02d:%02d" % [mins, secs]

func _on_kill_count_changed(count: int):
	kill_label.text = str(count)

func _update_item_counts():
	if item1_label:
		item1_label.text = "x" + str(GameData.item_counts.get(1, 0))
	if item2_label:
		item2_label.text = "x" + str(GameData.item_counts.get(2, 0))
	if item3_label:
		item3_label.text = "x" + str(GameData.item_counts.get(3, 0))

func _on_skill_cooldown_updated(skill_key: String, current_cd: float, max_cd: float):
	var overlay: ColorRect = null
	var label: Label = null
	match skill_key:
		"q":
			overlay = skill_q_cd
			label = skill_q_label
		"w":
			overlay = skill_w_cd
			label = skill_w_label
		"e":
			overlay = skill_e_cd
			label = skill_e_label
		"r":
			overlay = skill_r_cd
			label = skill_r_label
	
	if overlay and label:
		if current_cd > 0.05:
			overlay.visible = true
			var ratio = current_cd / max_cd
			overlay.anchor_top = 1.0 - ratio
			label.visible = true
			label.text = "%.1f" % current_cd
		else:
			overlay.visible = false
			label.visible = false

func _on_pause_button_pressed():
	GameManager.toggle_pause()
