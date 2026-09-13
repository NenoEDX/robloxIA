---
name: roblox-09-economy-devex
description: "Cubre monetización y DevEx 2026 (skills 211-225): ProcessReceipt idempotente con persistencia previa del PurchaseId, tasa preferencial U.S. 18+ ($0.0054/R), avatares R15, gamepasses y compliance de compras. Úsala al implementar Developer Products, Gamepasses, validar recibos o planificar cash-out por DevEx."
license: MIT
allowed-tools: Read Write Bash(node:*,luau-lsp:*,rojo:*,wally:*)
metadata:
  domain: "Economy & DevEx 2026"
  range: "211-225"
  author: "RAASE 2.0 / robloxIA"
---

# roblox-09-economy-devex — Economía, Monetización y DevEx 2026 (Skills 211 - 225)

Este módulo rige las políticas de monetización y diseño económico auditadas bajo el programa Roblox Developer Exchange (DevEx 2026).

## Marco de Tasas DevEx 2026
- **Vigencia verificada:** 2026-09-13 (documentación oficial de Roblox); la tasa 18+ rige desde el 8-jun-2026.
- **Tasa Estándar 2026:** $0.0038 USD por Robux (umbral mínimo de retiro: 30.000 R$ = $114.00 USD).
- **Tasa Preferencial U.S. 18+:** $0.0054 USD por Robux (30.000 R$ = $162.00 USD). La verificación de edad/identidad corresponde al **jugador comprador U.S. 18+** (facial age estimation o government ID) y aplica a developer products, passes, subscriptions y private servers en juegos elegibles.
- **Tasa Legada:** $0.0035 USD por Robux para saldos anteriores al 5-sep-2025, 10 a. m. PT.

## Catálogo de Habilidades Técnicas

### 211. `economy-gamepass-service-wrapper`
- **Regla:** Consultar propiedad de gamepasses en el servidor mediante `MarketplaceService:UserOwnsGamePassAsync()` cacheando resultados para no saturar la API.

### 212. `economy-dev-product-process-receipt`
- **Regla:** Implementación OBLIGATORIA y exclusiva del callback `MarketplaceService.ProcessReceipt` en el servidor.

### 213. `economy-receipt-purchase-id-dedup`
- **Regla:** Registrar de forma transaccional el `PurchaseId` en DataStore mediante `UpdateAsync()` antes de otorgar beneficios (*Idempotencia*). Si el `PurchaseId` ya existe, retornar de inmediato `Enum.ProductPurchaseDecision.PurchaseGranted`.

### 214. `economy-not-processed-failover`
- **Regla:** Si la persistencia en base de datos falla o el jugador no está conectado, retornar SIEMPRE `Enum.ProductPurchaseDecision.NotProcessedYet`.

### 215. `economy-prompt-purchase-cooldown`
- **Regla:** Limitar la frecuencia con la que se disparan prompts de compra al usuario para prevenir spam y compras involuntarias.

### 216. `economy-devex-rate-standard-tier`
- **Regla:** Modelar pronósticos de ingresos calculando a la tasa estándar de $0.0038 USD por Robux para creadores generales.

### 217. `economy-devex-rate-legacy-tier`
- **Regla:** Manejar contabilidad retrocompatible para Robux históricos calculados a $0.0035 USD por Robux.

### 218. `economy-devex-us-18-plus-qualifier`
- **Regla:** Auditar y certificar que la experiencia califique para la tasa preferencial U.S. 18+ de $0.0054 USD por Robux con los criterios verificados: 100 % del playtime como R15 platform; human-form custom (cabeza + 2 brazos + 2 piernas; 12 limb parts O 12 limb joints distribuidas; torso ≥2; bípedo completo) **o** nonhuman-form custom (también califica); sin R6 en ningún momento; animation packs R15; NPCs no se evalúan.

### 219. `economy-r15-strict-avatar-enforcement`
- **Regla:** La exigencia R15 aplica al sistema de avatares platform para la tasa 18+ (correr 100 % en R15, sin R6); no es requisito del DevEx estándar.

### 220. `economy-devex-threshold-audit`
- **Regla:** Verificar que la cuenta de desarrollo supere el umbral mínimo oficial de 30.000 Robux ganados legítimamente antes de solicitar DevEx (requisitos base: 13+, email verificado, portal DevEx, formularios W-9/W-8).

### 221. `economy-lootbox-probability-disclosure`
- **Regla:** En mecánicas de recompensas aleatorias o cajas de botín, mostrar de forma obligatoria y pública en la UI los porcentajes de probabilidad exactos antes de comprar.
- **Cumplimiento Anti-Apuestas:** Prohibido implementar mecánicas de casino o apuestas con ganancia/pérdida de moneda de pago (cross-reference: consultar directivas completas en [roblox-20-moderation-compliance](../roblox-20-moderation-compliance/SKILL.md) para políticas de contenido maduro y ToS).

### 222. `economy-premium-payouts-design`
- **Regla:** Diseñar ciclos de engagement y retención para maximizar el tiempo de juego de suscriptores Roblox Premium (Premium Payouts).

### 223. `economy-in-game-shop-layout`
- **Regla:** Organizar tiendas en el juego con categorías claras, precios visibles y confirmaciones de compra seguras.
- **Balance de Moneda:** Para el equilibrio matemático de fuentes (*faucets*) y sumideros (*sinks*), ver análisis de economía en [roblox-17-analytics-liveops](../roblox-17-analytics-liveops/SKILL.md) (`analytics-economy-sink-source-tracking`).

### 224. `economy-cross-sell-teleport-portal`
- **Regla:** Implementar portales de teletransporte a otras experiencias del mismo creador o universo para tracción cruzada de usuarios.

### 225. `economy-ugc-limiteds-resale-hub`
- **Regla:** Gestionar compra y venta de ítems UGC Limited dentro de la experiencia respetando tarifas de creador y comisiones oficiales.
