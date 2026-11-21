extends "res://scenes/monsters/base_monster.gd"

var model_animation_player: AnimationPlayer
var model_clips: Dictionary = {}
var active_action_clip: String = ""


func _ready():
	monster_id = "infected"
	max_hp = 35.0
	move_speed = 3.2
	attack_damage = 7.0
	attack_range = 1.6
	attack_interval = 1.0
	xp_value = 1
	death_visual_duration = 1.0
	super._ready()
	_setup_model_animations()


func _physics_process(delta: float):
	super._physics_process(delta)
	if is_dead or model_animation_player == null:
		return
	var moving := Vector2(velocity.x, velocity.z).length_squared() > 0.1
	_play_model_animation("Walk" if moving else "Idle")


func perform_attack():
	super.perform_attack()
	_play_model_animation("Attack", true)


func take_damage(amount: float, is_crit: bool = false):
	super.take_damage(amount, is_crit)
	if not is_dead:
		_play_model_animation("Hit", true)


func die():
	if is_dead:
		return
	super.die()
	_play_model_animation("Death", true)


func _setup_model_animations():
	var model := get_node_or_null("VisualRoot/Model") as Node3D
	if model == null:
		return
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	model_animation_player = players[0] as AnimationPlayer
	for animation_name in model_animation_player.get_animation_list():
		var clip_name := str(animation_name)
		var clip_key := clip_name.get_slice("/", 1) if clip_name.contains("/") else clip_name
		model_clips[clip_key] = clip_name
	for clip_key in ["Idle", "Walk"]:
		if model_clips.has(clip_key):
			var clip := model_animation_player.get_animation(str(model_clips[clip_key]))
			if clip != null:
				clip.loop_mode = Animation.LOOP_LINEAR
	model_animation_player.animation_finished.connect(_on_model_animation_finished)
	_play_model_animation("Idle")


func _on_model_animation_finished(animation_name: StringName):
	if str(animation_name) == active_action_clip:
		active_action_clip = ""


func _play_model_animation(clip_key: String, action: bool = false):
	if model_animation_player == null or not model_clips.has(clip_key):
		return
	var clip_name := str(model_clips[clip_key])
	if action:
		active_action_clip = clip_name
		model_animation_player.play(clip_name, 0.12)
		return
	if not active_action_clip.is_empty() and model_animation_player.is_playing():
		return
	if str(model_animation_player.current_animation) != clip_name or not model_animation_player.is_playing():
		model_animation_player.play(clip_name, 0.16)
