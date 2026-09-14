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

### 266. `model-dual-doctrine-structures-vs-props`
- **Regla:** Separación arquitectónica estricta entre estructuras y props especializados:
  1. **Estructuras ("Modelos Roblox Normalitos"):** Edificaciones, casas, búnkers, cuartos, muros, torres, escaleras, suelos y techos se construyen mediante **geometría nativa de Roblox (`Part`, `WedgePart`, `CornerWedgePart`, `TrussPart`)** con materiales estándar (`Concrete`, `WoodPlanks`, `Brick`, `CorrodedMetal`, `Fabric`). Los bloques se limitan EXCLUSIVAMENTE a cimientos, suelos, muros, columnas y **A LO MUCHO TEJADOS**.
  2. **Cero Decoración con Bloques (NADA DE NADA):** Queda TERMINANTEMENTE PROHIBIDO usar bloques primitivos de Roblox para cualquier tipo de decoración, muebles o accesorios (prohibidos barriles, cajas, letreros o muebles hechos de bloques).
  3. **Decoración Interior y Props Complejos Modelados por Separado:** Si una estructura contiene elementos complejos o decoración interior (mesas, sillas, camas, estantes, terminales, lámparas, adornos, tuberías), **CADA COSA DEBE MODELARSE POR SEPARADO** como Malla 3D Dedicada (`MeshPart` / `.glb` con Vertex Colors o multi-pieza), jamás como partes de bloques integradas a la pared.
  4. **Props Especializados ("Mesh-First"):** Vehículos, armas, maquinaria, cofres, generadores, reliquias y NPCs DEBEN ser mallas 3D dedicadas (`MeshPart` / `.glb` de Blender, Image-to-3D o packs curados). Queda prohibido el "slop de cubos" para estos elementos.

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

### 269. `model-3d-color-fidelity-pipeline`
- **Regla:** Todo modelo 3D especializado DEBE nacer con coloración visual completa; prohibido el gris monocromático por defecto (`Medium stone grey`).
- **Técnicas de Coloración Obligatorias:**
  1. **Vertex Colors en Blender (.glb):** Al modelar en Blender, asignar atributos de color (`mesh.color_attributes.new("Color")`). Al exportar a `.glb`, Roblox Studio renderiza los colores de vértice automáticamente sin necesidad de cargar texturas de imagen externas.
  2. **Jerarquía Multi-MeshPart:** Ensamblar el modelo con sub-partes semánticas (`Body`, `Tires`, `Glass`, `Lights`), aplicando a cada una su `Color3.fromRGB` y `Material` nativo (`Metal`, `SmoothPlastic`, `Glass`, `Neon`).
  3. **Mapas PBR (`SurfaceAppearance`):** Inyectar `ColorMap` para props con textura UV horneada o generada por IA.

### 270. `model-specialized-vfx-effects-bundle`
- **Regla:** Todo prop especializado nuevo debe integrar su paquete de efectos visuales (VFX Bundle):
  1. **Partículas (`ParticleEmitter`):** Humo, chispas, llamas o auras energéticas configuradas con curvas suaves de `NumberSequence` (Skill 266 de VFX).
  2. **Iluminación Dinámica (`PointLight` / `SpotLight`):** Alojada dentro del foco o núcleo con `Shadows = true`, brillo entre 1.5 y 2.6, y rango acotado al área de influencia.
  3. **Acentos Emisivos (`Neon`):** Elementos clave (indicadores, filamentos, runas, faros) configurados en `Enum.Material.Neon` para emisión de luz nativa en post-procesado Bloom.
  4. **Interactividad:** Si el objeto es interactivo o un punto de interés, incluir `ProximityPrompt` con `Highlight` o sonido 3D posicional en bucle.

### 271. `model-exhaustive-geometry-taxonomy`
- **Regla:** Clasificación estricta y sin ambigüedad entre Geometría Nativa de Roblox y Mallas 3D Especializadas:
  - **ZONA A: EXCLUSIVO PARA BLOQUES ROBLOX (`Part`, `WedgePart`):**
    1. Cimientos y losas de suelo estructurales (asfalto de calles, veredas base, suelos de tierra/concreto).
    2. Muros perimetrales, muros de carga y divisiones de habitaciones principales.
    3. Pilares y columnas portantes simples (cuadrados o rectangulares).
    4. Huecos limpios para aberturas de puertas y ventanas (los vanos arquitectónicos).
    5. Escalones base (huella y contrahuella) con cuña invisible de colisión suave.
    6. Cubiertas y tejados básicos (losas planas y faldas inclinadas de cuña).
    7. Volúmenes invisibles (`Transparency = 1`): zonas de trigger, cajas de colisión AABB y barreras de mapa.
  - **ZONA B: OBLIGATORIAMENTE MALLAS 3D DEDICADAS (`MeshPart` / `.glb` con colores horneados y modeladas por separado):**
    1. **Cercas, Vallas y Delimitadores:** Alambradas de púas, cercas de alambre tejido (*chainlink*), vallas de madera rústicas o de estacas, rejas de hierro forjado con barrotes ornamentados, barandillas/pasamanos de escaleras o balcones, vallas peatonales de control, barreras Jersey con roturas y marcas de desgaste.
    2. **Mobiliario (Interior y Exterior, Cada Uno por Separado):** Sillas, sofás, bancos, taburetes, mesas, escritorios, mostradores, estanterías, libreros, casilleros metálicos (*lockers*), camas, literas, colchones con arrugas, armarios y cómodas.
    3. **Infraestructura Urbana e Industrial:** Postes de luz pública con brazos curvos, semáforos, tuberías con codos curvos y válvulas, ductos y rejillas de ventilación (*HVAC*), transformadores, generadores diésel, paneles solares, hidrantes, contenedores de basura (*dumpsters*), palets de madera con clavos y textura, barriles con rebordes y estrías.
    4. **Vehículos y Movilidad:** Todo auto, camión, bus, tanque, moto, bicicleta, carretilla, barco o avión (incluyendo chasis quemados, ruedas sueltas y neumáticos pinchados).
    5. **Armamento, Herramientas e Interactivos:** Fusiles, pistolas, espadas, bates, hachas, llaves inglesas, palancas (*crowbars*), cofres de botín, cajas fuertes, cajas de munición, botiquines médicos, consolas de terminal y tableros de control.
    6. **Vegetación y Naturaleza:** Árboles orgánicos completos (tronco con corteza y ramas, copas con volumen), troncos caídos astillados, raíces retorcidas, rocas angulares o cantos rodados con facetas, arbustos y enredaderas.
    7. **Escombros y Desorden (Clutter de Suelo):** Pilas de escombros de concreto con varillas de hierro dobladas, sacos de arena con pliegues y costuras, cajas de cartón arrugadas, tablones rotos, latas y botellas rotas.
    8. **Iluminación Ornamental y Fuego:** Antorchas medievales de hierro para pared, candelabros, faroles industriales colgantes, hogueras de campamento con leños 3D entrecruzados.
    9. **Elementos de Detalle Arquitectónico:** Marcos de puertas y ventanas con moldura en relieve, manijas de puerta, bisagras, rejas de ventanas, cornisas decorativas complejas.

### 272. `model-anti-slop-prohibitions-catalog`
- **Regla:** Catálogo de los 10 anti-patrones de modelado con cubos estrictamente PROHIBIDOS para la IA:
  1. *Anti-patrón "Valla de Palitos":* Prohibido crear rejas o cercas apilando decenas de partes delgadas (`0.2 studs`). Debe ser un módulo 3D (`MeshPart`) de tramo repetible.
  2. *Anti-patrón "Barandal Flotante":* Prohibido crear pasamanos de escaleras o balcones suspendiendo prismas rectangulares.
  3. *Anti-patrón "Mesa de 5 Cubos":* Prohibido construir mesas o sillas con 1 bloque de tabla y 4 cilindros de patas. Todo mueble es una malla 3D estilizada.
  4. *Anti-patrón "Tubería Ortogonal":* Prohibido crear tuberías pegando cilindros rectos en esquinas duras de 90°. Deben ser mallas 3D con codos curvos y bridas.
  5. *Anti-patrón "Barril de Cilindro Liso":* Prohibido usar un cilindro primitivo de Roblox para simular un tambor de aceite o barril.
  6. *Anti-patrón "Vegetación Minecraft":* Prohibido crear árboles con un cilindro marrón y una esfera/cubo verde encima.
  7. *Anti-patrón "Sacos de Arena de Ladrillo":* Prohibido apilar bloques rectangulares beige simulando sacos de arena.
  8. *Anti-patrón "Ventana/Puerta Plana":* Prohibido pegar calcomanías (`Decals`) sobre paredes planas para simular puertas o ventanas cerradas. Marcos y manijas van en 3D con relieve.
  9. *Anti-patrón "Cartel Volador":* Prohibido instanciar carteles como losas flotantes sin postes anclados o fijaciones visibles al muro.
  10. *Anti-patrón "Antorcha de Bloque Neón":* Prohibido simular fuego o antorchas con cubos o esferas de neón sin soporte 3D y sin partículas.




