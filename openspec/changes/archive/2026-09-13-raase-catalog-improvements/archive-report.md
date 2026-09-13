# Archive Report — `raase-catalog-improvements`

- **Change:** Mejoras del catálogo RAASE 2.1 (`raase-catalog-improvements`)
- **Archivado:** 2026-09-13 · store: `openspec`
- **Ruta:** `openspec/changes/archive/2026-09-13-raase-catalog-improvements/`
- **Estado al cierre:** **CERRADO** — 33/33 tareas · verify v2 PASS (27/27 requirements · 33/33 scenarios) · 0 blockers · 0 CRITICAL
- **HEAD al cierre:** `36c7b95`, con 2 archivos modificados en working tree (enmienda R2 de `catalog-index-sync` + verify-report v2 admitido) incorporados al commit de cierre de este archivo.

## Verificación final (v2, admitida)

- **Veredicto:** PASS (`{"valid": true, "verdict": "pass"}`); `evidence_revision: sha256:e7c4bd75b4c94a0c997a144e6b07c6a5400972edb85aecbfaf47cc9e8bb6872e`.
- **Gate de cierre scopiado** (definido por la enmienda de `catalog-index-sync` R2 para targets externos no-catálogo):
  `node "...\skill-validator\scripts\validate-skills.mjs" "skills-roblox" --strict --skip-index-sync` → `39 pass · 0 with issues` · **exit 0**.
- Conteos intactos: 39 SKILL.md · 610 reglas numeradas · 35 dominios; tokens prohibidos = 0; reglas `### NNN.` nuevas = 0; frontmatter `name`/`description` intacto; índices no-op vs línea base WU0.2.
- Los errores `manifest-*` del validador son drift externo ajeno a este change (Judgment Day, 4 jueces, 2026-09-13); ver "Problema externo conocido".

## Commits entregados

| Commit | Alcance |
|---|---|
| `1ec1eb9` | WU1 — DevEx: tasas, elegibilidad y atribución 18+ (`roblox-09`) |
| `19be1ac` | WU2 — CSG/import: presupuesto 20k, opciones de UnionAsync, specs de importación (`roblox-04`, `roblox-36`) |
| `2756810` | Artefactos openspec del change (PR1) |
| `eff5931` | Lote `roblox-38` (ajeno a las ediciones de este change; landeado entre PR1 y PR2) |
| `c433a7c` | WU3 — Audio: tabla legacy→Audio API y frontera 07/35 (`roblox-07`, `roblox-35`) |
| `9cb0301` | WU4 — Plumbing canónico de remotos (`roblox-02`) |
| `c373552` | Compliance del validador: `allows-script-exec` en frontmatter (`roblox-36`) |
| `36c7b95` | Cierre de trail (tasks 33/33, apply-progress, verify-report) |

- Al cierre quedaban 2 modificaciones sin commitear (enmienda R2 + verify-report v2 admitido); se commitean junto con el archivo del change.
- Nota de trazabilidad: la sección "Estado de entrega" de `apply-progress.md` registraba PR2 "en espera" (snapshot intermedio previo); los commits de PR2 se ejecutaron después (`c433a7c` → `36c7b95`), como confirma el historial.

## Specs promovidas (baseline nuevo)

`openspec/specs/` no tenía specs principales (solo `.gitkeep`); las 5 delta specs son ahora el baseline, por copia mecánica byte a byte (`git diff --no-index` vacío + SHA256 idénticos, sin composición). `.gitkeep` eliminado.

| Capability | Requirements | SHA256 |
|---|---|---|
| `devex-fact-sheet` | 6 | `C6236E65371D633C6D67BC22E0C51BE0F52CD6B0B8D536007AC31869D0A19C56` |
| `audio-legacy-modern-mapping` | 5 | `943C9851264B673841EFB29C92C83311C037A851A549B02288D944128B0EEC07` |
| `remotes-canonical-plumbing` | 6 | `E098AFBE976BA4A6EB82F7C7A80C50B8020335B47833AB047D70D1A7AEE7AC7B` |
| `csg-import-specs` | 6 | `25F9065D805D9D2DF3934A6DF95BCF3C8D146698BFDB892665C84F3EB01D3890` |
| `catalog-index-sync` | 4 (R2 enmendada: gate scopiado) | `1D9CFA713492456B6A5E2EE9311AC5FF8358247B98565F7BA767BE1637FF96EC` |

Total: **27 requirements / 33 scenarios**.

## Contenido del archivo

`proposal.md` · `exploration.md` · `research.md` · `design.md` · `specs/` (5 capabilities) · `tasks.md` (33/33) · `apply-progress.md` · `verify-report.md` · `archive-report.md` (este archivo).

## Problema externo conocido (no bloqueante)

- El validador skillsGV (`skills-25-upgrade` WU3a) carece de scoping de targets externos: emite falsos positivos `manifest-*` / `catalog.json` / `tier0` sobre carpetas de dominio externas como `skills-roblox`. Judgment Day (4 jueces, 2026-09-13) validó que son ajenos a este change y que la corrección naíf no es shippable. **Handoff pendiente** al lado skillsGV; no bloquea este archivo. El contrato vigente para targets externos es el gate scopiado definido en `catalog-index-sync` R2.

## Follow-ups heredados

- `SOURCES.md` — trazabilidad de fuentes por dominio (fuera de alcance; ver `proposal.md`).
- V9 — auditoría Creator Store de `roblox-18` (verificado sin tasas DevEx; sin edición).
- V20/V21 — límites numéricos de rate de remotos (no verificados; correctamente sin publicar).
- V24/V27 — formatos del importador / Scale Unit.
- S-01 — renombre opcional del slug `audio-limiter-ducking-compression` (regla 606 de `roblox-35`).
- Backfill editorial de dominios compactos 01-13.
- skillsGV — scoping de targets externos del validador (handoff).

## Rollback

- **Archivo/promoción:** revertir = devolver `openspec/changes/archive/2026-09-13-raase-catalog-improvements/` → `openspec/changes/raase-catalog-improvements/`, revertir la promoción de las 5 specs baseline y restaurar `openspec/specs/.gitkeep` (vía revert del commit de cierre).
- **Ediciones de código** (por archivo, `git checkout -- <ruta>`; nunca `git checkout -- .`):
  - WU1: `skills-roblox/roblox-09-economy-devex/SKILL.md`
  - WU2: `skills-roblox/roblox-04-3d-world-csg/SKILL.md`, `skills-roblox/roblox-36-asset-pipeline/SKILL.md`
  - WU3: `skills-roblox/roblox-07-audio-dsp/SKILL.md`, `skills-roblox/roblox-35-dynamic-audio-music/SKILL.md`
  - WU4: `skills-roblox/roblox-02-netsec/SKILL.md`

## Evidencia mecánica del archivo

- **Promoción:** 5/5 `git diff --no-index` vacíos (exit 0) + SHA256 idénticos; diff agregado `changes/.../specs/` vs `openspec/specs/` vacío (exit 0).
- **Movimiento:** snapshot pre-move de 12 archivos; `git mv` exit 0; readback snapshot vs carpeta archivada **vacío** (exit 0) — sin truncamiento ni alteración de bytes.
- **Sin deltas destructivos** (regla `archive` de `openspec/config.yaml`): la promoción crea baseline, no mergea ni elimina requirements.
