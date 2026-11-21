"""Build a textured, Godot-ready GLB for char05 from its extracted FBX maps."""

import bpy
import os

ROOT = os.path.dirname(__file__)
FBX_PATH = os.path.join(ROOT, "char05.fbx")
TEXTURE_DIR = os.path.join(ROOT, "cgt_extracted")
OUTPUT_BLEND = os.path.join(ROOT, "char05_textured.blend")
OUTPUT_GLB = os.path.join(ROOT, "char05_textured.glb")

MATERIAL_TEXTURES = {
	"Ch44_body1": {
		"Diffuse": "Ch44_1001_Diffuse.png",
		"Emissive": "Ch44_1001_Emissive.png",
		"Glossiness": "Ch44_1001_Glossiness.png",
		"Normal": "Ch44_1001_Normal.png",
		"Specular": "Ch44_1001_Specular.png",
	},
	"Ch44_Body": {
		"Diffuse": "Ch44_1002_Diffuse.png",
		"Emissive": "Ch44_1002_Emissive.png",
		"Glossiness": "Ch44_1002_Glossiness.png",
		"Normal": "Ch44_1002_Normal.png",
		"Specular": "Ch44_1002_Specular.png",
	},
}


def load_image(filename, color_space):
	path = os.path.join(TEXTURE_DIR, filename)
	if not os.path.isfile(path):
		raise FileNotFoundError(path)
	image = bpy.data.images.load(path, check_existing=True)
	image.colorspace_settings.name = color_space
	return image


def connect_map(nodes, links, image, label, y, target_socket):
	texture = nodes.new("ShaderNodeTexImage")
	texture.image = image
	texture.label = label
	texture.location = (-800, y)
	links.new(texture.outputs["Color"], target_socket)
	return texture


def configure_material(material, filenames):
	material.use_nodes = True
	nodes = material.node_tree.nodes
	links = material.node_tree.links
	nodes.clear()
	shader = nodes.new("ShaderNodeBsdfPrincipled")
	shader.location = (0, 0)
	output = nodes.new("ShaderNodeOutputMaterial")
	output.location = (320, 0)
	links.new(shader.outputs["BSDF"], output.inputs["Surface"])

	diffuse = load_image(filenames["Diffuse"], "sRGB")
	diffuse_node = connect_map(nodes, links, diffuse, "Diffuse / Base Color", 360, shader.inputs["Base Color"])
	if "Alpha" in diffuse_node.outputs and "Alpha" in shader.inputs:
		links.new(diffuse_node.outputs["Alpha"], shader.inputs["Alpha"])

	emissive = load_image(filenames["Emissive"], "sRGB")
	emission_socket = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
	connect_map(nodes, links, emissive, "Emissive", 80, emission_socket)
	if shader.inputs.get("Emission Strength"):
		shader.inputs["Emission Strength"].default_value = 1.0

	gloss = load_image(filenames["Glossiness"], "Non-Color")
	gloss_node = nodes.new("ShaderNodeTexImage")
	gloss_node.image = gloss
	gloss_node.label = "Glossiness"
	gloss_node.location = (-800, -180)
	invert = nodes.new("ShaderNodeInvert")
	invert.location = (-520, -180)
	links.new(gloss_node.outputs["Color"], invert.inputs["Color"])
	links.new(invert.outputs["Color"], shader.inputs["Roughness"])

	normal = load_image(filenames["Normal"], "Non-Color")
	normal_node = nodes.new("ShaderNodeTexImage")
	normal_node.image = normal
	normal_node.label = "Normal"
	normal_node.location = (-800, -440)
	normal_map = nodes.new("ShaderNodeNormalMap")
	normal_map.location = (-520, -440)
	links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
	links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])

	specular = load_image(filenames["Specular"], "Non-Color")
	specular_socket = shader.inputs.get("Specular IOR Level") or shader.inputs.get("Specular")
	connect_map(nodes, links, specular, "Specular", -700, specular_socket)


def main():
	if not os.path.isfile(FBX_PATH):
		raise FileNotFoundError(FBX_PATH)
	bpy.ops.import_scene.fbx(filepath=FBX_PATH, use_image_search=False)
	objects = list(bpy.context.selected_objects)
	if not objects:
		raise RuntimeError("FBX imported without objects")

	for material_name, filenames in MATERIAL_TEXTURES.items():
		material = bpy.data.materials.get(material_name)
		if material is None:
			raise RuntimeError(f"Missing FBX material: {material_name}")
		configure_material(material, filenames)

	for obj in bpy.context.selected_objects:
		obj.select_set(False)
	for obj in objects:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = next((obj for obj in objects if obj.type == "ARMATURE"), objects[0])

	bpy.ops.wm.save_as_mainfile(filepath=OUTPUT_BLEND)
	bpy.ops.export_scene.gltf(
		filepath=OUTPUT_GLB,
		export_format="GLB",
		use_selection=True,
		export_animations=True,
		export_apply=False,
	)
	print(f"TEXTURED_BLEND={OUTPUT_BLEND}")
	print(f"TEXTURED_GLB={OUTPUT_GLB}")
	print(f"MATERIALS_LINKED={len(MATERIAL_TEXTURES)}")


if __name__ == "__main__":
	main()
