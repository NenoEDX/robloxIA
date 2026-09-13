---
name: roblox-07-audio-dsp
description: "Rige el procesamiento de audio espacial y DSP (skills 166-185): SoundGroups, curvas de atenuación roll-off, ecualización contextual, compresión ducking, reverb por zonas y la Audio API 2026 de grafos de nodos. Úsala al mezclar sonido, implementar audio 3D, pasos por material o música interactiva."
license: MIT
allowed-tools: Read Write Bash(node:*,luau-lsp:*,rojo:*,wally:*)
metadata:
  domain: "Audio & DSP Effects"
  range: "166-185"
  author: "RAASE 2.0 / robloxIA"
---

# roblox-07-audio-dsp — Audio Espacial, Efectos DSP y Sonido Dinámico (Skills 166 - 185)

Este módulo rige el diseño acústico, procesamiento de señal (DSP) y espacialización sonora en Roblox Studio.

## Catálogo de Habilidades Técnicas

### 166. `audio-sound-service-master-bus`
- **Regla:** Organizar el árbol de sonido en `SoundService` mediante `SoundGroup` principales (Master, Music, SFX, Voice, Ambience).

### 167. `audio-spatial-roll-off-calibration`
- **Regla:** Calibrar `RollOffMinDistance` y `RollOffMaxDistance` con curva `InverseTapered` para caída natural de volumen en sonidos 3D.

### 168. `audio-sound-regions-part-bounds`
- **Regla:** Activar música y ambientes acústicos según la posición del jugador dentro de regiones espaciales delimitadas.

### 169. `audio-equalizer-muffled-effect`
- **Regla:** Conectar un `EqualizerSoundEffect` atenuando frecuencias agudas al sumergirse bajo el agua o estar tras una pared.

### 170. `audio-reverb-environmental-spaces`
- **Regla:** Modular `ReverbSoundEffect` diferenciando salas pequeñas, cavernas húmedas o catedrales resonantes.

### 171. `audio-compressor-side-chain`
- **Regla:** Atenuar automáticamente la música (`ducking`) mediante `CompressorSoundEffect` cuando se reproduce una línea de voz o explosión.

### 172. `audio-distortion-effect-radio`
- **Regla:** Aplicar `DistortionSoundEffect` sutil para simular transmisiones de radio de walkie-talkie.

### 173. `audio-pitch-shift-sound-variation`
- **Regla:** Variar `PlaybackSpeed` aleatoriamente (+/- 10%) en disparos o impactos para evitar fatiga auditiva.

### 174. `audio-dynamic-cross-fader`
- **Regla:** Transicionar suavemente entre pistas musicales modulando sus volúmenes de forma proporcional cruzada.

### 175. `audio-footstep-material-detector`
- **Regla:** Consultar el material de la superficie pisada por el personaje para disparar el sonido de paso correspondiente.

### 176. `audio-doppler-effect-vehicles`
- **Regla:** Escalar la frecuencia de sonido en vehículos a alta velocidad según el vector de movimiento relativo a la cámara.

### 177. `audio-concurrency-sound-pooling`
- **Regla:** Limitar el número de instancias sonoras simultáneas de un mismo tipo para evitar saturación del mezclador.

### 178. `audio-listener-camera-character-toggle`
- **Regla:** Conmutar `SoundService:SetListener()` entre la cámara y la cabeza del personaje según la perspectiva (1ª o 3ª persona).

### 179. `audio-occlusion-muffling-system`
- **Regla:** Trazar raycasts entre la fuente de sonido y la oreja del oyente; si colisiona con una pared, aplicar filtro pasa-bajos.

### 180. `audio-ambient-day-night-cycle`
- **Regla:** Interpolar sonidos ambientales (aves de día, grillos y viento de noche) según `Lighting.ClockTime`.

### 181. `audio-heartbeat-low-health-warning`
- **Regla:** Disparar latido rítmico acelerado y atenuar el resto de canales cuando la salud del jugador caiga por debajo del 25%.

### 182. `audio-ui-sfx-feedback-suite`
- **Regla:** Diseñar una biblioteca unificada de efectos de interfaz (clicks, alertas de error, recompensas) en un bus prioritario.

### 183. `audio-wire-wiring-node-graph`
- **Regla:** Conectar fuentes, filtros y salidas mediante la arquitectura de cables de la Audio API 2026.

### 184. `audio-pitch-tempo-scaling`
- **Regla:** Modular el tono y velocidad de reproducción armónicamente para efectos de cámara lenta (*bullet time*).

### 185. `audio-copyright-asset-validator`
- **Regla:** Verificar que los identificadores de audio utilizados cumplan con las licencias y políticas de derechos de Roblox.

---

## 🎧 Anexo: Simulación Acústica Avanzada (Acoustic Simulation)
La arquitectura de audio 2026 permite una simulación física del sonido:
1. **Oclusión y Obstrucción:** Se calcula el ángulo y espesor de las paredes interpuestas mediante raycasting multi-muestra; la obstrucción atenúa la energía directa preservando el rebote tardío, mientras que la oclusión total filtra todas las frecuencias superiores a 800 Hz.
2. **Audio API Wire Graph:** Reemplazo de los emisores tradicionales por grafos formales con `AudioPlayer`, `AudioEmitter`, `AudioListener` y cables `Wire`, permitiendo encadenar efectos DSP arbitrarios por nodo antes de la espacialización.

## 🔁 Anexo: Migración legacy → Audio API (tabla de equivalencias)
Los efectos legacy `*SoundEffect` conviven con los nodos modernos de la Audio API (verificado 2026-09-13); equivalencias directas:

| Efecto legacy (`*SoundEffect`) | Nodo moderno (Audio API) |
|---|---|
| `DistortionSoundEffect` | → `AudioDistortion` |
| `EqualizerSoundEffect` | → `AudioEqualizer` |
| `ReverbSoundEffect` | → `AudioReverb` |
| `CompressorSoundEffect` | → `AudioCompressor` |
| `ChorusSoundEffect` | → `AudioChorus` |
| `FlangeSoundEffect` | → `AudioFlanger` |
| `TremoloSoundEffect` | → `AudioTremolo` |
| `EchoSoundEffect` | → `AudioEcho` |

- **Orden de efectos:** el orden de la cadena altera el resultado: `Chorus→Distortion` ≠ `Distortion→Chorus`.
- **Frontera:** el grafo Wire avanzado se documenta en [roblox-35-dynamic-audio-music](../roblox-35-dynamic-audio-music/SKILL.md).
