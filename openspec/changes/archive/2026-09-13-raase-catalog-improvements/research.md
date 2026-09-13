# Investigación: Mejoras del catálogo RAASE 2.1 (raase-catalog-improvements)

> Fase: sdd-research · Fecha de trabajo: 2026-09-13 · Store: openspec
> Estado global: **BLOQUEADA — sin evidencia externa admitida.** Los grants de evidencia de esta sesión están vacíos (`documentation=[]`, `open-web=[]`); no existe herramienta de acceso web en el runtime y el inventario MCP no expone recursos. En consecuencia se emiten **cero claims externos**: todo dato que requiera fuente oficial queda marcado `UNVERIFIABLE` con motivo exacto y objetivo de verificación.
> Regla aplicada (sdd-research): ningún claim sin fuente; un claim no respaldado se marca `unverified` y no se presenta como hecho.

---

## 1. Contexto

La fase `sdd-explore` identificó 4 oportunidades de alta prioridad para el catálogo `skills-roblox/` (39 skills, español, formato agentskills.io). El usuario seleccionó las 4 lanes de investigación externa que respaldan la decisión de la propuesta:

| Lane | Tema | Decisión que informa | Riesgo si el dato es incorrecto |
|---|---|---|---|
| L1 | DevEx 2026 (tasas, umbral, elegibilidad, verificación) | Editar o confirmar `roblox-09` + `roblox-18` | Dinero/legal — máximo |
| L2 | Mapeo audio legacy ↔ API moderna (`roblox-07` + `roblox-35`) | Completar tabla de equivalencia y recetas de zona | Medio (exactitud técnica) |
| L3 | Patrones canónicos de remotos (`roblox-02`) | Añadir anexo de scaffolding + límites oficiales | Medio-alto (seguridad) |
| L4 | CSG un-merge + specs de importación (`roblox-04` + `roblox-36`) | Añadir `SeparateAsync` + cifras oficiales | Medio (exactitud técnica) |

El catálogo no cita fuentes ni fechas de verificación en ningún SKILL.md (hallazgo de la exploración); este documento establece además el estado de verificación externa que `sdd-propose` debe respetar.

---

## 2. Metodología

### 2.1 Qué se consultó (fuentes locales, lectura directa — confianza alta)

| Fuente local | Uso | Fecha |
|---|---|---|
| `openspec/changes/raase-catalog-improvements/exploration.md` | Insumo: oportunidades priorizadas y mapa de cobertura | 2026-09-13 |
| `openspec/project.md` | Convenciones del repo, restricciones, verificación | 2026-09-13 |
| `skills-roblox/roblox-09-economy-devex/SKILL.md` (L1) | Claims actuales de tasas/umbral/R15 | 2026-09-13 |
| `skills-roblox/roblox-18-monetization-suite/SKILL.md` (L1) | Anexo Creator Store USD | 2026-09-13 |
| `skills-roblox/roblox-02-netsec/SKILL.md` (L3) | Reglas 026-060, rate limiter, Unreliable | 2026-09-13 |
| `skills-roblox/roblox-07-audio-dsp/SKILL.md` y `roblox-35-dynamic-audio-music/SKILL.md` (L2) | Nodos legacy/modernos, Wire, zonas | 2026-09-13 |
| `skills-roblox/roblox-04-3d-world-csg/SKILL.md` y `roblox-36-asset-pipeline/SKILL.md` (L4) | CSG, presupuestos, importación | 2026-09-13 |
| Greps de auditoría sobre `skills-roblox/**/*.md` | Cobertura real de clases audio, ops GeometryService, términos de remotos, formatos de import | 2026-09-13 |

Los greps de auditoría local cubrieron: `Audio[A-Z][A-Za-z]+`, `SeparateAsync|UnionAsync|IntersectAsync|SubtractAsync|SweepPartAsync|FragmentAsync|GeometryService`, `UnreliableRemoteEvent|RemoteFunction|FireServer|OnServerEvent|InvokeClient|OnClientInvoke|FireClient`, `SoundEffect|SoundGroup|SoundService`, y `\.glb|\.gltf|\.fbx|\.obj|GLB|FBX|Open Cloud|3D Importer`.

### 2.2 Qué NO se pudo consultar (y por qué — motivo exacto)

**Ninguna fuente externa pudo consultarse.** Causas concurrentes, todas verificadas en esta sesión:

1. **Sin herramienta de acceso web**: el conjunto de herramientas disponible no incluye `websearch`/`webfetch` ni equivalente.
2. **Grants de evidencia vacíos**: el contrato de evidencia de esta sesión declara `documentation=[]` y `open-web=[]`. Las clases no soportadas o no declaradas **niegan admisión y no emiten claims**; por tanto ni siquiera fuentes documentales accesibles por otras vías (p. ej. Context7, que existe en el runtime) son admisibles: su clase (`documentation`) no tiene grant.
3. **Inventario MCP vacío**: `list_mcp_resources` y `list_mcp_resource_templates` devolvieron `[]`.

Fuentes objetivo que quedaron sin consultar (por lane):

- **L1**: documentación oficial de Developer Exchange en create.roblox.com; anuncios oficiales de tasas (devforum/Anuncios); Centro de ayuda/legal (términos DevEx); secundarias solo para contraste (bloxsniper, generalistprogrammer).
- **L2**: documentación oficial de audio/efectos y audio dinámico (create.roblox.com), referencias de clase del engine, guía de `Wire`.
- **L3**: guía oficial de eventos remotos y límites de red (create.roblox.com), referencias de `UnreliableRemoteEvent`, `RemoteFunction`, `RemoteEvent`; devforum (módulo rate limiter, checklist baseplatedev) como fuentes comunitarias a triangular.
- **L4**: referencia de clase `GeometryService`, `art/modeling/specifications`, documentación del importador 3D, referencia de Open Cloud (Assets API); hilo de devforum sobre un-merge/vertex count.

### 2.3 Reglas de evidencia aplicadas

- Un claim externo sin fuente concreta se marca `UNVERIFIABLE` con motivo; no se sustituye por conocimiento previo del modelo ni por inferencia.
- La auditoría del contenido actual del catálogo (archivo:línea) es una **observación local verificada** (lectura directa), no un juicio de exactitud externa; se etiqueta como tal.
- La aritmética derivable localmente (p. ej. conversión R$→USD con las tasas afirmadas por el catálogo) se marca `VERIFICADO (local)` solo en su consistencia interna, nunca en la validez de las tasas de entrada.
- Escala de veredictos usada: `VERIFIED` (confirmado con fuente) · `CHANGED` (la fuente contradice o actualiza el claim) · `UNVERIFIABLE` (sin evidencia admisible para decidir). En esta sesión: **0 VERIFIED, 0 CHANGED, todos los ítems externos UNVERIFIABLE.**

---

## 3. Lane 1 — DevEx 2026 (tasas, umbral, elegibilidad, verificación)

**Pregunta:** ¿siguen siendo correctos hoy los datos DevEx que afirma el catálogo (tasas $0.0038/$0.0054/$0.0035, umbral 30.000 R$, requisito R15) y cómo se atribuye la verificación de identidad/edad?

**Estado de evidencia externa:** `UNVERIFIABLE` — sin grant `open-web`/`documentation`, sin herramienta web, sin recursos MCP (ver 2.2). No se emite ningún claim sobre las tasas vigentes.

### 3.1 Claims actuales del catálogo (observación local verificada)

| # | Claim del catálogo | Ubicación |
|---|---|---|
| 1 | Tasa estándar 2026 = $0.0038 USD/R$; umbral mínimo de retiro 30.000 R$ = $114.00 | `roblox-09-economy-devex/SKILL.md:17` |
| 2 | Tasa preferencial U.S. 18+ = $0.0054 USD/R$; 30.000 R$ = $162.00; requiere avatares R15 y verificación de identidad | `roblox-09-economy-devex/SKILL.md:18` |
| 3 | Tasa legada = $0.0035 USD/R$ para balances generados **antes de septiembre de 2025** | `roblox-09-economy-devex/SKILL.md:19` |
| 4 | Imponer R15 en `StarterPlayer.GameSettings` para calificar a la tasa preferencial | `roblox-09-economy-devex/SKILL.md:48` (skill 219) |
| 5 | Umbral oficial = 30.000 Robux ganados legítimamente | `roblox-09-economy-devex/SKILL.md:51` (skill 220) |
| 6 | Anexo Creator Store: venta directa en USD, liquidación sin conversión a Robux | `roblox-18-monetization-suite/SKILL.md:310-313` |
| 7 | (Duplicado en raíz) "Configurar el juego exclusivamente con avatares R15 para calificar a la tasa preferencial U.S. 18+" | `CLAUDE.md` (raíz, fuera del catálogo) |

### 3.2 Verificaciones pendientes (ítem por ítem)

| # | Pregunta de verificación | Claim a contrastar | Veredicto | Objetivo de verificación (fuente oficial / candidata, sin verificar) |
|---|---|---|---|---|
| V1 | ¿La tasa estándar vigente es $0.0038/R$? | Claim 1 | `UNVERIFIABLE` — sin evidencia admisible | create.roblox.com → Docs → monetización → Developer Exchange (ruta candidata `/docs/production/monetization/developer-exchange`) |
| V2 | ¿La tasa preferencial U.S. 18+ vigente es $0.0054/R$? | Claim 2 | `UNVERIFIABLE` | misma fuente que V1 + anuncios oficiales |
| V3 | ¿La tasa legada es $0.0035/R$ y cuál es la fecha de corte exacta? **(el catálogo afirma "antes de septiembre de 2025"; el encargo plantea "pre-2025" — las dos formulaciones difieren y ninguna está citada)** | Claim 3 | `UNVERIFIABLE` — además, discrepancia interna entre formulaciones | misma fuente que V1; anuncio oficial de transición de tasas |
| V4 | ¿El umbral mínimo de retiro es 30.000 R$? | Claims 1, 5 | `UNVERIFIABLE` | misma fuente que V1 |
| V5 | ¿La conversión 30.000 R$ → $114.00 y → $162.00 es consistente? | Claims 1, 2 | `VERIFICADO (local, solo aritmética)`: 30.000 × 0.0038 = 114.00 y 30.000 × 0.0054 = 162.00. La validez final depende de V1/V2 | — |
| V6 | ¿El requisito de calificación incluye R15 hoy? ¿Cómo aplican los matices de elegibilidad: rigs human-form personalizados, rigs no humanos, juegos sin avatar? | Claims 2, 4, 7 | `UNVERIFIABLE` | misma fuente que V1 (sección de requisitos/elegibilidad); términos legales DevEx |
| V7 | ¿El mecanismo `StarterPlayer.GameSettings` citado para forzar R15 existe/es correcto? **(claim técnico preciso, sin cita — alta prioridad)** | Claim 4 | `UNVERIFIABLE` | referencia de API/Studio sobre configuración de tipo de avatar; verificar nombre y ubicación reales |
| V8 | ¿La verificación de identidad (y el chequeo de edad) corresponde al creador o al gastador? **(el catálogo dice "requiere … verificación de identidad" sin atribuir a quién)** | Claim 2 | `UNVERIFIABLE` — ambigüedad de atribución no resoluble localmente | misma fuente que V1 + términos DevEx |
| V9 | ¿El anexo Creator Store (pagos USD) sigue vigente y con qué alcance? | Claim 6 | `UNVERIFIABLE` | create.roblox.com → Creator Store / pagos |

**Veredicto L1:** `UNVERIFIABLE` — 0/9 ítems con evidencia admisible. Se confirmó localmente que el catálogo **no cita fuente ni fecha** para ninguno de estos datos y que existe una discrepancia de formulación en la fecha de corte de la tasa legada (V3) y una ambigüedad de atribución en la verificación de identidad (V8).

**Implicación para el catálogo:** ninguna cifra de `roblox-09`/`roblox-18` puede modificarse ni confirmarse como "vigente" sin la verificación V1-V9. Si se requiere publicar ya, la propuesta debe tratar estas cifras como **sujetas a verificación externa obligatoria** y no como hechos (riesgo dinero/legal). Este es el gate más duro de la propuesta.

---

## 4. Lane 2 — Mapeo audio legacy ↔ API moderna (`roblox-07` + `roblox-35`)

**Pregunta:** ¿cuáles de los nodos modernos `Audio*` existen realmente hoy, cómo se cablean por `Wire`, cuál es su equivalencia con los `*SoundEffect` legacy, y qué mecanismo real tiene la técnica de "zonas de sonido sin scripting" y el reverb multi-zona?

**Estado de evidencia externa:** `UNVERIFIABLE` — mismas causas (2.2). No se emite ningún claim sobre existencia, propiedades ni equivalencia de clases.

### 4.1 Auditoría local de cobertura (observación verificada por grep + lectura)

**Clases legacy `*SoundEffect` mencionadas en el catálogo (4):**

| Clase | Ubicación |
|---|---|
| `EqualizerSoundEffect` | `roblox-07-audio-dsp/SKILL.md:28` (skill 169) |
| `ReverbSoundEffect` | `roblox-07-audio-dsp/SKILL.md:31` (skill 170) |
| `CompressorSoundEffect` | `roblox-07-audio-dsp/SKILL.md:34` (skill 171) |
| `DistortionSoundEffect` | `roblox-07-audio-dsp/SKILL.md:37` (skill 172) |

**Clases legacy ausentes del catálogo (4):** `ChorusSoundEffect`, `FlangeSoundEffect`, `TremoloSoundEffect`, `EchoSoundEffect` — no aparecen en ningún archivo de `skills-roblox/` (grep `SoundEffect`).

**Nodos modernos mencionados en el catálogo (10):** `AudioPlayer`, `AudioDeviceInput`, `AudioEmitter`, `AudioListener`, `AudioFader`, `AudioPitchShifter`, `AudioChorus`, `AudioFilter`, `AudioAnalyzer`, `AudioReverb` (+ `Wire` como instancia de conexión) — p. ej. `roblox-35-dynamic-audio-music/SKILL.md:24-236` y `roblox-07-audio-dsp/SKILL.md:70,83`.

**Nodos modernos ausentes del catálogo (8):** `AudioDistortion`, `AudioEcho`, `AudioCompressor`, `AudioEqualizer`, `AudioLimiter`, `AudioGate`, `AudioTremolo`, `AudioFlanger` — sin aparición en `skills-roblox/`.

**Propiedades/APIs citadas por el catálogo que también requieren verificación externa:** `AudioFader.Volume`; `AudioPitchShifter.Pitch`; `AudioFilter.FilterType` (`Enum.AudioFilterType.Lowpass/Bandpass`) y `CutoffFrequency`; `AudioReverb.DecayTime/Density/Diffusion`; `AudioAnalyzer:GetSpectrum()`; `AudioEmitter.DistanceAttenuation`; `Wire.SourceInstance/TargetInstance` (`roblox-35:26-31,39-45,66-71,79-84,108-121,125-134,171-179,190-205`).

**Mecanismos de reverb coexistentes (tensión a resolver):**

| Mecanismo | Ubicación | Nota |
|---|---|---|
| Nodo `AudioReverb` con `DecayTime/Density/Diffusion` | `roblox-35:124-134` (skill 603) | Mecanismo moderno del grafo Wire |
| `SoundService.AmbientReverb` + `Enum.ReverbType.Cave/ConcertHall` vía detector script | `roblox-11-map-making/SKILL.md:95` | Mecanismo legacy; el catálogo no documenta la frontera entre ambos |

**Zonas de sonido:** la regla 168 (`roblox-07:24-25`) describe activación por posición del jugador — scripting implícito; `roblox-11:95` describe un `Part` no colisionable (AABB) + *script detector* + `AmbientReverb`. **No existe en el catálogo ninguna técnica "sin scripting" documentada**; el mecanismo citado por el encargo (partes/regiones físicas + ajustes de audio espacial) es una hipótesis a verificar, no un hallazgo.

### 4.2 Verificaciones pendientes

| # | Pregunta | Veredicto | Objetivo de verificación |
|---|---|---|---|
| V10 | ¿Cuáles de las 8 clases legacy existen hoy y con qué estado (vigente/deprecada)? | `UNVERIFIABLE` | create.roblox.com → referencia de clases del engine (`/docs/reference/engine/classes/<ClassName>`) |
| V11 | ¿Cuáles de los 14 nodos modernos candidatos son clases reales hoy? ¿Cuáles se conectan vía `Wire`? | `UNVERIFIABLE` (la existencia de los 10 ya citados por el catálogo tampoco está verificada externamente) | docs de audio/efectos + referencia de clases + `Wire` |
| V12 | ¿Cuál es la equivalencia funcional exacta legacy ↔ moderna (para la tabla de mapeo)? | `UNVERIFIABLE` | docs de efectos (posible página de migración/equivalencias) |
| V13 | ¿La técnica "zonas de sonido sin scripting" es un flujo real de Studio? ¿Cuál es su mecanismo exacto (partes físicas + audio espacial, u otro)? | `UNVERIFIABLE` | docs de audio espacial / audio dinámico; video/artículo fuente original del catálogo |
| V14 | Reverb multi-zona: ¿el enfoque recomendado actual pasa por `AudioReverb` + zonas vía `AudioListener`/emisores? | `UNVERIFIABLE` | docs de audio dinámico; referencia `AudioReverb`/`AudioListener` |
| V15 | ¿Las propiedades citadas (4.1) existen con esos nombres y tipos? | `UNVERIFIABLE` | referencia de clase por nodo |

**Veredicto L2:** `UNVERIFIABLE` — el mapeo legacy↔moderno no puede completarse con evidencia admisible. Auditoría local confirmada: **4 clases legacy faltantes** (Chorus/Flange/Tremolo/Echo) y **8 nodos modernos faltantes** (Distortion/Echo/Compressor/Equalizer/Limiter/Gate/Tremolo/Flanger) respecto de los candidatos; técnica "sin scripting" no documentada; dos mecanismos de reverb coexisten sin frontera.

**Implicación para el catálogo:** la propuesta puede planificar la tabla de equivalencia, el relleno de nodos y la receta de zonas multi-reverb, pero **el contenido técnico de cada fila queda condicionado a V10-V15**. La frontera `07` (fundamentos/legacy) ↔ `35` (grafo moderno) debe resolverse en diseño, no asumirse.

---

## 5. Lane 3 — Patrones canónicos de remotos (`roblox-02`)

**Pregunta:** ¿cuáles son hoy los límites y la semántica oficial de `UnreliableRemoteEvent`, la guía de `RemoteFunction` (yield/`InvokeClient`), el patrón canónico de rate limiter por jugador, el scaffolding cliente→servidor y los límites de tasa oficiales de remotes?

**Estado de evidencia externa:** `UNVERIFIABLE` — mismas causas (2.2).

### 5.1 Auditoría local: qué tiene y qué no tiene el catálogo

**Reglas presentes (sin ejemplos):** validación `typeof()` (`roblox-02:26`), distancia `.Magnitude <= 15` (`:32`), rate limiter Token Bucket con "ej: máx 20 tokens, recarga de 5/seg" (`:41`), `UnreliableRemoteEvent` para cosméticos de alta frecuencia (`:44`), `RemoteEvent` para cambios de estado críticos (`:47`), descarte sobre 50 invocaciones/seg por jugador (`:98`), honeypots (`:56`), aislamiento de módulos (`:89-92`), entre otros.

**Ausencias confirmadas por grep en todo `skills-roblox/`:**

| Elemento | Estado local |
|---|---|
| Snippets `FireServer` / `OnServerEvent` | **Ausentes** (única mención de `OnServerEvent`: texto de la regla 027, `roblox-02:26`) |
| Guía/sección `RemoteFunction` y riesgos de `InvokeClient` (yield, cuelgues) | **Ausente** del cuerpo (solo aparece en la `description` de `roblox-02`) |
| Tabla de decisión Reliable vs Unreliable | **Ausente** (solo reglas 033/034 aisladas) |
| Scaffolding canónico cliente→servidor (intención → validación → respuesta) | **Ausente** |
| Implementación de referencia del Token Bucket por jugador | **Ausente** (solo el número "ej:" de la regla 032) |
| Checklist de auditoría baseplatedev verificable | **Ausente** (conceptos sueltos en reglas) |
| Uso real de `UnreliableRemoteEvent` | 1 ejemplo: `roblox-31-combat-systems/SKILL.md:223-227` (indicadores de daño) |

**Cifras del catálogo sin cita (a contrastar con límites oficiales):** 20 tokens / recarga 5 por segundo (`roblox-02:41`) y descarte > 50 invocaciones/seg (`roblox-02:98`). Son heurísticas internas; no hay fuente ni fecha asociada.

### 5.2 Verificaciones pendientes

| # | Pregunta | Veredicto | Objetivo de verificación |
|---|---|---|---|
| V16 | `UnreliableRemoteEvent`: límites de tasa/banda, semántica de orden y descarte, cuándo usar y cuándo no | `UNVERIFIABLE` | guía oficial de eventos remotos + referencia `UnreliableRemoteEvent` |
| V17 | `RemoteFunction`: riesgos de yield, peligros de `InvokeClient`, cuándo evitarse | `UNVERIFIABLE` | referencia `RemoteFunction` (advertencias oficiales) + consenso devforum |
| V18 | Rate limiter canónico por jugador (Token Bucket): módulo de referencia devforum y patrón estándar | `UNVERIFIABLE` | devforum (módulo destacado de rate limiting) — triangular con síntesis propia |
| V19 | Scaffolding canónico actual cliente→servidor y checklist baseplatedev (ítems de auditoría) | `UNVERIFIABLE` | guía oficial de remotos + checklist baseplatedev (fuente comunitaria) |
| V20 | Límites de tasa oficiales hoy (presupuestos por evento / por servidor) | `UNVERIFIABLE` | docs de red/remotos (páginas de límites) |
| V21 | ¿Las cifras internas 20/5 y 50/seg se alinean con los límites oficiales? | `UNVERIFIABLE` | misma fuente que V20 |

**Veredicto L3:** `UNVERIFIABLE` — 0/6 con evidencia admisible. Auditoría local confirmada: el catálogo tiene 40 reglas de seguridad sin plumbing (sin snippets cliente→servidor, sin `RemoteFunction`, sin tabla de decisión, sin implementación de referencia) y dos cifras de rate limit sin cita.

**Implicación para el catálogo:** el anexo de ejemplos canónicos de `roblox-02` es localmente necesario (hueco confirmado), pero **cada snippet, límite y recomendación debe construirse sobre V16-V21**; publicar números o semánticas sin verificar repetiría la falta de trazabilidad actual.

---

## 6. Lane 4 — CSG un-merge + specs de importación (`roblox-04` + `roblox-36`)

**Pregunta:** ¿existe `GeometryService:SeparateAsync` (nombre/firma/disponibilidad) y las operaciones relacionadas; cuáles son las cifras oficiales de especificaciones de modelado (triángulos/texturas) para reemplazar la heurística "4k-10k"; qué formatos soporta hoy el importador y qué soporta Open Cloud para modelos; y cuál es la advertencia exacta del hilo devforum sobre un-merge/vertex count?

**Estado de evidencia externa:** `UNVERIFIABLE` — mismas causas (2.2).

### 6.1 Auditoría local

| Elemento | Estado local |
|---|---|
| `SeparateAsync` | **Ausente** en todo `skills-roblox/` (grep) — no hay regla de un-merge |
| `UnionAsync` / `SubtractAsync` / `IntersectAsync` / `SweepPartAsync` | Presentes por nombre: `roblox-04:39,42,45,48`; `SubtractAsync` también en `roblox-12:83` |
| `FragmentAsync` | **No nombrada**: la regla 095 (`roblox-04:50-51`) describe fragmentación dinámica sin citar la API |
| Presupuesto de triángulos (v1) | `roblox-04:27`: "máximo 4.000 a 10.000 triángulos según categoría" |
| Presupuesto de triángulos (v2) | `roblox-36:96` (regla 2): props ≤ 5.000; héroes/armas ≤ 20.000; atlas flipbook ≤ 1.024 px |
| **Tensión interna**: 04 fija máximo general 4k-10k "según categoría"; 36 permite 20k para héroes/armas | Ambos sin cita; la relación entre ambos presupuestos no está explicada |
| Formatos citados | GLB/FBX (`roblox-04:24`); `.glb` con fallback `.gltf` (`roblox-36:82`); `.obj` **no se menciona**; template de handoff menciona FBX como alternativa (`scripts/ASSETS_HANDOFF.template.md:16`) |
| Importador: "Scale Unit = Meter", default Stud "~3.57× de diferencia", 1 stud ≈ 0.28 m | `roblox-36:81` — la aritmética es consistente (1/0.28 = 3.571), pero el comportamiento del importador no está verificado |
| Afirmación fuerte: "no existe API de scripting para importar mallas" (paso humano obligatorio) | `roblox-36:100` (regla 6) |
| Afirmación en tensión: subida de assets "GLB, audio, texturas" vía APIs REST de Open Cloud | `roblox-10-tooling-automation/SKILL.md:38` — el alcance exacto (¿subir el asset vs insertarlo en el lugar?) no está aclarado; verificar contra Open Cloud |

### 6.2 Verificaciones pendientes

| # | Pregunta | Veredicto | Objetivo de verificación |
|---|---|---|---|
| V22 | `GeometryService:SeparateAsync`: nombre exacto, firma, disponibilidad | `UNVERIFIABLE` | referencia de clase `GeometryService` (métodos `SeparateAsync`, `UnionAsync`, `IntersectAsync`, `SubtractAsync`, `SweepPartAsync`, `FragmentAsync`) |
| V23 | Cifras oficiales vigentes por categoría de `art/modeling/specifications` (triángulos por malla, tamaño de texturas, etc.) | `UNVERIFIABLE` | create.roblox.com → arte/modelado → especificaciones |
| V24 | Formatos soportados hoy por el importador de Studio (.fbx/.obj/.gltf/.glb u otros) | `UNVERIFIABLE` | docs del importador 3D |
| V25 | ¿Qué soporta Open Cloud hoy para assets de modelos (subida, inserción, límites)? | `UNVERIFIABLE` | referencia Open Cloud → Assets |
| V26 | Advertencia exacta del hilo devforum sobre un-merge / conteo de vértices (qué caveat documentar) | `UNVERIFIABLE` | devforum (identificar el hilo fuente; triangular con V22) |
| V27 | ¿El default del importador es realmente "Stud" y la equivalencia 1 stud ≈ 0.28 m? | `UNVERIFIABLE` | docs del importador 3D |

**Veredicto L4:** `UNVERIFIABLE` — 0/6 con evidencia admisible. Auditoría local confirmada: `SeparateAsync` ausente; `FragmentAsync` sin nombrar; dos presupuestos de triángulos internamente tensos (4k-10k vs ≤5k/≤20k); `.obj` no mencionado; afirmación "no existe API de scripting para importar mallas" en tensión aparente con la subida de assets vía Open Cloud.

**Implicación para el catálogo:** la adición de `SeparateAsync`, la sustitución de "4k-10k" por specs oficiales y las cifras de importación de `roblox-36` quedan **condicionadas a V22-V27**; además hay una aclaración de alcance pendiente (paso humano vs Open Cloud) que debe resolverse antes de editar.

---

## 7. Resumen de cambios requeridos al catálogo (accionable, con dependencia)

> Nota: ninguna fila es ejecutable como "corrección de dato" sin verificación externa previa. Las filas marcadas **[estructural]** están justificadas por la auditoría local (huecos/ausencias confirmadas); las marcadas **[exactitud]** dependen de una lane.

| # | Archivo / dominio | Cambio requerido | Tipo | Dependencia |
|---|---|---|---|---|
| 1 | `roblox-09` (+ `roblox-18` anexo) | Confirmar/corregir tasas estándar, 18+, legada (incluida la fecha de corte exacta), umbral 30k, y añadir nota de vigencia con cita | [exactitud] | L1 (V1-V5, V9) |
| 2 | `roblox-09` (skill 219 y texto) | Verificar/corregir el mecanismo `StarterPlayer.GameSettings`; precisar qué requisito de avatar aplica a la tasa preferencial | [exactitud] | L1 (V6, V7) |
| 3 | `roblox-09` | Atribuir explícitamente la verificación de identidad/edad (creador vs gastador) | [exactitud] | L1 (V8) |
| 4 | `CLAUDE.md` (raíz; coherencia) | Revisar la línea "avatares R15 para calificar…" una vez verificado L1 (mismo dato duplicado fuera del catálogo) | [exactitud] | L1 |
| 5 | `roblox-07` | Añadir tabla legacy ↔ moderna; completar clases legacy faltantes (Chorus/Flange/Tremolo/Echo); añadir técnica de regiones si V13 la confirma; cross-ref a `roblox-35` | [estructural + exactitud] | L2 (V10, V12, V13) |
| 6 | `roblox-35` | Incorporar nodos modernos faltantes (Distortion/Echo/Compressor/Equalizer/Limiter/Gate/Tremolo/Flanger) según V11; receta de zonas multi-reverb (V14); cross-ref a `roblox-07` | [estructural + exactitud] | L2 (V11, V14, V15) |
| 7 | `roblox-11` | Reconciliar `SoundService.AmbientReverb` con la recomendación vigente; documentar frontera legacy/moderno | [exactitud] | L2 (V10, V14) |
| 8 | `roblox-02` | Anexo de ejemplos canónicos: scaffolding intención→`typeof`→distancia→rate limit→respuesta; tabla Reliable/Unreliable; snippet Token Bucket; sección `RemoteFunction` (yield/`InvokeClient`); checklist de auditoría baseplatedev | [estructural + exactitud] | L3 (V16-V19) |
| 9 | `roblox-02` | Corregir/confirmar cifras internas 20/5 y 50/seg contra límites oficiales | [exactitud] | L3 (V20, V21) |
| 10 | `roblox-04` | Añadir `SeparateAsync` (un-merge) y nombrar `FragmentAsync` si V22 lo confirma; reemplazar "4.000-10.000" por specs oficiales | [estructural + exactitud] | L4 (V22, V23, V26) |
| 11 | `roblox-36` | Alinear presupuestos (props/héroes) con specs oficiales; añadir cifras por categoría al anexo de verificación post-import; verificar formatos y Scale Unit; aclarar alcance Open Cloud vs paso humano | [exactitud] | L4 (V23-V25, V27) |
| 12 | `roblox-10` / `roblox-36` | Resolver la tensión de alcance: subida de assets vía Open Cloud (10:38) vs "no existe API de scripting para importar mallas" (36:100) | [exactitud] | L4 (V25) |
| 13 | Catálogo (transversal; p. ej. `SOURCES.md`) | Añadir trazabilidad de fuentes con fecha de última verificación; este documento aporta el esqueleto de qué verificar y dónde | [estructural] | Ninguna (decisión de la propuesta) |

---

## 8. Incertidumbres y verificaciones pendientes (estado de recuperación)

### 8.1 Condición de desbloqueo (blocked recovery)

Esta fase **no puede cerrar con evidencia** hasta que se cumpla al menos una de estas condiciones:

1. **Habilitar grant `open-web`** con whitelist de dominios oficiales (`create.roblox.com`, `devforum.roblox.com`, `en.help.roblox.com`, `roblox.com/legal`) y una herramienta de acceso web (`webfetch`/`websearch`) disponible en el runtime; o
2. **Habilitar grant `documentation`** para una fuente documental admisible (p. ej. Context7 con un dataset/índice aplicable); o
3. **Aporte del creador**: extractos textuales fechados de las fuentes oficiales para los ítems V1-V27.

Mientras ninguna se cumpla, cualquier dato DevEx/specs/límites que se escriba en el catálogo quedaría sin respaldo — exactamente el problema que la propuesta busca resolver.

### 8.2 Lista operativa de verificación (a ejecutar cuando se desbloquee)

**L1 — DevEx (create.roblox.com + anuncios oficiales):** extraer tasas estándar/18+/legada vigentes, fecha de corte de la legada, umbral mínimo, requisitos de elegibilidad (R15: rigs human-form, no humanos, juegos sin avatar), y a quién corresponde la verificación de identidad/edad; contrastar con el anuncio oficial de transición de tasas y, solo como cross-check, con secundarias (bloxsniper, generalistprogrammer).

**L2 — Audio (create.roblox.com/docs audio/effects + dynamic-effects + reference classes + Wire):** confirmar existencia y estado de las 8 legacy y de los 14 candidatos modernos; extraer la tabla de equivalencias y propiedades clave por nodo; confirmar el mecanismo real de "zonas de sonido sin scripting" y el enfoque recomendado de reverb multi-zona.

**L3 — Remotos (create.roblox.com/docs scripting/events + reference classes + devforum):** extraer límites oficiales de `UnreliableRemoteEvent` (tasa/banda, orden/drop), advertencias de `RemoteFunction`/`InvokeClient`, límites por evento/servidor; recuperar el módulo canónico de rate limiting (devforum) y el checklist baseplatedev; triangular con las cifras internas del catálogo.

**L4 — CSG/Import (reference GeometryService + art/modeling/specifications + importer + Open Cloud Assets):** confirmar `SeparateAsync` (nombre/firma/disponibilidad) y operaciones relacionadas; extraer cifras oficiales por categoría; confirmar formatos soportados y comportamiento de Scale Unit; establecer qué permite Open Cloud con modelos; identificar el caveat exacto del hilo un-merge/vertex count.

### 8.3 Incertidumbres de proceso

- **Cita de fuentes**: hoy ningún SKILL.md cita fuente/fecha; incluso con verificación, la propuesta debe decidir el mecanismo de trazabilidad (SOURCES.md vs anexo por dominio).
- **Alcance v1**: si el desbloqueo no llega antes de `sdd-propose`, la propuesta debe decidir explícitamente entre (a) recortar a cambios estructurales y diferir los datos, o (b) proceder con placeholders marcados "pendiente de verificación" — decisión del usuario, no del research.
- **Overlap 07/35**: la frontera editorial entre ambos debe fijarse en `sdd-design` para no consolidar la duplicación.

## Ready for Proposal

**Sí — desbloqueado y verificado (ver Addendum A).** El sub-agente de research no tenía acceso web (grants vacíos), pero el ORQUESTADOR ejecutó la verificación externa contra documentación oficial de Roblox el 2026-09-13 (8 páginas oficiales). El Addendum A contiene la evidencia citada por lane y las correcciones concretas al catálogo. Pendientes menores declarados allí (límites numéricos de rate de remotes; formato exacto de importaciones en la página del importer).

---

## Fuentes locales consultadas

- `openspec/changes/raase-catalog-improvements/exploration.md` — insumo de fase (2026-09-13).
- `openspec/project.md` — contexto y verificación del repo (2026-09-13).
- `skills-roblox/roblox-09-economy-devex/SKILL.md`, `roblox-18-monetization-suite/SKILL.md` (L1); `roblox-07-audio-dsp/SKILL.md`, `roblox-35-dynamic-audio-music/SKILL.md` (L2); `roblox-02-netsec/SKILL.md`, `roblox-31-combat-systems/SKILL.md` (L3, grep); `roblox-04-3d-world-csg/SKILL.md`, `roblox-36-asset-pipeline/SKILL.md`, `roblox-10-tooling-automation/SKILL.md` (L4); `roblox-11-map-making/SKILL.md`, `roblox-12-model-maker/SKILL.md`, `roblox-16-chat-voice-social/SKILL.md`, `roblox-25-platform-performance/SKILL.md` (grep) — lectura directa 2026-09-13, confianza alta (observación local, no juicio externo).
- Greps de auditoría sobre `skills-roblox/**/*.md` (patrones en §2.1) — 2026-09-13.

---

## Addendum A — Evidencia externa verificada (orquestador, web oficial, 2026-09-13)

> Fuentes fetch directo (docs oficiales, ©2026): developer-exchange · 18-plus-devex-rate · audio/effects · scripting/events/remote · reference UnreliableRemoteEvent · parts/solid-modeling · reference GeometryService · art/modeling/specifications. Todas las afirmaciones de abajo salen de esas páginas.

### Lane 1 — DevEx: **VERIFICADO con matices**
- `$0.0038` estándar **CONFIRMADO** (30,000 R$ = $114 USD). `$0.0035` **CONFIRMADO** para saldos anteriores al 5-sep-2025 10am PT. `$0.0054` **CONFIRMADO** (U.S. 18+, vigente desde **8-jun-2026**).
- **La verificación 18+ es del JUGADOR** (spender: facial age estimation o government ID) — **no del creador**. Aplica a compras de developer products, passes, subscriptions y private servers de players U.S. 18+ en juegos elegibles.
- Elegibilidad 18+ (personajes): 100% del playtime como R15 platform, **custom human-form** (1 cabeza/2 brazos/2 piernas; 12 limb parts O 12 limb joints distribuidas; torso ≥2 parts/joints; bipedal completo) **o custom nonhuman-form (también califica)**; **sin R6 en ningún momento**; animation packs R15. **NPCs no se evalúan.**
- Base DevEx (estándar): 13+ años, 30k Earned Robux, email verificado, portal DevEx, W-9/W-8. La regla "R15-only" aplica al **sistema de avatares platform** para la tasa 18+ — no es requisito del DevEx estándar.
- → **Correcciones para 09/18**: atribución de verificación (jugador, no creador); "nonhuman-form también califica" + "sin R6"; fecha de vigencia 18+ (8-jun-2026); ejemplos de conversión R$→USD.

### Lane 2 — Audio legacy ↔ moderno: **VERIFICADO**
- Clases modernas **CONFIRMADAS** (docs/audio/effects): `AudioEqualizer`, `AudioCompressor`, `AudioReverb`, `AudioChorus`, `AudioDistortion`, `AudioEcho`, `AudioFlanger`, `AudioTremolo`, `AudioPitchShifter`, `AudioFader`, `AudioAnalyzer`.
- `AudioLimiter` y `AudioGate`: **NO aparecen** en la doc de efectos → no incluirlos (no confirmados).
- Los docs destacan que **el orden de los efectos altera el resultado** (ej. Chorus→Distortion ≠ Distortion→Chorus) — documentarlo.
- → **Para 07/35**: tabla de equivalencias (Distortion→AudioDistortion, Equalizer→AudioEqualizer, Reverb→AudioReverb, Compressor→AudioCompressor, Chorus→AudioChorus, Flange→AudioFlanger, Tremolo→AudioTremolo, Echo→AudioEcho); nota de orden; cross-ref explícito 07↔35.

### Lane 3 — Remotos: **VERIFICADO** (plumbing canónico)
- Scaffolding oficial: `FireServer`/`OnServerEvent(player, …)`; `FireClient(player, …)`/`OnClientEvent`; `FireAllClients`.
- **`InvokeClient` riesgos oficiales**: error del cliente se propaga al servidor; disconnect del cliente → error; si el cliente no retorna → **el servidor yieldea para siempre**. La doc recomienda **RemoteEvent** para flujo server→client de una vía.
- `UnreliableRemoteEvent`: one-way; sacrifica orden y confiabilidad por performance de red ("datos que cambian continuamente o no son críticos"); misma superficie de métodos/eventos que RemoteEvent.
- **Limitaciones de argumentos oficiales**: índices no-string → se convierten a string; funciones → `nil`; no mezclar keys numéricas y string; evitar `nil` en índices; las tablas se **copian** (identidad perdida); **metatables se pierden**; instancias no replicables → `nil`.
- Límites numéricos de rate de remotes: **no verificados en estas páginas** → pendiente (no publicar números sin fuente).
- → **Para 02**: anexo de plumbing canónico + tabla Reliable vs Unreliable + riesgos de InvokeClient + pitfalls de argumentos.

### Lane 4 — CSG/specs: **VERIFICADO con correcciones importantes**
- **`SeparateAsync` NO EXISTE**: los métodos oficiales de `GeometryService` son `UnionAsync`, `IntersectAsync`, `SubtractAsync`, `FragmentAsync`, `GenerateFragmentSites`, `SweepPartAsync`, `CalculateConstraintsToPreserve`. El "Separate" es **herramienta de Studio** (ShiftCtrl+U); **no hay API de un-merge in-game**.
- **20,000 triángulos** = límite oficial por mesh individual (specs) — y las operaciones CSG simplifican a 20k si exceden (o fallan si no se puede).
- `UnionAsync` options confirmadas: `CollisionFidelity`, `RenderFidelity`, **`SplitApart` (default true)**; para preservar constraints/attachments usar `CalculateConstraintsToPreserve` (sample oficial).
- Negación in-game = tag `rbxNegate` vía `CollectionService` (no hay método engine).
- **Sweep/Fragment y CSG sobre meshes están gated por Beta Feature "Solid Modeling On Meshes"** (File → Beta Features) — el catálogo lo daba por "full release": **CORREGIR**.
- Watertight: reglas oficiales + reparación con Blender (3D Print Toolbox, Mesh Repair Tools) o Meshlab; Blender `Solidify` para shells.
- Specs de rigging: transforms congelados (scale 1,1,1 / rot 0,0,0), root en 0,0,0, **máx 4 influencias por vértice**, sin influencias al root. Animación: **single track por export**. Cages: naming `_InnerCage`/`_OuterCage`. Geometría: watertight, sin N-gons, sin grosor 0.
- → **Para 04/36**: quitar el plan `SeparateAsync`; documentar Separate (Studio) + `SubstituteGeometry()`/`MeshPart:ApplyMesh()`; presupuesto oficial 20k; `SplitApart`; `rbxNegate`; beta gate de Sweep/Fragment; specs numéricas + guía watertight/reparación.
