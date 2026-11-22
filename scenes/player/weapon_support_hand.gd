extends SkeletonModifier3D
## Keeps a supporting palm on a weapon after the body animation is sampled.

var _main_wrist := -1
var _support_wrist := -1
var _forearm := -1
var _upper_arm := -1
var _weapon: Node3D
var _animation: AnimationPlayer
var _grip_in_weapon: Vector3
var _palm_in_rig_units: Vector3
var _wrist_in_weapon: Basis
var _clips: PackedStringArray

func configure(rig: Skeleton3D, main_wrist: int, weapon: Node3D, animation: AnimationPlayer, data: CharacterData, model_units_per_rig_unit: float) -> bool:
	_support_wrist = rig.find_bone(data.weapon_support_bone_name)
	if _support_wrist < 0 or _support_wrist == main_wrist or model_units_per_rig_unit <= 0.00001:
		return false
	_forearm = rig.get_bone_parent(_support_wrist)
	if _forearm < 0:
		return false
	_upper_arm = rig.get_bone_parent(_forearm)
	if _upper_arm < 0:
		return false
	name = "WeaponSupportHand"
	_main_wrist = main_wrist
	_weapon = weapon
	_animation = animation
	_grip_in_weapon = data.weapon_support_grip_position
	_palm_in_rig_units = data.weapon_support_palm_offset / model_units_per_rig_unit
	_wrist_in_weapon = Basis.from_euler(data.weapon_support_rotation_degrees * PI / 180.0)
	_clips = data.weapon_support_clips
	return true

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(_weapon):
		return
	if not _clips.is_empty() and (not is_instance_valid(_animation) or not _clips.has(_animation.current_animation)):
		return
	var rig := get_skeleton()
	# Read the animated holding bone directly. The attachment node itself may update later in the frame.
	var prop_pose := rig.get_bone_global_pose(_main_wrist) * _weapon.transform
	var wrist_basis := prop_pose.basis.orthonormalized() * _wrist_in_weapon
	var target := prop_pose * _grip_in_weapon - wrist_basis * _palm_in_rig_units
	_pose_arm(rig, target, wrist_basis)

func _pose_arm(rig: Skeleton3D, target: Vector3, wrist_basis: Basis) -> void:
	var upper_pose := rig.get_bone_global_pose(_upper_arm)
	var forearm_pose := rig.get_bone_global_pose(_forearm)
	var wrist_pose := rig.get_bone_global_pose(_support_wrist)
	var upper_segment := forearm_pose.origin - upper_pose.origin
	var lower_segment := wrist_pose.origin - forearm_pose.origin
	var upper_length := upper_segment.length()
	var lower_length := lower_segment.length()
	var reach := target - upper_pose.origin
	if minf(minf(upper_length, lower_length), reach.length()) < 0.0001:
		return

	var direction := reach.normalized()
	var bend := upper_segment.slide(direction)
	if bend.length_squared() < 0.000001:
		bend = upper_pose.basis.x.slide(direction)
		if bend.length_squared() < 0.000001:
			bend = upper_pose.basis.y.slide(direction)
	# Keep the length of both bones and choose the elbow on the animated side of the arm.
	var margin := minf(upper_length, lower_length) * 0.005
	var distance := clampf(reach.length(), absf(upper_length - lower_length) + margin, upper_length + lower_length - margin)
	var elbow_along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var elbow_out := sqrt(maxf(0.0, upper_length * upper_length - elbow_along * elbow_along))
	var elbow := upper_pose.origin + direction * elbow_along + bend.normalized() * elbow_out
	var wrist := upper_pose.origin + direction * distance
	var upper_turn := Basis(Quaternion(upper_segment.normalized(), (elbow - upper_pose.origin).normalized()))
	var lower_turn := Basis(Quaternion((upper_turn * lower_segment).normalized(), (wrist - elbow).normalized()))
	rig.set_bone_global_pose(_upper_arm, Transform3D(upper_turn * upper_pose.basis, upper_pose.origin))
	rig.set_bone_global_pose(_forearm, Transform3D(lower_turn * upper_turn * forearm_pose.basis, elbow))
	rig.set_bone_global_pose(_support_wrist, Transform3D(wrist_basis.scaled_local(wrist_pose.basis.get_scale()), wrist))
