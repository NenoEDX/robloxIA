---
name: roblox-02-netsec
description: "Rige la seguridad de red cliente-servidor Zero-Trust (skills 026-060): validación de remotes con Token Bucket, honeypots anti-RemoteSpy, verificación espacial y de tipos, UnreliableRemoteEvents, defensa anti-exploit y simulación autoritativa en el servidor. Úsala al diseñar cualquier RemoteEvent o RemoteFunction, endpoint sensible o protección contra exploiters."
license: MIT
allowed-tools: Read Write Bash(node:*,luau-lsp:*,rojo:*,wally:*)
metadata:
  domain: "Networking & Anti-Exploit Security"
  range: "026-060"
  author: "RAASE 2.1 / robloxIA"
---

# roblox-02-netsec — Redes Autoritativas, Seguridad y Anti-Exploits (Skills 026 - 060)

Este módulo establece los estándares de seguridad de red inviolables para experiencias de Roblox en 2026.

## Principio Fundamental: Zero-Trust Client
El cliente de Roblox se ejecuta en la máquina del usuario y debe considerarse **100% comprometido y hostil**. El cliente solo tiene permiso para enviar intenciones de entrada (*inputs*); el servidor valida y ejecuta todo cambio de estado.

## Catálogo de Habilidades Técnicas

### 026. `net-server-authoritative-model`
- **Regla:** Salud, daño, monedas, inventarios, transacciones y posición legal se calculan exclusivamente en el servidor.
- **Prohibido:** Que el cliente declare "Me hice 50 de daño" o "Compré este ítem por 10 monedas".

### 027. `net-remote-payload-validation`
- **Regla:** Validar con `typeof()` el tipo y forma exacta de cada parámetro entrante en `RemoteEvent.OnServerEvent`.

### 028. `net-packet-size-sanitization`
- **Regla:** Rechazar cadenas de texto superiores a 500 caracteres o tablas con más de 50 elementos para prevenir ataques de desbordamiento de memoria (OOM / packet flooding).

### 029. `net-spatial-distance-validation`
- **Regla:** Validar la distancia euclidiana entre el personaje y el objeto con el que interactúa (`.Magnitude <= 15`).

### 030. `net-raycast-server-verification`
- **Regla:** En armas de fuego y proyectiles, trazar un rayo en el servidor (`workspace:Raycast`) para confirmar línea de visión antes de registrar impactos.

### 031. `net-contextual-state-verification`
- **Regla:** No procesar acciones de un jugador si su personaje está muerto (`Humanoid.Health <= 0`), congelado, aturdido o en cooldown.

### 032. `net-remote-rate-limiter`
- **Regla:** Todo `RemoteEvent` debe contar con un limitador de tasa Token Bucket por jugador (ej: máx 20 tokens, recarga de 5/seg). Si se agotan los tokens, descartar paquetes y alertar telemetría.

### 033. `net-unreliable-remote-sync`
- **Regla:** Usar `UnreliableRemoteEvent` para sincronizar datos cosméticos de alta frecuencia (efectos de partículas, orientación de torretas, destellos de disparo).

### 034. `net-reliable-transactional-remotes`
- **Regla:** Reservar `RemoteEvent` estándar únicamente para eventos de cambio de estado críticos (compras, muertes, inicio de rondas, apertura de cofres).

### 035. `net-dynamic-remote-instantiation`
- **Regla:** Instanciar remotos dinámicamente en tiempo de ejecución alojados en carpetas protegidas en `ReplicatedStorage.Remotes`.

### 036. `net-unidirectional-remote-policing`
- **Regla:** Si un cliente invoca un `RemoteEvent` concebido solo para dispararse de Servidor a Cliente, expulsar inmediatamente al jugador con `player:Kick()`.

### 037. `net-honeypot-decoy-remotes`
- **Regla:** Desplegar remotos trampa con nombres comunes en exploits (`AdminAddCoins`, `KillAllPlayers`, `GiveGodmode`). Cualquier cliente que dispare estos remotos es automáticamente baneado y expulsado.

### 038. `net-timestamp-latency-compensation`
- **Regla:** Compensar el lag del cliente verificando marcas de tiempo en el servidor y validando contra un búfer circular de estados pasados (máx 200 ms).

### 039. `net-anticheat-speed-audit`
- **Regla:** Monitorear el delta de posición física en el tiempo en el servidor: corregir con rubberbanding si excede `maxAllowedSpeed * 1.3`.

### 040. `net-anticheat-teleport-detection`
- **Regla:** Detectar saltos espaciales instantáneos sin interacción previa con vehículos o teletransportadores registrados.

### 041. `net-anticheat-fly-noclip-guard`
- **Regla:** Validar estados ilegales de física (`Enum.HumanoidStateType.Flying`) e interpenetración de partes sólidas en el servidor.

### 042. `net-server-side-sanity-checks`
- **Regla:** Cálculos de costos, verificación de saldo y reglas de negocio ejecutadas exclusivamente en el servidor.

### 043. `net-anti-memory-tampering`
- **Regla:** En el cliente, proteger tablas críticas y configuraciones mediante metatablas congeladas con `table.freeze` o proxies protectores.

### 044. `net-kick-message-sanitization`
- **Regla:** Estandarizar los mensajes de expulsión para no filtrar lógica interna de seguridad (ej: "Error de conexión con el servidor").

### 045. `net-session-token-handshake`
- **Regla:** Para transacciones críticas secuenciales, generar tokens de sesión de un solo uso validados en el servidor.

### 046. `net-character-ownership-assertion`
- **Regla:** Verificar que la instancia manipulada o el personaje corresponda efectivamente al `player.Character` del emisor.

### 047. `net-network-ownership-lockdown`
- **Regla:** Asignar `part:SetNetworkOwner(nil)` forzando la simulación física en el servidor en entidades críticas (monedas, proyectiles, jefes).

### 048. `net-replicated-storage-segregation`
- **Regla:** Aislar módulos con lógica sensible exclusivamente en `ServerScriptService`, exponiendo únicamente tipos y definiciones en `ReplicatedStorage`.

### 049. `net-server-script-service-isolation`
- **Regla:** Evitar que código de servidor o secretos de configuración residan en carpetas accesibles al cliente.

### 050. `net-remote-call-graph-logging`
- **Regla:** Registrar el volumen y frecuencia de llamadas a remotos por jugador para auditar anomalías volumétricas.

### 051. `net-ddos-packet-flood-mitigation`
- **Regla:** Descartar en seco ráfagas de paquetes entrantes cuando un jugador supere el límite máximo de 50 invocaciones por segundo.

### 052. `net-position-history-rewind`
- **Regla:** Mantener un historial de 1 segundo de posiciones de entidades para validar impactos de proyectiles con lag compensation.

### 053. `net-exploit-telemetry-beacon`
- **Regla:** Enviar telemetría al servidor cuando el cliente detecta discrepancias de entorno o llamadas no autorizadas.

### 054. `net-client-gui-obfuscation-signals`
- **Regla:** Proteger elementos de interfaz críticos y señales de input de inyecciones maliciosas en el cliente.

### 055. `net-ban-list-sync-messaging`
- **Regla:** Sincronizar listas de baneo en tiempo real entre servidores mediante `MessagingService` para expulsión global inmediata.

### 056. `net-packet-compression-huffman`
- **Regla:** Comprimir buffers binarios y payloads grandes antes de transmitirlos para reducir la carga de red.

### 057. `net-client-heartbeat-watchdog`
- **Regla:** Monitorizar señales periódicas de vida del cliente para detectar pausas artificiales, congelamiento de procesos o desconexiones silenciosas.

### 058. `net-server-physics-ownership-claim`
- **Regla:** Reclamar activamente la propiedad física de partes en interacción para evitar manipulaciones de velocidad por clientes maliciosos.

### 059. `net-anti-teleport-raycast-validation`
- **Regla:** Validar trayectoria continua con raycasting entre dos posiciones consecutivas para detectar teletransporte a través de geometrías sólidas.

### 060. `net-payload-schema-guard`
- **Regla:** Aplicar esquemas tipados estrictos a los payloads de los remotos, rechazando cualquier parámetro no declarado.

---

## 🛡️ Anexo de Seguridad: Simulación Autoritativa del Servidor (Server-Authority Simulation)
En la arquitectura Zero-Trust de RAASE 2.1, el servidor es el único árbitro de la simulación física y el estado del mundo:
1. **Network Ownership Restricto:** Todas las partes interactivas, proyectiles, vehículos compartidos y drops de botín deben tener `part:SetNetworkOwner(nil)`. Esto delega el cálculo de integración de física a la CPU del servidor, anulando cualquier exploit de manipulación de velocidad o colisiones cliente-side.
2. **Reconciliación y Predicción:** El cliente puede ejecutar predicción local de movimiento para suavidad perceptual, pero el servidor realiza reconciliación estricta; cualquier desvío mayor al umbral de tolerancia es corregido inmediatamente mediante snapshot autoritativo.
3. **Validación de Línea de Visión (Raycast):** Ninguna interacción espacial ni disparo de proyectil es efectivo sin una validación geométrica en el servidor que confirme que la trayectoria está despejada de obstáculos impenetrables.

## 📡 Anexo: Plumbing canónico de remotos (cliente ↔ servidor)
Flujo canónico de la arquitectura Zero-Trust (verificado 2026-09-13): el cliente solo declara intenciones; el servidor valida antes de ejecutar y responde.

- **Cliente → servidor (intención → validación → respuesta):** `FireServer` envía la intención; `OnServerEvent` la recibe con `player` como primer argumento. Orden obligatorio: validación de tipos (026) → distancia (029) + rate limiter (032) → respuesta con `FireClient`.
- **Servidor → cliente:** `FireClient(player, …)` con `OnClientEvent` para respuestas puntuales; `FireAllClients` para difusión a todos los clientes.
- **Decisión Reliable vs Unreliable:** `UnreliableRemoteEvent` es one-way; sacrifica orden y confiabilidad por performance de red. Úsalo para datos que cambian continuamente o no son críticos. Comparte la misma superficie de métodos y eventos que `RemoteEvent`.

Snippet mínimo (`--!strict`), validación server-side antes de responder:

```luau
--!strict
-- Cliente: solo envía la intención
remoteEvent:FireServer(actionName, targetPart)

-- Servidor: validación → ejecución → respuesta
remoteEvent.OnServerEvent:Connect(function(player: Player, actionName: string, targetPart: Instance)
    if typeof(actionName) ~= "string" or typeof(targetPart) ~= "Instance" then
        return -- validación de tipos (026)
    end
    -- distancia (029) + rate limiter (032) antes de ejecutar; luego responder:
    remoteEvent:FireClient(player, "ack")
end)
```

Tabla de decisión:

| Aspecto | `RemoteEvent` | `UnreliableRemoteEvent` |
|---|---|---|
| Confiabilidad | Garantiza la entrega | Puede perder paquetes |
| Orden | Preserva el orden de envío | No garantiza orden |
| Dirección | Bidireccional | One-way (una sola dirección por disparo) |
| Uso | Datos críticos (compras, muertes, rondas) | Datos continuos o no críticos (cosméticos de alta frecuencia) |
| Superficie API | Métodos y eventos estándar | Misma superficie de métodos y eventos que `RemoteEvent` |

- **Riesgos de `InvokeClient`:** (1) un error en el cliente se propaga al servidor; (2) la desconexión del cliente produce error; (3) si el cliente no retorna, el servidor yieldea indefinidamente. Para un flujo servidor→cliente de una vía, preferir `RemoteEvent`.
- **Limitaciones de argumentos (serialización):**
  1. Índices no-string se convierten a string.
  2. Las funciones se serializan como `nil`.
  3. No mezclar claves numéricas y string en una misma tabla.
  4. Evitar `nil` en índices y valores.
  5. Las tablas se copian (se pierde la identidad).
  6. Las metatables se pierden.
  7. Las instancias no replicables llegan como `nil`.
