# Adapter — Generic (cualquier agente con shell)

> Plantilla base para CUALQUIER herramienta futura con acceso a shell y archivos (una CLI nueva, un agente propio, un modelo vía script). Estado: conceptual — completar los huecos al integrar.

## 1. Checklist de integración

1. **¿Tiene shell?** Sin shell ejecutable → no operable (advisory only).
2. **¿Tiene acceso a `127.0.0.1:34873`?** El bridge es local; sin loopback no hay RAASE.
3. **¿Dónde lee sus skills/prompts?** Registrar su ruta y correr el instalador de skillsGV:
   `node <skillsGV>/install.mjs --target "<proyecto>" --symlink --tool <id>` (si el tool no está en la lista de skill-sync, instalar manualmente en su carpeta de convención).
4. **System prompt**: cargar `agent/system_prompt.md` + `CLAUDE.md` del repo como contexto de sistema.
5. **Certificar** con los 6 puntos de `docs/HARNESS-PORTABILITY.md`.

## 2. Ciclo operativo mínimo (sin importar el modelo)

```
1. LEER: agent/system_prompt.md + skills-roblox/roblox-engineer/SKILL.md (+1-3 dominios relevantes)
2. ESTADO: node agent/orchestrator_cli.mjs status
3. INTROSPECCIÓN: GET_SCENE_GRAPH / INSPECT_OBJECT (RN-10: respetar lo del creador)
4. PLAN: declarar qué skills se aplican + las mutaciones propuestas
5. MUTAR: comandos del bridge (BATCH_SPAWN upsert / MODIFY / DELETE / EXECUTE_LUAU validado)
6. CAPTURAR: POST /api/capture (máx 2 pases, RN-11)
7. VERIFICAR: con visión si hay; si no, enviar PNG al humano
8. CERRAR: reporte al creador + próximos pasos
```

## 3. Degradaciones por capacidad

| Falta | Qué hacer |
|---|---|
| Visión | PNG → humano; continuar flujo (RN-11 asistido) |
| Contexto corto | Cargar 1 skill por tarea (progressive disclosure) |
| Razonamiento bajo | Modo Lite: humano planifica, agente ejecuta; la CLI hace el trabajo pesado |
| MCP | Todo por CLI (default de todos modos) |
| Blender | `roblox-36-asset-pipeline`: **recomendar instalarlo** (blender.org) para mallas; degrada a `.py` + manifiesto para otra PC |

## 4. Reglas no negociables del contrato

- El token es por bridge; nunca se hardcodea en prompts ni en el repo.
- El agente NO importa mallas (no hay API): el paso humano de import es obligatorio.
- Seguridad de red: cualquier harness que exponga el bridge más allá de loopback queda fuera de certificación.
