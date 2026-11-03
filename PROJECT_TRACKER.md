# 🗃️ PROJECT DATA LEDGER: robloxIA / RAASE 2.0

> **Registro histórico — 2026-11-03.** Los PASS/SHIP de este documento no certifican la renovación actual. El seguimiento canónico está en [odd/tasks/system-overhaul.md](odd/tasks/system-overhaul.md) y el [plan maestro](docs/PLAN_MAESTRO.md).

## 1. 📌 Project Identity
- **Name**: robloxIA (Roblox Autonomous Agent Studio Engine - RAASE 2.0)
- **Core Goal**: Convertir cualquier agente de IA (Antigravity, Claude Code, Codex, OpenCode) en un Ingeniero y Diseñador Autónomo de Roblox Studio de alto rendimiento capaz de construir, programar, auditar por visión computacional y desplegar experiencias completas sin intervención manual.
- **Tech Stack**:
  - **Lenguaje Motor**: Luau 2026 con modo estricto (`--!strict`), bibliotecas `task`, `buffer`, `vector`, `GeometryService`, `Audio API`.
  - **Sincronización**: Rojo 7.x (File-Sync bidireccional local a Studio).
  - **Puente RPC**: Servidor HTTP nativo en Node.js (Long-polling en puerto `34873`).
  - **Visión Computacional**: Python / Node (captura host-side del Viewport de Studio).
  - **Seguridad & Datos**: Token Bucket Rate Limiter, Honeypots, DataStore `UpdateAsync` con Session Locking, DevEx 2026 con avatares R15 estrictos.
  - **Metodología y Reglas**: skillsGV (209 skills de software e ingeniería) + RAASE (610 micro-habilidades técnicas Luau en 35 dominios).
- **Aesthetic**: Código modular y desacoplado, arquitecturas Zero-Trust, interfaces adaptativas para móviles y consola, estética 3D con Future Lighting y alineación matemática de texturas.

## 2. 🚦 Strict Rules
- **RN-01 (Luau Strict)**: Todo script Luau (`.luau`) DEBE iniciar con la directiva `--!strict` y tipado nominal/estructural explícito (`export type ...`).
- **RN-02 (Zero Legacy Functions)**: Prohibidas las funciones obsoletas `spawn()`, `delay()`, `wait()`. Emplear exclusivamente la biblioteca nativa `task`.
- **RN-03 (Acceso a Servicios)**: Acceso a servicios únicamente mediante `game:GetService("NombreServicio")`.
- **RN-04 (Zero-Trust NetSec)**: El cliente es hostil; toda transacción, daño, inventario y validación espacial se calcula en el servidor.
- **RN-05 (Janitor Lifecycle)**: Todo objeto con eventos o promesas debe implementar `Janitor` para erradicar fugas de memoria (`RBXScriptConnection`).
- **RN-06 (Kinematics Rule)**: Toda cinemática procedural debe manipular `Motor6D.Transform` en hilos de render; prohibido alterar `C0/C1` en tiempo de ejecución.
- **RN-07 (DevEx 2026 & Idempotencia)**: `MarketplaceService.ProcessReceipt` debe persistir `PurchaseId` en DataStore antes de otorgar productos y retornar `NotProcessedYet` en fallos. Solo avatares R15 para calificar a tasa U.S. 18+ ($0.0054/R$).
- **RN-08 (Undo Safety)**: Todo comando de modificación de escena en el companion plugin debe registrarse con `ChangeHistoryService:TryBeginRecording()` y `FinishRecording()`.
- **RN-09 (SOLID / Clean Code)**: Funciones cortas (<40 líneas), principio de responsabilidad única, sin código muerto ni bypasses no documentados.
- **RN-10 (Soberanía del Creador & No-Resurrección)**: El usuario humano en Roblox Studio es la máxima autoridad; terminantemente prohibido re-crear o restaurar instancias que el usuario haya borrado o editado, salvo orden textual explícita. Prohibido ejecutar scripts generadores monolíticos completos sobre escenas en edición.
- **RN-11 (Convergencia Visual & Cortacircuitos)**: Máximo 2 pases de captura del Viewport por iteración con parada obligatoria. El servidor bridge bloquea capturas consecutivas sin mutación con HTTP 429 (`CIRCUIT_BREAKER_TRIGGERED`).

## 3. 🗺️ Roadmap & Phases
- `[x]` **Fase 1: Especificación Formal, Catálogo de Skills y Setup del Repositorio**
- `[x]` **Fase 2: Infraestructura del Enlace Local (Host Bridge & Vision Worker)**
- `[x]` **Fase 3: Companion Plugin de Roblox Studio**
- `[x]` **Fase 4: Plantilla de Proyecto Luau de Producción con Rojo**
- `[x]` **Fase 5: Herramientas del Agente Autónomo y CLI Orquestador**
- `[x]` **Fase 6: Verificación de Calidad (DoD Gatekeeper & Pruebas)**
- `[x]` **Fase 7: RAASE 2.1 — Grafo Bidireccional, Smart Upsert, Cortacircuitos y Soberanía del Creador**
  - Implementación de `GET_SCENE_GRAPH`, `INSPECT_OBJECT`, `MODIFY_OBJECT`, `DELETE_OBJECT`, `CLEAR_ZONE`.
  - Smart Upsert en `BATCH_SPAWN` para impedir duplicación de partes o solapamientos.
  - Cortacircuitos en el Bridge (`server.mjs`) que frena bucles infinitos de capturas.
  - Captura no invasiva sin parpadeo de ventanas (`screen_capture.py`).
  - Reglas RN-10 y RN-11 sincronizadas en `system_prompt.md` y `CLAUDE.md`.
  - Blueprint RAASE 2.0 actualizado con rediseño.
  - Matriz indexada de las 610 micro-habilidades (`raase_skills.json`) en 35 dominios técnicos.
  - Instrucciones de agente (`CLAUDE.md`, `agent/system_prompt.md`).
- `[x]` **Fase 2: Infraestructura del Enlace Local (Host Bridge & Vision Worker)**
  - Servidor HTTP REST + Long-Polling (`bridge/server.mjs`).
  - Capturador host-side de Viewport de Studio (`bridge/screen_capture.py`).
  - Conector de subida de assets (`bridge/open_cloud.mjs`).
- `[x]` **Fase 3: Companion Plugin de Roblox Studio**
  - Script Luau con long-polling, ChangeHistoryService y actuadores de escena (`plugin/CompanionPlugin.server.luau`).
  - Configuración Rojo para compilar el plugin (`plugin/default.project.json`).
- `[x]` **Fase 4: Plantilla de Proyecto Luau de Producción con Rojo**
  - Configuración de Rojo (`default.project.json`), Wally, Selene y StyLua.
  - Módulos de seguridad de red, DataStore transaccional y DevEx 2026.
  - Controlador de cinemática procedural y HUD reactivo.
- `[x]` **Fase 5: Herramientas del Agente Autónomo y CLI Orquestador**
  - Script CLI (`agent/orchestrator_cli.mjs`) para canalizar intenciones, bridge y visión.
  - Documentación maestra (`README.md`).
- `[x]` **Fase 6: Verificación de Calidad (DoD Gatekeeper & Pruebas)**
  - Auditoría DoD Checker: SOLID, seguridad, integridad funcional `[ 🟢 PASS ]`.
  - Pruebas unitarias y de integración del bridge verificadas exitosamente.
  - Doble juicio ciego (Judgment Day: Red SHIP / Blue SHIP).

## 4. 🧠 Decision Log
- `[2026-09-07]` **Despliegue y Validación del Lobby Mágico Medieval (Inspirado en Harry Potter)**:
  1. **Generación Procedural V2 High-Fidelity**: Ensamblado completo de 476 instancias primitivas en Roblox Studio organizadas en 10 modelos semánticos en `Workspace`.
  2. **Arquitectura de las 5 Zonas**:
     - *Zona 1 (Norte)*: Portal de Partidas con arco monumental, vórtice azul celestial, dos pebeteros de fuego y murallas de castillo con dos torreones *Norman Keep* de 32 studs.
     - *Zona 2 (Este)*: Bóveda de Crates abierta con 4 columnas de piedra, 3 cofres reforzados con hierro y llaves flotantes iluminadas.
     - *Zona 3 (Oeste)*: Boticario con entramado de madera, gran caldero de hierro verde borboteante con vapor y 3 estantes con 15 viales de pociones translúcidas.
     - *Zona 4 (Sureste)*: Campo de entrenamiento cercado con 3 maniquís vestidos de mago (sombreros puntiagudos y túnicas), barras de vida y números de daño flotantes.
     - *Zona 5 (Suroeste)*: Forja de piedra con hogar ardiente, chimenea, yunque, banco de terciopelo con anillos arcanos (Rubí, Zafiro, Esmeralda) y el PNJ Enano Elfo modelado.
  3. **Iluminación & Estética Natural Clara**: Configuración diurna de hora dorada (*Golden Hour*) bajo tecnología `Future` con más de 16 antorchas de hierro forjado y basalto negro (`PointLight.Shadows = true`) y gran hoguera comunal en el patio central.
  4. **Servicio Luau 2026**: Creación de `LobbyInteractionService.luau` bajo `--!strict` coordinando la cola de duelos, apertura de cofres con llaves, buffs de pociones y mejora de armaduras con el Elfo.
  5. **Herramientas**: Expansión de `CompanionPlugin.server.luau` con `EXECUTE_LUAU`, rotaciones CFrame, `ProximityPrompt` y `BillboardGui`. Registro en `CCUNDLOCK.md`.
- `[2026-09-07]` **Resolución de Judgment Day (Ronda 2 - Double Blind Audit)**:
  1. `MonetizationService.luau`: Enlace a `DataPersistenceService` con mutación real de monedas y tracker en sesión (`inSessionFulfilledReceipts`) para prevenir explotación de duplicación en reintentos de DataStore.
  2. `CompanionPlugin.server.luau`: Destrucción de partes originales (`partA` y `partB`) tras operaciones CSG exitosas para erradicar Z-fighting y colisiones superpuestas; adición de parámetro `nocache = true` en `HttpService:GetAsync` y backoff exponencial para respetar la cuota de 500 req/min del motor.
  3. `bridge/server.mjs`: Inyección de cabeceras HTTP `Cache-Control: no-cache, no-store, must-revalidate` y `Pragma: no-cache` en `sendJson` para impedir respuestas obsoletas cacheadas por Studio.
  4. `CharacterController.client.luau`: Preservación de la posición animada (`waistJoint.Transform.Position`), inversión de signo en pitch para orientación canónica, soporte multiplataforma (Touch/Gamepad) y limpieza de articulaciones en `onCharacterAdded` ante respawn.
  5. `DataPersistenceService.luau`: Corrección de liberación de sesión concurrente (`isReleasingSession`) tras guardados en vuelo, bucle rotador de autoguardado periódico cada 120s (evita caducidad de lease tras 15 min) y carga reactiva de jugadores presentes al iniciar.
  6. `Janitor.luau`: Salvaguarda `item ~= coroutine.running()` para impedir que un hilo se auto-cancele a mitad de iteración abortando la limpieza de los demás ítems.
  7. `bridge/screen_capture.py`: Sintaxis de constructor `Rectangle($x, $y, $w, $h)` para prevenir errores con coordenadas negativas en configuraciones multimonitor y detección de ventanas minimizadas (`x < -10000`).
  8. `bridge/open_cloud.mjs`: Inspección explícita de `opData.error` durante el polling de operaciones para abortar inmediatamente con el mensaje exacto de rechazo o moderación.
  9. `NetworkSecurityService.luau`: Adición de comprobaciones `math.huge` para rechazar coordenadas infinitas en validación espacial.
  10. `default.project.json` & `agent/orchestrator_cli.mjs`: Mapeo de `Packages` de Wally hacia `ReplicatedStorage` y exposición CLI de comandos `csg-op` y `set-terrain`.
- `[2026-09-07]` **Resolución Final del 360° QA Audit & Judgment Day**:
  1. `Janitor.luau`: Eliminado el sombreado de variable `task` en el bucle `for item in pairs(tasks)` para que `task.cancel()` cancele hilos reales sin silenciar errores en `pcall`.
  2. `MonetizationService.luau`: Verificación del jugador conectado e invocación exitosa del handler de producto antes de registrar la compra cumplida (`granted = true`) en DataStore, evitando la pérdida irreversible de compras en retintento.
  3. `CompanionPlugin.server.luau`: Desenpaquetado e iteración correcta sobre el array `{BasePart}` devuelto por `GeometryService:UnionAsync`, `SubtractAsync` e `IntersectAsync` para nombrarlas y emparentarlas correctamente en `workspace`.
  4. `bridge/server.mjs`: Añadido guard `responded` en `/api/capture` para erradicar llamadas duplicadas a `sendJson()` y el error fatal de proceso `ERR_HTTP_HEADERS_SENT`.
  5. `DataPersistenceService.luau`: Protección de lease en `saveData` (`sessionLockJobId == CURRENT_JOB_ID`) y cola atómica de guardados en vuelo (`activeSavingCount`) para evitar salidas prematuras en `game:BindToClose`.
  6. `CharacterController.client.luau`: Asignación directa de `waistJoint.Transform` y `neckJoint.Transform` con ángulos acotados para prevenir la acumulación multiplicativa y el giro centrífugo continuo del personaje.
  7. `bridge/open_cloud.mjs`: Lanzamiento de error explícito ante timeout en polling en lugar de inyectar un UUID de operación en formato `rbxassetid://`.
  8. `NetworkSecurityService.luau`: Detección y rechazo de valores `NaN` en coordenadas de `targetPosition` en la validación de proximidad espacial.
- `[2026-09-07]` **Resolución Adversarial de Judgment Day Inicial**: Corrección de 8 fallas críticas detectadas por los jueces Red y Blue:
  1. Jerarquía de `require` en `init.server.luau` para Rojo (`script:WaitForChild(...)`).
  2. Serialización de payloads en `postReport` (eliminado `JSONDecode` redundante).
  3. Soporte de actuadores `CSG_OPERATION` (`GeometryService`) y `SET_TERRAIN_VOXELS` en el Companion Plugin.
  4. Session locking con `JobId` y detección de adquisición de lease en `DataPersistenceService`.
  5. Deduplicación atómica con `UpdateAsync` en `MonetizationService` antes de entregar productos.
  6. Corrección de articulación `Neck` en `UpperTorso` y transformación de puntería a espacio objeto en `CharacterController`.
  7. Captura de pantalla enfocada en el rect de la ventana de Roblox Studio.
  8. Protecciones con `pcall` en `Janitor:Cleanup()` y middleware `listenGuarded` en `NetworkSecurityService`.
- `[2026-09-07]` **Aprobación de la Especificación de Arquitectura RAASE 2.1 (SDD Master Blueprint)**:
  1. **Grafo de Escena Bidireccional**: Especificación de `GET_SCENE_GRAPH`, `INSPECT_OBJECT`, `DELETE_OBJECT`, `MODIFY_OBJECT`, y `CLEAR_ZONE` con filtros espaciales AABB, limitadores de profundidad y ChangeHistoryService undo safety.
  2. **Erradicación de Throttling HTTP 429**: Diseño de `BATCH_SPAWN` para agrupar hasta 250 partes por payload HTTP, reduciendo el consumo de la cuota de 500 req/min en un 99.6%.
  3. **Directiva Anti-Neón & Matriz Estética**: Prohibición del uso de Neón en fluidos y superficies estructurales; sustitución obligatoria por `Glass` o `Terrain Water`, adición de rodapiés/cornisas (*bevels* y *trims*), antorchas de punta negra y luces físicas `PointLight.Shadows = true`.
  4. **Expansión del Catálogo a 280 Habilidades**: Creación de 3 nuevos módulos en estándar `agentskills.io`: `roblox-11-map-making` (236-250), `roblox-12-model-maker` (251-265) y `roblox-13-vfx-maker` (266-280).
  5. **DockWidget de Estado en Roblox Studio**: Sustitución del botón plano por un panel dockable interactivo con máquina de estados (🟢 ONLINE, 🟣 BUSY, 🟡 PAUSED, 🔴 OFFLINE), telemetría en tiempo real y registro de comandos.
- `[2026-09-08]` **Remediación de Seguridad y Expansión Completa a 610 Habilidades (35 Dominios Técnicos)**:
  1. **Remediación Crítica de Seguridad en Bridge y Plugin**: Autenticación Bearer Token con `crypto.timingSafeEqual`, restricción CORS a localhost, watchdog con timeout de 5s en `EXECUTE_LUAU` (`task.delay` + `task.cancel`), lista blanca estricta de propiedades mutables en `MODIFY_OBJECT` (`ALLOWED_MODIFY_PROPERTIES` bloqueando `Script.Source`), validación estricta de rutas en `DELETE_OBJECT`, fail-closed en `CLEAR_ZONE`, y soporte de `SpawnLocation` en `BATCH_SPAWN`.
  2. **Descontaminación de skillsGV**: Saneamiento completo de 40 archivos de skills eliminando referencias a proyectos heredados.
  3. **Expansión de Dominios roblox-14 a roblox-35**: 22 nuevos dominios técnicos (330 micro-habilidades en Luau 2026 `--!strict`, frontmatter `agentskills.io` y 5+ reglas inviolables).
  4. **Sincronización Total del Catálogo Canónico**: Reconstrucción de `raase_skills.json`, `roblox-engineer/SKILL.md`, `system_prompt.md`, `CLAUDE.md` y `PROJECT_TRACKER.md` a 35 dominios técnicos y 610 micro-habilidades.

## 5. 🐞 Deferred Issues
- *Ninguno registrado al inicio de la Fase 1.*

