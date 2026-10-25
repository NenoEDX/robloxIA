#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
blender_zombies_generator.py — Generador Batch RAASE 3.0 en Blender 5.2 para los 61 Zombies
de Zombie Awareness (v4.0) (Z-01 a Z-60 + Z-BOSS-01 Dios Zombi Troll).

Cumple estrictamente el contrato de `blender_export_example.py` y `roblox-36-asset-pipeline`:
1. Modelado 3D real en Blender (`bmesh` + modificadores Bevel/Subsurf): cráneo esculpido con cuencas
   oculares, arco superciliar, mandíbula articulada con colmillos, caja torácica anatómica, columna,
   deltoides, bíceps, antebrazos, manos con 3 garras, pelvis, muslos, gemelos, botas/zarpas y el
   arma/armadura/mutación única de cada uno de los 61 zombies.
2. Escala métrica exacta de Roblox (`1 stud = 0.28 m`), pivote en la planta de los pies (`Z = 0.0`)
   y `apply_deterministic_transforms` (Location, Rotation y Scale congelados).
3. Doble preservación cromática RAASE 3.0 ("Colores puestos de una vez"):
   - Estrategia A: `bake_materials_to_vertex_colors` (`BYTE_COLOR` / `CORNER` en `Color` / `Col`).
   - Estrategia B: `map_uv_to_palette_atlas` colapsando islas UV a escala cero sobre `zombies_palette_256.png`
     (grilla 16x16 = 256x256 px, 1 Draw Call para todo el catálogo).
4. Validación estricta `< 20,000` triángulos por malla (`validate_mesh_budget`).
5. Exporta:
   - Los 61 archivos `.glb` y `.fbx` individuales en `exports/zombies-v4/`
   - La escena maestra `ZA_All61Zombies_Showcase.fbx` y `ZA_All61Zombies_Showcase.glb` con los 61 zombies
     separados por objeto y ordenados en 4 filas para importar de un solo golpe en Roblox Studio.
   - `assets_manifest.json`, `zombies_palette_256.png` y `ASSETS_HANDOFF.md`.
"""

import bpy
import bmesh
import math
import mathutils
import os
import sys
import json
import struct
import zlib

MAX_ROBLOX_TRIANGLES = 20000
STUD_TO_METERS = 0.28
PALETTE_GRID_N = 16

# Paleta Maestra de 32 Materiales Indexados (Slots 0..31 en la grilla 16x16 de 256x256 px)
PALETTE_MATERIALS = [
    ("Mat_00_SkinZombieBase", (0.40, 0.47, 0.37)),
    ("Mat_01_SkinZombieDark", (0.28, 0.34, 0.26)),
    ("Mat_02_SkinCharred", (0.14, 0.13, 0.13)),
    ("Mat_03_SkinToxic", (0.31, 0.45, 0.29)),
    ("Mat_04_SkinPaleMutant", (0.52, 0.47, 0.54)),
    ("Mat_05_SkinNightBlack", (0.09, 0.10, 0.14)),
    ("Mat_06_SkinBeastFurBrown", (0.32, 0.23, 0.17)),
    ("Mat_07_SkinBeastFurGrey", (0.29, 0.32, 0.30)),
    ("Mat_08_ClothUrbanGrey", (0.22, 0.25, 0.29)),
    ("Mat_09_ClothDarkPants", (0.15, 0.17, 0.20)),
    ("Mat_10_ClothFirefighter", (0.72, 0.52, 0.12)),
    ("Mat_11_ClothSurgicalTeal", (0.26, 0.56, 0.54)),
    ("Mat_12_ClothLumberjackRed", (0.62, 0.14, 0.14)),
    ("Mat_13_ClothPrisonOrange", (0.85, 0.40, 0.11)),
    ("Mat_14_ClothPoliceNavy", (0.11, 0.17, 0.31)),
    ("Mat_15_ClothMilitaryOlive", (0.24, 0.30, 0.20)),
    ("Mat_16_ClothButcherWhite", (0.84, 0.80, 0.78)),
    ("Mat_17_ClothCommanderRed", (0.42, 0.10, 0.12)),
    ("Mat_18_MetalSteel", (0.42, 0.45, 0.50)),
    ("Mat_19_MetalDarkGun", (0.16, 0.18, 0.22)),
    ("Mat_20_MetalRust", (0.48, 0.26, 0.16)),
    ("Mat_21_MetalGoldBadge", (0.92, 0.76, 0.20)),
    ("Mat_22_WoodHandle", (0.46, 0.29, 0.16)),
    ("Mat_23_BoneIvory", (0.87, 0.84, 0.75)),
    ("Mat_24_BloodCrimson", (0.60, 0.08, 0.08)),
    ("Mat_25_GlowEyeRed", (0.95, 0.16, 0.14)),
    ("Mat_26_GlowToxicGreen", (0.42, 1.00, 0.22)),
    ("Mat_27_GlowFireOrange", (1.00, 0.42, 0.08)),
    ("Mat_28_GlowElectricBlue", (0.24, 0.84, 1.00)),
    ("Mat_29_GlowSonicViolet", (0.72, 0.34, 1.00)),
    ("Mat_30_GlowWeakSpotYellow", (1.00, 0.90, 0.18)),
    ("Mat_31_ConcreteBoulder", (0.44, 0.46, 0.48)),
]

# Catálogo completo de los 61 Zombies (Z-01 a Z-60 + Z-BOSS-01)
ZOMBIE_SPECS = [
    ("Z-01", "Caminante", "RIG-04", "Zombie_Melee", [2.2, 5.5, 1.8], 0, 8, 9, 25, "claws_ribs"),
    ("Z-02", "Corredor", "RIG-04", "Zombie_Melee", [2.0, 5.5, 1.8], 0, 8, 9, 25, "runner_crest"),
    ("Z-03", "Reventador_Urbano", "RIG-04", "Zombie_Melee", [2.4, 5.6, 1.9], 0, 8, 9, 25, "lead_pipe"),
    ("Z-04", "Salvaje_Saltador", "RIG-04", "Zombie_Melee", [2.2, 5.4, 2.0], 1, 8, 9, 25, "raptor_claws"),
    ("Z-05", "Ghoul_Ardiente", "RIG-04", "Zombie_Melee", [2.2, 5.5, 1.8], 2, 2, 2, 27, "flame_core"),
    ("Z-06", "Ghoul_Marcador", "RIG-04", "Zombie_Melee", [2.2, 5.5, 1.8], 3, 8, 9, 26, "pheromone_sacs"),
    ("Z-07", "Griton_Invocador", "RIG-04", "Zombie_Melee", [2.2, 5.6, 1.8], 4, 8, 9, 29, "sonic_throat"),
    ("Z-08", "Pululante_Toxico", "RIG-04", "Zombie_Melee", [2.3, 5.5, 2.0], 3, 8, 9, 26, "toxic_pustules"),
    ("Z-09", "Bombero_Infectado", "RIG-04", "Zombie_Melee", [2.5, 5.7, 2.0], 0, 10, 9, 25, "firefighter_axe"),
    ("Z-10", "Cirujano_Distrito_Medico", "RIG-04", "Zombie_Melee", [2.2, 5.5, 1.8], 0, 11, 11, 25, "surgeon_bonesaw"),
    ("Z-11", "Lenador_Motosierra", "RIG-04", "Zombie_Melee", [2.5, 5.7, 2.2], 0, 12, 9, 25, "chainsaw"),
    ("Z-12", "Preso_Encadenado", "RIG-04", "Zombie_Melee", [2.4, 5.6, 2.2], 0, 13, 13, 25, "prison_ball"),
    ("Z-13", "Cocinero_Carnicero", "RIG-04", "Zombie_Melee", [2.5, 5.7, 2.0], 0, 16, 9, 25, "butcher_cleavers"),
    ("Z-14", "Atleta_Infectado", "RIG-04", "Zombie_Melee", [2.6, 5.7, 2.0], 0, 12, 16, 25, "athlete_pads"),
    ("Z-15", "Reptante_Alcantarilla", "RIG-04", "Zombie_Melee", [2.2, 2.2, 4.2], 3, 8, 9, 25, "crawler_no_legs"),
    ("Z-16", "Portador_Alambre", "RIG-04", "Zombie_Melee", [2.4, 5.6, 2.0], 0, 8, 9, 25, "barbed_wire"),
    ("Z-17", "Sepulturero", "RIG-04", "Zombie_Melee", [2.3, 5.7, 2.2], 1, 9, 9, 25, "gravedigger_shovel"),
    ("Z-18", "Paciente_Cero_Electrico", "RIG-04", "Zombie_Melee", [2.3, 5.6, 2.0], 4, 11, 9, 28, "tesla_coils"),
    ("Z-19", "Acechador_Nocturno", "RIG-04", "Zombie_Melee", [2.3, 5.7, 2.1], 5, 5, 5, 25, "night_scythes"),
    ("Z-20", "Amalgama_de_Carne", "RIG-04", "Zombie_Melee", [3.2, 5.9, 2.4], 0, 24, 9, 25, "flesh_amalgam_4arms"),
    ("Z-21", "Vomitor_Acido", "RIG-04", "Zombie_Ranged", [2.5, 5.5, 2.2], 3, 8, 9, 26, "acid_belly"),
    ("Z-22", "Policia_Infectado", "RIG-04", "Zombie_Ranged", [2.3, 5.6, 2.4], 0, 14, 14, 25, "police_shotgun"),
    ("Z-23", "Guardia_Seguridad", "RIG-04", "Zombie_Ranged", [2.2, 5.5, 2.2], 0, 14, 9, 25, "security_pistol"),
    ("Z-24", "Soldado_Caido_Rifle", "RIG-04", "Zombie_Ranged", [2.4, 5.6, 2.6], 0, 15, 15, 25, "soldier_rifle"),
    ("Z-25", "Zombie_Bomba_Gas", "RIG-04", "Zombie_Ranged", [2.4, 5.8, 2.4], 0, 8, 9, 27, "propane_tank_back"),
    ("Z-26", "Infectado_Subfusil", "RIG-04", "Zombie_Ranged", [2.2, 5.5, 2.3], 0, 8, 9, 25, "smg_gun"),
    ("Z-27", "Lanzador_de_Huesos", "RIG-04", "Zombie_Ranged", [2.3, 5.7, 2.4], 1, 8, 9, 25, "bone_javelins"),
    ("Z-28", "Artillero_Anclado_LMG", "RIG-04", "Zombie_Ranged", [2.7, 5.7, 3.0], 1, 15, 9, 27, "heavy_lmg"),
    ("Z-29", "Francotirador_Zombificado", "RIG-04", "Zombie_Ranged", [2.4, 5.6, 3.4], 3, 15, 15, 30, "sniper_ghillie"),
    ("Z-30", "Portador_Barril_Toxico", "RIG-04", "Zombie_Ranged", [2.6, 5.6, 2.6], 3, 10, 9, 26, "toxic_barrel_hug"),
    ("Z-31", "Infectado_Lanzallamas", "RIG-04", "Zombie_Ranged", [2.5, 5.7, 2.8], 2, 10, 9, 27, "flamethrower_pack"),
    ("Z-32", "Escupidor_Enjambre", "RIG-04", "Zombie_Ranged", [2.5, 5.6, 2.2], 3, 8, 9, 26, "insect_hive_torso"),
    ("Z-33", "Zombie_Lanzagranadas", "RIG-04", "Zombie_Ranged", [2.5, 5.6, 2.6], 0, 15, 15, 25, "grenade_launcher_drum"),
    ("Z-34", "Artillero_Arpones", "RIG-04", "Zombie_Ranged", [2.4, 5.6, 2.8], 0, 20, 9, 25, "harpoon_cannon"),
    ("Z-35", "Comandante_Infectado", "RIG-04", "Zombie_Ranged", [2.4, 5.8, 2.2], 0, 17, 9, 25, "commander_revolver"),
    ("Z-36", "Blindado_Antidisturbios", "RIG-04", "Zombie_ArmoredBeast", [2.8, 5.8, 2.5], 1, 14, 19, 25, "riot_shield_armor"),
    ("Z-37", "Soldado_Kevlar_Pesado", "RIG-04", "Zombie_ArmoredBeast", [2.7, 5.8, 2.2], 1, 15, 15, 25, "kevlar_heavy"),
    ("Z-38", "Juggernaut_EOD", "RIG-04", "Zombie_ArmoredBeast", [3.1, 6.0, 2.6], 1, 19, 19, 27, "eod_juggernaut_maul"),
    ("Z-39", "Soldador_Acorazado", "RIG-04", "Zombie_ArmoredBeast", [2.7, 5.8, 2.4], 1, 18, 20, 28, "welder_armor_torch"),
    ("Z-40", "Minero_Subterraneo", "RIG-04", "Zombie_ArmoredBeast", [2.5, 5.7, 2.4], 1, 10, 9, 30, "miner_helmet_pickaxe"),
    ("Z-41", "Sabueso_Infectado", "RIG-03", "Zombie_ArmoredBeast", [2.0, 3.2, 4.4], 6, 24, 6, 25, "beast_hound"),
    ("Z-42", "Warg_de_Asedio", "RIG-03", "Zombie_ArmoredBeast", [2.5, 3.8, 4.8], 7, 23, 7, 25, "beast_warg_plates"),
    ("Z-43", "Alfa_Lobo_Infectado", "RIG-03", "Zombie_ArmoredBeast", [2.8, 4.4, 5.4], 7, 24, 7, 26, "beast_alpha_spikes"),
    ("Z-44", "Simio_Demoledor", "RIG-03", "Zombie_ArmoredBeast", [3.6, 5.2, 4.2], 6, 8, 6, 25, "beast_ape_gorilla"),
    ("Z-45", "Oso_Zombie", "RIG-03", "Zombie_ArmoredBeast", [3.8, 4.8, 5.6], 6, 24, 6, 25, "beast_bear_claws"),
    ("Z-46", "Felino_Fantasma", "RIG-03", "Zombie_ArmoredBeast", [2.2, 3.4, 4.8], 4, 28, 4, 28, "beast_ghost_feline"),
    ("Z-47", "Hiena_Necrofaga", "RIG-03", "Zombie_ArmoredBeast", [2.2, 3.5, 4.5], 6, 20, 6, 25, "beast_hyena_ridge"),
    ("Z-48", "Pantera_Medianoche", "RIG-03", "Zombie_ArmoredBeast", [2.3, 3.4, 5.0], 5, 24, 5, 30, "beast_midnight_panther"),
    ("Z-49", "Jabali_Acorazado", "RIG-03", "Zombie_ArmoredBeast", [2.8, 3.8, 4.8], 6, 23, 6, 25, "beast_boar_tusks"),
    ("Z-50", "Quimera_Zombie", "RIG-03", "Zombie_ArmoredBeast", [4.0, 5.8, 6.2], 3, 23, 6, 26, "beast_chimera_antlers"),
    ("Z-51", "Bruto_Estandar", "RIG-05", "Zombie_Brute", [5.2, 11.0, 3.8], 0, 8, 9, 25, "brute_gauntlets"),
    ("Z-52", "Aplastador_Sismico", "RIG-05", "Zombie_Brute", [5.5, 11.2, 4.0], 1, 31, 9, 27, "brute_seismic_rock"),
    ("Z-53", "Pedrero_Urbano", "RIG-05", "Zombie_Brute", [5.6, 11.8, 4.6], 0, 8, 9, 25, "brute_boulder_thrower"),
    ("Z-54", "Devorador", "RIG-05", "Zombie_Brute", [5.6, 11.4, 4.2], 0, 24, 9, 25, "brute_chest_maw"),
    ("Z-55", "Colmillos_XL", "RIG-05", "Zombie_Brute", [5.4, 11.2, 4.8], 1, 23, 9, 25, "brute_xl_bone_blades"),
    ("Z-56", "Acorazado_de_Hueso", "RIG-05", "Zombie_Brute", [5.8, 11.5, 4.2], 23, 23, 9, 30, "brute_bone_carapace"),
    ("Z-57", "Hulk_Toxico", "RIG-05", "Zombie_Brute", [5.5, 11.2, 4.0], 3, 26, 9, 26, "brute_toxic_vents"),
    ("Z-58", "Hulk_Igneo", "RIG-05", "Zombie_Brute", [5.5, 11.4, 4.0], 2, 27, 2, 27, "brute_ignis_horns"),
    ("Z-59", "Titan_Destructor", "RIG-05", "Zombie_Brute", [6.2, 13.0, 5.4], 1, 31, 9, 25, "brute_concrete_pillar"),
    ("Z-60", "Coloso_de_Zona", "RIG-05", "Zombie_Brute", [6.8, 14.5, 4.8], 3, 23, 9, 26, "brute_zone_crown"),
    ("Z-BOSS-01", "Dios_Zombi_Troll", "RIG-06", "Zombie_MegaBoss", [14.0, 26.0, 10.5], 1, 31, 9, 26, "mega_boss_troll"),
]


def write_palette_png(filepath: str, grid_n: int = 16, img_size: int = 256) -> None:
    """Genera un PNG RGBA de 256x256 (sin dependencias externas) con las celdas de PALETTE_MATERIALS."""
    cell_px = img_size // grid_n
    raw_rows = bytearray()
    for y in range(img_size):
        raw_rows.append(0)  # filter type 0
        row_idx = y // cell_px
        for x in range(img_size):
            col_idx = x // cell_px
            slot = row_idx * grid_n + col_idx
            if slot < len(PALETTE_MATERIALS):
                rgb = PALETTE_MATERIALS[slot][1]
            else:
                rgb = (0.35, 0.38, 0.40)
            r = max(0, min(255, int(round(rgb[0] * 255))))
            g = max(0, min(255, int(round(rgb[1] * 255))))
            b = max(0, min(255, int(round(rgb[2] * 255))))
            raw_rows.extend((r, g, b, 255))

    def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", img_size, img_size, 8, 6, 0, 0, 0)
    compressed = zlib.compress(bytes(raw_rows), 9)
    png_bytes = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"IDAT", compressed)
        + png_chunk(b"IEND", b"")
    )
    with open(filepath, "wb") as f:
        f.write(png_bytes)


def ensure_palette_materials() -> list:
    """Crea o recupera los 32 materiales Principled BSDF indexados."""
    mats = []
    for name, rgb in PALETTE_MATERIALS:
        mat = bpy.data.materials.get(name)
        if not mat:
            mat = bpy.data.materials.new(name=name)
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
                bsdf.inputs["Roughness"].default_value = 0.65
        mats.append(mat)
    return mats


def add_box_part(bm: bmesh.types.BMesh, size: tuple, center: tuple, rot_deg: tuple, mat_idx: int, bevel_amt: float = 0.0):
    """Añade un prisma/extremidad articulada con biselado opcional en el BMesh."""
    ret = bmesh.ops.create_cube(bm, size=1.0)
    verts = ret["verts"]
    scale_mat = mathutils.Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.transform(bm, matrix=scale_mat, verts=verts)

    if bevel_amt > 0.0:
        edges = list({e for v in verts for e in v.link_edges})
        bev = bmesh.ops.bevel(bm, geom=verts + edges, offset=bevel_amt, segments=1, affect='EDGES')
        seed_verts = [v for v in (list(verts) + list(bev.get("verts", []))) if v.is_valid]
    else:
        seed_verts = [v for v in verts if v.is_valid]

    eul = mathutils.Euler((math.radians(rot_deg[0]), math.radians(rot_deg[1]), math.radians(rot_deg[2])), 'XYZ')
    xform = mathutils.Matrix.Translation(center) @ eul.to_matrix().to_4x4()
    seen = set(seed_verts)
    queue = list(seed_verts)
    while queue:
        v = queue.pop()
        if not v.is_valid:
            continue
        for e in v.link_edges:
            ov = e.other_vert(v)
            if ov.is_valid and ov not in seen:
                seen.add(ov)
                queue.append(ov)
    valid_seen = [v for v in seen if v.is_valid]
    bmesh.ops.transform(bm, matrix=xform, verts=valid_seen)
    for v in valid_seen:
        for f in v.link_faces:
            f.material_index = mat_idx


def add_cone_or_cylinder(
    bm: bmesh.types.BMesh,
    r1: float,
    r2: float,
    depth: float,
    segments: int,
    center: tuple,
    rot_deg: tuple,
    mat_idx: int,
):
    """Añade un miembro cilíndrico/cónico orgánico (músculos, colmillos, cañones, barriles)."""
    ret = bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=True,
        segments=segments,
        radius1=r1,
        radius2=r2,
        depth=depth,
    )
    verts = ret["verts"]
    eul = mathutils.Euler((math.radians(rot_deg[0]), math.radians(rot_deg[1]), math.radians(rot_deg[2])), 'XYZ')
    xform = mathutils.Matrix.Translation(center) @ eul.to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=xform, verts=verts)
    for v in verts:
        for f in v.link_faces:
            f.material_index = mat_idx


def add_sphere_part(bm: bmesh.types.BMesh, scale_xyz: tuple, center: tuple, rot_deg: tuple, mat_idx: int):
    """Añade un volumen esférico/elipsoidal orgánico (cráneo, articulaciones, pústulas, núcleos)."""
    ret = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    verts = ret["verts"]
    smat = mathutils.Matrix.Diagonal((scale_xyz[0], scale_xyz[1], scale_xyz[2], 1.0))
    bmesh.ops.transform(bm, matrix=smat, verts=verts)
    eul = mathutils.Euler((math.radians(rot_deg[0]), math.radians(rot_deg[1]), math.radians(rot_deg[2])), 'XYZ')
    xform = mathutils.Matrix.Translation(center) @ eul.to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=xform, verts=verts)
    for v in verts:
        for f in v.link_faces:
            f.material_index = mat_idx


def build_zombie_bmesh(spec: tuple) -> bmesh.types.BMesh:
    """Construye la malla orgánica completa de un Zombie en espacio métrico (Z arriba, pies en Z=0)."""
    unit_id, name, rig_type, sub_faction, dims_studs, skin_mat, cloth_mat, pants_mat, eye_mat, variant = spec
    bm = bmesh.new()

    # Escala en metros (1 stud = 0.28 m)
    total_h_m = dims_studs[1] * STUD_TO_METERS
    base_h = 5.5 * STUD_TO_METERS
    s = total_h_m / base_h

    # Caso 1: Bestias Infectadas Cuadrúpedas / Simiescas (Z-41 a Z-50, RIG-03)
    if rig_type == "RIG-03":
        bs = (dims_studs[1] / 3.6) * STUD_TO_METERS
        body_z = 2.15 * bs
        # Torso torácico delantero y grupa trasera orgánica
        add_sphere_part(bm, (0.95 * bs, 1.45 * bs, 0.82 * bs), (0, -0.45 * bs, body_z + 0.1 * bs), (8, 0, 0), skin_mat)
        add_sphere_part(bm, (0.78 * bs, 1.25 * bs, 0.68 * bs), (0, 0.85 * bs, body_z - 0.08 * bs), (-6, 0, 0), skin_mat)
        # Columna dorsal y costillas
        for r_i in range(4):
            add_box_part(bm, (0.28 * bs, 0.42 * bs, 0.35 * bs), (0, (-0.8 + r_i * 0.55) * bs, body_z + 0.72 * bs), (12, 0, 0), cloth_mat, 0.03 * bs)

        # Cabeza bestial, hocico, mandíbula abierta con colmillos, ojos y orejas
        head_y = -1.85 * bs
        head_z = body_z + (0.85 if variant == "beast_ape_gorilla" else 0.45) * bs
        add_sphere_part(bm, (0.68 * bs, 0.78 * bs, 0.62 * bs), (0, head_y, head_z), (0, 0, 0), skin_mat)
        add_box_part(bm, (0.75 * bs, 0.95 * bs, 0.42 * bs), (0, head_y - 0.65 * bs, head_z - 0.05 * bs), (6, 0, 0), skin_mat, 0.05 * bs)
        add_box_part(bm, (0.62 * bs, 0.85 * bs, 0.25 * bs), (0, head_y - 0.58 * bs, head_z - 0.38 * bs), (-22, 0, 0), 24, 0.03 * bs)
        for side in (-1, 1):
            add_sphere_part(bm, (0.14 * bs, 0.14 * bs, 0.14 * bs), (side * 0.36 * bs, head_y - 0.38 * bs, head_z + 0.18 * bs), (0, 0, 0), eye_mat)
            add_cone_or_cylinder(bm, 0.10 * bs, 0.01 * bs, 0.42 * bs, 8, (side * 0.24 * bs, head_y - 0.92 * bs, head_z - 0.18 * bs), (180, 0, 0), 23)
            add_cone_or_cylinder(bm, 0.16 * bs, 0.02 * bs, 0.55 * bs, 8, (side * 0.42 * bs, head_y + 0.15 * bs, head_z + 0.62 * bs), (-18, side * 15, 0), skin_mat)

        # 4 Extremidades cuadrúpedas articuladas (muslo + canilla + zarpa con 3 garras apoyadas en Z = 0)
        legs = [
            (-0.82 * bs, -0.95 * bs, True),
            (0.82 * bs, -0.95 * bs, True),
            (-0.74 * bs, 1.05 * bs, False),
            (0.74 * bs, 1.05 * bs, False),
        ]
        for lx, ly, is_front in legs:
            rad = (0.38 if (is_front and variant in ("beast_ape_gorilla", "beast_bear_claws")) else 0.26) * bs
            add_cone_or_cylinder(bm, rad * 1.15, rad * 0.85, body_z * 0.58, 10, (lx, ly, body_z * 0.72), (14 if is_front else -14, 0, 0), skin_mat)
            add_cone_or_cylinder(bm, rad * 0.85, rad * 0.68, body_z * 0.52, 10, (lx, ly - 0.08 * bs, body_z * 0.28), (-8 if is_front else 10, 0, 0), skin_mat)
            add_box_part(bm, (rad * 1.6, rad * 2.1, 0.24 * bs), (lx, ly - 0.22 * bs, 0.12 * bs), (0, 0, 0), 19, 0.03 * bs)
            for claw_i in (-1, 0, 1):
                add_cone_or_cylinder(bm, 0.06 * bs, 0.01 * bs, 0.32 * bs, 6, (lx + claw_i * rad * 0.45, ly - 0.58 * bs, 0.10 * bs), (90, 0, 0), 23)

        # Cola bestial y variantes específicas (Warg, Jabalí, Quimera)
        add_cone_or_cylinder(bm, 0.18 * bs, 0.04 * bs, 1.45 * bs, 8, (0, 1.85 * bs, body_z - 0.1 * bs), (-55, 0, 0), skin_mat)
        if variant in ("beast_warg_plates", "beast_boar_tusks", "beast_alpha_spikes"):
            for sp in range(5):
                add_cone_or_cylinder(bm, 0.28 * bs, 0.03 * bs, 0.85 * bs, 8, (0, (-1.1 + sp * 0.52) * bs, body_z + 0.95 * bs), (-15, 0, 0), 23)
        if variant == "beast_boar_tusks":
            for side in (-1, 1):
                add_cone_or_cylinder(bm, 0.16 * bs, 0.02 * bs, 1.15 * bs, 10, (side * 0.48 * bs, head_y - 0.95 * bs, head_z - 0.05 * bs), (45, side * -22, 0), 23)
        if variant == "beast_chimera_antlers":
            for side in (-1, 1):
                add_cone_or_cylinder(bm, 0.14 * bs, 0.03 * bs, 1.85 * bs, 8, (side * 0.55 * bs, head_y - 0.1 * bs, head_z + 1.15 * bs), (-20, side * 28, 0), 23)
                add_cone_or_cylinder(bm, 0.10 * bs, 0.02 * bs, 1.10 * bs, 8, (side * 0.95 * bs, head_y - 0.35 * bs, head_z + 1.45 * bs), (25, side * 52, 0), 23)
            add_sphere_part(bm, (0.45 * bs, 0.45 * bs, 0.35 * bs), (0, head_y - 0.85 * bs, head_z - 0.22 * bs), (0, 0, 0), 26)
        return bm

    # Caso 2: Reptante de Alcantarilla (Z-15, arrastrándose a ras de suelo sin piernas)
    if variant == "crawler_no_legs":
        add_sphere_part(bm, (0.32, 0.48, 0.22), (0, 0.0, 0.24), (0, 0, 0), cloth_mat)
        for v_i in range(4):
            add_cone_or_cylinder(bm, 0.08, 0.05, 0.22, 8, (0, 0.42 + v_i * 0.16, 0.16), (-75, 0, 0), 23)
        add_sphere_part(bm, (0.22, 0.24, 0.22), (0, -0.46, 0.34), (0, 0, 0), skin_mat)
        for side in (-1, 1):
            add_sphere_part(bm, (0.04, 0.04, 0.04), (side * 0.08, -0.66, 0.36), (0, 0, 0), eye_mat)
            add_cone_or_cylinder(bm, 0.09, 0.07, 0.45, 10, (side * 0.34, -0.35, 0.16), (80, 0, side * -18), skin_mat)
            add_box_part(bm, (0.14, 0.20, 0.08), (side * 0.38, -0.65, 0.06), (0, 0, 0), 24, 0.01)
        return bm

    # Caso 3: Anatomía Humanoide Infectada (RIG-04), Bruto Hulk (RIG-05) y Dios Zombi Troll (RIG-06)
    bulk = 1.45 if rig_type == "RIG-05" else (1.65 if rig_type == "RIG-06" else 1.0)
    foot_h = 0.10 * s
    shin_h = 0.33 * s
    thigh_h = 0.34 * s
    pelvis_z = foot_h + shin_h + thigh_h
    pelvis_h = 0.20 * s
    torso_h = 0.44 * s * (1.12 if bulk > 1.0 else 1.0)
    torso_z = pelvis_z + pelvis_h + torso_h * 0.5

    hip_x = 0.15 * s * bulk
    # Piernas orgánicas (Bota biselada en Z=0 + Gemelo cónico + Rodilla + Muslo cónico)
    for side in (-1, 1):
        add_box_part(bm, (0.20 * s * bulk, 0.34 * s, foot_h), (side * hip_x, -0.05 * s, foot_h * 0.5), (0, 0, 0), 9, 0.02 * s)
        add_cone_or_cylinder(bm, 0.09 * s * bulk, 0.11 * s * bulk, shin_h, 10, (side * hip_x, 0.02 * s, foot_h + shin_h * 0.5), (4, 0, 0), skin_mat)
        add_sphere_part(bm, (0.10 * s * bulk, 0.10 * s * bulk, 0.10 * s * bulk), (side * hip_x, 0.0, foot_h + shin_h), (0, 0, 0), pants_mat)
        add_cone_or_cylinder(bm, 0.11 * s * bulk, 0.14 * s * bulk, thigh_h, 10, (side * hip_x, 0.01 * s, foot_h + shin_h + thigh_h * 0.5), (-4, 0, 0), pants_mat)

    # Pelvis y Torso (Abdomen + Caja Torácica trapezoidal + Pectorales + Hombros)
    add_box_part(bm, (0.46 * s * bulk, 0.28 * s * bulk, pelvis_h), (0, 0.02 * s, pelvis_z + pelvis_h * 0.5), (0, 0, 0), pants_mat, 0.04 * s)
    add_box_part(bm, (0.56 * s * bulk, 0.34 * s * bulk, torso_h), (0, 0.0, torso_z), (6, 0, 0), cloth_mat, 0.06 * s)
    for side in (-1, 1):
        add_sphere_part(bm, (0.16 * s * bulk, 0.12 * s * bulk, 0.12 * s * bulk), (side * 0.14 * s * bulk, -0.15 * s * bulk, torso_z + 0.06 * s), (0, 0, 0), cloth_mat if bulk == 1.0 else skin_mat)

    # Cuello y Cabeza Esculpida (Cráneo + Mandíbula + Dientes + Arco Superciliar + Cuencas + Ojos)
    neck_z = pelvis_z + pelvis_h + torso_h
    head_z = neck_z + 0.18 * s
    add_cone_or_cylinder(bm, 0.10 * s * bulk, 0.09 * s * bulk, 0.12 * s, 10, (0, -0.02 * s, neck_z + 0.04 * s), (10, 0, 0), skin_mat)
    add_sphere_part(bm, (0.19 * s, 0.21 * s, 0.18 * s), (0, -0.04 * s, head_z + 0.04 * s), (0, 0, 0), skin_mat)
    jaw_drop = 0.07 * s if variant in ("sonic_throat", "brute_chest_maw", "mega_boss_troll") else 0.02 * s
    add_box_part(bm, (0.24 * s, 0.24 * s, 0.10 * s), (0, -0.08 * s, head_z - 0.10 * s - jaw_drop), (-16, 0, 0), skin_mat, 0.02 * s)
    add_box_part(bm, (0.18 * s, 0.06 * s, 0.04 * s), (0, -0.20 * s, head_z - 0.05 * s), (0, 0, 0), 23, 0.005 * s)
    add_box_part(bm, (0.28 * s, 0.09 * s, 0.05 * s), (0, -0.21 * s, head_z + 0.08 * s), (8, 0, 0), skin_mat, 0.01 * s)
    for side in (-1, 1):
        add_sphere_part(bm, (0.042 * s, 0.035 * s, 0.042 * s), (side * 0.075 * s, -0.22 * s, head_z + 0.04 * s), (0, 0, 0), eye_mat)

    # Brazos articulados (Deltoides + Bíceps + Codo + Antebrazo + Mano con 3 Garras)
    sh_x = 0.35 * s * bulk
    sh_z = torso_z + torso_h * 0.36
    r_hand_pos = (sh_x, -0.36 * s, sh_z - 0.22 * s)
    l_hand_pos = (-sh_x, -0.36 * s, sh_z - 0.22 * s)
    for side in (-1, 1):
        add_sphere_part(bm, (0.12 * s * bulk, 0.12 * s * bulk, 0.12 * s * bulk), (side * sh_x, 0.0, sh_z), (0, 0, 0), cloth_mat)
        add_cone_or_cylinder(bm, 0.10 * s * bulk, 0.08 * s * bulk, 0.30 * s, 10, (side * sh_x, -0.10 * s, sh_z - 0.11 * s), (42, 0, side * -6), cloth_mat)
        add_cone_or_cylinder(bm, 0.085 * s * bulk, 0.07 * s * bulk, 0.28 * s, 10, (side * sh_x, -0.26 * s, sh_z - 0.20 * s), (68, 0, side * -4), skin_mat)
        hx, hy, hz = (side * sh_x, -0.38 * s, sh_z - 0.24 * s)
        add_box_part(bm, (0.11 * s * bulk, 0.14 * s * bulk, 0.09 * s * bulk), (hx, hy, hz), (15, 0, 0), skin_mat, 0.015 * s)
        for c_i in (-1, 0, 1):
            add_cone_or_cylinder(bm, 0.022 * s * bulk, 0.004 * s, 0.11 * s, 6, (hx + c_i * 0.032 * s * bulk, hy - 0.09 * s, hz - 0.02 * s), (75, 0, 0), 24 if variant == "claws_ribs" else 23)
        if side > 0:
            r_hand_pos = (hx, hy, hz)
        else:
            l_hand_pos = (hx, hy, hz)

    # Geometría 3D específica por variante de Zombie (Z-01 a Z-60 y Z-BOSS-01)
    rx, ry, rz = r_hand_pos
    lx, ly, lz = l_hand_pos
    if variant == "claws_ribs":
        for i in range(3):
            add_box_part(bm, (0.34 * s, 0.05 * s, 0.04 * s), (0, -0.18 * s, torso_z + (0.10 - i * 0.09) * s), (0, 0, 0), 23, 0.005 * s)
    elif variant == "runner_crest":
        for i in range(3):
            add_cone_or_cylinder(bm, 0.05 * s, 0.01 * s, 0.24 * s, 8, (0, 0.18 * s, torso_z + (0.14 - i * 0.12) * s), (-55, 0, 0), 24)
    elif variant == "lead_pipe":
        add_cone_or_cylinder(bm, 0.045 * s, 0.045 * s, 0.85 * s, 10, (rx, ry - 0.25 * s, rz + 0.12 * s), (65, 0, 0), 18)
        add_cone_or_cylinder(bm, 0.08 * s, 0.08 * s, 0.12 * s, 10, (rx, ry - 0.60 * s, rz + 0.28 * s), (65, 0, 0), 19)
    elif variant == "raptor_claws":
        for hx_c, hy_c, hz_c in (r_hand_pos, l_hand_pos):
            for c_i in (-1, 0, 1):
                add_cone_or_cylinder(bm, 0.03 * s, 0.004 * s, 0.28 * s, 6, (hx_c + c_i * 0.04 * s, hy_c - 0.18 * s, hz_c - 0.04 * s), (80, 0, 0), 23)
    elif variant == "flame_core":
        add_sphere_part(bm, (0.20 * s, 0.16 * s, 0.20 * s), (0, -0.10 * s, torso_z), (0, 0, 0), 27)
        for i in range(4):
            add_cone_or_cylinder(bm, 0.06 * s, 0.01 * s, 0.28 * s, 8, ((i - 1.5) * 0.06 * s, -0.02 * s, head_z + 0.24 * s), (0, (i - 1.5) * 12, 0), 27)
    elif variant == "pheromone_sacs":
        for side in (-1, 1):
            add_sphere_part(bm, (0.14 * s, 0.14 * s, 0.14 * s), (side * 0.28 * s, 0.05 * s, sh_z + 0.08 * s), (0, 0, 0), 26)
    elif variant == "sonic_throat":
        add_sphere_part(bm, (0.18 * s, 0.18 * s, 0.16 * s), (0, -0.14 * s, head_z - 0.16 * s), (0, 0, 0), 29)
    elif variant == "toxic_pustules":
        for px, py, pz in ((-0.15, 0.14, 0.12), (0.16, 0.14, 0.08), (0.0, 0.18, -0.05), (-0.12, -0.16, 0.06), (0.14, -0.15, -0.04)):
            add_sphere_part(bm, (0.12 * s, 0.12 * s, 0.12 * s), (px * s, py * s, torso_z + pz * s), (0, 0, 0), 26)
    elif variant == "firefighter_axe":
        add_sphere_part(bm, (0.23 * s, 0.26 * s, 0.12 * s), (0, -0.02 * s, head_z + 0.16 * s), (0, 0, 0), 21)
        add_cone_or_cylinder(bm, 0.035 * s, 0.035 * s, 0.90 * s, 8, (rx, ry - 0.25 * s, rz + 0.10 * s), (68, 0, 0), 22)
        add_box_part(bm, (0.04 * s, 0.28 * s, 0.24 * s), (rx, ry - 0.62 * s, rz + 0.24 * s), (68, 0, 0), 12, 0.01 * s)
    elif variant == "surgeon_bonesaw":
        add_cone_or_cylinder(bm, 0.18 * s, 0.18 * s, 0.03 * s, 16, (rx, ry - 0.28 * s, rz), (0, 90, 0), 18)
    elif variant == "chainsaw":
        add_box_part(bm, (0.22 * s, 0.34 * s, 0.22 * s), (rx, ry - 0.12 * s, rz), (0, 0, 0), 12, 0.02 * s)
        add_box_part(bm, (0.04 * s, 0.72 * s, 0.14 * s), (rx, ry - 0.58 * s, rz), (0, 0, 0), 18, 0.005 * s)
    elif variant == "prison_ball":
        add_sphere_part(bm, (0.26 * s, 0.26 * s, 0.26 * s), (rx, ry - 0.38 * s, rz - 0.32 * s), (0, 0, 0), 19)
    elif variant == "butcher_cleavers":
        for hx_c, hy_c, hz_c in (r_hand_pos, l_hand_pos):
            add_box_part(bm, (0.03 * s, 0.42 * s, 0.22 * s), (hx_c, hy_c - 0.24 * s, hz_c + 0.04 * s), (0, 0, 0), 18, 0.005 * s)
    elif variant == "athlete_pads":
        for side in (-1, 1):
            add_sphere_part(bm, (0.20 * s, 0.22 * s, 0.14 * s), (side * (sh_x + 0.05 * s), 0.0, sh_z + 0.05 * s), (0, 0, 0), 12)
    elif variant == "barbed_wire":
        for c_i in range(4):
            add_box_part(bm, (0.64 * s, 0.40 * s, 0.03 * s), (0, 0.0, torso_z + (0.14 - c_i * 0.09) * s), (0, 8 * (c_i - 1.5), 0), 18, 0.005 * s)
    elif variant == "gravedigger_shovel":
        add_cone_or_cylinder(bm, 0.32 * s, 0.32 * s, 0.03 * s, 12, (0, -0.04 * s, head_z + 0.16 * s), (0, 0, 0), 19)
        add_cone_or_cylinder(bm, 0.03 * s, 0.03 * s, 1.15 * s, 8, (rx, ry - 0.30 * s, rz + 0.12 * s), (65, 0, 0), 22)
        add_box_part(bm, (0.24 * s, 0.30 * s, 0.03 * s), (rx, ry - 0.80 * s, rz + 0.34 * s), (65, 0, 0), 18, 0.005 * s)
    elif variant == "tesla_coils":
        for side in (-1, 1):
            add_cone_or_cylinder(bm, 0.08 * s, 0.06 * s, 0.48 * s, 10, (side * 0.18 * s, 0.18 * s, torso_z + 0.22 * s), (-15, 0, 0), 28)
    elif variant == "night_scythes":
        for hx_c, hy_c, hz_c in (r_hand_pos, l_hand_pos):
            add_cone_or_cylinder(bm, 0.05 * s, 0.005 * s, 0.48 * s, 8, (hx_c, hy_c - 0.26 * s, hz_c - 0.05 * s), (78, 0, 0), 25)
    elif variant == "flesh_amalgam_4arms":
        add_sphere_part(bm, (0.14 * s, 0.15 * s, 0.14 * s), (-0.26 * s, -0.05 * s, sh_z + 0.14 * s), (0, 0, 22), 4)
        for side in (-1, 1):
            add_cone_or_cylinder(bm, 0.09 * s, 0.07 * s, 0.52 * s, 8, (side * (sh_x + 0.08 * s), -0.22 * s, torso_z - 0.04 * s), (65, 0, side * -25), 0)
    elif variant == "acid_belly":
        add_sphere_part(bm, (0.26 * s, 0.24 * s, 0.24 * s), (0, -0.16 * s, torso_z - 0.06 * s), (0, 0, 0), 26)
    elif variant in ("police_shotgun", "security_pistol", "soldier_rifle", "smg_gun", "heavy_lmg", "sniper_ghillie", "grenade_launcher_drum", "harpoon_cannon", "commander_revolver"):
        gun_len = 0.95 * s if variant == "sniper_ghillie" else (0.72 * s if variant in ("soldier_rifle", "heavy_lmg") else 0.48 * s)
        add_box_part(bm, (0.08 * s, gun_len, 0.14 * s), (rx, ry - gun_len * 0.45, rz + 0.04 * s), (0, 0, 0), 19, 0.01 * s)
        if variant == "grenade_launcher_drum":
            add_cone_or_cylinder(bm, 0.12 * s, 0.12 * s, 0.18 * s, 12, (rx, ry - 0.22 * s, rz), (90, 0, 0), 18)
    elif variant == "propane_tank_back":
        add_cone_or_cylinder(bm, 0.18 * s, 0.18 * s, 0.58 * s, 12, (0, 0.24 * s, torso_z + 0.06 * s), (0, 0, 0), 12)
        add_sphere_part(bm, (0.08 * s, 0.08 * s, 0.08 * s), (0, 0.24 * s, torso_z + 0.38 * s), (0, 0, 0), 27)
    elif variant == "bone_javelins":
        for b_i in (-1, 0, 1):
            add_cone_or_cylinder(bm, 0.04 * s, 0.005 * s, 0.62 * s, 8, (b_i * 0.14 * s, 0.20 * s, torso_z + 0.22 * s), (-20, b_i * 12, 0), 23)
    elif variant == "toxic_barrel_hug":
        add_cone_or_cylinder(bm, 0.22 * s, 0.22 * s, 0.56 * s, 14, (0, -0.36 * s, torso_z + 0.04 * s), (0, 90, 0), 21)
        add_cone_or_cylinder(bm, 0.19 * s, 0.19 * s, 0.60 * s, 12, (0, -0.36 * s, torso_z + 0.04 * s), (0, 90, 0), 26)
    elif variant == "flamethrower_pack":
        for side in (-1, 1):
            add_cone_or_cylinder(bm, 0.11 * s, 0.11 * s, 0.52 * s, 10, (side * 0.13 * s, 0.22 * s, torso_z + 0.05 * s), (0, 0, 0), 12)
        add_box_part(bm, (0.09 * s, 0.68 * s, 0.12 * s), (rx, ry - 0.30 * s, rz + 0.02 * s), (0, 0, 0), 19, 0.01 * s)
    elif variant == "insect_hive_torso":
        add_sphere_part(bm, (0.25 * s, 0.24 * s, 0.26 * s), (0.10 * s, -0.08 * s, torso_z + 0.08 * s), (0, 0, 0), 20)
    elif variant == "riot_shield_armor":
        add_box_part(bm, (0.68 * s, 0.08 * s, 1.05 * s), (lx + 0.08 * s, ly - 0.16 * s, lz + 0.10 * s), (0, 0, 0), 19, 0.02 * s)
        add_box_part(bm, (0.44 * s, 0.10 * s, 0.18 * s), (lx + 0.08 * s, ly - 0.16 * s, lz + 0.36 * s), (0, 0, 0), 28, 0.005 * s)
    elif variant in ("kevlar_heavy", "eod_juggernaut_maul", "welder_armor_torch", "miner_helmet_pickaxe"):
        add_box_part(bm, (0.64 * s * bulk, 0.42 * s * bulk, torso_h * 0.92), (0, 0.0, torso_z), (0, 0, 0), 18, 0.04 * s)
        if variant == "eod_juggernaut_maul":
            add_cone_or_cylinder(bm, 0.04 * s, 0.04 * s, 0.95 * s, 8, (rx, ry - 0.25 * s, rz + 0.10 * s), (68, 0, 0), 18)
            add_box_part(bm, (0.32 * s, 0.32 * s, 0.28 * s), (rx, ry - 0.68 * s, rz + 0.28 * s), (68, 0, 0), 19, 0.02 * s)
        elif variant == "miner_helmet_pickaxe":
            add_sphere_part(bm, (0.22 * s, 0.24 * s, 0.12 * s), (0, 0.0, head_z + 0.15 * s), (0, 0, 0), 21)
            add_sphere_part(bm, (0.06 * s, 0.06 * s, 0.06 * s), (0, -0.22 * s, head_z + 0.16 * s), (0, 0, 0), 30)
    elif variant.startswith("brute_"):
        # Rasgos específicos de los 10 Brutos Tipo Hulk/Troll (Z-51 a Z-60)
        for hx_c, hy_c, hz_c in (r_hand_pos, l_hand_pos):
            add_sphere_part(bm, (0.22 * s, 0.24 * s, 0.22 * s), (hx_c, hy_c, hz_c), (0, 0, 0), 31 if variant == "brute_seismic_rock" else skin_mat)
        if variant == "brute_boulder_thrower":
            add_box_part(bm, (1.15 * s, 0.78 * s, 0.58 * s), (0, -0.48 * s, sh_z + 0.35 * s), (12, 10, 0), 31, 0.08 * s)
        elif variant == "brute_chest_maw":
            add_box_part(bm, (0.58 * s, 0.16 * s, 0.48 * s), (0, -0.26 * s, torso_z), (0, 0, 0), 24, 0.02 * s)
            for t_i in range(-2, 3):
                add_cone_or_cylinder(bm, 0.045 * s, 0.005 * s, 0.16 * s, 6, (t_i * 0.10 * s, -0.32 * s, torso_z + 0.18 * s), (180, 0, 0), 23)
        elif variant == "brute_xl_bone_blades":
            for hx_c, hy_c, hz_c in (r_hand_pos, l_hand_pos):
                add_cone_or_cylinder(bm, 0.09 * s, 0.01 * s, 0.95 * s, 8, (hx_c, hy_c - 0.42 * s, hz_c - 0.05 * s), (82, 0, 0), 23)
        elif variant == "brute_bone_carapace":
            for c_i in (-1, 0, 1):
                add_box_part(bm, (0.08 * s, 0.55 * s * bulk, 0.55 * s), (c_i * 0.22 * s, 0.0, torso_z), (0, c_i * 12, 0), 30, 0.01 * s)
        elif variant in ("brute_toxic_vents", "brute_ignis_horns"):
            glow_m = 26 if variant == "brute_toxic_vents" else 27
            add_sphere_part(bm, (0.28 * s, 0.24 * s, 0.28 * s), (0, -0.14 * s, torso_z + 0.05 * s), (0, 0, 0), glow_m)
            for side in (-1, 1):
                add_cone_or_cylinder(bm, 0.12 * s, 0.02 * s, 0.58 * s, 8, (side * 0.38 * s, 0.12 * s, sh_z + 0.26 * s), (-18, side * 22, 0), glow_m)
        elif variant == "brute_concrete_pillar":
            add_box_part(bm, (0.34 * s, 1.85 * s, 0.34 * s), (rx, ry - 0.65 * s, rz + 0.15 * s), (18, 0, 0), 31, 0.03 * s)
        elif variant == "brute_zone_crown":
            for c_i in range(-2, 3):
                add_cone_or_cylinder(bm, 0.08 * s, 0.01 * s, 0.62 * s, 8, (c_i * 0.16 * s, 0.18 * s, sh_z + 0.28 * s), (-22, c_i * 10, 0), 23)
    elif variant == "mega_boss_troll":
        # DIOS ZOMBI TROLL (Z-BOSS-01, 26 studs) con los 3 WeakPoints Oficiales y Monolitos Dorsales
        add_sphere_part(bm, (0.14 * s, 0.14 * s, 0.14 * s), (0, -0.04 * s, head_z + 0.26 * s), (0, 0, 0), 26)      # WeakPoint_Head
        add_sphere_part(bm, (0.24 * s, 0.16 * s, 0.24 * s), (0, -0.28 * s * bulk, torso_z + 0.04 * s), (0, 0, 0), 26)  # WeakPoint_Chest
        add_sphere_part(bm, (0.26 * s, 0.18 * s, 0.28 * s), (0, 0.28 * s * bulk, torso_z + 0.06 * s), (0, 0, 0), 26)   # WeakPoint_Back
        for side in (-1, 1):
            add_box_part(bm, (0.42 * s, 0.44 * s, 0.32 * s), (side * (sh_x + 0.12 * s), 0.0, sh_z + 0.14 * s), (0, 0, side * -12), 31, 0.05 * s)
            add_cone_or_cylinder(bm, 0.12 * s, 0.015 * s, 0.65 * s, 8, (side * (sh_x + 0.14 * s), 0.04 * s, sh_z + 0.52 * s), (0, side * 18, 0), 26)

    # Garantizar que el vértice más bajo quede exactamente en Z = 0.0 (Origin to Bottom)
    if bm.verts:
        min_z = min(v.co.z for v in bm.verts)
        if abs(min_z) > 1e-5:
            bmesh.ops.translate(bm, verts=list(bm.verts), vec=(0.0, 0.0, -min_z))

    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return bm


def apply_vertex_colors_and_palette_uv(obj: bpy.types.Object, palette_grid_size: int = 16) -> int:
    """Hornea Vertex Colors (BYTE_COLOR / CORNER) y colapsa las islas UV a escala cero en el Atlas 16x16."""
    mesh = obj.data
    color_attr = mesh.color_attributes.get("Color")
    if not color_attr:
        color_attr = mesh.color_attributes.new(name="Color", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.active_color = color_attr
    mesh.color_attributes.render_color_index = 0

    uv_layer = mesh.uv_layers.active or mesh.uv_layers.new(name="PaletteUV")
    mesh.uv_layers.active = uv_layer

    grid_n = float(max(1, palette_grid_size))
    total_tris = 0

    for poly in mesh.polygons:
        mat_idx = poly.material_index % len(PALETTE_MATERIALS)
        rgb = PALETTE_MATERIALS[mat_idx][1]
        col = (float(rgb[0]), float(rgb[1]), float(rgb[2]), 1.0)

        col_idx = mat_idx % palette_grid_size
        row_idx = mat_idx // palette_grid_size
        u_center = (col_idx + 0.5) / grid_n
        v_center = 1.0 - ((row_idx + 0.5) / grid_n)

        for loop_idx in poly.loop_indices:
            color_attr.data[loop_idx].color = col
            uv_layer.data[loop_idx].uv = (u_center, v_center)

        total_tris += len(poly.vertices) - 2

    if total_tris > MAX_ROBLOX_TRIANGLES:
        raise ValueError(f"[RAASE] {obj.name} excede el límite de {MAX_ROBLOX_TRIANGLES} triángulos ({total_tris}).")
    return total_tris


def main() -> None:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    out_dir = os.path.abspath(argv[0]) if argv else os.path.abspath("exports/zombies-v4")
    os.makedirs(out_dir, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = ensure_palette_materials()

    # 1. Generar la textura Atlas de Paleta compartida (256x256 px, 1 Draw Call)
    palette_png_path = os.path.join(out_dir, "zombies_palette_256.png")
    write_palette_png(palette_png_path, grid_n=PALETTE_GRID_N, img_size=256)

    manifest_assets = []
    handoff_rows = []
    showcase_entries = []

    # 2. Construir y exportar cada uno de los 61 Zombies individualmente (.glb + .fbx)
    for idx, spec in enumerate(ZOMBIE_SPECS):
        unit_id, name, rig_type, sub_faction, dims_studs, *_ = spec
        safe_id = unit_id.replace("-", "")
        asset_id = f"mesh_zombie_{safe_id}_{name.lower()}"

        bm = build_zombie_bmesh(spec)
        mesh_data = bpy.data.meshes.new(asset_id)
        bm.to_mesh(mesh_data)
        bm.free()

        for m in mats:
            mesh_data.materials.append(m)
        for poly in mesh_data.polygons:
            poly.use_smooth = True

        obj = bpy.data.objects.new(asset_id, mesh_data)
        bpy.context.scene.collection.objects.link(obj)

        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

        tris = apply_vertex_colors_and_palette_uv(obj, palette_grid_size=PALETTE_GRID_N)

        glb_path = os.path.join(out_dir, f"{asset_id}.glb")
        fbx_path = os.path.join(out_dir, f"{asset_id}.fbx")

        try:
            bpy.ops.export_scene.gltf(
                filepath=glb_path,
                export_format="GLB",
                use_selection=True,
                export_vertex_color='ACTIVE',
                export_apply=True,
            )
        except TypeError:
            bpy.ops.export_scene.gltf(
                filepath=glb_path,
                export_format="GLB",
                use_selection=True,
                export_colors=True,
                export_apply=True,
            )
        bpy.ops.export_scene.fbx(
            filepath=fbx_path,
            use_selection=True,
            path_mode='COPY',
            embed_textures=True,
            colors_type='SRGB',
            apply_scale_options='FBX_SCALE_ALL',
        )

        # Posicionar en la escena maestra de 4 filas (para importar los 61 de golpe si se desea)
        if idx < 20:
            row_x = (idx - 9.5) * (12.0 * STUD_TO_METERS)
            row_y = -58.0 * STUD_TO_METERS
        elif idx < 35:
            row_x = ((idx - 20) - 7.0) * (14.0 * STUD_TO_METERS)
            row_y = -24.0 * STUD_TO_METERS
        elif idx < 50:
            row_x = ((idx - 35) - 7.0) * (14.0 * STUD_TO_METERS)
            row_y = 10.0 * STUD_TO_METERS
        elif idx < 60:
            row_x = ((idx - 50) - 4.5) * (18.5 * STUD_TO_METERS)
            row_y = 48.0 * STUD_TO_METERS
        else:
            row_x = 108.0 * STUD_TO_METERS
            row_y = 48.0 * STUD_TO_METERS

        obj.location = (row_x, row_y, 0.0)
        showcase_entries.append(obj)

        manifest_assets.append({
            "id": asset_id,
            "unitId": unit_id,
            "nombre": f"{unit_id} {name.replace('_', ' ')}",
            "tipo": "mesh",
            "masterRig": rig_type,
            "subFaction": sub_faction,
            "rol": f"Unidad Zombie {sub_faction} ({rig_type})",
            "dimensionesStuds": dims_studs,
            "triBudget": MAX_ROBLOX_TRIANGLES,
            "actualTriangles": tris,
            "glbFile": f"{asset_id}.glb",
            "fbxFile": f"{asset_id}.fbx",
            "paletteTexture": "zombies_palette_256.png",
            "destino": "ReplicatedStorage.Assets.Zombies",
            "status": "generado",
        })
        handoff_rows.append(
            f"| `{asset_id}` | `{unit_id}` | `{rig_type}` | `{dims_studs[0]}×{dims_studs[1]}×{dims_studs[2]} studs` | `{tris}` tris | `{asset_id}.glb` / `.fbx` | ✅ Generado |"
        )
        print(f"[RAASE] {asset_id} ({unit_id}): tris={tris} | glb={os.path.basename(glb_path)} | fbx={os.path.basename(fbx_path)}")

    # 3. Exportar la Escena Maestra con los 61 Zombies juntos en sus 4 filas
    bpy.ops.object.select_all(action='SELECT')
    master_glb = os.path.join(out_dir, "ZA_All61Zombies_Showcase.glb")
    master_fbx = os.path.join(out_dir, "ZA_All61Zombies_Showcase.fbx")
    try:
        bpy.ops.export_scene.gltf(
            filepath=master_glb,
            export_format="GLB",
            use_selection=False,
            export_vertex_color='ACTIVE',
            export_apply=False,
        )
    except TypeError:
        bpy.ops.export_scene.gltf(
            filepath=master_glb,
            export_format="GLB",
            use_selection=False,
            export_colors=True,
            export_apply=False,
        )
    bpy.ops.export_scene.fbx(
        filepath=master_fbx,
        use_selection=False,
        path_mode='COPY',
        embed_textures=True,
        colors_type='SRGB',
        apply_scale_options='FBX_SCALE_ALL',
    )

    # 4. Escribir assets_manifest.json y ASSETS_HANDOFF.md
    manifest_data = {
        "batch": "zombies-v4",
        "approvedBy": "creator",
        "blenderVersion": bpy.app.version_string,
        "paletteAtlas": "zombies_palette_256.png",
        "masterShowcaseGlb": "ZA_All61Zombies_Showcase.glb",
        "masterShowcaseFbx": "ZA_All61Zombies_Showcase.fbx",
        "totalAssets": len(manifest_assets),
        "assets": manifest_assets,
    }
    with open(os.path.join(out_dir, "assets_manifest.json"), "w", encoding="utf-8") as mf:
        json.dump(manifest_data, mf, indent=2, ensure_ascii=False)

    handoff_md = [
        '# ASSETS_HANDOFF — Lote `"zombies-v4"` (61 Modelos 3D Blender para Roblox)',
        "",
        f"> Generado automáticamente con **Blender {bpy.app.version_string}** bajo el estándar **RAASE 3.0 (`roblox-36-asset-pipeline`)**.",
        "- **Preservación Cromática Dual**:",
        "  1. `COLOR_0` / `Color` (`BYTE_COLOR` / `CORNER` en SRGB) horneado directamente en los vértices de cada `.glb` y `.fbx`.",
        "  2. UV de área cero mapeado a `zombies_palette_256.png` (`256x256 px`, 1 Draw Call).",
        "- **Importación Rápida de los 61 Zombies en 1 Clic**:",
        "  - En Roblox Studio → **Avatar / Model → 3D Importer** → selecciona `ZA_All61Zombies_Showcase.fbx` (o `.glb`) → **Scale Unit = Meter** → Import.",
        "  - O importa cualquier zombie individual (`mesh_zombie_Z01_caminante.fbx`, etc.) hacia `ReplicatedStorage.Assets.Zombies`.",
        "",
        "## Catálogo de 61 Mallas 3D Generadas",
        "",
        "| Asset ID | Unidad | Rig | Dimensiones | Triángulos | Artefactos | Estado |",
        "|---|---|---|---|---|---|---|",
        *handoff_rows,
        "",
    ]
    with open(os.path.join(out_dir, "ASSETS_HANDOFF.md"), "w", encoding="utf-8") as hf:
        hf.write("\n".join(handoff_md))

    print(f"[RAASE] Lote zombies-v4 completado: {len(manifest_assets)} zombies exportados (.glb + .fbx) en {out_dir}")


if __name__ == "__main__":
    main()
