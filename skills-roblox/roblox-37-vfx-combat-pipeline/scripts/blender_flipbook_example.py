#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
blender_flipbook_example.py — Plantilla de referencia RAASE 2.1 (roblox-37-vfx-combat-pipeline)

Genera un FLIPBOOK de impacto (onda de choque estilizada) renderizando N frames
a PNG transparente, listos para empaquetar como atlas sprite-sheet para
ParticleEmitter.FlipbookLayout en Roblox.

Uso:
  blender --background --python blender_flipbook_example.py -- --out "C:/ruta/exports/impacts" --frames 16 --size 256

Parámetros (después de `--`):
  --out     carpeta de salida (crea frames/ dentro)
  --frames  cantidad de frames: SOLO 4, 16 o 64 (mapea a Grid2x2/Grid4x4/Grid8x8)
  --size    resolución POR FRAME (default 256; el atlas 4x4 = 1024, el máximo que acepta el motor)

Salidas:
  <out>/frames/impact_00.png ... impact_NN.png   (RGBA con alpha real)
  Comando de empaquetado impreso en consola (ImageMagick v7 `magick montage` o v6 `montage`).

Restricciones del motor (verificadas):
  * Textura de flipbook: cuadrada, potencia de dos, MÁXIMO 1024x1024 en el atlas.
  * 4x4 de 256px → atlas 1024 ✓ | 8x8 requiere 128px por frame para no exceder 1024.

Compatibilidad Blender: 3.x / 4.x / 5.x (sockets y engines con guards de versión).
"""

import bpy
import sys
import os
import math
import argparse

VALID_FRAMES = {4: "Grid2x2", 16: "Grid4x4", 64: "Grid8x8"}


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser(description="RAASE impact flipbook template")
    parser.add_argument("--out", required=True)
    parser.add_argument("--frames", type=int, default=16)
    parser.add_argument("--size", type=int, default=256)
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def set_emission(mat: bpy.types.Material, color: tuple, strength: float) -> None:
    """Socket con guard de versión: 'Emission Color' (4.x+) vs 'Emission' (3.x)."""
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if not bsdf:
        return
    for socket_name in ("Emission Color", "Emission"):
        if socket_name in bsdf.inputs:
            bsdf.inputs[socket_name].default_value = (*color, 1.0)
            break
    if "Emission Strength" in bsdf.inputs:
        bsdf.inputs["Emission Strength"].default_value = strength


def enable_material_blend(mat: bpy.types.Material) -> None:
    """Transparencia del material por versión: 4.2+ surface_render_method / 3.x-4.1 blend_method."""
    if hasattr(mat, "surface_render_method"):
        try:
            mat.surface_render_method = "BLENDED"
            return
        except TypeError:
            pass
    for attr, value in (("blend_method", "BLEND"), ("shadow_method", "NONE")):
        if hasattr(mat, attr):
            try:
                setattr(mat, attr, value)
            except TypeError:
                pass


def build_shockwave() -> bpy.types.Object:
    """Anillo emisivo que escala y se desvanece — reemplazar por el efecto real."""
    bpy.ops.mesh.primitive_torus_add(major_radius=0.6, minor_radius=0.12)

    ring = bpy.context.active_object
    ring.name = "shockwave"

    mat = bpy.data.materials.new(name="shockwave_mat")
    mat.use_nodes = True
    set_emission(mat, (1.0, 0.6, 0.15), 6.0)
    enable_material_blend(mat)
    ring.data.materials.append(mat)
    return ring


def setup_camera(size: int) -> None:
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue

    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.image_settings.color_mode = "RGBA"
    # CRÍTICO para VFX: fondo transparente real (sin esto cada frame es opaco).
    scene.render.film_transparent = True

    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0.0, -3.4, 0.6)
    cam.rotation_euler = (math.radians(80), 0.0, 0.0)
    scene.camera = cam


def render_frames(ring: bpy.types.Object, out_dir: str, total: int) -> None:
    scene = bpy.context.scene
    frames_dir = os.path.join(out_dir, "frames")
    os.makedirs(frames_dir, exist_ok=True)

    mat = ring.data.materials[0]
    bsdf = mat.node_tree.nodes.get("Principled BSDF")

    for i in range(total):
        t = i / max(total - 1, 1)  # 0..1
        scale = 0.5 + t * 2.2
        ring.scale = (scale, scale, scale * (0.5 + t * 0.3))

        # Fade real: alpha del BSDF + film_transparent + render method BLENDED/Blend.
        if bsdf and "Alpha" in bsdf.inputs:
            bsdf.inputs["Alpha"].default_value = max(0.0, 1.0 - t)

        scene.render.filepath = os.path.join(frames_dir, f"impact_{i:02d}.png")
        bpy.ops.render.render(write_still=True)

    grid = VALID_FRAMES.get(total, "Custom")
    side = int(math.sqrt(total))
    print(f"[RAASE] {total} frames RGBA en {frames_dir} | layout objetivo: {grid}")
    print(
        f"[RAASE] Empaquetar atlas {side}x{side} (max 1024): "
        f"magick montage {frames_dir}/impact_*.png -tile {side}x{side} -geometry +0+0 "
        f"{out_dir}/impact_atlas_{side}x{side}.png   (ImageMagick v6: usar `montage` sin `magick`)"
    )


def main() -> None:
    args = parse_args()
    if args.frames not in VALID_FRAMES:
        raise SystemExit(
            f"[RAASE] --frames={args.frames} inválido: el motor solo acepta 4 (Grid2x2), 16 (Grid4x4) o 64 (Grid8x8)."
        )
    if args.size * int(math.sqrt(args.frames)) > 1024:
        raise SystemExit(
            f"[RAASE] --size={args.size} x grid {int(math.sqrt(args.frames))}x{int(math.sqrt(args.frames))} "
            f"excede el máximo de atlas 1024x1024 del motor."
        )

    clear_scene()
    ring = build_shockwave()
    setup_camera(args.size)
    render_frames(ring, args.out, args.frames)


if __name__ == "__main__":
    main()
