# Adapter — Claude Code (Anthropic)

> Estado: ✅ skills instaladas (`.claude/skills`); smoke test pendiente de correr.

## 1. Skills
- **Project scope**: `.claude/skills/` (197 skills de skillsGV instaladas — junction en Windows).
- **Instalación**: `node <skillsGV>/install.mjs --target "<ruta del proyecto>" --symlink --tool claude-code`.
- Claude Code descubre skills del proyecto automáticamente; también acepta skills globales en `~/.claude/skills`.

## 2. System prompt
- El repo ya tiene `CLAUDE.md` en la raíz (reglas de ingeniería RAASE) — Claude Code lo carga automáticamente al abrir el proyecto.
- Complementar con `agent/system_prompt.md` como referencia adicional (catálogo de skills + workflow).

## 3. Ejecución
- Bash tool completo. Aprobaciones de comandos: para el flujo RAASE conviene permitir `node`, `git`, `python`, `blender` (o usar bypass-permissions en sesiones de confianza).
- Red localhost sin restricciones.

## 4. Capacidades y degradaciones
| Capacidad | Estado | Degradación |
|---|---|---|
| Visión | ✅ (modelos Claude con visión) | — |
| Contexto | ✅ largo | — |
| Subagentes | ✅ (Task tool) | Puede delegar exploración/mapping como en esta sesión |

## 5. Smoke test
Los 6 puntos de `docs/HARNESS-PORTABILITY.md`:
```powershell
node bridge/server.mjs
node agent/orchestrator_cli.mjs status
node <skillsGV>/00-meta-skills/skill-validator/scripts/validate-skills.mjs <repo>/skills-roblox --strict
```

## 6. Quirks
- Claude Code respeta `CLAUDE.md` anidados por carpeta — mantener UNA fuente de reglas (`CLAUDE.md` raíz) para evitar desincronización.
- Los `.claude/skills` del proyecto son junctions: no editar ahí — editar el clone de skillsGV (o el skill real) y el cambio fluye.
