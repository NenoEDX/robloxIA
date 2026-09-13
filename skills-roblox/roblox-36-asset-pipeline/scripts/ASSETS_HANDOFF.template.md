# ASSETS_HANDOFF — Lote "<batch>" (PLANTILLA)

> Plantilla de handoff de `roblox-36-asset-pipeline`. `run_batch.mjs` la genera completada en `exports/<lote>/ASSETS_HANDOFF.md`.
> El creador completa la columna de import; el agente completa la verificación post-import.

## Assets

| id | tipo | rol | artefactos | estado |
|---|---|---|---|---|
| `mesh_...` | mesh | ... | `<id>.glb` + `<id>_preview.png` | generado / falló / pendiente |
| `tex_...` | flipbook | ... | `frames/*.png` (+ atlas) | generado / pendiente |

## Pasos del creador (import manual)

1. **Meshes** → Studio → 3D Importer → **Scale Unit = Meter** (el default *Stud* produce ~3.57× de diferencia; el flujo asume 1 stud ≈ 0.28 m).
   - Si el importer rechaza `.glb`: re-exportar con `--format GLTF_SEPARATE` (o FBX) desde la plantilla — misma geometría.
   - CollisionFidelity: `Box` (props) / `Hull` (armas) / `PreciseConvexDecomposition` (solo si hace falta).
2. **Flipbooks** → empaquetar atlas cuadrado potencia de dos (≤1024 px) → subir como **Texture** → copiar el `rbxassetid://`.
3. Registrar cada `rbxassetid://` en la tabla de arriba y avisar **LISTO** al agente.

## Verificación post-import (agente, vía Companion Plugin)

- [ ] Escala: `INSPECT_OBJECT.size` vs dimensiones objetivo (±5%).
- [ ] Posición/orientación correctas en el destino.
- [ ] `CanCollide` / `Massless` según rol (corregibles por `MODIFY_OBJECT`).
- [ ] Tri count y CollisionFidelity: **confirmados por el creador desde el editor** (no inspeccionables por RPC — deuda del plugin).

## Pendientes / notas

- ...
