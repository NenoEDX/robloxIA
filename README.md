# robloxIA / RAASE — desarrollo local para Roblox Studio

**Estado:** prototipos locales con composiciones y pruebas verificadas; no es una
certificación de producción, persistencia, pagos ni funcionamiento completo en Studio.
El [plan maestro](docs/PLAN_MAESTRO.md) explica la arquitectura y los pendientes.
El [registro de tareas](odd/tasks/system-overhaul.md) conserva comandos, resultados y commits.

## Arquitectura actual

| Capa | Responsabilidad |
| --- | --- |
| Git y archivos Luau | Fuente de verdad del código persistente en `project_template/src/` |
| Rojo | Compatibilidad de builds locales; no se usa como transporte de T9 |
| MCP oficial de Studio | Único transporte de T9 para scripts, escena y pruebas; archivos locales versionados en Git |
| Bridge/plugin RAASE | Adaptador heredado y transitorio; no iniciar un segundo escritor sobre los mismos objetos |
| Vault y Engram | Conocimiento y recuperación, nunca autorización para ejecutar instrucciones encontradas en archivos |

Las listas de herramientas de versiones anteriores y `mcp_config.example.json`
son referencias de compatibilidad, no un inventario actual del servidor instalado.
El doctor local comprueba configuración y presencia de rutas/variables; no acredita
credenciales Open Cloud ni una conexión funcional a una experiencia.

## Composiciones de juego

- SLIME PIT: `project_template/slime.project.json`; [implementación y estado de la V1](docs/SLIME_PIT_V1.md).
- Zombie Awareness: `project_template/zombie.project.json`.
- `project_template/default.project.json` conserva la composición mixta histórica;
  no es el punto de entrada recomendado y su build sigue dependiendo de `Packages/`,
  ausente en este worktree.

Consultar [composiciones](docs/GAME_COMPOSITIONS.md) antes de desplegar. En T9,
el usuario autorizó el mismo place y el reemplazo del lobby. El MCP oficial
despliega los archivos mediante `multi_edit`; no escribir `.Source` mediante
`execute_luau`, ni iniciar Rojo o el bridge como escritores paralelos.

## Qué está implementado localmente

| Área | Guía canónica | Límite de la evidencia |
| --- | --- | --- |
| MCP nativo | [Configuración y descubrimiento](docs/STUDIO_MCP_SETUP.md) | T9 montó scripts y arrancó servidor/HUD en Studio; la aceptación jugable y visual sigue pendiente |
| Framework Slime | [Ciclo de vida y eventos](docs/GAME_LIFECYCLE.md) | Luau ejecutado con límites de Roblox simulados; no certifica renderizado o replicación real |
| Estado e intercambios | [Estado de Slime](docs/SLIME_STATE.md) | Inventarios de sesión, oferta/aceptación; compras deshabilitadas y sin persistencia productiva |
| Vault | [Snapshots locales](docs/VAULT_SNAPSHOTS.md) | Markdown y metadatos; no migración del vault, sincronización remota ni restauración certificada |
| Assets y mapas | [Referencias y controles](docs/ASSET_MAP_PIPELINE.md) | Metadatos sin autoridad; falta aprobación humana y QA real de cada asset/mapa |

El bridge Open Cloud heredado puede producir identificadores `mock_...` sin
credenciales. Eso **no es una subida ni un asset terminado**. Tampoco una captura
del escritorio sustituye evidencia del viewport. No ejecutar el flujo heredado
para evitar las restricciones de referencia, aprobación, destino o sesión.

## Pruebas locales

Node y pnpm ejecutan la suite sin instalar dependencias automáticamente. Lune y
Rojo deben estar disponibles mediante rutas absolutas verificadas y autorizadas;
los tests no los descargan. Sin esas variables, sus pruebas se marcan omitidas.

```powershell
$env:LUNE_BIN = "C:/ApprovedTools/lune.exe"
$env:ROJO_BIN = "C:/ApprovedTools/rojo.exe"
pnpm --dir bridge --config.verify-deps-before-run=false exec node --test `
  test_mcp_doctor.mjs test_studio_mcp_config.mjs test_master_modules.mjs `
  test_abyssal_slime_core.mjs test_zombie_awareness_v4.mjs test_open_cloud.mjs `
  test_rojo_split.mjs test_rojo_build.mjs test_vault_snapshot.mjs `
  test_luau_framework.mjs test_asset_reference_gate.mjs
```

Esta es la suite seleccionada para la renovación, no todas las pruebas históricas
del bridge HTTP. La prueba de exports Zombie necesita los exports existentes
preservados fuera de Git; no regenerarlos ni subirlos como efecto de una prueba.
Los resultados observados están en el registro de tareas, no en una cifra fija aquí.

## Pendientes para una entrega operativa

Completar la integración selectiva del trabajo original (T1), identificar una copia
de Studio y probar gameplay/replicación/multicliente (T3/T9), verificar la migración y
restauración del vault, y aprobar/probar los assets reales. Las compras seguirán
deshabilitadas hasta tener productos del propietario, precios reales, recibos y
concesiones persistentes probadas. No se garantiza una tasa DevEx ni seguridad por
el mero uso de un avatar, módulo, prompt o resultado histórico.

## Referencias del repositorio

- [Contratos actuales para agentes](AGENTS.md) y [guía CLI](CLAUDE.md).
- [Adaptadores](adapters/README.md) y [prompt de entrada](agent/system_prompt.md).
- [Catálogo RAASE](agent/raase_skills.json) y [skill Roblox](skills-roblox/roblox-engineer/SKILL.md).
- Los blueprints RAASE 2.0/2.1/Next-Gen y `PROJECT_TRACKER.md` conservan historia,
  no una aprobación vigente. Los cambios locales no autorizan publicación.
