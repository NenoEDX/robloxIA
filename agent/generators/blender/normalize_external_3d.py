# -*- coding: utf-8 -*-
"""
normalize_external_3d.py — Route C Blender 5.2 Auto-Cleanup Pipeline for Roblox.

Converts raw external AI 3D meshes (Tripo 3D, Meshy, Hyper3D Rodin, Cube 3D, etc.)
from .glb/.gltf/.fbx/.obj into Roblox-ready MeshParts:
  1. Joins fragmented mesh objects into one cohesive mesh.
  2. Applies transforms, sets bottom-center origin (min Z = 0, centered XY).
  3. Scales uniformly so height matches --height-studs (1 Blender unit = 1 stud).
  4. Decimates triangle soup down to --target-tris (always strictly < 20,000).
  5. Collapses multiple material slots into one clean Principled BSDF material.
  6. Exports a normalized .glb and writes <slug>_stats.json.

Usage:
  blender -b --factory-startup --python agent/generators/blender/normalize_external_3d.py -- \
    --input <raw.glb|fbx|obj> --out <clean.glb> [--target-tris 4000] [--height-studs 4.0]
"""

import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    parser = argparse.ArgumentParser(description="Normalize external 3D asset for Roblox Studio")
    parser.add_argument("--input", required=True, help="Input .glb/.gltf/.fbx/.obj path")
    parser.add_argument("--out", required=True, help="Output normalized .glb path")
    parser.add_argument("--target-tris", type=int, default=4000, help="Target triangle budget (< 20000)")
    parser.add_argument("--height-studs", type=float, default=4.0, help="Target height in Roblox studs")
    return parser.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_raw_model(filepath: str):
    ext = os.path.splitext(filepath)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=filepath)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=filepath)
    else:
        raise ValueError(f"Unsupported input format: {ext}")


def count_triangles(obj) -> int:
    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(deps)
    mesh = eval_obj.to_mesh()
    mesh.calc_loop_triangles()
    n = len(mesh.loop_triangles)
    eval_obj.to_mesh_clear()
    return n


def normalize_mesh(target_tris: int, height_studs: float):
    mesh_objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not mesh_objs:
        raise RuntimeError("No MESH objects found in imported file")

    bpy.ops.object.select_all(action="DESELECT")
    for o in mesh_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objs[0]

    if len(mesh_objs) > 1:
        bpy.ops.object.join()

    obj = bpy.context.view_layer.objects.active
    obj.name = "NormalizedAsset"

    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    if not obj.data.vertices:
        raise RuntimeError("Imported mesh has 0 vertices")

    tris_before = count_triangles(obj)
    capped_target = min(max(target_tris, 100), 19500)

    if tris_before > capped_target:
        ratio = max(0.02, min(1.0, float(capped_target) / float(tris_before)))
        dec = obj.modifiers.new(name="RobloxBudgetDecimate", type="DECIMATE")
        dec.decimate_type = "COLLAPSE"
        dec.ratio = ratio
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=dec.name)

    tri_mod = obj.modifiers.new(name="TriangulateNgons", type="TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri_mod.name)

    # Recenter XY, seat bottom at Z=0, and scale to exact heightStuds AFTER decimation
    verts = [v.co for v in obj.data.vertices]
    min_x = min(v.x for v in verts)
    max_x = max(v.x for v in verts)
    min_y = min(v.y for v in verts)
    max_y = max(v.y for v in verts)
    min_z = min(v.z for v in verts)
    max_z = max(v.z for v in verts)

    center_x = 0.5 * (min_x + max_x)
    center_y = 0.5 * (min_y + max_y)
    raw_height = max(max_z - min_z, 1e-4)
    scale_factor = height_studs / raw_height

    for v in obj.data.vertices:
        v.co.x = (v.co.x - center_x) * scale_factor
        v.co.y = (v.co.y - center_y) * scale_factor
        v.co.z = (v.co.z - min_z) * scale_factor
    obj.data.update()

    if len(obj.data.materials) > 1:
        first_mat = obj.data.materials[0]
        obj.data.materials.clear()
        obj.data.materials.append(first_mat)
    elif len(obj.data.materials) == 0:
        mat = bpy.data.materials.new(name="RobloxStylizedMat")
        mat.use_nodes = True
        obj.data.materials.append(mat)

    tris_after = count_triangles(obj)
    verts_after = [v.co for v in obj.data.vertices]
    final_min_z = min(v.z for v in verts_after)
    final_max_z = max(v.z for v in verts_after)
    final_width = max(v.x for v in verts_after) - min(v.x for v in verts_after)
    final_depth = max(v.y for v in verts_after) - min(v.y for v in verts_after)
    final_height = final_max_z - final_min_z

    return obj, {
        "trisBefore": tris_before,
        "trisAfter": tris_after,
        "targetTris": capped_target,
        "heightStuds": round(final_height, 4),
        "boundsStuds": [round(final_width, 4), round(final_depth, 4), round(final_height, 4)],
        "bottomZ": round(final_min_z, 6),
        "materialSlots": len(obj.data.materials),
        "checks": {
            "underRoblox20k": tris_after < 20000,
            "withinTargetBudget": tris_after <= capped_target * 1.15,
            "bottomOrigin": abs(final_min_z) < 1e-3,
            "singleMaterial": len(obj.data.materials) == 1,
        },
    }


def main():
    args = parse_args()
    if not os.path.exists(args.input):
        raise FileNotFoundError(f"Input 3D file not found: {args.input}")

    out_path = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    clear_scene()
    import_raw_model(os.path.abspath(args.input))
    obj, stats = normalize_mesh(args.target_tris, args.height_studs)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )

    stats_path = os.path.splitext(out_path)[0] + "_stats.json"
    with open(stats_path, "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)

    print(f"[normalize_external_3d] OK tris={stats['trisBefore']}->{stats['trisAfter']} out={out_path}")


if __name__ == "__main__":
    main()
