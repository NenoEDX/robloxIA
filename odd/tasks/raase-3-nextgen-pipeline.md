Objective: Evolucionar `robloxIA` (RAASE 2.1 → Next-Gen 3.0) con coexistencia Rojo + `StudioMCP` + `MCPBridge`, pipeline 3D con color garantizado (Vertex Colors + Palette Atlas UV + Open Cloud `.glb`/`.fbx`), 4 Módulos Maestros declarativos Luau (`VoxelTerrainBuilder`, `WorldAssembler`, `ProceduralAnimator`, `VFXAndJuiceEngine`) y contratos cerrados de Playtest QA.
Branch: `feat/raase-3-nextgen-pipeline` | Delivery: work-unit commits por fase (Conventional Commits) | Test runner: `node --test`

## Specs

- **S1 — Fase 1 (Orquestación Dual MCP y Coexistencia con Rojo)**:
  - Pedido textual del usuario: `"cambiado de modelo para que analice el .md o pdf si es posible para preparar un plan, es valido investigar si los puntos que investigue son validos puntos ciegos o problemas teoricos que no se vieron durante la investigacion si es viable para hacer los mejores juegos en el menor tiempo posible, investiga busca referencias si encuentras la misma conclusion haz el plan y si no  con la informacion nueva tambien, y  que sea viable que haga todas esas cosas como un profesional"` y `"continua"`.
  - Alcance autorizado:
    1. Plantilla `mcp_config.example.json` con resolución de ruta absoluta para el ejecutable oficial `StudioMCP` (`mcp.bat` sin variables `%LOCALAPPDATA%` sin expandir), notas de enrutamiento `studio_id` (`list_roblox_studios`) y coexistencia con `MCPBridge` (`localhost:7843`).
    2. Regla de soberanía Rojo vs. `StudioMCP`: prohibido editar scripts persistentes directamente en Studio vía `execute_luau`; todo módulo persistente vive en `project_template/src/` sincronizado por Rojo (`default.project.json`).
    3. Script verificador `bridge/mcp_doctor.mjs` y suite de tests `bridge/test_mcp_doctor.mjs` que auditen la configuración MCP, la presencia de Rojo (`default.project.json`), el mapeo de herramientas reales de `StudioMCP` vs. wrappers comunitarios y las variables Open Cloud.
  - Checks aplicables: `node --test bridge/test_mcp_doctor.mjs`.

- **S2 — Fase 2 (Pipeline 3D con Color Garantizado y Open Cloud v1/assets)**:
  - Alcance autorizado:
    1. Actualizar `skills-roblox/roblox-36-asset-pipeline/scripts/blender_export_example.py` para proveer ambas estrategias de color sin pérdida en exportación headless:
       - `bake_materials_to_vertex_colors(obj)` (`mesh.color_attributes` con `BYTE_COLOR` / `CORNER` y render activo).
       - `map_uv_to_palette_atlas(obj, palette_grid_size=16)` (colapso de islas UV a escala `(0, 0)` centradas en el píxel `(u + 0.5) / N, 1.0 - (v + 0.5) / N`).
       - Aplicación determinista de transformaciones (`location=True, rotation=True, scale=True`, `1 stud = 0.28m`) y validación estricta `< 20,000` triángulos por malla (`validate_mesh_budget`).
    2. Extender `bridge/open_cloud.mjs` para soportar `.fbx` (`model/fbx`) además de `.glb` (`model/gltf-binary`), `.mp3` (`audio/mpeg`) y `.png` (`image/png`), exponer validación de presupuesto y helper de manifiesto `rbxassetid://<assetId>`, con tests unitarios en `bridge/test_open_cloud.mjs`.
  - Checks aplicables: `node --test bridge/test_open_cloud.mjs`.

- **S3 — Fase 3 (Los 4 Módulos Maestros Declarativos en `project_template/src/shared/`)**:
  - Alcance autorizado:
    1. `project_template/src/shared/VoxelTerrainBuilder.luau` (`--!strict`): `GenerateFBM(config)` con `Region3:ExpandToGrid(4)`, ruido Perlin FBM de 4–6 octavas (`math.noise`), ocupancia fraccional $\in [0, 1]$, asignación automática de materiales por pendiente/altitud (`Rock`, `Sand`, `Grass`, `Snow`), chunking con `task.wait()`, y `CarveRoadPath(points, widthStuds, material?)` usando `ReadVoxels`/`WriteVoxels`.
    2. `project_template/src/shared/WorldAssembler.luau` (`--!strict`): `PlaceGrounded(model, position, options?)` con `workspace:Raycast` vertical hacia abajo, compensación de `GetExtentsSize().Y / 2`, alineación opcional a la normal del suelo (`AlignToSlope`), snapping a grilla y `SmartUpsert` (`RN-10` soberanía del creador).
    3. `project_template/src/shared/ProceduralAnimator.luau` (`--!strict`): `AttachIK(character, config)` envolviendo `IKControl` nativo (`Type`, `ChainRoot`, `EndEffector`, `Target`, `SmoothTime`, `Weight`) más restricciones anatómicas opcionales (`BallSocketConstraint` / `HingeConstraint` con `LimitsEnabled = true`) para héroes/bosses, `Spring2D` amortiguado ($\ddot{x} + 2\zeta\omega_0\dot{x} + \omega_0^2(x - x_{\text{target}}) = 0$, $\zeta \in [0.45, 0.75]$) para UI/cámara y `FlipbookController` (`ImageRectOffset` / `ImageRectSize`) para spritesheets 2D.
    4. `project_template/src/shared/VFXAndJuiceEngine.luau` (`--!strict`): promover y expandir `impact_sequencer.luau` con `AddTrauma(amount)` y cámara shake cúbico ($S = T^3$ en `Enum.RenderPriority.Camera.Value + 1` con Perlin noise), `TriggerHitFlash(targetModel, duration?)` (`Highlight` blanco `FillTransparency = 0.1 -> 1.0` en `0.12s`), `ApplyHitstop`, `PlayModulatedSound(sound, pitchVariance?, knockbackTarget?, knockbackImpulse?)` ($\pm 9\%$ pitch) y `CastEffect(effectType, cframe, scale?, options?)` componiendo las 5 capas (`CoreFlash`, `ShockwaveRing`, `SlashTrail` con `FaceCamera = false`, `DirectionalSparks` con `VelocityParallel` y `Squash = -1.5`, y `VoxelDebris` heredando Material y Color del suelo vía `Raycast`).
    5. Actualizar `project_template/src/shared/Types.luau` con los contratos de tipos de los 4 módulos y crear suite de verificación `bridge/test_master_modules.mjs`.
  - Checks aplicables: `node --test bridge/test_master_modules.mjs`.

- **S4 — Fase 4 (Contratos Maestros en `CLAUDE.md` / `AGENTS.md` / `agent/system_prompt.md` / `docs/` y Playtest QA)**:
  - Alcance autorizado:
    1. Sincronizar `docs/ARQUITECTURA_ROBLOX_IA_NEXTGEN.md` (tanto en `robloxIA/docs/` como en la raíz del workspace) incluyendo la tabla de 6 puntos ciegos corregidos, el mapeo de las 10 herramientas reales de `StudioMCP` vs. wrappers comunitarios y las reglas de coexistencia Rojo + `StudioMCP`.
    2. Actualizar `CLAUDE.md`, `AGENTS.md`, `agent/system_prompt.md` y `README.md` con las firmas exactas de los 4 Módulos Maestros (`VoxelTerrainBuilder`, `WorldAssembler`, `ProceduralAnimator`, `VFXAndJuiceEngine`) y el protocolo obligatorio de QA en bucle cerrado (`start_stop_play` -> `character_navigation` -> `user_keyboard_input`/`user_mouse_input` -> `get_console_output` 0 errores -> `screen_capture` bajo circuit breaker `RN-11` de máx. 2 pasadas).
  - Checks aplicables: `node --test bridge/test_*.mjs`.

## Tasks

- [x] **T1** (S1 | route: inline | status: completed | commit: `acbbb4e`): Configurar `mcp_config.example.json`, `bridge/mcp_doctor.mjs` (doctor de coexistencia Rojo + `StudioMCP` + `MCPBridge` + Open Cloud) y `bridge/test_mcp_doctor.mjs` (5/5 tests PASS).
- [x] **T2** (S2 | route: inline | status: completed | commit: `6085494`): Actualizar `blender_export_example.py` (Vertex Colors + Palette Atlas UV + `<20k` tris) y `bridge/open_cloud.mjs` (`.fbx`/`.glb` + manifiesto `rbxassetid://`) con `bridge/test_open_cloud.mjs` (4/4 tests PASS).
- [x] **T3** (S3 | route: inline | status: completed | commit: `61a8148`): Implementar los 4 Módulos Maestros en `project_template/src/shared/` (`VoxelTerrainBuilder.luau`, `WorldAssembler.luau`, `ProceduralAnimator.luau`, `VFXAndJuiceEngine.luau`), actualizar `Types.luau` y verificar con `bridge/test_master_modules.mjs` (5/5 tests PASS).
- [x] **T4** (S4 | route: inline | status: completed | commit: `09ba9be`): Estandarizar contratos RAASE 3.0 y protocolo Playtest QA en `CLAUDE.md`, `AGENTS.md`, `agent/system_prompt.md` y `docs/ARQUITECTURA_ROBLOX_IA_NEXTGEN.md` (16/16 tests PASS en suite completa).

## Log

- **L1 (2026-10-24)**: Solicitud original del usuario (verbatim): `"cambiado de modelo para que analice el .md o pdf si es posible para preparar un plan, es valido investigar si los puntos que investigue son validos puntos ciegos o problemas teoricos que no se vieron durante la investigacion si es viable para hacer los mejores juegos en el menor tiempo posible, investiga busca referencias si encuentras la misma conclusion haz el plan y si no  con la informacion nueva tambien, y  que sea viable que haga todas esas cosas como un profesional"`.
- **L2 (2026-10-24)**: Aprobación del usuario para ejecutar el Plan Maestro de 4 fases (verbatim): `"continua"`. Ruta elegida: `inline` para T1–T4 (unidades secuenciales acopladas al mismo árbol local `robloxIA`, sin motivo de paralelismo multi-writer; el padre ejecuta cada tarea con su test focalizado y commit por unidad de trabajo).
- **L3 (2026-10-24)**: Cierre verificado de T1 (`acbbb4e`), T2 (`6085494`), T3 (`61a8148`) y T4 (`09ba9be`) en rama `feat/raase-3-nextgen-pipeline`. Suite completa `node --test bridge/test_*.mjs`: 16/16 PASS (`test_mcp_doctor.mjs`, `test_open_cloud.mjs`, `test_master_modules.mjs`, `test_circuit_breaker.mjs`, `test_bridge_v2_1.mjs`).
