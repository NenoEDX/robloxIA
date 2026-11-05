# Plan Maestro del Ecosistema IA + Roblox Studio MCP Oficial

Este documento define el protocolo operativo definitivo para la creación asistida por IA de juegos de Roblox utilizando **exclusivamente el servidor MCP oficial de Roblox Studio** como transporte hacia Studio, interconectado con el baúl de conocimiento **LihFolk Vault V2** (1,300+ notas) y el **LihFolk Asset Pack** (815 modelos 3D, 204 materiales, 48 cielos, 9 animaciones y VFX).

---

## 1. Arquitectura MCP-First + Soberanía en Git

- **Transporte único a Studio:** Toda edición en vivo en Roblox Studio se realiza mediante el **MCP oficial de Roblox Studio** (`multi_edit` para scripts, `execute_luau` para posicionamiento 3D y auditorías, `start_stop_play` + `get_console_output` + `screen_capture` para verificación en tiempo real).
- **Cero dependencia de demonios externos:** No es necesario levantar servidores de Rojo ni el Companion Bridge de RASEE para trabajar en Studio.
- **Fuente de verdad en Git:** Todo script se guarda primero en los archivos `.luau` del repositorio local y se despliega a Studio con `multi_edit`.

---

## 2. Interconexión con el Baúl de 1.2 GB y Detector de Assets Faltantes

El comando central del ecosistema es [`bridge/asset_ecosystem.mjs`](../bridge/asset_ecosystem.mjs) junto con el registro reutilizable [`assets/ecosystem_registry.json`](../assets/ecosystem_registry.json).

```powershell
# Ver estado del ecosistema, conexión al Vault/Asset Pack y cola de assets faltantes
node bridge/asset_ecosystem.mjs status

# Si clonas el repositorio desde GitHub en otra PC y descargas luego el Vault/Asset Pack de 1.2 GB, vincúlalo con:
node bridge/asset_ecosystem.mjs link-vault --vault "C:\ruta\a\LihFolk Vault V2" --assets "C:\ruta\a\LihFolk-Assets"

# Buscar cualquier modelo 3D en el ecosistema propio o en los 815 modelos de LihFolk
node bridge/asset_ecosystem.mjs search --query crystal
```

### Regla dura de detección:
1. Antes de construir una zona o sistema, la IA ejecuta `auditGameAssets` cruzando los objetos necesarios contra:
   - [`assets/ecosystem_registry.json`](../assets/ecosystem_registry.json) (modelos 3D propios reutilizables entre juegos).
   - `LihFolk-Assets/Models/Kits/CATALOG.csv` (815 modelos validados con Gate A1-A18).
2. Si falta un asset, **está estrictamente prohibido inventar bloques básicos sin criterio (`MINDLESS_DECORATION_FORBIDDEN`)**. El asset pasa a la cola 1 por 1 de Nano Banana.

---

## 3. Departamento de Modelos 3D (1 por 1 para Complejos + Tanda de 10 para Accesorios/Mutaciones)

El sistema clasifica automáticamente cada asset según su nivel de detalle:
- **Modelos Complejos (`single_1x1` — Criaturas, Héroes, Máquinas, Edificios, Verjas):** Los pide **uno por uno** (`node bridge/asset_ecosystem.mjs next-prompt`) para máxima precisión geométrica.
- **Modelos Simples / Pequeños (`sheet_10x` — Accesorios, Mutaciones, Iconos, Props `< 1,000 tris`):** Los agrupa automáticamente en **tandas de hasta 10 en una sola hoja (Grid 2x5)** (`node bridge/asset_ecosystem.mjs next-prompt --mode batch10`) para ahorrar tus generaciones y tokens en Nano Banana.

```powershell
# Siguiente modelo complejo (1 por 1)
node bridge/asset_ecosystem.mjs next-prompt

# Tanda de hasta 10 accesorios / mutaciones en una sola hoja de Nano Banana
node bridge/asset_ecosystem.mjs next-prompt --mode batch10
```

El comando devuelve **un único asset a la vez** con su prompt de **Nano Banana** optimizado para 3D (vista 3/4 ortográfica, fondo neutro `#E8E8E8`, iluminación difusa sin sombras duras pintadas, silueta *chunky*) y las **3 rutas de conversión**:

| Ruta | Cuándo elegirla | Comando / Herramienta |
|---|---|---|
| **Ruta A: Blender 5.2 Paramétrico en el mismo chat** | Cuando usas una IA potente (Claude Opus, GPT-5.4, Gemini 4 Argon) para criaturas, slimes, casas o kits modulares. | `node agent/generators/run_slime_assets.mjs --only <slug> --out exports/ecosystem` |
| **Ruta B: Nativo en Studio vía MCP** | Cuando quieres generar la malla directo dentro de Roblox Studio con la imagen de referencia. | `Roblox_Studio.generate_mesh` / `generate_procedural_model` |
| **Ruta C: IA Ligera o App Externa (Tripo / Meshy / Rodin) + Auto-Limpieza Blender** | Cuando pasas la imagen de Nano Banana por un generador 3D externo y descargas un `.glb`/`.fbx` pesado. | `blender -b --factory-startup --python agent/generators/blender/normalize_external_3d.py -- --input <raw.glb> --out exports/ecosystem/<slug>/<slug>.glb --target-tris 4000 --height-studs 4.0` |

### Añadir fácilmente nuevos assets al ecosistema para futuros juegos:
Una vez generado o limpiado cualquier modelo 3D, se registra con un solo comando para que quede disponible en todos tus juegos futuros:

```powershell
node bridge/asset_ecosystem.mjs register --id verja_abismal_3d --name "Verja Modular Abismal 3D" --category module --glb exports/ecosystem/verja_abismal_3d/verja_abismal_3d.glb --tris 1640 --height 5.5 --tags verja,fence,abyssal,modular
```

---

## 4. Departamento de VFX Nivel "Juegos de Pelea" (`VFXRecipeCatalog`)

No necesitas buscar referencias técnicas de VFX. El catálogo [`VFXRecipeCatalog.luau`](../project_template/src/shared/VFXRecipeCatalog.luau) y el CLI te permiten elegir efectos por intención en español:

```powershell
node bridge/asset_ecosystem.mjs vfx-recipes --intent espada
node bridge/asset_ecosystem.mjs vfx-recipes --intent kamehameha
node bridge/asset_ecosystem.mjs vfx-recipes --intent slime

# Componer automáticamente un VFX original fluido de 6 fases (60 Hz) para definitivas, eventos de meteoritos o mutaciones sobre plantas/slimes:
node bridge/asset_ecosystem.mjs compose-vfx --prompt "Habilidad definitiva de lluvia de meteoritos solares que mutan las plantas con cristales dorados" --element solar --scale 1.25
```

Cada receta aplica automáticamente la **Regla de los 3 Tonos** de LihFolk (`hotCore` blanco brillante + `elementBody` saturado + `darkInkRim` de tinta oscura de contraste), límite frontal `±100°` para tajos, `CameraShake` y `HitStop`. Para **habilidades definitivas, eventos climáticos o mutaciones sobre plantas/slimes**, `compose-vfx` (`composeOriginalVfx` / `composeCustomStoryboard`) sintetiza la línea de tiempo animada a **60 Hz (`RunService.RenderStepped`)** en 6 fases (Telegraph, Descenso/Cast, Impacto con Hit-Stop + ColorCorrection, Onda Expansiva, Transformación 4-Capas de Superficie con injerto 3D en tanda de 10, y Disipación `Quint.Out`).

---

## 5. Pipeline de Mapas en 2 Etapas (Plano desde Arriba + Topografía -> Referencias por Zona + Objetos 3D Reales)

Validado por [`MapZoneBuilder.luau`](../project_template/src/shared/MapZoneBuilder.luau) y `validateMapBlueprint` en [`bridge/asset_ecosystem.mjs`](../bridge/asset_ecosystem.mjs):

1. **Etapa 1 — Plano desde Arriba + Topografía (`topDownPlan` + `topography`):**  
   La IA solicita primero el plano cenital 2D del mapa junto con su **topografía** (alturas, fosos, terrazas, pendientes y rampas, más caminos `>= 16 studs` medidos a `16 studs/s`). Sin plano aprobado devuelve `MISSING_TOP_DOWN_PLAN`.
2. **Etapa 2 — Referencias por Cada Zona (`zoneReferences[]`):**  
   Para cada zona del plano (ej. Santuario, Jardín de Musgo, Caverna de Cristal), la IA solicita la imagen de referencia visual de esa zona. Sin ella devuelve `MISSING_ZONE_REFERENCE`.
3. **Etapa 3 — Desglose de Objetos 3D Reales (`props3d[]`) y Cero Decoración sin Criterio:**  
   Cada elemento decorativo o funcional de una zona (una verja 3D, una máquina extractora 3D, un arco portal 3D) se declara como un modelo 3D explícito con `placementRule: "placeOnGround"` o `"modularSnap"`. Cualquier intento de rellenar una zona con bloques primitivos al azar es bloqueado con `MINDLESS_DECORATION_FORBIDDEN`.

---

## 6. Generador de Frameworks Modulares Escalables (`scaffold-framework`)

Cada vez que pidas un sistema nuevo para crear o gestionar cosas (mascotas, forja, reliquias, misiones, combate), el comando `scaffold-framework` estructura una arquitectura de **5 capas en Luau (`--!strict`)** donde añadir nuevos elementos en el futuro consiste únicamente en agregar una fila al catálogo:

```powershell
node bridge/asset_ecosystem.mjs scaffold-framework --name RelicForge
```
- **Capa 1 (`<Sistema>Catalogs.luau`):** Tabla pura de datos, rarezas, stats y vínculos a modelos 3D y recetas VFX.
- **Capa 2 (`<Sistema>Rules.luau`):** Lógica pura y matemática determinista (testeable sin esperas).
- **Capa 3 (`<Sistema>Service.luau`):** Servicio autoritativo de servidor, seguridad de red y estado.
- **Capa 4 (`<Sistema>Controller.client.luau`):** Interfaz, prompts, acople de modelos 3D y disparo de VFX.
- **Capa 5 (`<Sistema>RulesTests.luau`):** Suite ejecutable en Studio vía MCP `execute_luau`.
