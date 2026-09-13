# Apply Progress — `raase-catalog-improvements` (PR1: WU1 + WU2)

> sdd-apply · 2026-09-13 · store: openspec · Blueprint: `design.md` · Fuente vinculante: `research.md` → Addendum A · Sin commits ejecutados.

## Status

**Slice PR1 COMPLETO** (WU0 + WU1 + WU2). WU3–WU5 quedan pendientes para PR2.
Todas las ediciones se aplicaron **como diseñadas** (12/12); ninguna desviación, ninguna edición fuera de los 3 archivos objetivo.

## Baseline (WU0)

- **HEAD base SHA:** `e00fbaa461dc358573727eff241ea5ec4dd18991`
- **Hashes SHA256 pre-edit de índices (read-only):**
  - `skills-roblox/SKILLS.md` = `40519C759FAB7A1FE8339B79509AE06E074E5A822FA92F92CD39E4CA6F67A4B0`
  - `skills-roblox/AGENTS.md` = `099FDA804446DF25C360AFFB6E99ED15BA457602402C94546C1B19BA1FF55B27`
  - `skills-roblox/.atl/skill-registry.md` = `30BA6C4D75E81D93BB30DD8D6FBA050C3FCB08E6020EA143667A579F0B7ED1D0`
- **Snapshot de working tree:** M `README.md`, M `agent/system_prompt.md`, M `skills-roblox/.atl/skill-registry.md`, M `skills-roblox/AGENTS.md`, M `skills-roblox/SKILLS.md`, M `skills-roblox/roblox-engineer/SKILL.md`; untracked: `openspec/`, `skills-roblox/roblox-38-env-vfx-craft/`. Coincide con el lote sucio esperado; queda intacto.

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

## Commits preparados (NO ejecutados)

**WU1** — boundary: solo `skills-roblox/roblox-09-economy-devex/SKILL.md`:
```text
fix(skills-roblox): correct DevEx rates, eligibility and 18+ verification attribution (roblox-09)
```

**WU2** — boundary: `skills-roblox/roblox-04-3d-world-csg/SKILL.md`, `skills-roblox/roblox-36-asset-pipeline/SKILL.md`:
```text
fix(skills-roblox): align CSG triangle budget, union options and asset import specs (roblox-04, roblox-36)
```
`git add` por archivo explícito — nunca `git add -A` (lote roblox-38 sin commitear).

## Pendiente para PR2

- **WU3:** `roblox-07` + `roblox-35` (B1–B3) — anexo de migración legacy→Audio API + frontera 07/35 con cross-refs.
- **WU4:** `roblox-02` (C1) — anexo de plumbing canónico de remotos.
- **WU5:** cierre — validador strict, conteos, tokens prohibidos en los 6 archivos, hashes de índices.
- `tasks.md`: WU3 (4), WU4 (2) y WU5 (9) permanecen sin marcar.

## Notas

- **Anclas vs. design:** todas las anclas del blueprint coincidieron con el texto real de los archivos. En **E1**, el texto real de la regla 2 usa `≤` (`props ≤ 5,000`; `héroes/armas ≤ 20,000`): se conservó tal cual y el paréntesis se insertó tras `20,000`. En **D6** se respetó la corrección del validador de design: la frase es "no existe API in-game de separación; el Separate de Studio (Shift+Ctrl+U) es la única vía" — la cadena `SeparateAsync` no aparece en ningún archivo final.
- Sin cambios de frontmatter/descripciones; sin reglas `### NNN.` nuevas; sin tocar índices, `agent/raase_skills.json`, `roblox-18` ni el lote roblox-38.
- **Rollback PR1:** `git checkout -- skills-roblox/roblox-09-economy-devex/SKILL.md skills-roblox/roblox-04-3d-world-csg/SKILL.md skills-roblox/roblox-36-asset-pipeline/SKILL.md` (nunca `git checkout -- .`).
