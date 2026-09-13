# Tareas: Mejoras del catálogo RAASE 2.1 (`raase-catalog-improvements`)

> sdd-tasks · 2026-09-13 · store: openspec · Blueprint: `design.md` (16 ediciones A1-E2, §"Orden de apply") · DoD trazado a las 27 requirements de `specs/**`. Fuente vinculante: `research.md` → Addendum A.

**Guard de entrega (contrato):**

```text
Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: Medium
```

**Order of apply → PR plan:** WU1 → WU2 (PR1) · WU3 → WU4 → WU5 (PR2). Commits secuenciales. `git add` por archivo explícito: **nunca** `git add -A` ni `git diff` sin filtro (hay lote roblox-38 sin commitear).

## WU0 — Línea base (antes de la primera edición)

- [x] 0.1 Guardar el SHA base: `git rev-parse HEAD` (va a apply-progress; se usa en todas las verificaciones acumuladas).
- [x] 0.2 Guardar hashes SHA256 de `skills-roblox/SKILLS.md` (read-only), `skills-roblox/AGENTS.md` (read-only) y `skills-roblox/.atl/skill-registry.md` (read-only) con `Get-FileHash` (capturados en planificación: `4051…A4B0`, `099F…5B27`, `30BA…D1D0`).
- [x] 0.3 Snapshot de aislamiento: `git status --short` debe mostrar el lote sucio esperado — M: `README.md`, `agent/system_prompt.md`, `skills-roblox/.atl/skill-registry.md`, `skills-roblox/AGENTS.md`, `skills-roblox/SKILLS.md`, `skills-roblox/roblox-engineer/SKILL.md`; untracked: `openspec/`, `skills-roblox/roblox-38-env-vfx-craft/`. Guardar la salida.

## WU1 — DevEx: `roblox-09` (A1-A4) + auditoría V9 de `roblox-18`

**Archivos:** edita `skills-roblox/roblox-09-economy-devex/SKILL.md`; audita sin editar `skills-roblox/roblox-18-monetization-suite/SKILL.md`.

- [x] 1.1 **(A1, L16-19)** Bullet de vigencia "verificado 2026-09-13; tasa 18+ vigente desde 8-jun-2026"; L18: la verificación de edad/identidad corresponde al **jugador comprador U.S. 18+** (facial age estimation o government ID; alcance: developer products, passes, subscriptions, private servers); L19: "saldos anteriores al 5-sep-2025, 10 a. m. PT"; conservar $114.00/$162.00.
- [x] 1.2 **(A2, regla 218, L45)** Criterios: 100 % del playtime como R15 platform; human-form custom (12 limb parts O 12 limb joints, torso ≥2, bípedo) o nonhuman-form custom (también califica); sin R6; animation packs R15; NPCs no se evalúan.
- [x] 1.3 **(A3, regla 219, L48)** Eliminar `StarterPlayer.GameSettings`; reformular: la exigencia R15 aplica al sistema de avatares platform para la tasa 18+ y no es requisito del DevEx estándar.
- [x] 1.4 **(A4, regla 220, L51)** Conservar umbral 30.000 R$ + requisitos base (13+, email verificado, portal DevEx, W-9/W-8).
- [x] 1.5 **(V9, auditoría)** Confirmar que `roblox-18` no publica tasas DevEx; registrar hallazgo en apply-progress; sin edición factual.
- [x] 1.6 **DoD (spec `devex-fact-sheet`, 6 reqs):** tasas con ejemplos + nota de vigencia (R1); corte legado exacto sin "antes de septiembre de 2025" (R1); atribución al jugador con ambos métodos (R2); seis criterios con nonhuman-form elegible (R3); umbral + 4 requisitos base (R4); 0 `StarterPlayer.GameSettings` (R5); `roblox-18` sin tasas ni edición (R6).

**Verificación (PowerShell, desde la raíz):**

```powershell
Select-String -Path "skills-roblox\roblox-09-economy-devex\SKILL.md" -Pattern 'StarterPlayer\.GameSettings'   # 0
Select-String -Path "skills-roblox\roblox-09-economy-devex\SKILL.md" -Pattern '2026-09-13|8-jun-2026|5-sep-2025, 10 a\. m\. PT|facial|government ID|nonhuman-form|13\+|W-9|W-8'   # cada patrón >=1
Select-String -Path "skills-roblox\roblox-09-economy-devex\SKILL.md" -Pattern 'antes de septiembre de 2025'   # 0
git diff -U0 -- skills-roblox/roblox-09-economy-devex/SKILL.md | Select-String -Pattern '^\+.*### \d{3}\.'   # 0 líneas numeradas nuevas
git diff -- skills-roblox/roblox-09-economy-devex/SKILL.md | Select-String -Pattern '^[+-](name|description):'   # 0 (frontmatter intacto)
git status --short -- skills-roblox/roblox-18-monetization-suite/SKILL.md   # vacío (sin edición)
```

**Commit:** `fix(skills-roblox): correct DevEx rates, eligibility and 18+ verification attribution (roblox-09)` — boundary: solo `roblox-09`.

## WU2 — CSG/specs: `roblox-04` + `roblox-36` (D1-D6, E1-E2)

**Archivos:** `skills-roblox/roblox-04-3d-world-csg/SKILL.md`, `skills-roblox/roblox-36-asset-pipeline/SKILL.md`.

- [x] 2.1 **(D1, 087, L27)** Reemplazar "máximo 4,000 a 10,000 triángulos" por el límite oficial de 20,000 tris por mesh; las operaciones CSG simplifican a 20k si se excede (o fallan).
- [x] 2.2 **(D2, 090, L36)** Bullet nuevo bajo la regla: reparación watertight con Blender (3D Print Toolbox, Mesh Repair Tools) o Meshlab; `Solidify` para shells.
- [x] 2.3 **(D3, 091, L39)** Añadir opciones de `UnionAsync`: `CollisionFidelity`, `RenderFidelity`, `SplitApart` (default `true`), `CalculateConstraintsToPreserve`.
- [x] 2.4 **(D4, 094, L48)** `SweepPartAsync` tras la Beta Feature "Solid Modeling On Meshes" (File → Beta Features; no release pleno).
- [x] 2.5 **(D5, 095, L51)** Nombrar `GeometryService:FragmentAsync()` + mismo beta gate.
- [x] 2.6 **(D6, anexo tras L111)** Título exacto `## 🧱 Anexo: Un-merge, negación y CSG sobre meshes (notas)`: Separate de Studio (Shift+Ctrl+U) única vía de un-merge; tag `rbxNegate` vía `CollectionService`; `SubstituteGeometry()`/`MeshPart:ApplyMesh()`; beta gate. Sin `SeparateAsync`.
- [x] 2.7 **(E1, 36 regla 2, L96)** Precisar "héroes/armas = 20,000 (tope oficial por mesh individual; alineado con roblox-04)".
- [x] 2.8 **(E2, 36 paso 5, tras L83)** Bullet de requisitos verificados: transform congelado scale (1,1,1)/rot (0,0,0) + root en (0,0,0); máx. 4 influencias por vértice sin influencias al root; single track de animación por export; cages `_InnerCage`/`_OuterCage`; geometría watertight, sin N-gons, sin grosor 0.
- [x] 2.9 **DoD (spec `csg-import-specs`, 6 reqs):** 20k en 04 sin rango viejo (R1); 36 alineado al tope (R1); cuatro opciones de UnionAsync con default de SplitApart (R2); un-merge + `rbxNegate` + substitute sin `SeparateAsync` (R3); beta gate visible en 094-095 (R4); herramientas watertight (R5); specs de importación en el handoff (R6).

**Verificación (PowerShell):**

```powershell
Select-String -Path "skills-roblox\roblox-04-3d-world-csg\SKILL.md","skills-roblox\roblox-36-asset-pipeline\SKILL.md" -Pattern 'SeparateAsync'   # 0
Select-String -Path "skills-roblox\roblox-04-3d-world-csg\SKILL.md" -Pattern '4,000 a 10,000'   # 0
Select-String -Path "skills-roblox\roblox-04-3d-world-csg\SKILL.md" -Pattern '20,000|SplitApart|CollisionFidelity|RenderFidelity|CalculateConstraintsToPreserve|SweepPartAsync|FragmentAsync|rbxNegate|SubstituteGeometry|Beta Feature|Shift\+Ctrl\+U'   # cada patrón >=1
Select-String -Path "skills-roblox\roblox-36-asset-pipeline\SKILL.md" -Pattern '_InnerCage|_OuterCage|20,000|4 influencias|N-gons|watertight'   # cada patrón >=1
git diff -U0 -- skills-roblox/roblox-04-3d-world-csg/SKILL.md skills-roblox/roblox-36-asset-pipeline/SKILL.md | Select-String -Pattern '^\+.*### \d{3}\.'   # 0
```

**Commit:** `fix(skills-roblox): align CSG triangle budget, union options and asset import specs (roblox-04, roblox-36)` — boundary: ambos archivos.

## WU3 — Audio: `roblox-07` + `roblox-35` (B1-B3)

**Archivos:** `skills-roblox/roblox-07-audio-dsp/SKILL.md`, `skills-roblox/roblox-35-dynamic-audio-music/SKILL.md`.

- [x] 3.1 **(B1, anexo tras L83 en 07)** Título exacto `## 🔁 Anexo: Migración legacy → Audio API (tabla de equivalencias)`; tabla de 2 columnas con exactamente 8 filas (Distortion→`AudioDistortion`, Equalizer→`AudioEqualizer`, Reverb→`AudioReverb`, Compressor→`AudioCompressor`, Chorus→`AudioChorus`, Flange→`AudioFlanger`, Tremolo→`AudioTremolo`, Echo→`AudioEcho`); nota de orden "Chorus→Distortion ≠ Distortion→Chorus"; cross-ref a `roblox-35`.
- [x] 3.2 **(B2, 35 L235)** Extender la enumeración de procesadores con los 6 nodos faltantes (`AudioDistortion`, `AudioEcho`, `AudioCompressor`, `AudioEqualizer`, `AudioTremolo`, `AudioFlanger`) → 9 procesadores nombrados.
- [x] 3.3 **(B3, 35 tras L236)** Bullet de frontera: 35 = grafo Wire avanzado; fundamentos y tabla de migración viven en `roblox-07` (cross-ref inverso).
- [x] 3.4 **DoD (spec `audio-legacy-modern-mapping`, 5 reqs):** exactamente 8 equivalencias sin clases extra (R1); nota de orden con ejemplo invertido (R2); seis nodos en 35 (R3); cross-refs bidireccionales y sin recetas duplicadas (R4); 0 `AudioLimiter`/`AudioGate`, sin multi-reverb ni "sin scripting" (R5). Anexo de 07 solo-agrega: reglas existentes intactas.

**Verificación (PowerShell):**

```powershell
Select-String -Path "skills-roblox\roblox-07-audio-dsp\SKILL.md","skills-roblox\roblox-35-dynamic-audio-music\SKILL.md" -Pattern 'AudioLimiter|AudioGate|multi-reverb|sin scripting'   # 0
(Select-String -Path "skills-roblox\roblox-07-audio-dsp\SKILL.md" -Pattern '→' | Measure-Object).Count   # 10 (8 filas + 2 del ejemplo de orden)
(Select-String -Path "skills-roblox\roblox-07-audio-dsp\SKILL.md" -Pattern 'AudioDistortion|AudioEqualizer|AudioReverb|AudioCompressor|AudioChorus|AudioFlanger|AudioTremolo|AudioEcho' | Measure-Object).Count   # 8 (una por fila)
Select-String -Path "skills-roblox\roblox-07-audio-dsp\SKILL.md" -Pattern 'roblox-35-dynamic-audio-music'   # >=1
Select-String -Path "skills-roblox\roblox-35-dynamic-audio-music\SKILL.md" -Pattern 'roblox-07-audio-dsp'   # >=1
Select-String -Path "skills-roblox\roblox-35-dynamic-audio-music\SKILL.md" -Pattern 'AudioDistortion|AudioEcho|AudioCompressor|AudioEqualizer|AudioTremolo|AudioFlanger'   # cada patrón >=1
git diff -U0 -- skills-roblox/roblox-07-audio-dsp/SKILL.md | Select-String -Pattern '^-[^-]'   # 0 (solo append en 07)
git diff -U0 -- skills-roblox/roblox-07-audio-dsp/SKILL.md skills-roblox/roblox-35-dynamic-audio-music/SKILL.md | Select-String -Pattern '^\+.*### \d{3}\.'   # 0
```

**Commit:** `docs(skills-roblox): add legacy-to-Audio API mapping and settle 07/35 boundary (roblox-07, roblox-35)` — boundary: ambos archivos.

## WU4 — Remotos: `roblox-02` (C1)

**Archivos:** `skills-roblox/roblox-02-netsec/SKILL.md`.

- [x] 4.1 **(C1, anexo tras L133)** Título exacto `## 📡 Anexo: Plumbing canónico de remotos (cliente ↔ servidor)`:
  - cliente→servidor: `FireServer` + `OnServerEvent(player, …)` (player como primer argumento) con snippet `--!strict`; validación de tipos (026) → distancia (029) + rate limiter (032) → respuesta `FireClient(player, "ack")`.
  - servidor→cliente: `FireClient`/`OnClientEvent`; `FireAllClients` para difusión.
  - tabla de decisión (5 filas) `RemoteEvent` vs `UnreliableRemoteEvent`.
  - riesgos de `InvokeClient` (3) + recomendación de `RemoteEvent` para una vía.
  - 7 limitaciones de argumentos (índices no-string → string; funciones → `nil`; no mezclar claves numéricas y string; evitar `nil`; tablas copiadas; metatables perdidas; instancias no replicables → `nil`).
  - guarda: sin cifras de rate (V20/V21).
- [x] 4.2 **DoD (spec `remotes-canonical-plumbing`, 6 reqs):** plumbing con validación server-side (R1); respuestas al cliente (R2); tabla Reliable/Unreliable (R3); riesgos de `InvokeClient` (R4); siete limitaciones (R5); 0 cifras nuevas y reglas 032 (L41) / 051 (L98) intactas (R6).

**Verificación (PowerShell):**

```powershell
Select-String -Path "skills-roblox\roblox-02-netsec\SKILL.md" -Pattern 'FireServer|OnServerEvent|FireClient|OnClientEvent|FireAllClients|UnreliableRemoteEvent|InvokeClient'   # cada patrón >=1
Select-String -Path "skills-roblox\roblox-02-netsec\SKILL.md" -Pattern 'metatables|no replicables|índices no-string|claves numéricas'   # cada patrón >=1
git diff -U0 -- skills-roblox/roblox-02-netsec/SKILL.md | Select-String -Pattern '^-[^-]'   # 0 (solo append → L41 y L98 intactas)
git diff -U0 -- skills-roblox/roblox-02-netsec/SKILL.md | Select-String -Pattern '^\+.*### \d{3}\.'   # 0
```

**Commit:** `docs(skills-roblox): add canonical remote plumbing annex (roblox-02)` — boundary: solo `roblox-02`.

## WU5 — Cierre: validación completa (gate de `sdd-verify`)

- [x] 5.1 Ejecutar el validador strict (`C:\Users\j1347\Desktop\skills\00-meta-skills\skill-validator\scripts\validate-skills.mjs` (read-only)) → 39/39, exit 0.
- [x] 5.2 Conteos intactos: 39 entradas / 610 micro-skills / 35 dominios.
- [x] 5.3 Cero reglas `### NNN.` nuevas en el diff acumulado de los 6 archivos.
- [x] 5.4 Tokens prohibidos ausentes en los 6 archivos FINALES: `SeparateAsync`, `AudioLimiter`, `AudioGate`, `StarterPlayer.GameSettings`.
- [x] 5.5 Índices no-op: hashes post == hashes de WU0.2 (los 3 índices están sucios por el lote roblox-38: no deben cambiar).
- [x] 5.6 `agent/raase_skills.json` sin cambios (0 diff); sin `SOURCES.md` nuevo; sin micro-skills numeradas nuevas.
- [x] 5.7 Aislamiento: `git status --short` == baseline de WU0.3 + 6 `M` de los 6 archivos editados; nada más (el lote roblox-38 queda intacto).
- [x] 5.8 Lectura de vuelta de los 6 archivos: títulos exactos de anexos, cross-refs 07↔35, hechos del Addendum A, frontmatter intacto.
- [x] 5.9 Sin commit: WU5 es solo verificación y alimenta `sdd-verify`.

```powershell
node "C:\Users\j1347\Desktop\skills\00-meta-skills\skill-validator\scripts\validate-skills.mjs" "skills-roblox" --strict; $LASTEXITCODE   # 39/39 · 0
(Get-ChildItem skills-roblox -Recurse -Filter SKILL.md).Count   # 39
(Select-String -Path "skills-roblox\*\SKILL.md" -Pattern '^### \d{3}\.' | Measure-Object).Count   # 610
(Select-String -Path "skills-roblox\*\SKILL.md" -Pattern '^### \d{3}\.' | Select-Object -ExpandProperty Path -Unique).Count   # 35
$files = "skills-roblox\roblox-02-netsec\SKILL.md","skills-roblox\roblox-04-3d-world-csg\SKILL.md","skills-roblox\roblox-07-audio-dsp\SKILL.md","skills-roblox\roblox-09-economy-devex\SKILL.md","skills-roblox\roblox-35-dynamic-audio-music\SKILL.md","skills-roblox\roblox-36-asset-pipeline\SKILL.md"
Select-String -Path $files -Pattern 'SeparateAsync|AudioLimiter|AudioGate|StarterPlayer\.GameSettings'   # 0
git diff <BASE_SHA> -- $files | Select-String -Pattern '^\+.*### \d{3}\.'   # 0
Get-FileHash skills-roblox\SKILLS.md, skills-roblox\AGENTS.md, skills-roblox\.atl\skill-registry.md -Algorithm SHA256   # == WU0.2
git status --short -- agent/raase_skills.json   # vacío
git status --short   # baseline WU0.3 + 6 M
```

## Evidencia por unidad (focused test · runtime harness · rollback)

| WU | Focused test command | Runtime harness | Rollback boundary |
|----|----------------------|-----------------|-------------------|
| WU1 | greps de presencia/ausencia sobre `roblox-09` | N/A: solo Markdown; sin bridge/Studio (declarado en design) | `git checkout -- skills-roblox/roblox-09-economy-devex/SKILL.md` |
| WU2 | greps de 04/36 (20k, opciones, sin `SeparateAsync`) | N/A (ídem) | `git checkout -- skills-roblox/roblox-04-3d-world-csg/SKILL.md skills-roblox/roblox-36-asset-pipeline/SKILL.md` |
| WU3 | greps 07/35 (8 filas, nodos, cross-refs) + append-only en 07 | N/A (ídem) | `git checkout -- skills-roblox/roblox-07-audio-dsp/SKILL.md skills-roblox/roblox-35-dynamic-audio-music/SKILL.md` |
| WU4 | greps de 02 + append-only (L41/L98 intactas) | N/A (ídem) | `git checkout -- skills-roblox/roblox-02-netsec/SKILL.md` |
| WU5 | validador strict 39/39 + conteos 39/610/35 | N/A (ídem) | sin cambios (solo lectura) — nunca `git checkout -- .` |

## Review Workload Forecast

| Campo | Valor |
|-------|-------|
| Estimated changed lines | 235-380 (máximo del proposal; las 16 ediciones quirúrgicas sugieren el tramo bajo) |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Decision needed before apply | Yes |

```text
Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: Medium
```

**Split propuesto (si se confirma):**

- **PR1 = WU1 + WU2 → 95-150 líneas.** Foco de review: corrección dinero/legal de DevEx (tasas, elegibilidad, atribución 18+) y consistencia del presupuesto CSG/import (20k).
- **PR2 = WU3 + WU4 + WU5 → 140-210 líneas.** Foco de review: frontera audio 07/35 con cross-refs bidireccionales, plumbing canónico de remotos (seguridad cliente↔servidor) y gates de cierre.

Fundamento: aunque el pico estimado (380) no supera el presupuesto de 400, el cambio cruza 4 dominios independientes (dinero/legal, CSG, audio, netsec) en 6 archivos; el split ya contemplado por proposal/design protege el foco de review con dos PRs por debajo de 400 líneas.
