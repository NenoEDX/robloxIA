#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
blender_export_example.py — Plantilla de referencia RAASE 2.1 (roblox-36-asset-pipeline)

Fabricar un prop estilizado (default: cofre/caja con bevels) y exportarlo como GLB
+ render de preview PNG para el handoff al creador.

Uso:
  blender --background --python blender_export_example.py -- --name mesh_chest_iron --out "C:/ruta/exports/lote"

Parámetros (después de `--`):
  --name   id del asset (naming `mesh_<nombre>_<variante>`)
  --out    carpeta de salida (GLB + preview PNG)
  --dims   dimensiones finales x,y,z en metros (preferido; el runner lo calcula por-eje)
  --scale  tamaño uniforme en metros (fallback; default 0.9 ≈ 3.2 studs; 1 stud ≈ 0.28 m)
  --color  color base RGB 0-1 "r,g,b" (default gris acero)
  --format formato de export: GLB (default) | GLTF_SEPARATE | FBX — fallback si el
           importer de Studio rechaza GLB (misma geometría)

Salidas:
  <out>/<name>.glb            malla exportada
  <out>/<name>_preview.png    render de preview para ASSETS_HANDOFF.md
El log imprime el tri count real para la verificación de presupuesto.
"""

import bpy
import sys
import os
import argparse


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser(description="RAASE asset export template")
    parser.add_argument("--name", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--scale", type=float, default=0.9)
    parser.add_argument("--dims", default=None)
    parser.add_argument("--color", default="0.55,0.58,0.62")
    parser.add_argument("--format", default="GLB", choices=["GLB", "GLTF_SEPARATE", "FBX"])
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def build_prop(name: str, dims: tuple, color: tuple) -> bpy.types.Object:
    """Prop genérico: caja con bevel + tapa. Reemplazar por lógica del asset real.
    `dims` = dimensiones finales (x, y, z) en metros (cubo base size=1 ⇒ scale = dims)."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    body = bpy.context.active_object
    body.name = name
    body.scale = dims

    bevel = body.modifiers.new(name="bevel", type='BEVEL')
    bevel.width = min(dims) * 0.06
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)

    mat = bpy.data.materials.new(name=f"{name}_mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.7
    body.data.materials.append(mat)
    return body


def export_asset(path: str, fmt: str) -> str:
    """Exporta con fallback de formato: GLB (default), GLTF_SEPARATE o FBX."""
    if fmt == "FBX":
        fbx_path = os.path.splitext(path)[0] + ".fbx"
        bpy.ops.export_scene.fbx(filepath=fbx_path, use_selection=False)
        return fbx_path
    if fmt == "GLTF_SEPARATE":
        gltf_path = os.path.splitext(path)[0] + ".gltf"
        bpy.ops.export_scene.gltf(filepath=gltf_path, export_format="GLTF_SEPARATE", use_selection=False)
        return gltf_path
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False)
    return path


def render_preview(prop: bpy.types.Object, path: str) -> None:
    """Cámara + luz + render rápido para el preview del handoff."""
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue

    cam_data = bpy.data.cameras.new("preview_cam")
    cam = bpy.data.objects.new("preview_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (prop.dimensions.x * 2.2, -prop.dimensions.y * 2.2, prop.dimensions.z * 2.4)
    cam.rotation_euler = (1.05, 0.0, 0.78)
    scene.camera = cam

    sun_data = bpy.data.lights.new("sun", type='SUN')
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (0.9, 0.2, 0.6)
    scene.collection.objects.link(sun)

    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main() -> None:
    args = parse_args()
    color = tuple(float(c) for c in args.color.split(","))
    if args.dims:
        dims = tuple(float(d) for d in args.dims.split(","))
        if len(dims) != 3:
            raise SystemExit("[RAASE] --dims requiere el formato 'x,y,z' en metros.")
    else:
        dims = (args.scale, args.scale * 0.7, args.scale * 0.6)
    os.makedirs(args.out, exist_ok=True)

    clear_scene()
    prop = build_prop(args.name, dims, color)

    glb_path = os.path.join(args.out, f"{args.name}.glb")
    preview_path = os.path.join(args.out, f"{args.name}_preview.png")
    exported_path = export_asset(glb_path, args.format)
    render_preview(prop, preview_path)

    tris = sum(len(poly.vertices) - 2 for poly in prop.data.polygons)
    print(f"[RAASE] {args.name}: export={exported_path} | preview={preview_path} | tris={tris}")


if __name__ == "__main__":
    main()
