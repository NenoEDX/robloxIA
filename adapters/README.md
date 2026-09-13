# adapters/ — Perfiles de Harness para RAASE 2.1

Cada archivo define cómo correr RAASE desde una herramienta/modelo concreto: dónde van las skills, cómo se carga el system prompt, qué permisos necesita y qué se degrada si le falta una capacidad.

Leer primero: [`../docs/HARNESS-PORTABILITY.md`](../docs/HARNESS-PORTABILITY.md) — el contrato completo de portabilidad.

| Adapter | Herramienta | Estado |
|---|---|---|
| [antigravity.md](antigravity.md) | Google Antigravity (Gemini) | ✅ verificado en uso real |
| [claude-code.md](claude-code.md) | Claude Code (Anthropic) | ✅ skills instaladas (smoke test pendiente) |
| [codex.md](codex.md) | OpenAI Codex CLI | ✅ skills instaladas (smoke test pendiente) |
| [opencode.md](opencode.md) | OpenCode (multi-modelo) | ✅ skills instaladas (smoke test pendiente) |
| [generic.md](generic.md) | Cualquier agente con shell | Plantilla base |

## Regla común

Todos los adapters apuntan al **mismo repo, mismo bridge, mismo plugin**. La diferencia es solo: dónde lee el tool sus skills y su prompt, y qué permisos exige. El ciclo operativo (introspectar → planificar → mutar → capturar → verificar) no cambia.
