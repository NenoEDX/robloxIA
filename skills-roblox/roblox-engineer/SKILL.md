---
name: roblox-engineer
description: "Skill maestra del desarrollo autónomo en Roblox Studio. Orquesta los 35 dominios técnicos de Roblox (610 micro-habilidades), las extensiones roblox-36-asset-pipeline (Blender/assets), roblox-37-vfx-combat-pipeline (VFX de combate) y roblox-38-env-vfx-craft (VFX ambiental), y las 19 skills metodológicas de software de skillsGV combinadas con Rojo, Companion Plugin y auditoría visual. Úsala como punto de entrada cuando el agente deba planificar, construir, auditar o desplegar cualquier experiencia Roblox."
license: MIT
allowed-tools: Read Write Bash(node:*,luau-lsp:*,rojo:*,wally:*)
metadata:
  domain: "Master Roblox Autonomous Engineering"
  totalSkills: 610
  methodologySkills: 19
  author: "RAASE 2.1 / robloxIA"
---

# roblox-engineer — Ingeniero de Software y Diseñador Autónomo para Roblox Studio

Esta es la habilidad maestra que guía al agente en la planificación, construcción, auditoría, programación y despliegue de experiencias profesionales en Roblox Studio bajo los estándares de ingeniería Luau 2026.

## 🧭 Mapa de Dominios Técnicos de Roblox (35 Módulos / 610 Habilidades)

### 🧱 Núcleo de Motor, Redes y Persistencia (01 - 10)
| Dominio | Rango | Módulo | Habilidades Clave |
|---|---|---|---|
| **01** | `001-025` | [roblox-01-luau-core](../roblox-01-luau-core/SKILL.md) | `--!strict`, genéricos, buffer binario, task library, Selene linting. |
| **02** | `026-060` | [roblox-02-netsec](../roblox-02-netsec/SKILL.md) | Redes Zero-Trust, Token Bucket Rate Limiting, Honeypots, validación espacial. |
| **03** | `061-085` | [roblox-03-persistence-datastores](../roblox-03-persistence-datastores/SKILL.md) | `UpdateAsync`, Session Locking, MemoryStore, guardado en `BindToClose`. |
| **04** | `086-115` | [roblox-04-3d-world-csg](../roblox-04-3d-world-csg/SKILL.md) | GeometryService (CSGv3), terreno voxel Perlin, iluminación Future, PBR. |
| **05** | `116-140` | [roblox-05-kinematics-rigs](../roblox-05-kinematics-rigs/SKILL.md) | `Motor6D.Transform` en hilo de render, inmutabilidad de C0/C1, IKControl. |
| **06** | `141-165` | [roblox-06-ui-ux-gui](../roblox-06-ui-ux-gui/SKILL.md) | UI reactiva, `UIAspectRatioConstraint`, CanvasGroup, safe zones móviles. |
| **07** | `166-185` | [roblox-07-audio-dsp](../roblox-07-audio-dsp/SKILL.md) | SoundGroups, ecualizadores, zonas acústicas, ducking compressor. |
| **08** | `186-210` | [roblox-08-memory-lifecycle](../roblox-08-memory-lifecycle/SKILL.md) | Patrón Janitor, erradicación de fugas, PartCache pooling, 60 FPS estables. |
| **09** | `211-225` | [roblox-09-economy-devex](../roblox-09-economy-devex/SKILL.md) | `ProcessReceipt` idempotente, DevEx 2026 U.S. 18+ ($0.0054/R), avatares R15. |
| **10** | `226-235` | [roblox-10-tooling-automation](../roblox-10-tooling-automation/SKILL.md) | Rojo file-sync, Companion Plugin RPC, captura host-side, auto-corrección Z-fighting. |

### 🎨 Construcción, Nivelación y Efectos Visuales (11 - 13)
| Dominio | Rango | Módulo | Habilidades Clave |
|---|---|---|---|
| **11** | `236-250` | [roblox-11-map-making](../roblox-11-map-making/SKILL.md) | Level design, macro-zonificación, clearance AABB, biomas procedurales, streaming budgets. |
| **12** | `251-265` | [roblox-12-model-maker](../roblox-12-model-maker/SKILL.md) | Ensamble modular, proporciones áureas, Directiva Anti-Neón, jerarquía limpia. |
| **13** | `266-280` | [roblox-13-vfx-maker](../roblox-13-vfx-maker/SKILL.md) | Partículas, curvas ColorSequence, Beams, Trails, Highlights y dynamic lighting. |

### 🎮 Sistemas de Juego, Monetización y Compliance (14 - 20)
| Dominio | Rango | Módulo | Habilidades Clave |
|---|---|---|---|
| **14** | `281-295` | [roblox-14-npc-ai-pathfinding](../roblox-14-npc-ai-pathfinding/SKILL.md) | PathfindingService, FSM (Idle/Chase/Attack), FOV con producto escalar, Network Ownership. |
| **15** | `296-310` | [roblox-15-input-action-systems](../roblox-15-input-action-systems/SKILL.md) | ContextActionService (`Sink`/`Pass`), UI táctil móvil, Gamepad deadzones ($\ge 0.20$), action buffering. |
| **16** | `311-325` | [roblox-16-chat-voice-social](../roblox-16-chat-voice-social/SKILL.md) | TextChatService moderno, filtrado server-side con `TextService`, Voice Chat 3D espacial con `Wire`. |
| **17** | `326-340` | [roblox-17-analytics-liveops](../roblox-17-analytics-liveops/SKILL.md) | Funnels en AnalyticsService, Badges con rate-limit y verificación previa, Feature Flags en MemoryStore. |
| **18** | `341-355` | [roblox-18-monetization-suite](../roblox-18-monetization-suite/SKILL.md) | MarketplaceService, `ProcessReceipt` idempotente con `PurchaseId`, suscripciones Robux, PolicyService. |
| **19** | `356-370` | [roblox-19-testing-ci-pipeline](../roblox-19-testing-ci-pipeline/SKILL.md) | TestEZ BDD (`describe`/`it`/`expect`), DataModel mocks, `luau-lsp --analyze`, Selene, StyLua en GitHub Actions. |
| **20** | `371-385` | [roblox-20-moderation-compliance](../roblox-20-moderation-compliance/SKILL.md) | Content Maturity Rating, divulgación de probabilidades de lootboxes, purga GDPR en $<30$ días. |

### ⚙️ Motor, Plataforma y Rendimiento Avanzado (21 - 28)
| Dominio | Rango | Módulo | Habilidades Clave |
|---|---|---|---|
| **21** | `386-400` | [roblox-21-physics-mechanisms](../roblox-21-physics-mechanisms/SKILL.md) | Constraints físicas modernas, resortes amortiguados, CollisionGroups, erradicación de BodyMovers. |
| **22** | `401-415` | [roblox-22-camera-cinematics](../roblox-22-camera-cinematics/SKILL.md) | `CameraType.Scriptable`, screen shake con ruido Perlin 3D, secuencias multicámara y shapecast. |
| **23** | `416-430` | [roblox-23-parallel-luau](../roblox-23-parallel-luau/SKILL.md) | Instancias `Actor`, bifurcación con `task.desynchronize()`, memoria compartida con `SharedTable`. |
| **24** | `431-445` | [roblox-24-localization-i18n](../roblox-24-localization-i18n/SKILL.md) | LocalizationService, tablas semánticas, pluralización gramatical, soporte RTL y formateo local. |
| **25** | `446-460` | [roblox-25-platform-performance](../roblox-25-platform-performance/SKILL.md) | StreamingEnabled (`ModelStreamingMode.Atomic`), MicroProfiler tags, presupuestos de memoria móvil. |
| **26** | `461-475` | [roblox-26-accessibility](../roblox-26-accessibility/SKILL.md) | Modos de alto contraste y daltonismo, textos escalables, subtítulos espaciales y haptic feedback. |
| **27** | `476-490` | [roblox-27-teleport-matchmaking](../roblox-27-teleport-matchmaking/SKILL.md) | TeleportAsync con opciones seguras, sanitización de `TeleportInitData`, colas globales en MemoryStore. |
| **28** | `491-505` | [roblox-28-instance-service-internals](../roblox-28-instance-service-internals/SKILL.md) | CollectionService tag-driven, regla de *Parent siempre al final*, instanciación diferida (<4 ms/frame). |

### 🎭 Profundidad de Juego, Combate e Interacción (29 - 35)
| Dominio | Rango | Módulo | Habilidades Clave |
|---|---|---|---|
| **29** | `506-520` | [roblox-29-animation-authoring-retargeting](../roblox-29-animation-authoring-retargeting/SKILL.md) | Retargeting R15, CurveAnimation, transiciones `AdjustWeight`, marcadores de impacto. |
| **30** | `521-535` | [roblox-30-avatar-customization](../roblox-30-avatar-customization/SKILL.md) | `HumanoidDescription`, Layered Clothing con `WrapTarget`/`WrapLayer`, acoplamiento `WeldConstraint`. |
| **31** | `536-550` | [roblox-31-combat-systems](../roblox-31-combat-systems/SKILL.md) | Consultas espaciales volumétricas `GetPartBoundsInBox/Radius`, trazado multipunto, reconciliación de ping. |
| **32** | `551-565` | [roblox-32-world-interactions](../roblox-32-world-interactions/SKILL.md) | `ProximityPrompt` avanzado, revalidación server-side de distancia, cinemática de puertas, cofres seguros. |
| **33** | `566-580` | [roblox-33-team-collab-workflows](../roblox-33-team-collab-workflows/SKILL.md) | Flujos multi-partición en Rojo, Git trunk-based, separación de código vs binarios `.rbxl`, `wally.lock`. |
| **34** | `581-595` | [roblox-34-external-apis-secrets](../roblox-34-external-apis-secrets/SKILL.md) | `HttpService` tipado, `HttpService:GetSecret()`, token bucket ($\le 500$ req/min por servidor), backoff con jitter. |
| **35** | `596-610` | [roblox-35-dynamic-audio-music](../roblox-35-dynamic-audio-music/SKILL.md) | Audio API 2026 conectada por nodos `Wire`, `AudioFader` crossfade, pitch modulación y oclusión por raycast. |
| **EXT** | `—` | [roblox-36-asset-pipeline](../roblox-36-asset-pipeline/SKILL.md) | Pipeline de assets externos: Blender headless → GLB/flipbooks → handoff al creador → verificación post-import. |
| **EXT** | `—` | [roblox-37-vfx-combat-pipeline](../roblox-37-vfx-combat-pipeline/SKILL.md) | VFX de combate estilo fighting-game: hitstop, camera juice, flipbooks de impacto, impact frames y secuenciador. |
| **EXT** | `—` | [roblox-38-env-vfx-craft](../roblox-38-env-vfx-craft/SKILL.md) | VFX ambiental de calidad por recetas: antorchas/fuego, agua, pórticos, clima — capas, curvas de calor y flicker. |

---

## 🛠️ Suite Metodológica Transversal (19 Skills de `skillsGV`)

Estas 19 habilidades de ingeniería de software rigen la disciplina de trabajo del agente, complementando el motor desde el repositorio hermano `skillsGV`:

1. **Planificación & Desglose**:
   - [`professional-planner`](../../../skillsGV/professional-planner/SKILL.md): Planificación formal por fases con presupuesto de riesgos.
   - [`project-tracker`](../../../skillsGV/01-planning-process/project-tracker/SKILL.md): Seguimiento estricto en `PROJECT_TRACKER.md`.
   - [`parallelization`](../../../skillsGV/01-planning-process/parallelization/SKILL.md): División de trabajo entre sub-agentes sin colisiones.
   - [`idea-to-prd-express`](../../../skillsGV/01-planning-process/idea-to-prd-express/SKILL.md): Conversión de ideas en GDDs técnicos completos.
   - [`sdd-suite`](../../../skillsGV/00-meta-skills/): Metodología Spec-Driven Development (`sdd-spec`, `sdd-design`, `sdd-tasks`, `sdd-apply`, `sdd-verify`).
2. **Arquitectura & Puertas de Calidad**:
   - [`architecture-designer`](../../../skillsGV/02-dev-roles/architecture-designer/SKILL.md): Diseño de contratos y desacoplamiento de servicios.
   - [`code-reviewer`](../../../skillsGV/02-dev-roles/code-reviewer/SKILL.md): Revisión rigurosa de legibilidad, tipado y antipatrones.
   - [`review-reliability`](../../../skillsGV/02-dev-roles/review-reliability/SKILL.md): Auditoría de tolerancia a fallos en servicios I/O.
   - [`security-audit`](../../../skillsGV/02-dev-roles/security-audit/SKILL.md): Verificación de modelo Zero-Trust y defensas anti-exploit.
   - [`dod-checker`](../../../skillsGV/02-dev-roles/dod-checker/SKILL.md): Definition of Done Gatekeeper.
   - [`verification-before-completion`](../../../skillsGV/02-dev-roles/verification-before-completion/SKILL.md): Prohibición de dar por hecho una tarea sin pruebas demostrables.
   - [`solid-clean-code`](../../../skillsGV/06-code-quality/solid-clean-code/SKILL.md): Principios SOLID aplicados a OOP en Luau.
3. **Depuración & Testing**:
   - [`systematic-debugging`](../../../skillsGV/02-dev-roles/systematic-debugging/SKILL.md): Metodología científica de aislamiento de causa raíz.
   - [`testing-patterns`](../../../skillsGV/07-testing/testing-patterns/SKILL.md): Patrones de pruebas unitarias y generación de casos borde.
   - [`diagnosing-bugs`](../../../skillsGV/12-matt-pocock/diagnosing-bugs/SKILL.md): Aislamiento y reproducción determinista de errores.
4. **LiveOps & Operaciones**:
   - [`kill-switches`](../../../skillsGV/08-devops/kill-switches/SKILL.md): Desactivación en caliente de funciones bugeadas sin reiniciar servidores.
   - [`ci-cd`](../../../skillsGV/08-devops/ci-cd/SKILL.md): Automatización de linting, builds de Rojo y despliegue a Open Cloud.
5. **Clarificación de Requisitos**:
   - [`grill-me`](../../../skillsGV/12-matt-pocock/grill-me/SKILL.md): Interrogatorio al usuario para definir edge cases antes de codificar.
   - [`ux-auditor-agent`](../../../skillsGV/11-mcp-hybrid/ux-auditor-agent/SKILL.md): Auditoría de ergonomía en pantallas táctiles y mandos.

---

## ⚙️ Reglas Inviolables
1. **Nunca mutar `C0` o `C1` en bucles de tiempo de ejecución.** Manipular únicamente `Motor6D.Transform`.
2. **Nunca omitir `--!strict` en ningún script `.luau`.**
3. **Nunca confiar en datos enviados por el cliente (Zero-Trust).**
4. **Nunca dejar eventos sin limpiar.** Emplear siempre `Janitor`.
5. **Siempre registrar waypoints con `ChangeHistoryService` al editar escenas.**
6. **Nunca dar por terminada una tarea sin verificación empírica (`verification-before-completion`).**
