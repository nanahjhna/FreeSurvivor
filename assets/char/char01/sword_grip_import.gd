@tool
extends EditorScenePostImport
## char01's four fingers are rigidly weighted to the wrist in the source GLB.
## Bake a grip into the imported mesh so the original asset and animation clips stay reusable.

const RIGHT_HAND := &"mixamorigRightHand"
const FINGER_RADIUS := 0.028
const GRIP_CENTER_X := -0.051
const GRADIENT_STEP := 0.0001

func _post_import(scene: Node) -> Object:
	var meshes := scene.find_children("Skinned Mesh 0", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return scene
	var model := meshes[0] as MeshInstance3D
	if model.skin == null or not model.mesh is ArrayMesh:
		return scene

	var skin := model.skin
	for bind in skin.get_bind_count():
		if skin.get_bind_name(bind) == RIGHT_HAND:
			var fitted := _bake_grip(model.mesh, bind, skin.get_bind_pose(bind))
			if fitted != null and fitted.get_surface_count() == model.mesh.get_surface_count():
				model.mesh = fitted
			break
	return scene

func _bake_grip(source: ArrayMesh, hand_bind: int, mesh_to_hand: Transform3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.resource_name = source.resource_name
	result.custom_aabb = source.custom_aabb
	result.lightmap_size_hint = source.lightmap_size_hint
	result.blend_shape_mode = source.blend_shape_mode
	for shape in source.get_blend_shape_count():
		result.add_blend_shape(source.get_blend_shape_name(shape))
	var hand_to_mesh := mesh_to_hand.affine_inverse()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		# char01 stores the V_None morph in normalized mode, as absolute vertices.
		var shapes := source.surface_get_blend_shape_arrays(surface)
		if arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null:
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			_bend_vertices(arrays, bones, weights, hand_bind, mesh_to_hand, hand_to_mesh)
			for shape_arrays in shapes:
				_bend_vertices(shape_arrays, bones, weights, hand_bind, mesh_to_hand, hand_to_mesh)
		var flags := source.surface_get_format(surface) & (
			Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		)
		var lods := _surface_lods(source, surface)
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, shapes, lods, flags)
		result.surface_set_material(surface, source.surface_get_material(surface))
		result.surface_set_name(surface, source.surface_get_name(surface))
	if source.shadow_mesh != null:
		result.shadow_mesh = _bake_grip(source.shadow_mesh, hand_bind, mesh_to_hand)
	return result

func _surface_lods(source: ArrayMesh, surface: int) -> Dictionary:
	var surface_data := RenderingServer.mesh_get_surface(source.get_rid(), surface)
	var lods := {}
	if not surface_data.has("lods") or int(surface_data.index_count) == 0:
		return lods
	var index_data: PackedByteArray = surface_data.index_data
	var uses_16_bit_indices := index_data.size() == int(surface_data.index_count) * 2
	for level in surface_data.lods:
		var packed: PackedByteArray = level.index_data
		if uses_16_bit_indices:
			var indices := PackedInt32Array()
			for offset in range(0, packed.size(), 2):
				indices.append(packed.decode_u16(offset))
			lods[level.edge_length] = indices
		else:
			lods[level.edge_length] = packed.to_int32_array()
	return lods

func _bend_vertices(arrays: Array, bones: PackedInt32Array, weights: PackedFloat32Array, hand_bind: int, mesh_to_hand: Transform3D, hand_to_mesh: Transform3D) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var stride := roundi(float(bones.size()) / float(vertices.size()))
	for index in vertices.size():
		var influence := index * stride
		if bones[influence] != hand_bind or weights[influence] < 0.999:
			continue
		var point := mesh_to_hand * vertices[index]
		var curled := _curl(point)
		if curled == point:
			continue
		vertices[index] = hand_to_mesh * curled
		if normals.is_empty():
			continue
		var derivative := Basis(
			(_curl(point + Vector3.RIGHT * GRADIENT_STEP) - curled) / GRADIENT_STEP,
			(_curl(point + Vector3.UP * GRADIENT_STEP) - curled) / GRADIENT_STEP,
			(_curl(point + Vector3.BACK * GRADIENT_STEP) - curled) / GRADIENT_STEP,
		)
		var deformation := hand_to_mesh.basis * derivative * mesh_to_hand.basis
		if absf(deformation.determinant()) < 0.0001:
			continue
		normals[index] = (deformation.inverse().transposed() * normals[index]).normalized()
		if not tangents.is_empty():
			var offset := index * 4
			var tangent := Vector3(tangents[offset], tangents[offset + 1], tangents[offset + 2])
			tangent = (deformation * tangent).normalized()
			tangents[offset] = tangent.x
			tangents[offset + 1] = tangent.y
			tangents[offset + 2] = tangent.z
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not normals.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = normals
	if not tangents.is_empty():
		arrays[Mesh.ARRAY_TANGENT] = tangents

func _curl(point: Vector3) -> Vector3:
	# The knuckles start farther back toward the pinky (negative Z).
	var knuckle_y := clampf(point.z * 0.17 + minf(point.z + 0.004, 0.0) * 0.28 + 0.0005, -0.010, 0.008)
	var arc := clampf((point.y - knuckle_y) / FINGER_RADIUS, 0.0, PI * 0.94)
	if arc <= 0.0:
		return point
	var radius := point.x - GRIP_CENTER_X
	return point + Vector3(radius * (cos(arc) - 1.0), radius * sin(arc) - FINGER_RADIUS * arc, 0.0)
