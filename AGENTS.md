# RAASE 3.0 / robloxIA — Contratos Maestros para Agentes (AGENTS.md)

Este repositorio implementa **RAASE 3.0 Next-Gen (`robloxIA`)**. Todo agente (Claude Code, OpenAI Codex, Google Antigravity, Cursor, OpenCode) debe cumplir las siguientes reglas inquebrantables de arquitectura y ejecución:

## 1. Soberanía de Rojo vs. `StudioMCP` (`bridge/mcp_doctor.mjs`)
- **Fuente única de verdad en código**: Todo módulo Luau persistente reside en `project_template/src/` y es sincronizado hacia Roblox Studio por **Rojo** (`default.project.json` -> `ReplicatedStorage.RAASE_Shared`, `ServerScriptService.RAASE_Server`, `StarterPlayerScripts.RAASE_Client`).
- **Prohibición estricta en `execute_luau`**: NUNCA edites `.Source` ni destruyas scripts dentro de contenedores sincronizados por Rojo mediante `execute_luau`. Usa `execute_luau` exclusivamente para requerir e invocar declarativamente los Módulos Maestros (`require(game:GetService("ReplicatedStorage").RAASE_Shared.<Modulo>)`) o inspeccionar el `DataModel`.
- **Resolución de ruta en Windows**: Configura `StudioMCP` usando la ruta absoluta hacia `mcp.bat` resuelta por `node bridge/mcp_doctor.mjs` (ver `mcp_config.example.json`). Nunca uses `%LOCALAPPDATA%` sin expandir en el campo `command`.
- **Herramientas Oficiales de `StudioMCP` (10 en total)**:
  1. `execute_luau`
  2. `insert_model`
  3. `generate_mesh`
  4. `generate_material`
  5. `start_stop_play`
  6. `character_navigation`
  7. `user_keyboard_input`
  8. `user_mouse_input`
  9. `get_console_output`
  10. `screen_capture`
  *(Nota: Invoca siempre `list_roblox_studios` primero para obtener el `studio_id`. Herramientas como `insert_asset`, `generate_procedural_model`, `store_image` o `upload_image` pertenecen a wrappers comunitarios y NO existen en el `StudioMCP` oficial; para insertar un `assetId` subido por Open Cloud usa `execute_luau` con `game:GetService("InsertService"):LoadAsset(assetId)` o `MCPBridge`).*

## 2. Los 4 Módulos Maestros Declarativos (`ReplicatedStorage.RAASE_Shared`)
1. **`VoxelTerrainBuilder`** (`project_template/src/shared/VoxelTerrainBuilder.luau`):
   - `VoxelTerrainBuilder.GenerateFBM(config)` (`Region3:ExpandToGrid(4)`, ruido Perlin FBM de 4–6 octavas, ocupancia fraccional continua $\in [0, 1]$, materiales automáticos por pendiente y altitud `Rock`, `Sand`, `Grass`, `Snow`, `Water`).
   - `VoxelTerrainBuilder.CarveRoadPath(points, widthStuds, roadMaterial?)` (`ReadVoxels` / `WriteVoxels`).
2. **`WorldAssembler`** (`project_template/src/shared/WorldAssembler.luau`):
   - `WorldAssembler.PlaceGrounded(model, position, options?)` (`workspace:Raycast` vertical hacia abajo + `GetExtentsSize().Y / 2` + `AlignToSlope` opcional + snapping a grilla).
   - `WorldAssembler.SmartUpsert(parent, template, name, targetPosition, options?)` (respeta `RAASE_Locked == true` bajo `RN-10`).
3. **`ProceduralAnimator`** (`project_template/src/shared/ProceduralAnimator.luau`):
   - `ProceduralAnimator.AttachIK(character, config)` (`IKControl` nativo + `BallSocketConstraint` con `LimitsEnabled = true` para jugador local, héroes y bosses; para hordas masivas mantener `Motor6D.Transform`).
   - `ProceduralAnimator.CreateSpring2D(omega0?, zeta?, initialPos?)` ($\zeta \in [0.45, 0.75]$).
   - `ProceduralAnimator.CreateFlipbookController(imageLabel, columns, rows, frameWidthPx, frameHeightPx, fps?)`.
4. **`VFXAndJuiceEngine`** (`project_template/src/shared/VFXAndJuiceEngine.luau`):
   - `VFXAndJuiceEngine.CastEffect(effectType, cframe, scale?, options?)` (5 capas: `CoreFlash` + `ShockwaveRing` + `SlashBeam` `FaceCamera = false` + `DirectionalSparks` `VelocityParallel`/`Squash = -1.5` + `VoxelDebris` con `Raycast` al suelo heredando `Material` y `Color`).
   - `VFXAndJuiceEngine.AddTrauma(amount)` (sacudida cúbica $S = T^3$ en `Enum.RenderPriority.Camera.Value + 1`).
   - `VFXAndJuiceEngine.TriggerHitFlash(targetModel, duration?)` (`Highlight` blanco `0.1 -> 1.0` en `0.12s`).
   - `VFXAndJuiceEngine.ApplyHitstop(character, frames)` y `VFXAndJuiceEngine.PlayModulatedSound(...)` ($\pm 9\%$ pitch + knockback).

## 3. Pipeline 3D con Color Garantizado y Open Cloud (`bridge/open_cloud.mjs`)
- En Blender headless (`skills-roblox/roblox-36-asset-pipeline/scripts/blender_export_example.py`), ejecuta siempre `apply_deterministic_transforms`, `bake_materials_to_vertex_colors`, `map_uv_to_palette_atlas` y `validate_mesh_budget` (`< 20,000` triángulos).
- Sube activos `.glb` (`model/gltf-binary`), `.fbx` (`model/fbx`), `.mp3`/`.ogg` y `.png` mediante `bridge/open_cloud.mjs` (`POST /assets/v1/assets`). Prohibido subir `.rbxm` sintetizados fuera de Studio.

## 4. Protocolo de QA Autónomo en Bucle Cerrado (Playtest QA + RN-11)
Toda tarea de gameplay, movimiento o combate concluye obligatoriamente ejecutando:
1. `start_stop_play` (iniciar Playtest)
2. `character_navigation` y simulación de entrada (`user_keyboard_input` / `user_mouse_input`)
3. `get_console_output` (verificando **0 errores**)
4. `screen_capture` (verificando fidelidad visual en máximo 2 pases bajo el cortacircuitos `RN-11`)
5. `start_stop_play` (detener Playtest)
