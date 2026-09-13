# HARNESS-PORTABILITY.md — Contrato de Portabilidad de Modelo (RAASE 2.1)

> Este documento define cómo RAASE sobrevive el cambio de modelo/harness (Gemini/Antigravity, GPT/Codex, Claude/Claude Code, OpenCode, cualquier agente con shell). Si una herramienta futura no cumple el contrato, RAASE la degrada explícitamente — nunca finge que funciona.

## Principio Rector

**La inteligencia vive en código y artefactos portables, no en el modelo.** El bridge, el plugin, el tokenizer, el nonce y el cortacircuitos *fuerzan* el comportamiento correcto; el modelo solo planifica y decide. Cualquier modelo que pueda ejecutar comandos y leer archivos puede operar RAASE; la calidad de sus planes escala con su capacidad de razonamiento, pero la seguridad y la integridad del sistema no dependen de su disciplina.

## Contrato de Capacidades

### Obligatorias (MUST) — sin esto no se opera RAASE
| Capacidad | Por qué |
|---|---|
| Ejecutar comandos de shell (Node, git) | Correr `bridge/server.mjs`, la CLI del orquestador, el instalador de skills |
| Leer y escribir archivos | Manifiestos, GLB, SKILL.md, código Luau |
| Interpretar un system prompt + skills markdown (agentskills.io) | El cerebro del sistema son los prompts, no el modelo |
| Acceso HTTP a `127.0.0.1` (directo o vía scripts Node) | Toda la comunicación con Studio pasa por el bridge local |

### Deseables (SHOULD) — degradan elegante si faltan
| Capacidad | Con ella | Sin ella |
|---|---|---|
| Visión (screenshots) | Auditoría visual automática (RN-11, 2 pases) | Los PNG de captura se envían al humano: "¿ves defectos?", y el humano dictamina |
| Contexto largo | Carga varios dominios de skills a la vez | Progressive disclosure: cargar 1-3 SKILL.md por tarea (tier0/tier1 de skillsGV) |
| Razonamiento de planificación alto | Construye sistemas completos en una corrida | Modo Lite: el humano define el plan; el modelo ejecuta micro-tareas con la CLI |
| Soporte MCP | BlenderMCP/Blender vivo (opcional) | Todo por CLI headless (la vía principal de todos modos) |
| Web/descarga de assets | Buscar referencias y packs | Assets solo por Blender IA-gen local |

### Muro duro (no negociable)
- Un **chat puro sin herramientas** (web chat sin shell/files) **no puede operar RAASE** — solo puede aconsejar/leer código pegado a mano. No es un destino válido para el flujo completo.

## Tiers de Modelo

| Tier | Ejemplos de gama | Autonomía |
|---|---|---|
| **A** | Gemini Pro/Antigravity, Claude Opus/Sonnet con tools, GPT top con Codex | Ciclo completo: explorar → planificar → construir → verificar visualmente → iterar |
| **B** | Modelos medianos con tools | Ciclo completo con más checkpoints: confirmar plan antes de lotes grandes; verificación visual humana |
| **C** | Modelos chicos/rápidos (flash-grade) con tools | Modo Lite: micro-tareas + validación del humano entre pasos; el CLI y el bridge hacen el trabajo pesado |
| — | Chat sin tools | No operable (advisory only) |

## Protocolo de Certificación (smoke test de harness)

Un harness nuevo se certifica corriendo estos 6 puntos (todos deben pasar):

1. `node bridge/server.mjs` arranca y muestra el token.
2. `node agent/orchestrator_cli.mjs status` → `Roblox Studio Connected: YES` (con Studio abierto + plugin cargado + token pegado).
3. Petición sin token a un endpoint protegido (`POST /api/command`) → `401` (la seguridad está activa; `GET /api/status` es público y devuelve 200).
4. `GET_SCENE_GRAPH` vía CLI → devuelve el árbol del Workspace.
5. `BATCH_SPAWN` de una parte de prueba con upsert → reporte SUCCESS con `createdCount`.
6. `node <skillsGV>/00-meta-skills/skill-validator/scripts/validate-skills.mjs <skills-roblox> --strict` → 0 errores.

## Estructura de Adapters

Cada archivo en `adapters/` debe especificar:
1. **Skills**: dónde las lee el tool (ruta project + global) y cómo se instalan (skill-sync de skillsGV).
2. **System prompt**: cómo se carga `agent/system_prompt.md` en ese tool.
3. **Ejecución**: herramienta de shell, permisos requeridos (red localhost, archivos).
4. **Capacidades y degradaciones**: visión, contexto, MCP → qué cambia.
5. **Smoke test**: los 6 comandos del protocolo.
6. **Quirks**: particularidades conocidas del tool con RAASE.

Adapters disponibles: `antigravity.md`, `claude-code.md`, `codex.md`, `opencode.md`, `generic.md`.

## Estado Actual (verificado)

| Herramienta | Skills instaladas | Estado |
|---|---|---|
| Antigravity | `.agents/skills` (workspace) + `~/.gemini/antigravity/skills` (global) — 197, junctions | ✅ happy path actual |
| Claude Code | `.claude/skills` (197) | ✅ instalado, smoke test pendiente |
| OpenCode | `.opencode/skills` (197) | ✅ instalado |
| Codex | `.agents/skills` (repo scan) — 197 | ✅ instalado, revisar red sandbox |
| Gemini CLI / DeepSeek / Cursor / Windsurf / Kiro / Copilot | rutas respectivas (197 c/u) | ✅ instalado (skillsGV `install.mjs`) |

> Nota: la instalación referenciada vive en la carpeta del proyecto (`IA INTEGRADA CON ROBLOX STUDIO`) y apunta por junction al clone de `skillsGV` — actualizar el clone actualiza todas las herramientas.
