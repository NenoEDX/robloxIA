---
name: roblox-35-dynamic-audio-music
description: "Rige el diseño acústico, paisajes sonoros adaptativos y la Audio API 2026 en Roblox (skills 596-610): arquitectura modular de nodos con Wire (AudioPlayer, AudioFader, AudioPitchShifter, AudioChorus, AudioFilter), transiciones musicales crossfade, mezcla vertical por stems sincronizados, análisis espectral reactivo con AudioAnalyzer, oclusión acústica geométrica por raycast y gestión de voz espacial. Úsala al construir bandas sonoras dinámicas, efectos ambientales inmersivos, respuesta audiovisual rítmica y sistemas de audio 3D."
license: MIT
allowed-tools: Read Write Bash(node:*,luau-lsp:*,rojo:*,wally:*)
metadata:
  domain: "Dynamic Music & Adaptive Soundscapes"
  range: "596-610"
  author: "RAASE 2.1 / robloxIA"
---

# roblox-35-dynamic-audio-music — Música Adaptativa, Audio API 2026 y Paisajes Sonoros (Skills 596 - 610)

Este módulo establece los estándares de ingeniería de sonido, grafos de procesamiento digital de señales (DSP) y música interactiva adaptativa bajo Luau 2026.

## Catálogo de Habilidades Técnicas

### 596. `audio-adaptive-music-crossfader`
- **Regla:** Las transiciones entre pistas musicales de exploración, tensión y combate deben realizarse mediante interpolación de volumen (*crossfade*) en lugar de cortes abruptos.
- **Ejemplo:**
  ```luau
  --!strict
  local TweenService = game:GetService("TweenService")

  local function crossfadePlayers(currentFader: AudioFader, nextFader: AudioFader, duration: number)
      local fadeOutTween = TweenService:Create(currentFader, TweenInfo.new(duration), { Volume = 0.0 })
      local fadeInTween = TweenService:Create(nextFader, TweenInfo.new(duration), { Volume = 1.0 })

      fadeOutTween:Play()
      fadeInTween:Play()
  end
  ```

### 597. `audio-2026-wire-graph-architecture`
- **Regla:** Emplear la arquitectura basada en grafos de la Audio API 2026 conectando explícitamente instancias mediante cables virtuales `Wire`.
- **Ejemplo:**
  ```luau
  --!strict
  local function connectAudioNodes(source: Instance, target: Instance): Wire
      local wire = Instance.new("Wire")
      wire.SourceInstance = source
      wire.TargetInstance = target
      wire.Parent = source
      return wire
  end
  ```

### 598. `audio-fader-dynamic-gain-control`
- **Regla:** Modular la ganancia sonora en tiempo real utilizando la propiedad `Volume` de una instancia `AudioFader`, evitando artefactos de chasquido o sobremodulación (*clipping* digital).
- **Ejemplo:**
  ```luau
  --!strict
  local function setSmoothVolume(fader: AudioFader, targetVolume: number, transitionTime: number)
      local tween = game:GetService("TweenService"):Create(fader, TweenInfo.new(transitionTime, Enum.EasingStyle.Quad), {
          Volume = math.clamp(targetVolume, 0.0, 1.0),
      })
      tween:Play()
  end
  ```

### 599. `audio-pitch-shifter-bullet-time`
- **Regla:** En efectos de tiempo ralentizado (*bullet time*) o aturdimiento, reducir la propiedad `Pitch` de un `AudioPitchShifter` acoplado al canal de mezcla principal sin afectar la tasa de ticks de la lógica del juego.
- **Ejemplo:**
  ```luau
  --!strict
  local function applyBulletTimePitch(shifter: AudioPitchShifter, isSlowMo: boolean)
      local targetPitch = if isSlowMo then 0.65 else 1.0
      game:GetService("TweenService"):Create(shifter, TweenInfo.new(0.35), {
          Pitch = targetPitch,
      }):Play()
  end
  ```

### 600. `audio-chorus-flanger-underwater-fx`
- **Regla:** Para ambientes subacuáticos o estados de confusión, acoplar en serie un `AudioChorus` junto a un `AudioFilter` en modo pasa-bajos (*Lowpass*) configurando una frecuencia de corte de 800 Hz.
- **Ejemplo:**
  ```luau
  --!strict
  local function configureUnderwaterDSPs(chorus: AudioChorus, filter: AudioFilter)
      chorus.Depth = 0.4
      chorus.Rate = 0.5
      filter.FilterType = Enum.AudioFilterType.Lowpass
      filter.CutoffFrequency = 800
  end
  ```

### 601. `audio-analyzer-spectrum-reactivity`
- **Regla:** Para que luces o efectos de interfaz reaccionen al ritmo musical, muestrear el espectro de frecuencias mediante `AudioAnalyzer:GetSpectrum()` y extraer la energía en las bandas de graves (20 a 150 Hz).
- **Ejemplo:**
  ```luau
  --!strict
  local function readBassIntensity(analyzer: AudioAnalyzer): number
      local spectrum = analyzer:GetSpectrum()
      local bassSum = 0
      local sampleCount = math.min(#spectrum, 8) -- Primeros bins corresponden a frecuencias bajas
      for i = 1, sampleCount do
          bassSum += spectrum[i]
      end
      return if sampleCount > 0 then (bassSum / sampleCount) else 0
  end
  ```

### 602. `audio-geometry-spatial-occlusion`
- **Regla:** Trazar un rayo entre la fuente emisora 3D y la cámara del jugador. Si se detectan muros intermedios, atenuar la frecuencia de corte del `AudioFilter` local a 1200 Hz para simular amortiguación acústica por masa.
- **Ejemplo:**
  ```luau
  --!strict
  local function updateOcclusion(emitterPart: BasePart, listenerCFrame: CFrame, filter: AudioFilter)
      local origin = emitterPart.Position
      local direction = listenerCFrame.Position - origin
      local params = RaycastParams.new()
      params.FilterType = Enum.RaycastFilterType.Exclude
      params.FilterDescendantsInstances = { emitterPart }

      local hit = workspace:Raycast(origin, direction, params)
      if hit and hit.Instance.CanCollide then
          filter.CutoffFrequency = 1200 -- Ocluido tras pared
      else
          filter.CutoffFrequency = 20000 -- Visión directa
      end
  end
  ```

### 603. `audio-reverb-dynamic-zone-switching`
- **Regla:** Modificar suavemente los parámetros de un nodo `AudioReverb` (DecayTime, Density) al cruzar los límites volumétricos de una zona acústica cerrada (e.g. cueva vs planicie).
- **Ejemplo:**
  ```luau
  --!strict
  local function setCathedralReverb(reverb: AudioReverb)
      reverb.DecayTime = 3.5
      reverb.Density = 0.85
      reverb.Diffusion = 0.9
  end
  ```

### 604. `audio-layered-stem-mixing`
- **Regla:** En pistas compuestas por capas multicanal (*stems* sincronizados), mantener reproduciéndose todas las capas en bucle al unísono y controlar la intensidad de la escena modulando los faders individuales de percusión y metales.
- **Ejemplo:**
  ```luau
  --!strict
  export type MusicStems = { drums: AudioFader, bass: AudioFader, melody: AudioFader }

  local function setCombatTension(stems: MusicStems, inCombat: boolean)
      local drumVolume = if inCombat then 1.0 else 0.0
      stems.drums.Volume = drumVolume
  end
  ```

### 605. `audio-device-input-voice-chat-routing`
- **Regla:** Al enrutar la voz espacial de los jugadores mediante `AudioDeviceInput`, interconectar un `AudioPitchShifter` o `AudioFilter` para emular efectos de walkie-talkie o megafonía.
- **Ejemplo:**
  ```luau
  --!strict
  local function routeWalkieTalkieVoice(deviceInput: AudioDeviceInput, emitter: AudioEmitter, filter: AudioFilter)
      filter.FilterType = Enum.AudioFilterType.Bandpass
      filter.CutoffFrequency = 1800
  end
  ```

### 606. `audio-limiter-ducking-compression`
- **Regla:** Atenuar automáticamente la música de fondo (*audio ducking*) a un 30% de su volumen cuando un locutor o diálogo empiece a sonar, restableciéndola al culminar la locución.
- **Ejemplo:**
  ```luau
  --!strict
  local function applyDucking(musicFader: AudioFader, dialogueFader: AudioFader, onDialogueStart: () -> ())
      musicFader.Volume = 0.3
  end
  ```

### 607. `audio-distance-attenuation-rolloff`
- **Regla:** Configurar `AudioEmitter` con distancias de atenuación explícitas: `DistanceAttenuation` calibrado con caída realista para que el sonido no invada salas adyacentes innecesariamente.
- **Ejemplo:**
  ```luau
  --!strict
  local function setupEmitterDistances(emitter: AudioEmitter, minDistance: number, maxDistance: number)
      -- En AudioEmitter, calibrar atenuación espacial
      emitter.Parent = workspace
  end
  ```

### 608. `audio-procedural-footstep-material-audio`
- **Regla:** Al emitir sonidos de pasos, inspeccionar `RaycastResult.Material` bajo los pies del personaje y seleccionar aleatoriamente una variación acústica entre al menos 3 grabaciones del mismo material.
- **Ejemplo:**
  ```luau
  --!strict
  local function getFootstepAsset(material: Enum.Material): string
      if material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
          return "rbxassetid://WOOD_STEP_1"
      elseif material == Enum.Material.Grass then
          return "rbxassetid://GRASS_STEP_1"
      else
          return "rbxassetid://CONCRETE_STEP_1"
      end
  end
  ```

### 609. `audio-silent-zone-acoustic-baffle`
- **Regla:** Definir zonas de amortiguación acústica en recintos protegidos o menús de pausa donde el volumen maestro ambiental decaiga de forma paramétrica.
- **Ejemplo:**
  ```luau
  --!strict
  local function applyPauseMuffle(masterFilter: AudioFilter)
      masterFilter.FilterType = Enum.AudioFilterType.Lowpass
      masterFilter.CutoffFrequency = 600
  end
  ```

### 610. `audio-graph-cleanup-janitor`
- **Regla:** Todo nodo de audio temporal y sus cables virtuales `Wire` deben desconectarse y destruirse mediante `Janitor` para evitar saturar el subsistema de procesamiento de sonido de Roblox.
- **Ejemplo:**
  ```luau
  --!strict
  local function cleanupAudioGraph(player: AudioPlayer, wire: Wire)
      wire.SourceInstance = nil
      wire.TargetInstance = nil
      wire:Destroy()
      player:Stop()
      player:Destroy()
  end
  ```

## Reglas Inviolables

1. **Topología Wire explícita:** Toda conexión de audio moderno debe modelarse con instancias `Wire` explícitamente enlazadas. Prohibido depender de mezclas acústicas no controladas.
2. **Interpolación sin chasquidos:** Queda estrictamente prohibido alterar volúmenes bruscamente entre 0 y 1; utilizar siempre `TweenService` o `AudioFader` con interpolaciones suaves.
3. **Sincronía estricta de Stems:** Todas las pistas de música por capas deben inicializarse al mismo instante temporal para garantizar que los compases permanezcan en fase.
4. **Presupuesto de Raycasts de oclusión:** El cálculo de oclusión sonora geométrica debe ejecutarse a una frecuencia máxima de 10 Hz o limitarse al movimiento del oyente para no malgastar tiempo de CPU.
5. **Desconexión y reciclaje de grafos:** Todo cable `Wire` y nodo de efecto debe ser liberado explícitamente al culminar su reproducción para prevenir fugas de recursos en el motor de audio.


---

## 🎧 Anexo: Simulación Acústica y Wire Graph 2026
La Audio API 2026 transforma la infraestructura de sonido de Roblox:
- **Nodos de Cableado (Wires):** Permiten encadenar salidas sonoras (`AudioPlayer`, `AudioDeviceInput`) con procesadores de señal (`AudioFilter`, `AudioPitchShifter`, `AudioFader`, `AudioDistortion`, `AudioEcho`, `AudioCompressor`, `AudioEqualizer`, `AudioTremolo`, `AudioFlanger`) hacia emisores 3D (`AudioEmitter`) o el oyente del jugador (`AudioListener`).
- **Acústica Fisiológica y Geométrica:** Permite oclusión dependiente de la densidad de materiales de los muros y reverberación dinámica calculada por el volumen espacial de la habitación.
- **Frontera con roblox-07:** esta skill cubre el grafo Wire avanzado; los fundamentos de DSP y la tabla de migración legacy→moderna viven en [roblox-07-audio-dsp](../roblox-07-audio-dsp/SKILL.md).
