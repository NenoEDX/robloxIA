---
name: roblox-04-3d-world-csg
description: "Rige la construcción del mundo 3D, CSGv3, mallas modulares y terreno procedural en Roblox (skills 086-115): GeometryService async, voxel terrain, PBR SurfaceAppearance, LOD, StreamingEnabled y post-procesamiento. Úsala al generación de niveles, destrucción procedural o diseño de iluminación."
license: MIT
allowed-tools: Read Write Bash(node:*,luau-lsp:*,rojo:*,wally:*)
metadata:
  domain: "3D World, CSGv3 & Procedural"
  range: "086-115"
  author: "RAASE 2.0 / robloxIA"
---

# roblox-04-3d-world-csg — Mundo 3D, CSGv3 y Terreno Procedural (Skills 086 - 115)

Este módulo rige la creación de entornos tridimensionales, modelado paramétrico y optimización geométrica para Roblox 2026.

## Principios Fundamentales
- **CSG Asíncrono:** Todas las operaciones booleanas sólidas se realizan mediante `GeometryService` asíncrono para no congelar la tasa de cuadros.
- **Topología Estanca:** Garantizar geometrías sin huecos ni caras invertidas antes de operaciones de unión o sustracción.
- **Fidelidad de Colisión:** Ajustar `CollisionFidelity` de acuerdo a la interacción requerida, priorizando `Box` o `Hull`.

## Catálogo de Habilidades Técnicas

### 086. `3d-glb-pipeline-import`
- **Regla:** Validar y optimizar la importación de mallas GLB/FBX asegurando proporciones de escala uniformes y jerarquías limpias.

### 087. `3d-triangle-budget-compliance`
- **Regla:** Respetar el presupuesto poligonal por objeto (límite oficial de 20,000 triángulos por mesh individual; las operaciones CSG que exceden el tope simplifican el resultado a 20k, o fallan si no se puede) para mantener 60 FPS estables.

### 088. `3d-building-mesh-fragmentation`
- **Regla:** Dividir estructuras arquitectónicas grandes en componentes modulares repetibles en lugar de mallas colosales únicas.

### 089. `3d-pbr-material-authoring`
- **Regla:** Configurar texturas PBR completas (Color, Metalness, Roughness, Normal) en SurfaceAppearance con resolución balanceada.

### 090. `csg-watertight-mesh-assertion`
- **Regla:** Verificar que las partes base a operar mediante CSG no posean caras invertidas ni huecos para evitar operaciones fallidas.
- **Reparación (watertight):** Blender (3D Print Toolbox, Mesh Repair Tools) o Meshlab reparan huecos y caras invertidas; `Solidify` de Blender da grosor a shells.

### 091. `csg-geometry-service-union`
- **Regla:** Emplear GeometryService:UnionAsync() de forma asíncrona para combinar geometrías sin bloquear el hilo de ejecución principal; configurar sus opciones verificadas: `CollisionFidelity`, `RenderFidelity`, `SplitApart` (default `true`) y `CalculateConstraintsToPreserve`.

### 092. `csg-geometry-service-subtract`
- **Regla:** Utilizar GeometryService:SubtractAsync() asegurando que la parte negativa solape completamente la superficie a perforar.

### 093. `csg-geometry-service-intersect`
- **Regla:** Aplicar GeometryService:IntersectAsync() calculando el volumen volumétrico común exacto entre dos partes.

### 094. `csg-geometry-service-sweeppart`
- **Regla:** Generar extrusiones dinámicas de geometrías a lo largo de curvas con GeometryService:SweepPartAsync() (requiere la Beta Feature "Solid Modeling On Meshes", File → Beta Features; no es release pleno).

### 095. `csg-geometry-service-fragment`
- **Regla:** Fragmentar mallas sólidas de forma dinámica con GeometryService:FragmentAsync() para efectos de destrucción procedural en tiempo de ejecución (requiere la Beta Feature "Solid Modeling On Meshes", File → Beta Features; no es release pleno).

### 096. `terrain-procedural-perlin-islands`
- **Regla:** Generar topografía insular natural mediante ruido Perlin o simplex muestreado en 2D y 3D.

### 097. `terrain-voxel-biomes-palette`
- **Regla:** Pintar materiales de terreno (Grass, Sand, Rock, Snow) de forma coherente según la elevación y pendiente del mapa.

### 098. `terrain-smooth-write-voxels`
- **Regla:** Utilizar Terrain:WriteVoxels() para manipular bloques volumétricos de terreno de manera eficiente en lote.

### 099. `terrain-raycast-vegetation-scatter`
- **Regla:** Muestrear colisiones con raycast hacia el terreno para posicionar follaje, árboles y rocas adaptados a la normal del suelo.

### 100. `3d-checkerboard-texture-styling`
- **Regla:** Utilizar texturas de cuadrícula/damero de referencia para prototipado y ajuste milimétrico de escalas y métricas de juego.

### 101. `3d-level-of-detail-setup`
- **Regla:** Configurar niveles de detalle (LOD) automáticos en MeshParts para reducir la carga de renderizado a distancia.

### 102. `3d-content-streaming-optimization`
- **Regla:** Optimizar ModelStreamingMode y StreamInOut para habilitar streaming de contenido fluido en dispositivos con memoria restringida.

### 103. `3d-collision-fidelity-tuning`
- **Regla:** Ajustar CollisionFidelity a Box o Hull para objetos decorativos, reservando PreciseConvexDecomposition solo donde sea imprescindible.

### 104. `3d-lighting-atmosphere-design`
- **Regla:** Configurar Atmosphere, Sky y Lighting (Technology = Future) para una iluminación volumétrica y ambiental inmersiva.

### 105. `3d-depth-of-field-cinematics`
- **Regla:** Ajustar DepthOfFieldEffect para enfocar la atención visual en escenas cinematográficas y planos de conversación.

### 106. `3d-bloom-sunrays-postprocessing`
- **Regla:** Balancear BloomEffect y SunRaysEffect para lograr destellos lumínicos realistas sin saturar ni cegar al usuario.

### 107. `3d-volumetric-cloud-styling`
- **Regla:** Configurar nubes volumétricas dinámicas (Clouds) con densidades y coberturas que acompañen el clima del juego.

### 108. `3d-particle-emitter-optimization`
- **Regla:** Controlar la tasa de emisión (Rate) y tiempo de vida (Lifetime) en ParticleEmitters para no exceder presupuestos de renderizado de partículas.

### 109. `3d-beam-trail-vfx`
- **Regla:** Crear efectos de estelas y rayos dinámicos utilizando Beams y Trails con texturas transparentes optimizadas.

### 110. `3d-highlight-selection-rendering`
- **Regla:** Utilizar Highlight de forma consciente para siluetas y selecciones interactivas sin superar el límite de 31 highlights concurrentes.

### 111. `3d-smart-asset-caching`
- **Regla:** Reutilizar mallas y texturas idénticas mediante clonación de instancias para beneficiarse del caché de instanciación del motor.

### 112. `3d-bounding-box-placement-grid`
- **Regla:** Calcular GetBoundingBox() de modelos para alinear construcciones a una cuadrícula espacial de colocación precisa.

### 113. `3d-meshpart-vertex-welding`
- **Regla:** Unir piezas modulares mediante WeldConstraints manteniendo RootPriority definido para estabilizar el ensamble físico.

### 114. `3d-procedural-dungeon-generator`
- **Regla:** Diseñar mazmorras o salas aleatorias conectando módulos prefab mediante algoritmos de crecimiento en árbol o WFC.

### 115. `3d-wireframe-handle-debugging`
- **Regla:** Utilizar WireframeHandleAdornment para visualizar cajas de colisión y áreas de influencia espacial durante el desarrollo.

## 🧱 Anexo: Un-merge, negación y CSG sobre meshes (notas)

- **Un-merge:** no existe API in-game de separación; el Separate de Studio (Shift+Ctrl+U) es la única vía (se deshace en el editor, no por script).
- **Negación in-game:** tag `rbxNegate` vía `CollectionService`.
- **Reemplazo de geometría:** `SubstituteGeometry()` / `MeshPart:ApplyMesh()`.
- **Beta gate:** `SweepPartAsync`, `FragmentAsync` y el CSG sobre meshes requieren la Beta Feature "Solid Modeling On Meshes" (File → Beta Features).
