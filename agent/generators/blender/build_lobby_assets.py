#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_lobby_assets.py — RAASE 2.1 / roblox-36-asset-pipeline (Lote: lobby-zombie)

Fabricación dedicada de mallas "hechas desde 0" para el lobby "Conciencia Zombie",
bajo la doctrina Mesh-First (roblox-12 #266-268).

Contrato de salida (idéntico a blender_export_example.py):
  blender --background --python build_lobby_assets.py -- --asset <id> --name <id> --out <dir> --dims "x,y,z"(metros)
  Salidas: <out>/<name>.glb + <out>/<name>_preview.png + línea de log [RAASE] con tri count.

Convenciones de ejes (Blender):
  X = ancho, Y = largo (FRENTE hacia +Y  =>  -Z en Roblox), Z = altura.
  `--dims` en metros: x=ancho, y=alto, z=largo (studs * 0.28 desde el manifiesto).
"""

import bpy
import math
import os
import sys
import argparse
import random
from mathutils import Vector, Matrix, Euler


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser(description="RAASE lobby-zombie asset builder")
    p.add_argument("--asset", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--dims", required=True)
    p.add_argument("--color", default=None)
    p.add_argument("--seed", type=int, default=42)
    a = p.parse_args(argv)
    a.dims = tuple(float(x) for x in a.dims.split(","))
    if a.color:
        a.color = tuple(float(x) for x in a.color.split(","))
    return a


# ---------------------------------------------------------------------------
# Librería base
# ---------------------------------------------------------------------------
def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.75, metal=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
        b.inputs["Roughness"].default_value = rough
        b.inputs["Metallic"].default_value = metal
    return m


def activate(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def box(sx, sy, sz, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    o.rotation_euler = Euler(rot, 'XYZ')
    o.location = loc
    # Hornear la escala en los vértices: la matemática de vértices usa unidades reales
    activate(o)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if m:
        o.data.materials.append(m)
    return o


def cyl(radius, depth, axis='Z', verts=16, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=verts)
    o = bpy.context.active_object
    base = {'Z': (0, 0, 0), 'X': (0, math.pi / 2, 0), 'Y': (math.pi / 2, 0, 0)}[axis]
    o.rotation_euler = Euler((base[0] + rot[0], base[1] + rot[1], base[2] + rot[2]), 'XYZ')
    o.location = loc
    if m:
        o.data.materials.append(m)
    return o


def cone(r1, r2, depth, axis='Z', verts=14, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, vertices=verts)
    o = bpy.context.active_object
    base = {'Z': (0, 0, 0), 'X': (0, math.pi / 2, 0), 'Y': (math.pi / 2, 0, 0)}[axis]
    o.rotation_euler = Euler((base[0] + rot[0], base[1] + rot[1], base[2] + rot[2]), 'XYZ')
    o.location = loc
    if m:
        o.data.materials.append(m)
    return o


def sphere(r, seg=12, ring=8, loc=(0, 0, 0), scale=(1, 1, 1), m=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=ring)
    o = bpy.context.active_object
    o.scale = scale
    o.location = loc
    if m:
        o.data.materials.append(m)
    return o


def bevel(o, width, segs=2):
    activate(o)
    mod = o.modifiers.new(name="bev", type='BEVEL')
    mod.width = width
    mod.segments = segs
    mod.limit_method = 'ANGLE'
    mod.angle_limit = math.radians(30)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o


def boolean_diff(o, cutter):
    activate(o)
    mod = o.modifiers.new(name="bool", type='BOOLEAN')
    mod.operation = 'DIFFERENCE'
    mod.object = cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return o


def join(objs, name):
    activate(objs[0])
    for o in objs[1:]:
        o.select_set(True)
    bpy.ops.object.join()
    j = bpy.context.active_object
    j.name = name
    return j


def shade_smooth(o):
    activate(o)
    bpy.ops.object.shade_smooth()
    return o


def shade_flat(o):
    activate(o)
    bpy.ops.object.shade_flat()
    return o


def taper_z(o, z0, z1, f0, f1, cx=0.0, cy=0.0):
    """Escala X/Y por vértice según su altura (z0..z1) interpolando f0→f1."""
    for v in o.data.vertices:
        t = (v.co.z - z0) / (z1 - z0) if z1 != z0 else 0.0
        t = max(0.0, min(1.0, t))
        s = f0 + (f1 - f0) * t
        v.co.x = cx + (v.co.x - cx) * s
        v.co.y = cy + (v.co.y - cy) * s
    return o


def transform_verts(o, fn):
    for v in o.data.vertices:
        v.co = fn(v.co)
    return o


def rotate_verts(o, pivot, axis, deg):
    piv = Matrix.Translation(Vector(pivot))
    rot = Matrix.Rotation(math.radians(deg), 4, axis)
    m = piv @ rot @ piv.inverted()
    for v in o.data.vertices:
        v.co = m @ v.co
    return o


def assign_mats(o, mats):
    o.data.materials.clear()
    for m in mats:
        o.data.materials.append(m)
    return o


def render_preview(objs, path):
    scene = bpy.context.scene
    engines = ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH")
    last_err = None
    for engine in engines:
        try:
            scene.render.engine = engine
            last_err = None
            break
        except TypeError as e:
            last_err = e
    if last_err:
        scene.render.engine = "BLENDER_WORKBENCH"

    # bounding box total
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    center = (lo + hi) / 2
    size = max((hi - lo).x, (hi - lo).y, (hi - lo).z, 0.2)

    cam_data = bpy.data.cameras.new("preview_cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("preview_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = center + Vector((size * 1.3, size * 1.6, size * 0.85))
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam

    sun_data = bpy.data.lights.new("sun", type='SUN')
    sun_data.energy = 3.2
    sun_data.use_shadow = False
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (math.radians(52), math.radians(12), math.radians(40))
    scene.collection.objects.link(sun)
    fill_data = bpy.data.lights.new("fill", type='SUN')
    fill_data.energy = 1.3
    fill_data.use_shadow = False
    fill = bpy.data.objects.new("fill", fill_data)
    fill.rotation_euler = (math.radians(65), math.radians(-20), math.radians(-140))
    scene.collection.objects.link(fill)

    world = bpy.data.worlds.new("preview_world") if scene.world is None else scene.world
    scene.world = world
    if world.use_nodes:
        bg = world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs[0].default_value = (0.09, 0.10, 0.12, 1.0)

    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def bake_materials_to_vertex_colors(objs):
    """Hornea los colores de los materiales Principled BSDF en un Color Attribute de vértice
    para que Roblox Studio los renderice con sus colores nativos directamente desde el .glb."""
    for obj in objs:
        if not obj or obj.type != 'MESH':
            continue
        mesh = obj.data
        if hasattr(mesh, "color_attributes"):
            color_attr = mesh.color_attributes.get("Color")
            if not color_attr:
                color_attr = mesh.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
            for poly in mesh.polygons:
                col = (0.7, 0.7, 0.7, 1.0)
                if poly.material_index < len(mesh.materials):
                    m = mesh.materials[poly.material_index]
                    if m and m.use_nodes:
                        b = m.node_tree.nodes.get("Principled BSDF")
                        if b and "Base Color" in b.inputs:
                            dv = b.inputs["Base Color"].default_value
                            col = (dv[0], dv[1], dv[2], 1.0)
                for loop_idx in poly.loop_indices:
                    color_attr.data[loop_idx].color = col
        elif hasattr(mesh, "vertex_colors"):
            vcol = mesh.vertex_colors.get("Color") or mesh.vertex_colors.new(name="Color")
            for poly in mesh.polygons:
                col = (0.7, 0.7, 0.7, 1.0)
                if poly.material_index < len(mesh.materials):
                    m = mesh.materials[poly.material_index]
                    if m and m.use_nodes:
                        b = m.node_tree.nodes.get("Principled BSDF")
                        if b and "Base Color" in b.inputs:
                            dv = b.inputs["Base Color"].default_value
                            col = (dv[0], dv[1], dv[2], 1.0)
                for loop_idx in poly.loop_indices:
                    vcol.data[loop_idx].color = col


def export_glb(path, objs=None):
    if objs:
        bake_materials_to_vertex_colors(objs)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False, export_colors=True)
    return path



def tri_count(objs):
    total = 0
    for o in objs:
        total += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return total


# ---------------------------------------------------------------------------
# BUILDERS
# ---------------------------------------------------------------------------
def build_car(dims, color):
    """Sedán low-poly: perfil lateral con cabina inclinada, arcos de rueda (boolean),
    banda de ventanas, ruedas con llanta, paragolpes y faros."""
    W, H, L = dims  # ancho, alto, largo (m)
    r = random.Random(11)
    body_c = color or (0.46, 0.18, 0.14)
    m_body = mat("car_body", body_c, 0.62)
    m_glass = mat("car_glass", (0.04, 0.05, 0.06), 0.25, 0.2)
    m_tire = mat("car_tire", (0.045, 0.045, 0.05), 0.9)
    m_chrome = mat("car_chrome", (0.55, 0.57, 0.6), 0.35, 0.75)
    m_light = mat("car_light", (0.95, 0.9, 0.72), 0.4)
    m_tail = mat("car_tail", (0.6, 0.08, 0.07), 0.4)
    parts = []

    wheel_r = min(H * 0.225, 0.34)
    # carrocería inferior
    lower = box(W, L * 0.985, H * 0.32, loc=(0, 0, wheel_r * 0.9 + H * 0.16), m=m_body)
    bevel(lower, 0.05, 2)
    # capó / nariz: desplazar vértices superiores delanteros hacia abajo
    transform_verts(lower, lambda c: Vector((c.x, c.y, c.z - (0.06 if (c.y > L * 0.30 and c.z > 0) else 0.0))))
    # cabina con parabrisas inclinado
    cab_l = L * 0.44
    cab = box(W * 0.93, cab_l, H * 0.42, loc=(0, -L * 0.05, wheel_r * 0.9 + H * 0.16 + H * 0.16 + H * 0.21), m=m_body)
    cz_top = cab.location.z
    def rake(c):
        if c.z > 0.0:
            backend = -(H * 0.24) if c.y > 0 else (H * 0.11)
            return Vector((c.x, c.y + backend, c.z))
        return c
    transform_verts(cab, rake)
    bevel(cab, 0.045, 2)
    # banda de ventanas (sobresale 5 mm por lado)
    band = box(W * 0.945, cab_l * 0.96, H * 0.20, loc=(0, -L * 0.05, wheel_r * 0.9 + H * 0.16 + H * 0.30))
    band.data.materials.append(m_glass)
    # ruedas
    axle_y = L * 0.305
    for sx in (1, -1):
        for sy in (1, -1):
            tire = cyl(wheel_r, 0.24, axis='X', verts=16, loc=(sx * (W / 2 - 0.11), sy * axle_y, wheel_r))
            tire.data.materials.append(m_tire)
            hub = cyl(wheel_r * 0.52, 0.255, axis='X', verts=12, loc=(sx * (W / 2 - 0.11), sy * axle_y, wheel_r))
            hub.data.materials.append(m_chrome)
            parts += [tire, hub]
    # arcos de rueda (boolean)
    for sy in (1, -1):
        cutter = cyl(wheel_r * 1.18, W * 1.3, axis='X', verts=18, loc=(0, sy * axle_y, wheel_r))
        boolean_diff(lower, cutter)
    # paragolpes
    for sy in (1, -1):
        b = box(W * 0.99, 0.16, 0.17, loc=(0, sy * (L / 2 - 0.07), wheel_r * 0.75))
        b.data.materials.append(m_chrome)
        parts.append(b)
    # faros / luces traseras
    for sx in (1, -1):
        hl = box(0.17, 0.06, 0.11, loc=(sx * W * 0.30, L / 2 - 0.02, wheel_r * 1.35))
        hl.data.materials.append(m_light)
        tl = box(0.15, 0.05, 0.10, loc=(sx * W * 0.30, -(L / 2 - 0.02), wheel_r * 1.35))
        tl.data.materials.append(m_tail)
        parts += [hl, tl]
    # retrovisores
    for sx in (1, -1):
        mr = box(0.05, 0.09, 0.06, loc=(sx * (W / 2 + 0.02), L * 0.16, wheel_r * 0.9 + H * 0.42))
        mr.data.materials.append(m_chrome)
        parts.append(mr)
    car = join([lower, cab, band] + parts, "mesh_car_sedan")
    car.data.materials  # keep
    return [car]


def build_bus(dims, color):
    """Colectivo: casco con techo abovedado, banda de ventanas envolvente,
    parabrisas, faldón inferior, 6 ruedas y ventilaciones de techo."""
    W, H, L = dims
    body_c = color or (0.40, 0.45, 0.50)
    m_body = mat("bus_body", body_c, 0.6)
    m_glass = mat("bus_glass", (0.04, 0.05, 0.06), 0.25, 0.2)
    m_tire = mat("bus_tire", (0.045, 0.045, 0.05), 0.9)
    m_dark = mat("bus_dark", (0.16, 0.17, 0.18), 0.7)
    m_chrome = mat("bus_chrome", (0.5, 0.52, 0.55), 0.35, 0.7)
    parts = []

    wheel_r = 0.45
    body_h = H * 0.72
    lower = box(W, L * 0.99, body_h, loc=(0, 0, 0.45 + body_h / 2 - 0.05), m=m_body)
    bevel(lower, 0.06, 2)
    # techo abovedado (vértices superiores hacia adentro)
    roof = box(W * 0.97, L * 0.965, H * 0.2, loc=(0, 0, 0.45 + body_h - 0.05 + H * 0.1), m=m_body)
    transform_verts(roof, lambda c: Vector((c.x * (0.82 if c.z > 0 else 1.0), c.y, c.z)))
    bevel(roof, 0.05, 2)
    # banda de ventanas
    band = box(W + 0.03, L * 0.86, body_h * 0.36, loc=(0, -L * 0.02, 0.45 + body_h * 0.62))
    band.data.materials.append(m_glass)
    # parabrisas y luneta
    ws = box(W * 0.9, 0.07, body_h * 0.4, loc=(0, L / 2 - 0.015, 0.45 + body_h * 0.62))
    rs = box(W * 0.9, 0.07, body_h * 0.36, loc=(0, -(L / 2 - 0.015), 0.45 + body_h * 0.60))
    ws.data.materials.append(m_glass)
    rs.data.materials.append(m_glass)
    # faldón
    skirt = box(W * 1.01, L * 0.97, 0.2, loc=(0, 0, 0.44))
    skirt.data.materials.append(m_dark)
    # ruedas (6)
    for ax in (L * 0.32, -(L * 0.30), -(L * 0.30 + 0.95)):
        for sx in (1, -1):
            t = cyl(wheel_r, 0.3, axis='X', verts=16, loc=(sx * (W / 2 - 0.14), ax, wheel_r))
            t.data.materials.append(m_tire)
            hub = cyl(wheel_r * 0.5, 0.31, axis='X', verts=12, loc=(sx * (W / 2 - 0.14), ax, wheel_r))
            hub.data.materials.append(m_chrome)
            parts += [t, hub]
    # paragolpes
    for sy in (1, -1):
        b = box(W + 0.05, 0.2, 0.28, loc=(0, sy * (L / 2 - 0.06), 0.62))
        b.data.materials.append(m_chrome)
        parts.append(b)
    # ventilaciones de techo
    for i in range(2):
        v = box(W * 0.5, L * 0.14, 0.12, loc=(0, -L * 0.18 + i * L * 0.32, 0.45 + body_h + H * 0.18))
        v.data.materials.append(m_dark)
        parts.append(v)
    bus = join([lower, roof, band, ws, rs, skirt] + parts, "mesh_bus_wreck")
    return [bus]


def build_truck(dims, color):
    """Camión militar: cabina con capó corto, caja de carga con lona arqueada,
    6 ruedas, paragolpes, espejos y tanque de combustible lateral."""
    W, H, L = dims
    body_c = color or (0.30, 0.33, 0.22)
    m_body = mat("truck_body", body_c, 0.7, 0.1)
    m_canvas = mat("truck_canvas", (0.36, 0.38, 0.26), 0.9)
    m_tire = mat("truck_tire", (0.045, 0.045, 0.05), 0.9)
    m_glass = mat("truck_glass", (0.04, 0.05, 0.06), 0.25, 0.2)
    m_dark = mat("truck_dark", (0.14, 0.15, 0.16), 0.7)
    parts = []

    wheel_r = 0.45
    # chasis
    ch = box(W * 0.88, L, 0.2, loc=(0, 0, 0.52))
    ch.data.materials.append(m_dark)
    # capó corto
    nose = box(W * 0.95, L * 0.16, 0.72, loc=(0, L / 2 - L * 0.08, 0.72), m=m_body)
    bevel(nose, 0.05, 2)
    gr = box(W * 0.8, 0.06, 0.5, loc=(0, L / 2 - 0.01, 0.78))
    gr.data.materials.append(m_dark)
    # cabina
    cab = box(W, L * 0.24, 1.42, loc=(0, L / 2 - L * 0.16 - L * 0.12, 0.62 + 1.42 / 2 - 0.02), m=m_body)
    bevel(cab, 0.05, 2)
    ws = box(W * 0.88, 0.06, 0.62, loc=(0, cab.location.y + L * 0.12 - 0.01, 1.62))
    ws.data.materials.append(m_glass)
    # caja de carga
    bed = box(W, L * 0.52, 0.88, loc=(0, -(L / 2) + L * 0.26 + 0.05, 0.62 + 0.44 - 0.02), m=m_body)
    bevel(bed, 0.04, 2)
    for sx in (1, -1):
        rail = box(0.07, L * 0.52, 0.3, loc=(sx * (W / 2 - 0.035), bed.location.y, bed.location.z + 0.59))
        rail.data.materials.append(m_body)
        parts.append(rail)
    # lona arqueada
    canvas = cyl(1.02, L * 0.5, axis='Y', verts=18, loc=(0, bed.location.y, bed.location.z + 0.32), m=m_canvas)
    transform_verts(canvas, lambda c: Vector((c.x, c.y * 0.62, c.z)))
    # ruedas (6)
    axles = (L / 2 - L * 0.16, -(L / 2) + 1.55, -(L / 2) + 2.85)
    for ax in axles:
        for sx in (1, -1):
            t = cyl(wheel_r, 0.34, axis='X', verts=16, loc=(sx * (W / 2 - 0.16), ax, wheel_r))
            t.data.materials.append(m_tire)
            hub = cyl(wheel_r * 0.5, 0.35, axis='X', verts=12, loc=(sx * (W / 2 - 0.16), ax, wheel_r))
            hub.data.materials.append(m_dark)
            parts += [t, hub]
    # paragolpes
    bf = box(W + 0.08, 0.2, 0.34, loc=(0, L / 2 - 0.05, 0.6))
    bf.data.materials.append(m_body)
    # tanque de combustible
    tank = cyl(0.2, 0.8, axis='Y', verts=12, loc=(W / 2 + 0.06, L * 0.05 - 0.3, 0.62))
    tank.data.materials.append(m_body)
    # espejos
    for sx in (1, -1):
        mr = box(0.05, 0.1, 0.5, loc=(sx * (W / 2 + 0.1), cab.location.y + L * 0.1, 1.75))
        mr.data.materials.append(m_dark)
        parts.append(mr)
    truck = join([ch, nose, gr, cab, ws, bed, canvas, bf, tank] + parts, "mesh_truck_military")
    return [truck]


def build_zombie(dims, color):
    """Infectado estilizado — reconstruido con METABALLS (volúmenes orgánicos fusionados)
    para lograr una silueta de criatura real, no un ensamblado de cubos.
    Postura encorvada, brazos extendidos hacia adelante, piernas flexionadas."""
    W, H, L = dims
    r = random.Random(66)
    skin_c = color or (0.42, 0.50, 0.33)
    m_skin = mat("zombie_skin", skin_c, 0.85)
    m_pants = mat("zombie_pants", (0.15, 0.14, 0.18), 0.9)
    m_shirt = mat("zombie_shirt", (0.30, 0.33, 0.26), 0.92)

    mb = bpy.data.metaballs.new("zomb_mb")
    mb.resolution = 0.012
    mb.render_resolution = 0.012
    mb.threshold = 0.3
    mobj = bpy.data.objects.new("zomb_mb_obj", mb)
    bpy.context.scene.collection.objects.link(mobj)

    def ball(x, y, z, rad):
        el = mb.elements.new()
        el.co = (x, y, z)
        el.radius = rad
        return el

    def capsule(p1, p2, rad):
        p1v, p2v = Vector(p1), Vector(p2)
        d = p2v - p1v
        el = mb.elements.new()
        el.co = (p1v + p2v) / 2
        el.radius = rad
        el.type = 'CAPSULE'
        el.size_x = d.length / 2
        el.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())
        return el

    # Piernas: cápsulas (muslo + espinilla) y pies — fusión total garantizada
    for sx in (0.10, -0.10):
        capsule((sx, 0.00, 0.92), (sx, 0.03, 0.55), 0.105)
        capsule((sx, 0.03, 0.55), (sx, 0.06, 0.17), 0.082)
        ball(sx, 0.075, 0.105, 0.070)     # talón
        ball(sx, 0.095, 0.055, 0.062)     # planta
        ball(sx, 0.185, 0.05, 0.052)      # puntera
    # Pelvis
    ball(0, 0.0, 1.02, 0.165)
    # Columna encorvada (paramétrica hacia adelante)
    for i in range(7):
        t = i / 6.0
        ball(0, 0.02 + 0.15 * (t ** 1.4), 1.08 + 0.085 * i, 0.165 + 0.042 * t)
    # Hombros caídos hacia adelante
    ball(0.19, 0.17, 1.50, 0.118)
    ball(-0.19, 0.17, 1.50, 0.118)
    # Cuello y cabeza (cráneo + mandíbula + nuca)
    ball(0, 0.20, 1.58, 0.085)
    ball(0, 0.235, 1.70, 0.118)           # cráneo
    ball(0, 0.28, 1.645, 0.075)           # mandíbula hacia adelante
    ball(0, 0.19, 1.755, 0.088)           # nuca
    # Brazos extendidos: cadenas de bolas súper ajustadas (fusión suave comprobada)
    for sx, lift in ((1.0, 0.0), (-1.0, 0.055)):
        p1 = Vector((sx * 0.20, 0.20, 1.49 + lift))
        p2 = Vector((sx * 0.24, 0.86, 1.29 + lift))
        n = 16
        for i in range(n + 1):
            t = i / n
            p = p1 + (p2 - p1) * t
            rad = 0.072 - 0.020 * t
            ball(p.x, p.y, p.z, rad)
        ball(p2.x, p2.y + 0.05, p2.z - 0.01, 0.060)   # mano
        ball(p2.x, p2.y + 0.11, p2.z, 0.045)          # dedos

    activate(mobj)
    bpy.ops.object.convert(target='MESH')
    zobj = bpy.context.active_object
    zobj.name = "mesh_zombie"

    pre_tris = sum(len(p.vertices) - 2 for p in zobj.data.polygons)
    print(f"[RAASE-DEBUG] zombie premesh tris={pre_tris}")
    activate(zobj)
    dec = zobj.modifiers.new("dec", 'DECIMATE')
    if os.environ.get("CZ_NODEC") == "1":
        dec.ratio = 1.0
    else:
        dec.ratio = min(1.0, max(0.15, 12000.0 / max(pre_tris, 1)))
    bpy.ops.object.modifier_apply(modifier=dec.name)

    assign_mats(zobj, [m_skin, m_pants, m_shirt])
    for p in zobj.data.polygons:
        z = p.center.z
        x = abs(p.center.x)
        if z < 0.98:
            p.material_index = 1        # pantalón
        elif z < 1.45 and x < 0.19:
            p.material_index = 2 if r.random() > 0.3 else 0   # camisa rasgada (solo torso)
        else:
            p.material_index = 0        # piel
    shade_smooth(zobj)
    return [zobj]


def build_mannequin(dims, color):
    """Maniquí de armadura: base, poste, torso blindado con hombreras y cabeza de acero."""
    W, H, L = dims
    steel_c = color or (0.30, 0.32, 0.36)
    m_steel = mat("manq_steel", steel_c, 0.45, 0.65)
    m_dark = mat("manq_dark", (0.12, 0.12, 0.14), 0.6, 0.3)
    m_head = mat("manq_head", (0.42, 0.44, 0.48), 0.4, 0.7)
    parts = []

    base = cyl(0.30, 0.06, axis='Z', verts=16, loc=(0, 0, 0.03))
    base.data.materials.append(m_dark)
    pole = cyl(0.035, 0.78, axis='Z', verts=10, loc=(0, 0, 0.45))
    pole.data.materials.append(m_dark)
    hip = box(0.26, 0.16, 0.12, loc=(0, 0, 0.88))
    hip.data.materials.append(m_dark)

    torso = box(0.34, 0.22, 0.62, loc=(0, 0, 1.22))
    taper_z(torso, -0.31, 0.31, 0.72, 1.14)
    bevel(torso, 0.05, 2)
    shade_smooth(torso)
    torso.data.materials.append(m_steel)
    for sx in (1, -1):
        pad = box(0.15, 0.21, 0.11, loc=(sx * 0.23, 0, 1.47), rot=(0, sx * 0.32, 0))
        bevel(pad, 0.03, 2)
        pad.data.materials.append(m_steel)
        parts.append(pad)
    collar = cyl(0.065, 0.06, axis='Z', verts=12, loc=(0, 0, 1.53))
    collar.data.materials.append(m_dark)
    head = sphere(0.105, seg=12, ring=8, loc=(0, 0, 1.64), scale=(0.85, 0.95, 1.2))
    head.data.materials.append(m_head)
    shade_smooth(head)

    manq = join([base, pole, hip, torso, collar, head] + parts, "mesh_mannequin")
    return [manq]


def build_rifle(dims, color):
    """Rifle de asalto: receptor, cañón fina, culata y empuñadura de madera,
    cargador angulado, alza y punto de mira."""
    W, H, L = dims  # L ≈ 1.0 m
    m_metal = mat("rifle_metal", (0.10, 0.10, 0.12), 0.45, 0.7)
    m_wood = mat("rifle_wood", color or (0.34, 0.23, 0.13), 0.75)
    m_dark = mat("rifle_dark", (0.06, 0.06, 0.07), 0.5, 0.5)
    S = L / 1.008  # factor de escala por largo real
    parts = []

    receiver = box(0.045 * S, 0.30 * S, 0.085 * S, loc=(0, -0.06 * S, 0.02 * S))
    receiver.data.materials.append(m_metal)
    barrel = cyl(0.013 * S, 0.46 * S, axis='Y', verts=10, loc=(0, 0.28 * S, 0.03 * S))
    barrel.data.materials.append(m_dark)
    muzzle = box(0.03 * S, 0.05 * S, 0.045 * S, loc=(0, 0.505 * S, 0.03 * S))
    muzzle.data.materials.append(m_dark)
    guard = box(0.05 * S, 0.22 * S, 0.07 * S, loc=(0, 0.16 * S, 0.025 * S))
    guard.data.materials.append(m_metal)
    rail = box(0.03 * S, 0.34 * S, 0.018 * S, loc=(0, -0.02 * S, 0.075 * S))
    rail.data.materials.append(m_dark)
    rsight = box(0.026 * S, 0.05 * S, 0.04 * S, loc=(0, -0.16 * S, 0.095 * S))
    rsight.data.materials.append(m_dark)
    fsight = box(0.02 * S, 0.035 * S, 0.045 * S, loc=(0, 0.40 * S, 0.085 * S))
    fsight.data.materials.append(m_dark)
    stock = box(0.038 * S, 0.28 * S, 0.115 * S, loc=(0, -0.345 * S, 0.005 * S), rot=(0.05, 0, 0))
    bevel(stock, 0.012 * S, 1)
    stock.data.materials.append(m_wood)
    butt = box(0.042 * S, 0.025 * S, 0.13 * S, loc=(0, -0.49 * S, -0.002 * S), rot=(0.13, 0, 0))
    butt.data.materials.append(m_dark)
    grip = box(0.034 * S, 0.055 * S, 0.15 * S, loc=(0, -0.145 * S, -0.075 * S), rot=(0.32, 0, 0))
    grip.data.materials.append(m_wood)
    mag = box(0.036 * S, 0.095 * S, 0.22 * S, loc=(0, 0.01 * S, -0.10 * S), rot=(-0.2, 0, 0))
    bevel(mag, 0.01 * S, 1)
    mag.data.materials.append(m_dark)
    trig = box(0.03 * S, 0.085 * S, 0.012 * S, loc=(0, -0.085 * S, -0.04 * S))
    trig.data.materials.append(m_dark)
    parts += [receiver, barrel, muzzle, guard, rail, rsight, fsight, stock, butt, grip, mag, trig]
    rifle = join(parts, "mesh_rifle")
    return [rifle]


def build_machete(dims, color):
    """Machete: hoja de acero con clip point, guarda y mango torneado."""
    W, H, L = dims
    m_blade = mat("mach_blade", color or (0.52, 0.54, 0.57), 0.4, 0.8)
    m_grip = mat("mach_grip", (0.08, 0.08, 0.09), 0.8)
    m_ring = mat("mach_ring", (0.35, 0.36, 0.38), 0.5, 0.6)
    parts = []

    blade_len = H * 0.74
    grip_len = H * 0.22
    blade_w = min(L, 0.055)  # ancho de hoja realista (≈5.5 cm)
    y0 = -H / 2 + grip_len
    blade = box(0.008, blade_len, blade_w, loc=(0, y0 + blade_len / 2, 0))
    # clip point: recorte del extremo
    transform_verts(blade, lambda c: Vector((c.x,
        c.y + (0.16 * blade_len if (c.y > 0 and c.z > blade_w * 0.05) else 0.0),
        c.z)))
    blade.data.materials.append(m_blade)
    spine = box(0.012, blade_len * 0.9, 0.012, loc=(0, y0 + blade_len * 0.5, blade_w / 2 - 0.006))
    spine.data.materials.append(m_blade)
    guard = box(0.024, 0.02, blade_w * 1.25, loc=(0, y0 - 0.01, 0))
    guard.data.materials.append(m_ring)
    grip = box(0.032, grip_len, 0.042, loc=(0, -H / 2 + grip_len / 2, 0))
    bevel(grip, 0.008, 1)
    grip.data.materials.append(m_grip)
    pommel = cyl(0.028, 0.02, axis='Y', verts=10, loc=(0, -H / 2 + 0.01, 0))
    pommel.data.materials.append(m_ring)
    parts += [blade, spine, guard, grip, pommel]
    machete = join(parts, "mesh_machete")
    return [machete]


def build_bat(dims, color):
    """Bate de béisbol de madera con extremo abombado y pomo."""
    W, H, L = dims
    m_wood = mat("bat_wood", color or (0.45, 0.30, 0.16), 0.7)
    parts = []

    barrel_r = 0.034  # ≈ 6.8 cm de diámetro (referencia real)
    handle_r = 0.024
    body = cone(barrel_r, handle_r, H * 0.86, axis='Y', verts=12, loc=(0, H * 0.035, 0))
    # barril más grueso en el extremo (segunda pasada cónica suave)
    transform_verts(body, lambda c: Vector((c.x, c.y, c.z)))
    body.data.materials.append(m_wood)
    knob = cyl(handle_r * 1.35, 0.045, axis='Y', verts=10, loc=(0, -H * 0.455, 0))
    bevel(knob, 0.008, 1)
    knob.data.materials.append(m_wood)
    parts += [body, knob]
    bat = join(parts, "mesh_bat")
    return [bat]


def build_generator(dims, color):
    """Generador portátil: carcasa, tanque superior con tapa, rejillas de ventilación,
    escape, panel de control con tomacorrientes y asa de transporte."""
    W, H, L = dims  # W = 0.45, H = 0.50, L = 0.64
    m_body = mat("gen_body", color or (0.62, 0.25, 0.12), 0.55, 0.2)
    m_dark = mat("gen_dark", (0.10, 0.10, 0.11), 0.6, 0.4)
    m_metal = mat("gen_metal", (0.35, 0.36, 0.38), 0.4, 0.7)
    parts = []

    # carcasa principal
    body = box(W, L * 0.92, H * 0.78, loc=(0, 0, H * 0.39 + 0.025), m=m_body)
    bevel(body, 0.02, 2)
    # tanque de combustible
    tank = box(W * 0.94, L * 0.70, H * 0.14, loc=(0, -L * 0.05, H * 0.85), m=m_body)
    bevel(tank, 0.015, 2)
    cap = cyl(0.045, 0.05, axis='Z', verts=10, loc=(0, -L * 0.28, H * 0.95))
    cap.data.materials.append(m_dark)
    # rejillas de ventilación (lado +X)
    for i in range(3):
        v = box(0.012, L * 0.44, H * 0.05, loc=(W / 2 + 0.004, 0, H * 0.22 + i * H * 0.13))
        v.data.materials.append(m_dark)
        parts.append(v)
    # escape
    ex = cyl(0.02, H * 0.55, axis='Z', verts=10, loc=(W * 0.36, -L * 0.40, H * 0.42))
    ex.data.materials.append(m_dark)
    tip = cyl(0.028, 0.03, axis='Z', verts=10, loc=(W * 0.36, -L * 0.40, H * 0.72))
    tip.data.materials.append(m_metal)
    # panel de control (frente -Y)
    panel = box(W * 0.72, 0.014, H * 0.34, loc=(0, -L * 0.47, H * 0.36))
    panel.data.materials.append(m_dark)
    for sx in (1, -1):
        sock = cyl(0.028, 0.02, axis='Y', verts=10, loc=(sx * W * 0.18, -L * 0.475, H * 0.30))
        sock.data.materials.append(m_metal)
        parts.append(sock)
    sw = box(0.05, 0.016, 0.06, loc=(0, -L * 0.475, H * 0.48))
    sw.data.materials.append(m_metal)
    # asa de transporte (superior trasera)
    for sx in (1, -1):
        post = cyl(0.013, 0.12, axis='Z', verts=8, loc=(sx * W * 0.30, L * 0.38, H * 0.92))
        post.data.materials.append(m_metal)
        parts.append(post)
    handle = cyl(0.015, W * 0.62, axis='X', verts=8, loc=(0, L * 0.38, H * 0.98))
    handle.data.materials.append(m_dark)
    # patas
    for sx in (1, -1):
        for sy in (1, -1):
            ft = box(0.05, 0.05, 0.03, loc=(sx * W * 0.38, sy * L * 0.40, 0.015))
            ft.data.materials.append(m_dark)
            parts.append(ft)
    gen = join([body, tank, cap, ex, tip, panel, sw, handle] + parts, "mesh_generator")
    return [gen]


def build_mg(dims, color):
    """Ametralladora pesada: receptor con tapa superior, cañón largo, freno de boca,
    agarres de mariposa, caja de munición lateral y horquilla de afuste."""
    W, H, L = dims  # aprox 0.31 × 0.36 × 1.65 m
    m_gun = mat("mg_gun", color or (0.11, 0.12, 0.13), 0.45, 0.65)
    m_dark = mat("mg_dark", (0.06, 0.06, 0.07), 0.6, 0.4)
    m_olive = mat("mg_olive", (0.28, 0.30, 0.20), 0.8)
    parts = []

    S = L / 1.65
    receiver = box(0.09 * S, 0.44 * S, 0.13 * S, loc=(0, -0.33 * S, 0.0))
    receiver.data.materials.append(m_gun)
    cover = box(0.085 * S, 0.42 * S, 0.045 * S, loc=(0, -0.33 * S, 0.088 * S))
    bevel(cover, 0.012 * S, 1)
    cover.data.materials.append(m_gun)
    barrel = cyl(0.021 * S, 0.66 * S, axis='Y', verts=12, loc=(0, 0.16 * S, 0.01 * S))
    barrel.data.materials.append(m_dark)
    muzzle = box(0.036 * S, 0.06 * S, 0.04 * S, loc=(0, 0.505 * S, 0.01 * S))
    muzzle.data.materials.append(m_dark)
    fsight = box(0.018 * S, 0.03 * S, 0.05 * S, loc=(0, 0.40 * S, 0.06 * S))
    fsight.data.materials.append(m_dark)
    backplate = box(0.10 * S, 0.03 * S, 0.15 * S, loc=(0, -0.565 * S, 0.0))
    backplate.data.materials.append(m_dark)
    for sx in (1, -1):
        g = cyl(0.015 * S, 0.13 * S, axis='Z', verts=8, loc=(sx * 0.055 * S, -0.63 * S, 0.01 * S), rot=(-0.5, 0, 0))
        g.data.materials.append(m_dark)
        parts.append(g)
    gbar = cyl(0.013 * S, 0.13 * S, axis='X', verts=8, loc=(0, -0.685 * S, 0.055 * S))
    gbar.data.materials.append(m_dark)
    trigframe = box(0.06 * S, 0.13 * S, 0.10 * S, loc=(0, -0.52 * S, -0.095 * S))
    trigframe.data.materials.append(m_dark)
    ammo = box(0.115 * S, 0.24 * S, 0.16 * S, loc=(-0.175 * S, -0.28 * S, -0.03 * S))
    bevel(ammo, 0.012 * S, 1)
    ammo.data.materials.append(m_olive)
    post = cyl(0.034 * S, 0.17 * S, axis='Z', verts=10, loc=(0, -0.33 * S, -0.155 * S))
    post.data.materials.append(m_gun)
    for sx in (1, -1):
        fk = box(0.012 * S, 0.11 * S, 0.10 * S, loc=(sx * 0.05 * S, -0.33 * S, -0.075 * S))
        fk.data.materials.append(m_gun)
        parts.append(fk)
    parts += [receiver, cover, barrel, muzzle, fsight, backplate, gbar, trigframe, ammo, post]
    mg = join(parts, "mesh_mg_turret")
    return [mg]


def build_tree(dims, color):
    """Árbol muerto: tronco nudoso en 3 segmentos con inclinación, flare de raíces,
    ramas quebradas splayed y muñones. Sin hojas."""
    W, H, L = dims
    m_wood = mat("tree_wood", color or (0.30, 0.25, 0.19), 0.95)
    parts = []

    flare = cone(0.46, 0.30, 0.6, verts=10, loc=(0, 0, 0.30))
    flare.data.materials.append(m_wood)
    s1 = cone(0.30, 0.23, 2.7, verts=10, loc=(0, 0.03, 1.85), rot=(0.05, 0, 0.02))
    s2 = cone(0.23, 0.145, 2.5, verts=10, loc=(-0.02, 0.10, 4.45), rot=(0.09, 0, -0.04))
    s3 = cone(0.145, 0.05, 1.7, verts=9, loc=(0.01, 0.08, 6.55), rot=(-0.10, 0, 0.05))
    for s in (s1, s2, s3):
        s.data.materials.append(m_wood)
    top = cone(0.055, 0.02, 0.35, verts=8, loc=(0.0, 0.02, 7.50), rot=(0.55, 0, 0.35))
    top.data.materials.append(m_wood)
    parts += [flare, s1, s2, s3, top]

    branches = [
        (3.55, 25, 64, 2.0), (4.30, 135, 56, 2.35), (4.95, 250, 61, 2.0),
        (5.60, 70, 50, 1.7), (6.15, 205, 58, 1.5), (6.70, 315, 47, 1.25),
    ]
    for (bh, az, tilt, blen) in branches:
        tr, tz = math.radians(tilt), math.radians(az)
        axis = Vector((math.sin(tr) * math.sin(tz), -math.sin(tr) * math.cos(tz), math.cos(tr)))
        base = Vector((0.0, 0.06, bh))
        loc = base + axis * (blen / 2)
        br = cone(0.06, 0.014, blen, verts=8, loc=(loc.x, loc.y, loc.z), rot=(tr, 0, tz))
        br.data.materials.append(m_wood)
        parts.append(br)
    stubs = [(4.0, 300, 70, 0.55), (5.2, 160, 66, 0.6), (6.3, 40, 75, 0.5)]
    for (bh, az, tilt, blen) in stubs:
        tr, tz = math.radians(tilt), math.radians(az)
        axis = Vector((math.sin(tr) * math.sin(tz), -math.sin(tr) * math.cos(tz), math.cos(tr)))
        base = Vector((0.0, 0.06, bh))
        loc = base + axis * (blen / 2)
        st = cone(0.045, 0.02, blen, verts=7, loc=(loc.x, loc.y, loc.z), rot=(tr, 0, tz))
        st.data.materials.append(m_wood)
        parts.append(st)
    tree = join(parts, "mesh_tree_dead")
    return [tree]


def build_tent(dims, color):
    """Carpa militar: prisma de perfil pentagonal con faldones, puerta frontal,
    postes de entrada y estacas."""
    import bmesh
    W, H, L = dims
    m_tent = mat("tent_fabric", color or (0.30, 0.33, 0.24), 0.9)
    m_dark = mat("tent_dark", (0.20, 0.22, 0.16), 0.9)
    m_pole = mat("tent_pole", (0.35, 0.35, 0.37), 0.5, 0.6)
    m_peg = mat("tent_peg", (0.25, 0.20, 0.15), 0.8)

    me = bpy.data.meshes.new("tent_mesh")
    obj = bpy.data.objects.new("mesh_tent_army", me)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    prof = [(-W / 2, 0.0), (-W / 2, H * 0.55), (0.0, H * 0.97), (W / 2, H * 0.55), (W / 2, 0.0)]
    f = [bm.verts.new((x, L / 2, z)) for (x, z) in prof]
    b = [bm.verts.new((x, -L / 2, z)) for (x, z) in prof]
    bm.faces.new(f)
    bm.faces.new(list(reversed(b)))
    for i in range(len(prof) - 1):
        bm.faces.new([f[i], b[i], b[i + 1], f[i + 1]])
    bm.faces.new([f[0], f[4], b[4], b[0]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj.data.materials.append(m_tent)
    parts = [obj]

    for sx in (1, -1):
        flap = box(0.55, L * 0.99, 0.05, loc=(sx * (W / 2 + 0.26), 0, 0.05))
        flap.data.materials.append(m_tent)
        parts.append(flap)
    door = box(W * 0.42, 0.05, H * 0.66, loc=(0, L / 2 + 0.015, H * 0.35))
    door.data.materials.append(m_dark)
    parts.append(door)
    for sx in (1, -1):
        pole = cyl(0.03, H * 0.62, axis='Z', verts=8, loc=(sx * W * 0.33, L / 2 + 0.05, H * 0.31))
        pole.data.materials.append(m_pole)
        parts.append(pole)
        for sy2 in (1, -1):
            peg = cyl(0.018, 0.3, axis='Z', verts=6,
                      loc=(sx * (W / 2 + 0.52), sy2 * (L / 2 + 0.28), 0.10), rot=(0.5 * sy2, 0, 0))
            peg.data.materials.append(m_peg)
            parts.append(peg)
    tent = join(parts, "mesh_tent_army")
    return [tent]


# ---------------------------------------------------------------------------
# DISPATCH + MAIN
# ---------------------------------------------------------------------------
BUILDERS = {
    "mesh_car_sedan": build_car,
    "mesh_bus_wreck": build_bus,
    "mesh_truck_military": build_truck,
    "mesh_zombie": build_zombie,
    "mesh_mannequin": build_mannequin,
    "mesh_rifle": build_rifle,
    "mesh_machete": build_machete,
    "mesh_bat": build_bat,
    "mesh_generator": build_generator,
    "mesh_mg_turret": build_mg,
    "mesh_tree_dead": build_tree,
    "mesh_tent_army": build_tent,
}

# Dimensiones reales fijas (metros) por asset — el manifiesto solo documenta.
# Evita el bucle de retroalimentación dims → geometría → medida → dims.
FIXED_DIMS = {
    "mesh_car_sedan": (1.79, 1.46, 4.59),
    "mesh_bus_wreck": (2.49, 3.19, 12.01),
    "mesh_truck_military": (2.41, 2.91, 6.80),
    "mesh_rifle": (0.14, 0.42, 1.008),
    "mesh_machete": (0.084, 0.756, 0.14),
    "mesh_bat": (0.084, 0.896, 0.084),
    "mesh_generator": (0.448, 0.504, 0.644),
    "mesh_mg_turret": (0.31, 0.65, 1.512),
    "mesh_tent_army": (2.212, 1.904, 3.388),
}


def main():
    args = parse_args()
    builder = BUILDERS.get(args.asset)
    if builder is None:
        raise SystemExit(f"[RAASE] asset desconocido: {args.asset} (disponibles: {', '.join(BUILDERS)})")
    clear_scene()
    build_dims = FIXED_DIMS.get(args.asset, args.dims)
    objs = builder(build_dims, args.color)

    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    mx, my, mz = (hi[0] - lo[0]), (hi[1] - lo[1]), (hi[2] - lo[2])

    os.makedirs(args.out, exist_ok=True)
    glb_path = os.path.join(args.out, f"{args.name}.glb")
    preview_path = os.path.join(args.out, f"{args.name}_preview.png")

    export_glb(glb_path, objs)
    render_preview(objs, preview_path)

    tris = tri_count(objs)
    # studs en orden de manifiesto [x=ancho, y=alto, z=largo]
    studs = (mx / 0.28, mz / 0.28, my / 0.28)
    print(
        f"[RAASE] {args.name}: export={glb_path} | preview={preview_path} | tris={tris} | "
        f"dims_m=[{mx:.3f},{my:.3f},{mz:.3f}] | studs=[{studs[0]:.2f},{studs[1]:.2f},{studs[2]:.2f}]"
    )


if __name__ == "__main__":
    main()
