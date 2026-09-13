# Apply Progress — `raase-catalog-improvements` (PR1 + PR2: WU1–WU5)

> sdd-apply · 2026-09-13 · store: openspec · Blueprint: `design.md` · Fuente vinculante: `research.md` → Addendum A · PR1 (WU1+WU2) commiteado y pusheado; PR2 (WU3+WU4+WU5) aplicado en working tree, sin commit.

## Status

**Change COMPLETO** (PR1: WU0 + WU1 + WU2 · PR2: WU3 + WU4 + WU5).
PR1: 12/12 ediciones como diseñadas, ya en historia (`1ec1eb9`, `19be1ac`). PR2: 4/4 ediciones (B1–B3 + C1) como diseñadas, verificadas y sin commit. Ninguna edición fuera de los archivos objetivo de cada slice.

## Baseline (WU0)

- **HEAD base SHA:** `e00fbaa461dc358573727eff241ea5ec4dd18991`
- **Hashes SHA256 pre-edit de índices (read-only):**
  - `skills-roblox/SKILLS.md` = `40519C759FAB7A1FE8339B79509AE06E074E5A822FA92F92CD39E4CA6F67A4B0`
  - `skills-roblox/AGENTS.md` = `099FDA804446DF25C360AFFB6E99ED15BA457602402C94546C1B19BA1FF55B27`
  - `skills-roblox/.atl/skill-registry.md` = `30BA6C4D75E81D93BB30DD8D6FBA050C3FCB08E6020EA143667A579F0B7ED1D0`
- **Snapshot de working tree:** M `README.md`, M `agent/system_prompt.md`, M `skills-roblox/.atl/skill-registry.md`, M `skills-roblox/AGENTS.md`, M `skills-roblox/SKILLS.md`, M `skills-roblox/roblox-engineer/SKILL.md`; untracked: `openspec/`, `skills-roblox/roblox-38-env-vfx-craft/`. Coincide con el lote sucio esperado; queda intacto.
- **Baseline PR2 (post-PR1, 2026-09-13):** HEAD = `2756810cb0d65f936a9c3da5aaf268f71efe390c` (PR1: `1ec1eb9` WU1, `19be1ac` WU2, `2756810` artefactos openspec). Los 3 archivos de PR1 están limpios en HEAD (0 diff); los 3 índices re-hasheados pre/post PR2: **idénticos** a WU0.2. El lote sucio del working tree sigue intacto (`openspec/` ya quedó trackeado por 2756810).

## WU1 — `roblox-09-economy-devex` (A1–A4) ✅

| Edit | Texto final (resumen) |
|---|---|
| **A1** (marco de tasas, L16-19) | Primer bullet nuevo: `- **Vigencia verificada:** 2026-09-13 (documentación oficial de Roblox); la tasa 18+ rige desde el 8-jun-2026.` Tasa 18+: la verificación de edad/identidad corresponde al **jugador comprador U.S. 18+** (facial age estimation o government ID) y aplica a developer products, passes, subscriptions y private servers en juegos elegibles. Tasa legada: "saldos anteriores al 5-sep-2025, 10 a. m. PT". Ejemplos $114.00/$162.00 conservados. |
| **A2** (regla 218) | Seis criterios verificados: 100 % del playtime como R15 platform; human-form custom (12 limb parts O 12 limb joints; torso ≥2; bípedo completo) **o** nonhuman-form custom (también califica); sin R6 en ningún momento; animation packs R15; NPCs no se evalúan. |
| **A3** (regla 219) | `StarterPlayer.GameSettings` ELIMINADO. Regla reformulada: la exigencia R15 aplica al sistema de avatares platform para la tasa 18+ (correr 100 % en R15, sin R6); no es requisito del DevEx estándar. |
| **A4** (regla 220) | Umbral 30.000 R$ conservado + requisitos base añadidos: `(requisitos base: 13+, email verificado, portal DevEx, formularios W-9/W-8)`. |
| **V9** (auditoría `roblox-18`, sin edición) | Grep de `0.0038|0.0054|0.0035|DevEx|devex` → **0 coincidencias**. `roblox-18` no publica tasas DevEx ni claims de elegibilidad 18+; `git status` del archivo vacío. Confirmado. |

## WU2 — `roblox-04` + `roblox-36` (D1–D6, E1–E2) ✅

| Edit | Texto final (resumen) |
|---|---|
| **D1** (087) | Rango "4,000 a 10,000" reemplazado por: límite oficial de **20,000 triángulos por mesh individual**; las operaciones CSG que exceden el tope simplifican el resultado a 20k, o fallan si no se puede. |
| **D2** (090) | Bullet nuevo bajo la regla: `- **Reparación (watertight):** Blender (3D Print Toolbox, Mesh Repair Tools) o Meshlab reparan huecos y caras invertidas; `Solidify` de Blender da grosor a shells.` |
| **D3** (091) | Opciones verificadas de `GeometryService:UnionAsync()` añadidas: `CollisionFidelity`, `RenderFidelity`, `SplitApart` (default `true`) y `CalculateConstraintsToPreserve`. |
| **D4** (094) | `SweepPartAsync` marcado con `(requiere la Beta Feature "Solid Modeling On Meshes", File → Beta Features; no es release pleno)`. |
| **D5** (095) | `GeometryService:FragmentAsync()` nombrado explícitamente + mismo beta gate "Solid Modeling On Meshes". |
| **D6** (anexo tras L111) | Título exacto `## 🧱 Anexo: Un-merge, negación y CSG sobre meshes (notas)` con 4 bullets: Separate de Studio (Shift+Ctrl+U) como única vía de un-merge (sin API in-game de separación); negación in-game con tag `rbxNegate` vía `CollectionService`; reemplazo de geometría con `SubstituteGeometry()`/`MeshPart:ApplyMesh()`; beta gate de Sweep/Fragment/CSG sobre meshes. **Sin la cadena `SeparateAsync`.** |
| **E1** (36 regla 2) | `héroes/armas ≤ 20,000 (tope oficial por mesh individual; alineado con roblox-04)`. Props ≤ 5,000 y flipbooks ≤ 1,024 px intactos. |
| **E2** (36 paso 5) | Bullet nuevo `- **Requisitos de exportación verificados** (confirmar antes de importar):` con 5 sub-bullets: transform congelado (`scale (1,1,1)`, `rot (0,0,0)`) y root en `(0,0,0)`; máx. 4 influencias por vértice sin influencias al root; un solo track de animación por export; cages `_InnerCage` / `_OuterCage`; geometría watertight, sin N-gons, sin grosor 0. |

## WU3 — `roblox-07` + `roblox-35` (B1–B3) ✅

| Edit | Texto final (resumen) |
|---|---|
| **B1** (anexo tras L83 en 07) | Título exacto `## 🔁 Anexo: Migración legacy → Audio API (tabla de equivalencias)`; intro (convivencia legacy `*SoundEffect` ↔ Audio API, verificado 2026-09-13); tabla de 2 columnas × 8 filas con flecha de mapeo en cada fila (`DistortionSoundEffect`→`AudioDistortion`, `EqualizerSoundEffect`→`AudioEqualizer`, `ReverbSoundEffect`→`AudioReverb`, `CompressorSoundEffect`→`AudioCompressor`, `ChorusSoundEffect`→`AudioChorus`, `FlangeSoundEffect`→`AudioFlanger`, `TremoloSoundEffect`→`AudioTremolo`, `EchoSoundEffect`→`AudioEcho`); bullet de orden con el ejemplo invertido `Chorus→Distortion` ≠ `Distortion→Chorus`; bullet de frontera → 35. Append puro (+17/−0). |
| **B2** (35 L235) | Enumeración de procesadores extendida: `AudioFilter`, `AudioPitchShifter`, `AudioFader` + `AudioDistortion`, `AudioEcho`, `AudioCompressor`, `AudioEqualizer`, `AudioTremolo`, `AudioFlanger` = **9 procesadores nombrados**. |
| **B3** (35 tras L236) | Bullet nuevo: `- **Frontera con roblox-07:** esta skill cubre el grafo Wire avanzado; los fundamentos de DSP y la tabla de migración legacy→moderna viven en [roblox-07-audio-dsp](../roblox-07-audio-dsp/SKILL.md).` (35 = +2/−1). |

Nota B1: la verificación `→` = **10** de tasks.md exige la flecha **dentro de cada fila** (8) + título (1) + nota de orden en una línea (1). La primera versión de la tabla (sin flechas por fila) daba 2; se corrigió antes del cierre. La tabla conserva 2 columnas y 8 filas.

## WU4 — `roblox-02` (C1) ✅

| Edit | Texto final (resumen) |
|---|---|
| **C1** (anexo tras L133 en 02) | Título exacto `## 📡 Anexo: Plumbing canónico de remotos (cliente ↔ servidor)`. Contenido: bullet cliente→servidor (`FireServer` → `OnServerEvent` con `player` como primer argumento; validación 026 → 029 + 032 → respuesta `FireClient`); bullet servidor→cliente (`FireClient`/`OnClientEvent` + `FireAllClients`); bullet de decisión Reliable vs Unreliable; snippet Luau `--!strict` con validación server-side y `FireClient(player, "ack")`; tabla de decisión de 5 filas `RemoteEvent` vs `UnreliableRemoteEvent`; 3 riesgos de `InvokeClient` + preferir `RemoteEvent` para una vía; 7 limitaciones de argumentos (índices no-string, funciones→`nil`, claves numéricas+string, `nil`, tablas copiadas, metatables, no replicables). Append puro (+44/−0); sin cifras de rate nuevas; reglas 032 (L41) y 051 (L98) intactas. |

## WU5 — Cierre ✅

| Gate | Resultado (salida real) |
|---|---|
| 5.1 Validador strict | `39 pass · 0 with issues · 0 errors · 0 warnings · EXIT=0` (re-ejecutado sobre el estado final, post-corrección de tabla). |
| 5.2 Conteos | SKILL.md = **39**; reglas `^### \d{3}\.` = **610**; dominios únicos = **35**. |
| 5.3 Reglas numeradas nuevas | `git diff e00fbaa -U0` sobre los 6 archivos → 0 coincidencias de `^\+.*### \d{3}\.` (idem por archivo). |
| 5.4 Tokens prohibidos | `SeparateAsync|AudioLimiter|AudioGate|StarterPlayer\.GameSettings` en los 6 archivos finales = **0**. |
| 5.5 Índices no-op | Hashes post == WU0.2: `4051…A4B0`, `099F…5B27`, `30BA…D1D0` (idénticos pre y post). |
| 5.6 Registro | `agent/raase_skills.json` sin cambios; sin `SOURCES.md` nuevo; sin micro-skills numeradas nuevas. |
| 5.7 Aislamiento | Skills: solo los **3 M** esperados (`roblox-02`, `roblox-07`, `roblox-35`); PR1 sin diff vs HEAD; lote roblox-38 intacto. `openspec/` ya está trackeado (2756810), por lo que `tasks.md` y `apply-progress.md` figuran como M por este mismo cierre (artefactos SDD, no skills). |
| 5.8 Lectura de vuelta | Títulos exactos de anexos; cross-refs 07↔35 bidireccionales (07 L100 → 35; 35 L237 → 07); hechos del Addendum A; frontmatter intacto (0 líneas `name:`/`description:` en el diff). |
| 5.9 Sin commit | WU5 solo verificación; no se ejecutó commit. |

## Evidencia de verificación (post-edit, salida real)

1. **Validador strict:** `39 pass · 0 with issues · 0 errors · 0 warnings · exit 0`.
2. **Conteos:** SKILL.md = **39**; reglas `^### \d{3}\.` = **610**; dominios únicos = **35**.
3. **Tokens prohibidos:** `SeparateAsync|AudioLimiter|AudioGate` en los 3 archivos finales = **0**; `StarterPlayer.GameSettings` en 09 final = **0**.
4. **Reglas numeradas nuevas:** `git diff -U0 | ^\+.*### \d{3}\.` = **0**; diff de frontmatter (`^[+-](name|description):`) = **0**.
5. **Índices no-op:** hashes post-edit **idénticos** a WU0.2 (`4051…A4B0`, `099F…5B27`, `30BA…D1D0`).
6. **Aislamiento:** `git diff --stat` = solo los 3 archivos (25 insertions, 10 deletions); `git status --short` = baseline + 3 `M` nuevos; `roblox-18` sin cambios.
7. **WU1 — greps de presencia (cada uno ≥1):** `2026-09-13`, `8-jun-2026`, `5-sep-2025, 10 a. m. PT`, `facial`, `government ID`, `nonhuman-form`, `13+`, `W-9`, `W-8`. Ausencia: `antes de septiembre de 2025` = **0**.
8. **WU2 — greps de presencia (cada uno ≥1):** en 04: `20,000`, `SplitApart`, `CollisionFidelity`, `RenderFidelity`, `CalculateConstraintsToPreserve`, `SweepPartAsync`, `FragmentAsync`, `rbxNegate`, `SubstituteGeometry`, `Beta Feature`, `Shift+Ctrl+U`; ausencia: `4,000 a 10,000` = **0**. En 36: `_InnerCage`, `_OuterCage`, `20,000`, `4 influencias`, `N-gons`, `watertight`.
9. **tasks.md:** WU0 (3) + WU1 (6) + WU2 (9) = **18 ítems `[x]`**; quedan **15 `[ ]`** (solo WU3–WU5).

## Evidencia de verificación (PR2, post-edit, salida real)

10. **Diffs acotados:** 07 = +17/−0 (append puro); 35 = +2/−1 (L235 extendida + bullet B3); 02 = +44/−0 (append puro). Total del slice: **63 insertions / 1 deletion**.
11. **WU3:** `AudioLimiter|AudioGate|multi-reverb|sin scripting` en 07/35 = **0**; `→` en 07 = **10**; clases `Audio*` en 07 = **8**; cada uno de los 6 nodos en 35 ≥1; cross-refs bidireccionales presentes; `git diff -U0 -- 07` sin líneas `^-` (solo append).
12. **WU4:** `FireServer`/`OnServerEvent`/`FireClient`/`OnClientEvent`/`FireAllClients`/`UnreliableRemoteEvent`/`InvokeClient` cada uno ≥1; `metatables`/`no replicables`/`índices no-string`/`claves numéricas` cada uno ≥1; `git diff -U0 -- 02` sin líneas `^-`; sin hunks sobre reglas 032/051.
13. **Integridad:** 07/35/02 = UTF-8 válido y CRLF puro (0 mixtos); frontmatter intacto; hashes de índices re-capturados post-cierre === WU0.2.

## Commits PR1 (EJECUTADOS por el orquestador)

Ya en historia: `1ec1eb9` (WU1), `19be1ac` (WU2) y `2756810` (artefactos openspec del change). Mensajes preparados originales:

**WU1** — boundary: solo `skills-roblox/roblox-09-economy-devex/SKILL.md`:
```text
fix(skills-roblox): correct DevEx rates, eligibility and 18+ verification attribution (roblox-09)
```

**WU2** — boundary: `skills-roblox/roblox-04-3d-world-csg/SKILL.md`, `skills-roblox/roblox-36-asset-pipeline/SKILL.md`:
```text
fix(skills-roblox): align CSG triangle budget, union options and asset import specs (roblox-04, roblox-36)
```
`git add` por archivo explícito — nunca `git add -A` (lote roblox-38 sin commitear).

## Commits PR2 preparados (NO ejecutados)

**WU3** — boundary: `skills-roblox/roblox-07-audio-dsp/SKILL.md`, `skills-roblox/roblox-35-dynamic-audio-music/SKILL.md`:
```text
docs(skills-roblox): add legacy-to-Audio API mapping and settle 07/35 boundary (roblox-07, roblox-35)
```

**WU4** — boundary: solo `skills-roblox/roblox-02-netsec/SKILL.md`:
```text
docs(skills-roblox): add canonical remote plumbing annex (roblox-02)
```

Alternativa combinada (1 solo commit para PR2):
```text
feat(skills-roblox): add audio legacy-modern mapping and canonical remotes plumbing (roblox-07, roblox-35, roblox-02)
```
`git add` por archivo explícito — nunca `git add -A` (lote roblox-38 sin commitear). WU5 no agrega commit propio.

## PR2 (WU3 + WU4 + WU5) — EJECUTADO

- **WU3:** `roblox-07` + `roblox-35` (B1–B3) ✅ — ver sección WU3.
- **WU4:** `roblox-02` (C1) ✅ — ver sección WU4.
- **WU5:** cierre ✅ — ver sección WU5 (todos los gates en verde).
- `tasks.md`: WU0–WU5 marcados `[x]` (**33/33**); 0 `[ ]` restantes.
- **Rollback PR2:** `git checkout -- skills-roblox/roblox-07-audio-dsp/SKILL.md skills-roblox/roblox-35-dynamic-audio-music/SKILL.md skills-roblox/roblox-02-netsec/SKILL.md` (nunca `git checkout -- .`).

## Notas

- **Anclas vs. design:** todas las anclas del blueprint coincidieron con el texto real de los archivos. En **E1**, el texto real de la regla 2 usa `≤` (`props ≤ 5,000`; `héroes/armas ≤ 20,000`): se conservó tal cual y el paréntesis se insertó tras `20,000`. En **D6** se respetó la corrección del validador de design: la frase es "no existe API in-game de separación; el Separate de Studio (Shift+Ctrl+U) es la única vía" — la cadena `SeparateAsync` no aparece en ningún archivo final.
- Sin cambios de frontmatter/descripciones; sin reglas `### NNN.` nuevas; sin tocar índices, `agent/raase_skills.json`, `roblox-18` ni el lote roblox-38.
- **Rollback PR1:** `git checkout -- skills-roblox/roblox-09-economy-devex/SKILL.md skills-roblox/roblox-04-3d-world-csg/SKILL.md skills-roblox/roblox-36-asset-pipeline/SKILL.md` (nunca `git checkout -- .`).
- **PR2 — flecha de mapeo en la tabla (B1):** la verificación de tasks.md (`→` = 10) exige la flecha en cada una de las 8 filas de la tabla; la primera versión (sin flechas por fila) daba 2 y se corrigió antes del cierre. La tabla sigue teniendo 2 columnas y 8 filas; `Audio*` en 07 = 8 líneas (una por fila).
- **PR2 — aislamiento:** `openspec/` quedó trackeado por 2756810 (commit de PR1), por lo que las actualizaciones de `tasks.md` y `apply-progress.md` de este cierre aparecen como M además de los 3 SKILL.md. Ni `agent/raase_skills.json`, ni los 3 índices, ni el lote roblox-38 fueron tocados; los archivos de PR1 no tienen diff vs HEAD.
- **PR2 — anclas vs. design:** las anclas del blueprint (07 L83, 35 L235-236, 02 L133) coincidieron con el texto real. En 35, la extensión del paréntesis conservó los 3 procesadores previos + 6 nuevos = 9; en 02, el anexo es 100% append (reglas 032/051 intactas).

## Estado de entrega (2026-09-13, post-verify)

- **PR1:** ✅ entregado y pusheado (commits `1ec1eb9`, `19be1ac`, `2756810`; `neno/main` = `2756810`).
- **PR2:** ⏸️ **EN ESPERA por decisión del creador** (esperar el scoping del validador `skills-25-upgrade`). Ediciones aplicadas y verificadas en working tree; **NO commiteado**. Pendientes de commit: `roblox-07`, `roblox-35`, `roblox-02`, compliance `allows-script-exec` en `roblox-36` (nuevo), + `tasks.md` + este artefacto + `verify-report.md`.
- **Gate actual:** validador externo en WIP → `39 pass · 1 with issues · 3 errors` catalog-level (`catalog.json`/tier0/orphan-section; falsos positivos del WIP sin scoping de modo-dominio, reproducen en base `e00fbaa`). El error `script-audit` quedó resuelto vía `allows-script-exec`.
- **Desbloqueo:** cuando el scoping de `skills-25-upgrade` lande → re-correr `validate-skills.mjs --strict`; si queda 39/39 full → commit + push PR2 → `sdd-archive`.
