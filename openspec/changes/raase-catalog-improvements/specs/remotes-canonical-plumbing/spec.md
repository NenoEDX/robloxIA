# Remotes Canonical Plumbing Specification

## Purpose

Anexo de plumbing canónico de remotos en `roblox-02-netsec`: scaffolding cliente→servidor, flujo servidor→cliente, tabla de decisión Reliable/Unreliable, riesgos de `InvokeClient` y limitaciones de argumentos. Todo trazable al Addendum A (docs oficiales de eventos remotos, 2026-09-13); sin cifras de rate (no verificadas).

## Requirements

### Requirement: Scaffolding canónico cliente→servidor

`roblox-02` MUST incluir un ejemplo canónico con `FireServer` desde el cliente y `OnServerEvent(player, …)` en el servidor, donde el jugador es el primer argumento del handler y el servidor valida antes de responder (intención → validación → respuesta).

#### Scenario: Snippet con plumbing real

- GIVEN un lector de `roblox-02-netsec`
- WHEN abre el anexo de plumbing
- THEN encuentra `FireServer` y `OnServerEvent` con `player` como primer parámetro
- AND el flujo muestra validación server-side antes de la respuesta

### Requirement: Flujo servidor→cliente

El anexo MUST incluir `FireClient(player, …)` con `OnClientEvent` y `FireAllClients`.

#### Scenario: Respuestas al cliente documentadas

- GIVEN el anexo de plumbing
- WHEN el lector busca respuestas del servidor
- THEN encuentra `FireClient`/`OnClientEvent` y `FireAllClients`

### Requirement: Tabla de decisión Reliable vs Unreliable

El anexo MUST comparar `RemoteEvent` con `UnreliableRemoteEvent`: este último es one-way, sacrifica orden y confiabilidad por performance de red, sirve para datos que cambian continuamente o no son críticos y comparte la superficie de métodos/eventos de `RemoteEvent`.

#### Scenario: Decisión informada

- GIVEN un desarrollador que elige transporte
- WHEN consulta la tabla
- THEN encuentra cuándo usar cada evento y sus tradeoffs

### Requirement: Riesgos de InvokeClient

El anexo MUST documentar los riesgos oficiales: el error del cliente se propaga al servidor; la desconexión del cliente produce error; si el cliente no retorna, el servidor yieldea indefinidamente; para un flujo server→client de una vía se SHOULD preferir `RemoteEvent`.

#### Scenario: Advertencias completas

- GIVEN el anexo de plumbing
- WHEN el lector busca advertencias sobre `InvokeClient`
- THEN encuentra los tres riesgos y la recomendación de `RemoteEvent` para una vía

### Requirement: Limitaciones de argumentos de remotos

El anexo MUST listar las limitaciones oficiales: índices no-string se convierten a string; funciones se serializan como `nil`; no mezclar claves numéricas y string; evitar `nil` en índices y valores; las tablas se copian (identidad perdida); las metatables se pierden; las instancias no replicables llegan como `nil`.

#### Scenario: Pitfalls listados

- GIVEN un desarrollador que diseña un payload
- WHEN revisa las limitaciones
- THEN encuentra las siete reglas de serialización

### Requirement: Sin cifras de rate nuevas

El anexo MUST NOT publicar límites numéricos de rate (V20/V21 sin verificar). Las cifras internas existentes de `roblox-02` (token bucket de ejemplo y umbral de descarte) MUST permanecer sin cambios.

#### Scenario: Cero números sin fuente

- GIVEN el anexo de plumbing final
- WHEN se buscan límites de rate o cifras nuevas
- THEN no hay ninguna
- AND las cifras internas existentes quedan intactas
