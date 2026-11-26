@tool
extends EditorScenePostImport
## Keep the motion catalogue and rest skeleton while reducing baked key data.

func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for library_name in player.get_animation_library_list():
			var library := player.get_animation_library(library_name)
			for clip_name in library.get_animation_list():
				if clip_name == &"Rest_Pose" or clip_name == &"RESET":
					continue
				_optimize_clip(library.get_animation(clip_name))
	return scene


func _optimize_clip(clip: Animation) -> void:
	# All game consumers use only bone rotations and the hips position.
	for index in range(clip.get_track_count() - 1, -1, -1):
		var path := clip.track_get_path(index)
		var kind := clip.track_get_type(index)
		var used := path.get_subname_count() == 1 and (
			kind == Animation.TYPE_ROTATION_3D
			or (kind == Animation.TYPE_POSITION_3D and path.get_subname(0) == &"mixamorigHips")
		)
		if not used:
			clip.remove_track(index)
	clip.optimize(0.008, 0.008, 4)
	# Import samples at 30 FPS. A 60 FPS compression grid preserves their timing.
	clip.compress(8192, 60)
