# Adapter — OpenAI Codex CLI

> Estado: ✅ skills instaladas (`.codex/skills`); revisar permisos de red del sandbox.

## 1. Skills
- **Repo scan (el que lee Codex)**: `.agents/skills/` — Codex escanea esta carpeta desde el cwd hacia arriba hasta la raíz del repo (vendor docs); el instalador ya la puebla (197 skills por junction).
- **Alias del instalador**: `.codex/skills/` (mismo contenido; usarlo si tu versión de Codex lo prefiere).
- **Instalación**: `node <skillsGV>/install.mjs --target "<ruta del proyecto>" --symlink --tool codex`.
- Codex también lee `AGENTS.md` jerárquicos; el repo ya tiene uno en `skills-roblox/AGENTS.md` y puede sumarse uno raíz que apunte a `agent/system_prompt.md`.

## 2. System prompt
- Convención Codex: `AGENTS.md` en la raíz del proyecto. Recomendado: crear/confirmar un `AGENTS.md` raíz que resuma reglas RAASE + linkee `agent/system_prompt.md`.

## 3. Ejecución
- **Ojo con el sandbox**: por defecto Codex puede bloquear red — RAASE necesita acceso a `127.0.0.1:34873`. Opciones: aprobar los comandos `node bridge/...` y `node agent/...`, o configurar network access al loopback.
- Sin sandbox (sesión de confianza): flujo completo directo.

## 4. Capacidades y degradaciones
| Capacidad | Estado | Degradación |
|---|---|---|
| Visión | ⚠️ depende del modelo elegido | Sin visión: los PNG de captura van al humano para dictamen (RN-11 se vuelve asistido) |
| Contexto | ✅ (modelos GPT largos) | — |
| Red localhost | ⚠️ requiere permiso/config | Aprobar comandos o allowlist de loopback |

## 5. Smoke test
```powershell
node bridge/server.mjs
node agent/orchestrator_cli.mjs status     # ← debe alcanzar el bridge (probar que el sandbox no lo bloquea)
```

## 6. Quirks
- Si el sandbox bloquea el POST al bridge con un error de red genérico, no es RAASE: es permisos. Documentar el comando exacto aprobado.
- Para sesiones largas de construcción: preferir `--full-auto` con red de loopback habilitada.
