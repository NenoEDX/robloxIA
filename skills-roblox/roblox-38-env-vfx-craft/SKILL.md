---
name: roblox-38-env-vfx-craft
description: "Rige la calidad artesanal del VFX ambiental — extensión RAASE 2.1 (no registrada en raase_skills.json, como roblox-engineer). Define el principio de CAPAS (núcleo + cuerpo + secundarias + luz + sonido + timing) y las RECETAS completas para los efectos ambientales más pedidos: antorcha/fuego (la receta de referencia), cascada/agua viva, pórtico mágico, velas y brasas, lluvia/nieve/niebla y magia del mundo — cada una con configuración exacta de ParticleEmitters, curvas de calor ColorSequence, flicker de luz por script compartido y layering de sonido. Integra los flipbooks de roblox-36, los presupuestos de roblox-25 y las puertas de calidad de 2 pases (RN-11). Úsala cuando el pedido sea 'ponele VFX a X' (antorchas, cascadas, portales, clima) y el resultado deba verse PINTADO y con vida — no como un emisor genérico."
license: MIT
allowed-tools: Read Write Bash(node:*,blender:*)
metadata:
  domain: "Environmental VFX & Craft"
  author: "RAASE 2.1 / robloxIA"
  range: "no registrada (extensión, como roblox-engineer)"
---

# roblox-38-env-vfx-craft — VFX Ambiental de Calidad (Recetas)

Este módulo enseña el **oficio**: que un fuego se vea como fuego pintado y no como un emisor genérico. La diferencia entre "efecto" y "VFX bonito" no es más partículas — es **capas, curvas y respiración**. Acá están las recetas exactas.

## Principio de Capas (todo efecto ambiental de calidad)

```
1. NÚCLEO      → el corazón del brillo (partícula chica, LightEmission 1)
2. CUERPO      → el movimiento principal (flipbook roblox-36 o sprites)
3. SECUNDARIAS → brasas, chispas, humo, mist (profundidad y detalle premium)
4. LUZ         → PointLight con FLICKER irregular (la luz reacciona al efecto)
5. SONIDO      → capa base + capa detalle, espacializado (roblox-07)
6. TIMING      → NADA en loop perfecto: la irregularidad es la "vida"
```

## Receta A — Antorcha / Fuego (la referencia)

| Capa | Configuración |
|---|---|
| **Núcleo** | ParticleEmitter: `Rate 20`, `Lifetime 0.2–0.3`, `Size 0.4→0.6`, `LightEmission 1`, color `#FFE8A3` plano, `Speed 0.5` |
| **Llama** | `Rate 14`, `Lifetime 0.7–1.1`, `Speed 1–2`, `Rotation ±20`, `RotSpeed ±15`, `Drag 1.5` |
| **Curva de calor (ColorSequence)** | `0.0 #FFF3C4` → `0.25 #FFC24B` → `0.55 #FF7A1A` → `0.8 #C93A00` → `1.0 #3A0A00` |
| **Transparencia (NumberSequence)** | `0 → 0 → 0.15 → 0.6 → 1` (se apaga al final, nunca corta) |
| **Tamaño (NumberSequence)** | `0 → 0.7` · `0.3 → 1.0` · `1.0 → 0.3` (crece y se desvanece) |
| **Brasas** | `Rate 3`, `Speed 2–3`, `Acceleration (0, 4, 0)`, `Lifetime 1.5–2.5`, color `#FFB347 → #FF3D00`, tamaño `0.1 → 0.02` |
| **Humo** | `Rate 1.5`, `Speed 1`, `Lifetime 2–3`, color `#555555 → #222222`, tamaño `0.5 → 1.5`, `RotSpeed` lento |
| **Luz** | PointLight `Color3.fromRGB(255, 140, 60)`, `Brightness ~1.5`, `Range ~12` + **flicker por script** (ver abajo) |
| **Sonido** | loop de fogata (base) + crackles esporádicos (detalle) |

**Flicker compartido (1 script para N luces — NUNCA un script por antorcha):**

```luau
--!strict
-- Registrá cada luz con un seed único: light:SetAttribute("raaseSeed", n)
local flickerLights: { PointLight } = {} -- llenar al construir las antorchas

game:GetService("RunService").Heartbeat:Connect(function()
	local t = os.clock()
	for _, light in flickerLights do
		if light.Parent == nil then
			continue
		end
		local seed = light:GetAttribute("raaseSeed") or 0
		-- math.noise: irregular > cualquier senoidal — esto es lo que "respira"
		light.Brightness = 1.5 + math.noise(seed, t * 2.3) * 0.45
		light.Range = 12 + math.noise(seed + 50, t * 1.7) * 2
	end
end)
```

**Presupuesto por antorcha:** ≤ 4 emisores + 1 luz + 2 sonidos. Para 30 antorchas: LOD por distancia obligatorio (apagar brasas/humo/luz fuera de rango — cf. roblox-11/25).

## Receta B — Cascada / Agua viva
- Núcleo blanco-cian (`#E8FBFF`) con LightEmission alto SOLO en la espuma + cuerpo con flipbook opcional (roblox-36).
- Mist en la base (partículas grandes translúcidas, `Lifetime 1–2`), splash ocasional.
- La luz del sol/generada debe reflejarse: usar `PointLight` cian tenue cerca del agua.
- Anti-neón: el agua NO usa material Neon — el brillo va en las partículas/espuma.

## Receta C — Pórtico mágico
- Core glow pulsante (`Brightness` con noise lento) + partículas en espiral (usar `Acceleration` tangencial o `Velocity` en cono).
- Runas/glyphs: UI o meshes (roblox-36) con `LightEmission` + `Transparency` animada.
- Humo de fondo + sonido de zumbido con capa de "whoosh" al activarse.

## Receta D — Clima
- **Lluvia**: emisor global de streaks finitos + splash particles en superficies; truenos = flash de `Lighting` + sonido con delay calculado (velocidad del sonido ≈ percepción).
- **Nieve**: `Lifetime` largo, caída con `Acceleration` suave + deriva por noise; tamaño 2-3 variantes.
- **Niebla**: `Atmosphere.Density` + emisores de niebla baja (billboards grandes, `Speed` casi 0, transparencia alta).

## Receta E — Velas / Brasas / Lámparas
- Micro-recetas de 1–2 emisores + luz compartida por el MISMO gestor de flicker (nunca luces con script propio).
- Vela: núcleo + llama chica (colores más pálidos), sin humo salvo al apagarse.

## Reglas de Craft (inviolables)

1. **Todo fuego respira**: flicker irregular por `math.noise`; un loop perfecto = efecto muerto.
2. **Curva de calor, nunca color plano**: la llama va de blanco cálido a rojo oscuro.
3. **Las secundarias son el sabor**: brasas/humo son ocasionales, no constantes.
4. **LOD por distancia** para props repetidos (30 antorchas ≠ 30× el costo).
5. **Anti-Neón bien entendido**: la Directiva Anti-Neón prohíbe Neon en superficies/fluidos estructurales; el brillo de VFX usa `LightEmission` y luces sobre partículas — no material Neon en geometría visible.
6. **Audio siempre layerado** (base + detalle) y espacializado (roblox-07/35).
7. **Móvil**: flipbooks a Grid4x4, brasas/humo off, `Range` reducido, LOD más agresivo (roblox-25).

## Puertas de Calidad (RN-11 — 2 pases)

1. Captura del prop EN PENUMBRA (es donde se ve el fuego real) → ¿se lee como fuego? ¿ilumina las superficies alrededor? ¿respira?
2. Un único paquete de micro-ajustes → captura de verificación. PARAR.

Checklist de aprobación: color de llama correcto en oscuridad (nunca saturado), flicker visible pero no mareante, la luz afecta el entorno, sonido sincronizado, **cero loops evidentes**.

## Integración con el catálogo

- **roblox-13** (fundación de partículas/beams/trails) → esta skill agrega el oficio encima.
- **roblox-36** (flipbooks) → opción premium para las llamas y el agua.
- **roblox-04** (iluminación/Atmosphere) y **roblox-35/07** (audio) → capas 4 y 5.
- **roblox-25** (presupuestos por plataforma) y **roblox-11** (LOD de escenarios).
- **roblox-37** (combat juice) → compañera: combate para impactos, ésta para ambientes.
