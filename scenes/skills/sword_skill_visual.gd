class_name SwordSkillVisual
extends Node3D
## Mesh ribbons are cached. Only material uniforms and transforms animate per cast.

const RIBBON_SHADER := preload("res://scenes/skills/sword_ribbon.gdshader")
const SPARK_SHADER := preload("res://scenes/skills/sword_spark.gdshader")
const COLORS := {
	"sword_cut": Color("#39b8ff"),
	"sword_sweep": Color("#ff991c"),
	"sword_impact": Color("#ff701f"),
	"sword_combo": Color("#be61ff"),
}
const SEGMENTS := 30
static var _ribbon_meshes: Dictionary = {}

var _duration := 0.4
var _age := 0.0
var _ribbons: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _stretch := 0.0


static func wave(host: Node3D, style: String, step: int, dimensions: Vector3, duration: float) -> void:
	var effect := _mount(host, Vector3.ZERO, duration)
	effect.scale = dimensions
	var color: Color = COLORS[style]
	if style == "sword_combo" and step == 2:
		color = Color("#ef8dff")
	var key := "%s_%d" % [style, step]
	if not _ribbon_meshes.has(key):
		_ribbon_meshes[key] = _wave_mesh(style, step)
	effect._renderer(_ribbon_meshes[key], color)
	effect._particles(18 if step == 2 else 11, color, Vector3.BACK + Vector3.UP * 0.35, 5.5, 2.5, 0.28)


static func ground(host: Node3D, world_point: Vector3, radius: float) -> void:
	var effect := _mount(host, host.to_local(world_point), 0.68)
	var color: Color = COLORS["sword_impact"]
	if not _ribbon_meshes.has("ring"):
		_ribbon_meshes["ring"] = _ring_mesh()
		_ribbon_meshes["fractures"] = _fracture_mesh()
	var cracks := effect._renderer(_ribbon_meshes["fractures"], color)
	cracks.scale = Vector3(radius, 1.0, radius)
	var leading := effect._renderer(_ribbon_meshes["ring"], Color("#ffc654"))
	leading.position.y = 0.025
	var echo := effect._renderer(_ribbon_meshes["ring"], color)
	echo.position.y = 0.085
	echo.rotation.y = PI
	effect._stretch = radius
	effect._set_ring(1, 0.0, 1.0)
	effect._set_ring(2, 0.0, 0.62)
	var burst := effect._renderer(_cached_spark_mesh(), Color("#ffbd48"))
	burst.position.y = 0.38
	burst.scale = Vector3(2.1, 1.8, 2.1)
	effect._particles(24, Color("#ffb442"), Vector3.UP, 6.4, 5.5, 0.51)
	effect._particles(11, Color("#cc6d37"), Vector3.UP, 4.3, 3.3, 0.61, 0.14)


static func spark(host: Node3D, world_point: Vector3, style: String, strength: float = 1.0) -> void:
	var effect := _mount(host, host.to_local(world_point), 0.30)
	effect.scale = Vector3.ONE * strength
	var tint: Color = COLORS[style]
	var flashes := effect._renderer(_cached_spark_mesh(), tint)
	flashes.rotation.y = 0.45
	effect._particles(7, tint.lightened(0.2), Vector3.UP, 4.0 * strength, 2.2, 0.27)


static func _mount(host: Node3D, offset: Vector3, duration: float) -> SwordSkillVisual:
	var effect := SwordSkillVisual.new()
	effect.name = "SwordSkillVisual"
	effect._duration = maxf(0.10, duration)
	effect.position = offset
	host.add_child(effect)
	return effect


func _renderer(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = RIBBON_SHADER
	material.set_shader_parameter("edge_color", color)
	material.set_shader_parameter("core_color", color.lightened(0.86))
	mesh_instance.material_override = material
	_ribbons.append(mesh_instance)
	_materials.append(material)
	add_child(mesh_instance)
	return mesh_instance


func _particles(count: int, color: Color, heading: Vector3, speed: float, gravity: float, lifetime: float, thickness: float = 0.035) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.93
	particles.amount = count
	particles.lifetime = lifetime
	particles.visibility_aabb = AABB(Vector3(-7, -3, -7), Vector3(14, 10, 14))
	var process := ParticleProcessMaterial.new()
	process.direction = heading
	process.spread = 60.0
	process.initial_velocity_min = speed * 0.42
	process.initial_velocity_max = speed
	process.gravity = Vector3.DOWN * gravity
	process.particle_flag_align_y = true
	process.scale_min = 0.36
	process.scale_max = 1.12
	var fade := GradientTexture1D.new()
	fade.gradient = Gradient.new()
	fade.gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	fade.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 0.83, 0.45, 0.85), Color(1, 0.54, 0.32, 0)])
	process.color_ramp = fade
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2(thickness * 2.6, 0.33)
	var material := ShaderMaterial.new()
	material.shader = SPARK_SHADER
	material.set_shader_parameter("spark_color", color)
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.emitting = true


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
		return
	var phase := _age / _duration
	for material in _materials:
		material.set_shader_parameter("phase", phase)
		material.set_shader_parameter("intensity", 1.0 - smoothstep(0.22, 1.0, phase))
	if _stretch > 0.0:
		var lead := clampf(_age / 0.27, 0.0, 1.0)
		var echo := clampf((_age - 0.055) / 0.31, 0.0, 1.0)
		_set_ring(1, lead, 1.0)
		_set_ring(2, echo, 0.62)
		_materials[3].set_shader_parameter("intensity", 1.0 - smoothstep(0.045, 0.19, _age))


func _set_ring(index: int, progress: float, strength: float) -> void:
	var radius := _stretch * lerpf(0.12, 1.0, ease(progress, 0.6))
	_ribbons[index].scale = Vector3(radius, 1.0, radius)
	_materials[index].set_shader_parameter("intensity", strength * smoothstep(0, 0.075, progress) * (1.0 - smoothstep(0.52, 1.0, progress)))


static func _wave_mesh(style: String, step: int) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sweep := style == "sword_sweep"
	var final_strike := style == "sword_combo" and step == 2
	var lean := 0.15 if sweep else (-0.8 if step == 1 else 0.82)
	var reach := 1.48 if final_strike else 1.32
	var layers: Array[Vector4] = [Vector4(1.0, 0.0, 0.0, 1.0),
		Vector4(0.91, 0.38, -0.19, 0.82), Vector4(0.70, 0.79, 0.20, 0.48)]
	if sweep or final_strike:
		layers.append(Vector4(0.98, 0.94, -0.25, 0.65))
	if final_strike:
		layers.append(Vector4(0.83, 0.51, 0.06, 0.82))
	for layer_index in layers.size():
		var layer := layers[layer_index]
		var tilt := -0.58 if final_strike and layer_index == layers.size() - 1 else lean
		var points := PackedVector3Array()
		var edges := PackedVector3Array()
		for index in range(SEGMENTS + 1):
			var t := float(index) / SEGMENTS
			var side := t * 2.0 - 1.0
			var taper := maxf(0.002, pow(sin(t * PI), 0.88))
			var belly := 1.12 if sweep or final_strike else 0.87
			points.append(Vector3(side * reach * layer.x, side * tilt + layer.z + taper * 0.16,
				-belly * taper + layer.y + side * 0.19))
			var width := (0.46 if sweep or final_strike else 0.37) * taper
			edges.append(Vector3(0, -0.57, 1.0) * width * (1.0 if layer.y == 0.0 else 0.56))
		_ribbon(mesh, points, edges, layer.w)
	return mesh.commit()


static func _ring_mesh() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	var edges := PackedVector3Array()
	for index in range(SEGMENTS * 2 + 1):
		var t := float(index) / (SEGMENTS * 2)
		var radial := Vector3(cos(t * TAU), 0, sin(t * TAU))
		var jagged := 0.02 * sin(t * TAU * 13.0)
		points.append(radial * (0.93 + jagged))
		edges.append(radial * (0.045 + 0.018 * sin(t * TAU * 7.0)))
	_ribbon(mesh, points, edges, 1.0)
	return mesh.commit()


static func _fracture_mesh() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 835926
	for spoke in range(10):
		var angle := float(spoke) * TAU / 10.0 + rng.randf_range(-0.12, 0.12)
		var radial := Vector3(cos(angle), 0, sin(angle))
		var side := radial.cross(Vector3.UP)
		var points := PackedVector3Array([radial * 0.025])
		var length := rng.randf_range(0.68, 0.98)
		for step in range(1, 6):
			points.append(radial * length * (float(step) / 5.0) + side * rng.randf_range(-0.055, 0.055))
		var thickness := rng.randf_range(0.008, 0.017)
		var edges := PackedVector3Array([side * thickness, side * thickness, side * thickness,
			side * thickness * 0.62, side * thickness * 0.36, side * 0.001])
		_ribbon(mesh, points, edges, 0.86)
		var tip := points[2] + radial * rng.randf_range(0.16, 0.27) + side * (0.12 if spoke % 2 == 0 else -0.12)
		var fork := points[2].lerp(tip, 0.56) + side * 0.03
		_ribbon(mesh, PackedVector3Array([points[2], fork, tip]),
			PackedVector3Array([side * thickness * 0.5, side * thickness * 0.30, side * 0.001]), 0.73)
	return mesh.commit()


static func _spark_mesh() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var radial := Vector3(cos(angle), sin(angle), 0)
		var side := radial.cross(Vector3.FORWARD)
		var length := 0.5 + 0.2 * sin(float(index) * 2.1)
		_ribbon(mesh, PackedVector3Array([Vector3.ZERO, radial * (length * 0.26), radial * length]),
			PackedVector3Array([side * 0.07, side * 0.05, side * 0.005]), 1.0)
	return mesh.commit()


static func _cached_spark_mesh() -> Mesh:
	if not _ribbon_meshes.has("spark"):
		_ribbon_meshes["spark"] = _spark_mesh()
	return _ribbon_meshes["spark"]


static func _ribbon(mesh: SurfaceTool, points: PackedVector3Array, edges: PackedVector3Array, opacity: float) -> void:
	for index in range(points.size() - 1):
		var u0 := float(index) / (points.size() - 1)
		var u1 := float(index + 1) / (points.size() - 1)
		var near_left := points[index] - edges[index]
		var near_right := points[index] + edges[index]
		var far_left := points[index + 1] - edges[index + 1]
		var far_right := points[index + 1] + edges[index + 1]
		_vertex(mesh, near_left, Vector2(u0, 0), opacity)
		_vertex(mesh, far_left, Vector2(u1, 0), opacity)
		_vertex(mesh, near_right, Vector2(u0, 1), opacity)
		_vertex(mesh, near_right, Vector2(u0, 1), opacity)
		_vertex(mesh, far_left, Vector2(u1, 0), opacity)
		_vertex(mesh, far_right, Vector2(u1, 1), opacity)


static func _vertex(mesh: SurfaceTool, point: Vector3, uv: Vector2, opacity: float) -> void:
	mesh.set_uv(uv)
	mesh.set_color(Color(1, 1, 1, opacity))
	mesh.add_vertex(point)
