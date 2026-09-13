---
name: roblox-37-vfx-combat-pipeline
description: "Rige el diseño y la implementación del sistema de VFX de combate de alta fidelidad (estilo fighting-game) — extensión RAASE 2.1 (no registrada en raase_skills.json, como roblox-engineer). Define la receta del 'juice' de impacto (hitstop de 2-6 frames, FOV punch, camera shake por curvas, impact frames de UI y speed lines), emisores flipbook de partículas para explosiones e impacts, meshes aditivos de vida corta para slashes y ondas de choque, y el secuenciador por habilidad sincronizado con el Animator. Integra la cadena de assets (flipbooks vía roblox-36), los presupuestos por impacto y las puertas de calidad visual de 2 pases (RN-11). Úsala al construir combate cuerpo a cuerpo, habilidades mágicas, golpes de área o cualquier impacto que deba sentirse 'pesado' — peleas de anime, campos de batalla, hunt y oleadas."
license: MIT
allowed-tools: Read Write Bash(node:*,blender:*)
metadata:
  domain: "Combat VFX & Game Feel"
  author: "RAASE 2.1 / robloxIA"
  range: "no registrada (extensión, como roblox-engineer)"
---

# roblox-37-vfx-combat-pipeline — VFX de Combate Estilo Fighting-Game

Este módulo rige el "juice" de combate: la capa de efectos que hace que un golpe **se sienta pesado**. Cubre desde un impacto individual (secuenciador + camera juice + flipbook) hasta la receta replicable para 30 habilidades. La referencia de calidad objetivo: fighting-games de Roblox de primer nivel (anime fighters, battlegrounds).

## La Receta del Impacto (timeline a 60 FPS)

| t (frames) | Capa | Implementación |
|---|---|---|
| 0 | **Hitstop** | Congelar animaciones (`Animator` tracks → `AdjustSpeed(0)`) y locomoción del personaje 2-6 frames. El "peso" nace acá |
| 0-1 | **Flash aditivo** | Mesh/parte efímera (Neon) en el punto de contacto, vida ≤ 0.1s |
| 1-3 | **Impact frame (UI)** | ImageLabel full-screen (imagen IA) visible 1-2 frames — efecto cómic/anime (GUI no tiene blend aditivo nativo: se simula con transparencia) |
| 2-14 | **Flipbook de impacto** | `ParticleEmitter` con `FlipbookLayout` reproduciendo el atlas generado por roblox-36 |
| 3-20 | **Camera juice** | FOV punch (FOV actual +N° → restaura), shake por `math.noise`, micro-zoom al atacante |
| 4-30 | **Partículas secundarias** | Sparks, escombros, humo — presupuesto por impacto (ver abajo) |
| 6-24 | **SFX layering** | Impacto + whoosh + silencio de 0.05-0.1s (contraste) — roblox-07/35 |

Regla: si el golpe no tiene hitstop, no importa cuántos efectos le agregues — va a sentirse "de papel".

## Emisores Flipbook (el 70% del look)

- Textura: atlas sprite-sheet generado por **roblox-36** (Blender render batch) o pack con licencia.
- Configuración base del `ParticleEmitter`:
  - `FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4` (o `Grid8x8` para efectos largos)
  - `FlipbookFramerate = NumberRange.new(24, 30)`
  - `FlipbookStartRandom = false` (los impacts deben arrancar en frame 0)
- Regla: **1 emisor flipbook por efecto**; no superponer 4 emisores de explosión (el look se ensucia y explota el presupuesto).
- Configuración de la referencia: `FlipbookMode.OneShot`, `Speed = 0`, `Lifetime ≈ frames/fps` (16 frames ≈ 0.7 s a 24 fps — un `Lifetime` menor **trunca la animación**).
- Beams/Trails para slashes (roblox-13); el flipbook es para explosiones, polvo, humo y magia.

## Meshes Aditivos de Vida Corta

- Slash arcs, ondas de choque, anillos: `MeshPart` (o Part + SpecialMesh) con material `Neon`, `Anchored`, vida 0.05-0.3s.
- Nunca crear/destruir en el pico del combate: **pooling con PartCache** (roblox-08). La referencia v1 usa pools ligeros internos (reuso por asset); en producción a escala, migrar a PartCache.
- El mesh del slash se fabrica en Blender (arcos procedurales = fácil) vía roblox-36.

## Camera Juice (el "director de combate")

- **FOV punch**: `Camera.FieldOfView` con `TweenService` (curva `Enum.EasingStyle.Quad` out) — captura el FOV actual y lo restaura (jamás hardcodear 70); solo golpes fuertes, jamás en cada hit (fatiga visual).
- **Shake**: `math.noise` como offset de rotación por frame en `RunService.PreRender` (aplica y quita el offset — sin acumulación ni drift); amplitud por tabla de intensidad (light/heavy/ultimate).
- **Hitstop de cámara**: 1-2 frames de freeze total opcional para ultimates.
- Implementación de referencia: `scripts/impact_sequencer.luau`.

## Impact Frames y Speed Lines (UI)

- Impact frames: imágenes generadas por IA (nano-banana — skillsGV) o packs; ImageLabel full-screen con transparencia + toggle de visibilidad; **1-2 frames máximo**.
- Speed lines: radiales, 0.1-0.2s, solo en dash/ultimate.
- Concentración: máximo 1 impact frame por segundo — el efecto pierde fuerza si se repite.

## Secuenciador por Habilidad

Patrón: una tabla de timeline por habilidad, **disparada por el marcador de la animación** (`track:GetMarkerReachedSignal("Hit")`) o por el evento de daño confirmado en servidor; dentro del impacto los delays son post-disparo (sin `wait` sueltos por fuera del timeline):

```luau
--!strict
-- Ver scripts/impact_sequencer.luau para la implementación completa de referencia.
local ImpactSequencer = require(script.ImpactSequencer)

ImpactSequencer.play({
    hitstopFrames = 4,          -- 2 = jab, 4 = heavy, 6 = ultimate
    fovPunch = 8,               -- grados de FOV (0 = sin punch)
    shake = "heavy",            -- "light" | "heavy" | "ultimate"
    impactFrame = "rbxassetid://IMPACT_FRAME_ASSET",
    flipbook = "rbxassetid://IMPACT_ATLAS_4X4",
    flipbookFrames = 16, -- 4 | 16 | 64 (Grid2x2/Grid4x4/Grid8x8)
    meshFlash = "rbxassetid://SLASH_ARC_MESH",
    sound = "rbxassetid://IMPACT_SFX",
    position = hitCFrame,
})
```

Los IDs de assets se reemplazan por los generados/importados vía roblox-36. Colocación del módulo: `StarterPlayerScripts` (una instancia por cliente; evita duplicar pools/GUI por respawn).

## Presupuestos por Impacto (roblox-25)

| Recurso | Presupuesto |
|---|---|
| Partículas simultáneas por impacto | ≤ 3 emisores activos |
| VFX concurrentes en pantalla (batalla de 10 NPCs) | ≤ 24 partículas pesadas / segundo total |
| Meshes efímeros | ≤ 6 por impacto, vía pool |
| Impact frames | ≤ 1 por segundo, ≤ 2 frames visible |
| Degradación móvil | hitstop SÍ (es gratis), flipbooks a Grid4x4, shake 50%, impact frames off (el switch no está en el script v1 — se implementa por juego según DeviceTier) |

## Puertas de Calidad (RN-11)

1. Capturar el impacto en Studio (POST /api/capture) en 2 pases: pase 1 identifica (¿se lee el golpe? ¿el flash tapa la acción?), pase 2 confirma el ajuste. **Máximo 2 pases, sin bucles.**
2. Checklist de "feel" antes de aprobar una habilidad:
   - ¿El hitstop se siente sin exagerar? (2-6 frames)
   - ¿El impacto se lee a 720p móvil? (el flipbook debe legible en pantalla chica)
   - ¿El sonido tiene contraste (silencio antes del impacto)?
   - ¿La cámara acompaña sin marear? (shake corto, FOV sutil)
3. Una habilidad aprobada = **plantilla replicable**: misma estructura para las siguientes 29.

## Integración con el catálogo

- **roblox-36** (asset-pipeline): fabrica los flipbooks (Blender) y los meshes de slash.
- **roblox-13 / roblox-35**: partículas base (no-flipbook), beams, layers de audio.
- **roblox-08**: pooling (PartCache) obligatorio para meshes efímeros.
- **roblox-22**: cámara base; esta skill agrega el juice de combate encima.
- **roblox-31**: hitboxes y daño — el impacto visual se dispara desde el evento de daño confirmado en servidor.
- **roblox-07**: SFX layering y ducking.
