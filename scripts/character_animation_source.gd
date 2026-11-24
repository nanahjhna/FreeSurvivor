extends RefCounted
## Copy selected animations from a matching skeleton onto the character model.
## Shared libraries avoid loading the large source GLB for every preview or respawn.

static var _libraries: Dictionary = {}

static func apply_to(model: Node3D, player: AnimationPlayer, data: CharacterData) -> void:
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		return
	var target := rigs[0] as Skeleton3D
	var root := player.get_node_or_null(player.root_node)
	if root == null:
		return
	var target_path := root.get_path_to(target)
	var cache_key := "%s|%s|%s|%s" % [data.model_scene.resource_path, data.animation_source_path, target_path, data.animation_source_clips]
	if not _libraries.has(cache_key):
		var built := _build_library(player, target, target_path, data)
		if built == null:
			return
		_libraries[cache_key] = built
	if player.has_animation_library(""):
		player.remove_animation_library("")
	player.add_animation_library("", _libraries[cache_key])

static func _build_library(player: AnimationPlayer, target: Skeleton3D, target_path: NodePath, data: CharacterData) -> AnimationLibrary:
	var packed := load(data.animation_source_path) as PackedScene
	if packed == null:
		push_warning("애니메이션 원본을 불러올 수 없습니다: " + data.animation_source_path)
		return null
	var source := packed.instantiate()
	var players := source.find_children("*", "AnimationPlayer", true, false)
	var rigs := source.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or rigs.is_empty():
		source.free()
		push_warning("애니메이션 원본에 뼈대 또는 AnimationPlayer가 없습니다.")
		return null
	var source_player := players[0] as AnimationPlayer
	var source_rig := rigs[0] as Skeleton3D
	var source_rest := _rest_hip(source_player, source_rig)
	var target_rest := _rest_hip(player, target)
	var height_ratio := target_rest.z / source_rest.z if absf(source_rest.z) > 0.0001 else 1.0
	var library := AnimationLibrary.new()
	for alias in data.animation_source_clips:
		var source_name := str(data.animation_source_clips[alias])
		if not source_player.has_animation(source_name):
			push_warning("애니메이션을 찾을 수 없습니다: " + source_name)
			continue
		var copy := source_player.get_animation(source_name).duplicate(true) as Animation
		for index in range(copy.get_track_count() - 1, -1, -1):
			var path := copy.track_get_path(index)
			if path.get_subname_count() != 1:
				copy.remove_track(index)
				continue
			var bone := str(path.get_subname(0))
			if target.find_bone(bone) < 0:
				copy.remove_track(index)
				continue
			var kind := copy.track_get_type(index)
			if kind == Animation.TYPE_POSITION_3D:
				if bone != "mixamorigHips":
					copy.remove_track(index)
					continue
				for key in range(copy.track_get_key_count(index)):
					var original: Vector3 = copy.track_get_key_value(index, key)
					# The controller owns ground movement. Preserve only vertical hip motion.
					var corrected := target_rest
					corrected.z += (original.z - source_rest.z) * height_ratio
					copy.track_set_key_value(index, key, corrected)
			elif kind != Animation.TYPE_ROTATION_3D:
				copy.remove_track(index)
				continue
			copy.track_set_path(index, NodePath(str(target_path) + ":" + bone))
		library.add_animation(str(alias), copy)
	source.free()
	return library

static func _rest_hip(player: AnimationPlayer, skeleton: Skeleton3D) -> Vector3:
	if player.has_animation("Rest_Pose"):
		var rest := player.get_animation("Rest_Pose")
		for i in range(rest.get_track_count()):
			if rest.track_get_type(i) == Animation.TYPE_POSITION_3D and str(rest.track_get_path(i)).ends_with(":mixamorigHips"):
				return rest.track_get_key_value(i, 0)
	var hips := skeleton.find_bone("mixamorigHips")
	return skeleton.get_bone_rest(hips).origin if hips >= 0 else Vector3.ZERO
