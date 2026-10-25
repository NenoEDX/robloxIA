Objective: Construir desde cero Zombie Awareness (v4.0) bajo el estándar RAASE 3.0, purgando todo código/instancia heredada y materializando el ecosistema procedural de 3 facciones (150 unidades, 32 armas Lv1–10, 16 eventos, Z0–Z7 + 2 Zonas Especiales con Mutex) en `project_template/src/` y en Roblox Studio.
Branch: `feat/zombie-awareness-v4` | Delivery: work-unit commits por tarea (Conventional Commits) | Test runner: `node --test`

## Specs

- **S1 — Purga de Legado, Contratos `Types.luau`, Catálogos Maestros (`ZombieCatalogs.luau`) y Persistencia v4.0 (`DataPersistenceService.luau`)**:
  - Pedido textual del usuario: `"vamos a trabajar creando ese juego planifica investiga y tapa los puntos cciegos del gameloop que puedas encontrar etc etc"` y `"desde 0 todo lo que este ya viejo borralo"`.
  - Alcance autorizado:
    1. Purgar instancias heredadas del Workspace y StarterPlayerScripts en Roblox Studio (`Campamento7_Lobby`, `Baseplate`, `ImpactSequencer`, `TestImpact`) y eliminar lógica obsoleta de islas/monedas RAASE 2.0 en `project_template/src/`.
    2. Expandir `project_template/src/shared/Types.luau` (`--!strict`) con todos los contratos de Zombie Awareness v4.0 preservando intactos los contratos de los 4 Módulos Maestros (`VoxelTerrainConfig`, `GroundPlacementOptions`, `IKRigConfig`, `VFXEffectType`, `VFXCastOptions`).
    3. Crear `project_template/src/shared/ZombieCatalogs.luau` (`--!strict`) con las definiciones exactas de las 150 unidades (`H-01..H-30`, `M-01..M-60` + `M-BOSS-01`, `Z-01..Z-60` + `Z-BOSS-01`), las 32 armas en 10 niveles + Emisor `G-20` (3 tiers, 91 piezas modulares, 5 pools de munición), los 6 Rigs Maestros (`RIG-01..RIG-06`), los 9 Presets Matemáticos de VFX (`VFX_Muzzle_Ballistic` a `VFX_Weapon_Lv10_Aura`), los 32 edificios del Refugio Propio (Catálogo A en 3 tiers), los distritos `Z0..Z7` + 2 Zonas Especiales y los 16 eventos (`E-01..E-16`).
    4. Reescribir `project_template/src/server/DataPersistenceService.luau` (`--!strict`) con clave `User_{UserId}`, Session Locking con exponential backoff y jitter, guardado cada 180s y en transacciones críticas, bucle de Mochila Táctica vs. Bóveda Segura (extracción y penalización 50% al morir) y ciclo solar de 24 min (20m día + 4m noche).
  - Checks aplicables: `node --test bridge/test_master_modules.mjs`.

- **S2 — Generación Procedural por Semilla (`MissionGenService.luau`) y Control Territorial (`ThreatAndDistrictService.luau`)**:
  - Alcance autorizado:
    1. Crear `project_template/src/server/MissionGenService.luau` (`--!strict`) ejecutando las 6 etapas deterministas a partir de una semilla alfanumérica de 8 caracteres usando `VoxelTerrainBuilder` y `WorldAssembler`: (1) partición de anillos `Z0` (Refugio Seguro en borde sur con `ModelStreamingMode.Persistent`) a `Z7` (Núcleo de Infección, amenaza 2000), Zonas Especiales Oeste/Este y río tóxico perimetral (25 HP/s); (2) grafo vial urbano; (3) instanciación de prefabs urbanos con estructura portante indestructible + paneles `RAASE_BreachWall` (400 HP, cero geometría flotante); (4) campamentos Humanos (Z1–Z5), Bastiones Mutantes (Z3–Z6) y nidos Zombies (Z2/Z3/Z7); (5) WaypointNodes y LootPoints escalados por zona; (6) validación de conectividad de Pathfinding con re-seed por celda.
    2. Crear `project_template/src/server/ThreatAndDistrictService.luau` (`--!strict`): regeneración pasiva de amenaza (+5/min), reconstrucción de Puesto Avanzado, Fábrica y Refugio local asignando especialistas rescatados (`H-02`, `H-03`, `H-20`, `H-29`), y liberación permanente de distrito al llegar a amenaza 0.
  - Checks aplicables: validación de sintaxis estricta y tests de generación por semilla.

- **S3 — Motor de IA Masiva de Tres Facciones (`AIService.luau`)**:
  - Alcance autorizado:
    1. Crear `project_template/src/server/AIService.luau` (`--!strict`) con Object Pooling absoluto de hasta 180 NPCs (120 base + 60 eventos/Zonas Especiales) en 5 reservas tipadas (`Pool_Human`, `Pool_Mutant_Green`, `Pool_Mutant_Anthro`, `Pool_Zombie_Base`, `Pool_Brute`) sin usar `:Destroy()` al morir y con gobernador de rendimiento (<30 Hz reduce lote 20->10 y cap 180->120).
    2. Perception Batching rotativo (20 unidades/frame cada 5 fotogramas = 83 ms; cono 120° zombies, 90° mutantes/humanos, audio 60 studs).
    3. Cola priorizada de Pathfinding (máx. 4 `ComputeAsync` simultáneos: `MegaBrutes > HulkBrutes > Mutants > Humans > Zombies`) con caché espacial por celda invalidada al demoler muros `RAASE_BreachWall`.
    4. Steering Behaviors (`Seek + Separation + Obstacle Avoidance`) para hordas de 6+ zombies (`Z-01..Z-20`), máquinas de estado asimétricas para las 3 facciones y regla de exclusión mutua `ServerBossMutex = true` para los Crisoles de Masacre Oeste (`Z-BOSS-01`) y Este (`M-BOSS-01`) al acumular 1.000 puntos de Muerte de Facción.
  - Checks aplicables: tests unitarios y de integración de contratos IA/Mutex.

- **S4 — Combate Autoritativo, Arsenal Modular Lv1–10, Emisor `G-20` y Planificador de Eventos (`CombatAndArsenalService.luau` + `EventSchedulerService.luau`)**:
  - Alcance autorizado:
    1. Crear `project_template/src/server/CombatAndArsenalService.luau` (`--!strict`) integrado con `NetworkSecurityService.luau`: Loadout de 10 armas + slot `G-20`, evolución Lv1–10 (+80% daño, +50% cargador, -30% recarga, -50% dispersión en Lv10) con refundición al 80%, daño localizado por extremidad (Headshot x2.5/x3, grietas Acorazado x3, derribo en piernas), validación server-side del Emisor de Conciencia `G-20` (<=60 studs, 2s canalización, inmunidad de Hulks/Jefes, sub-pool `AlliedSwarm`), árbol táctico de 3 ramas (Pulso de Conciencia, Dash Táctico 0.3s i-frames, QTE), demolición/reparación de muros de 400 HP, barriles explosivos (50 dmg, 10 studs) y bandera individual de Renegado anti-griefing.
    2. Crear `project_template/src/server/EventSchedulerService.luau` (`--!strict`) que evalúa cada 90–180s la amenaza y los campamentos para instanciar hasta 3 eventos simultáneos del catálogo `E-01` a `E-16`, además de orquestar el ciclo solar de 24 min (`E-09 Noche de Caza`).
    3. Actualizar `project_template/src/server/init.server.luau` para inicializar todos los subsistemas de Zombie Awareness v4.0.
  - Checks aplicables: tests de seguridad, combate y planificador de eventos.

- **S5 — Controlador Táctico de Cliente, HUD de Conciencia, Sincronización en Vivo con Roblox Studio y Suite de Verificación (`test_zombie_awareness_v4.mjs`)**:
  - Alcance autorizado:
    1. Reescribir `project_template/src/client/CharacterController.client.luau` (`--!strict`): apuntado procedural (`Motor6D.Transform`), `ProceduralAnimator.AttachIK` para héroe/jefes, `Spring2D` de retroceso, Dash Táctico (0.3s i-frames), Pulso de Conciencia (tecla `Z`), QTE, cambio rápido de armas (`Q`/`F`/`G`) + Rueda Táctica de 10 slots (`Tab`), e integración con `VFXAndJuiceEngine` (`CastEffect` 5 capas + 9 presets VFX + marcadores `WindupVFX`, `HitFrame`, `RecoveryCancel`).
    2. Reescribir `project_template/src/client/HUDController.client.luau` (`--!strict`): Mapa de Conciencia (`Z0..Z7` + Crisoles Oeste/Este), barra de Jefe Supremo (`Z-BOSS-01` / `M-BOSS-01`), indicador de Mochila Táctica vs. Bóveda Segura, alertas de eventos `E-01..E-16` y panel de Armería/Refugio.
    3. Desplegar la estructura inicial de Zombie Awareness v4.0 en Roblox Studio vía Bridge (`orchestrator_cli.mjs`) y verificar toda la arquitectura con `bridge/test_zombie_awareness_v4.mjs` + suite completa `node --test bridge/test_*.mjs`.
  - Checks aplicables: `node --test bridge/test_*.mjs` y `node agent/orchestrator_cli.mjs status` / `inspect Workspace`.

## Tasks

- [x] **T1** (S1 | route: inline | status: completed | commit: `2df1ca3`): Purgar legado en Studio, actualizar `Types.luau`, crear `ZombieCatalogs.luau` (150 unidades + 2 Mega Brutos, 32 armas Lv1–10, 9 VFX presets, 16 eventos) y reescribir `DataPersistenceService.luau` y `MonetizationService.luau`.
- [x] **T2** (S2 | route: inline | status: completed | commit: `85852ad`): Implementar `MissionGenService.luau` (semilla 8 chars, Z0–Z7, Zonas Especiales, prefabs con brechas 400 HP) y `ThreatAndDistrictService.luau`.
- [x] **T3** (S3 | route: inline | status: completed | commit: `576d45c`): Implementar `AIService.luau` (Object Pool 180 NPCs, Perception Batching 20/frame, cola 4 `ComputeAsync`, Steering y `ServerBossMutex`).
- [x] **T4** (S4 | route: inline | status: completed | commit: `a2ea9ea`): Implementar `CombatAndArsenalService.luau`, `EventSchedulerService.luau` (eventos E-01..E-16) y bootstrap `init.server.luau`.
- [x] **T5** (S5 | route: inline | status: completed | commit: pending): Reescribir `CharacterController.client.luau` y `HUDController.client.luau`, desplegar `Workspace.ZA_World_ZA40SEED` en Roblox Studio y verificar suite completa `node --test bridge/test_*.mjs` (22/22 PASS).

## Log

- **L1 (2026-10-25)**: Solicitud original del usuario (verbatim): `"vamos a trabajar creando ese juego planifica investiga y tapa los puntos cciegos del gameloop que puedas encontrar etc etc"`.
- **L2 (2026-10-25)**: Instrucción de arranque desde cero y limpieza total (verbatim): `"desde 0 todo lo que este ya viejo borralo"`. Ruta declarada: `inline` para T1–T5 (unidades secuenciales en el mismo árbol `robloxIA/project_template/src/` donde cada servicio depende de los contratos de tipos y catálogos previos; el padre ejecuta cada tarea, corre su suite de verificación y registra su commit).
- **L3 (2026-10-25)**: Cierre verificado de T1 (`2df1ca3`), T2 (`85852ad`), T3 (`576d45c`), T4 (`a2ea9ea`) y T5 en rama `feat/zombie-awareness-v4`. Limpieza en vivo en Roblox Studio (`Campamento7_Lobby`, `Baseplate`, `ImpactSequencer`, `TestImpact` eliminados; `Workspace.ZA_World_ZA40SEED` desplegado) y suite completa `node --test bridge/test_*.mjs`: 22/22 tests PASS.
