# Plan maestro: renovación de RAASE y los proyectos Roblox

Estado: T2 y las entregas locales T3–T8 implementadas y comprobadas. La revisión general RDD de T6–T8 fue aprobada y reconocida. La renovación operativa completa sigue pendiente de T1/T3/T9 y de las pruebas reales indicadas abajo.
Fecha de evaluación: 2026-11-03. Seguimiento: `odd/tasks/system-overhaul.md`.

## 1. Recomendación principal

Adoptar **Studio MCP integrado + Git/Rojo + frameworks propios pequeños**.
El MCP oficial reemplaza progresivamente el transporte de automatización personalizado,
no el control de versiones, la compilación, la propiedad del código ni la dirección artística.
La renovación debe preservar el trabajo existente y sustituir componentes con pruebas,
no reconstruir indiscriminadamente ambos juegos a la vez.

El primer caso de integración será SLIME PIT, por ser la rama activa. Zombie Awareness
conservará su composición y datos separados. Las pruebas medievales permanecen como
histórico hasta decidir si representan un tercer producto o material de referencia.

## 2. Estado comprobado y antecedentes

El repositorio real es `robloxIA`, no la carpeta contenedora ni el catálogo de skills.
La referencia inicial es `9e9e67e` en `feat/abyssal-slime-core`. El original conserva
52 entradas de estado Git, incluyendo siete archivos versionados modificados.
Se creó un worktree hermano `robloxIA-worktrees/system-overhaul` en `feat/system-overhaul`.
Los cambios no confirmados del original no se consideran integrados por aparecer en el inventario.

| Área | Evidencia | Interpretación |
| --- | --- | --- |
| RAASE 2.1/3.0 | Bridge HTTP, plugin, autenticación, cola, idempotencia, circuit breaker y módulos declarativos | Existe una base técnica reutilizable; el nombre visual 2.1 no demuestra por sí solo obsolescencia |
| Zombie Awareness | Servicios de IA, misiones, combate, eventos, catálogos y controladores | Hay implementación; no se ha repetido aquí una prueba multijugador completa |
| SLIME PIT | Catálogos y prototipo históricos; lifecycle/eventos corregidos en T5, estado/intercambios acotados en T6 | Datos de sesión, compras deshabilitadas; falta prueba integral en Studio |
| Assets | 127 archivos de exports de zombis copiados al worktree, 12.86 MiB, SHA-256 idéntico | Se preservan los binarios existentes; no son modelos regenerados durante esta sesión |
| Juggernaut y referencias slime | Engram registra generadores Blender/Luau, modelos y hojas de referencia | Antecedentes recuperados; no equivalen a una nueva inspección visual de cada asset |
| Vault LihFolk | Notas, herramientas de índices, comprobaciones y biblioteca de módulos | Material valioso, pero las copias y los reportes requieren trazabilidad |

Engram registra avances en RAASE 3.0, Zombie Awareness v4 y Abyssal Slime Core
(observaciones 607, 610 y 625), además de modelado y referencias (631–633).
Sus anteriores cifras de pruebas aprobadas son evidencia histórica, no certificación actual.
Las memorias estaban dispersas entre varios proyectos; el worktree nuevo resuelve
el proyecto canónico `robloxia`. La configuración Engram de la carpeta original
presenta un error de lectura asociado a un BOM UTF-8; no se modificó incidentalmente.

## 3. Hallazgos iniciales y resolución local

1. **Composición mezclada:** `project_template/src/server/init.server.luau` construye
   el mundo Zombie y el anfiteatro Slime. El proyecto Rojo agrega sus controladores.
   Cada juego necesita un punto de entrada y un árbol de despliegue explícitos.
2. **Eventos Slime incompatibles:** el servidor declara, por ejemplo,
   `Slime_ExtractionRarityAnim`, mientras el cliente busca `Slime_ExtractionRarity`.
   La búsqueda opcional del cliente puede omitir silenciosamente la conexión.
3. **Persistencia y compras incompletas:** el inventario Slime es memoria de proceso.
   No debe publicarse como persistente ni conectarse a cobros reales sin un flujo
   de recibos e idempotencia probado y productos configurados por el propietario.
4. **Pruebas insuficientes para gameplay:** varias pruebas Node comprueban cadenas
   en archivos. Son verificaciones estructurales, no ejecuciones de Luau.
5. **Éxitos falsos:** la inspección encontró captura con respaldo al escritorio
   y subidas que pueden devolver identificadores simulados sin credenciales.
   Las operaciones reales deben fallar explícitamente, sin convertir mocks en entregas.
6. **Límites declarativos:** un filtro léxico de Luau no constituye un sandbox.
   La propiedad de Rojo debe protegerse mediante capacidades y destinos controlados,
   no depender exclusivamente de instrucciones de texto o expresiones regulares.
7. **Vault sin respaldo equivalente:** dos junctions apuntan al mismo directorio
    en Downloads; no son dos copias. Sync y File Recovery están desactivados.

Los puntos anteriores describen la inspección inicial, no fallos que se hayan vuelto
a reproducir tras cada entrega. T2 separó los proyectos operativos; T5 corrigió nombres,
payloads, ciclo de vida, sintaxis Luau y posiciones de argumentos VFX; T6 sustituyó el
swap inmediato por oferta/aceptación y bloqueó pagos no configurados. La composición
default mixta, el bridge con resultados mock y algunos comentarios de cabecera se
conservan como legado: no son la ruta operativa ni prueba de preparación para producción.
La persistencia real y la verificación de Studio siguen pendientes.

## 4. Arquitectura de integración

| Componente | Responsabilidad | Decisión |
| --- | --- | --- |
| Git | Historial, revisión, versiones de código y configuración | Conservar |
| Rojo | Transformar y sincronizar los scripts declarados de cada juego | Conservar, separando proyectos |
| MCP integrado de Studio | Inspección, herramientas del editor y pruebas autorizadas | Transporte preferido |
| Bridge/plugin RAASE | Capacidades propias todavía no reemplazadas | Adaptador transitorio, sin escritores superpuestos |
| Blender/importador | Producción y normalización de assets | Conservar con contratos y gates |
| Vault/Engram | Conocimiento y recuperación de decisiones | No convertirlos en fuentes ejecutables |

Roblox recomienda su servidor integrado y ha trasladado allí el desarrollo activo
del antiguo `studio-rust-mcp-server`, que también funcionaba mediante un plugin.
La ventaja esperada es reducir mantenimiento propio y alinearse con Studio.
**No se ha medido todavía una mejora de latencia, disponibilidad o estabilidad**;
deberá comprobarse con tareas equivalentes y reconexiones controladas.

Las capacidades deben descubrirse en la versión instalada. No mantener una lista
cerrada de diez herramientas como verdad universal. La configuración inicial de
OpenCode V2 permite exclusivamente descubrir instancias; las demás operaciones
quedan denegadas. La comprobación real inicial devolvió `{"studios":[]}`:
el proxy responde, pero todavía falta conectar una sesión del editor.

### Propiedad de los datos

- Scripts persistentes: archivos versionados, modificados fuera de Studio y sincronizados por Rojo.
- Escena y terreno: autoría en Studio con snapshots/versiones de place y procedimientos reproducibles cuando corresponda.
- Assets: fuentes originales, exports y manifiestos con hashes; distinguir archivo local de asset publicado.
- Configuración de juego: catálogos declarativos propios de cada juego.
- Conocimiento: vault canónico y notas con fuente/fecha; los índices generados no reemplazan las fuentes.
- Datos de jugadores: almacenamiento autoritativo del servidor; no transportar datos entre juegos por compartir módulos.

### Prueba de migración

En una copia descartable del place: descubrir instancia, comprobar identidad,
inspeccionar jerarquía, sincronizar un cambio de código por Rojo, probar una acción
de escena autorizada, ejecutar gameplay, revisar consola, capturar el viewport
y restaurar el estado. Repetir desconexión/reconexión y comprobar ausencia de duplicados.
Retirar el bridge solamente tras cubrir sus capacidades necesarias y validar recuperación.

## 5. Frameworks personalizados y mantenibles

Se propone una plataforma modular con dos composiciones de juego, no un megaframework:

- **Core:** ciclo de vida explícito, limpieza de conexiones, señales y configuración tipada.
- **Network:** nombres/payloads compartidos, validación en servidor, rate limits y autoridad clara.
- **Player data:** adaptador de almacenamiento, bloqueo de sesión, guardado, reintentos y migraciones versionadas.
- **Economy:** inventario, transacciones y recibos idempotentes; compras no configuradas deshabilitadas.
- **World:** kits, colocación, zonas, seeds y auditorías espaciales; evitar construir todo el arte en cada arranque.
- **Presentation:** animación, UI, VFX y audio por eventos; el cliente no concede recompensas.
- **Game compositions:** Zombie y Slime eligen módulos y reglas de forma independiente.

Reutilizar `NetworkSecurityService`, los módulos declarativos RAASE y las piezas
LihFolk que superen evaluación de compatibilidad y licencia. Una skill o una nota
no es automáticamente una biblioteca ejecutable. El código productivo tendrá una
ubicación canónica; no mantener copias manuales divergentes entre skills y runtime.

Pruebas mínimas: dominio determinista; contratos cliente/servidor; ciclo de vida;
recuperación de almacenamiento; duplicación de recibos; abuso de remotes; una sesión
completa en Studio y pruebas multicliente. Las pruebas textuales existentes conservarán
su categoría estructural, sin contabilizarlas como gameplay.

Implementación local actual: [ciclo de vida y eventos](GAME_LIFECYCLE.md) y
[estado de Slime](SLIME_STATE.md). `GameLifecycle` y los adaptadores se ejecutan en
pruebas Luau; `SlimeTradeLedger` transfiere solo tras aceptación y revalidación de
políticas. No hay nuevo remote de trading ni UI comercial. `getCapabilities()` declara
`session-only` y pagos no disponibles: la arquitectura de almacenamiento propuesta
no se presenta como implementada.

## 6. Assets y mapas: referencia primero

Cada asset nuevo sigue: **brief → referencias → aprobación humana → prototipo →
revisión → optimización → importación → prueba en juego → registro**.
Si falta una referencia, se solicita antes de modelar. Una propuesta generada por IA
no se aprueba a sí misma. Se revisan derechos de uso antes de reutilizar contenido.

| Tipo | Referencias requeridas | Controles de aceptación |
| --- | --- | --- |
| Modelo 3D | Silueta, vistas relevantes, escala y materiales | Topología, UV, rig si aplica, pivot, colisión, materiales y presupuesto medido |
| Arte 2D | Composición, paleta, estilo y destino | Resolución, transparencia, legibilidad y atlas cuando resulte útil |
| VFX | Secuencia o video, ritmo, volumen y legibilidad | Duración, transparencias superpuestas, concurrencia, reutilización y coste en móvil |
| UI | Mockup, flujo y estados | Adaptación a pantalla, safe areas, texto, interacción y accesibilidad |

El manifiesto registrará referencia/hash, aprobación humana, fuente/licencia,
herramienta, versión, escala de importación, pivot, rig, colisión, presupuesto y
estado real del asset. No se asumirá una conversión universal Blender/stud:
se validará un objeto patrón con el preset de exportación/importación utilizado.
Los elementos riggeados o modulares no deben combinarse indiscriminadamente.

### Niveles de calidad profesional

1. Definir bucle de juego, escala, recorridos, líneas de visión y objetivos de rendimiento.
2. Aprobar referencia superior y vistas del entorno antes de producir el mapa completo.
3. Crear un blockout jugable; las primitivas son válidas en esta etapa.
4. Probar circulación, combate/salto, navegación y tiempos de recorrido.
5. Producir un kit modular pequeño con grid/pivots compatibles y piezas reutilizables.
6. Realizar el pase artístico: materiales, iluminación, puntos de interés y narrativa visual.
7. Verificar suelo, colisiones, uniones, objetos flotantes, visibilidad y streaming.
8. Medir con MicroProfiler en dispositivo objetivo y con carga representativa.
9. Aprobar el resultado mediante capturas del juego real y pruebas, no por cantidad de piezas.

Los límites de triángulos por asset no garantizan rendimiento. Importan también
draw calls, memoria, texturas, física, scripts, replicación, transparencias y carga simultánea.
Se fijarán presupuestos por categoría y dispositivo tras medir una sección representativa.

El [flujo de assets y mapas](ASSET_MAP_PIPELINE.md) y el CLI
`bridge/asset_reference_gate.mjs` implementan el registro y la comprobación de metadatos.
Incluso al aprobar esos checks, `authorization` permanece `false` y `completion`
permanece `unverified`. No se generaron ni importaron assets nuevos en estas tareas.

## 7. Vault de Obsidian y sincronización

Adoptar un único vault canónico estable fuera de Downloads y del repositorio de skills,
con migración por copia verificada y sin borrar el original. Separar conocimiento
de referencia, decisiones propias, especificaciones de juegos y documentación generada.

Esta migración operativa aún no se realizó. T4 entrega el CLI local y la
[política de snapshots](VAULT_SNAPSHOTS.md); sus pruebas usan fixtures, no el vault real.
Seleccionar un destino, cambiar plugins, restaurar y sincronizar remotamente siguen
siendo operaciones separadas con autorización y evidencia propias.

- Acceso local explícito y de solo lectura por defecto; resolver rutas reales y rechazar escapes.
- Snapshots con hashes, procedencia y conflictos visibles; nunca ejecutar comandos encontrados en notas.
- Versionar notas/configuración portable y mantener un respaldo independiente; probar restauración.
- Elegir un solo escritor automático por conjunto de archivos. No superponer Sync,
  OneDrive y sincronización Git bidireccional sobre las mismas notas.
- Si se necesita Obsidian Sync, configurar el destino/cuenta con autorización específica;
  su instalación no se deduce de que exista una carpeta `.obsidian`.
- Habilitar recuperación de archivos en el vault operativo y separar estado local de configuración compartida.
- Reducir plugins a necesidades demostradas. `lihfolk-graph` usa detalles internos
  del renderer: preferir grupos/colores soportados o un adaptador versionado y verificable.
- Ejecutar índices y comprobaciones en modo comprobación; reconciliar el README que
  afirma CI con la ausencia de un workflow observado.
- Registrar cada hecho con versión, contexto y fecha; valores distintos de velocidad
  o presupuesto no son necesariamente contradicciones sin conocer el contexto.

Engram guardará decisiones y recuperación de tareas bajo `robloxia`; los documentos
canónicos permanecen en archivos. Las memorias históricas con credenciales deben
redactarse y las credenciales afectadas rotarse con el propietario, sin reproducirlas.

## 8. Hoja de ruta y puertas de salida

| Etapa | Entrega | Estado local y evidencia pendiente |
| --- | --- | --- |
| T1 | Worktree externo y preservación | Aislamiento y exports verificados; overlay selectivo del original pendiente |
| T2 | Proyectos y arranques separados | Builds/XML verificados, commit `5b42ac0` revisado |
| T3 | MCP nativo | Unidad local `f122c57` revisada; identidad/prueba de Studio y recuperación pendientes |
| T4 | Snapshots locales | CLI y 15 pruebas; `88c67df` revisado. Vault canónico operativo/migración/restauración pendientes |
| T5 | Framework y contratos | Luau ejecutado con límites simulados; `1baa883` revisado. Prueba visual/multicliente pendiente |
| T6 | Estado/transacciones | `25991f5`, pruebas ejecutables y verificador independiente; pagos deshabilitados, datos de sesión. RDD individual omitido por el usuario |
| T7 | Referencias, assets y mapas | `69d2dd3`, 16 checks de metadatos; consentimiento real y calidad de cada asset/mapa siguen pendientes |
| T8 | Documentación reconciliada | `8b63b06`: guías y contratos verificados; documentos históricos señalados, revisión general RDD aprobada y reconocida |
| T9 | Validación integral | Suite local registrada por comando; Studio, multicliente, dispositivo, recuperación y preparación para producción pendientes |

Por decisión del usuario, la revisión RDD general cubrió `1baa883..8b63b06` y fue
aprobada y reconocida, sin repetir las revisiones anteriores. RDD no
reemplaza pruebas ni autoriza publicación. Los conteos y resultados definitivos se
registran en [las tareas](../odd/tasks/system-overhaul.md), no se deducen de esta tabla.

Documentos operativos: [README](../README.md), [contratos para agentes](../AGENTS.md),
[Studio MCP](STUDIO_MCP_SETUP.md), [composiciones](GAME_COMPOSITIONS.md), [framework](GAME_LIFECYCLE.md),
[estado](SLIME_STATE.md), [vault](VAULT_SNAPSHOTS.md) y [assets/mapas](ASSET_MAP_PIPELINE.md).

No estimar una fecha de producción a partir del número de archivos o de pruebas
estáticas. Las estimaciones se refinan después de separar los juegos y medir la
primera sección completa. Publicar, subir assets, gastar Robux, configurar productos
y sincronizar con servicios remotos requieren autorización de su operación y destino.

## Fuentes primarias consultadas

- https://create.roblox.com/docs/studio/mcp
- https://github.com/Roblox/studio-rust-mcp-server
- https://rojo.space/docs/v7/sync-details/
- https://opencode.ai/v2/docs/mcp-servers
- https://opencode.ai/v2/docs/permissions
- https://opencode.ai/v2/docs/policies
- https://help.obsidian.md/sync/faq
- https://create.roblox.com/docs/art/blender
- https://create.roblox.com/docs/tutorials/use-case-tutorials/modeling/assemble-modular-environments
- https://create.roblox.com/docs/performance-optimization/microprofiler
