# Propuesta: Mejoras del catálogo RAASE 2.1 (raase-catalog-improvements)

> Change: `raase-catalog-improvements` · Fecha: 2026-09-13 · Store: openspec · Evidencia vinculante: `research.md` → Addendum A (documentación oficial de Roblox, verificada 2026-09-13)

## Intent / Why

El usuario pidió investigar qué mejorar en el catálogo `skills-roblox/` (39 skills; 610 micro-habilidades en 35 dominios) respecto de las 73 fuentes originales. La exploración y la investigación identificaron 4 hallazgos de alto riesgo que esta v1 corrige:

1. **DevEx (dinero/legal)**: tasas, umbral y elegibilidad sin fuente, fecha ni atribución correcta.
2. **Audio**: 07 enseña primitivas legacy y 35 el grafo moderno, sin tabla de equivalencia ni frontera editorial; faltan nodos modernos.
3. **Remotos**: 40 reglas de seguridad y cero plumbing: `FireServer`/`OnServerEvent` no aparecen en ningún snippet del catálogo.
4. **CSG/specs**: falta el un-merge; presupuestos internos en tensión (4k-10k vs ≤20k); Sweep/Fragment figuran como release pleno sin serlo.

## Approach

Edición editorial quirúrgica, sin reescrituras: correcciones dentro de reglas existentes y anexos no numerados (no se crean micro-habilidades nuevas → rangos y conteos intactos); cada afirmación nueva traza al Addendum A; registro y estilo propios de cada dominio; cierre obligatorio con sincronía de índices y validador strict.

## What Changes (alcance IN)

### (a) DevEx — roblox-09 (roblox-18 auditado)

| Punto base | Edición |
|---|---|
| `09:16-19` | Nota de vigencia (verificado 2026-09-13, docs oficiales); fecha de corte legada precisa (saldos anteriores al 5-sep-2025 10 am PT); ejemplos de conversión R$→USD. |
| `09:18` | Corregir atribución: la verificación de identidad/edad corresponde al **jugador** (comprador U.S. 18+), no al creador. |
| `09:44-45` (218) | Criterios verificados de elegibilidad: 100 % del playtime como R15 platform; sin R6 en ningún momento; human-form custom (12 limb parts o 12 joints; torso ≥2; bípedo completo) **o** nonhuman-form custom (también califica); animation packs R15; NPCs no se evalúan. |
| `09:47-48` (219) | Eliminar el mecanismo no verificado `StarterPlayer.GameSettings`; reformular: la regla R15 aplica al sistema de avatares platform para la tasa 18+, y no es requisito del DevEx estándar. |
| `09:50-51` (220) | Conservar umbral 30 000 R$ (confirmado); añadir requisitos base (13+, email verificado, portal DevEx, W-9/W-8). |
| `18:310-313` | Auditoría de línea base: el anexo Creator Store no contiene tasas DevEx → sin edición factual en v1 (verificación V9 → follow-up). |

### (b) Audio — roblox-07 / roblox-35

| Punto base | Edición |
|---|---|
| `07` (anexo, tras `07:80-83`) | Tabla de equivalencias legacy ↔ moderna (8 filas: Distortion→`AudioDistortion`, Equalizer→`AudioEqualizer`, Reverb→`AudioReverb`, Compressor→`AudioCompressor`, Chorus→`AudioChorus`, Flange→`AudioFlanger`, Tremolo→`AudioTremolo`, Echo→`AudioEcho`); nota de que el orden de los efectos altera el resultado; cross-ref a 35. |
| `35` (anexo Wire y enumeraciones de nodos, p. ej. `35:233-236`) | Añadir los nodos modernos verificados faltantes: `AudioDistortion`, `AudioEcho`, `AudioCompressor`, `AudioEqualizer`, `AudioTremolo`, `AudioFlanger`; cross-ref a 07. Excluir `AudioLimiter` y `AudioGate` (no confirmados en la doc oficial). |
| Frontera 07/35 | **07 = fundamentos + tabla de migración legacy→moderna; 35 = grafo Wire avanzado.** Sin recetas de zona multi-reverb ni técnica "sin scripting" (V13/V14 sin verificar). |

### (c) Remotos — roblox-02

| Punto base | Edición |
|---|---|
| `02` (nuevo anexo, tras `02:129-133`) | "Plumbing canónico": `FireServer`/`OnServerEvent(player, …)` → validación → respuesta; `FireClient`/`OnClientEvent`/`FireAllClients`; tabla de decisión Reliable vs Unreliable (one-way; sacrifica orden y confiabilidad por performance; datos continuos o no críticos); riesgos oficiales de `InvokeClient` (el error del cliente se propaga al servidor; disconnect → error; si el cliente no retorna, el servidor yieldea para siempre; preferir `RemoteEvent` para server→client de una vía); limitaciones de argumentos (índices no-string → string; funciones → `nil`; no mezclar claves numéricas y string; evitar `nil`; las tablas se copian — identidad perdida; metatables perdidas; instancias no replicables → `nil`). |
| Cifras | El anexo no publica límites de rate (no verificados en Addendum A); las cifras internas existentes (`02:41`, `02:98`) quedan sin tocar en v1 (V20/V21). |

### (d) CSG/specs — roblox-04 / roblox-36

| Punto base | Edición |
|---|---|
| `04:26-27` (087) | Sustituir "4.000-10.000 según categoría" por el límite oficial: 20 000 triángulos por mesh; las operaciones CSG simplifican a 20k si se excede (o fallan). |
| `04:38-51` (091-095) | `UnionAsync` con `CollisionFidelity`, `RenderFidelity`, `SplitApart` (default true) y `CalculateConstraintsToPreserve`; nombrar `FragmentAsync` (095); corregir Sweep/Fragment: están tras la Beta Feature "Solid Modeling On Meshes"; un-merge sin API in-game: Separate = herramienta de Studio (Shift+Ctrl+U), negado in-game = tag `rbxNegate` vía `CollectionService`, sustituto = `SubstituteGeometry()`/`MeshPart:ApplyMesh()`. |
| `04:35-36` (090) | Guía watertight y reparación: Blender (3D Print Toolbox, Mesh Repair Tools), Meshlab; `Solidify` para shells. |
| `36:96` (regla 2) | Alinear presupuesto con el tope oficial de 20k por mesh (resolver la tensión con 04). |
| `36` (handoff/verificación, `36:76-91`) | Specs verificadas: transform congelado (scale 1,1,1 / rot 0,0,0), root en 0,0,0, máx. 4 influencias por vértice, sin influencias al root; animación: single track por export; cages `_InnerCage`/`_OuterCage`; geometría watertight, sin N-gons, sin grosor 0. |

Restricción transversal: sin micro-habilidades numeradas nuevas (rangos y conteos 610/35 intactos); las adiciones van en reglas existentes y anexos no numerados; ediciones de estilo consistentes con cada dominio.

## Out of Scope

- `SOURCES.md` y trazabilidad de fuentes por dominio (follow-up).
- `agent/raase_skills.json` y extensiones 36-38: sin cambios de registro ni cascada de conteos.
- Backfill editorial de dominios compactos 01-13; cambios de Blender/scripts del pipeline de assets.
- Recetas de zonas acústicas multi-reverb y "sound regions sin scripting" (V13/V14).
- Límites numéricos de rate (V20/V21), formatos del importer y Scale Unit (V24/V27), alcance Creator Store de 18 (V9).
- `CLAUDE.md` raíz (duplicado de la regla R15) y cualquier cambio en bridge/plugin/project_template (sin runtime; RN-10/RN-11 no aplican).

## Capabilities (contrato con sdd-spec)

Nuevas (no hay specs previas en `openspec/specs/`):

- `devex-fact-sheet`: hechos DevEx verificados en roblox-09.
- `audio-legacy-modern-mapping`: equivalencias legacy↔moderna y frontera 07/35.
- `remotes-canonical-plumbing`: anexo canónico de remotos en 02.
- `csg-import-specs`: correcciones CSG y specs de importación 04/36.
- `catalog-index-sync`: sincronía de índices + validador strict + conteos intactos.

Modificadas: Ninguna.

## Impact (esfuerzo, pronóstico y verificación)

| Archivo | Líneas estimadas (add+del) |
|---|---|
| `roblox-09` (+ `roblox-18`: 0, auditoría) | 35-60 |
| `roblox-07` + `roblox-35` | 60-90 |
| `roblox-02` | 80-120 |
| `roblox-04` + `roblox-36` | 60-90 |
| Índices (`SKILLS.md`, `AGENTS.md`, `.atl/skill-registry.md`) | 0-20 (solo si cambian descripciones; si no, verificación no-op) |

Total: **~235-380 líneas cambiadas** (peak cercano a 400 si se maximizan los rangos). No excede el presupuesto de forma clara; si `sdd-tasks` confirma >400, split encadenado propuesto: **PR1 = DevEx (09) + CSG/specs (04/36); PR2 = audio (07/35) + remotos (02) + cierre de índices**.

Verificación (solo Markdown; store openspec):

- `node "C:\Users\j1347\Desktop\skills\00-meta-skills\skill-validator\scripts\validate-skills.mjs" "skills-roblox" --strict` desde la raíz → 39/39, exit 0 (gate obligatorio).
- No aplican `node --check`/`py_compile` (no se tocan `.mjs`/`.py`); no se ejecuta bridge ni Studio.
- Lectura de vuelta de cada archivo editado + `git diff --stat` para confirmar conteos.

Dependencias: ninguna externa en apply; el Addendum A es la fuente vinculante (no requiere acceso web).

## Risks & Mitigations

| Riesgo | Mitigación |
|---|---|
| Solapamiento 07/35 | Frontera fijada (07 fundamentos + migración; 35 grafo Wire), cross-refs bidireccionales, sin recetas duplicadas. |
| Regresión estructural/frontmatter | Validador strict 39/39 como gate; frontmatter intacto salvo necesidad; sincronía de índices obligatoria. |
| Deriva de claims | Todo lo nuevo traza al Addendum A; sin cifras de rate; sin `SeparateAsync`, `AudioLimiter` ni `AudioGate`. |
| Índices desincronizados | Paso de cierre sobre los 3 índices + validador; conteos 39/610/35 sin cambios. |
| Peak de presupuesto | Guarda de 400 líneas en `sdd-tasks` + split PR1/PR2 propuesto. |
| `roblox-18` sin edición factual (V9 fuera del Addendum A) | Declarado en alcance; follow-up separado que no bloquea v1. |

## Rollback Plan

Los cambios son solo texto Markdown en `skills-roblox/`: revertir con `git revert <commit>` (o `git checkout --` de los archivos del PR) y confirmar la restauración con el validador strict (39/39) y `git diff`. Sin datos, runtime ni migraciones; bridge/plugin/Studio intactos.

## Success Criteria

- [ ] Los 4 hallazgos quedan corregidos según el Addendum A (DevEx: atribución/elegibilidad/vigencia; audio: tabla + nodos; remotos: anexo canónico; CSG: 20k/`SplitApart`/`rbxNegate`/beta gate + specs de import).
- [ ] `validate-skills.mjs --strict`: 39/39, exit 0.
- [ ] Índices sincronizados (`SKILLS.md`, `AGENTS.md`, `.atl/skill-registry.md`); conteos 39 entradas / 610 skills / 35 dominios intactos.
- [ ] Cero claims fuera del Addendum A; cero cifras de rate nuevas; `SeparateAsync`/`AudioLimiter`/`AudioGate` no publicados.
- [ ] Frontera 07/35 aplicada con cross-references.
