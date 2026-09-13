# Diseño: Mejoras del catálogo RAASE 2.1 (`raase-catalog-improvements`)

> Fase: sdd-design · Fecha: 2026-09-13 · Store: openspec · Fuente vinculante: `research.md` → Addendum A (docs oficiales de Roblox, verificado 2026-09-13). Ninguna afirmación nueva puede exceder esa evidencia.

## Enfoque técnico

Edición quirúrgica de 6 archivos Markdown de `skills-roblox/`: correcciones dentro de reglas existentes y anexos no numerados. Sin micro-habilidades numeradas nuevas (protege 610/35), sin cambios de frontmatter ni descripciones (protege los índices), sin tocar `agent/raase_skills.json`, `bridge/`, `plugin/` ni `project_template/`. El apply es mecánico: 16 ediciones, cada una con anclaje textual citado y reemplazo acotado.

## Decisiones de arquitectura

| # | Decisión | Alternativas | Racional |
|---|---|---|---|
| D1 | Adiciones en reglas existentes o anexos no numerados | Nuevas reglas `### NNN.` | Una regla nueva altera rangos y exige registro; los anexos preservan 610/35 y el gate strict. |
| D2 | Frontera 07/35: 07 = fundamentos + tabla de migración; 35 = grafo Wire avanzado; cross-refs bidireccionales | Duplicar la tabla en ambos; consolidar todo en 35 | Elimina la duplicación actual sin perder acceso; cada archivo conserva su audiencia. |
| D3 | CSG: correcciones inline en 087/090/091/094/095 + anexo no numerado | Reescribir el bloque 086-095 | El un-merge/negación no corresponde a ninguna regla existente; el resto son reemplazos puntuales. |
| D4 | Índices: verificación no-op por hash (sin edición) | Editar índices "por consistencia" | Las descripciones no cambian; el árbol trae el lote roblox-38 sin commitear y no debe mezclarse. |
| D5 | Anexo 02 sin cifras de rate; reglas 032/051 intactas | Publicar/alinear límites | V20/V21 sin verificar; `rules.design` se honra documentando validación server-side, no números sin fuente. |

## Blueprint de edición

### (a) DevEx — `roblox-09-economy-devex/SKILL.md`

**A1 · Marco de Tasas (L16-19).** Ancla:
```markdown
## Marco de Tasas DevEx 2026
- **Tasa Estándar 2026:** $0.0038 USD por Robux (umbral mínimo de retiro: 30.000 R$ = $114.00 USD).
- **Tasa Preferencial U.S. 18+:** $0.0054 USD por Robux (30.000 R$ = $162.00 USD). Requiere avatares estrictamente en formato R15 y verificación de identidad.
- **Tasa Legada:** $0.0035 USD por Robux para balances generados antes de septiembre de 2025.
```
Cambio: añadir como primer bullet del marco `- **Vigencia verificada:** 2026-09-13 (documentación oficial de Roblox); la tasa 18+ rige desde el 8-jun-2026.`; en L18 reemplazar "Requiere avatares… identidad" por: la verificación de edad/identidad corresponde al **jugador comprador U.S. 18+** (facial age estimation o government ID) y aplica a developer products, passes, subscriptions y private servers en juegos elegibles; en L19: "saldos anteriores al 5-sep-2025, 10 a. m. PT". Conservar los ejemplos $114.00/$162.00. Estilo: bullets `- **Nombre:**` existentes.

**A2 · Regla 218 (L45).** Ancla: `- **Regla:** Auditar y certificar que la experiencia califique para la tasa preferencial U.S. 18+ de $0.0054 USD por Robux cumpliendo los requisitos de identidad y formato de juego.`
Reemplazo: criterios verificados — 100 % del playtime como R15 platform; human-form custom (cabeza + 2 brazos + 2 piernas; 12 limb parts O 12 limb joints distribuidas; torso ≥2; bípedo completo) **o** nonhuman-form custom (también califica); sin R6 en ningún momento; animation packs R15; NPCs no se evalúan.

**A3 · Regla 219 (L48).** Ancla: `- **Regla:** Excluir avatares R6 legados e imponer personajes R15 modernos en StarterPlayer.GameSettings para calificar a la tasa preferencial U.S. 18+ ($0.0054/R).`
Reemplazo: `- **Regla:** La exigencia R15 aplica al sistema de avatares platform para la tasa 18+ (correr 100 % en R15, sin R6); no es requisito del DevEx estándar.` → cero ocurrencias de `StarterPlayer.GameSettings`.

**A4 · Regla 220 (L51).** Ancla: `- **Regla:** Verificar que la cuenta de desarrollo supere el umbral mínimo oficial de 30.000 Robux ganados legítimamente antes de solicitar DevEx.`
Edición: conservar el umbral 30.000 R$ y añadir `(requisitos base: 13+, email verificado, portal DevEx, formularios W-9/W-8)`.

### (b) Audio — `roblox-07-audio-dsp/SKILL.md` + `roblox-35-dynamic-audio-music/SKILL.md`

**B1 · Anexo nuevo al final de 07 (tras L83).** Título exacto: `## 🔁 Anexo: Migración legacy → Audio API (tabla de equivalencias)`. Skeleton:
- Intro: los efectos legacy `*SoundEffect` conviven con los nodos modernos de la Audio API (verificado 2026-09-13).
- Tabla de 2 columnas, exactamente 8 filas (nada más): `DistortionSoundEffect`→`AudioDistortion`; `EqualizerSoundEffect`→`AudioEqualizer`; `ReverbSoundEffect`→`AudioReverb`; `CompressorSoundEffect`→`AudioCompressor`; `ChorusSoundEffect`→`AudioChorus`; `FlangeSoundEffect`→`AudioFlanger`; `TremoloSoundEffect`→`AudioTremolo`; `EchoSoundEffect`→`AudioEcho`.
- Nota de orden: el orden de los efectos altera el resultado (Chorus→Distortion ≠ Distortion→Chorus).
- Cross-ref 07→35: "El grafo Wire avanzado se documenta en [roblox-35-dynamic-audio-music](../roblox-35-dynamic-audio-music/SKILL.md)."
Estilo: anexo `## ...` no numerado como el existente (L80); no se tocan las reglas 166-185.

**B2 · Enumeración de nodos en 35 (L235).** Ancla (bullet de nodos de cableado): `procesadores de señal (AudioFilter, AudioPitchShifter, AudioFader) hacia emisores 3D`.
Edición: extender el paréntesis, antes de "hacia emisores 3D", con los seis nodos: `AudioDistortion`, `AudioEcho`, `AudioCompressor`, `AudioEqualizer`, `AudioTremolo`, `AudioFlanger` (quedan 9 procesadores nombrados).

**B3 · Bullet nuevo al cierre del anexo de 35 (tras L236).** Redacción base: `- **Frontera con roblox-07:** esta skill cubre el grafo Wire avanzado; los fundamentos de DSP y la tabla de migración legacy→moderna viven en [roblox-07-audio-dsp](../roblox-07-audio-dsp/SKILL.md).`

### (c) Remotos — `roblox-02-netsec/SKILL.md`

**C1 · Anexo nuevo al final de 02 (tras L133).** Título exacto: `## 📡 Anexo: Plumbing canónico de remotos (cliente ↔ servidor)`. Skeleton (bullets, sin numerar):
- Cliente→servidor (intención→validación→respuesta), snippet mínimo con `--!strict`:
```luau
-- Cliente
remoteEvent:FireServer(actionName, targetPart)

-- Servidor
remoteEvent.OnServerEvent:Connect(function(player: Player, actionName: string, targetPart: Instance)
    if typeof(actionName) ~= "string" or typeof(targetPart) ~= "Instance" then
        return -- validación de tipos (026)
    end
    -- distancia (029) + rate limiter (032) antes de ejecutar; luego responder:
    remoteEvent:FireClient(player, "ack")
end)
```
- Servidor→cliente: `FireClient(player, …)` + `OnClientEvent`; `FireAllClients` para difusión.
- Tabla decisión Reliable/Unreliable (5 filas): confiabilidad, orden, dirección (one-way), uso (datos continuos o no críticos), misma superficie de métodos/eventos que `RemoteEvent`.
- Riesgos de `InvokeClient`: el error del cliente se propaga al servidor; disconnect → error; sin retorno → el servidor yieldea indefinidamente; preferir `RemoteEvent` para server→client de una vía.
- Limitaciones de argumentos (7): índices no-string → string; funciones → `nil`; no mezclar claves numéricas y string; evitar `nil`; tablas copiadas (identidad perdida); metatables perdidas; instancias no replicables → `nil`.
- Guarda: sin cifras de rate (V20/V21 no verificadas).
Estilo: el anexo existente (L129-133) es el precedente; el nuevo va después, sin numerar ítems; snippets `--!strict` como en otros dominios.

### (d) CSG/specs — `roblox-04-3d-world-csg/SKILL.md` + `roblox-36-asset-pipeline/SKILL.md`

**D1 · Regla 087 (L27).** Ancla: `- **Regla:** Respetar el presupuesto poligonal por objeto (máximo 4,000 a 10,000 triángulos según categoría) para mantener 60 FPS estables.`
Reemplazo: `... límite oficial de 20,000 triángulos por mesh individual; las operaciones CSG que exceden el tope simplifican el resultado a 20k (o fallan si no se puede). Mantener 60 FPS estables.` → el rango "4,000 a 10,000" desaparece.

**D2 · Regla 090 (L36).** Ancla: `... no posean caras invertidas ni huecos para evitar operaciones fallidas.`
Edición: añadir, justo bajo la regla 090, el bullet `- **Reparación (watertight):** Blender (3D Print Toolbox, Mesh Repair Tools) o Meshlab reparan huecos y caras invertidas; Solidify de Blender da grosor a shells.`

**D3 · Regla 091 (L39).** Ancla: `... GeometryService:UnionAsync() de forma asíncrona para combinar geometrías sin bloquear el hilo de ejecución principal.`
Edición: añadir opciones verificadas: `CollisionFidelity`, `RenderFidelity`, `SplitApart` (default `true`) y `CalculateConstraintsToPreserve`.

**D4 · Regla 094 (L48).** Ancla: `- **Regla:** Generar extrusiones dinámicas de geometrías a lo largo de curvas con GeometryService:SweepPartAsync().`
Edición: añadir `(requiere la Beta Feature "Solid Modeling On Meshes", File → Beta Features; no es release pleno)`.

**D5 · Regla 095 (L51).** Ancla: `- **Regla:** Fragmentar mallas sólidas de forma dinámica para efectos de destrucción procedural en tiempo de ejecución.`
Reemplazo: `- **Regla:** Fragmentar mallas sólidas de forma dinámica con GeometryService:FragmentAsync() para efectos de destrucción procedural en tiempo de ejecución (requiere la Beta Feature "Solid Modeling On Meshes", File → Beta Features; no es release pleno).`

**D6 · Anexo nuevo al final de 04 (tras L111).** Título exacto: `## 🧱 Anexo: Un-merge, negación y CSG sobre meshes (notas)`. Bullets:
- Un-merge: no existe API in-game de separación; el Separate de Studio (Shift+Ctrl+U) es la única vía (se deshace en el editor, no por script).
- Negación in-game: tag `rbxNegate` vía `CollectionService`.
- Reemplazo de geometría: `SubstituteGeometry()` / `MeshPart:ApplyMesh()`.
- Beta gate: `SweepPartAsync`, `FragmentAsync` y el CSG sobre meshes requieren la Beta Feature "Solid Modeling On Meshes" (File → Beta Features).
Estilo: anexo no numerado (04 no tenía anexo; patrón del catálogo en 02/07/35).

**E1 · Regla 2 de 36 (L96).** Ancla: `props ≤ 5,000 tris; héroes/armas ≤ 20,000; flipbooks: atlas ≤ 1,024 px ...`
Edición: precisar `héroes/armas ≤ 20,000 (tope oficial por mesh individual; alineado con roblox-04)`.

**E2 · Handoff de 36 (paso 5, tras L83).** Bullet nuevo (sub-bullets con la indentación existente): `- **Requisitos de exportación verificados** (confirmar antes de importar):` → transform congelado (`scale (1,1,1)`, `rot (0,0,0)`) y root en `(0,0,0)`; máx. 4 influencias por vértice, sin influencias al root; un solo track de animación por export; cages `_InnerCage`/`_OuterCage`; geometría watertight, sin N-gons, sin grosor 0.

## Frontera 07/35 (contrato)

- 07 = fundamentos + tabla de migración legacy→moderna; 35 = grafo Wire avanzado.
- 07→35: última línea del anexo B1. 35→07: bullet B3. Cross-refs bidireccionales obligatorios.
- Prohibido duplicar una misma receta en ambos; sin recetas de zonas multi-reverb ni técnicas "sin scripting" (V13/V14).

## Orden de apply

1. `roblox-09` (A1-A4): riesgo dinero/legal máximo; archivo aislado.
2. `roblox-04` + `roblox-36` (D1-D6, E1-E2): par con presupuesto compartido (20k) y specs de import.
3. `roblox-07` + `roblox-35` (B1-B3): la frontera y los cross-refs entran juntos.
4. `roblox-02` (C1): anexo más extenso, directo del Addendum A.
5. Cierre: verificación completa (sección siguiente).

Coincide con el split propuesto (PR1 = 09 + 04/36; PR2 = 07/35 + 02 + cierre) si `sdd-tasks` confirma >400 líneas.

## Verificación (estrategia de prueba)

| Capa | Qué valida | Cómo |
|---|---|---|
| Estructural | 39/39 skills, frontmatter sano | `node "C:\Users\j1347\Desktop\skills\00-meta-skills\skill-validator\scripts\validate-skills.mjs" "skills-roblox" --strict` → 39/39, exit 0 (desde la raíz) |
| Conteos | 39 / 610 / 35 | `(Get-ChildItem skills-roblox -Recurse -Filter SKILL.md).Count` = 39; `Select-String -Path "skills-roblox\*\SKILL.md" -Pattern '^### \d{3}\.'` = 610 (35 dominios; 0 en 36-38/engineer) |
| Sin reglas nuevas | 0 `### NNN.` añadidos | salida de `git diff -U0` sobre los 6 archivos sin líneas que casen `^\+.*### \d{3}\.` → 0 |
| Exclusiones | `SeparateAsync`, `AudioLimiter`, `AudioGate` ausentes en ARCHIVOS FINALES; `StarterPlayer.GameSettings` ausente en líneas AGREGADAS (existe como línea removida `-` en 09); sin cifras de rate nuevas | grep sobre los 6 archivos finales → 0 para los tres tokens; `git diff -U0 -- <file>` sin `^\+.*StarterPlayer\.GameSettings`; diff de 02 sin hunks en reglas 032 (L41) ni 051 (L98) |
| Aislamiento | solo los 6 archivos; índices no-op | `git diff --stat -- <6 archivos>`; hashes pre/post de `SKILLS.md`, `AGENTS.md`, `.atl/skill-registry.md` idénticos; diffs por archivo con `git diff -- <file>` (nunca sin filtro: hay lote roblox-38 sin commitear) |
| Contenido | hechos del Addendum A; cross-refs; descripciones intactas | lectura de vuelta de los 6 archivos; diff sin tocar frontmatter |

## Non-changes explícitos

`agent/raase_skills.json`; los 3 índices; frontmatter/descripciones de los 6 archivos; `roblox-18` (solo auditoría V9, sin edición factual); `roblox-11`, `CLAUDE.md` raíz y `SOURCES.md`; reglas 032/051 de 02; reglas 086/088/089/092/093/096-115 de 04; reglas 1/3/4/5/6 y pasos 4/6 de 36; `bridge/`, `plugin/`, `project_template/`.

## Rollback

Los 6 archivos están limpios en HEAD (verificado 2026-09-13): revertir por archivo con `git checkout -- skills-roblox/<skill>/SKILL.md` (6 comandos). **Nunca `git checkout -- .`**: revertiría el lote roblox-38 sin commitear. `openspec/` está untracked: el change completo se cancela borrando `openspec/changes/raase-catalog-improvements/`.

## Matriz de amenazas

N/A — cambio solo Markdown; sin routing, shell, subprocesos, automatización VCS/PR, clasificación de ejecutables ni integración de procesos.

## Open Questions

Ninguna bloqueante. Fuera de alcance declarado: cifras de rate de remotos (V20/V21), formatos del importer/Scale Unit (V24/V27), alcance Creator Store de 18 (V9 → follow-up).
