# Exploración: Mejoras del catálogo RAASE 2.1 (raase-catalog-improvements)

> Fase: sdd-explore · Fecha: 2026-09-13 · Store: openspec
> Alcance: identificar qué se puede mejorar en el catálogo `skills-roblox/` (39 skills) respecto de las 73 fuentes de investigación originales (deduplicadas) y las capacidades actuales del motor.
> Método: lectura de índices + muestreo de 12 SKILL.md (01, 02, 03, 04, 07, 08, 09, 10, 13, 25, 35, engineer) + greps de cobertura de keywords sobre los 39 skills. Árbol de trabajo como fuente de verdad.

## Contexto

- El catálogo nació de 73 fuentes de investigación (blueprints internos, noticias/docs oficiales, devforum, YouTube, reddit, wikis) y hoy consta de 39 skills agentskills.io en español: 35 dominios técnicos (610 micro-habilidades, skills 001-610), 3 extensiones RAASE 2.1 (roblox-36 asset-pipeline, roblox-37 vfx-combat-pipeline, roblox-38 env-vfx-craft) y la skill maestra roblox-engineer.
- Índices que deben permanecer sincronizados: `skills-roblox/SKILLS.md` (39 entradas), `skills-roblox/AGENTS.md`, `skills-roblox/.atl/skill-registry.md` (39 indexadas) y `agent/raase_skills.json` (35 dominios / 610 skills). Las extensiones 36-38 **no** están registradas en `raase_skills.json` (decisión documentada; ver `openspec/project.md`).
- La pregunta del usuario: "investiga para ver qué podemos mejorar" respecto de esas fuentes y del motor actual.

## Estado actual

- **Dos generaciones editoriales**: dominios 01-13 compactos (34-105 líneas, reglas sin ejemplos en su mayoría); dominios 14-35 expandidos (100-290 líneas con snippets Luau); extensiones 36-38 y engineer (~85-105 líneas, formato "receta + handoff").
- **Sin trazabilidad de fuentes en los skills**: ningún SKILL.md cita la fuente original ni fecha de verificación; no existe un índice de fuentes en el repo (las dos fuentes internas citadas no están en `docs/`).
- **Verificación externa existente**: `validate-skills.mjs` (39/39 pass, strict) valida frontmatter/estructura, no exactitud técnica.
- **Cobertura general alta** en: seguridad de remotos (02), DataStores (03), CSG (04), audio (07 + 35), memoria/Janitor (08), DevEx (09 + 18), performance (25), animación Motor6D (05/29/21), DOF/iluminación (04/13/22). Los greps confirman que las fuentes principales tienen regla asignada.

## Mapa de cobertura (fuente → catálogo)

| # | Cluster de fuentes | Estado | Dónde | Qué falta / nota |
|---|---|---|---|---|
| 1 | Blueprints internos (Architectural Specification; Guía de Fuentes) | COVERED | Catálogo 01-35 en conjunto | Base estructural del catálogo; no están en el repo |
| 2 | Audio — efectos (newsroom 2016, docs/audio/effects) | COVERED (legacy) | 07:169-172 (`EqualizerSoundEffect`, `ReverbSoundEffect`, `CompressorSoundEffect`, `DistortionSoundEffect`) | Solo API legacy de efectos; Flange/Tremolo/Chorus legacy no se mencionan |
| 3 | Audio — API moderna de efectos | PARTIAL | 35 (AudioChorus, AudioFilter, AudioPitchShifter, AudioFader, AudioReverb:125) | Faltan nodos AudioDistortion, AudioEcho, AudioCompressor, AudioEqualizer, AudioLimiter, AudioGate, AudioTremolo, AudioFlanger; sin tabla legacy ↔ Audio* |
| 4 | Audio — dynamic-effects (docs) | PARTIAL | 35 (Wire graph, crossfade, stems, AudioAnalyzer, oclusión) | Sin recetas de zonas acústicas por volumen/región; sin ejemplo de AudioEmitter por zona |
| 5 | Audio — Distortion fandom wiki | COVERED | 07:172 | — |
| 6 | Audio — "SOUND REGIONS sin scripting" (YouTube) | PARTIAL | 07:168 (regiones por posición del jugador) | Sin técnica "sin código" (regiones físicas) ni receta implementable; sin ejemplo |
| 7 | Audio — reverb por zonas (pages.dev) | PARTIAL | 07:170 (regla); 35:125-129 (AudioReverb catedral) | Sin receta completa de zonas múltiples (cueva/sala/catedral) con transición suave |
| 8 | Secure remotes — devforum "protect RemoteEvents" | COVERED | 02:026-060 (40 reglas) | Profundidad conceptual alta |
| 9 | Secure remotes — UnreliableRemoteEvents / Reliable vs Unreliable | PARTIAL | 02:033-034 | Sin tabla de decisión ni ejemplo de uso; grep sin ejemplos `FireServer`/`OnServerEvent` en todo el catálogo (1 sola mención, en la descripción de 02) |
| 10 | Secure remotes — baseplatedev checklist | PARTIAL | 02 (validación de tipos 027, rate limit 032, autoridad 026, segregación 048-049) | `RemoteFunction` ausente (solo nombrada en la descripción); sin checklist de auditoría verificable |
| 11 | Secure remotes — módulo rate limiter (devforum) | PARTIAL | 02:032 (Token Bucket, regla) | Sin implementación de referencia (bucket por jugador) |
| 12 | Secure remotes — reddit FireServer basics | PARTIAL | 02:048-049 (aislamiento ReplicatedStorage/ServerScriptService) | Sin scaffolding canónico cliente→servidor (intención → validación → respuesta) |
| 13 | DevEx — calculator / rates 2026 / guide / docs | COVERED con RIESGO DE OBSOLESCENCIA | 09 (tasas $0.0038 estándar, $0.0054 U.S. 18+, $0.0035 legada; umbral 30k R$; R15) + 18 | Tasas, umbral y requisito R15 **deben re-verificarse** contra docs oficiales antes de publicar (sensibilidad monetaria/legal) |
| 14 | Luau — codecademy / docs / luau-lang.org | COVERED | 01 (001-025), 19 (CI), 33 | — |
| 15 | Luau — security overview (sandbox github) | PARTIAL | 01 (implícito; 19 usa `_G` en mocks) | Sin regla explícita sobre `loadstring`/`getfenv`/sandbox y superficie de ataque del cliente |
| 16 | CSG — Intersection / solid modeling / docs parts | COVERED | 04:091-095 (Union/Subtract/Intersect/Sweep/Fragment) | — |
| 17 | CSG — "un-merges meshes / vertex count" (devforum) | PARTIAL | 04:087 (presupuesto 4k-10k tris), 04:090 (watertight) | Sin `SeparateAsync` (deshacer unión/negate); cifra de triángulos a re-verificar contra `art/modeling/specifications` |
| 18 | Meshes/import — meshy.ai / nilo.io / specs | COVERED (pipeline) / PARTIAL (cifras) | 04:086 + 36 (Blender→GLB→handoff→verificación) | Faltan cifras de especificación de import (límites de triángulos/texturas por categoría) |
| 19 | Performance — improve (docs) | COVERED | 25 (446-460: Streaming, tiers de memoria, MicroProfiler, LOD, térmico) + 08 + 04:108-110 | Sólido y actualizado |
| 20 | Memoria/cleanup — Janitor (devforum) / Maid (sleitnick) | COVERED | 08:186-187 + reglas globales (CLAUDE.md, project_template) | — |
| 21 | Animación — Motor6D.Transform (doc) | COVERED | 05:017/024, 29:150/248, 21:189, engineer:111 | Regla inviolable consistente en 4+ lugares |
| 22 | Lighting — Depth of Field (YouTube) | COVERED | 04:105, 13:279, 22:136 | Consistente; sin receta de DOF con focus tracking completa (22:136 la esboza) |
| 23 | Estilo/convenciones — Roblox Lua style guide / Kampfkarren | PARTIAL | 01:007 (tab/100 cols/comillas), 19 y 33 (Selene/StyLua/luau-lsp en CI) | Sin convenciones de nombres (PascalCase/camelCase), orden de archivos ni las guidelines de Kampfkarren más allá del CI |

## Oportunidades (priorizadas)

### Alta prioridad

1. **09/18 — Re-verificación de tasas DevEx 2026 y calculadora** (esfuerzo: Bajo).
   Verificar contra docs oficiales: tasas $0.0038/$0.0054/$0.0035, umbral 30.000 R$, requisito R15/identidad. Añadir tabla de conversión R$→USD con ejemplos y nota de vigencia. Es el hallazgo con mayor riesgo (dinero/legal) si el dato cambió.

2. **07 — Capa moderna de efectos de audio + recetas de zona** (esfuerzo: Medio).
   Tabla de equivalencia legacy ↔ API 2026 (`DistortionSoundEffect`→`AudioDistortion`, `EqualizerSoundEffect`→`AudioEqualizer`/`AudioFilter`, `ReverbSoundEffect`→`AudioReverb`, `CompressorSoundEffect`→`AudioCompressor`, más `AudioEcho`, `AudioLimiter`, `AudioGate`, `AudioTremolo`, `AudioFlanger`); receta de zonas acústicas múltiples con transición suave; técnica "sound regions sin scripting"; cross-referencia explícita 07 ↔ 35 (hoy conviven sin enlace y 07 describe primitivas legacy mientras 35 usa el grafo Wire).

3. **02 — Anexo de ejemplos canónicos de remotos** (esfuerzo: Medio).
   El catálogo es rico en reglas (40) y pobre en plumbing: no hay `FireServer`/`OnServerEvent` en ningún snippet. Añadir scaffolding cliente→servidor (intención → validación `typeof` + distancia + rate limit → respuesta), tabla de decisión Reliable vs Unreliable, snippet Token Bucket y guía `RemoteFunction` (cuándo evitar, riesgos de yield/InvokeClient). Conectar con el checklist baseplatedev como "checklist de auditoría" de ítems verificables.

4. **04/36 — CSG un-merge + cifras de importación** (esfuerzo: Bajo-Medio).
   Añadir `SeparateAsync` (deshacer uniones/negates) al catálogo CSG y re-verificar el presupuesto 4k-10k triángulos contra las especificaciones de modelado vigentes; añadir al anexo de 36 las cifras de import (triángulos/texturas por categoría) para que la verificación post-import tenga umbrales numéricos.

### Media prioridad

5. **Trazabilidad de fuentes** (esfuerzo: Medio).
   Crear `skills-roblox/SOURCES.md` (o anexo "Fuentes" por dominio) que mapee las 73 fuentes a los dominios con fecha de última verificación. Hoy no hay forma de auditar de dónde salió cada regla ni cuándo se validó; habilita mantenimiento periódico (p. ej. re-verificación anual de tasas/specs).

6. **01 — Guía de estilo ampliada** (esfuerzo: Bajo).
   Convenciones de nombres, `module` layout, reglas de sandbox del cliente (`loadstring`/`getfenv`), y alineación explícita con la guía oficial y las Luau guidelines de Kampfkarren (hoy solo viven como versiones de CI).

7. **Índices — sincronización como paso verificable** (esfuerzo: Bajo).
   Cualquier cambio de catálogo debe actualizar SKILLS.md + AGENTS.md + `.atl/skill-registry.md` (+ `raase_skills.json` si aplica) y re-pasar `validate-skills.mjs --strict`. Convertirlo en tarea explícita de apply/verify.

### Baja prioridad

8. **Estructura de extensiones** (esfuerzo: Bajo): decidir formalmente si 36-38 se registran en `raase_skills.json` o se añade una sección `"extensions"` al JSON preservando la distinción actual (documentada).
9. **Matriz de cross-references** (esfuerzo: Bajo): completar enlaces entre dominios solapados (07↔35 audio, 04↔36 mesh/CSG, 13↔37↔38 VFX, 09↔17↔18 economía).
10. **Consistencia editorial 01-13 vs 14-38** (esfuerzo: Alto): backfill de snippets en dominios compactos; decisión de estilo "regla" vs "regla + receta".

## Riesgos

- **Verificación externa**: los puntos de mayor valor (tasas DevEx, specs de import, nodos audio 2026) requieren contrastar docs oficiales; si la investigación web no está disponible en fases siguientes, deben quedar como verificación manual del creador con estado explícito.
- **Ámbito**: tocar los 4 índices + 10 dominios potenciales supera el presupuesto de ~400 líneas de cambio; la propuesta debe recortar a v1 (probable: hallazgos Alta 1-3) con el resto como follow-ups.
- **No-regresión de estructura**: el validador externo (39/39) y la convención agentskills.io son gates; cualquier edición debe mantener frontmatter y descripciones.
- **Overlap 07/35**: si se editan ambos sin una frontera clara (07 = fundamentos/legacy, 35 = grafo moderno), se consolidará la duplicación existente en lugar de eliminarla.

## Preguntas abiertas para la propuesta

1. ¿Alcance de la v1: solo hallazgos Alta (DevEx, audio moderno, remotos, CSG) o se incluye trazabilidad de fuentes (SOURCES.md)?
2. ¿La verificación de tasas DevEx y specs de import se hace en fase de research con acceso web, o se marca como "pendiente de verificación del creador" con placeholders explícitos?
3. ¿Se actualiza `agent/raase_skills.json` para extensiones/sección nueva, o se preserva la distinción actual (36-38 fuera del JSON)?
4. ¿Se adopta "regla + receta + snippet" como estándar editorial para los dominios compactos, o se mantiene el formato actual por dominio?
5. ¿La propuesta debe incluir el ciclo de sincronización de índices + validador como tareas obligatorias de apply/verify?

## Fuentes

- 73 research sources (deduplicadas y agrupadas por cluster) provistas por el orquestador: blueprints internos (2), audio (6), remote security (7), DevEx (4), Luau (4), CSG/solid modeling (4), meshes/import (3), performance (1), memoria (2), animación (1), lighting (1), estilo (2).
- Artefactos del repo: `openspec/project.md`, `openspec/config.yaml`, `skills-roblox/SKILLS.md`, `skills-roblox/AGENTS.md`, `skills-roblox/.atl/skill-registry.md`, `agent/raase_skills.json`.
- Evidencia directa: lectura de SKILL.md de 01, 02, 03, 04, 07, 08, 09, 10, 13, 25, 35, engineer; greps de cobertura (`DistortionSoundEffect|…`, `AudioPlayer|…`, `Motor6D|…`, `FireServer|OnServerEvent`, `SeparateAsync|SetMetadata`, `DepthOfField`, `IntersectAsync|GeometryService|GLB`, `Kampfkarren|Selene|StyLua|loadstring`).

## Ready for Proposal

**Yes.** La cobertura está mapeada y las oportunidades priorizadas; la propuesta debería cerrar las preguntas abiertas (alcance v1, verificación externa, JSON de extensiones) y recortar a un slice ejecutable dentro del presupuesto de cambio.
