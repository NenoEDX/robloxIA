#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_slime_assets.py — S13 reference-led cartoon slime asset builder (Blender 5.2 LTS).

One design per invocation. Reads a JSON spec from agent/generators/blender/slime_specs/,
builds an original mesh from parametric primitives, paints an original 1024 colour and
roughness texture by rasterising a procedural material function in UV space, rigs it with
a light armature, authors Idle/Extract/Release clips, exports a GLB with embedded textures
and saves the editable .blend next to the renders and a stats file.

Contract:
  * 1 Blender unit = 1 Roblox stud.
  * Bottom-centre origin (min Z = 0, XY centred on 0).
  * Forward is -Y in Blender.
  * One merged mesh, one skin, three clips, <= 4 normalised bone influences per vertex.
  * No reference image is read or redistributed: references informed the silhouette only.

Usage (driven by agent/generators/run_slime_assets.mjs):
  blender -b --factory-startup --python-exit-code 1 --python build_slime_assets.py -- \
      --spec slime_specs/classic_blue.json --out exports/slime-v1/classic_blue \
      --helper skills-roblox/roblox-36-asset-pipeline/scripts/blender_export_example.py \
      [--skip-render] [--seed 1000]
"""

import argparse
import hashlib
import importlib.util
import json
import math
import os
import struct
import sys
import traceback

import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30
MAX_INFLUENCES = 4
CLIP_ORDER = ("Idle", "Extract", "Release")
ROLES = ("skin", "eye", "glint", "mouth", "cheek", "accent", "accentDeep", "core")


# =============================================================================
# Math, colour and noise
# =============================================================================

def clamp01(value):
    return 0.0 if value < 0.0 else (1.0 if value > 1.0 else value)


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def hex_to_rgb(text):
    text = text.lstrip("#")
    return np.array([int(text[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float64)


def srgb_to_linear(values):
    values = np.clip(values, 0.0, 1.0)
    return np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(values):
    values = np.clip(values, 0.0, 1.0)
    return np.where(values <= 0.0031308, values * 12.92, 1.055 * np.power(values, 1.0 / 2.4) - 0.055)


def _hash3(ix, iy, iz, seed):
    n = (ix * 374761393 + iy * 668265263 + iz * 1274126177 + seed * 982451653) & 0x7FFFFFFF
    n = (n ^ (n >> 13)) & 0x7FFFFFFF
    n = (n * 1274126177) & 0x7FFFFFFF
    n = (n ^ (n >> 16)) & 0x7FFFFFFF
    return n.astype(np.float64) / float(0x7FFFFFFF)


def value_noise(points, seed):
    """Deterministic trilinear value noise in [0, 1] over an (N, 3) array."""
    base = np.floor(points)
    frac = points - base
    ix = base[:, 0].astype(np.int64)
    iy = base[:, 1].astype(np.int64)
    iz = base[:, 2].astype(np.int64)
    ux, uy, uz = smoothstep(frac[:, 0]), smoothstep(frac[:, 1]), smoothstep(frac[:, 2])
    acc = np.zeros(points.shape[0], dtype=np.float64)
    for dx in (0, 1):
        wx = ux if dx else 1.0 - ux
        for dy in (0, 1):
            wy = uy if dy else 1.0 - uy
            for dz in (0, 1):
                wz = uz if dz else 1.0 - uz
                acc += wx * wy * wz * _hash3(ix + dx, iy + dy, iz + dz, seed)
    return acc


def fbm(points, seed):
    return value_noise(points, seed) * 0.65 + value_noise(points * 2.17 + 11.3, seed + 7) * 0.35


def bubble_mask(points, cell_size, seed):
    """One soft round bubble per grid cell, fully contained so no hard cut appears."""
    grid = points / max(cell_size, 1e-4)
    base = np.floor(grid)
    frac = grid - base
    ix = base[:, 0].astype(np.int64)
    iy = base[:, 1].astype(np.int64)
    iz = base[:, 2].astype(np.int64)
    h1 = _hash3(ix, iy, iz, seed + 101)
    h2 = _hash3(ix, iy, iz, seed + 202)
    h3 = _hash3(ix, iy, iz, seed + 303)
    h4 = _hash3(ix, iy, iz, seed + 404)
    centre_x = 0.28 + h1 * 0.44
    centre_y = 0.28 + h2 * 0.44
    centre_z = 0.28 + h3 * 0.44
    radius = 0.1 + h4 * 0.15
    distance = np.sqrt((frac[:, 0] - centre_x) ** 2 + (frac[:, 1] - centre_y) ** 2
                       + (frac[:, 2] - centre_z) ** 2) / radius
    mask = smoothstep(np.clip(1.0 - distance, 0.0, 1.0))
    return np.where(h1 > 0.42, mask, 0.0)


# =============================================================================
# Mesh primitives
# =============================================================================

class MeshData:
    """Raw vertex/face soup for one material role, in final world coordinates."""

    __slots__ = ("verts", "faces", "role", "smooth")

    def __init__(self, role="skin", smooth=True):
        self.verts = []
        self.faces = []
        self.role = role
        self.smooth = smooth

    def add(self, verts, faces):
        offset = len(self.verts)
        self.verts.extend(verts)
        self.faces.extend(tuple(index + offset for index in face) for face in faces)
        return self


def _se(value, exponent):
    return math.copysign(abs(value) ** exponent, value) if abs(value) > 1e-12 else 0.0


def superellipsoid(rx, ry, rz, center=(0.0, 0.0, 0.0), nu=32, nv=20, e=2.0, e2=None):
    """Superquadric surface. e=2 is a sphere, e>2 tends to a rounded box."""
    e2 = e if e2 is None else e2
    m1 = 2.0 / e
    m2 = 2.0 / e2
    cx, cy, cz = center
    verts, faces = [], []
    rings = []
    for j in range(1, nv):
        phi = -math.pi / 2.0 + math.pi * j / nv
        radial = _se(math.cos(phi), m1)
        z = _se(math.sin(phi), m1)
        ring = []
        for i in range(nu):
            theta = 2.0 * math.pi * i / nu
            ring.append(len(verts))
            verts.append((cx + rx * radial * _se(math.cos(theta), m2),
                          cy + ry * radial * _se(math.sin(theta), m2),
                          cz + rz * z))
        rings.append(ring)
    bottom = len(verts)
    verts.append((cx, cy, cz - rz))
    top = len(verts)
    verts.append((cx, cy, cz + rz))
    for i in range(nu):
        j = (i + 1) % nu
        faces.append((bottom, rings[0][j], rings[0][i]))
        faces.append((top, rings[-1][i], rings[-1][j]))
    for r in range(len(rings) - 1):
        lower, upper = rings[r], rings[r + 1]
        for i in range(nu):
            j = (i + 1) % nu
            faces.append((lower[i], lower[j], upper[j], upper[i]))
    return verts, faces


def geodesic(radius, subdivisions=2, center=(0.0, 0.0, 0.0), scale=(1.0, 1.0, 1.0), jitter=0.0):
    """Icosphere-based faceted gem: round silhouette, flat polygonal facets."""
    golden = (1.0 + math.sqrt(5.0)) / 2.0
    verts = [(-1.0, golden, 0.0), (1.0, golden, 0.0), (-1.0, -golden, 0.0), (1.0, -golden, 0.0),
             (0.0, -1.0, golden), (0.0, 1.0, golden), (0.0, -1.0, -golden), (0.0, 1.0, -golden),
             (golden, 0.0, -1.0), (golden, 0.0, 1.0), (-golden, 0.0, -1.0), (-golden, 0.0, 1.0)]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4),
             (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8),
             (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(max(0, int(subdivisions))):
        cache = {}
        subdivided = []

        def midpoint(a, b):
            key = (a, b) if a < b else (b, a)
            if key in cache:
                return cache[key]
            va, vb = verts[a], verts[b]
            verts.append(tuple((va[axis] + vb[axis]) * 0.5 for axis in range(3)))
            cache[key] = len(verts) - 1
            return cache[key]

        for (a, b, c) in faces:
            ab, bc, ca = midpoint(a, b), midpoint(b, c), midpoint(c, a)
            subdivided.extend(((a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)))
        faces = subdivided
    out = []
    for index, vertex in enumerate(verts):
        length = math.sqrt(sum(component * component for component in vertex))
        unit = [component / length for component in vertex]
        if jitter > 0.0:
            wobble = 1.0 + jitter * math.sin(index * 12.9898 + 4.1)
        else:
            wobble = 1.0
        out.append((center[0] + unit[0] * radius * scale[0] * wobble,
                    center[1] + unit[1] * radius * scale[1] * wobble,
                    center[2] + unit[2] * radius * scale[2] * wobble))
    return out, faces


def lathe(profile, segments=40, warp=None, close_bottom=True, close_top=True):
    """Revolve a (radius, z) profile around Z. A zero radius collapses to a pole."""
    verts, faces, rings = [], [], []
    for (radius, z) in profile:
        if radius <= 1e-6:
            rings.append(("pole", len(verts)))
            verts.append((0.0, 0.0, z))
            continue
        ring = []
        for i in range(segments):
            theta = 2.0 * math.pi * i / segments
            r, zz = radius, z
            if warp is not None:
                r, zz = warp(theta, z, radius)
            ring.append(len(verts))
            verts.append((r * math.cos(theta), r * math.sin(theta), zz))
        rings.append(("ring", ring))
    for index in range(len(rings) - 1):
        kind_a, a = rings[index]
        kind_b, b = rings[index + 1]
        if kind_a == "ring" and kind_b == "ring":
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((a[i], a[j], b[j], b[i]))
        elif kind_a == "pole" and kind_b == "ring":
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((a, b[i], b[j]))
        elif kind_a == "ring" and kind_b == "pole":
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((b, a[j], a[i]))
    if close_bottom and rings[0][0] == "ring":
        center = len(verts)
        verts.append((0.0, 0.0, profile[0][1]))
        ring = rings[0][1]
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((center, ring[j], ring[i]))
    if close_top and rings[-1][0] == "ring":
        center = len(verts)
        verts.append((0.0, 0.0, profile[-1][1]))
        ring = rings[-1][1]
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((center, ring[i], ring[j]))
    return verts, faces


def _frames(points):
    """Parallel-transport frames along a polyline: (tangent, normal, binormal) per point."""
    count = len(points)
    tangents = []
    for index in range(count):
        if index == 0:
            tangent = points[1] - points[0]
        elif index == count - 1:
            tangent = points[-1] - points[-2]
        else:
            tangent = points[index + 1] - points[index - 1]
        if tangent.length < 1e-9:
            tangent = Vector((0.0, 0.0, 1.0))
        tangents.append(tangent.normalized())
    seed = Vector((0.0, 0.0, 1.0))
    if abs(tangents[0].dot(seed)) > 0.95:
        seed = Vector((0.0, 1.0, 0.0))
    normal = (seed - tangents[0] * seed.dot(tangents[0])).normalized()
    frames = []
    for index in range(count):
        if index > 0:
            rotation = tangents[index - 1].rotation_difference(tangents[index])
            normal = (rotation @ normal).normalized()
            normal = (normal - tangents[index] * normal.dot(tangents[index])).normalized()
        binormal = tangents[index].cross(normal).normalized()
        frames.append((tangents[index], normal, binormal))
    return frames


def sweep(points, radii, segments=14, squash=1.0, caps=True):
    """Tube along a polyline with parallel-transport frames and tapered radii."""
    pts = [Vector(p) for p in points]
    frames = _frames(pts)
    verts, faces, rings = [], [], []
    for index, point in enumerate(pts):
        radius = radii[index]
        if radius <= 1e-6:
            rings.append(("pole", len(verts)))
            verts.append(tuple(point))
            continue
        _, normal, binormal = frames[index]
        ring = []
        for i in range(segments):
            theta = 2.0 * math.pi * i / segments
            offset = normal * (math.cos(theta) * radius) + binormal * (math.sin(theta) * radius * squash)
            ring.append(len(verts))
            verts.append(tuple(point + offset))
        rings.append(("ring", ring))
    for index in range(len(rings) - 1):
        kind_a, a = rings[index]
        kind_b, b = rings[index + 1]
        if kind_a == "ring" and kind_b == "ring":
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((a[i], a[j], b[j], b[i]))
        elif kind_a == "pole":
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((a, b[i], b[j]))
        else:
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((b, a[j], a[i]))
    if caps:
        if rings[0][0] == "ring":
            center = len(verts)
            verts.append(tuple(pts[0]))
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((center, rings[0][1][j], rings[0][1][i]))
        if rings[-1][0] == "ring":
            center = len(verts)
            verts.append(tuple(pts[-1]))
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((center, rings[-1][1][i], rings[-1][1][j]))
    return verts, faces


def shard(base, direction, length, radius, sides=5, waist=0.55, bulge=1.12, flatten=1.0):
    """Faceted crystal spike from a base point. `flatten` squashes one cross-section axis."""
    base_v = Vector(base)
    axis = Vector(direction).normalized()
    helper = Vector((0.0, 0.0, 1.0))
    if abs(axis.dot(helper)) > 0.95:
        helper = Vector((0.0, 1.0, 0.0))
    axis_u = (helper - axis * helper.dot(axis)).normalized()
    axis_v = axis.cross(axis_u).normalized()
    verts, faces = [], []
    rings = []
    for station, (height, scale) in enumerate(((0.0, 1.0), (waist, bulge), (1.0, 0.0))):
        point = base_v + axis * (height * length)
        if scale <= 1e-6:
            rings.append(("pole", len(verts)))
            verts.append(tuple(point))
            continue
        ring = []
        for i in range(sides):
            theta = 2.0 * math.pi * i / sides + station * 0.22
            offset = axis_u * (math.cos(theta) * radius * scale) + axis_v * (math.sin(theta) * radius * scale * flatten)
            ring.append(len(verts))
            verts.append(tuple(point + offset))
        rings.append(("ring", ring))
    for index in range(len(rings) - 1):
        kind_a, a = rings[index]
        kind_b, b = rings[index + 1]
        if kind_b == "pole":
            for i in range(sides):
                j = (i + 1) % sides
                faces.append((b, a[i], a[j]))
        else:
            for i in range(sides):
                j = (i + 1) % sides
                faces.append((a[i], a[j], b[j], b[i]))
    base_center = len(verts)
    verts.append(tuple(base_v))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((base_center, rings[0][1][j], rings[0][1][i]))
    return verts, faces


def wing_plate(root, span_dir, chord_dir, normal, span_length, chord_length, thickness,
               lobes=3, scallop=0.16, sweep_up=0.0):
    """Thin scalloped membrane swept along span_dir (used for wings and fins)."""
    root_v = Vector(root)
    span = Vector(span_dir).normalized()
    chord = Vector(chord_dir).normalized()
    nrm = Vector(normal).normalized()
    nu, nv = 8, 6
    layers = []
    for sign in (1.0, -1.0):
        grid = []
        for iu in range(nu + 1):
            u = iu / nu
            row = []
            width_scale = 1.0 - 0.55 * u
            for iv in range(nv + 1):
                v = iv / nv
                wave = scallop * math.sin(math.pi * lobes * u) * (v ** 3)
                along = (v - 0.5) * chord_length * width_scale - wave * chord_length * 0.5
                point = (root_v + span * (u * span_length) + chord * along
                         + nrm * (sign * thickness * 0.5)
                         + Vector((0.0, 0.0, sweep_up * u * u)))
                row.append(tuple(point))
            grid.append(row)
        layers.append(grid)
    verts, faces = [], []
    index = {}
    for layer_index, grid in enumerate(layers):
        for iu in range(nu + 1):
            for iv in range(nv + 1):
                index[(layer_index, iu, iv)] = len(verts)
                verts.append(grid[iu][iv])
    for iu in range(nu):
        for iv in range(nv):
            a = index[(0, iu, iv)]
            b = index[(0, iu + 1, iv)]
            c = index[(0, iu + 1, iv + 1)]
            d = index[(0, iu, iv + 1)]
            faces.append((a, b, c, d))
            a2 = index[(1, iu, iv)]
            b2 = index[(1, iu + 1, iv)]
            c2 = index[(1, iu + 1, iv + 1)]
            d2 = index[(1, iu, iv + 1)]
            faces.append((a2, d2, c2, b2))
    border = [(iu, 0) for iu in range(nu)] + [(nu, iv) for iv in range(nv)]
    border += [(iu, nv) for iu in range(nu, 0, -1)] + [(0, iv) for iv in range(nv, 0, -1)]
    for position in range(len(border)):
        iu, iv = border[position]
        iu2, iv2 = border[(position + 1) % len(border)]
        faces.append((index[(0, iu, iv)], index[(0, iu2, iv2)], index[(1, iu2, iv2)], index[(1, iu, iv)]))

    # Leading-edge rib so the membrane reads as a wing, not a paper sliver.
    rib_points = [Vector(layers[0][iu][0]) for iu in range(nu + 1)]
    rib_radii = [thickness * (1.45 - 0.85 * (iu / nu)) for iu in range(nu + 1)]
    rib_verts, rib_faces = sweep(rib_points, rib_radii, segments=7, caps=True)
    offset = len(verts)
    verts.extend(rib_verts)
    faces.extend(tuple(item + offset for item in face) for face in rib_faces)
    return verts, faces


def torus(major_radius, tube_radius, center=(0.0, 0.0, 0.0), segments=44, tube_segments=8,
          tilt_x=0.0, tilt_y=0.0):
    cx, cy, cz = center
    cos_x, sin_x = math.cos(tilt_x), math.sin(tilt_x)
    cos_y, sin_y = math.cos(tilt_y), math.sin(tilt_y)
    verts, faces = [], []
    rings = []
    for i in range(segments):
        theta = 2.0 * math.pi * i / segments
        local = Vector((major_radius * math.cos(theta), major_radius * math.sin(theta), 0.0))
        local = Vector((local.x, local.y * cos_x - local.z * sin_x, local.y * sin_x + local.z * cos_x))
        local = Vector((local.x * cos_y + local.z * sin_y, local.y, -local.x * sin_y + local.z * cos_y))
        ring_center = local
        outward = Vector((math.cos(theta) * cos_y, math.sin(theta) * cos_x, math.sin(theta) * sin_x))
        ring = []
        for j in range(tube_segments):
            phi = 2.0 * math.pi * j / tube_segments
            offset = outward * (math.cos(phi) * tube_radius) + Vector((0.0, 0.0, 1.0)) * (
                math.sin(phi) * tube_radius)
            ring.append(len(verts))
            verts.append((cx + ring_center.x + offset.x, cy + ring_center.y + offset.y, cz + ring_center.z + offset.z))
        rings.append(ring)
    for i in range(segments):
        a, b = rings[i], rings[(i + 1) % segments]
        for j in range(tube_segments):
            k = (j + 1) % tube_segments
            faces.append((a[j], a[k], b[k], b[j]))
    return verts, faces


# =============================================================================
# Blender scene helpers
# =============================================================================

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    # No .blend1 backups: the pack is regenerated in place.
    try:
        bpy.context.preferences.filepaths.save_version = 0
    except Exception:
        pass
    return scene


def make_role_material(role, palette):
    material = bpy.data.materials.new(f"SLIME_role_{role}")
    material.use_nodes = True
    colour = hex_to_rgb(palette.get("eye", "#101010"))
    if role == "skin":
        colour = hex_to_rgb(palette["bottom"])
    elif role == "glint":
        colour = hex_to_rgb(palette["glint"])
    elif role == "mouth":
        colour = np.array([0.05, 0.03, 0.07])
    elif role == "cheek":
        colour = hex_to_rgb(palette["cheek"])
    elif role == "accent":
        colour = hex_to_rgb(palette["accent"])
    elif role == "accentDeep":
        colour = hex_to_rgb(palette["accentDeep"])
    elif role == "core":
        colour = hex_to_rgb(palette["core"])
    material.diffuse_color = (*colour, 1.0)
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.35
    return material


def create_object(name, mesh_data, material, collection):
    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata([tuple(v) for v in mesh_data.verts], [], mesh_data.faces)
    mesh.validate(verbose=False)
    bmesh_fix_normals(mesh)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    mesh.materials.append(material)
    for polygon in mesh.polygons:
        polygon.use_smooth = mesh_data.smooth
    return obj


def bmesh_fix_normals(mesh):
    """Each part is a closed shell, so its outward orientation is unambiguous here.

    Recalculating after joining would be ambiguous because the face shells sit inside
    the body shell; Blender then flips whole bands of the body inward.
    """
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()


def join_objects(objects, name):
    if len(objects) == 1:
        joined = objects[0]
        joined.name = name
        joined.data.name = f"{name}_mesh"
        return joined
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    joined.data.name = f"{name}_mesh"
    return joined


def recenter_and_ground(obj):
    """Translate the mesh so min Z = 0 and XY are centred; the pivot stays at the origin."""
    mesh = obj.data
    coords = np.array([tuple(v.co) for v in mesh.vertices], dtype=np.float64)
    minimum = coords.min(axis=0)
    maximum = coords.max(axis=0)
    shift = np.array([(minimum[0] + maximum[0]) * 0.5, (minimum[1] + maximum[1]) * 0.5, minimum[2]])
    for vertex in mesh.vertices:
        vertex.co = Vector((vertex.co.x - shift[0], vertex.co.y - shift[1], vertex.co.z - shift[2]))
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    mesh.update()
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return shift


def uv_unwrap(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.008, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    layer = obj.data.uv_layers.active
    coords = np.empty((len(layer.data), 2), dtype=np.float64)
    layer.data.foreach_get("uv", coords.ravel())
    low = coords.min(axis=0)
    high = coords.max(axis=0)
    span = max(float(high[0] - low[0]), float(high[1] - low[1]), 1e-6)
    scale = 0.98 / span
    baked = (coords - low) * scale + 0.01
    layer.data.foreach_set("uv", baked.ravel())
    obj.data.update()
    return {"minU": float(baked[:, 0].min()), "maxU": float(baked[:, 0].max()),
            "minV": float(baked[:, 1].min()), "maxV": float(baked[:, 1].max())}


# =============================================================================
# Procedural texture painting (UV-space rasteriser)
# =============================================================================

def role_index_map(mesh):
    mapping = {}
    for index, material in enumerate(mesh.materials):
        name = material.name.replace("SLIME_role_", "")
        mapping[index] = ROLES.index(name) if name in ROLES else 0
    return mapping


def paint_surface(points, normals, roles, spec, zmin, zmax, seed):
    count = points.shape[0]
    palette = spec["palette"]
    surface = spec["surface"]
    height = max(zmax - zmin, 1e-6)
    t = np.clip((points[:, 2] - zmin) / height, 0.0, 1.0)

    bottom = hex_to_rgb(palette["bottom"])
    top = hex_to_rgb(palette["top"])
    spot_colour = hex_to_rgb(palette["spot"])
    belly_colour = hex_to_rgb(palette["belly"])
    accent = hex_to_rgb(palette["accent"])
    accent_deep = hex_to_rgb(palette["accentDeep"])
    eye_colour = hex_to_rgb(palette["eye"])
    glint_colour = hex_to_rgb(palette["glint"])
    cheek_colour = hex_to_rgb(palette["cheek"])
    core_colour = hex_to_rgb(palette["core"])

    ramp = smoothstep(np.clip(t * 1.14 - 0.07, 0.0, 1.0))[:, None]
    colour = bottom[None, :] * (1.0 - ramp) + top[None, :] * ramp

    # Soft cartoon sheen: one restrained highlight, never a hard-edged patch.
    light = np.array([0.42, -0.78, 0.46])
    light = light / np.linalg.norm(light)
    facing = np.clip(normals @ light, 0.0, 1.0) ** 3.0
    sheen = (facing * 0.09)[:, None]
    colour = colour * (1.0 - sheen) + np.array([1.0, 1.0, 1.0])[None, :] * sheen

    # Round, spaced jelly bubbles. Cell-based so every bubble stays a closed disc
    # instead of the old blotchy fbm camouflage.
    bubble = bubble_mask(points, 1.6 / max(surface["spotScale"], 1e-3), seed)
    bubble = (bubble * surface["spotStrength"])[:, None]
    colour = colour * (1.0 - bubble) + spot_colour[None, :] * bubble

    front = (np.clip(-normals[:, 1], 0.0, 1.0) * np.clip((0.52 - t) / 0.52, 0.0, 1.0))[:, None]
    colour = colour * (1.0 - front * 0.34) + belly_colour[None, :] * front * 0.34

    form = np.clip(1.0 + surface["rim"] * normals[:, 1] * 0.55, 0.72, 1.18)[:, None]
    colour = colour * form

    roughness_noise = fbm(points * 9.0 + 3.1, seed + 31)
    roughness = np.full(count, surface["roughness"], dtype=np.float64)
    roughness += (roughness_noise - 0.5) * 2.0 * surface["roughnessVar"]

    def apply(role_name, value, roughness_value, strength=1.0):
        mask = roles == ROLES.index(role_name)
        if not np.any(mask):
            return
        colour[mask] = colour[mask] * (1.0 - strength) + value[None, :] * strength
        roughness[mask] = roughness_value

    apply("eye", eye_colour, 0.06)
    apply("glint", glint_colour, 0.04)
    apply("mouth", np.array([0.04, 0.02, 0.06]), 0.32)
    apply("cheek", cheek_colour, 0.42, 0.92)
    apply("core", core_colour, 0.05)

    glow = surface.get("coreGlow")
    if glow:
        centre = np.array(glow["center"], dtype=np.float64)
        radius = max(float(glow["radius"]), 1e-6)
        strength = float(glow["strength"])
        distance = np.linalg.norm(points - centre[None, :], axis=1) / radius
        mask = (smoothstep(np.clip(1.0 - distance, 0.0, 1.0)) * strength)[:, None]
        colour = colour * (1.0 - mask) + core_colour[None, :] * mask

    accent_mask = roles == ROLES.index("accent")
    if np.any(accent_mask):
        mix_t = 0.42 + 0.58 * smoothstep(t[accent_mask])[:, None]
        value = accent_deep[None, :] * (1.0 - mix_t) + accent[None, :] * mix_t
        colour[accent_mask] = value
        roughness[accent_mask] = 0.1
    deep_mask = roles == ROLES.index("accentDeep")
    if np.any(deep_mask):
        rock = fbm(points[deep_mask] * 7.0, seed + 13)[:, None]
        colour[deep_mask] = accent_deep[None, :] * (0.82 + rock * 0.36)
        roughness[deep_mask] = 0.5

    return np.clip(colour, 0.0, 1.0), np.clip(roughness, 0.03, 1.0)


def rasterize_textures(obj, spec, seed, out_dir):
    mesh = obj.data
    mesh.calc_loop_triangles()
    size = int(spec["textureSize"])
    layer = mesh.uv_layers.active
    uv = np.empty((len(layer.data), 2), dtype=np.float64)
    layer.data.foreach_get("uv", uv.ravel())
    coords = np.empty((len(mesh.vertices), 3), dtype=np.float64)
    mesh.vertices.foreach_get("co", coords.ravel())
    try:
        normals = np.empty((len(mesh.vertices), 3), dtype=np.float64)
        mesh.vertex_normals.foreach_get("vector", normals.ravel())
    except Exception:
        normals = np.empty((len(mesh.vertices), 3), dtype=np.float64)
        mesh.vertices.foreach_get("normal", normals.ravel())

    zmin = float(coords[:, 2].min())
    zmax = float(coords[:, 2].max())
    role_by_material = role_index_map(mesh)
    role_by_polygon = np.zeros(len(mesh.polygons), dtype=np.int32)
    for polygon in mesh.polygons:
        role_by_polygon[polygon.index] = role_by_material.get(polygon.material_index, 0)

    colour_sum = np.zeros((size, size, 3), dtype=np.float64)
    rough_sum = np.zeros((size, size), dtype=np.float64)
    weight_sum = np.zeros((size, size), dtype=np.float64)

    for tri in mesh.loop_triangles:
        loop_uv = uv[list(tri.loops)]
        if loop_uv.shape != (3, 2):
            continue
        px = loop_uv[:, 0] * size
        py = loop_uv[:, 1] * size
        min_x = max(int(math.floor(px.min())) - 1, 0)
        max_x = min(int(math.ceil(px.max())) + 1, size - 1)
        min_y = max(int(math.floor(py.min())) - 1, 0)
        max_y = min(int(math.ceil(py.max())) + 1, size - 1)
        if max_x <= min_x or max_y <= min_y:
            continue
        xs = np.arange(min_x, max_x + 1, dtype=np.float64) + 0.5
        ys = np.arange(min_y, max_y + 1, dtype=np.float64) + 0.5
        grid_x, grid_y = np.meshgrid(xs, ys)
        denominator = (py[1] - py[2]) * (px[0] - px[2]) + (px[2] - px[1]) * (py[0] - py[2])
        if abs(denominator) < 1e-12:
            continue
        w0 = ((py[1] - py[2]) * (grid_x - px[2]) + (px[2] - px[1]) * (grid_y - py[2])) / denominator
        w1 = ((py[2] - py[0]) * (grid_x - px[2]) + (px[0] - px[2]) * (grid_y - py[2])) / denominator
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not np.any(inside):
            continue
        row0, col0 = min_y, min_x
        local = np.nonzero(inside)
        rows = local[0] + row0
        cols = local[1] + col0
        a = w0[local][:, None]
        b = w1[local][:, None]
        c = w2[local][:, None]
        vertices = list(tri.vertices)
        positions = (a * coords[vertices[0]][None, :] + b * coords[vertices[1]][None, :]
                     + c * coords[vertices[2]][None, :])
        vertex_normals = (a * normals[vertices[0]][None, :] + b * normals[vertices[1]][None, :]
                          + c * normals[vertices[2]][None, :])
        lengths = np.linalg.norm(vertex_normals, axis=1, keepdims=True)
        vertex_normals = vertex_normals / np.maximum(lengths, 1e-9)
        role = np.full(positions.shape[0], role_by_polygon[tri.polygon_index], dtype=np.int32)
        colour, rough = paint_surface(positions, vertex_normals, role, spec, zmin, zmax, seed)
        colour_sum[rows, cols] += colour
        rough_sum[rows, cols] += rough
        weight_sum[rows, cols] += 1.0

    filled = weight_sum > 0
    divisor = np.maximum(weight_sum, 1.0)[:, :, None]
    colour_map = colour_sum / divisor
    rough_map = rough_sum / np.maximum(weight_sum, 1.0)

    for _ in range(3):
        pad_colour = np.pad(colour_map, ((1, 1), (1, 1), (0, 0)), mode="edge")
        pad_rough = np.pad(rough_map, ((1, 1), (1, 1)), mode="edge")
        pad_mask = np.pad(filled, ((1, 1), (1, 1)), mode="edge").astype(np.float64)
        neighbour_colour = np.zeros_like(colour_map)
        neighbour_rough = np.zeros_like(rough_map)
        neighbour_count = np.zeros_like(weight_sum)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                neighbour_colour += pad_colour[1 + dy:1 + dy + size, 1 + dx:1 + dx + size]
                neighbour_rough += pad_rough[1 + dy:1 + dy + size, 1 + dx:1 + dx + size]
                neighbour_count += pad_mask[1 + dy:1 + dy + size, 1 + dx:1 + dx + size]
        bleed = (~filled) & (neighbour_count > 0)
        colour_map[bleed] = neighbour_colour[bleed] / neighbour_count[bleed][:, None]
        rough_map[bleed] = neighbour_rough[bleed] / neighbour_count[bleed]
        filled = filled | bleed

    coverage = float(filled.mean())
    colour_path = os.path.join(out_dir, f"{spec['slug']}_color.png")
    rough_path = os.path.join(out_dir, f"{spec['slug']}_roughness.png")
    roundtrip = _write_image(colour_path, colour_map, size, srgb=True, key="Color")
    _write_image(rough_path, rough_map[:, :, None], size, srgb=False, key="Roughness")
    return colour_path, rough_path, coverage, roundtrip


def _write_image(filepath, array, size, srgb, key):
    image = bpy.data.images.new(f"SLIME_{key}_{os.path.basename(filepath)}", size, size, alpha=False)
    image.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    rgb = np.clip(array[:, :, :3], 0.0, 1.0)
    if rgb.shape[2] == 1:
        rgb = np.repeat(rgb, 3, axis=2)
    if srgb:
        stored = srgb_to_linear(rgb)
    else:
        stored = rgb
    pixels = np.concatenate([stored, np.ones((size, size, 1))], axis=2).astype(np.float32)
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = filepath
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)

    check = bpy.data.images.load(filepath, check_existing=False)
    sample = np.empty(len(check.pixels), dtype=np.float32)
    check.pixels.foreach_get(sample)
    sample = sample.reshape((size, size, 4))[:, :, :3]
    if srgb:
        recovered = linear_to_srgb(sample)
        error = float(np.abs(recovered - rgb).max())
    else:
        error = float(np.abs(sample - rgb).max())
    bpy.data.images.remove(check)
    return error


def build_material(spec, colour_path, rough_path):
    material = bpy.data.materials.new(f"SLIME_{spec['slug']}_skin")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    colour_node = nodes.new("ShaderNodeTexImage")
    colour_node.image = bpy.data.images.load(colour_path, check_existing=True)
    colour_node.image.colorspace_settings.name = "sRGB"
    colour_node.location = (-520, 240)
    rough_node = nodes.new("ShaderNodeTexImage")
    rough_node.image = bpy.data.images.load(rough_path, check_existing=True)
    rough_node.image.colorspace_settings.name = "Non-Color"
    rough_node.location = (-520, -60)
    links.new(colour_node.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(rough_node.outputs["Color"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.0
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = 0.0
    material.diffuse_color = (0.3, 0.7, 1.0, 1.0)
    return material


def pack_material_images(material):
    """Embed the texture files in the .blend so the scene opens without its source PNGs."""
    packed = []
    for node in material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None:
            image = node.image
            if image.packed_file is None:
                image.pack()
            packed.append({
                "name": image.name,
                "packed": image.packed_file is not None,
                "size": int(image.size[0]),
            })
    return packed


def apply_single_material(obj, material):
    mesh = obj.data
    mesh.materials.clear()
    mesh.materials.append(material)
    for polygon in mesh.polygons:
        polygon.material_index = 0
    mesh.update()


# =============================================================================
# Face features
# =============================================================================

def surface_hit(obj, probe, direction=None):
    """Ray-cast onto the part surface.

    A nearest-point search from a distant probe slides toward the widest part of the
    body, so the face features would drift. A ray along the probe direction lands where
    the face actually is.
    """
    origin = Vector(probe)
    ray = Vector(direction) if direction is not None else Vector((0.0, 1.0, 0.0))
    ray.normalize()
    ok, location, normal, _ = obj.ray_cast(origin, ray, distance=60.0)
    if not ok:
        return origin, Vector((0.0, -1.0, 0.0))
    normal = normal.normalized()
    if normal.dot(ray) > 0.0:
        normal = -normal
    return location, normal


def add_eye_parts(parts, obj, probe, radius, palette, squash=0.62):
    location, normal = surface_hit(obj, probe)
    center = location + normal * (radius * 0.12)
    verts, faces = superellipsoid(radius, radius * squash, radius * 1.04, center=tuple(center),
                                  nu=18, nv=12, e=2.05)
    aligned = _orient_around(verts, center, normal)
    parts.append((MeshData("eye").add(aligned, faces), None))

    right = normal.cross(Vector((0.0, 0.0, 1.0)))
    if right.length < 1e-4:
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    up = right.cross(normal).normalized()
    for (dx, dz, scale) in ((0.34, 0.38, 0.38), (-0.26, 0.52, 0.22)):
        glint_center = center + normal * (radius * 0.5) + right * (radius * dx) + up * (radius * dz)
        gv, gf = superellipsoid(radius * scale, radius * scale * 0.6, radius * scale, center=tuple(glint_center),
                                nu=12, nv=8, e=2.0)
        parts.append((MeshData("glint").add(_orient_around(gv, glint_center, normal), gf), None))
    return location, normal


def _surface_frame(normal):
    """Stable orthonormal frame: local +Y follows the normal, +Z stays as vertical as possible."""
    forward = Vector(normal).normalized()
    hint = Vector((0.0, 0.0, 1.0))
    if abs(forward.dot(hint)) > 0.98:
        hint = Vector((0.0, 1.0, 0.0))
    right = hint.cross(forward)
    if right.length < 1e-6:
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    up = forward.cross(right).normalized()
    return Matrix(((right.x, forward.x, up.x),
                   (right.y, forward.y, up.y),
                   (right.z, forward.z, up.z)))


def _orient_around(verts, center, normal):
    frame = _surface_frame(normal)
    pivot = Vector(center)
    return [tuple(frame @ (Vector(vertex) - pivot) + pivot) for vertex in verts]


def add_mouth_parts(parts, obj, probe, style, width):
    location, normal = surface_hit(obj, probe)
    right = normal.cross(Vector((0.0, 0.0, 1.0)))
    if right.length < 1e-4:
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    up = right.cross(normal).normalized()
    if style == "open":
        center = location + normal * (width * 0.06)
        ov, of = superellipsoid(width * 0.95, width * 0.26, width * 0.34, center=tuple(center),
                                nu=18, nv=10, e=2.2)
        parts.append((MeshData("mouth").add(_orient_around(ov, center, normal), of), None))
        return
    points, radii = [], []
    for index in range(9):
        u = index / 8.0
        angle = (u - 0.5) * math.pi * 0.86
        bend = 0.55 if style == "smile" else -0.55
        along = right * (math.sin(angle) * width)
        vertical = up * (-bend * (math.cos(angle) - 0.62) * width * 0.5)
        contact, contact_normal = surface_hit(obj, tuple(location + along + vertical + normal * 0.6), direction=-normal)
        points.append(tuple(contact + contact_normal * (width * 0.05)))
        radii.append(width * 0.17 * (1.0 - abs(u - 0.5) * 1.4) + width * 0.05)
    mv, mf = sweep(points, radii, segments=8, caps=True)
    parts.append((MeshData("mouth").add(mv, mf), None))


def add_cheek_parts(parts, obj, probe, radius):
    location, normal = surface_hit(obj, probe)
    center = location + normal * (radius * 0.05)
    cv, cf = superellipsoid(radius, radius * 0.4, radius * 0.85, center=tuple(center), nu=14, nv=10, e=2.1)
    parts.append((MeshData("cheek").add(_orient_around(cv, center, normal), cf), None))


def add_brow_parts(parts, obj, probe, radius, tilt):
    location, normal = surface_hit(obj, probe)
    right = normal.cross(Vector((0.0, 0.0, 1.0)))
    if right.length < 1e-4:
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    up = right.cross(normal).normalized()
    center = location + normal * (radius * 0.18) + up * (radius * 0.95)
    bv, bf = superellipsoid(radius * 0.92, radius * 0.22, radius * 0.22, center=(0.0, 0.0, 0.0), nu=10, nv=6, e=2.4)
    frame = _surface_frame(normal)
    tilt_rotation = Euler((0.0, math.radians(tilt), 0.0)).to_matrix()
    vertices = []
    for vertex in bv:
        local = tilt_rotation @ Vector(vertex)
        vertices.append(tuple(frame @ local + center))
    parts.append((MeshData("accentDeep", smooth=False).add(vertices, bf), None))


# =============================================================================
# Rigging
# =============================================================================

def build_armature(slug, bones, scale=1.0):
    armature = bpy.data.armatures.new(f"SLIME_{slug}_armature")
    rig = bpy.data.objects.new(f"SLIME_{slug}_rig", armature)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    created = {}
    for (name, head, tail, parent, deform) in bones:
        edit_bone = armature.edit_bones.new(name)
        edit_bone.head = tuple(value * scale for value in head)
        edit_bone.tail = tuple(value * scale for value in tail)
        edit_bone.use_deform = bool(deform)
        if parent:
            edit_bone.parent = created[parent]
            edit_bone.use_connect = False
        created[name] = edit_bone
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def _segment_distance(point, head, tail):
    head_v = Vector(head)
    tail_v = Vector(tail)
    segment = tail_v - head_v
    length_sq = segment.length_squared
    if length_sq < 1e-12:
        return (point - head_v).length
    factor = max(0.0, min(1.0, (point - head_v).dot(segment) / length_sq))
    return (point - (head_v + segment * factor)).length


def assign_weights(obj, rig, bones, radius_map):
    deform = [(name, head, tail) for (name, head, tail, parent, use) in bones if use]
    groups = {name: obj.vertex_groups.new(name=name) for (name, _, _) in deform}
    mesh = obj.data
    max_error = 0.0
    max_influences = 0
    for vertex in mesh.vertices:
        point = vertex.co
        scored = []
        for (name, head, tail) in deform:
            radius = radius_map.get(name, 0.6)
            distance = _segment_distance(point, head, tail)
            scored.append((1.0 / ((distance / radius) + 0.18) ** 4, name))
        scored.sort(reverse=True)
        chosen = scored[:MAX_INFLUENCES]
        total = sum(score for score, _ in chosen)
        if total <= 0.0:
            chosen = [(1.0, scored[0][1])]
            total = 1.0
        error = 0.0
        for score, name in chosen:
            weight = score / total
            error += weight
            groups[name].add([vertex.index], weight, "REPLACE")
        max_error = max(max_error, abs(error - 1.0))
        max_influences = max(max_influences, len(chosen))
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    return max_influences, max_error, len(deform)


def iter_fcurves(action):
    """Yield fcurves across legacy and slotted action layouts."""
    if hasattr(action, "fcurves"):
        try:
            for curve in action.fcurves:
                yield curve
            return
        except Exception:
            pass
    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in getattr(strip, "channelbags", []):
                for curve in channelbag.fcurves:
                    yield curve


# =============================================================================
# Animation authoring
# =============================================================================

def _apply_pose(rig, entries):
    for name, payload in entries.items():
        bone = rig.pose.bones.get(name)
        if bone is None:
            continue
        bone.rotation_mode = "QUATERNION"
        if "location" in payload:
            bone.location = payload["location"]
        if "rotation" in payload:
            bone.rotation_quaternion = Euler(payload["rotation"], "XYZ").to_quaternion()
        if "scale" in payload:
            bone.scale = payload["scale"]


def _key_pose(rig, entries, frame, quaternion_state):
    for name in entries:
        bone = rig.pose.bones.get(name)
        if bone is None:
            continue
        # q and -q are the same rotation; keep consecutive keys on the same hemisphere so
        # interpolation never takes the long way round.
        quaternion = bone.rotation_quaternion.copy()
        quaternion.normalize()
        previous = quaternion_state.get(name)
        if previous is not None and quaternion.dot(previous) < 0.0:
            quaternion = Quaternion((-quaternion.w, -quaternion.x, -quaternion.y, -quaternion.z))
        bone.rotation_quaternion = quaternion
        quaternion_state[name] = quaternion
        bone.keyframe_insert("rotation_quaternion", frame=frame)
        if "location" in entries[name]:
            bone.keyframe_insert("location", frame=frame)
        if "scale" in entries[name]:
            bone.keyframe_insert("scale", frame=frame)


def pose_idle(rig, t, spec, heads, appendages):
    anim = spec["anim"]
    phase = 2.0 * math.pi * t
    bob = math.sin(phase)
    squash = math.sin(phase + math.pi * 0.5)
    entries = {
        "Body": {
            "location": (0.0, 0.0, anim["bob"] * bob * 0.5),
            "scale": (1.0 + anim["squash"] * squash * 0.5, 1.0 + anim["squash"] * squash * 0.5,
                      1.0 - anim["squash"] * squash),
            "rotation": (0.02 * bob, 0.0, 0.02 * math.sin(phase * 2.0)),
        },
    }
    for index, name in enumerate(heads):
        entries[name] = {"rotation": (0.06 * math.sin(phase + index * 0.8), 0.0,
                                      0.05 * math.sin(phase + index * 1.3))}
    for index, name in enumerate(appendages):
        entries[name] = {"rotation": (0.1 * math.sin(phase + index * 0.9), 0.0,
                                      0.08 * math.sin(phase * 2.0 + index * 1.4))}
    _apply_pose(rig, entries)
    return entries


def pose_extract(rig, t, spec, heads, appendages):
    anim = spec["anim"]
    strain = anim["strain"]
    if t < 0.45:
        k = smoothstep(t / 0.45)
        lift = 0.16 * k
        stretch = strain * k
        tremble = 0.0
    elif t < 0.82:
        k = smoothstep((t - 0.45) / 0.37)
        lift = 0.16 + 0.03 * k
        stretch = strain * (1.0 - 0.35 * k)
        tremble = 0.012 * math.sin(t * 210.0)
    else:
        k = smoothstep((t - 0.82) / 0.18)
        lift = 0.16 * (1.0 - k)
        stretch = strain * (1.0 - k)
        tremble = 0.0
    entries = {
        "Body": {
            "location": (0.0, -0.05 * (stretch / max(strain, 1e-6)), lift + tremble),
            "scale": (1.0 - stretch * 0.35, 1.0 - stretch * 0.35, 1.0 + stretch),
            "rotation": (-0.12 * (stretch / max(strain, 1e-6)), 0.0, tremble * 4.0),
        },
    }
    for index, name in enumerate(heads):
        entries[name] = {"rotation": (0.22 * (stretch / max(strain, 1e-6)) + tremble * 3.0, 0.0,
                                      0.06 * math.sin(t * 30.0 + index))}
    for index, name in enumerate(appendages):
        entries[name] = {"rotation": (0.28 * (stretch / max(strain, 1e-6)), 0.0,
                                      0.12 * math.sin(t * 26.0 + index * 1.2))}
    _apply_pose(rig, entries)
    return entries


def pose_release(rig, t, spec, heads, appendages):
    anim = spec["anim"]
    pop = anim["pop"]
    if t < 0.16:
        k = smoothstep(t / 0.16)
        height = pop * k
        wide = 1.0 + 0.16 * k
        tall = 1.0 + 0.1 * k
    elif t < 0.34:
        k = smoothstep((t - 0.16) / 0.18)
        height = pop * (1.0 - k)
        wide = 1.16 - 0.28 * k
        tall = 1.1 - 0.28 * k
    else:
        k = (t - 0.34) / 0.66
        decay = math.exp(-4.2 * k) * math.sin(k * math.pi * 2.6)
        height = 0.06 * decay
        wide = 1.0 + 0.06 * decay
        tall = 1.0 - 0.1 * decay
    entries = {
        "Body": {
            "location": (0.0, 0.0, height),
            "scale": (wide, wide, tall),
            "rotation": (0.08 * math.exp(-5.0 * t) * math.sin(t * 22.0), 0.0, 0.0),
        },
    }
    lift = height / max(pop, 1e-6)
    for index, name in enumerate(heads):
        entries[name] = {"rotation": (-0.24 * lift, 0.0, 0.1 * lift * (1 if index % 2 == 0 else -1))}
    for index, name in enumerate(appendages):
        entries[name] = {"rotation": (-0.3 * lift, 0.0, 0.16 * lift * (1 if index % 2 == 0 else -1))}
    _apply_pose(rig, entries)
    return entries


def author_clips(rig, spec, heads, appendages):
    scene = bpy.context.scene
    rig.animation_data_create()
    clips = []
    for name, pose_fn, length, looping in (
        ("Idle", pose_idle, int(spec["clips"]["idle"]), True),
        ("Extract", pose_extract, int(spec["clips"]["extract"]), False),
        ("Release", pose_release, int(spec["clips"]["release"]), False),
    ):
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        total = length + 1 if looping else length
        step = 4
        frames = sorted(set([1] + list(range(1 + step, total, step)) + [total]))
        quaternion_state = {}
        for frame in frames:
            t = (frame - 1) / float(length) if looping else (frame - 1) / float(max(total - 1, 1))
            entries = pose_fn(rig, t, spec, heads, appendages)
            _key_pose(rig, entries, frame, quaternion_state)
        action.use_frame_range = True
        action.frame_start = 1.0
        action.frame_end = float(total)
        for curve in iter_fcurves(action):
            for key in curve.keyframe_points:
                key.interpolation = "BEZIER"
        loop_error = 0.0
        if looping:
            loop_error = measure_loop_error(rig, action, 1, total)
        clips.append({
            "name": name,
            "frames": total,
            "durationSeconds": round((total - 1) / float(FPS), 4),
            "channels": sum(1 for _ in iter_fcurves(action)),
            "loopError": loop_error,
            "action": action,
        })
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 1, action)
        strip.name = name
        rig.animation_data.action = None
    scene.frame_start = 1
    scene.frame_end = 1
    return clips


def measure_loop_error(rig, action, first, last):
    """Compare the keyed curve values at the loop endpoints.

    This reads the authored animation directly instead of re-evaluating the depsgraph,
    which can serve a stale pose matrix in background mode.
    """
    error = 0.0
    worst = None
    for curve in iter_fcurves(action):
        delta = abs(curve.evaluate(first) - curve.evaluate(last))
        if delta > error:
            error = delta
            worst = curve.data_path
    if worst is not None and error > 1e-4:
        print(f"[SLIME] loop mismatch on {worst}: {error:.6f}")
    return error


# =============================================================================
# Render, export and stats
# =============================================================================

def setup_render_scene(spec):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 32
    except Exception:
        pass
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("SLIME_world")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background:
        background.inputs["Color"].default_value = (0.72, 0.78, 0.85, 1.0)
        background.inputs["Strength"].default_value = 1.1
    scene.world = world

    ground_material = bpy.data.materials.new("SLIME_ground")
    ground_material.use_nodes = True
    ground_bsdf = ground_material.node_tree.nodes.get("Principled BSDF")
    if ground_bsdf:
        ground_bsdf.inputs["Base Color"].default_value = (0.62, 0.68, 0.74, 1.0)
        ground_bsdf.inputs["Roughness"].default_value = 0.85
    bpy.ops.mesh.primitive_plane_add(size=60.0, location=(0.0, 0.0, -0.002))
    ground = bpy.context.object
    ground.name = "SLIME_ground"
    ground.data.materials.append(ground_material)

    for name, location, energy, size in (
        ("key", (6.0, -7.0, 9.0), 900.0, 6.0),
        ("fill", (-7.0, -4.0, 5.0), 320.0, 7.0),
        ("rim", (-2.0, 8.0, 8.0), 500.0, 5.0),
    ):
        light_data = bpy.data.lights.new(f"SLIME_{name}", "AREA")
        light_data.energy = energy
        light_data.size = size
        light = bpy.data.objects.new(f"SLIME_{name}", light_data)
        bpy.context.scene.collection.objects.link(light)
        light.location = location
        direction = Vector((0.0, 0.0, 2.0)) - Vector(location)
        light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    return ground


def render_preview(spec, bounds, path, size):
    scene = bpy.context.scene
    height = bounds["size"][2]
    width = max(bounds["size"][0], bounds["size"][1])
    focus = Vector((0.0, 0.0, height * 0.52))
    distance = max(height, width) * 2.15 + 2.0
    azimuth = math.radians(float(spec.get("cameraAzimuth", 32)))
    elevation = math.radians(13.0)
    location = focus + Vector((math.sin(azimuth) * math.cos(elevation),
                               -math.cos(azimuth) * math.cos(elevation),
                               math.sin(elevation))) * distance
    camera_data = bpy.data.cameras.new("SLIME_camera")
    camera_data.lens = 62.0
    camera = bpy.data.objects.new("SLIME_camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = location
    camera.rotation_euler = (focus - location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def render_silhouette(spec, path, size):
    scene = bpy.context.scene
    black = bpy.data.materials.new("SLIME_silhouette")
    black.use_nodes = True
    nodes = black.node_tree.nodes
    for node in list(nodes):
        if node.type != "OUTPUT_MATERIAL":
            nodes.remove(node)
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    emission.inputs["Strength"].default_value = 0.0
    nodes.active = emission
    output = nodes.get("Material Output")
    black.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    target = bpy.data.objects.get(spec["slug"])
    if target is not None:
        target.data.materials.clear()
        target.data.materials.append(black)
        for polygon in target.data.polygons:
            polygon.material_index = 0
    ground = bpy.data.objects.get("SLIME_ground")
    if ground is not None:
        ground.hide_render = True
    world = scene.world
    if world and world.use_nodes:
        background = world.node_tree.nodes.get("Background")
        if background:
            background.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
            background.inputs["Strength"].default_value = 1.0
    for name in ("key", "fill", "rim"):
        light = bpy.data.objects.get(f"SLIME_{name}")
        if light is not None:
            light.hide_render = True
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def export_glb(obj, rig, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    properties = bpy.ops.export_scene.gltf.get_rna_type().properties
    requested = {
        "filepath": path,
        "export_format": "GLB",
        "use_selection": True,
        "export_apply": True,
        "export_yup": True,
        "export_texcoords": True,
        "export_normals": True,
        "export_skins": True,
        "export_animations": True,
        "export_animation_mode": "ACTIONS",
        "export_force_sampling": True,
        "export_frame_range": False,
        "export_anim_slide_to_zero": True,
        "export_influence_nb": MAX_INFLUENCES,
        "export_all_influences": False,
        "export_vertex_color": "NONE",
        "export_image_format": "AUTO",
        "export_materials": "EXPORT",
        "export_extras": False,
    }
    unknown = [key for key in requested if key != "filepath" and key not in properties]
    if unknown:
        raise RuntimeError(f"unsupported glTF export options in this Blender build: {unknown}")
    bpy.ops.export_scene.gltf(**requested)
    return path


def normalize_glb_rotation_tracks(path):
    """Force every exported rotation track onto one quaternion hemisphere.

    Blender's glTF exporter converts each sampled pose matrix independently, so q and -q
    can alternate between neighbouring samples even when the authored keys are aligned.
    Both encode the same rotation, but a player interpolating them takes the long way.
    Rewriting the sign in place keeps the data identical apart from that convention.
    """
    with open(path, "rb") as handle:
        blob = bytearray(handle.read())
    json_length = struct.unpack_from("<I", blob, 12)[0]
    document = json.loads(bytes(blob[20:20 + json_length]).decode("utf-8"))
    bin_header = 20 + json_length
    bin_length, bin_magic = struct.unpack_from("<II", blob, bin_header)
    if bin_magic != 0x004E4942:
        raise RuntimeError("exported GLB has no BIN chunk to normalise")
    bin_start = bin_header + 8
    flipped = 0
    minimum_dot = 1.0
    for animation in document.get("animations", []):
        for channel in animation.get("channels", []):
            if channel.get("target", {}).get("path") != "rotation":
                continue
            accessor = document["accessors"][animation["samplers"][channel["sampler"]]["output"]]
            if accessor.get("componentType") != 5126 or accessor.get("type") != "VEC4":
                continue
            view = document["bufferViews"][accessor["bufferView"]]
            base = bin_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride") or 16
            previous = None
            for index in range(accessor["count"]):
                offset = base + index * stride
                values = list(struct.unpack_from("<4f", blob, offset))
                length = math.sqrt(sum(value * value for value in values)) or 1.0
                values = [value / length for value in values]
                if previous is not None:
                    dot = sum(first * second for first, second in zip(previous, values))
                    if dot < 0.0:
                        values = [-value for value in values]
                        struct.pack_into("<4f", blob, offset, *values)
                        flipped += 1
                        dot = -dot
                    minimum_dot = min(minimum_dot, dot)
                else:
                    struct.pack_into("<4f", blob, offset, *values)
                previous = values
    with open(path, "wb") as handle:
        handle.write(blob)
    return {"flippedSamples": flipped, "minimumDot": minimum_dot, "bytes": len(blob)}


def inspect_glb(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    magic, version, total = struct.unpack("<III", blob[:12])
    if magic != 0x46546C67 or version != 2 or total != len(blob):
        raise RuntimeError("exported GLB failed container validation")
    json_length, json_type = struct.unpack("<II", blob[12:20])
    if json_type != 0x4E4F534A:
        raise RuntimeError("exported GLB has no JSON chunk")
    doc = json.loads(blob[20:20 + json_length].decode("utf-8"))
    return {
        "animations": [animation.get("name") for animation in doc.get("animations", [])],
        "animationChannels": [len(animation.get("channels", [])) for animation in doc.get("animations", [])],
        "skins": len(doc.get("skins", [])),
        "joints": len(doc.get("skins", [{}])[0].get("joints", [])) if doc.get("skins") else 0,
        "meshes": len(doc.get("meshes", [])),
        "images": len(doc.get("images", [])),
        "embeddedImages": sum(1 for image in doc.get("images", []) if "bufferView" in image),
        "materials": len(doc.get("materials", [])),
        "primitives": sum(len(mesh.get("primitives", [])) for mesh in doc.get("meshes", [])),
        "vertices": sum(doc["accessors"][primitive["attributes"]["POSITION"]]["count"]
                        for mesh in doc.get("meshes", [])
                        for primitive in mesh.get("primitives", [])),
        "sha256": hashlib.sha256(blob).hexdigest(),
        "bytes": len(blob),
    }


def mesh_bounds(mesh):
    coords = np.empty((len(mesh.vertices), 3), dtype=np.float64)
    mesh.vertices.foreach_get("co", coords.ravel())
    return {
        "min": [float(value) for value in coords.min(axis=0)],
        "max": [float(value) for value in coords.max(axis=0)],
        "size": [float(value) for value in (coords.max(axis=0) - coords.min(axis=0))],
    }


def write_stats(path, payload):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")


# =============================================================================
# Design builders — each returns (parts, bones, radius map, heads, appendages, face)
# =============================================================================

def _eye_anchor(x, z, depth=-6.0):
    return (x, depth, z)


def face_params(spec, default_height, default_half, default_radius):
    """Eye height, half-spacing and radius come from the spec when it declares them."""
    face = spec.get("face", {})
    height = float(face.get("eyeZ") or 0.0) or default_height
    spacing = float(face.get("eyeSpacing") or 0.0)
    half = (spacing * 0.5) if spacing > 0.0 else default_half
    radius = float(face.get("eyeRadius") or 0.0) or default_radius
    return height, half, radius


def build_classic_blue(spec):
    parts = []
    profile = [(0.0, 0.0), (0.78, 0.02), (1.16, 0.16), (1.36, 0.58), (1.38, 1.02),
               (1.3, 1.52), (1.14, 1.98), (0.94, 2.34), (0.68, 2.62), (0.36, 2.8), (0.0, 2.92)]
    verts, faces = lathe(profile, segments=44, warp=lambda theta, z, r: (r * (1.0 + 0.02 * math.cos(theta * 3.0)), z))
    parts.append((MeshData("skin").add(verts, faces), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.08), (0.0, 0.0, 1.45), "Root", True),
        ("Head", (0.0, 0.0, 1.5), (0.0, 0.0, 2.6), "Body", True),
    ]
    z, half, radius = face_params(spec, 1.9, 0.26, 0.2)
    cheek = float(spec["face"].get("cheekRadius") or 0.12)
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.48), "smile", float(spec["face"]["mouthWidth"])),
        "cheeks": [(_eye_anchor(-(half + 0.36), z - 0.28), cheek), (_eye_anchor(half + 0.36, z - 0.28), cheek)],
        "brows": [],
    }
    return parts, bones, {"Body": 1.6, "Head": 1.1}, ["Head"], [], face


def build_mint_droplet(spec):
    parts = []
    puddle, puddle_faces = lathe(
        [(0.0, 0.0), (1.46, 0.0), (1.56, 0.06), (1.5, 0.14), (1.2, 0.2), (0.0, 0.22)],
        segments=46,
        warp=lambda theta, z, r: (r * (1.0 + 0.05 * math.cos(theta * 6.0)), z),
    )
    parts.append((MeshData("skin").add(puddle, puddle_faces), None))
    spine = [(0.0, 0.0, 0.08), (0.0, 0.0, 0.8), (0.02, 0.0, 1.55), (0.12, 0.0, 2.2),
             (0.34, 0.0, 2.75), (0.62, 0.0, 3.12), (0.82, 0.0, 3.3), (0.9, 0.0, 3.36)]
    radii = [0.98, 1.16, 1.05, 0.82, 0.55, 0.34, 0.16, 0.0]
    verts, faces = sweep(spine, radii, segments=36, squash=0.92)
    parts.append((MeshData("skin").add(verts, faces), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.05), (0.0, 0.0, 1.35), "Root", True),
        ("Head", (0.0, 0.0, 1.4), (0.0, 0.0, 2.6), "Body", True),
        ("Tip", (0.34, 0.0, 2.75), (0.9, 0.0, 3.36), "Head", True),
    ]
    z, half, radius = face_params(spec, 1.5, 0.28, 0.18)
    cheek = float(spec["face"].get("cheekRadius") or 0.11)
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.36), "smile", float(spec["face"]["mouthWidth"])),
        "cheeks": [(_eye_anchor(-(half + 0.34), z - 0.2), cheek), (_eye_anchor(half + 0.34, z - 0.2), cheek)],
        "brows": [],
    }
    return parts, bones, {"Body": 1.5, "Head": 1.0, "Tip": 0.5}, ["Head"], ["Tip"], face


def build_gel_cube(spec):
    parts = []
    verts, faces = superellipsoid(1.5, 1.5, 1.7, center=(0.0, 0.0, 1.7), nu=36, nv=26, e=6.0)
    parts.append((MeshData("skin").add(verts, faces), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.1), (0.0, 0.0, 1.6), "Root", True),
        ("Head", (0.0, 0.0, 1.55), (0.0, 0.0, 2.9), "Body", True),
    ]
    z, half, radius = face_params(spec, 1.95, 0.27, 0.19)
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.35), "open", float(spec["face"]["mouthWidth"])),
        "cheeks": [],
        "brows": [],
    }
    return parts, bones, {"Body": 1.7, "Head": 1.2}, ["Head"], [], face


def build_spiral_slime(spec):
    parts = []
    base_v, base_f = superellipsoid(1.02, 0.98, 0.92, center=(0.0, 0.0, 0.92), nu=32, nv=22, e=2.3)
    parts.append((MeshData("skin").add(base_v, base_f), None))
    spine, radii = [], []
    turns = 2.35
    for index in range(45):
        t = index / 44.0
        angle = t * math.tau * turns
        radius = 0.74 * (1.0 - t * 0.78) + 0.14
        spine.append((radius * math.cos(angle), radius * math.sin(angle), 1.18 + t * 2.05))
        radii.append(0.5 * (1.0 - t * 0.72) * (1.0 - t ** 6) + 0.02)
    radii[-1] = 0.0
    helix_v, helix_f = sweep(spine, radii, segments=20)
    parts.append((MeshData("skin").add(helix_v, helix_f), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.05), (0.0, 0.0, 1.2), "Root", True),
        ("Head", (0.0, 0.0, 1.25), (0.0, 0.0, 2.3), "Body", True),
        ("Spiral", (0.0, 0.0, 2.3), (0.0, 0.0, 3.2), "Head", True),
    ]
    z, half, radius = face_params(spec, 1.05, 0.24, 0.17)
    cheek = float(spec["face"].get("cheekRadius") or 0.1)
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.27), "open", float(spec["face"]["mouthWidth"])),
        "cheeks": [(_eye_anchor(-(half + 0.31), z - 0.15), cheek), (_eye_anchor(half + 0.31, z - 0.15), cheek)],
        "brows": [],
    }
    return parts, bones, {"Body": 1.3, "Head": 0.9, "Spiral": 0.7}, ["Head"], ["Spiral"], face


def build_faceted_crystal(spec):
    parts = []
    verts, faces = geodesic(1.58, subdivisions=2, center=(0.0, 0.0, 1.9), scale=(1.0, 0.94, 1.2), jitter=0.03)
    parts.append((MeshData("skin", smooth=False).add(verts, faces), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.05), (0.0, 0.0, 1.7), "Root", True),
        ("Head", (0.0, 0.0, 1.75), (0.0, 0.0, 3.2), "Body", True),
    ]
    z, half, radius = face_params(spec, 2.05, 0.31, 0.32)
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.5), "open", float(spec["face"]["mouthWidth"])),
        "cheeks": [],
        "brows": [],
    }
    return parts, bones, {"Body": 1.7, "Head": 1.25}, ["Head"], [], face


def build_jellyfish_slime(spec):
    parts = []
    profile = [(1.5, 1.52), (1.62, 1.78), (1.6, 2.15), (1.44, 2.62), (1.16, 3.08),
               (0.84, 3.48), (0.5, 3.78), (0.22, 3.94), (0.0, 4.0)]
    bell_v, bell_f = lathe(
        profile,
        segments=46,
        warp=lambda theta, z, r: (r * (1.0 + 0.055 * math.cos(theta * 8.0) * clamp01((2.05 - z) / 0.6)), z),
    )
    parts.append((MeshData("skin").add(bell_v, bell_f), None))
    tentacles = []
    for index in range(6):
        angle = math.tau * index / 6.0
        start = (1.5 * math.cos(angle), 1.5 * math.sin(angle), 1.62)
        points = [start]
        radii = [0.17]
        for step in range(1, 9):
            t = step / 8.0
            radial = 1.5 - 0.42 * t + 0.16 * math.sin(t * math.pi * 2.0) * t
            drift = 0.5 * t * t
            points.append((radial * math.cos(angle + drift * 0.6), radial * math.sin(angle + drift * 0.6),
                           1.62 - t * 1.45))
            radii.append(0.17 * (1.0 - t * 0.82) + 0.02)
        radii[-1] = 0.0
        tv, tf = sweep(points, radii, segments=10)
        parts.append((MeshData("skin").add(tv, tf), None))
        tentacles.append(f"Tentacle{index + 1}")
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 1.35), (0.0, 0.0, 2.3), "Root", True),
        ("Head", (0.0, 0.0, 2.35), (0.0, 0.0, 3.9), "Body", True),
    ]
    radius_map = {"Body": 1.5, "Head": 1.3}
    for index in range(6):
        angle = math.tau * index / 6.0
        head = (1.5 * math.cos(angle), 1.5 * math.sin(angle), 1.62)
        tail = (1.3 * math.cos(angle + 0.2), 1.3 * math.sin(angle + 0.2), 0.3)
        bones.append((tentacles[index], head, tail, "Body", True))
        radius_map[tentacles[index]] = 0.34
    z, half, radius = face_params(spec, 2.92, 0.26, 0.19)
    cheek = float(spec["face"].get("cheekRadius") or 0.11)
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.3), "open", float(spec["face"]["mouthWidth"])),
        "cheeks": [(_eye_anchor(-(half + 0.34), z - 0.26), cheek), (_eye_anchor(half + 0.34, z - 0.26), cheek)],
        "brows": [],
    }
    return parts, bones, radius_map, ["Head"], tentacles, face


def build_cosmic_orb(spec):
    parts = []
    body_v, body_f = superellipsoid(1.34, 1.28, 1.42, center=(0.0, 0.0, 1.52), nu=38, nv=26, e=2.15)
    parts.append((MeshData("skin").add(body_v, body_f), None))
    for tilt_x, tilt_y in ((math.radians(20.0), math.radians(-14.0)), (math.radians(-34.0), math.radians(28.0))):
        ring_v, ring_f = torus(1.86, 0.045, center=(0.0, 0.0, 1.62), segments=54, tube_segments=7,
                               tilt_x=tilt_x, tilt_y=tilt_y)
        parts.append((MeshData("accent", smooth=True).add(ring_v, ring_f), None))
    star_positions = []
    for index in range(6):
        angle = math.tau * index / 6.0
        tilt = 20.0 if index % 2 == 0 else -34.0
        x = 1.86 * math.cos(angle)
        y = 1.86 * math.sin(angle) * math.cos(math.radians(tilt))
        z = 1.62 + 1.86 * math.sin(angle) * math.sin(math.radians(tilt))
        star_positions.append((x, y, z))
        sv, sf = superellipsoid(0.1, 0.1, 0.1, center=(x, y, z), nu=10, nv=6, e=1.6)
        parts.append((MeshData("core", smooth=False).add(sv, sf), None))
    core_v, core_f = superellipsoid(0.24, 0.18, 0.24, center=(0.0, -1.3, 1.15), nu=18, nv=12, e=2.0)
    parts.append((MeshData("core").add(core_v, core_f), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.1), (0.0, 0.0, 1.4), "Root", True),
        ("Head", (0.0, 0.0, 1.45), (0.0, 0.0, 2.8), "Body", True),
    ]
    for index in range(6):
        x, y, z = star_positions[index]
        bones.append((f"Orbit{index + 1}", (x, y, z), (x, y, z + 0.18), "Body", True))
    radius_map = {"Body": 1.6, "Head": 1.2}
    for index in range(6):
        radius_map[f"Orbit{index + 1}"] = 0.42
    z, half, radius = face_params(spec, 1.78, 0.28, 0.2)
    cheek = float(spec["face"].get("cheekRadius") or 0.1)
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.28), "open", float(spec["face"]["mouthWidth"])),
        "cheeks": [(_eye_anchor(-(half + 0.34), z - 0.22), cheek), (_eye_anchor(half + 0.34, z - 0.22), cheek)],
        "brows": [],
    }
    return parts, bones, radius_map, ["Head"], [f"Orbit{i + 1}" for i in range(6)], face


def build_tornado_slime(spec):
    parts = []
    profile = [(0.16, 0.0), (0.3, 0.35), (0.26, 0.85), (0.36, 1.4), (0.54, 2.0),
               (0.82, 2.65), (1.2, 3.2), (1.62, 3.7), (1.96, 4.05), (2.08, 4.24),
               (1.92, 4.4), (1.45, 4.5), (0.85, 4.52), (0.0, 4.5)]

    def radius_at(z):
        for index in range(len(profile) - 1):
            low_r, low_z = profile[index]
            high_r, high_z = profile[index + 1]
            if low_z <= z <= high_z:
                span = max(high_z - low_z, 1e-6)
                return low_r + (high_r - low_r) * (z - low_z) / span
        return profile[-1][0]

    def funnel_warp(theta, z, r):
        ridge = 0.14 * math.sin(6.0 * theta + 4.6 * z)
        fade = clamp01((r - 0.2) / 0.5) * clamp01((4.45 - z) / 0.4)
        return (r * (1.0 + ridge * fade), z)

    funnel_v, funnel_f = lathe(profile, segments=54, warp=funnel_warp)
    parts.append((MeshData("skin").add(funnel_v, funnel_f), None))
    # Two ribbons spiral up the funnel: continuous helical flow instead of horizontal hoops.
    for ribbon in range(2):
        points, ribbon_radii = [], []
        for step in range(26):
            t = step / 25.0
            z = 0.7 + t * 3.45
            base = radius_at(z) + 0.025
            angle = ribbon * math.pi + t * math.tau * 1.15
            points.append((base * math.cos(angle), base * math.sin(angle), z))
            ribbon_radii.append(0.09 * (1.0 - 0.35 * t))
        rv, rf = sweep(points, ribbon_radii, segments=8)
        parts.append((MeshData("skin").add(rv, rf), None))
    for index in range(3):
        angle = math.tau * index / 3.0
        points, radii = [], []
        for step in range(5):
            t = step / 4.0
            radial = 0.2 + t * 0.75
            points.append((radial * math.cos(angle + t * 1.1), radial * math.sin(angle + t * 1.1), 0.1 + t * 0.1))
            radii.append(0.09 * (1.0 - t * 0.85))
        radii[-1] = 0.0
        wv, wf = sweep(points, radii, segments=8)
        parts.append((MeshData("skin").add(wv, wf), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.05), (0.0, 0.0, 1.6), "Root", True),
        ("Head", (0.0, 0.0, 1.7), (0.0, 0.0, 3.2), "Body", True),
        ("Crown", (0.0, 0.0, 3.25), (0.0, 0.0, 4.5), "Head", True),
    ]
    z, half, radius = face_params(spec, 2.9, 0.24, 0.19)
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.3), "open", float(spec["face"]["mouthWidth"])),
        "cheeks": [],
        "brows": [],
    }
    return parts, bones, {"Body": 1.4, "Head": 1.1, "Crown": 0.9}, ["Head", "Crown"], [], face


def build_celestial_winged(spec):
    parts = []
    body_v, body_f = superellipsoid(1.32, 1.24, 1.34, center=(0.0, 0.0, 1.58), nu=36, nv=24, e=2.1)
    parts.append((MeshData("skin").add(body_v, body_f), None))
    for (x, y, angle, length, radius) in ((-0.62, 0.1, -26.0, 1.05, 0.2), (0.62, 0.1, 26.0, 1.05, 0.2),
                                          (0.0, 0.5, 0.0, 1.35, 0.24)):
        direction = Vector((math.sin(math.radians(angle)), 0.32, math.cos(math.radians(angle))))
        sv, sf = shard((x, y, 2.72), tuple(direction), length, radius, sides=5, bulge=1.05)
        parts.append((MeshData("accent", smooth=False).add(sv, sf), None))
    for side in (-1.0, 1.0):
        for index, (angle, length, radius) in enumerate(((-10.0, 1.55, 0.26), (14.0, 1.95, 0.3),
                                                         (38.0, 1.75, 0.26), (60.0, 1.3, 0.2))):
            base = (side * 1.02, 0.18 + index * 0.02, 1.8 + index * 0.1)
            direction = (side * math.cos(math.radians(angle)), 0.18, math.sin(math.radians(angle)))
            sv, sf = shard(base, direction, length, radius, sides=5, flatten=0.42, bulge=1.06)
            parts.append((MeshData("accent", smooth=False).add(sv, sf), None))
    ring_v, ring_f = torus(1.78, 0.05, center=(0.0, 0.0, 1.75), segments=52, tube_segments=7,
                           tilt_x=math.radians(16.0), tilt_y=math.radians(8.0))
    parts.append((MeshData("accent").add(ring_v, ring_f), None))
    for index, angle in enumerate((0.4, 2.5, 4.6)):
        x = 1.78 * math.cos(angle)
        y = 1.78 * math.sin(angle) * math.cos(math.radians(16.0))
        z = 1.75 + 1.78 * math.sin(angle) * math.sin(math.radians(16.0))
        ov, of = superellipsoid(0.09, 0.09, 0.09, center=(x, y, z), nu=10, nv=6, e=1.8)
        parts.append((MeshData("core", smooth=False).add(ov, of), None))
    core_v, core_f = superellipsoid(0.3, 0.2, 0.3, center=(0.0, -1.36, 1.3), nu=18, nv=12, e=2.0)
    parts.append((MeshData("core").add(core_v, core_f), None))
    micro_v, micro_f = torus(0.44, 0.028, center=(0.0, -1.3, 1.3), segments=40, tube_segments=6,
                             tilt_x=math.radians(74.0), tilt_y=math.radians(12.0))
    parts.append((MeshData("accent").add(micro_v, micro_f), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.1), (0.0, 0.0, 1.4), "Root", True),
        ("Head", (0.0, 0.0, 1.45), (0.0, 0.0, 2.7), "Body", True),
        ("Wing.L", (-0.72, 0.18, 1.86), (-2.6, 0.5, 3.3), "Body", True),
        ("Wing.R", (0.72, 0.18, 1.86), (2.6, 0.5, 3.3), "Body", True),
        ("Halo", (-1.78, 0.0, 1.75), (1.78, 0.0, 1.75), "Body", True),
    ]
    z, half, radius = face_params(spec, 2.0, 0.27, 0.21)
    cheek = float(spec["face"].get("cheekRadius") or 0.11)
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.28), "open", float(spec["face"]["mouthWidth"])),
        "cheeks": [(_eye_anchor(-(half + 0.35), z - 0.26), cheek), (_eye_anchor(half + 0.35, z - 0.26), cheek)],
        "brows": [],
    }
    return parts, bones, {"Body": 1.6, "Head": 1.2, "Wing.L": 0.8, "Wing.R": 0.8, "Halo": 1.9}, ["Head"], ["Wing.L", "Wing.R"], face


def build_blob_hydra(spec):
    parts = []
    base_v, base_f = superellipsoid(1.52, 1.2, 0.98, center=(0.0, 0.0, 1.0), nu=34, nv=22, e=2.4)
    parts.append((MeshData("skin").add(base_v, base_f), None))
    heads = []
    necks = []
    layout = [(-0.9, -0.15, 3.3, -0.16), (0.0, 0.05, 4.05, 0.0), (0.9, -0.1, 3.42, 0.16)]
    for index, (x, y, head_z, lean) in enumerate(layout):
        name = ["L", "C", "R"][index]
        points = [
            (x * 0.42, y, 1.55),
            (x * 0.72, y - 0.06, 1.95 + index * 0.04),
            (x * 0.95 + lean, y - 0.16, 2.5 + index * 0.12),
            (x * 1.02 + lean * 1.4, y - 0.22, head_z - 0.38),
        ]
        radii = [0.44, 0.4, 0.35, 0.3]
        nv, nf = sweep(points, radii, segments=14)
        parts.append((MeshData("skin").add(nv, nf), None))
        head_center = (x * 1.04 + lean * 1.5, y - 0.26, head_z)
        hv, hf = superellipsoid(0.62, 0.7, 0.58, center=head_center, nu=22, nv=16, e=2.2)
        parts.append((MeshData("skin").add(hv, hf), None))
        necks.append(f"Neck.{name}")
        heads.append(f"Head.{name}")
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.05), (0.0, 0.0, 1.45), "Root", True),
    ]
    radius_map = {"Body": 1.5}
    for index, (x, y, head_z, lean) in enumerate(layout):
        name = ["L", "C", "R"][index]
        bones.append((f"Neck.{name}", (x * 0.42, y, 1.55), (x * 1.02 + lean * 1.4, y - 0.22, head_z - 0.38), "Body", True))
        bones.append((f"Head.{name}", (x * 1.04 + lean * 1.5, y - 0.26, head_z - 0.2),
                      (x * 1.04 + lean * 1.5, y - 0.26, head_z + 0.5), f"Neck.{name}", True))
        radius_map[f"Neck.{name}"] = 0.45
        radius_map[f"Head.{name}"] = 0.7
    _, _, head_radius = face_params(spec, 0.0, 0.22, 0.12)
    eyes = []
    for index, (x, y, head_z, lean) in enumerate(layout):
        center_x = x * 1.04 + lean * 1.5
        eyes.append(((center_x - 0.22, -6.0, head_z + 0.08), head_radius))
        eyes.append(((center_x + 0.22, -6.0, head_z + 0.08), head_radius))
    mouths = []
    for index, (x, y, head_z, lean) in enumerate(layout):
        center_x = x * 1.04 + lean * 1.5
        mouths.append(((center_x, -6.0, head_z - 0.24), "smile", float(spec["face"]["mouthWidth"])))
    face = {
        "eyes": eyes,
        "mouth": mouths,
        "cheeks": [],
        "brows": [],
    }
    return parts, bones, radius_map, heads, necks, face


def build_crystal_golem(spec):
    parts = []
    torso_v, torso_f = superellipsoid(1.62, 1.28, 1.9, center=(0.0, 0.0, 2.5), nu=34, nv=24, e=2.45)
    parts.append((MeshData("skin").add(torso_v, torso_f), None))
    # The face lives in a fused boss on the upper chest: no separate head above the body.
    boss_v, boss_f = superellipsoid(1.1, 0.7, 1.0, center=(0.0, -0.82, 3.45), nu=28, nv=20, e=2.3)
    parts.append((MeshData("skin").add(boss_v, boss_f), None))
    for (x, y, z, length, radius, tilt) in (
        (-0.62, 0.15, 4.25, 0.8, 0.2, -22.0), (0.0, 0.2, 4.45, 1.0, 0.24, 0.0),
        (0.62, 0.15, 4.25, 0.8, 0.2, 22.0), (-1.12, 0.35, 3.9, 0.62, 0.17, -42.0),
        (1.12, 0.35, 3.9, 0.62, 0.17, 42.0),
    ):
        direction = Vector((math.sin(math.radians(tilt)), 0.25, math.cos(math.radians(tilt))))
        sv, sf = shard((x, y, z), tuple(direction), length, radius, sides=5)
        parts.append((MeshData("accent", smooth=False).add(sv, sf), None))
    for side in (-1.0, 1.0):
        pad_v, pad_f = superellipsoid(0.9, 0.78, 0.62, center=(side * 1.72, 0.0, 3.95), nu=18, nv=12, e=3.6)
        parts.append((MeshData("accentDeep", smooth=False).add(pad_v, pad_f), None))
        for (offset, length, radius, tilt) in ((-0.45, 1.35, 0.26, 62.0), (-0.1, 1.6, 0.3, 34.0),
                                               (0.28, 1.4, 0.26, 10.0), (0.55, 1.0, 0.2, -14.0)):
            direction = Vector((side * math.sin(math.radians(tilt)), 0.1, math.cos(math.radians(tilt))))
            sv, sf = shard((side * (1.72 + offset * 0.5), 0.04, 4.32), tuple(direction), length, radius, sides=5)
            parts.append((MeshData("accent", smooth=False).add(sv, sf), None))
        arm_points = [(side * 1.45, 0.0, 3.7), (side * 2.0, -0.08, 2.85),
                      (side * 2.24, -0.16, 2.0), (side * 2.32, -0.2, 1.55)]
        arm_radii = [0.6, 0.56, 0.5, 0.46]
        av, af = sweep(arm_points, arm_radii, segments=16)
        parts.append((MeshData("skin").add(av, af), None))
        gauntlet_v, gauntlet_f = superellipsoid(0.66, 0.62, 0.52, center=(side * 2.34, -0.2, 1.58), nu=18, nv=12, e=3.2)
        parts.append((MeshData("accentDeep", smooth=False).add(gauntlet_v, gauntlet_f), None))
        for (dx, length) in ((-0.3, 0.7), (0.0, 0.85), (0.3, 0.65)):
            sv, sf = shard((side * 2.34 + dx, -0.45, 1.8), (dx * 1.4, -0.4, 1.0), length, 0.15, sides=5)
            parts.append((MeshData("accent", smooth=False).add(sv, sf), None))
        fist_v, fist_f = superellipsoid(0.8, 0.72, 0.72, center=(side * 2.38, -0.26, 0.92), nu=22, nv=14, e=2.15)
        parts.append((MeshData("accent").add(fist_v, fist_f), None))
        for knuckle in (-0.22, 0.22):
            kv, kf = shard((side * 2.38 + knuckle, -0.9, 0.95), (knuckle * 0.8, -0.7, 0.6), 0.34, 0.11, sides=4)
            parts.append((MeshData("accent", smooth=False).add(kv, kf), None))
        leg_points = [(side * 0.8, 0.0, 2.0), (side * 0.88, 0.0, 1.15), (side * 0.9, -0.02, 0.34)]
        leg_radii = [0.6, 0.56, 0.52]
        lv, lf = sweep(leg_points, leg_radii, segments=16)
        parts.append((MeshData("skin").add(lv, lf), None))
        foot_v, foot_f = superellipsoid(0.66, 0.8, 0.24, center=(side * 0.9, -0.22, 0.24), nu=18, nv=10, e=3.0)
        parts.append((MeshData("skin").add(foot_v, foot_f), None))
        knee_v, knee_f = shard((side * 0.88, -0.46, 1.2), (side * 0.25, -1.0, 0.2), 0.36, 0.15, sides=5)
        parts.append((MeshData("accentDeep", smooth=False).add(knee_v, knee_f), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.1), (0.0, 0.0, 2.6), "Root", True),
        ("Head", (0.0, 0.0, 3.15), (0.0, -0.2, 4.3), "Body", True),
        ("Arm.L", (-1.45, 0.0, 3.7), (-2.34, -0.2, 1.45), "Body", True),
        ("Arm.R", (1.45, 0.0, 3.7), (2.34, -0.2, 1.45), "Body", True),
        ("Leg.L", (-0.8, 0.0, 2.0), (-0.9, -0.02, 0.2), "Body", True),
        ("Leg.R", (0.8, 0.0, 2.0), (0.9, -0.02, 0.2), "Body", True),
    ]
    z, half, radius = face_params(spec, 3.55, 0.3, 0.22)
    brow = float(spec["face"].get("eyeRadius") or 0.22) * 1.05
    face = {
        "eyes": [(_eye_anchor(-half, z), radius), (_eye_anchor(half, z), radius)],
        "mouth": ((0.0, -6.0, z - 0.42), "frown", float(spec["face"]["mouthWidth"])),
        "cheeks": [],
        "brows": [(_eye_anchor(-half, z + 0.24), brow, -24.0), (_eye_anchor(half, z + 0.24), brow, 24.0)],
    }
    return parts, bones, {"Body": 2.1, "Head": 1.25, "Arm.L": 0.8, "Arm.R": 0.8, "Leg.L": 0.75, "Leg.R": 0.75}, ["Head"], ["Arm.L", "Arm.R"], face


def build_dragon_hydra(spec):
    parts = []
    base_v, base_f = superellipsoid(1.62, 1.3, 0.98, center=(0.0, 0.0, 1.3), nu=32, nv=22, e=2.5)
    parts.append((MeshData("skin").add(base_v, base_f), None))
    for side in (-1.0, 1.0):
        for (y, spread) in ((-0.55, 0.9), (0.6, 0.82)):
            points = [(side * spread, y, 1.15), (side * (spread + 0.24), y - 0.12, 0.72), (side * (spread + 0.3), y - 0.2, 0.16)]
            radii = [0.34, 0.28, 0.14]
            lv, lf = sweep(points, radii, segments=12)
            parts.append((MeshData("skin").add(lv, lf), None))
            for claw in (-0.16, 0.0, 0.16):
                cv, cf = shard((side * (spread + 0.3) + claw, y - 0.34, 0.16), (claw, -1.0, 0.1), 0.22, 0.06, sides=4)
                parts.append((MeshData("accent", smooth=False).add(cv, cf), None))
        wv, wf = wing_plate((side * 1.05, 0.45, 2.05), (side * 1.0, 0.18, 0.42), (0.0, 0.3, 0.95),
                            (0.0, 1.0, 0.0), 2.0, 1.4, 0.1, lobes=3, scallop=0.2, sweep_up=0.18)
        parts.append((MeshData("accent").add(wv, wf), None))
    tail_points = [(0.0, 0.95, 1.2), (0.15, 1.6, 0.9), (0.4, 2.15, 0.5), (0.72, 2.45, 0.16)]
    tv, tf = sweep(tail_points, [0.36, 0.28, 0.18, 0.0], segments=12)
    parts.append((MeshData("skin").add(tv, tf), None))
    heads, necks = [], []
    layout = [(-1.05, 0.0, 4.35, -0.42), (0.0, 0.18, 5.55, 0.0), (1.05, -0.02, 4.5, 0.42)]
    for index, (target_x, target_y, head_z, lean) in enumerate(layout):
        name = ["L", "C", "R"][index]
        base = (target_x * 0.32, 0.1, 1.9)
        points = [
            base,
            (target_x * 0.5, 0.02, 2.45 + index * 0.08),
            (target_x * 0.78 + lean * 0.35, -0.08, 3.15 + index * 0.2),
            (target_x + lean * 0.4, -0.16, head_z - 0.32),
        ]
        radii = [0.42, 0.37, 0.32, 0.27]
        nv, nf = sweep(points, radii, segments=13)
        parts.append((MeshData("skin").add(nv, nf), None))
        head_center = (target_x + lean * 0.45, -0.3, head_z)
        hv, hf = superellipsoid(0.4, 0.66, 0.38, center=head_center, nu=20, nv=14, e=2.3)
        parts.append((MeshData("skin").add(hv, hf), None))
        snout_v, snout_f = superellipsoid(0.28, 0.34, 0.24, center=(head_center[0], head_center[1] - 0.6, head_z - 0.06),
                                         nu=14, nv=10, e=2.6)
        parts.append((MeshData("skin").add(snout_v, snout_f), None))
        for horn in (-1.0, 1.0):
            hv2, hf2 = shard((head_center[0] + horn * 0.24, head_center[1] + 0.28, head_z + 0.24),
                             (horn * 0.55, 0.5, 1.0), 0.42, 0.1, sides=4)
            parts.append((MeshData("accent", smooth=False).add(hv2, hf2), None))
        for spike in (-1.0, 0.0, 1.0):
            sv, sf = shard((head_center[0] + spike * 0.22, head_center[1] + 0.52, head_z + 0.12),
                           (spike * 0.3, 0.8, 0.6), 0.26, 0.07, sides=4)
            parts.append((MeshData("accent", smooth=False).add(sv, sf), None))
        heads.append(f"Head.{name}")
        necks.append(f"Neck.{name}")
    for index in range(4):
        t = index / 3.0
        fin_v, fin_f = wing_plate((0.0, 0.95 + t * 0.5, 1.15 + t * 0.55), (0.0, -0.05, 1.0), (0.0, 0.9, -0.25),
                                  (1.0, 0.0, 0.0), 0.42, 0.3, 0.04, lobes=2, scallop=0.15)
        parts.append((MeshData("accent").add(fin_v, fin_f), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.1), (0.0, 0.0, 1.7), "Root", True),
        ("Wing.L", (-1.05, 0.45, 2.05), (-2.6, 1.2, 3.5), "Body", True),
        ("Wing.R", (1.05, 0.45, 2.05), (2.6, 1.2, 3.5), "Body", True),
        ("Tail", (0.0, 0.95, 1.2), (0.72, 2.45, 0.16), "Body", True),
    ]
    radius_map = {"Body": 1.8, "Wing.L": 0.8, "Wing.R": 0.8, "Tail": 0.5}
    for index, (target_x, target_y, head_z, lean) in enumerate(layout):
        name = ["L", "C", "R"][index]
        bones.append((f"Neck.{name}", (target_x * 0.32, 0.1, 1.9), (target_x + lean * 0.4, -0.16, head_z - 0.32), "Body", True))
        bones.append((f"Head.{name}", (target_x + lean * 0.45, -0.3, head_z - 0.25),
                      (target_x + lean * 0.45, -0.3, head_z + 0.35), f"Neck.{name}", True))
        radius_map[f"Neck.{name}"] = 0.45
        radius_map[f"Head.{name}"] = 0.62
    _, _, head_radius = face_params(spec, 0.0, 0.2, 0.1)
    eyes = []
    for (target_x, target_y, head_z, lean) in layout:
        center_x = target_x + lean * 0.45
        eyes.append(((center_x - 0.2, -6.0, head_z + 0.08), head_radius))
        eyes.append(((center_x + 0.2, -6.0, head_z + 0.08), head_radius))
    mouths = []
    for (target_x, target_y, head_z, lean) in layout:
        center_x = target_x + lean * 0.45
        mouths.append(((center_x, -6.0, head_z - 0.28), "smile", float(spec["face"]["mouthWidth"])))
    face = {
        "eyes": eyes,
        "mouth": mouths,
        "cheeks": [],
        "brows": [((layout[1][0] - 0.24, -6.0, 5.74), 0.16, -18.0), ((layout[1][0] + 0.24, -6.0, 5.74), 0.16, 18.0)],
    }
    return parts, bones, radius_map, heads, ["Tail", "Wing.L", "Wing.R"] + necks, face


def build_abyssal_leviathan(spec):
    parts = []
    spine, radii = [], []
    for index in range(6):
        t = index / 5.0
        angle = -1.55 - 0.55 * (1.0 - t)
        radial = 1.16 - 0.2 * t
        spine.append((radial * math.cos(angle), radial * math.sin(angle), 0.2 + 0.26 * t))
        radii.append(0.06 + 0.56 * t)
    for index in range(1, 26):
        t = index / 25.0
        angle = -1.1 + t * math.tau * 1.6
        radial = 0.95 + 0.05 * math.sin(t * math.pi)
        spine.append((radial * math.cos(angle), radial * math.sin(angle), 0.46 + t * 0.95))
        radii.append(0.62 * (1.0 - t * 0.1))
    coil_end = Vector(spine[-1])
    for index in range(1, 19):
        t = index / 18.0
        x = coil_end.x + (0.55 - coil_end.x) * t + 0.2 * math.sin(t * math.pi)
        y = coil_end.y + (1.55 - coil_end.y) * t
        z = coil_end.z + t * 3.2
        spine.append((x, y, z))
        radii.append(0.56 * (1.0 - t * 0.26))
    head_base = Vector(spine[-1])
    spine.append(tuple(head_base + Vector((0.0, 0.3, 0.55))))
    radii.append(0.4)
    body_v, body_f = sweep(spine, radii, segments=20, squash=0.95)
    parts.append((MeshData("skin").add(body_v, body_f), None))
    head_center = tuple(head_base + Vector((0.0, 0.62, 0.92)))
    hv, hf = superellipsoid(0.7, 1.02, 0.7, center=head_center, nu=24, nv=16, e=2.25)
    parts.append((MeshData("skin").add(hv, hf), None))
    snout_v, snout_f = superellipsoid(0.5, 0.54, 0.4,
                                      center=(head_center[0], head_center[1] - 1.0, head_center[2] - 0.12),
                                      nu=16, nv=12, e=2.5)
    parts.append((MeshData("skin").add(snout_v, snout_f), None))
    for index in range(8):
        spread = (index - 3.5) / 3.5
        angle = math.radians(18.0 + 26.0 * abs(spread))
        direction = Vector((spread * 0.9, 0.55, math.cos(angle)))
        base = Vector((head_center[0] + spread * 0.34, head_center[1] + 0.34,
                       head_center[2] + 0.2 + max(0.0, 0.25 - abs(spread) * 0.2)))
        sv, sf = shard(tuple(base), tuple(direction.normalized()), 1.0 - abs(spread) * 0.24,
                       0.2 - abs(spread) * 0.03, sides=5, flatten=0.5)
        parts.append((MeshData("accent", smooth=False).add(sv, sf), None))
    for side in (-1.0, 1.0):
        for horn in (0.0, 1.0):
            sv, sf = shard((head_center[0] + side * (0.3 + horn * 0.18), head_center[1] + 0.3 + horn * 0.16,
                            head_center[2] + 0.34), (side * 0.5, 0.45, 1.0), 0.7 - horn * 0.15, 0.13, sides=4)
            parts.append((MeshData("accent", smooth=False).add(sv, sf), None))
        fv, ff = wing_plate((head_center[0] + side * 0.32, head_center[1] - 0.1, head_center[2] - 0.05),
                            (side * 1.0, 0.45, -0.1), (0.0, -0.6, -0.8), (0.0, 0.0, 1.0),
                            0.95, 0.62, 0.055, lobes=2, scallop=0.22)
        parts.append((MeshData("accent").add(fv, ff), None))
    crest_v, crest_f = wing_plate((head_center[0], head_center[1] + 0.36, head_center[2] + 0.4),
                                  (0.0, 0.05, 1.0), (0.0, 0.95, -0.1), (1.0, 0.0, 0.0),
                                  1.0, 0.8, 0.07, lobes=3, scallop=0.24)
    parts.append((MeshData("accent").add(crest_v, crest_f), None))
    for index in range(6):
        t = 0.12 + index * 0.13
        x = coil_end.x + (0.55 - coil_end.x) * t + 0.2 * math.sin(t * math.pi)
        y = coil_end.y + (1.55 - coil_end.y) * t
        z = coil_end.z + t * 3.2
        length = 0.5 + 0.2 * math.sin(t * math.pi)
        sv, sf = shard((x, y, z + 0.12), (0.0, 0.4, 1.0), length, 0.15, sides=4, flatten=0.55)
        parts.append((MeshData("accent", smooth=False).add(sv, sf), None))
    bones = [
        ("Root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.5), None, False),
        ("Body", (0.0, 0.0, 0.35), (-0.2, 0.5, 1.2), "Root", True),
        ("Spine1", (-0.2, 0.5, 1.2), (0.3, 1.0, 2.6), "Body", True),
        ("Spine2", (0.3, 1.0, 2.6), (0.55, 1.55, 4.25), "Spine1", True),
        ("Head", (0.55, 1.55, 4.25), tuple(head_center), "Spine2", True),
        ("Tail", (0.0, 0.0, 0.45), (-1.15, 0.1, 0.22), "Body", True),
    ]
    _, _, head_radius = face_params(spec, 0.0, 0.26, 0.18)
    face = {
        "eyes": [((head_center[0] - 0.26, -6.0, head_center[2] + 0.14), head_radius),
                 ((head_center[0] + 0.26, -6.0, head_center[2] + 0.14), head_radius)],
        "mouth": ((head_center[0], -6.0, head_center[2] - 0.24), "open", float(spec["face"]["mouthWidth"])),
        "cheeks": [],
        "brows": [((head_center[0] - 0.26, -6.0, head_center[2] + 0.36), 0.16, -16.0),
                  ((head_center[0] + 0.26, -6.0, head_center[2] + 0.36), 0.16, 16.0)],
    }
    return parts, bones, {"Body": 1.3, "Spine1": 1.0, "Spine2": 0.95, "Head": 1.05, "Tail": 0.8}, ["Head"], ["Spine1", "Spine2", "Tail"], face


BUILDERS = {
    "classic_blue": build_classic_blue,
    "mint_droplet": build_mint_droplet,
    "gel_cube": build_gel_cube,
    "spiral_slime": build_spiral_slime,
    "faceted_crystal": build_faceted_crystal,
    "jellyfish_slime": build_jellyfish_slime,
    "cosmic_orb": build_cosmic_orb,
    "tornado_slime": build_tornado_slime,
    "celestial_winged": build_celestial_winged,
    "blob_hydra": build_blob_hydra,
    "crystal_golem": build_crystal_golem,
    "dragon_hydra": build_dragon_hydra,
    "abyssal_leviathan": build_abyssal_leviathan,
}


# =============================================================================
# Main
# =============================================================================

def load_first_party_helpers(path):
    if not os.path.exists(path):
        raise SystemExit(f"[SLIME] missing first-party pipeline helper: {path}")
    spec = importlib.util.spec_from_file_location("blender_export_example", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser(description="Build one S13 slime asset design")
    parser.add_argument("--spec", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--helper", required=True)
    parser.add_argument("--seed", type=int, default=1000)
    parser.add_argument("--skip-render", action="store_true")
    return parser.parse_args(argv)


def main():
    args = parse_args()
    with open(args.spec, "r", encoding="utf-8") as handle:
        spec = json.load(handle)
    slug = spec["slug"]
    builder = BUILDERS.get(spec["builder"])
    if builder is None:
        raise SystemExit(f"[SLIME] no builder registered for '{spec['builder']}'")
    os.makedirs(args.out, exist_ok=True)
    helpers = load_first_party_helpers(args.helper)

    reset_scene()
    scene = bpy.context.scene
    parts, bones, radius_map, heads, appendages, face = builder(spec)

    palette = spec["palette"]
    materials = {role: make_role_material(role, palette) for role in ROLES}
    objects = []
    for index, (mesh_data, _) in enumerate(parts):
        material = materials[mesh_data.role]
        objects.append(create_object(f"SLIME_{slug}_part{index:02d}", mesh_data, material, scene.collection))
    body = join_objects(objects, slug)

    helpers.apply_deterministic_transforms(body)
    recenter_and_ground(body)
    bpy.context.view_layer.update()

    face_parts = []
    for probe, radius in face["eyes"]:
        add_eye_parts(face_parts, body, probe, radius, palette)
    mouths = face.get("mouth")
    if mouths:
        mouth_list = mouths if isinstance(mouths[0][0], (list, tuple)) else [mouths]
        for probe, style, width in mouth_list:
            add_mouth_parts(face_parts, body, probe, style, width)
    for probe, radius in face["cheeks"]:
        add_cheek_parts(face_parts, body, probe, radius)
    for probe, radius, tilt in face["brows"]:
        add_brow_parts(face_parts, body, probe, radius, tilt)

    face_objects = []
    for index, (mesh_data, _) in enumerate(face_parts):
        face_objects.append(create_object(f"SLIME_{slug}_face{index:02d}", mesh_data,
                                          materials[mesh_data.role], scene.collection))
    body = join_objects([body] + face_objects, slug)
    helpers.apply_deterministic_transforms(body)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

    triangles = helpers.validate_mesh_budget([body], max_tris=20000)
    bounds = mesh_bounds(body.data)
    # The spec height is a contract: scale uniformly (mesh + rig) so the delivered
    # stud height is exactly the declared one.
    height_scale = float(spec["heightStuds"]) / max(bounds["size"][2], 1e-6)
    if abs(height_scale - 1.0) > 1e-4:
        for vertex in body.data.vertices:
            vertex.co *= height_scale
        body.data.update()
        recenter_and_ground(body)
        bounds = mesh_bounds(body.data)
    uv = uv_unwrap(body)
    colour_path, rough_path, coverage, roundtrip = rasterize_textures(body, spec, args.seed, args.out)
    skin_material = build_material(spec, colour_path, rough_path)
    apply_single_material(body, skin_material)
    packed_images = pack_material_images(skin_material)

    rig = build_armature(slug, bones, height_scale)
    max_influences, max_weight_error, deform_bones = assign_weights(
        body, rig, bones, {name: radius * height_scale for name, radius in radius_map.items()}
    )
    clips = author_clips(rig, spec, heads, appendages)

    scene.frame_set(1)
    bpy.context.view_layer.update()
    bounds = mesh_bounds(body.data)

    glb_path = os.path.join(args.out, f"{slug}.glb")
    export_glb(body, rig, glb_path)
    rotation_fix = normalize_glb_rotation_tracks(glb_path)
    exported = inspect_glb(glb_path)

    preview_path = os.path.join(args.out, f"{slug}_preview.png")
    silhouette_path = os.path.join(args.out, f"{slug}_silhouette.png")
    preview_size = 768 if bounds["size"][2] >= 6.0 else 640
    if not args.skip_render:
        setup_render_scene(spec)
        render_preview(spec, bounds, preview_path, preview_size)

    blend_path = os.path.join(args.out, f"{slug}.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    if not args.skip_render:
        render_silhouette(spec, silhouette_path, preview_size)

    non_finite = 0
    for vertex in body.data.vertices:
        if not all(math.isfinite(value) for value in vertex.co):
            non_finite += 1

    checks = {
        "triangleBudget": bool(triangles < 20000 and triangles > 0),
        "normalizedWeights": bool(max_weight_error < 1e-4),
        "uvInRange": bool(uv["minU"] >= -1e-4 and uv["maxU"] <= 1 + 1e-4
                          and uv["minV"] >= -1e-4 and uv["maxV"] <= 1 + 1e-4),
        "bottomOrigin": bool(abs(bounds["min"][2]) <= 1e-3),
        "clipCount": bool(len(clips) == 3 and sorted(exported["animations"]) == sorted(CLIP_ORDER)),
        "loopIdentity": bool(clips[0]["loopError"] < 1e-4),
        "texturesEmbedded": bool(exported["embeddedImages"] >= 2 and exported["images"] >= 2),
        "blendTexturesPacked": bool(len(packed_images) >= 2 and all(item["packed"] for item in packed_images)),
        "quaternionContinuity": bool(rotation_fix["minimumDot"] > 0.0),
    }
    stats = {
        "schema": "robloxia.slime-asset-stats/v1",
        "slug": slug,
        "name": spec["name"],
        "builder": spec["builder"],
        "referenceFile": spec["referenceFile"],
        "generatedAt": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat(),
        "blenderVersion": bpy.app.version_string,
        "tris": triangles,
        "vertices": len(body.data.vertices),
        "bounds": bounds,
        "origin": {
            "xyCenter": [round((bounds["min"][0] + bounds["max"][0]) * 0.5, 6),
                         round((bounds["min"][1] + bounds["max"][1]) * 0.5, 6)],
            "bottomZ": round(bounds["min"][2], 6),
        },
        "uv": {key: round(value, 6) for key, value in uv.items()},
        "textures": {
            "colour": os.path.basename(colour_path),
            "roughness": os.path.basename(rough_path),
            "size": int(spec["textureSize"]),
            "coverage": round(coverage, 4),
            "roundTripError": round(roundtrip, 6),
        },
        "materials": 1,
        "rig": {
            "bones": [bone[0] for bone in bones],
            "deformBones": deform_bones,
            "maxInfluences": max_influences,
            "maxWeightError": round(max_weight_error, 8),
        },
        "clips": [
            {"name": clip["name"], "frames": clip["frames"], "durationSeconds": clip["durationSeconds"],
             "channels": clip["channels"]}
            for clip in clips
        ],
        "exportedClips": exported["animations"],
        "loopError": round(clips[0]["loopError"], 8),
        "nonFinite": non_finite,
        "checks": checks,
        "export": {
            "glb": os.path.basename(glb_path),
            "blend": os.path.basename(blend_path),
            "bytes": exported["bytes"],
            "sha256": exported["sha256"],
            "skins": exported["skins"],
            "joints": exported["joints"],
            "images": exported["images"],
            "embeddedImages": exported["embeddedImages"],
            "animationChannels": exported["animationChannels"],
            "blendPackedImages": packed_images,
            "quaternionSignFixes": rotation_fix["flippedSamples"],
            "quaternionMinimumDot": round(rotation_fix["minimumDot"], 6),
        },
    }
    stats_path = os.path.join(args.out, f"{slug}_stats.json")
    write_stats(stats_path, stats)
    print(f"[SLIME] {slug} tris={triangles} bones={deform_bones} clips={','.join(exported['animations'])} "
          f"loop={clips[0]['loopError']:.2e} checks={sum(1 for value in checks.values() if value)}/{len(checks)}")
    if not all(checks.values()):
        raise SystemExit(f"[SLIME] {slug} failed checks: {[name for name, ok in checks.items() if not ok]}")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        raise SystemExit(1)
