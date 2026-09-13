# Audio Legacy Modern Mapping Specification

## Purpose

Tabla de equivalencias legacy↔moderna, nodos modernos faltantes y frontera editorial entre `roblox-07-audio-dsp` (fundamentos y migración) y `roblox-35-dynamic-audio-music` (grafo Wire avanzado). Solo clases confirmadas por el Addendum A (docs oficiales de efectos de audio, 2026-09-13).

## Requirements

### Requirement: Tabla de equivalencias legacy ↔ moderna

`roblox-07` MUST incluir en su anexo de audio una tabla con exactamente estas 8 equivalencias: Distortion→`AudioDistortion`, Equalizer→`AudioEqualizer`, Reverb→`AudioReverb`, Compressor→`AudioCompressor`, Chorus→`AudioChorus`, Flange→`AudioFlanger`, Tremolo→`AudioTremolo`, Echo→`AudioEcho`.

#### Scenario: Tabla completa

- GIVEN un lector de `roblox-07-audio-dsp`
- WHEN abre el anexo de audio
- THEN encuentra una tabla con las 8 filas legacy→moderna
- AND cada clase moderna coincide con el nombre confirmado del Addendum A

#### Scenario: Sin clases fuera de la evidencia

- GIVEN la tabla final
- WHEN se buscan clases modernas adicionales
- THEN no lista ninguna fuera de las 8 equivalencias anteriores

### Requirement: Nota de orden de efectos

La tabla o su nota al pie MUST advertir que el orden de los efectos altera el resultado, con el ejemplo Chorus→Distortion ≠ Distortion→Chorus.

#### Scenario: Advertencia presente

- GIVEN el anexo de `roblox-07`
- WHEN el lector busca la nota de orden
- THEN encuentra la advertencia con el ejemplo de orden invertido

### Requirement: Nodos modernos faltantes en roblox-35

`roblox-35` MUST añadir al anexo Wire (o a sus enumeraciones de nodos) las clases `AudioDistortion`, `AudioEcho`, `AudioCompressor`, `AudioEqualizer`, `AudioTremolo` y `AudioFlanger`.

#### Scenario: Nodos añadidos

- GIVEN un lector de `roblox-35-dynamic-audio-music`
- WHEN revisa el anexo Wire
- THEN encuentra los seis nodos modernos faltantes
- AND puede mapearlos contra la tabla legacy de `roblox-07`

### Requirement: Frontera editorial 07/35 con cross-referencias

`roblox-07` MUST quedar como fundamentos + tabla de migración legacy→moderna; `roblox-35` MUST quedar como grafo Wire avanzado. Cada archivo MUST referenciar explícitamente al otro; MUST NOT duplicarse una misma receta en ambos.

#### Scenario: Cross-referencias bidireccionales

- GIVEN ambos archivos finales
- WHEN el lector busca referencias cruzadas
- THEN `roblox-07` referencia a `roblox-35` y viceversa
- AND no hay recetas de zona duplicadas entre ambos

### Requirement: Exclusiones no verificadas

El catálogo MUST NOT publicar `AudioLimiter`, `AudioGate`, recetas de zonas multi-reverb ni técnicas "sin scripting" (no confirmadas en el Addendum A; V13/V14).

#### Scenario: Clases y recetas ausentes

- GIVEN `roblox-07` y `roblox-35` finales
- WHEN se busca `AudioLimiter`, `AudioGate` o recetas de zonas multi-reverb
- THEN hay cero ocurrencias
