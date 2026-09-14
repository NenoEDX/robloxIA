---
name: roblox-12-model-maker
description: "Cubre fabricación de modelos (skills 251-265): micro-ensamblado modular, proporciones arquitectónicas, molduras y bevels, jerarquía limpia de instancias y la Directiva Anti-Neón. Úsala al construir props, edificios o cualquier modelo del mundo que requiera calidad visual con conteo de partes controlado."
license: MIT
allowed-tools: Read Write Bash(node:*,luau-lsp:*,rojo:*,wally:*)
metadata:
  domain: "Model Making & Modular Assembly"
  range: "251-265"
  author: "RAASE 2.1 / robloxIA"
---

# roblox-12-model-maker — Model Making y Ensamblado Modular (Skills 251 - 265)

Este módulo rige el modelado estructural de props, mobiliario, edificaciones modulares y composiciones geométricas en Roblox Studio bajo estrictos estándares estéticos y mecánicos.

## Catálogo de Habilidades Técnicas

### 251. `model-primarypart-bounding-pivot`
- **Regla:** Todo `Model` instanciado DEBE tener asignada una `PrimaryPart`.
- **Estándar:** El pivote de la `PrimaryPart` debe posicionarse en la base inferior central del modelo (`Y = 0` relativo) para garantizar que llamadas a `model:PivotTo(cf)` descansen exactamente sobre la superficie de apoyo sin incrustarse.

```luau
--!strict
local function finalizeModel(model: Model, basePart: BasePart)
    model.PrimaryPart = basePart
    -- Alinear pivote en la base inferior
    local cf, size = model:GetBoundingBox()
    local bottomCenter = cf.Position - Vector3.new(0, size.Y / 2, 0)
    model.WorldPivot = CFrame.new(bottomCenter) * (cf - cf.Position)
end
```

### 252. `model-anchored-root-compliance`
- **Regla:** Toda parte estructural o arquitectónica fija debe nacer con `Anchored = true`. Solo partes con articulaciones físicas (`WeldConstraint`, `HingeConstraint`) pueden ser no ancladas.

### 253. `model-bevel-trim-molding-profile`
- **Regla:** Prohibido dejar muros o marcos como prismas lisos y planos de 90°.
- **Estándar:** Toda pared de altura $\ge 10$ studs debe incorporar:
  1. Rodapié inferior (*baseboard*) de altura 1.2 studs y resalte horizontal de +0.4 studs.
  2. Cornisa o almena superior (*cornice*) con resalte horizontal de +0.5 studs.
  3. Esto rompe la silueta monótona y genera sombras dinámicas ricas bajo tecnología `Future`.

### 254. `model-anti-neon-material-matrix`
- **Regla:** El material `Enum.Material.Neon` queda terminantemente PROHIBIDO para paredes, suelos, agua o props generales. Solo se permite en fuentes emisoras de luz activas (<0.8 studs) o pociones.
- **Sustituciones Obligatorias:**
  - Piedra: `Enum.Material.Cobblestone` (suelos) y `Enum.Material.Slate` (molduras).
  - Madera: `Enum.Material.WoodPlanks` (suelos/cajas) y `Enum.Material.Wood` (vigas).
  - Metal: `Enum.Material.Metal` con tonos oscuros forjados `[42, 45, 50]`.
  - Agua: `Enum.Material.Glass` translúcido o `Terrain:FillBlock(Water)`.

### 255. `model-architectural-proportions-golden`
- **Regla:** Las proporciones de las aberturas deben calibrarse según la escala del avatar R15 (5 studs de alto por 2.5 studs de ancho):
  - Puertas interiores: mínimo 8 studs de alto por 4.5 studs de ancho.
  - Puertas monumentales / portales: mínimo 16 studs de alto por 10 studs de ancho.
  - Altura de techos en interiores habitables: mínimo 12 studs.

### 256. `model-grain-orientation-alignment`
- **Regla:** El veteado de las partes de `Wood` o `WoodPlanks` debe alinearse en la dirección longitudinal del elemento utilizando `CFrame.Angles` para preservar la coherencia física de la madera.

### 257. `model-modular-wall-window-snap-grid`
- **Regla:** Los módulos arquitectónicos repetitivos deben diseñarse en múltiplos exactos de 4 studs (4x12, 8x12, 16x16) para asegurar que el snap en Studio y la generación procedural encajen sin huecos ni desfases milimétricos.

### 258. `model-hierarchical-grouping-hygiene`
- **Regla:** Los modelos complejos deben organizarse internamente en carpetas semánticas:
  - `Model/Geometry`: Partes colisionables fijas.
  - `Model/Decor`: Detalles pequeños con `CanCollide = false`.
  - `Model/Lights`: Puntos de luz y efectos.
  - `Model/VFX`: Emisores de partículas y sonidos.

### 259. `model-massless-decor-welding`
- **Regla:** Accesorios y detalles estéticos soldados a partes móviles deben configurarse con `Massless = true` para no desbalancear el centro de masa de la ensambladura física.

### 260. `model-surface-appearance-pbr-binding`
- **Regla:** Al emplear `MeshPart`, instanciar un objeto `SurfaceAppearance` con modo `AlphaMode.Opaque` o `SurfaceAppearance.AlphaMode.Overlay` e inyectar mapas PBR de resolución adecuada (1024x1024 máx).

### 261. `model-collision-fidelity-hull-box`
- **Regla:** Optimización de colisiones por tipo de malla:
  - Props no interactivos: `CollisionFidelity.Box`.
  - Rocas y columnas redondas: `CollisionFidelity.Hull`.
  - Puertas, arcos y pasajes cóncavos transitables: `CollisionFidelity.PreciseConvexDecomposition`.

### 262. `model-csg-watertight-primitive-slicing`
- **Regla:** Toda sustracción booleana con `GeometryService:SubtractAsync` debe garantizar que el objeto de corte sobresalga ligeramente ($\ge 0.05$ studs) de la superficie para evitar planos microscópicos residuales que causen parpadeo visual (*Z-fighting*).

### 263. `model-sign-heraldry-contrast-ratio`
- **Regla:** Todo cartel informativo (`BillboardGui` o `SurfaceGui`) debe mantener un ratio de contraste de luminancia $\ge 4.5:1$ (WCAG AA). Textos claros sobre marcos oscuros con `UIStroke` semitransparente.

### 264. `model-light-fixture-housing-geometry`
- **Regla:** Ningún `PointLight`, `SpotLight` o `SurfaceLight` puede existir suspendido en el aire. DEBE estar alojado dentro de una geometría modelada visible (soporte de hierro, antorcha con punta negra, candelabro o farol).

### 265. `model-assembly-memory-footprint-cap`
- **Regla:** Un modelo modular reutilizable no debe exceder de 60 partes primitivas individuales. Elementos más complejos deben consolidarse mediante operaciones CSG o `MeshPart`.

### 266. `model-mesh-first-anti-slop-policy`
- **Regla:** Queda terminantemente PROHIBIDO intentar construir vehículos (autos, buses, camiones, tanques), armas, maquinaria detallada, muebles complejos, NPCs/maniquíes o vegetación agrupando bloques primitivos (`Part`, `Wedge`, `Cylinder`).
- **Estándar:** Todo prop complejo DEBE ser una Malla 3D Dedicada (`MeshPart` / archivo `.glb` creado en Blender, Image-to-3D o packs curados). Las partes primitivas se reservan únicamente para suelos planos, aceras, colisiones invisibles y triggers de volumen.

### 267. `model-reference-backed-aesthetic-audit`
- **Regla:** Todo modelo o conjunto arquitectónico debe auditarse comparándolo activamente con una referencia visual del mundo real o concept art AAA antes de darse por terminado.
- **Checklist de Auditoría Estética:**
  1. ¿Escala humana exacta respecto al avatar R15 (5 studs alto x 2.5 ancho)?
  2. ¿Proporciones verosímiles (ruedas simétricas y alineadas al chasis, puertas a escala, techos firmes con soporte estructural real)?
  3. ¿Ausencia de geometrías flotantes o desalineadas?
  4. Si la auditoría con `capture` muestra que el objeto parece un "juguete tosco de bloques" o está fuera de lugar, el agente DEBE descartar los cubos y priorizar la malla 3D dedicada.

### 268. `model-ground-snap-anti-floating`
- **Regla:** Queda terminantemente PROHIBIDO instanciar techos, carteles, muebles, vehículos, maniquíes o escombros suspendidos en el aire sin contacto físico o soporte visible.
- **Estándar de Asentamiento:**
  1. **Ground-Snapping:** Todo objeto en el suelo debe anclar su base calculando `posY = floorY + (sizeY / 2)` o mediante un `Raycast` hacia abajo al instanciarse en Luau. Cero cotas Y arbitrarias a ojo.
  2. **Carteles y Rótulos:** Deben montarse sobre postes fijados al piso o adherirse directamente a la pared (`SurfaceGui` sobre la cara del muro).
  3. **Cubiertas y Techos:** El plano inferior del techo DEBE coincidir milimétricamente con la cota superior de los muros o pilares que lo sustentan.


