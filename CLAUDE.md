# RAASE 3.0 / robloxIA — Reglas de Ingeniería para Agentes CLI

## Identidad y Alcance
Este proyecto implementa el sistema **RAASE 3.0 Next-Gen (robloxIA)**: una arquitectura autónoma para Roblox Studio basada en agentes de IA, sincronización de código persistente con **Rojo**, control e inspección en vivo mediante el servidor oficial **`StudioMCP`** (`stdio`) y **`MCPBridge`** (`127.0.0.1:7843` / `:34873`), pipeline 3D coloreado con **Open Cloud Assets API (`v1/assets`)** y auditoría estética/funcional en bucle cerrado.

## Reglas Obligatorias de Luau 2026
1. Todo script Luau (`.luau`) DEBE comenzar con `--!strict`.
2. Prohibido el uso de `any` descontrolado. Usar tipos estrictos (`export type ...`).
3. Acceso canónico a servicios exclusivamente mediante `game:GetService("NombreServicio")`.
4. Comparaciones explícitas de nulidad (`valor == nil`).
5. Prohibidas las funciones obsoletas `spawn()`, `delay()` y `wait()`. Usar exclusivamente la biblioteca nativa `task`.
6. Formato de código: StyLua (tabulaciones físicas, límite de 100 caracteres por línea).

## Seguridad Zero-Trust
- El cliente es considerado comprometido y hostil.
- El servidor tiene autoridad absoluta sobre vida, daño, inventario, precios y distancias espaciales.
- Todo `RemoteEvent` debe validar tipos con `typeof()`, distancia euclidiana (`.Magnitude <= 15`) y pasar por un limitador de tasa *Token Bucket*.
- Desplegar remotos señuelo (*honeypots*) para expulsar automáticamente clientes que usen *RemoteSpy*.

## Ciclo de Vida y Memoria (Janitor)
- Todo componente que escuche señales o instancie partes debe implementar el patrón `Janitor`.
- Desconectar obligatoriamente todo `RBXScriptConnection` al morir el personaje o destruirse la entidad.
- Las instancias eliminadas deben desecharse formalmente con `:Destroy()`.

## Cinemática y Rigs (Política Dual: IKControl vs. Motor6D.Transform)
- Para el jugador local, héroes y bosses ($\le 12$ rigs simultáneos), usar **`ProceduralAnimator.AttachIK(character, config)`** (envolviendo `IKControl` nativo con restricciones anatómicas `BallSocketConstraint` `LimitsEnabled = true`).
- Para hordas masivas de NPCs ($> 15$ entidades), manipular **`Motor6D.Transform`** en hilos de render (`RenderStepped`).
- Prohibido terminantemente modificar `C0` o `C1` en bucles en tiempo de ejecución.

## Doctrina Dual: Estructuras Clásicas Roblox vs Props Especializados 3D con Efectos
- **1. Estructuras Arquitectónicas ("Modelos Roblox Normalitos")**:
  * Los bloques simples de Roblox (`Part`, `WedgePart`, `CornerWedgePart`, `TrussPart`) se reservan **EXCLUSIVAMENTE para la estructura bruta: cimientos, suelos, muros, columnas, marcos y A LO MUCHO TEJADOS**.
  * **CERO DECORACIÓN CON BLOQUES SIMPLES (NADA DE NADA):** Queda TERMINANTEMENTE PROHIBIDO usar bloques primitivos de Roblox para mobiliario, accesorios, cartelería o decoración (nada de barriles de cilindros, cajas de cubos, carpas de cuñas o muebles improvisados con bloques).
  * Usar combinaciones limpias de materiales nativos (`Concrete`, `WoodPlanks`, `Brick`, `CorrodedMetal`, `Fabric`, `Glass`, `SmoothPlastic`).
  * Mantener proporciones modulares (rejilla de 2, 4 u 8 studs), rodapiés, cornisas y techos apoyados exactamente sobre muros (`Anchored = true`, sin Z-fighting con desfase >= 0.05 studs).

- **2. Props, Decoración Interior, Cercas y Elementos Complejos (Mallas 3D Dedicadas por Separado)**:
  * **Taxonomía Obligatoria de Mallas 3D (`MeshPart` / `.glb` / `.fbx`):**
    - *Cercas, Vallas y Delimitadores:* Alambradas de púas, cercas de malla (*chainlink*), vallas de madera rústicas, rejas de hierro forjado con barrotes/remaches, barandillas de escaleras y balcones, vallas peatonales, barreras Jersey con roturas. (¡Prohibido crear rejas con palitos de 0.2 studs!).
    - *Mobiliario (Interior y Exterior, Cada Uno por Separado):* Mesas, sillas, sillones, bancos, escritorios, estanterías, casilleros metálicos (*lockers*), camas, literas, armarios, mostradores.
    - *Infraestructura Urbana e Industrial:* Postes de luz curva, semáforos, tuberías con codos curvos y válvulas, ductos HVAC, transformadores, generadores, contenedores de basura (*dumpsters*), palets, barriles industriales con aros en relieve.
    - *Vehículos y Maquinaria:* Autos, camiones, motos, carretillas, chasis quemados, ruedas sueltas.
    - *Armamento, Herramientas e Interactivos:* Fusiles, pistolas, espadas, bates, cofres, cajas de munición, terminales de control.
    - *Vegetación y Naturaleza:* Árboles orgánicos, tocones, rocas con facetas, arbustos y enredaderas.
    - *Escombros y Clutter:* Pilas de concreto con varillas dobladas, sacos de arena orgánicos con pliegues, tablones rotos.
  * **Modelado Individual por Separado:** Si un edificio tiene interior o zona de props, **CADA OBJETO SE MODELA POR SEPARADO**. Jamás fundir muebles en los muros.
  * **Colores Puestos de una Vez (Cero Mallas Grises):** Toda malla 3D debe salir coloreada de inmediato desde `blender_export_example.py`:
    a) *Vertex Colors en Blender (`.glb`/`.fbx`)*: `bake_materials_to_vertex_colors(objs)` hornea automáticamente los colores de los materiales en `mesh.color_attributes` (`BYTE_COLOR`/`CORNER`).
    b) *Palette Atlas UV (`map_uv_to_palette_atlas`)*: Colapsa las islas UV de cada cara a escala `(0, 0)` centradas en el píxel correspondiente de una paleta $16 \times 16$ ($256 \times 256\text{ px}$, 1 Draw Call).
    c) *Presupuesto Poligonal*: Validación estricta `< 20,000` triángulos por malla (`validate_mesh_budget`) antes de subir a Open Cloud (`bridge/open_cloud.mjs`).
  * **Paquete de Efectos Visuales (VFX Bundle Obligatorio en Objetos Especiales):**
    * Partículas dinámicas (`ParticleEmitter`): humo, chispas, llamas, vapor o ascuas con curvas `NumberSequence` suaves.
    * Iluminación dinámica (`PointLight` o `SpotLight`): alojada dentro de la fuente con `Shadows = true`, brillo suave (1.5 - 2.8) y rango adaptado.
    * Acentos emisivos: partes o runas con `Material = Enum.Material.Neon` para brillo Bloom nativo.
    * Audio 3D y Highlight: para objetos interactivos (`ProximityPrompt`).
  * **Catálogo de 10 Anti-Patrones Prohibidos:** Prohibido crear: (1) vallas de palitos, (2) barandales flotantes, (3) mesas de 5 cubos, (4) tuberías ortogonales de 90° sin codos, (5) barriles de cilindro liso, (6) árboles de Minecraft, (7) sacos de arena como ladrillos rígidos, (8) puertas/ventanas planas con Decal, (9) carteles flotantes sin poste o anclaje, (10) antorchas de cubo neón.

- **3. Prohibición Absoluta de Geometría Flotante (Ground-Snapping & Anclaje Estructural)**:
  * Queda TERMINANTEMENTE PROHIBIDO dejar techos, carteles, muebles, vehículos, maniquíes o escombros flotando en el aire sin soporte físico visible.
  * **Anclaje al suelo obligatorio (`WorldAssembler.PlaceGrounded`):** Todo objeto terrestre debe calcular su altura mediante `workspace:Raycast` vertical hacia abajo compensando `GetExtentsSize().Y / 2`. Cero coordenadas Y inventadas a ojo.
  * **Carteles y letreros:** Deben nacer montados sobre un poste que toque el suelo o pegados directamente a la superficie de un muro (`SurfaceGui`). Prohibido instanciar carteles suspendidos en el vacío.
  * **Integridad estructural en cubiertas:** Toda losa de techo debe coincidir exactamente con la cota superior de los muros o pilares de soporte en sus 4 esquinas.

## Arquitectura Next-Gen RAASE 3.0: Coexistencia Rojo + StudioMCP + 4 Módulos Maestros

### 1. Soberanía de Rojo vs. `StudioMCP` (`bridge/mcp_doctor.mjs`)
- **Regla de Oro**: Todo código Luau persistente vive en `project_template/src/` y se sincroniza hacia Roblox Studio vía **Rojo** (`default.project.json` -> `ReplicatedStorage.RAASE_Shared`, `ServerScriptService.RAASE_Server`, `StarterPlayerScripts.RAASE_Client`).
- Queda **TERMINANTEMENTE PROHIBIDO** mutar `.Source` o destruir módulos dentro de contenedores gobernados por Rojo desde `execute_luau`. Usa `execute_luau` únicamente para requerir e invocar declarativamente los Módulos Maestros o inspeccionar el `DataModel`.
- En Windows, configura `StudioMCP` usando la ruta absoluta resuelta hacia `mcp.bat` (ver `mcp_config.example.json` y `node bridge/mcp_doctor.mjs`); nunca uses `%LOCALAPPDATA%` sin expandir en `command`.
- Las **10 herramientas oficiales de `StudioMCP`** son: `execute_luau`, `insert_model`, `generate_mesh`, `generate_material`, `start_stop_play`, `character_navigation`, `user_keyboard_input`, `user_mouse_input`, `get_console_output` y `screen_capture` (invocando primero `list_roblox_studios` para obtener `studio_id`). Para insertar un `assetId` de Open Cloud, usa `InsertService:LoadAsset(assetId)` vía `execute_luau` o `MCPBridge`.

### 2. Los 4 Módulos Maestros Declarativos (`ReplicatedStorage.RAASE_Shared`)
1. **`VoxelTerrainBuilder` (`project_template/src/shared/VoxelTerrainBuilder.luau`)**:
   - `VoxelTerrainBuilder.GenerateFBM(config)`: Terreno suave con `Region3:ExpandToGrid(4)`, ruido Perlin FBM de 4–6 octavas (`math.noise`), ocupancia fraccional continua $\in [0, 1]$ y materiales automáticos por pendiente/altitud (`Rock`, `Sand`, `Grass`, `Snow`, `Water`).
   - `VoxelTerrainBuilder.CarveRoadPath(points, widthStuds, roadMaterial?)`: Esculpido y aplanado de caminos mediante `ReadVoxels` / `WriteVoxels`.
2. **`WorldAssembler` (`project_template/src/shared/WorldAssembler.luau`)**:
   - `WorldAssembler.PlaceGrounded(model, position, options?)`: `workspace:Raycast` vertical hacia abajo + compensación exacta `GetExtentsSize().Y / 2` + alineación opcional a la normal de la pendiente (`AlignToSlope`) + snapping a grilla.
   - `WorldAssembler.SmartUpsert(parent, template, name, targetPosition, options?)`: Respeta `RAASE_Locked == true` (RN-10 Soberanía del Creador).
3. **`ProceduralAnimator` (`project_template/src/shared/ProceduralAnimator.luau`)**:
   - `ProceduralAnimator.AttachIK(character, config)`: Envuelve `IKControl` nativo (`Transform`, `Position`, `LookAt`) y aplica límites anatómicos `BallSocketConstraint` (`LimitsEnabled = true`) para héroes, jugador local y bosses.
   - `ProceduralAnimator.CreateSpring2D(omega0?, zeta?, initialPos?)`: Oscilador armónico amortiguado 2D ($\zeta \in [0.45, 0.75]$) para UI y cámara.
   - `ProceduralAnimator.CreateFlipbookController(imageLabel, cols, rows, w, h, fps?)`: Spritesheets 2D mediante `ImageRectSize` e `ImageRectOffset`.
4. **`VFXAndJuiceEngine` (`project_template/src/shared/VFXAndJuiceEngine.luau`)**:
   - `VFXAndJuiceEngine.CastEffect(effectType, cframe, scale?, options?)`: Composición obligatoria de **5 capas** (Capa 1: `CoreFlash` con `PointLight`; Capa 2: `ShockwaveRing` con `EasingStyle.Quart`; Capa 3: `SlashBeam` con `FaceCamera = false` y `LightEmission = 1`; Capa 4: `DirectionalSparks` con `VelocityParallel` y `Squash = -1.5`; Capa 5: `VoxelDebris` contextual muestreando `Material` y `Color` del suelo vía `Raycast`).
   - Incluye `AddTrauma(amount)` (sacudida cúbica $S = T^3$ en `Enum.RenderPriority.Camera.Value + 1`), `TriggerHitFlash(targetModel, 0.12)` (`Highlight` blanco `0.1 -> 1.0`), `ApplyHitstop(character, frames)` y `PlayModulatedSound(...)` ($\pm 9\%$ pitch + knockback).

### 3. Protocolo de QA Autónomo en Bucle Cerrado (Playtest QA + RN-11)
Toda implementación de mecánicas de movimiento, combate o interacción concluye ejecutando:
1. `list_roblox_studios` -> obtener `studio_id`.
2. `start_stop_play` -> iniciar simulación en vivo.
3. `character_navigation` + `user_keyboard_input` / `user_mouse_input` -> navegar y disparar la interacción.
4. `get_console_output` -> verificar **0 errores** de tiempo de ejecución.
5. `screen_capture` -> verificar fidelidad visual (respetando el tope máximo de 2 pases de `RN-11`) y detener el playtest con `start_stop_play`.

## DevEx 2026 y Soberanía del Creador (RN-10)
- `MarketplaceService.ProcessReceipt` debe ser idempotente, guardando el `PurchaseId` en DataStore mediante `UpdateAsync()` antes de otorgar beneficios.
- Configurar el juego exclusivamente con avatares R15 para calificar a la tasa preferencial U.S. 18+ ($0.0054 por Robux).
- El usuario humano en Roblox Studio es la MÁXIMA AUTORIDAD del proyecto (`RN-10`). Prohibido re-crear o sobreescribir objetos borrados o bloqueados (`RAASE_Locked`) por el creador.

## Estructura del Repositorio
- `bridge/`: Servidor HTTP local, conector Open Cloud (`.glb`/`.fbx`), doctor MCP (`mcp_doctor.mjs`) y suites de tests (`node --test`).
- `plugin/`: Companion Plugin para Roblox Studio (gestión con `ChangeHistoryService` y Smart Upsert).
- `project_template/`: Estructura estándar de juego en Luau gestionada con Rojo (incluye los 4 Módulos Maestros en `src/shared/`).
- `agent/`: Catálogo JSON de 610 skills RAASE (35 dominios técnicos + extensiones 36/37/38), generadores Blender y prompts de sistema.
- `docs/`: Especificación formal RAASE 2.0 / 2.1 y Arquitectura Next-Gen 3.0 (`ARQUITECTURA_ROBLOX_IA_NEXTGEN.md`).
