# Csg Import Specs Specification

## Purpose

Correcciones CSG de `roblox-04-3d-world-csg` (límite oficial de triángulos, opciones de `UnionAsync`, un-merge/negación, beta gate) y alineación de las especificaciones de importación de `roblox-36-asset-pipeline`. Todo trazable al Addendum A (docs oficiales de solid modeling y specs de modelado, 2026-09-13).

## Requirements

### Requirement: Límite oficial de 20 000 triángulos por mesh

`roblox-04` MUST reemplazar "máximo 4.000 a 10.000 triángulos según categoría" por el límite oficial de 20 000 triángulos por mesh individual, e indicar que las operaciones CSG simplifican a 20k si se excede (o fallan si no se puede). `roblox-36` MUST alinear su presupuesto de la regla 2 con el mismo tope de 20k por mesh.

#### Scenario: Presupuesto consistente

- GIVEN un lector de `roblox-04`
- WHEN busca el presupuesto poligonal
- THEN encuentra 20 000 triángulos por mesh y ya no el rango "4.000 a 10.000"
- AND `roblox-36` no contradice ese tope (props ≤5 000; héroes/armas ≤20 000)

#### Scenario: CSG que excede el límite

- GIVEN una unión cuyo resultado supera 20k triángulos
- WHEN el lector revisa la regla CSG
- THEN la documentación indica que el resultado se simplifica a 20k o la operación falla

### Requirement: Opciones de UnionAsync

`roblox-04` MUST documentar `GeometryService:UnionAsync()` con las opciones `CollisionFidelity`, `RenderFidelity`, `SplitApart` (default `true`) y `CalculateConstraintsToPreserve`.

#### Scenario: Opciones completas

- GIVEN la regla de unión (091)
- WHEN el lector la revisa
- THEN encuentra las cuatro opciones con el default de `SplitApart`

### Requirement: Un-merge y negación in-game

`roblox-04` MUST documentar: Separate es herramienta de Studio (Shift+Ctrl+U) y la única vía de un-merge; la negación in-game de geometría se logra con el tag `rbxNegate` vía `CollectionService`; el reemplazo de geometría se hace con `SubstituteGeometry()`/`MeshPart:ApplyMesh()`. El catálogo MUST NOT introducir `SeparateAsync` (no existe en la API).

#### Scenario: Un-merge documentado sin API inexistente

- GIVEN un lector que quiere deshacer una unión
- WHEN busca el procedimiento
- THEN encuentra Separate de Studio (Shift+Ctrl+U) como única vía de un-merge
- AND encuentra `rbxNegate` para la negación in-game
- AND no aparece `SeparateAsync`

### Requirement: Beta gate de Sweep y Fragment

`roblox-04` MUST presentar `SweepPartAsync` (regla 094) y `FragmentAsync` (regla 095, hoy sin nombrar) como funcionalidades detrás de la Beta Feature "Solid Modeling On Meshes" (File → Beta Features); MUST NOT presentarlas como release pleno.

#### Scenario: Gate visible

- GIVEN el lector de las reglas 094-095
- WHEN revisa Sweep y Fragment
- THEN ambas nombran la API y advierten que requieren la Beta Feature "Solid Modeling On Meshes"

### Requirement: Guía watertight y reparación

`roblox-04` MUST incluir la guía de geometría watertight y reparación: Blender (3D Print Toolbox, Mesh Repair Tools) o Meshlab, y `Solidify` de Blender para shells.

#### Scenario: Herramientas de reparación

- GIVEN la regla watertight (090)
- WHEN el lector busca cómo reparar una malla
- THEN encuentra las herramientas de Blender y Meshlab
- AND `Solidify` para dar grosor a shells

### Requirement: Especificaciones verificadas de importación

`roblox-36` MUST documentar las especificaciones verificadas: transform congelado (scale 1,1,1 / rot 0,0,0), root en 0,0,0, máximo 4 influencias por vértice, sin influencias al root; animación con single track por export; cages `_InnerCage`/`_OuterCage`; geometría watertight, sin N-gons y sin grosor 0.

#### Scenario: Handoff con specs completas

- GIVEN un lector del handoff de `roblox-36`
- WHEN revisa los requisitos de exportación/importación
- THEN encuentra las reglas de transform, root, influencias, animación, cages y geometría
