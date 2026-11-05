#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
blender_export_example.py — Plantilla de referencia RAASE 3.0 (roblox-36-asset-pipeline)

Fabricar un prop estilizado (default: cofre/caja con bevels) y exportarlo como GLB/FBX
con preservación cromática garantizada (Vertex Colors + Palette Atlas UV zero-area scaling),
aplicación determinista de transformaciones (1 stud = 0.28 m) y validación de presupuesto
poligonal (< 20,000 triángulos por malla para Roblox Open Cloud v1/assets).

Uso:
  blender --background --python blender_export_example.py -- --name mesh_chest_iron --out "C:/ruta/exports/lote"

Parámetros (después de `--`):
  --name          id del asset (naming `mesh_<nombre>_<variante>`)
  --out           carpeta de salida (GLB/FBX + preview PNG)
  --dims          dimensiones finales x,y,z en metros (preferido; el runner lo calcula por-eje)
  --scale         tamaño uniforme en metros (fallback; default 0.9 ≈ 3.2 studs; 1 stud ≈ 0.28 m)
  --color         color base RGB 0-1 "r,g,b" (default gris acero)
  --format        formato de export: GLB (default) | GLTF_SEPARATE | FBX
  --palette-grid  tamaño N de la grilla de paleta UV NxN (default 16 para atlas 256x256)

Salidas:
  <out>/<name>.glb            malla exportada con COLOR_0 y UV de paleta
  <out>/<name>_preview.png    render de preview para ASSETS_HANDOFF.md
El log imprime el tri count real para la verificación de presupuesto.
"""

import bpy
import sys
import os
import argparse

MAX_ROBLOX_TRIANGLES = 20000
STUD_TO_METERS = 0.28


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser(description="RAASE 3.0 asset export template")
    parser.add_argument("--name", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--scale", type=float, default=0.9)
    parser.add_argument("--dims", default=None)
    parser.add_argument("--color", default="0.55,0.58,0.62")
    parser.add_argument("--format", default="GLB", choices=["GLB", "GLTF_SEPARATE", "FBX"])
    parser.add_argument("--palette-grid", type=int, default=16)
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _normalize_objects(obj_or_objs):
    if obj_or_objs is None:
        return [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if isinstance(obj_or_objs, (list, tuple, set)):
        return [o for o in obj_or_objs if o and o.type == 'MESH']
    return [obj_or_objs] if obj_or_objs.type == 'MESH' else []


def apply_deterministic_transforms(obj_or_objs) -> None:
    """Aplica location, rotation y scale en todas las mallas antes de exportar."""
    objs = _normalize_objects(obj_or_objs)
    if not objs:
        return
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def bake_materials_to_vertex_colors(obj_or_objs, attr_name: str = "Color") -> None:
    """Estrategia A: Hornea el Base Color de cada material Principled BSDF en el atributo
    de color de vértice (CORNER / BYTE_COLOR o FLOAT_COLOR) para que Roblox Studio renderice
    colores nativos sin requerir texturas externas."""
    for obj in _normalize_objects(obj_or_objs):
        mesh = obj.data
        if hasattr(mesh, "color_attributes"):
            color_attr = mesh.color_attributes.get(attr_name)
            if not color_attr:
                color_attr = mesh.color_attributes.new(
                    name=attr_name,
                    type='BYTE_COLOR',
                    domain='CORNER',
                )
            mesh.color_attributes.active_color = color_attr
            mesh.color_attributes.render_color_index = 0
            for poly in mesh.polygons:
                col = (0.7, 0.7, 0.7, 1.0)
                if poly.material_index < len(mesh.materials):
                    mat = mesh.materials[poly.material_index]
                    if mat and mat.use_nodes:
                        bsdf = mat.node_tree.nodes.get("Principled BSDF")
                        if bsdf and "Base Color" in bsdf.inputs:
                            dv = bsdf.inputs["Base Color"].default_value
                            col = (float(dv[0]), float(dv[1]), float(dv[2]), 1.0)
                for loop_idx in poly.loop_indices:
                    color_attr.data[loop_idx].color = col
        elif hasattr(mesh, "vertex_colors"):
            vcol = mesh.vertex_colors.get(attr_name) or mesh.vertex_colors.new(name=attr_name)
            for poly in mesh.polygons:
                col = (0.7, 0.7, 0.7, 1.0)
                if poly.material_index < len(mesh.materials):
                    mat = mesh.materials[poly.material_index]
                    if mat and mat.use_nodes:
                        bsdf = mat.node_tree.nodes.get("Principled BSDF")
                        if bsdf and "Base Color" in bsdf.inputs:
                            dv = bsdf.inputs["Base Color"].default_value
                            col = (float(dv[0]), float(dv[1]), float(dv[2]), 1.0)
                for loop_idx in poly.loop_indices:
                    vcol.data[loop_idx].color = col


def map_uv_to_palette_atlas(
    obj_or_objs,
    palette_grid_size: int = 16,
    slot_by_material: dict | None = None,
) -> None:
    """Estrategia B: Colapsa las islas UV de cada cara a escala cero (0, 0) centradas
    exactamente en el píxel correspondiente de un Atlas de Paleta NxN:
      u_center = (col_idx + 0.5) / N
      v_center = 1.0 - ((row_idx + 0.5) / N)
    Permite que cientos de mallas compartan una única textura de 256x256 (1 Draw Call)."""
    grid_n = max(1, int(palette_grid_size))
    for obj in _normalize_objects(obj_or_objs):
        mesh = obj.data
        uv_layer = mesh.uv_layers.active or mesh.uv_layers.new(name="PaletteUV")
        mesh.uv_layers.active = uv_layer
        for poly in mesh.polygons:
            mat_idx = poly.material_index
            if slot_by_material and mat_idx in slot_by_material:
                col_idx, row_idx = slot_by_material[mat_idx]
            else:
                slot = mat_idx % (grid_n * grid_n)
                col_idx = slot % grid_n
                row_idx = slot // grid_n
            u_center = (col_idx + 0.5) / float(grid_n)
            v_center = 1.0 - ((row_idx + 0.5) / float(grid_n))
            for loop_idx in poly.loop_indices:
                uv_layer.data[loop_idx].uv = (u_center, v_center)


def validate_mesh_budget(obj_or_objs, max_tris: int = MAX_ROBLOX_TRIANGLES) -> int:
    """Calcula el conteo de triángulos y valida el límite duro de Roblox (< 20,000 tris)."""
    total_tris = 0
    for obj in _normalize_objects(obj_or_objs):
        obj_tris = sum(len(poly.vertices) - 2 for poly in obj.data.polygons)
        if obj_tris > max_tris:
            raise ValueError(
                f"[RAASE] La malla '{obj.name}' tiene {obj_tris} triángulos, excediendo el límite de Roblox ({max_tris})."
            )
        total_tris += obj_tris
    if total_tris > max_tris:
        raise ValueError(
            f"[RAASE] El lote suma {total_tris} triángulos, excediendo el presupuesto máximo por malla ({max_tris})."
        )
    return total_tris


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


def export_asset(path: str, fmt: str, objs=None, palette_grid_size: int = 16) -> str:
    """Aplica transformaciones, hornea Vertex Colors + Palette UV, valida <20k tris y exporta."""
    target_objs = _normalize_objects(objs)
    apply_deterministic_transforms(target_objs)
    bake_materials_to_vertex_colors(target_objs)
    map_uv_to_palette_atlas(target_objs, palette_grid_size=palette_grid_size)
    validate_mesh_budget(target_objs, max_tris=MAX_ROBLOX_TRIANGLES)

    if fmt == "FBX":
        fbx_path = os.path.splitext(path)[0] + ".fbx"
        bpy.ops.export_scene.fbx(
            filepath=fbx_path,
            use_selection=False,
            path_mode='COPY',
            embed_textures=True,
            colors_type='SRGB',
            apply_scale_options='FBX_SCALE_ALL',
        )
        return fbx_path
    if fmt == "GLTF_SEPARATE":
        gltf_path = os.path.splitext(path)[0] + ".gltf"
        bpy.ops.export_scene.gltf(
            filepath=gltf_path,
            export_format="GLTF_SEPARATE",
            use_selection=False,
            export_colors=True,
            export_apply=True,
        )
        return gltf_path
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=False,
        export_colors=True,
        export_apply=True,
    )
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
    exported_path = export_asset(glb_path, args.format, objs=[prop], palette_grid_size=args.palette_grid)
    render_preview(prop, preview_path)

    tris = validate_mesh_budget([prop], max_tris=MAX_ROBLOX_TRIANGLES)
    print(f"[RAASE] {args.name}: export={exported_path} | preview={preview_path} | tris={tris}")


if __name__ == "__main__":
    main()
