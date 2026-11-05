# Slime asset pack (`slime-v1`) — S13 reference-led cartoon models

Status: **13/13 designs generated and validated locally** with Blender 5.2.1 LTS.
The pack is not imported into Roblox Studio, not uploaded and not published. Studio
import and animation playback remain separate, unproven steps that require the official
Studio MCP transport.

## Scope and provenance (S5 / S12 / S13)

- Input: the 13 reference images in the user-provided `modelos de slimes referencia`
  folder named in S13. Each image was inspected and mapped to exactly one design slug.
- The references are **read-only inputs**. They are not copied into the pack, never
  sampled as a texture, and never redistributed. Every mesh and every texture here is
  generated procedurally by `agent/generators/blender/build_slime_assets.py`.
- Approval for the asset scope is recorded in `odd/tasks/system-overhaul.md` (L39). The
  pack restates nothing broader: no upload, cloud conversion or asset-id publication is
  authorized or implied.
- One reference file maps to one design, so the pack cannot degrade into recolours:
  each design has its own builder, its own silhouette and its own palette.

## Design map

Height is the delivered stud height and is enforced by the builder. Clip frames include
the duplicated loop end key for `Idle` (30 fps).

| slug | reference file | silhouette | height | tris | deform bones | Idle/Extract/Release |
|---|---|---|---|---|---|---|
| `classic_blue` | `Gemini_Generated_Image_o5nhsso5nhsso5nh.jfif` | rounded teardrop blob, no appendages | 3.0 | 2,904 | 2 | 41/36/30 |
| `mint_droplet` | `Gemini_Generated_Image_t4qh2st4qh2st4qh.jfif` | asymmetric droplet, hooked tip, puddle disc | 3.4 | 2,984 | 3 | 41/34/28 |
| `gel_cube` | `Gemini_Generated_Image_jnc8o6jnc8o6jnc8.jfif` | rounded cuboid with heavy corner radius | 3.4 | 3,588 | 2 | 41/36/30 |
| `spiral_slime` | `Gemini_Generated_Image_a8ausaa8ausaa8au.jfif` | 2.35-turn soft-serve helix with pointed tip | 3.6 | 5,396 | 3 | 41/34/28 |
| `faceted_crystal` | `Gemini_Generated_Image_i1vs4ci1vs4ci1vs.jfif` | round icosphere gem, 320 flat facets, inner core glow | 3.8 | 2,108 | 2 | 41/36/30 |
| `jellyfish_slime` | `Gemini_Generated_Image_g67waog67waog67w.jfif` | scalloped dome bell on six tentacles | 4.2 | 3,988 | 8 | 45/36/30 |
| `cosmic_orb` | `Gemini_Generated_Image_nnuwnfnnuwnfnnuw.jfif` | orb, two crossing thin rings, seated chest core | 4.4 | 6,700 | 8 | 45/36/30 |
| `tornado_slime` | `Gemini_Generated_Image_bsa7cpbsa7cpbsa7.jfif` | spiral funnel, flat swirl crown, wispy thin stem | 4.6 | 4,216 | 3 | 45/36/30 |
| `celestial_winged` | `Gemini_Generated_Image_ir4dd4ir4dd4ir4d.jfif` | four-blade crystal fan per wing, antlers, halo, ringed core | 5.2 | 6,072 | 5 | 49/38/32 |
| `blob_hydra` | `Gemini_Generated_Image_gqrwaggqrwaggqrw.jfif` | wide blob, three necks, three heads with a face each | 5.0 | 8,568 | 7 | 49/38/32 |
| `crystal_golem` | `Gemini_Generated_Image_7skyzw7skyzw7sky.jfif` | fused chest face, large rock shoulder fans, crystal fists | 6.5 | 8,744 | 6 | 49/40/32 |
| `dragon_hydra` | `Gemini_Generated_Image_nonte0nonte0nont.jfif` | quadruped, three crested necks, wings, three faces | 6.8 | 12,032 | 10 | 49/40/32 |
| `abyssal_leviathan` | `Gemini_Generated_Image_ofqi2cofqi2cofqi.jfif` | thick coiled serpent, large crested head, crystal mane, dorsal chain | 7.0 | 6,502 | 5 | 49/40/32 |

## Delivery contract

- **Scale:** 1 Blender unit = 1 Roblox stud. No unit conversion anywhere in the pipeline.
- **Origin:** bottom-centre. `min Z = 0`, XY centred on the vertical axis.
- **Forward:** `-Y` in Blender. After the glTF Y-up conversion this becomes `+Z` in glTF
  space; the Roblox import orientation has **not** been verified.
- **Mesh:** one merged mesh, one material, one UV set, one skin.
- **Budget:** under 20,000 triangles per mesh (delivered range 2,108–12,032).
- **Weights:** at most 4 influences per vertex, normalised to 1.0.
- **Textures:** one 1024×1024 sRGB colour map and one 1024×1024 non-colour roughness map,
  embedded in the GLB **and packed into the `.blend`** so the scene opens without them.
- **Clips:** exactly `Idle`, `Extract` and `Release`, authored on bone transforms (no
  empty tracks). `Idle` is a loop whose first and last keyed values are identical, and
  every exported rotation track is sign-normalised so no runtime interpolates the long way.
- **VFX:** Roblox-side profiles live in `project_template/src/shared/SlimeAssetVFX.luau`.
  glTF carries geometry, textures and clips only; it never carries Roblox emitters.

## Pipeline

1. **Spec** (`agent/generators/blender/slime_specs/<slug>.json`) drives palette, surface
   treatment, face placement, clip lengths, animation amplitudes and VFX lanes.
2. **Geometry** from parametric primitives: superquadrics (spheres to rounded boxes),
   geodesic icospheres (faceted gems), lathes (bells and funnels), parallel-transport
   sweeps (necks, tentacles, tails, arms), faceted shards (crystals, feathers, mane),
   scalloped membrane plates (wings, fins, crests) and tori (rings, whorls, halo).
3. **Normals** are recalculated per part before joining. This matters: recalculating
   after joining flips whole bands of the body inward, because the eye/mouth shells sit
   inside the body shell and make "outside" ambiguous.
4. **Determinism:** transforms applied, mesh recentred, then uniformly scaled so the
   delivered height equals the declared `heightStuds`. The rig is built at the same scale.
5. **UVs:** `smart_project` with a uniform remap into `0.01…0.99`.
6. **Textures:** a UV-space rasteriser walks every triangle, interpolates position and
   normal barycentrically and evaluates a procedural paint function per pixel:
   - a smooth vertical jelly gradient (no camouflage blotches),
   - spaced **round bubbles** from a deterministic cell grid (`spotScale` = bubble
     density; each bubble stays inside its cell so no hard cuts appear),
   - a restrained upper-left sheen and a counter-shaded belly,
   - per-role overrides for eyes, glints, mouth, cheeks, crystal and rock,
   - an optional `surface.coreGlow` (a soft radial inner light, used by the gem).
   Three dilation passes fill island borders. Colour is written as sRGB, roughness as raw
   non-colour.
7. **Material:** one Principled BSDF fed by both maps; every former role slot is collapsed
   to that single material after baking, and both images are packed into the `.blend`.
8. **Rig:** a light armature; weights come from distance-to-bone-segment with per-bone
   influence radii, keeping the strongest 4 and normalising.
9. **Animation:** `Idle` uses only whole-harmonic sines so the loop is exact; `Extract`
   strains and trembles; `Release` pops, overshoots and settles. Consecutive quaternions
   are kept on one hemisphere while keying.
10. **Export:** GLB with the mesh and its armature selected, `export_apply`, Y-up,
    skinning, animations, 4 influences, no vertex colours. Because the exporter converts
    each sampled matrix independently, the builder then rewrites every exported rotation
    track so consecutive quaternions share a hemisphere, and re-inspects the GLB to prove
    clip names, skins, embedded images and that normalisation before writing `stats.json`.
11. **Renders:** an EEVEE preview and a black-on-white silhouette per design, plus an
    editable `.blend` that keeps the camera, lights and ground used for the preview.
    `save_version = 0` keeps regenerated packs free of `.blend1` backups.

### Reused first-party functions

`skills-roblox/roblox-36-asset-pipeline/scripts/blender_export_example.py` supplies
`apply_deterministic_transforms` and `validate_mesh_budget`, both reused by path (the
builder fails loudly if the file is missing).

Two functions from that helper are deliberately **not** used:

- `bake_materials_to_vertex_colors` bakes flat material colours into vertex colours; the
  deliverable requires real colour and roughness PNGs, so baking solid colours would drop
  a required artifact.
- `map_uv_to_palette_atlas` collapses UV islands to a palette pixel; that would destroy
  the per-pixel detail the texture contract asks for.

`export_asset` is not used either: it calls `export_colors`, which no longer exists in
Blender 5.2.

## Commands

```powershell
node agent/generators/run_slime_assets.mjs --list
pnpm --dir bridge --config.verify-deps-before-run=false exec node --test test_slime_assets.mjs
node agent/generators/run_slime_assets.mjs --blender "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --out exports/slime-v1 --all
```

Opt-in proofs (each is skipped unless its variable is set):

```powershell
# artifact proof: parses GLBs, PNG headers, stats, exported animation tracks and .blend packing
$env:SLIME_ASSET_DIR  = "<absolute path to exports/slime-v1>"
# real Blender CLI regression: --skip-render must keep a valid model and omit both renders
$env:SLIME_BLENDER_BIN = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
pnpm --dir bridge --config.verify-deps-before-run=false exec node --test test_slime_assets.mjs
```

Useful variants: `--only classic_blue,dragon_hydra`, `--dry-run`, `--skip-render`.

## Outputs (`exports/slime-v1`, git-ignored)

```
exports/slime-v1/
  manifest.json                     # per-design status, metrics, hashes, file list
  ASSETS_HANDOFF.md                 # human summary written by the runner
  <slug>/
    <slug>.glb                      # one mesh + skin + Idle/Extract/Release, embedded textures
    <slug>.blend                    # editable scene: mesh, rig, actions, camera, lights, packed textures
    <slug>_color.png                # 1024 sRGB colour map
    <slug>_roughness.png            # 1024 non-colour roughness map
    <slug>_preview.png              # EEVEE preview render
    <slug>_silhouette.png           # black-on-white silhouette
    <slug>_stats.json               # bounds, tris, UV, rig, clips, loop error, checks
```

The tree is ignored on purpose: it is regenerable from the committed sources plus
Blender 5.2. Nothing in it is uploaded.

## Verification evidence (observed)

- Builder run: `13/13 designs verified`; every design reports `loopError = 0.00e+0` and
  `checks = 9/9` (triangle budget, normalised weights, UV range, bottom origin, clip
  count, loop identity, embedded textures, packed `.blend` textures, quaternion continuity).
- Triangle range 2,108–12,032; deform bones 2–10; heights 3.0–7.0 studs, all equal to the
  declared spec height; `min Z = 0` on every model.
- GLB inspection (parsed binary): exactly one mesh, one skin with 3–11 joints, three
  animations named `Extract`, `Idle`, `Release`, every animation with channels and
  samplers, exactly two embedded images, and a material carrying both a base colour and
  a metallic-roughness texture.
- Exported animation tracks: all rotation samples share a hemisphere (the builder counts
  and fixes exporter sign flips and records the minimum dot in each stats file).
- Round-trip: `abyssal_leviathan`, `crystal_golem`, `celestial_winged` and
  `faceted_crystal` were re-imported into fresh Blender sessions. Each returned one model
  mesh, its full armature, three actions with populated curves, two packed 1024×1024
  images, bounds sitting on `Z = 0` and at most 4 normalised influences per vertex, with
  the expected heights (7.0 / 6.5 / 5.2 / 3.8 studs). Blender's glTF importer also creates
  a small unparented `Icosphere` object as a bone display shape; it is not in the GLB.
- `.blend` readback: opened in a fresh Blender process, `crystal_golem.blend` reports both
  textures with `packed_file` set and relative `//` paths. The test suite repeats this for
  all 13 scenes.
- Behaviour tests: `bridge/test_slime_assets.mjs` passes **15/15** with both opt-in
  variables set; without them, **8 pass and 7 skip**. The suite parses real GLB binaries,
  decodes animation accessors, and opens the real `.blend` files — it never greps this
  generator for claims.

## Visual checklist for the corrected blockers

Each item was checked against the corresponding reference image and the rendered preview.

| id | design | reference expectation | delivered |
|---|---|---|---|
| B2 | `faceted_crystal` | round multi-facet gem, large happy face, inner light | icosphere gem with 320 flat facets, eyes at ~40% of body width, soft inner core glow painted into the texture |
| B3 | `crystal_golem` | face embedded in the upper torso, rock shoulder fans, crystal fists | single fused body with a chest boss face, four-blade crystal shoulder fans on rock pads, bright crystal fists, no floating head |
| B4 | `abyssal_leviathan` | thick eastern-dragon serpent, large head, mane and fins | body radius 0.4–0.6 with a rising coil, head mass roughly tripled, eight-blade mane, cheek fins, crest and dorsal chain; spine/tail bones retained |
| B5 | `celestial_winged` | multi-blade crystal fans, visible galaxy core | four blade tips per wing, ringed core protruding 0.3 studs on the chest, cyan-to-purple gradient |
| B6 | `tornado_slime` | spiral ribbons, flat swirl top, wispy base | helical funnel ridges plus two continuous ribbons, flared dish crown, thin stem with wisps, no horizontal hoops and no goblet rim |

## Known limits

- **No Studio proof.** Local GLB/FBX files cannot be imported through the official MCP
  toolset available here (`insert_asset` needs an existing Roblox asset id). Animation
  playback in Roblox, LOD generation and lighting behaviour are untested.
- **No upload or publication.** No mesh, texture, animation or sound id is defined.
- **No catalog binding.** Asset slugs are design identities; the gameplay catalog and
  rarity mapping intentionally stay in the gameplay layer. `SlimeAssetVFX` is not mapped
  in `project_template/slime.project.json`.
- **Sound ids are absent by design.** `SlimeAssetVFX` passes a `soundId` only when the
  caller supplies one.
- Texture colour round-trip error is about 0.02 in sRGB units (8-bit quantisation); each
  `stats.json` records the measured value.
- The `.blend` files keep the preview camera, lights and ground plane; delete those
  objects if a clean export scene is preferred. Older `<slug>.blend1` backups from runs
  before `save_version = 0` may still sit in the output tree.
