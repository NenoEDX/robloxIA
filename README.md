# robloxIA — Sistema Autónomo de Desarrollo para Roblox Studio (RAASE 2.1)
### *Inspirado en el sistema "Generador de Robux 3000" (DEValen) y basado en estándares de ingeniería Luau 2026*

`robloxIA` (Roblox Autonomous Agent Studio Engine — **RAASE 2.1**) es una arquitectura de desarrollo desatendido de grado de producción que convierte a cualquier agente de Inteligencia Artificial (Google Antigravity, Claude Code, OpenAI Codex, OpenCode, Cursor) en un **Ingeniero de Software y Diseñador Técnico Autónomo de Roblox Studio**.

El sistema traduce intenciones de alto nivel (vía voz, chat o terminal) en:
1. **Lógica autoritativa en Luau estricto (`--!strict`)** libre de vulnerabilidades y fugas de memoria mediante ciclo de vida con `Janitor`.
2. **Generación procedural y manipulación bidireccional del mundo 3D** en Roblox Studio (inspección, mutación quirúrgica y eliminación segura sincronizadas con `ChangeHistoryService`).
3. **Auditoría estética asistida por visión computacional con convergencia estricta de 2 pases** y cortacircuitos activo para erradicar bucles infinitos.
4. **Arquitectura transaccional de persistencia y cumplimiento DevEx 2026** (tasa preferencial U.S. 18+ de $0.0054 USD por Robux con avatares R15).

---

## 🏛️ Arquitectura del Sistema (RAASE 2.1)

```mermaid
flowchart TD
    subgraph HostPlane ["1. Capa de Control y Orquestación (Host OS)"]
        User["Creador / Desarrollador (Voz / Chat / CLI)"] --> Agent["Agente Autónomo (Antigravity / Claude / Codex)"]
        Agent --> Router["skillsGV Router (209 Skills)"]
        Agent --> Catalog["Catálogo RAASE 2.1 (610 Luau Skills)"]
        Agent --> Bridge["Host Bridge HTTP Server (:34873)\n[Circuit Breaker / Mutex]"]
        Agent --> Rojo["Rojo File Sync Server (:34872)"]
        Agent --> VisionWorker["Host Screen Capture Worker (Win32 Non-Invasive)"]
    end

    subgraph StudioPlane ["2. Capa de Ejecución (Roblox Studio Engine)"]
        Rojo <-->|Sync Código Luau Bidireccional| DataModel["DataModel (ServerScriptService, ReplicatedStorage)"]
        Bridge <-->|HTTP Long-Polling JSON RPC| CompanionPlugin["Companion Plugin 2.1\n[DockWidget / Smart Upsert / Undo Recording]"]
        CompanionPlugin --> Viewport["Roblox Studio 3D Viewport"]
        Viewport -.->|Frame Buffer| VisionWorker
    end

    VisionWorker -->|viewport_latest.png| Agent
    Agent -->|Micro-Mutación Quirúrgica / Smart Upsert| Bridge
```

---

## 🌟 Novedades y Mejoras de RAASE 2.1

### 1. Grafo de Escena Bidireccional (Introspección Total)
El puente ya no opera a ciegas. Dispone de primitivas RPC completas para consultar y modificar el árbol del juego:
* `GET_SCENE_GRAPH`: Inspecciona la jerarquía del `Workspace` o cualquier sub-modelo con filtrado por clase, profundidad máxima y volumen AABB.
* `INSPECT_OBJECT`: Extrae al instante la posición, tamaño, material, color, atributos, etiquetas de `CollectionService` y bounding box de cualquier instancia.
* `MODIFY_OBJECT`: Altera propiedades específicas *in situ* con registro atómico en `ChangeHistoryService` (soporta `Ctrl+Z`).
* `DELETE_OBJECT`: Destruye instancias específicas de forma segura.
* `CLEAR_ZONE`: Limpia volúmenes espaciales o modelos filtrados sin tocar el resto del mapa.

### 2. Spawning Atómico con Smart Upsert (Soberanía del Creador RN-10)
* `BATCH_SPAWN` procesa lotes de instancias en una única transacción atómica de red y un solo paso de historial (`ChangeHistoryService`), protegido por un límite de cuerpo de 25MB y cola con tope de 200 comandos (HTTP 503 ante saturación).
* **Smart Upsert Anti-Z-Fighting (RN-10)**: Por defecto opera en modo `skip_existing` para proteger las construcciones del usuario. Solo sobreescribe o actualiza partes existentes si se especifica explícitamente `upsert: true`.
* Soporte nativo para adjuntar automáticamente `SpecialMesh`, `ProximityPrompt`, `BillboardGui` y `Sound` 3D en el mismo despacho.

### 3. Cortacircuitos de Captura de Pantalla y Autenticación C1
* **Autenticación Bearer Obligatoria (C1)**: Toda comunicación HTTP con el bridge requiere cabecera `Authorization: Bearer <TOKEN>`. El token se genera criptográficamente al iniciar y se almacena en `bridge/.bridge_token` (o se define vía variable de entorno `ROBLOXIA_BRIDGE_TOKEN`). Para pruebas automatizadas sin tocar disco, definir `ROBLOXIA_NO_WRITE_TOKEN_FILE=1`.
* **Guardia en el Bridge:** Limita las capturas consecutivas a un máximo de **2**. Si un agente intenta tomar una 3ª captura consecutiva sin haber ejecutado una mutación real en la escena, el servidor responde con **HTTP 429 (`CIRCUIT_BREAKER_TRIGGERED`)**, deteniendo cualquier loop infinito.
* Solo los comandos de mutación real de escena (`BATCH_SPAWN`, `MODIFY_OBJECT`, `DELETE_OBJECT`, `CLEAR_ZONE`, `SET_TERRAIN_VOXELS`, `SET_LIGHTING`, `SPAWN_PART`, `CREATE_ISLAND`, `CSG_OPERATION`) reinician el contador a cero.
* Endpoint de desbloqueo manual seguro: `POST /api/capture/reset` (requiere confirmación explícita mediante cabecera `X-Manual-Reset: true` o query `?manual=true`).

### 4. Captura de Pantalla No Invasiva
* El worker de visión (`bridge/screen_capture.py`) ya no fuerza `SetForegroundWindow` ni `ShowWindow(SW_RESTORE)` incondicionalmente en cada cuadro. Solo restaura la ventana si está minimizada y no roba el foco del usuario mientras trabaja en Windows.

### 5. Panel DockWidget Nativo en Studio
* Interfaz desacoplable en Roblox Studio (`DockWidgetPluginGui`) con:
  * **Indicador LED de 4 estados**: 🟢 ONLINE (Port 34873), 🟣 BUSY (Executing Actuator), 🟡 PAUSED, 🔴 OFFLINE.
  * **Métricas en tiempo real**: Memoria RAM (MB), primitivas activas, instancias en Workspace y comandos ejecutados.
  * **Botones de acción rápida**: Pausar/Reanudar sondeo, Limpiar Props (`Clear Props`) y Test de Conexión (`Ping Bridge`).
  * **Activity Stream**: Consola de logs con marca de tiempo de cada orden recibida.

### 6. Catálogo Ampliado a 610 Habilidades (35 Dominios Técnicos + Extensiones 36/37)
Se consolidó el catálogo completo de 35 módulos formales bajo el estándar `agentskills.io` (235 núcleo de motor + 45 nivelación y arte + 330 sistemas de juego y plataforma avanzada), complementado con 19 skills metodológicas de ingeniería:
* **Dominios 01 a 10** (Skills 001-235): Núcleo de Luau estricto, redes Zero-Trust, persistencia, mundo 3D, cinemática, UI reactiva, audio, memoria y automatización.
* **Dominios 11 a 13** (Skills 236-280): Map making, modelado modular y efectos visuales VFX.
* **Dominios 14 a 35** (Skills 281-610): Pathfinding de NPCs, input contextual, chat y voz espacial, analíticas, monetización avanzada, pipelines CI/CD con TestEZ, moderación, física moderna, cámaras cinemáticas, Parallel Luau con Actors, internacionalización, optimización de streaming, accesibilidad, matchmaking, internals de DataModel, animación R15, avatares y layered clothing, combate volumétrico, interacciones seguras, colaboración en equipo, integraciones de red/secretos y Audio API 2026.

---

## 🛠️ Historial de Bugs Corregidos (Changelog de Estabilidad)

| Fallo / Síntoma | Causa Técnica | Solución Implementada en RAASE 2.1 |
| :--- | :--- | :--- |
| **Error en `SET_LIGHTING` (`RobloxScript capability`)** | Intentar escribir `Lighting.Technology` directamente lanzaba un error fatal de permisos de seguridad en el hilo del plugin. | Todas las propiedades de `Lighting` ahora se ejecutan dentro de bloques `pcall`, aplicando iluminación, sombras, reloj y atmósfera de forma segura. |
| **Parpadeo en falso de "🔴 OFFLINE" tras cada comando** | `updateStatusUI()` mutaba `connectionStatus = "BUSY"`. Al terminar el comando (`isBusy = false`), la UI no encontraba el estado `"ONLINE"` y caía en la rama `else` (OFFLINE) hasta el siguiente tick. | Se separó la salud de la red (`connectionStatus`) del estado de ejecución (`isBusy`). La UI muestra `🟣 BUSY` y regresa fluidamente a `🟢 ONLINE` sin parpadear en rojo. |
| **Bloque de pasto gigante no seleccionable que tapaba caminos** | El agente generó un bloque de **Terreno Voxel** (`workspace.Terrain`), el cual no se puede seleccionar con la herramienta estándar de ratón ni borrar como una pieza normal, y sus colinas tapaban los caminos a `Y = 0.15`. | Se vació el bloque voxel con material `Air` y se sustituyó por una pieza normal (`BasePart`) llamada `Plaza_Lawn_Selectable` a `Y = -0.5`. Es 100% seleccionable, editable y borrable con el ratón o la tecla Supr. |
| **Cursor del ratón trabado al mover cámara con clic derecho** | `FOCUS_CAMERA` modificaba `Camera.CFrame` pero dejaba `Camera.Focus` desfasado. Al dar clic derecho, el controlador de órbita de Studio regresaba el cursor violentamente al punto antiguo. | Se sincronizó de forma obligatoria `Camera.Focus = CFrame.new(center)` en cada reubicación de cámara, manteniendo la órbita del ratón en perfecta sincronía. |
| **Re-creación no deseada de objetos borrados por el usuario** | El agente re-ejecutaba scripts monolíticos completos que sobreescribían los cambios manuales del creador. | **Regla RN-10 (Soberanía del Creador)**: Prohibición estricta de re-crear o restaurar objetos borrados por el usuario sin orden textual directa, y uso exclusivo de micro-mutaciones quirúrgicas. |
| **Bucle infinito de capturas (30 min de fotos sin cambios)** | El prompt permitía auto-perfección abierta y el bridge no limitaba capturas consecutivas. | **Cortacircuitos en el Bridge** (bloqueo con HTTP 429 a la 3ª captura consecutiva) + **Regla RN-11 de 2 Pases** (parada obligatoria tras la verificación). |

---

## 📁 Estructura del Repositorio

```
robloxIA/
├── bridge/                         # Servidor local de enlace Host <-> Studio
│   ├── server.mjs                  # Servidor HTTP REST + Long-Polling + Cortacircuitos (:34873)
│   ├── screen_capture.py           # Capturador host-side de Viewport no invasivo
│   ├── open_cloud.mjs              # Conector de subida a Roblox Open Cloud API
│   ├── test_bridge_v2_1.mjs        # Suite de pruebas unitarias e integración del bridge
│   ├── test_circuit_breaker.mjs    # Test automatizado del cortacircuitos de capturas
│   └── package.json                # Configuración npm del bridge
├── plugin/                         # Companion Plugin para Roblox Studio
│   ├── CompanionPlugin.server.luau # Luau estricto con DockWidget UI, Smart Upsert y Grafo RPC
│   └── default.project.json        # Configuración Rojo para compilar el plugin
├── project_template/               # Plantilla de juego Roblox de producción
│   ├── default.project.json        # Mapeo Rojo a DataModel
│   ├── wally.toml                  # Gestor de paquetes Wally (Janitor, Signal, Promise)
│   ├── selene.toml                 # Reglas de linter Selene
│   ├── stylua.toml                 # Reglas de formateo StyLua
│   └── src/
│       ├── server/                 # Scripts autoritativos en ServerScriptService
│       │   ├── NetworkSecurityService.luau # Token Bucket + Honeypots + Rate Limiting
│       │   ├── DataPersistenceService.luau # UpdateAsync + Session Locking transaccional
│       │   ├── MonetizationService.luau    # ProcessReceipt idempotente + DevEx 2026
│       │   ├── LobbyInteractionService.luau# Interacciones ProximityPrompt de tiendas y forjas
│       │   └── init.server.luau            # Bootstrap del servidor
│       ├── client/                 # Scripts en StarterPlayerScripts
│       │   ├── CharacterController.client.luau # Cinemática procedural Motor6D.Transform
│       │   └── HUDController.client.luau       # UI reactiva escalada sin distorsión
│       └── shared/                 # Módulos en ReplicatedStorage
│           ├── Types.luau          # Tipado estricto Luau 2026
│           └── Janitor.luau        # Erradicación de fugas de memoria
├── agent/                          # Herramientas del Agente Autónomo
│   ├── system_prompt.md            # Master System Prompt con reglas RN-10 y RN-11
│   ├── raase_skills.json           # Matriz indexada de las 610 micro-habilidades técnicas (35 dominios)
│   ├── orchestrator_cli.mjs        # CLI para canalizar comandos, inspección y visión
│   ├── fix_terrain_and_details.mjs # Utilidad de nivelación de terreno
│   └── generators/                 # Generadores procedurales de alto nivel
│       ├── build_magic_lobby.mjs   # Generador modular del Magic Lobby medieval
│       ├── attach_prompts_and_guis.mjs # Inyector de ProximityPrompts y BillboardGuis
│       ├── capture_tour.mjs        # Recorrido guiado de capturas con cámara estricta
│       └── deploy_server_scripts.mjs # Inyector directo de servicios en Studio
├── skills-roblox/                  # Especificación formal de skills (agentskills.io)
│   ├── roblox-11-map-making/       # Level Design y zonificación espacial
│   ├── roblox-12-model-maker/      # Modelado modular y directiva anti-neón
│   └── roblox-13-vfx-maker/        # Partículas, vigas, estelas e iluminación
├── docs/                           # Documentación y Especificación Técnica
│   └── RAASE_2_0_SPECIFICATION.md  # Blueprint arquitectónico formal
├── PROJECT_TRACKER.md              # Ledger de estado del proyecto (skillsGV format)
├── CLAUDE.md                       # Reglas de desarrollo para agentes CLI
└── README.md                       # Documentación principal
```

---

## 🚀 Guía de Inicio Rápido (Setup en 4 Pasos)

### 1. Iniciar el Servidor de Enlace (Bridge)
En una terminal:
```bash
node bridge/server.mjs
```
El servidor escuchará en `http://127.0.0.1:34873`, generará un Bearer Token criptográfico seguro y lo guardará en `bridge/.bridge_token`.

### 2. Instalar el Companion Plugin y Configurar Token en Roblox Studio
* Abre **Roblox Studio**.
* Compila el plugin directamente en la carpeta de plugins locales de Studio usando Rojo:
  ```powershell
  rojo build plugin/default.project.json -o "$env:LOCALAPPDATA\Roblox\Plugins\RAASE_Companion.rbxm"
  ```
* En Studio, activa los permisos de red en: `Game Settings -> Security -> Allow HTTP Requests` (**Activado**).
* **Flujo de Autenticación de Token**:
  1. Copia el token generado desde la terminal o desde `bridge/.bridge_token`.
  2. En la ventana desacoplable **RAASE 2.1 — Autonomous Studio Engine**, ingresa el token cuando sea solicitado (el plugin lo almacena de forma persistente con `plugin:SetSetting`).
  3. El indicador LED cambiará a verde `🟢 ONLINE (Port 34873)`.

### 3. Sincronizar el Código Luau con Rojo
En otra terminal:
```bash
rojo serve project_template/default.project.json
```
En Studio, abre el plugin de Rojo y presiona **Connect**.

### 4. Usar la CLI del Orquestador
Puedes interactuar directamente con Studio desde tu terminal o permitir que el agente lo haga:
```bash
# Consultar estado y telemetría del bridge
node agent/orchestrator_cli.mjs status

# Inspeccionar el grafo de escena en Workspace (profundidad 1)
node agent/orchestrator_cli.mjs scene-graph workspace 1

# Inspeccionar un objeto específico y todas sus propiedades
node agent/orchestrator_cli.mjs inspect "MagicLobby_Zone3_PotionShop"

# Modificar propiedades in-situ de una parte existente
node agent/orchestrator_cli.mjs modify "Plaza_Lawn_Selectable" '{"Color": [95, 150, 80], "Transparency": 0.05}'

# Borrar una instancia de forma segura
node agent/orchestrator_cli.mjs delete "ObjetoAntiguo"

# Limpiar una zona espacial AABB (Centro: 0, 10, 0 | Tamaño: 50, 20, 50)
node agent/orchestrator_cli.mjs clear-zone 0 10 0 50 20 50

# Tomar una captura del Viewport para auditoría visual
node agent/orchestrator_cli.mjs capture
```

---

## 🛡️ Estándares de Ingeniería Luau 2026

* **Strict Typing Obligatorio**: Todo script inicia con `--!strict`. Tipos nominales y estructurales explícitos con `export type ...`.
* **Seguridad Zero-Trust**: El cliente jamás declara daño o dinero. Todos los `RemoteEvent` validan tipos (`typeof()`), distancias espaciales (`.Magnitude <= 15`) y están protegidos por limitadores de tasa *Token Bucket* con señuelos *honeypots*.
* **Gestión de Memoria con Janitor**: Ningún `RBXScriptConnection` queda huérfano. Todo objeto destruido invoca `:Destroy()` formalmente.
* **Cinemática en RenderStepped**: Toda manipulación procedural en personajes altera EXCLUSIVAMENTE `Motor6D.Transform` en el hilo de render. Prohibido modificar `C0/C1` en bucles de tiempo de ejecución.
* **DevEx 2026 e Idempotencia**: `MarketplaceService.ProcessReceipt` persiste el `PurchaseId` en DataStore mediante `UpdateAsync()` antes de otorgar beneficios. Exclusividad de avatares R15 para calificar a la tasa preferencial U.S. 18+ ($0.0054 por Robux).
* **Soberanía del Creador (RN-10)**: Las modificaciones manuales del usuario en Studio son ley. Ningún agente puede re-crear partes eliminadas ni sobreescribir decisiones de diseño sin autorización expresa.

---

## 📚 Catálogo de Habilidades (610 Skills en 35 Dominios Técnicos + 2 Extensiones)

> **Extensiones RAASE 2.1** (fuera del registry JSON): `roblox-36-asset-pipeline` (pipeline Blender → handoff humano → verificación post-import) y `roblox-37-vfx-combat-pipeline` (VFX de combate estilo fighting-game). Portabilidad de modelo/harness: `docs/HARNESS-PORTABILITY.md` + `adapters/`.

El catálogo RAASE cubre 35 dominios de ingeniería de Roblox en estándar `agentskills.io` (610 micro-habilidades con Luau `--!strict`, reglas y snippets de producción):

### Núcleo de Motor, Redes y Persistencia (01 - 10)
1. `roblox-01-luau-core` (001-025): Luau Language & Strict Typing
2. `roblox-02-netsec` (026-060): Networking & Anti-Exploit Security
3. `roblox-03-persistence-datastores` (061-085): Persistence & DataStores
4. `roblox-04-3d-world-csg` (086-115): 3D World, CSGv3 & Procedural
5. `roblox-05-kinematics-rigs` (116-140): Rigging & Kinematics
6. `roblox-06-ui-ux-gui` (141-165): UI/UX & Reactive GUI
7. `roblox-07-audio-dsp` (166-185): Audio & DSP Effects
8. `roblox-08-memory-lifecycle` (186-210): Memory & Janitor Auditing
9. `roblox-09-economy-devex` (211-225): Economy & DevEx 2026
10. `roblox-10-tooling-automation` (226-235): Tooling & Studio Automation

### Construcción, Nivelación y Efectos Visuales (11 - 13)
11. `roblox-11-map-making` (236-250): Level Design, Zoning & AABB Spatial Check
12. `roblox-12-model-maker` (251-265): Modular 3D Assembly, Trims & Anti-Neon
13. `roblox-13-vfx-maker` (266-280): Particle Emitters, Beams, Trails & Dynamic Lighting

### Sistemas de Juego, Monetización y Compliance (14 - 20)
14. `roblox-14-npc-ai-pathfinding` (281-295): PathfindingService, FSM & Spatial Queries
15. `roblox-15-input-action-systems` (296-310): ContextActionService, Gamepad & Mobile Touch
16. `roblox-16-chat-voice-social` (311-325): TextChatService & Spatial Voice Wire API
17. `roblox-17-analytics-liveops` (326-340): AnalyticsService Funnels & LiveOps Flags
18. `roblox-18-monetization-suite` (341-355): MarketplaceService & Robux Subscriptions
19. `roblox-19-testing-ci-pipeline` (356-370): TestEZ BDD, Selene & CI Automation
20. `roblox-20-moderation-compliance` (371-385): Content Maturity & GDPR Compliance

### Motor, Plataforma y Rendimiento Avanzado (21 - 28)
21. `roblox-21-physics-mechanisms` (386-400): Modern Physics Constraints & Assemblies
22. `roblox-22-camera-cinematics` (401-415): Scriptable Cameras & Cinemachine
23. `roblox-23-parallel-luau` (416-430): Actor Concurrency & SharedTable
24. `roblox-24-localization-i18n` (431-445): LocalizationService & Semantic Tables
25. `roblox-25-platform-performance` (446-460): StreamingEnabled & MicroProfiler Budgets
26. `roblox-26-accessibility` (461-475): High-Contrast UI & Accessible Controls
27. `roblox-27-teleport-matchmaking` (476-490): TeleportAsync & Global Matchmaking
28. `roblox-28-instance-service-internals` (491-505): CollectionService & Instance Lifecycle

### Profundidad de Juego, Combate e Interacción (29 - 35)
29. `roblox-29-animation-authoring-retargeting` (506-520): R15 Retargeting & CurveAnimation
30. `roblox-30-avatar-customization` (521-535): HumanoidDescription & Layered Clothing
31. `roblox-31-combat-systems` (536-550): Spatial Queries, Raycasting & Hitboxes
32. `roblox-32-world-interactions` (551-565): ProximityPrompt & Environmental Systems
33. `roblox-33-team-collab-workflows` (566-580): Multi-Place Rojo Workflows & Wally
34. `roblox-34-external-apis-secrets` (581-595): HttpService, GetSecret & Webhooks
35. `roblox-35-dynamic-audio-music` (596-610): 2026 Wire Graph Architecture & Spatial Audio

Consulta la matriz canónica en [agent/raase_skills.json](file:///c:/Users/j1347/Desktop/Proyectos%20programacion/trabajos/IA%20INTEGRADA%20CON%20ROBLOX%20STUDIO/robloxIA/agent/raase_skills.json) y el índice general en [skills-roblox/roblox-engineer/SKILL.md](file:///c:/Users/j1347/Desktop/Proyectos%20programacion/trabajos/IA%20INTEGRADA%20CON%20ROBLOX%20STUDIO/robloxIA/skills-roblox/roblox-engineer/SKILL.md).
