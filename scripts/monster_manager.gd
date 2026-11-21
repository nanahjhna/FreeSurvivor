extends Node

const MONSTER_DATABASE = preload("res://scripts/monster_database.gd")
@export_range(0.5, 4.0, 0.1) var size_multiplier: float = 1.5


func get_definition(monster_id: String) -> Dictionary:
	return MONSTER_DATABASE.get_definition(monster_id)


func get_registered_ids() -> Array[String]:
	return MONSTER_DATABASE.get_ids()


func spawn_monster(
	monster_id: String,
	parent: Node,
	world_position: Vector3,
	overrides: Dictionary = {}
) -> BaseMonster:
	var definition := get_definition(monster_id)
	if definition.is_empty():
		push_warning("등록되지 않은 몬스터 ID입니다: %s" % monster_id)
		return null
	var scene_path := str(definition.get("scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("몬스터 씬이 등록되지 않았습니다: %s" % monster_id)
		return null
	var monster_scene := load(scene_path) as PackedScene
	if monster_scene == null:
		push_warning("몬스터 씬을 불러오지 못했습니다: %s" % scene_path)
		return null
	var monster := monster_scene.instantiate() as BaseMonster
	if monster == null:
		push_warning("몬스터 씬 루트는 BaseMonster를 상속해야 합니다: %s" % scene_path)
		return null
	parent.add_child(monster)
	monster.global_position = world_position
	monster.monster_id = monster_id
	_apply_definition(monster, definition, overrides)
	return monster


func _apply_definition(monster: BaseMonster, definition: Dictionary, overrides: Dictionary) -> void:
	for pair in [
		["max_hp", "hp"], ["move_speed", "speed"], ["attack_damage", "damage"],
		["attack_range", "range"], ["attack_interval", "interval"], ["xp_value", "xp"]
	]:
		var property_name := str(pair[0])
		var data_key := str(pair[1])
		if overrides.has(property_name):
			monster.set(property_name, overrides[property_name])
		elif definition.has(data_key):
			monster.set(property_name, definition[data_key])
	monster.current_hp = monster.max_hp

	var visual_scale: Variant = overrides.get("visual_scale", definition.get("visual_scale", Vector3.ONE))
	var visual := monster.get_node_or_null("VisualRoot") as Node3D
	if visual and visual_scale is Vector3:
		visual.scale = visual_scale * size_multiplier
	var configured_collision_scale: Variant = overrides.get("collision_scale", definition.get("collision_scale", Vector3.ONE))
	if configured_collision_scale is Vector3:
		var collision_scale: Vector3 = configured_collision_scale * size_multiplier
		var collision := monster.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision and collision.shape is CapsuleShape3D and collision_scale != Vector3.ONE:
			var shape := (collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
			shape.radius *= maxf(collision_scale.x, collision_scale.z)
			shape.height *= collision_scale.y
			collision.shape = shape
			collision.position.y = shape.height * 0.5
