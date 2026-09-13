# Contexto del Proyecto — robloxIA (RAASE 2.1)

> Contexto OpenSpec para las fases SDD de este repositorio.
> Inicializado: 2026-09-13 (sdd-init). Fuentes de detección: CLAUDE.md, PROJECT_TRACKER.md, bridge/, skills-roblox/.

## Resumen

robloxIA implementa el sistema **RAASE 2.1**: un puente local IA ↔ Roblox Studio. Un servidor HTTP en Node.js (sin dependencias externas) expone una cola de comandos por long-polling en `127.0.0.1:34873`; un Companion Plugin en Luau la consume dentro de Studio y ejecuta micro-mutaciones de escena con undo safety; un worker host-side (`screen_capture.py`) captura el viewport para auditoría visual. Cualquier agente de IA (Claude Code, Codex, OpenCode, Antigravity) opera a través del bridge y del catálogo de 39 skills de ingeniería Roblox.

## Estructura del repositorio

| Path | Contenido |
|---|---|
| `bridge/` | Servidor HTTP local (`server.mjs`), cliente Open Cloud (`open_cloud.mjs`), captura no invasiva (`screen_capture.py`), tests `.mjs` |
| `plugin/` | `CompanionPlugin.server.luau` + `default.project.json` (Rojo) |
| `agent/` | `orchestrator_cli.mjs`, `raase_skills.json` (610 micro-habilidades, 35 dominios), `system_prompt.md`, `lib/bridge-client.mjs` |
| `skills-roblox/` | 39 skills en formato agentskills.io (español): `SKILLS.md`, `AGENTS.md`, `.atl/skill-registry.md`, `roblox-01..38` + `roblox-engineer` |
| `project_template/` | Plantilla Luau con Rojo (`default.project.json`, `selene.toml`, `stylua.toml`, `wally.toml`) |
| `docs/` | Especificaciones RAASE 2.0/2.1 y `HARNESS-PORTABILITY.md` |
| `adapters/` | Guías de integración por harness (Claude Code, Codex, Antigravity, OpenCode, genérico) |

## Toolchain detectado (2026-09-13)

| Herramienta | Estado | Uso |
|---|---|---|
| Node.js v24.11.1 | disponible | bridge, CLI del agente, tests `.mjs` |
| Python 3.14.0 / `py -3` | disponible | `screen_capture.py`, plantillas Blender |
| Blender | pendiente de instalación | pipeline de assets (roblox-36) |
| `luau`, `luau-lsp`, `rojo`, `selene`, `stylua`, `lune`, `wally` | no disponibles en PATH | tooling Luau del `project_template` (lint, format, build, tests Luau) |

`bridge/package.json` no declara `dependencies`: el bridge es zero-deps y solo define los scripts `start` y `capture`. No existe script `test`.

## Convenciones de ingeniería

### Luau (obligatorio)
- Todo archivo `.luau` inicia con `--!strict`; tipos explícitos (`export type`), sin `any` descontrolado.
- Servicios solo vía `game:GetService("...")`; comparaciones de nulidad explícitas (`== nil`).
- Prohibidas `spawn()`, `delay()`, `wait()`; usar siempre la biblioteca `task`.
- Formato StyLua (tabulaciones, 100 columnas); lint Selene.
- Cinemática procedural: solo `Motor6D.Transform` en hilos de render; nunca mutar `C0`/`C1` en runtime.
- Ciclo de vida: patrón `Janitor`; desconectar todo `RBXScriptConnection` y usar `:Destroy()` explícito.
- DevEx: `ProcessReceipt` idempotente (persistir `PurchaseId` en DataStore antes de otorgar; `NotProcessedYet` ante fallo); avatares R15.

### Seguridad (Zero-Trust)
- El cliente es hostil; daño, inventario, precios y validación espacial son autoridad del servidor.
- Bridge: Bearer token comparado con `crypto.timingSafeEqual`; CORS restringido a localhost; token en `bridge/.bridge_token` (gitignored) o variable `ROBLOXIA_BRIDGE_TOKEN`; `ROBLOXIA_NO_WRITE_TOKEN_FILE=1` evita escritura del token en tests.
- Cada comando despachado recibe un `reportNonce` exclusivo del poller; reportes sin nonce válido → HTTP 403; reportes huérfanos → HTTP 400.
- Cortacircuitos de captura: 2 capturas consecutivas sin mutación real de escena → HTTP 429 (`CIRCUIT_BREAKER_TRIGGERED`); una mutación real (`createdCount > 0`) lo resetea.
- Undo safety: toda mutación de escena se registra con `ChangeHistoryService:TryBeginRecording()` / `FinishRecording()`.
- RN-10 (Soberanía del Creador): prohibido recrear o restaurar objetos editados o borrados por el humano; solo micro-mutaciones selectivas (`MODIFY_OBJECT`, `DELETE_OBJECT`, `BATCH_SPAWN`); consultar `GET_SCENE_GRAPH` / `INSPECT_OBJECT` antes de tocar una zona.
- RN-11 (Convergencia visual): máximo 2 pases de captura por iteración con parada obligatoria.

### Catálogo de skills
- Formato agentskills.io (frontmatter `name`/`description`), contenido en español.
- Índices que deben mantenerse sincronizados: `skills-roblox/SKILLS.md` (39 entradas), `skills-roblox/AGENTS.md`, `skills-roblox/.atl/skill-registry.md` y `agent/raase_skills.json`.
- Validación externa obligatoria tras cambios del catálogo (ver comandos abajo).

## Verificación (capacidades detectadas)

**strict_tdd: false.** No hay framework de tests (sin vitest/jest/mocha; tampoco `lune`/`testez` disponibles en PATH) ni un runner workspace-level que cubra todos los componentes. La verificación de facto es:

| Comando | Verifica | Requisitos | Hermético |
|---|---|---|---|
| `node bridge/test_bridge_v2_1.mjs` | API del bridge: status público, 401 sin auth, batch enqueue autenticado, long-poll con `reportNonce` exclusivo, rechazo de reportes huérfanos | Solo Node (levanta `server.mjs` en el puerto 34879 con token de prueba) | Sí |
| `node bridge/test_circuit_breaker.mjs` | Cortacircuitos con deltas reales: 2 capturas → 429; no-op no resetea; mutación real resetea | Python + ventana de Roblox Studio visible (ejecuta capturas reales vía `POST /api/capture`); puerto 34881 | No |
| `node --check <archivo.mjs>` (alias `node -c`) | Sintaxis de módulos Node | Node | Sí |
| `python -m py_compile bridge/screen_capture.py` | Sintaxis Python (escribe `__pycache__`, gitignored) | Python | Sí |
| `node "C:\Users\j1347\Desktop\skills\00-meta-skills\skill-validator\scripts\validate-skills.mjs" "skills-roblox" --strict` (desde la raíz del repo) | Frontmatter y estructura del catálogo completo (39 skills) | Node | Sí |

Estado del validador de skills en el init: 39/39 pass, 0 errores, exit 0 en modo strict.

## Restricciones para planificación

- `test_circuit_breaker.mjs` solo debe ejecutarse con Roblox Studio abierto; el resto de la verificación no requiere Studio.
- No ejecutar el bridge real (puerto 34873) durante tareas de planificación o verificación automática; los tests usan puertos alternos (34879/34881).
- No commitear `bridge/.bridge_token` ni capturas (`viewport_latest.png`, `bridge/temp/`); ya están en `.gitignore`.
- Al momento del init el árbol tiene cambios sin commitear (README.md, `agent/system_prompt.md`, archivos de `skills-roblox/` modificados y `roblox-38-env-vfx-craft/` sin trackear): no asumir árbol limpio.
- El bridge es zero-deps: agregar dependencias npm a `bridge/` requiere justificación explícita y aprobación del creador.
- Las extensiones `roblox-36`, `roblox-37` y `roblox-38` no están registradas en `raase_skills.json` (decisión documentada del catálogo); cualquier cambio debe preservar esa distinción o actualizarla de forma coherente.
