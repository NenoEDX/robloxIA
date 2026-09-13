# Adapter — Google Antigravity (Gemini)

> Happy path actual de RAASE 2.1. Estado: ✅ verificado en uso real.

## 1. Skills
- **Workspace scope (el que lee Antigravity)**: `.agents/skills/` — 197 skills de skillsGV instaladas por junction (verificado en disco).
- **Global scope**: `~/.gemini/antigravity/skills/` (convención global de Antigravity; el instalador además escribe `<proyecto>/.gemini/antigravity/skills` como alias por-tool).
- **Instalación/actualización**: `node <skillsGV>/install.mjs --target "<ruta del proyecto>" --symlink` (re-ejecutar solo cuando se agregan skills NUEVAS; editar existentes fluye en vivo por junction).
- Las skills de Roblox del catálogo RAASE viven en `skills-roblox/` del repo y se leen directo como archivos del workspace.

## 2. System prompt
- Cargar `agent/system_prompt.md` como contexto del workspace (reglas de ingeniería RAASE + referencia al catálogo).
- `CLAUDE.md` del repo contiene las reglas duras; en Antigravity, referenciarlo o pegarlo como contexto inicial de sesión.

## 3. Ejecución
- Shell completo (Node, git, Python, Blender si está instalado).
- Red: acceso a `127.0.0.1:34873` sin configuración extra.
- Quirks conocidos:
  - Antigravity escribe archivos de trabajo en `C:\Users\<user>\.gemini\antigravity\brain\<session>\scratch\` — útil para harnesses de prueba, pero **esos archivos no van al repo** (moverlos si son valiosos).
  - El agente tiende a prefijar el trabajo con lecturas amplias; para RAASE conviene recordarle la regla de micro-mutaciones (RN-10) en el prompt de sesión.

## 4. Capacidades y degradaciones
| Capacidad | Estado | Degradación |
|---|---|---|
| Shell + files | ✅ | — |
| Visión | ✅ | — |
| Contexto | ✅ largo | — |
| Blender | Requerido para mallas | Si no está: **RECOMENDAR instalarlo** (blender.org, gratis); mientras tanto genera `.py` + manifiesto para otra PC (roblox-36) |

## 5. Smoke test
```powershell
cd <repo-robloxIA>
node bridge/server.mjs          # copiar el token impreso
# (Studio: plugin cargado + token pegado una vez)
node agent/orchestrator_cli.mjs status   # → Connected: YES
```
Si algo falla: revisar 401 (token desincronizado → re-pegar en el panel del plugin).

## 6. Referencias cruzadas
- Flujo de skills para skillsGV en este harness: el instalador detecta `antigravity` y escribe en `.gemini/antigravity/skills`.
