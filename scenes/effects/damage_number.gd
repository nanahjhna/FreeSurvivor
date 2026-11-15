extends Node3D

@onready var label: Label3D = $Label3D

func setup(amount: float, is_crit: bool = false, is_heal: bool = false):
	if label == null:
		label = $Label3D
	
	if is_heal:
		label.text = "+" + str(int(amount))
		label.modulate = Color(0.2, 1.0, 0.3)
	elif is_crit:
		label.text = str(int(amount)) + "!"
		label.modulate = Color(1.0, 0.2, 0.1)
		scale = Vector3.ONE * 1.3
	else:
		label.text = str(int(amount))
		label.modulate = Color(1.0, 0.9, 0.2)
	
	var tween = create_tween()
	var target_pos = position + Vector3(randf_range(-0.5, 0.5), 1.8, randf_range(-0.5, 0.5))
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
