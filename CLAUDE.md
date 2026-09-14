# RAASE 2.0 / robloxIA — Reglas de Ingeniería para Agentes CLI

## Identidad y Alcance
Este proyecto implementa el sistema **RAASE 2.0 (robloxIA)**: una arquitectura autónoma para Roblox Studio basada en agentes de IA, sincronización de código con Rojo, manipulación de escena vía plugin RPC local (`127.0.0.1:34873`) y auditoría estética mediante visión computacional.

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

## Cinemática y Rigs
- En animaciones procedimentales (apuntado, giros de cabeza), manipular EXCLUSIVAMENTE `Motor6D.Transform` en hilos de render (`RenderStepped`).
- Prohibido terminantemente modificar `C0` o `C1` en bucles en tiempo de ejecución.

## Doctrina Dual: Estructuras Clásicas Roblox vs Props Especializados 3D con Efectos
- **1. Estructuras Arquitectónicas ("Modelos Roblox Normalitos")**:
  * Los bloques simples de Roblox (`Part`, `WedgePart`, `CornerWedgePart`, `TrussPart`) se reservan **EXCLUSIVAMENTE para la estructura bruta: cimientos, suelos, muros, columnas, marcos y A LO MUCHO TEJADOS**.
  * **CERO DECORACIÓN CON BLOQUES SIMPLES (NADA DE NADA):** Queda TERMINANTEMENTE PROHIBIDO usar bloques primitivos de Roblox para mobiliario, accesorios, cartelería o decoración (nada de barriles de cilindros, cajas de cubos, carpas de cuñas o muebles improvisados con bloques).
  * Usar combinaciones limpias de materiales nativos (`Concrete`, `WoodPlanks`, `Brick`, `CorrodedMetal`, `Fabric`, `Glass`, `SmoothPlastic`).
  * Mantener proporciones modulares (rejilla de 2, 4 u 8 studs), rodapiés, cornisas y techos apoyados exactamente sobre muros (`Anchored = true`, sin Z-fighting con desfase >= 0.05 studs).

- **2. Props, Decoración Interior, Cercas y Elementos Complejos (Mallas 3D Dedicadas por Separado)**:
  * **Taxonomía Obligatoria de Mallas 3D (`MeshPart` / `.glb`):**
    - *Cercas, Vallas y Delimitadores:* Alambradas de púas, cercas de malla (*chainlink*), vallas de madera rústicas, rejas de hierro forjado con barrotes/remaches, barandillas de escaleras y balcones, vallas peatonales, barreras Jersey con roturas. (¡Prohibido crear rejas con palitos de 0.2 studs!).
    - *Mobiliario (Interior y Exterior, Cada Uno por Separado):* Mesas, sillas, sillones, bancos, escritorios, estanterías, casilleros metálicos (*lockers*), camas, literas, armarios, mostradores.
    - *Infraestructura Urbana e Industrial:* Postes de luz curva, semáforos, tuberías con codos curvos y válvulas, ductos HVAC, transformadores, generadores, contenedores de basura (*dumpsters*), palets, barriles industriales con aros en relieve.
    - *Vehículos y Maquinaria:* Autos, camiones, motos, carretillas, chasis quemados, ruedas sueltas.
    - *Armamento, Herramientas e Interactivos:* Fusiles, pistolas, espadas, bates, cofres, cajas de munición, terminales de control.
    - *Vegetación y Naturaleza:* Árboles orgánicos, tocones, rocas con facetas, arbustos y enredaderas.
    - *Escombros y Clutter:* Pilas de concreto con varillas dobladas, sacos de arena orgánicos con pliegues, tablones rotos.
  * **Modelado Individual por Separado:** Si un edificio tiene interior o zona de props, **CADA OBJETO SE MODELA POR SEPARADO**. Jamás fundir muebles en los muros.
  * **Colores Puestos de una Vez (Cero Mallas Grises):** Toda malla 3D debe salir coloreada de inmediato:
    a) *Vertex Colors en Blender (.glb)*: El script de Blender hornea automáticamente los colores de los materiales en los atributos de vértice (`Color Attribute`), para que al importarse en Roblox Studio muestre todos sus colores nativos de inmediato sin texturas adicionales.
    b) *Modelos multi-pieza:* Sub-partes semánticas (`Body`, `Legs`, `Glass`, `Lights`), cada una con su `Color3.fromRGB(...)` y `Material` nativo.
    c) *Texturas PBR:* `SurfaceAppearance` con `ColorMap` cuando proceda de fotogrametría o IA.
  * **Paquete de Efectos Visuales (VFX Bundle Obligatorio en Objetos Especiales):**
    * Partículas dinámicas (`ParticleEmitter`): humo, chispas, llamas, vapor o ascuas con curvas `NumberSequence` suaves.
    * Iluminación dinámica (`PointLight` o `SpotLight`): alojada dentro de la fuente con `Shadows = true`, brillo suave (1.5 - 2.8) y rango adaptado.
    * Acentos emisivos: partes o runas con `Material = Enum.Material.Neon` para brillo Bloom nativo.
    * Audio 3D y Highlight: para objetos interactivos (`ProximityPrompt`).
  * **Catálogo de 10 Anti-Patrones Prohibidos:** Prohibido crear: (1) vallas de palitos, (2) barandales flotantes, (3) mesas de 5 cubos, (4) tuberías ortogonales de 90° sin codos, (5) barriles de cilindro liso, (6) árboles de Minecraft, (7) sacos de arena como ladrillos rígidos, (8) puertas/ventanas planas con Decal, (9) carteles flotantes sin poste o anclaje, (10) antorchas de cubo neón.

- **3. Prohibición Absoluta de Geometría Flotante (Ground-Snapping & Anclaje Estructural)**:
  * Queda TERMINANTEMENTE PROHIBIDO dejar techos, carteles, muebles, vehículos, maniquíes o escombros flotando en el aire sin soporte físico visible.
  * **Anclaje al suelo obligatorio:** Todo objeto terrestre debe calcular su altura mediante `Raycast` hacia abajo o mediante la fórmula matemática estricta: `posY = surfaceY + (sizeY / 2)`. Cero coordenadas Y inventadas a ojo.
  * **Carteles y letreros:** Deben nacer montados sobre un poste que toque el suelo o pegados directamente a la superficie de un muro (`SurfaceGui`). Prohibido instanciar carteles suspendidos en el vacío.
  * **Integridad estructural en cubiertas:** Toda losa de techo debe coincidir exactamente con la cota superior de los muros o pilares de soporte en sus 4 esquinas.

## DevEx 2026
- `MarketplaceService.ProcessReceipt` debe ser idempotente, guardando el `PurchaseId` en DataStore mediante `UpdateAsync()` antes de otorgar beneficios.
- Si la base de datos falla, retornar siempre `Enum.ProductPurchaseDecision.NotProcessedYet`.
- Configurar el juego exclusivamente con avatares R15 para calificar a la tasa preferencial U.S. 18+ ($0.0054 por Robux).

## Soberanía del Creador y No-Resurrección de Objetos
- El usuario humano en Roblox Studio es la MÁXIMA AUTORIDAD del proyecto.
- Si un objeto, modelo o terreno fue borrado o editado por el usuario, QUEDA ESTRICTAMENTE PROHIBIDO volver a crearlo, restaurarlo o sobreescribirlo sin orden explícita del creador.
- Jamás re-ejecutar scripts generadores monolíticos completos sobre un mapa en edición. Usar siempre micro-mutaciones selectivas (`MODIFY_OBJECT`, `DELETE_OBJECT`, o `BATCH_SPAWN` para elementos nuevos).
- Antes de modificar cualquier zona, consultar el estado real del Workspace con `GET_SCENE_GRAPH` o `INSPECT_OBJECT`.

## Protocolo de Convergencia Visual (Máximo 2 Pases - Anti-Bucle)
- Fase 1: 1 captura de Viewport (`POST /api/capture`) -> Identificar defectos -> Aplicar un único paquete de micro-ajustes.
- Fase 2: 1 captura de verificación -> Confirmar aplicación.
- PARADA OBLIGATORIA: Tras la verificación (o si no hubo defectos en Fase 1), detener inmediatamente cualquier captura adicional y devolver el control al usuario.

## Estructura del Repositorio
- `bridge/`: Servidor HTTP local (puerto `34873`) con cortacircuitos de captura y worker de captura no invasivo.
- `plugin/`: Companion Plugin para Roblox Studio (gestión con `ChangeHistoryService` y Smart Upsert).
- `project_template/`: Estructura estándar de juego en Luau gestionada con Rojo.
- `agent/`: Catálogo JSON de 610 skills RAASE (35 dominios técnicos), CLI de orquestación y prompts de sistema.
- `docs/`: Especificación formal RAASE 2.0 / 2.1.
