extends SkeletonModifier3D
## Reuses the imported gait's leg rotation tracks while a ranged attack owns the torso.

var _gaits: Dictionary = {}
var _tracks: Array[Vector2i] = []
var _animation: Animation
var _time := 0.0
var _rate := 1.0

func configure(skeleton: Skeleton3D, player: AnimationPlayer, leg_roots: PackedStringArray, walk: StringName, run: StringName) -> bool:
	var leg_bones := {}
	for root_name in leg_roots:
		var root := skeleton.find_bone(root_name)
		if root >= 0:
			_collect_bones(skeleton, root, leg_bones)
	if leg_bones.is_empty():
		return false
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null:
		return false
	for clip in [walk, run]:
		if clip.is_empty() or _gaits.has(clip):
			continue
		var animation := player.get_animation(clip)
		var tracks: Array[Vector2i] = []
		for index in range(animation.get_track_count()):
			if animation.track_get_type(index) != Animation.TYPE_ROTATION_3D or not animation.track_is_enabled(index):
				continue
			var path := animation.track_get_path(index)
			if path.get_subname_count() != 1 or not leg_bones.has(path.get_subname(0)):
				continue
			if animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) == skeleton:
				tracks.append(Vector2i(leg_bones[path.get_subname(0)], index))
		if not tracks.is_empty():
			_gaits[clip] = [animation, tracks]
	name = "MovingAttackLegs"
	active = false
	influence = 0.0
	return not _gaits.is_empty()

func _collect_bones(skeleton: Skeleton3D, bone: int, result: Dictionary) -> void:
	result[skeleton.get_bone_name(bone)] = bone
	for child in skeleton.get_bone_children(bone):
		_collect_bones(skeleton, child, result)

func sync_phase(clip: StringName, time: float) -> void:
	if _gaits.has(clip):
		_select_gait(clip)
		_time = time

func gait_phase() -> float:
	return _time / _animation.length if _animation != null else 0.0

func update_motion(delta: float, clip: StringName, rate: float, moving_attack: bool) -> void:
	var use_gait := moving_attack and _gaits.has(clip)
	if use_gait:
		_select_gait(clip)
		_rate = rate
	var weight := move_toward(influence, 1.0 if use_gait else 0.0, delta / (0.12 if use_gait else 0.20))
	if weight != influence:
		influence = weight
	if active != (weight > 0.0):
		active = weight > 0.0

func _select_gait(clip: StringName) -> void:
	var gait: Array = _gaits[clip]
	if _animation == gait[0]:
		return
	var phase := gait_phase()
	_animation = gait[0]
	_tracks = gait[1]
	_time = phase * _animation.length

func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	_time = fposmod(_time + delta * _rate, _animation.length)
	for pair in _tracks:
		skeleton.set_bone_pose_rotation(pair.x, _animation.rotation_track_interpolate(pair.y, _time))
