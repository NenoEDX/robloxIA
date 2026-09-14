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

## Doctrina de Modelado 3D "Mesh-First" y Auditoría contra Referencias
- **Prohibición Estricta de "Slop de Cubos"**:
  * Queda TERMINANTEMENTE PROHIBIDO intentar construir vehículos (autos, buses, tanques), armas, maquinaria, props detallados, muebles complejos, maniquíes/NPCs o vegetación apilando bloques primitivos (`Part`, `Wedge`, `Cylinder`).
  * Para cualquier objeto complejo, la PRIMERA Y OBLIGATORIA OPCIÓN es una **Malla 3D Dedicada (`MeshPart` / `.glb`)** modelada en Blender, generada con herramientas Image-to-3D (Tripo3D, Meshy, Trellis) o extraída de packs de assets curados.
  * Los bloques primitivos del motor se restringen EXCLUSIVAMENTE a: suelos base, aceras planas, cajas de colisión invisibles (`Transparency = 1`), triggers de volumen y zonas de interacción.
- **Auditoría Estética y Comparación con Referencias Reales**:
  * Antes de dar por bueno un asset o dar por concluido un escenario, el agente DEBE contrastar mental y visualmente las proporciones contra objetos del mundo real o referencias de arte conceptual AAA.
  * Checklist de calidad visual (Escala de Avatar: 5 studs de alto x 2 studs de ancho):
    1. ¿Las ruedas, puertas y asientos tienen proporción humana creíble?
    2. ¿Existen techos, losas o partes flotando sin soporte estructural?
    3. ¿Se ve como un objeto real o como un "juguete tosco de bloques"?
  * Si al auditar con `capture` el modelo se ve fuera de lugar, infantil o desalineado, el agente DEBE descartar la geometría primitiva y priorizar la generación o importación de la malla 3D dedicada.
- **Prohibición Absoluta de Geometría Flotante (Ground-Snapping & Anclaje Estructural)**:
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
