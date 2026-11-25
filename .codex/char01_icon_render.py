import bpy
import math
from mathutils import Vector

MODEL = r"C:\Users\nanah\Documents\FreeSurvivor\assets\char\char01\char01.glb"
OUT = r"C:\Users\nanah\Documents\FreeSurvivor\.codex\char01_reference.png"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=MODEL)

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
armatures = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
for o in meshes + armatures:
    o.select_set(True)

if not meshes:
    raise RuntimeError('char01 model contains no mesh')

mins = Vector((1e9, 1e9, 1e9))
maxs = Vector((-1e9, -1e9, -1e9))
for o in meshes:
    for corner in o.bound_box:
        p = o.matrix_world @ Vector(corner)
        mins.x = min(mins.x, p.x); mins.y = min(mins.y, p.y); mins.z = min(mins.z, p.z)
        maxs.x = max(maxs.x, p.x); maxs.y = max(maxs.y, p.y); maxs.z = max(maxs.z, p.z)
center = (mins + maxs) * 0.5
height = maxs.z - mins.z

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 768
scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = OUT
scene.render.film_transparent = False
scene.world.color = (0.015, 0.035, 0.06)

def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()

bpy.ops.object.camera_add(location=(center.x + height * 1.75, center.y - height * 2.6, center.z + height * 0.8))
cam = bpy.context.object
cam.data.lens = 58
look_at(cam, (center.x, center.y, center.z + height * 0.18))
scene.camera = cam

def add_area(name, loc, energy, color, size):
    bpy.ops.object.light_add(type='AREA', location=loc)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.color = color
    light.data.shape = 'DISK'
    light.data.size = size
    look_at(light, (center.x, center.y, center.z + height * 0.2))

add_area('Key', (center.x + height * 1.3, center.y - height * 1.7, center.z + height * 1.8), 950, (1.0, 0.72, 0.38), height * 0.9)
add_area('Fill', (center.x - height * 1.6, center.y - height * 1.0, center.z + height * 0.9), 700, (0.25, 0.55, 1.0), height * 1.2)
add_area('Rim', (center.x, center.y + height * 1.5, center.z + height * 1.5), 1100, (0.35, 0.9, 0.75), height * 0.8)

scene.view_settings.look = 'AgX - Medium High Contrast'
bpy.ops.wm.save_as_mainfile(filepath=r"C:\Users\nanah\Documents\FreeSurvivor\.codex\char01_reference.blend")
bpy.ops.render.render(write_still=True)
