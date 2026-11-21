"""Copy the CC_Base-weighted character onto the fitted Mixamo armature."""

import bpy
import math
import os
from collections import defaultdict
from mathutils import Matrix, Vector


SOURCE_ARMATURE_NAME = "Armature.001"
TARGET_ARMATURE_NAME = "Armature"


def make_bone_map():
	result = {
		"mixamorig:Hips": (("CC_Base_Hip", "head"), ("CC_Base_Pelvis", "tail")),
		"mixamorig:Spine": (("CC_Base_Pelvis", "tail"), ("CC_Base_Waist", "tail")),
		"mixamorig:Spine1": (("CC_Base_Waist", "tail"), ("CC_Base_Spine01", "tail")),
		"mixamorig:Spine2": (("CC_Base_Spine01", "tail"), ("CC_Base_Spine02", "tail")),
		"mixamorig:Neck": (("CC_Base_Spine02", "tail"), ("CC_Base_NeckTwist02", "tail")),
		"mixamorig:Head": (("CC_Base_NeckTwist02", "tail"), ("CC_Base_Head", "tail")),
	}

	for side, prefix in (("Left", "L"), ("Right", "R")):
		clavicle = f"CC_Base_{prefix}_Clavicle"
		upperarm = f"CC_Base_{prefix}_Upperarm"
		forearm = f"CC_Base_{prefix}_Forearm"
		hand = f"CC_Base_{prefix}_Hand"
		result[f"mixamorig:{side}Shoulder"] = ((clavicle, "head"), (clavicle, "tail"))
		result[f"mixamorig:{side}Arm"] = ((clavicle, "tail"), (upperarm, "tail"))
		result[f"mixamorig:{side}ForeArm"] = ((upperarm, "tail"), (forearm, "tail"))
		result[f"mixamorig:{side}Hand"] = ((forearm, "tail"), (hand, "tail"))
		result[f"mixamorig:{side}UpLeg"] = ((f"CC_Base_{prefix}_Thigh", "head"), (f"CC_Base_{prefix}_Thigh", "tail"))
		result[f"mixamorig:{side}Leg"] = ((f"CC_Base_{prefix}_Calf", "head"), (f"CC_Base_{prefix}_Calf", "tail"))
		result[f"mixamorig:{side}Foot"] = ((f"CC_Base_{prefix}_Foot", "head"), (f"CC_Base_{prefix}_Foot", "tail"))
		result[f"mixamorig:{side}ToeBase"] = ((f"CC_Base_{prefix}_ToeBase", "head"), (f"CC_Base_{prefix}_ToeBase", "tail"))
		for finger, source_finger in (("Thumb", "Thumb"), ("Index", "Index"), ("Middle", "Mid"), ("Ring", "Ring"), ("Pinky", "Pinky")):
			for digit in (1, 2, 3):
				result[f"mixamorig:{side}Hand{finger}{digit}"] = (
					(f"CC_Base_{prefix}_{source_finger}{digit}", "head"),
					(f"CC_Base_{prefix}_{source_finger}{digit}", "tail"),
				)
	return result


def weight_target_name(source_name, target_bones):
	name = source_name.removeprefix("CC_Base_")
	if name in ("BoneRoot", "Hip", "Pelvis"):
		return "mixamorig:Hips"
	if name in ("Waist",):
		return "mixamorig:Spine"
	if name == "Spine01":
		return "mixamorig:Spine1"
	if name == "Spine02":
		return "mixamorig:Spine2"
	if name.startswith("Neck"):
		return "mixamorig:Neck"
	if name in ("Head", "FacialBone", "JawRoot", "UpperJaw", "Teeth01", "Teeth02", "Tongue01", "Tongue02", "Tongue03", "L_Eye", "R_Eye"):
		return "mixamorig:Head"

	for prefix, side in (("L_", "Left"), ("R_", "Right")):
		if not name.startswith(prefix):
			continue
		part = name[len(prefix):]
		if part.startswith("Thigh"):
			return f"mixamorig:{side}UpLeg"
		if part.startswith(("Calf", "KneeShare")):
			return f"mixamorig:{side}Leg"
		if part.startswith(("Foot", "Toe", "BigToe", "PinkyToe", "RingToe", "MidToe", "IndexToe")):
			return f"mixamorig:{side}ToeBase" if "Toe" in part else f"mixamorig:{side}Foot"
		if part.startswith("Clavicle"):
			return f"mixamorig:{side}Shoulder"
		if part.startswith(("Upperarm",)):
			return f"mixamorig:{side}Arm"
		if part.startswith(("Forearm", "ElbowShare")):
			return f"mixamorig:{side}ForeArm"
		if part.startswith("Hand"):
			return f"mixamorig:{side}Hand"
		if part.startswith("Thumb"):
			return f"mixamorig:{side}HandThumb" + part.removeprefix("Thumb")
		if part.startswith("Index"):
			return f"mixamorig:{side}HandIndex" + part.removeprefix("Index")
		if part.startswith("Mid"):
			return f"mixamorig:{side}HandMiddle" + part.removeprefix("Mid")
		if part.startswith("Ring"):
			return f"mixamorig:{side}HandRing" + part.removeprefix("Ring")
		if part.startswith("Pinky"):
			return f"mixamorig:{side}HandPinky" + part.removeprefix("Pinky")
		if part.startswith(("RibsTwist", "Breast")):
			return "mixamorig:Spine2"

	return "mixamorig:Spine2" if "Spine" in name else "mixamorig:Head"


def fit_mixamo_bones(source, target):
	bone_map = make_bone_map()
	target_to_source = {
		name: endpoints for name, endpoints in bone_map.items()
		if name in target.data.bones and endpoints[0][0] in source.data.bones and endpoints[1][0] in source.data.bones
	}
	if len(target_to_source) < 50:
		raise RuntimeError(f"Expected about 52 Mixamo bones, mapped only {len(target_to_source)}")

	target_inverse = target.matrix_world.inverted()
	# The imported CC_Base object is rotated 90 degrees for its mesh, but its
	# rest-bone coordinates are already in the same Z-up frame as the character.
	# Reusing the armature object's rotation lays the new skeleton sideways.
	source_alignment = Matrix.Translation(source.matrix_world.translation) @ Matrix.Diagonal(
		(source.scale.x, source.scale.y, source.scale.z, 1.0)
	)
	source_vertical = (source_alignment.to_3x3() @ Vector((0.0, 0.0, 1.0))).normalized()
	bpy.ops.object.select_all(action="DESELECT")
	target.select_set(True)
	bpy.context.view_layer.objects.active = target
	bpy.ops.object.mode_set(mode="EDIT")
	edit_bones = target.data.edit_bones
	for target_name, (head_ref, tail_ref) in target_to_source.items():
		edit_bone = edit_bones.get(target_name)
		head_name, head_end = head_ref
		tail_name, tail_end = tail_ref
		head_bone = source.data.bones[head_name]
		tail_bone = source.data.bones[tail_name]
		head_local = head_bone.head_local if head_end == "head" else head_bone.tail_local
		tail_local = tail_bone.head_local if tail_end == "head" else tail_bone.tail_local
		head_world = source_alignment @ head_local
		tail_world = source_alignment @ tail_local
		if target_name == "mixamorig:Head":
			tail_world = head_world + source_vertical * 0.11
		if (head_world - tail_world).length < 0.015:
			tail_world = head_world + source_vertical * 0.04
		edit_bone.head = target_inverse @ head_world
		edit_bone.tail = target_inverse @ tail_world
		edit_bone.use_connect = False
		# Use the source bone that owns the target segment's tail joint for roll.
		# Using head_bone here gives the Mixamo hand the forearm's local axes;
		# that mismatch twists the wrist when the exported skeleton is evaluated.
		orientation = target_inverse.to_3x3() @ source_alignment.to_3x3() @ tail_bone.matrix_local.to_3x3()
		try:
			edit_bone.align_roll(orientation.col[2])
		except (ValueError, RuntimeError):
			pass
	bpy.ops.object.mode_set(mode="OBJECT")
	return bone_map


def remap_mesh_weights(mesh, source, target, bone_map):
	valid_targets = set(target.data.bones.keys())
	accumulated = defaultdict(lambda: defaultdict(float))
	for vertex in mesh.data.vertices:
		for membership in vertex.groups:
			group = mesh.vertex_groups[membership.group]
			mapped = weight_target_name(group.name, valid_targets)
			if mapped in valid_targets and membership.weight > 0.0:
				accumulated[vertex.index][mapped] += membership.weight

	for group in list(mesh.vertex_groups):
		mesh.vertex_groups.remove(group)

	grouped = defaultdict(lambda: defaultdict(list))
	for vertex_id, weights in accumulated.items():
		total = sum(weights.values())
		if total <= 0.0:
			continue
		for target_name, weight in weights.items():
			normalized = round(weight / total, 4)
			if normalized > 0.0:
				grouped[target_name][normalized].append(vertex_id)

	for target_name, buckets in grouped.items():
		group = mesh.vertex_groups.new(name=target_name)
		for weight, vertex_ids in buckets.items():
			group.add(vertex_ids, weight, "REPLACE")

	for modifier in list(mesh.modifiers):
		if modifier.type == "ARMATURE" and modifier.object == source:
			modifier.object = target
			modifier.name = "Mixamo Armature"
			modifier.use_deform_preserve_volume = True

	world = mesh.matrix_world.copy()
	mesh.parent = target
	mesh.matrix_parent_inverse = target.matrix_world.inverted()
	mesh.matrix_world = world


def main():
	source_path = bpy.data.filepath
	root = os.path.dirname(source_path)
	output_blend = os.path.join(root, "mixamo_born_moto_rigged.blend")
	output_glb = os.path.join(root, "mixamo_born_moto_rigged.glb")
	source = bpy.data.objects.get(SOURCE_ARMATURE_NAME)
	target = bpy.data.objects.get(TARGET_ARMATURE_NAME)
	if source is None or target is None or source.type != "ARMATURE" or target.type != "ARMATURE":
		raise RuntimeError("The source CC_Base or target Mixamo armature is missing")

	meshes = [
		obj for obj in bpy.data.objects
		if obj.type == "MESH" and any(mod.type == "ARMATURE" and mod.object == source for mod in obj.modifiers)
	]
	if not meshes:
		raise RuntimeError("No meshes are currently bound to the CC_Base armature")

	# Start from a separate project file; the user's original remains unchanged.
	bpy.ops.wm.save_as_mainfile(filepath=output_blend)
	bone_map = fit_mixamo_bones(source, target)
	for mesh in meshes:
		remap_mesh_weights(mesh, source, target, bone_map)

	# Keep the old rig in the project for inspection, but remove it from the character view/export.
	source.hide_set(True)
	source.hide_render = True
	target.hide_set(False)
	target.show_in_front = True
	target.display_type = "WIRE"
	target.data.display_type = "OCTAHEDRAL"
	target.show_name = True
	for obj in bpy.data.objects:
		obj.select_set(False)
	for mesh in meshes:
		mesh.select_set(True)
	target.select_set(True)
	bpy.context.view_layer.objects.active = target

	bpy.ops.wm.save_as_mainfile(filepath=output_blend)
	bpy.ops.export_scene.gltf(
		filepath=output_glb,
		export_format="GLB",
		use_selection=True,
		export_apply=False,
		export_animations=True,
	)
	print(f"RIGGED_BLEND={output_blend}")
	print(f"RIGGED_GLB={output_glb}")
	print(f"FITTED_BONES={len(bone_map)} MESHES={len(meshes)}")


if __name__ == "__main__":
	main()
