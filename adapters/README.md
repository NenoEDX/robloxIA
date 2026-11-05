# adapters/ — Perfiles de Harness para RAASE 2.1

Cada archivo define cómo correr RAASE desde una herramienta/modelo concreto: dónde van las skills, cómo se carga el system prompt, qué permisos necesita y qué se degrada si le falta una capacidad.

Leer primero: [AGENTS.md](../AGENTS.md) y [Studio MCP](../docs/STUDIO_MCP_SETUP.md). [HARNESS-PORTABILITY.md](../docs/HARNESS-PORTABILITY.md) conserva el diseño histórico del bridge, no la política operativa actual.

| Adapter | Herramienta | Estado |
|---|---|---|
| [antigravity.md](antigravity.md) | Google Antigravity (Gemini) | ✅ verificado en uso real |
| [claude-code.md](claude-code.md) | Claude Code (Anthropic) | ✅ skills instaladas (smoke test pendiente) |
| [codex.md](codex.md) | OpenAI Codex CLI | ✅ skills instaladas (smoke test pendiente) |
| [opencode.md](opencode.md) | OpenCode (multi-modelo) | ✅ skills instaladas (smoke test pendiente) |
| [generic.md](generic.md) | Cualquier agente con shell | Plantilla base |

## Regla común

Los adapters comparten los contratos del proyecto, no la obligación de usar el mismo transporte. MCP integrado es la ruta preferida; bridge/plugin es legado transitorio. Las capacidades, permisos y destinos se comprueban en cada runtime. Los estados de la tabla son históricos y no certifican una conexión actual.
