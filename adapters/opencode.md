# Adapter — OpenCode (multi-modelo)

> Estado: ✅ skills instaladas (`.opencode/skills`). Es el harness donde se auditó y consolidó RAASE 2.1.

## 1. Skills
- **Project scope**: `.opencode/skills/` (197 skills de skillsGV instaladas — junction).
- **Instalación**: `node <skillsGV>/install.mjs --target "<ruta del proyecto>" --symlink --tool opencode`.
- OpenCode además lee `AGENTS.md` del proyecto — el repo aporta los suyos (`CLAUDE.md` raíz + `skills-roblox/AGENTS.md`).

## 2. System prompt
- `AGENTS.md` / `CLAUDE.md` de la raíz se cargan automáticamente en la sesión del proyecto.
- La referencia al catálogo (`skills-roblox/`) se hace por lectura directa de los `SKILL.md` (progressive disclosure).

## 3. Ejecución
- Bash completo, subagentes (task tool), MCP opcional (codegraph, engram, etc.).
- Red localhost sin restricciones.

## 4. Capacidades y degradaciones
| Capacidad | Estado | Degradación |
|---|---|---|
| Visión | ⚠️ depende del modelo activo (Gemini/Claude/GPT la tienen; algunos flash no) | Sin visión: capturas al humano |
| Contexto | ✅ depende del modelo | Modelos chicos: modo Lite (ver HARNESS-PORTABILITY) |
| Subagentes | ✅ | — |

## 5. Smoke test
```powershell
node bridge/server.mjs
node agent/orchestrator_cli.mjs status
node <skillsGV>/00-meta-skills/skill-validator/scripts/validate-skills.mjs <repo>/skills-roblox --strict   # 0 errores
```

## 6. Quirks
- El modelo se cambia por configuración (opencode.json) — RAASE funciona igual; en modelos flash usar Modo Lite (micro-tareas + CLI para lo pesado).
- Ideal para el ciclo de auditoría: subagentes explore + verificación read-only (como se usó en las rondas de esta consolidación).
