extends RefCounted
## Copy selected animations from a matching skeleton onto the character model.
## Shared libraries avoid loading the large source GLB for every preview or respawn.

static var _libraries: Dictionary = {}
static var _idle_reference_poses: Dictionary = {}

static func apply_source_clip(model: Node3D, player: AnimationPlayer, source_path: String, source_clip: StringName, target_library_name: StringName = &"npc_source") -> bool:
	if model == null or player == null or source_path.is_empty() or source_clip.is_empty():
		return false
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	var root := player.get_node_or_null(player.root_node)
	if rigs.is_empty() or root == null:
		return false
	var target := rigs[0] as Skeleton3D
	if _find_bone(target, "mixamorigHips") < 0:
		return false
	var cache_key := "%s|%s|%s|%s|%s" % [model.scene_file_path, source_path, str(source_clip), root.get_path_to(target), target_library_name]
	var clip: Animation
	if _libraries.has(cache_key):
		clip = _libraries[cache_key] as Animation
	else:
		var source := get_source_library(source_path)
		if source == null or not source.has_animation(source_clip):
			push_warning("애니메이션을 찾을 수 없습니다: " + str(source_clip))
			return false
		var reference := _get_idle_reference_pose(source_path, source)
		if reference.is_empty():
			return false
		clip = _retarget_idle(source.get_animation(source_clip), target, root.get_path_to(target), reference)
		clip.loop_mode = Animation.LOOP_LINEAR
		if clip.get_track_count() == 0:
			return false
		_libraries[cache_key] = clip
	if player.has_animation_library(target_library_name):
		player.remove_animation_library(target_library_name)
	var library := AnimationLibrary.new()
	library.add_animation("Idle", clip)
	player.add_animation_library(target_library_name, library)
	target.reset_bone_poses()
	player.play(StringName(str(target_library_name) + "/Idle"))
	player.advance(0.0)
	return true

static func _get_idle_reference_pose(path: String, library: AnimationLibrary) -> Dictionary:
	if _idle_reference_poses.has(path):
		return _idle_reference_poses[path]
	if not library.has_animation(&"Rest_Pose"):
		return {}
	var packed := load(path) as PackedScene
	if packed == null:
		return {}
	var model := packed.instantiate()
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	var reference := {}
	if not rigs.is_empty():
		var rig := rigs[0] as Skeleton3D
		var rest := library.get_animation(&"Rest_Pose")
		rig.reset_bone_poses()
		for track in rest.get_track_count():
			var node_path := rest.track_get_path(track)
			if node_path.get_subname_count() != 1 or rest.track_get_key_count(track) == 0:
				continue
			var bone := rig.find_bone(node_path.get_subname(0))
			if bone < 0:
				continue
			match rest.track_get_type(track):
				Animation.TYPE_ROTATION_3D:
					rig.set_bone_pose_rotation(bone, rest.track_get_key_value(track, 0))
				Animation.TYPE_POSITION_3D:
					rig.set_bone_pose_position(bone, rest.track_get_key_value(track, 0))
		rig.force_update_all_bone_transforms()
		for bone in rig.get_bone_count():
			var parent := rig.get_bone_parent(bone)
			var parent_pose := rig.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
			reference[rig.get_bone_name(bone)] = {
				"global_pose": rig.get_bone_global_pose(bone),
				"parent_pose": parent_pose,
				"position": rig.get_bone_pose_position(bone),
			}
	model.free()
	_idle_reference_poses[path] = reference
	return reference

static func _retarget_idle(animation: Animation, target: Skeleton3D, target_path: NodePath, reference: Dictionary) -> Animation:
	var clip := animation.duplicate(true) as Animation
	var hips := _find_bone(target, "mixamorigHips")
	for track in range(clip.get_track_count() - 1, -1, -1):
		var path := clip.track_get_path(track)
		if path.get_subname_count() != 1:
			clip.remove_track(track)
			continue
		var source_name := path.get_subname(0)
		var bone := _find_bone(target, str(source_name))
		if bone < 0 or not reference.has(source_name):
			clip.remove_track(track)
			continue
		var source: Dictionary = reference[source_name]
		var source_pose: Transform3D = source.global_pose
		var source_parent: Transform3D = source.parent_pose
		var target_pose := target.get_bone_global_rest(bone)
		var parent := target.get_bone_parent(bone)
		var target_parent := target.get_bone_global_rest(parent) if parent >= 0 else Transform3D.IDENTITY
		match clip.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				# Convert the animation's parent and bone axes separately.
				var parent_axes := (target_parent.basis.inverse() * source_parent.basis).get_rotation_quaternion()
				var bone_axes := (source_pose.basis.inverse() * target_pose.basis).get_rotation_quaternion()
				for key in clip.track_get_key_count(track):
					var rotation: Quaternion = clip.track_get_key_value(track, key)
					clip.track_set_key_value(track, key, (parent_axes * rotation * bone_axes).normalized())
			Animation.TYPE_POSITION_3D:
				if bone != hips:
					clip.remove_track(track)
					continue
				var source_position: Vector3 = source.position
				var target_position := target.get_bone_rest(bone).origin
				var height_ratio := target_pose.origin.y / maxf(0.001, source_pose.origin.y)
				var vertical_axis := target_parent.basis.inverse() * Vector3.UP
				for key in clip.track_get_key_count(track):
					var position: Vector3 = clip.track_get_key_value(track, key)
					var height := (source_parent.basis * (position - source_position)).y
					clip.track_set_key_value(track, key, target_position + vertical_axis * height * height_ratio)
			_:
				clip.remove_track(track)
				continue
		clip.track_set_path(track, NodePath(str(target_path) + ":" + str(target.get_bone_name(bone))))
	return clip

static func get_source_library(source_path: String) -> AnimationLibrary:
	var packed := load(source_path) as PackedScene
	if packed == null:
		return null
	var state := packed.get_state()
	for index in range(state.get_node_count()):
		if state.get_node_type(index) != &"AnimationPlayer":
			continue
		for property_index in range(state.get_node_property_count(index)):
			if state.get_node_property_name(index, property_index) == &"libraries/":
				return state.get_node_property_value(index, property_index) as AnimationLibrary
	return null

static func play_preview(model: Node3D, player: AnimationPlayer, source: AnimationLibrary, clip_name: StringName) -> bool:
	if not source.has_animation(clip_name):
		return false
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	var root := player.get_node_or_null(player.root_node)
	if rigs.is_empty() or root == null:
		return false
	var target := rigs[0] as Skeleton3D
	if _find_bone(target, "mixamorigHips") < 0:
		return false

	var target_rest := _rest_hip(player, target)
	var source_rest := _rest_hip_from_animation(source.get_animation(&"Rest_Pose") if source.has_animation(&"Rest_Pose") else null, target_rest)
	var copy := _retarget_clip(source.get_animation(clip_name), target, root.get_path_to(target), source_rest, target_rest)
	if copy.get_track_count() == 0:
		return false
	copy.loop_mode = Animation.LOOP_LINEAR
	var preview := AnimationLibrary.new()
	preview.add_animation(clip_name, copy)
	player.stop()
	if player.has_animation_library(&"shop_preview"):
		player.remove_animation_library(&"shop_preview")
	player.add_animation_library(&"shop_preview", preview)
	target.reset_bone_poses()
	player.play(StringName("shop_preview/" + str(clip_name)))
	player.advance(0.0)
	return true

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
	var source := get_source_library(data.animation_source_path)
	if source == null:
		push_warning("애니메이션 원본을 불러올 수 없습니다: " + data.animation_source_path)
		return null
	var target_rest := _rest_hip(player, target)
	var source_rest := _source_rest_hip(data.animation_source_path, source, target_rest)
	var library := AnimationLibrary.new()
	for alias in data.animation_source_clips:
		var source_name := str(data.animation_source_clips[alias])
		if not source.has_animation(source_name):
			push_warning("애니메이션을 찾을 수 없습니다: " + source_name)
			continue
		var copy := _retarget_clip(source.get_animation(source_name), target, target_path, source_rest, target_rest)
		library.add_animation(str(alias), copy)
	return library

static func _source_rest_hip(path: String, source: AnimationLibrary, fallback: Vector3) -> Vector3:
	if source.has_animation(&"Rest_Pose"):
		var rest := _rest_hip_from_animation(source.get_animation(&"Rest_Pose"), Vector3.INF)
		if rest.is_finite():
			return rest
	# Older sources without a Rest_Pose track still use their skeleton rest.
	var packed := load(path) as PackedScene
	var model := packed.instantiate()
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if not rigs.is_empty():
		var rig := rigs[0] as Skeleton3D
		var hips := _find_bone(rig, "mixamorigHips")
		if hips >= 0:
			fallback = rig.get_bone_rest(hips).origin
	model.free()
	return fallback

static func _retarget_clip(animation: Animation, target: Skeleton3D, target_path: NodePath, source_rest: Vector3, target_rest: Vector3) -> Animation:
	var copy := animation.duplicate(true) as Animation
	var height_ratio := target_rest.z / source_rest.z if absf(source_rest.z) > 0.0001 else 1.0
	for index in range(copy.get_track_count() - 1, -1, -1):
		var path := copy.track_get_path(index)
		if path.get_subname_count() != 1:
			copy.remove_track(index)
			continue
		var bone := str(path.get_subname(0))
		var target_bone := _target_bone_name(target, bone)
		if target_bone.is_empty():
			copy.remove_track(index)
			continue
		var kind := copy.track_get_type(index)
		if kind == Animation.TYPE_POSITION_3D:
			if _find_bone(target, bone) != _find_bone(target, "mixamorigHips"):
				copy.remove_track(index)
				continue
			for key in range(copy.track_get_key_count(index)):
				var original: Vector3 = copy.track_get_key_value(index, key)
				# Keep vertical hip motion and let the controller handle ground movement.
				var corrected := target_rest
				corrected.z += (original.z - source_rest.z) * height_ratio
				copy.track_set_key_value(index, key, corrected)
		elif kind != Animation.TYPE_ROTATION_3D:
			copy.remove_track(index)
			continue
		copy.track_set_path(index, NodePath(str(target_path) + ":" + target_bone))
	return copy

static func _rest_hip(player: AnimationPlayer, skeleton: Skeleton3D) -> Vector3:
	var hips := _find_bone(skeleton, "mixamorigHips")
	var fallback := skeleton.get_bone_rest(hips).origin if hips >= 0 else Vector3.ZERO
	return _rest_hip_from_animation(player.get_animation(&"Rest_Pose") if player.has_animation(&"Rest_Pose") else null, fallback)

static func _find_bone(skeleton: Skeleton3D, requested: String) -> int:
	var exact := skeleton.find_bone(requested)
	if exact >= 0:
		return exact
	var normalized := _normalize_bone_name(requested)
	for index in range(skeleton.get_bone_count()):
		if _normalize_bone_name(str(skeleton.get_bone_name(index))) == normalized:
			return index
	return -1

static func _target_bone_name(skeleton: Skeleton3D, source_name: String) -> String:
	var direct := skeleton.find_bone(source_name)
	if direct >= 0:
		return str(skeleton.get_bone_name(direct))
	var normalized := _normalize_bone_name(source_name)
	for index in range(skeleton.get_bone_count()):
		var candidate := str(skeleton.get_bone_name(index))
		if _normalize_bone_name(candidate) == normalized:
			return candidate
	return ""

static func _normalize_bone_name(name: String) -> String:
	return name.replace("_", "").replace(":", "").to_lower()

static func _rest_hip_from_animation(rest: Animation, fallback: Vector3) -> Vector3:
	if rest != null:
		for i in range(rest.get_track_count()):
			if rest.track_get_type(i) == Animation.TYPE_POSITION_3D and str(rest.track_get_path(i)).ends_with(":mixamorigHips"):
				if rest.track_get_key_count(i) > 0:
					return rest.track_get_key_value(i, 0)
	return fallback
