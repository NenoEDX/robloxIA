---
name: roblox-36-asset-pipeline
description: "Rige la adquisición y fabricación de assets que el motor no puede expresar con primitivas — extensión RAASE 2.1 (no registrada en raase_skills.json, como roblox-engineer). Define: criterios de decisión entre Blender headless, marketplace con licencia, generación de imágenes (impact frames/texturas) y geometría de motor; el manifiesto de assets por lote; la generación batch con Blender (GLB + previews + reporte de handoff); el protocolo de aviso al creador para importación manual en Studio; y la verificación post-import vía Companion Plugin (escala, orientación, colisión, presupuesto de triángulos). Úsala cuando el diseño requiera mallas, texturas animadas (flipbooks) o rigs originales, o cuando debas decidir si un asset se fabrica, se compra o se reemplaza por geometría del motor."
license: MIT
allowed-tools: Read Write Bash(node:*,blender:*,python:*)
allows-script-exec: "run_batch.mjs ejecuta Blender headless (blender --background) para fabricar assets por lote — herramienta local del creador, sin red"
metadata:
  domain: "Asset Pipeline & External Tooling"
  author: "RAASE 2.1 / robloxIA"
  range: "no registrada (extensión, como roblox-engineer)"
---

# roblox-36-asset-pipeline — Pipeline de Assets Externos (Blender → Studio)

Este módulo rige el eslabón que el motor no cubre: fabricar los assets que **no se pueden expresar con primitivas, CSG ni partículas** — mallas originales, texturas flipbook de VFX, rigs y variantes detalladas. El agente decide, fabrica con Blender headless, y entrega un lote listo para que el **creador humano lo importe en Studio**. La verificación post-import es automática.

## Criterio de Decisión: ¿de dónde sale el asset?

| Necesidad | Fuente | Herramienta | Notas |
|---|---|---|---|
| Geometría imposible con primitivas/CSG (orgánicas, siluetas únicas, armas curvas, criaturas estilizadas) | **Fabricar** | Blender headless (`bpy`) | El caso principal de esta skill |
| Texturas de VFX animadas (flipbooks de impacto/explosión/magia) | **Fabricar** | Blender render batch → atlas de frames | EmberGen es el paso "pro" opcional de la industria |
| Impact frames, speed lines, UI art, texturas estáticas | **Generar** | Generación de imagen IA (nano-banana — skillsGV) | Un frame por vez; consistencia limitada para secuencias |
| Props modulares, escenarios, arquitectura, interiores | **Motor** | roblox-12 (model-maker) + CSGv3 | No gastar Blender en lo que las primitivas ya hacen bien |
| VFX de partículas, beams, trails, luces | **Motor** | roblox-13 / roblox-35 | Roblox no acepta VFX exportado: se re-autora in-engine |
| Orgánicos AAA (caras, criaturas detalladas) y actuación animada | **Humano/Marketplace** | Artista o Creator Store (licencia verificada) | Techo real del pipeline automatizado |
| Rigs y animaciones detalladas | **Fabricar (media)** o humano | Blender / Animation Editor | Lo scripted se nota; validar expectativa con el creador |

## Flujo Operativo (6 pasos)

### 1. Manifiesto de assets (acumulación, no disparo por asset)
Durante planificación o construcción, el agente acumula cada necesidad en `exports/<lote>/assets_manifest.json`. **Nunca se dispara Blender asset por asset** — se agrupa por lote lógico (ej: "sistema de combate", "bioma helado").

```json
{
  "batch": "combat-system",
  "assets": [
    {
      "id": "mesh_sword_ember",
      "nombre": "Espada Ember",
      "tipo": "mesh",
      "rol": "Arma equipable del jugador",
      "dimensionesStuds": [0.5, 5.5, 0.8],
      "triBudget": 4000,
      "estilo": "fantasía oscura, low-poly con bevels",
      "destino": "ReplicatedStorage.Assets.Weapons",
      "prioridad": "alta"
    }
  ]
}
```

### 2. Punto de corte y AVISO al creador
Cuando el manifiesto cierra un lote, el agente **pausa y notifica**:

```
🧊 PIPELINE DE ASSETS — Lote listo: "combat-system"
Assets requeridos: 7 (4 mallas, 2 flipbooks, 1 rig)
Blender: detectado ✅ (v4.x) — o "no detectado ⚠️" + instrucciones
Acción: confirmá la generación (o ajustá prioridades) y la fabrico por lote.
Al terminar: GLBs + previews en exports/combat-system/ + instrucciones de import.
```

Si el lote fue pre-aprobado por el creador, se salta la confirmación y se informa al terminar. La aprobación debe quedar **registrada en el manifiesto** (`approvedAt` + `approvedBy`). Si el creador no responde: **un** recordatorio; el lote queda EN PAUSA (no se fabrica nada) y el agente continúa con otras tareas del proyecto.

### 3. Verificación de Blender (con degradación)
- Detectar: `$BLENDER_BIN --version` si la variable está definida, si no `blender --version` (PATH).
- **Si NO hay Blender**: **RECOMENDAR instalarlo** (Blender.org, gratis, ~300 MB — desbloquea la fabricación local completa de mallas y flipbooks) y ofrecer las dos salidas: instalar en esta PC, o generar igual los scripts `.py` + manifiesto + `ASSETS_HANDOFF.md` para correrlos en otra PC (`node scripts/run_batch.mjs --dry-run` imprime los comandos exactos). **Jamás fabricar un sustituto silencioso.**

### 4. Generación batch (Blender headless)
- Runner: `node scripts/run_batch.mjs --manifest assets_manifest.json --out exports/<lote>/` (usa `$BLENDER_BIN` o `--blender <ruta>`; `--dry-run` no ejecuta).
- El runner mapea el manifiesto a las plantillas: meshes → `blender_export_example.py` (escala calculada de `dimensionesStuds`), flipbooks → `blender_flipbook_example.py` (frames 4/16/64, atlas ≤1024).
- Si un asset necesita geometría propia, el agente escribe un script dedicado tomando la plantilla como base (mismo contrato de salida).
- El runner usa `--python-exit-code 1` y **verifica el artefacto** antes de marcar `generado` (un script Python fallido ya no pasa como éxito) y aísla los frames de cada flipbook en `<out>/<id>/` (sin colisión entre assets).
- Salida por asset: mesh → `<id>.glb` + `<id>_preview.png`; flipbook → `frames/*.png` RGBA; siempre la línea de log `[RAASE]` con tri count o frames.

### 5. Handoff al creador (importación manual — el paso humano)
`exports/<lote>/ASSETS_HANDOFF.md` (lo genera `run_batch.mjs`; plantilla en `scripts/ASSETS_HANDOFF.template.md`) lista por asset según su tipo:
- **Mesh**: `<id>.glb` + `<id>_preview.png` + dimensiones objetivo en studs + CollisionFidelity sugerida (`Box` para props, `Hull` para armas, `PreciseConvexDecomposition` solo si hace falta).
- **Flipbook**: `<id>/frames/*.png` → empaquetar atlas (≤1024 px) → **subir a Roblox como Texture** y usar el `rbxassetid://` en el `ParticleEmitter` (declarar `flipbookFrames` 4/16/64 en el secuenciador).
- **Destino en el juego** (ej: `ReplicatedStorage.Assets.Weapons`) e instrucciones de import:
  - Studio → **3D Importer** → **Scale Unit = Meter** (el default *Stud* produce ~3.57× de diferencia; el flujo asume 1 stud ≈ 0.28 m).
  - Si el importer rechaza `.glb`, re-exportar como `.gltf` (`--format GLTF_SEPARATE` en la plantilla) — misma geometría.
  - Aplicar escala y collision → registrar cada `rbxassetid://` en el manifiesto → **avisar "LISTO"**.
- **Requisitos de exportación verificados** (confirmar antes de importar):
  - Transform congelado (`scale (1,1,1)`, `rot (0,0,0)`) y root en `(0,0,0)`.
  - Máx. 4 influencias por vértice, sin influencias al root.
  - Un solo track de animación por export.
  - Cages `_InnerCage` / `_OuterCage`.
  - Geometría watertight, sin N-gons, sin grosor 0.

### 6. Verificación post-import (automática vía Companion Plugin — alcance REAL)
Cuando el creador confirma, el agente verifica **cada** mesh con `INSPECT_OBJECT` sobre los campos que el plugin realmente expone:
- Escala y proporción: `size` real vs dimensiones objetivo del manifiesto (±5%).
- Posición y orientación: `position`/`cframe` en el destino correcto.
- Colisión: `CanCollide` (inspeccionable y corregible); `Massless` es corregible por RPC pero **no** reportado por `INSPECT_OBJECT`.
- **Tri count y CollisionFidelity NO son inspeccionables por RPC** (deuda conocida del plugin, ver Limitaciones): el creador los confirma desde el editor con el checklist del `ASSETS_HANDOFF.md`.
Correcciones vía `MODIFY_OBJECT` limitadas a la whitelist real del plugin (incluye `Name`, `Size`, `CFrame`, `Position`, `Color`, `Material`, `Transparency`, `Reflectance`, `Anchored`, `CanCollide`, `CanTouch`, `CanQuery`, `Massless`, `CastShadow`); el resto → devolver al creador con el detalle exacto. **Importar nunca es por RPC.**

## Reglas Inviolables

1. **Licencia primero**: marketplace solo con licencia verificada y atribución si aplica; assets generados por IA según ToS de la herramienta; prohibido material de origen dudoso.
2. **Presupuesto antes de fabricar**: props ≤ 5,000 tris; héroes/armas ≤ 20,000 (tope oficial por mesh individual; alineado con roblox-04); flipbooks: atlas **≤ 1,024 px** (cuadrado potencia de dos — Grid4x4 con frames ≤256 px, Grid8x8 con frames ≤128 px). Ajustar por plataforma (roblox-25).
3. **Naming determinista**: `<tipo>_<nombre>_<variante>` (`mesh_sword_ember`, `tex_impact_fire_4x4`). Carpetas `exports/<lote>/`.
4. **RN-10 aplica a los meshes**: los meshes que el creador puso por su cuenta son **intocables** — la verificación reporta, no reemplaza. Los assets **de este lote** (fabricados a pedido y entregados por el creador) SÍ pueden reposicionarse/escalarse por RPC dentro de la whitelist, siempre coordinado con él.
5. **Nada de assets sin verificación**: cada asset entra al handoff solo con su artefacto de verificación según tipo (mesh: preview + tri count en log; flipbook: frames RGBA + atlas; rig: GLB + preview).
6. **El paso humano es obligatorio en el estado actual del motor** (no existe API de scripting para importar mallas): el agente no lo simula ni lo saltea.

## Limitaciones conocidas (v1 — deuda declarada)

- **Tri count y CollisionFidelity no son inspeccionables por RPC**: el plugin actual no los expone en `INSPECT_OBJECT` ni los permite mutar en `MODIFY_OBJECT`. La verificación automática cubre escala/posición/colisión/masa; esos dos campos los confirma el creador desde el editor (checklist del handoff).
- **Rigs (v1)**: la fabricación de rigs con Blender es manual-asistida (la plantilla de v0 cubre meshes y flipbooks).
- **Empaquetado de atlas**: `blender_flipbook_example.py` deja los frames; el atlas se arma con ImageMagick (`magick montage`) o cualquier packer de PNGs cuadrados potencia de dos.
- **EEVEE requiere GPU/GL**: en máquinas headless sin GPU, correr el lote en otra PC (la degradación de la skill lo cubre).

## Integración con el catálogo

- **roblox-12** (model-maker): ensamblado modular in-engine — probar primero si el asset se logra sin Blender.
- **roblox-13 / roblox-35** (VFX): consumidores de los flipbooks generados aquí.
- **roblox-29** (animación): rigs y retargeting de lo importado.
- **roblox-25** (performance): presupuestos por plataforma.
- **roblox-10** (tooling): verificación post-import vía RPC del Companion Plugin.
