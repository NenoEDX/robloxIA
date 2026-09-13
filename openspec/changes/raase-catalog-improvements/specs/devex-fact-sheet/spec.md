# Devex Fact Sheet Specification

## Purpose

Hechos DevEx verificados que `roblox-09-economy-devex` MUST publicar (tasas, vigencia, elegibilidad y atribución de la verificación 18+), trazables al Addendum A (docs oficiales, 2026-09-13). Incluye la auditoría de `roblox-18-monetization-suite`.

## Requirements

### Requirement: Tasas DevEx vigentes con nota de verificación

`roblox-09` MUST declarar las tres tasas con ejemplos de conversión R$→USD y una nota de vigencia fechada:

| Tasa | Valor | Ejemplo | Vigencia |
|---|---|---|---|
| Estándar | `$0.0038 USD/R$` | 30 000 R$ = $114.00 | verificado 2026-09-13 (docs oficiales) |
| Preferencial U.S. 18+ | `$0.0054 USD/R$` | 30 000 R$ = $162.00 | vigente desde 8-jun-2026 |
| Legada | `$0.0035 USD/R$` | — | saldos anteriores al 5-sep-2025, 10 a. m. PT |

#### Scenario: Lectura de tasas y vigencia

- GIVEN un lector de `roblox-09-economy-devex`
- WHEN busca las tasas DevEx
- THEN encuentra `$0.0038`, `$0.0054` y `$0.0035` con sus ejemplos R$→USD
- AND encuentra la nota "verificado 2026-09-13" y la fecha de vigencia de la tasa 18+

#### Scenario: Corte legado preciso

- GIVEN el marco de tasas de `roblox-09`
- WHEN el lector audita la tasa legada
- THEN la condición es "saldos anteriores al 5-sep-2025, 10 a. m. PT"
- AND no queda la formulación vaga "antes de septiembre de 2025"

### Requirement: Atribución de la verificación 18+ al jugador

`roblox-09` MUST atribuir la verificación de edad/identidad de la tasa 18+ al **jugador comprador U.S. 18+** (facial age estimation o government ID) y MUST NOT atribuirla al creador. MUST declarar su alcance: developer products, passes, subscriptions y private servers en juegos elegibles.

#### Scenario: Sujeto correcto de la verificación

- GIVEN la sección de tasa preferencial U.S. 18+
- WHEN el lector identifica a quién corresponde la verificación
- THEN dice explícitamente que corresponde al jugador (spender)
- AND ofrece los métodos facial age estimation y government ID

#### Scenario: Sin obligación falsa al creador

- GIVEN cualquier mención de verificación de identidad en `roblox-09`
- WHEN el lector la lee
- THEN ninguna exige que el creador verifique su identidad para calificar

### Requirement: Elegibilidad 18+ de personajes

`roblox-09` MUST listar los criterios verificados: 100 % del playtime como R15 platform; human-form custom (12 limb parts O 12 limb joints distribuidas; torso ≥2; bípedo completo) O nonhuman-form custom (también califica); sin R6 en ningún momento; animation packs R15; NPCs no se evalúan.

#### Scenario: Auditoría de elegibilidad

- GIVEN un creador que evalúa su juego
- WHEN revisa los criterios de la tasa 18+
- THEN encuentra los seis criterios anteriores
- AND nonhuman-form aparece como elegible, no excluido

### Requirement: Umbral y requisitos base del DevEx estándar

`roblox-09` MUST conservar el umbral de retiro de 30 000 R$ y añadir los requisitos base: 13+ años, email verificado, portal DevEx y formularios W-9/W-8.

#### Scenario: Requisitos completos

- GIVEN un lector que planifica su cash-out
- WHEN busca los requisitos del DevEx estándar
- THEN encuentra el umbral de 30 000 R$ y los cuatro requisitos base

### Requirement: Prohibición del mecanismo no verificado

`roblox-09` MUST NOT publicar el mecanismo `StarterPlayer.GameSettings`. La regla 219 MUST reformularse: la exigencia R15 aplica al sistema de avatares platform para la tasa 18+ y no es requisito del DevEx estándar.

#### Scenario: Mecanismo ausente y regla reformulada

- GIVEN el archivo `roblox-09` final
- WHEN se busca `StarterPlayer.GameSettings`
- THEN hay cero ocurrencias
- AND la regla R15 queda asociada a la tasa 18+ (sistema platform), no al DevEx estándar

### Requirement: Auditoría de roblox-18 sin edición factual

`roblox-18-monetization-suite` MUST NOT recibir ediciones factuales en v1 ni incorporar tasas DevEx o claims de elegibilidad 18+ (V9 queda como follow-up).

#### Scenario: Anexo Creator Store sin tasas

- GIVEN `roblox-18-monetization-suite`
- WHEN el lector busca tasas DevEx
- THEN no encuentra ninguna
- AND no hay edición factual atribuible a este change
