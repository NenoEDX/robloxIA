#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Debug aislado: cómo renderiza Blender las cápsulas metaball (con/sin rotación)."""
import bpy
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
mb = bpy.data.metaballs.new("t")
mb.resolution = 0.012
mb.threshold = 0.3
o = bpy.data.objects.new("t", mb)
bpy.context.scene.collection.objects.link(o)

# e1: cápsula default en el centro (sin rotación)
e1 = mb.elements.new()
e1.co = (0, 0, 0)
e1.radius = 0.07
e1.type = 'CAPSULE'
e1.size_x = 0.3
print("[DBG] e1 type:", e1.type, "size_x:", e1.size_x)

# e2: cápsula desplazada +X (sin rotación) para comparar eje default
e2 = mb.elements.new()
e2.co = (0.7, 0, 0)
e2.radius = 0.07
e2.type = 'CAPSULE'
e2.size_x = 0.3

# e3: cápsula rotada para apuntar a +Y
e3 = mb.elements.new()
e3.co = (-0.7, 0, 0)
e3.radius = 0.07
e3.type = 'CAPSULE'
e3.size_x = 0.3
e3.rotation = Vector((1, 0, 0)).rotation_difference(Vector((0, 1, 0)))
print("[DBG] e3 rotation:", e3.rotation, "size_x:", e3.size_x)

bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = o
bpy.ops.object.convert(target='MESH')
z = bpy.context.active_object
tris = sum(len(p.vertices) - 2 for p in z.data.polygons)
dims = z.dimensions
print(f"[DBG] tris={tris} dims=({dims.x:.3f},{dims.y:.3f},{dims.z:.3f})")

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
cam_d = bpy.data.cameras.new("c")
cam = bpy.data.objects.new("c", cam_d)
sc.collection.objects.link(cam)
cam.location = (2.0, -2.4, 1.6)
d = (Vector((0, 0, 0)) - Vector(cam.location))
cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
sc.render.resolution_x = 640
sc.render.resolution_y = 480
sc.render.filepath = "C:/Users/j1347/Desktop/Proyectos programacion/trabajos/IA INTEGRADA CON ROBLOX STUDIO/robloxIA/exports/lobby-zombie/capsule_debug.png"
bpy.ops.render.render(write_still=True)
print("[DBG] done")
