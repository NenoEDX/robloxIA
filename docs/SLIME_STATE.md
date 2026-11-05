# Slime state, trade and unavailable purchases

This is a **server-owned session prototype**, not a persistent economy.
`SlimeCoreService.getCapabilities()` returns:

```luau
{ persistence = "session-only", paidPurchases = false, trading = "offer-accept" }
```

Inventories, daily-capture timestamps and fermentation timers live only in process
memory. They are not saved across server shutdowns or player departures. The name
`startOfflineFermentation` remains for compatibility but does not imply offline
persistence. No DataStore schema or production data migration is introduced.

## Paid features are disabled at the server boundary

- `openEventSpecialCrates(player, count, true)` rejects with
  `PAID_FEATURE_UNAVAILABLE`, empty items and no grant, remote event or policy query.
  Free server-authorized counts are exactly 1, 3 or 10; their pets are `Earned_Free`.
  The old deterministic paid queue is removed rather than kept as unreachable code.
- `attemptDynamicSlimeCapture` preserves valid daily free captures. Invalid slime
  IDs cannot consume them. Once free capture is unavailable, the result is
  unsuccessful, `promptedProduct = false` and `reason = PAID_FEATURE_UNAVAILABLE`.
  `mappedDeveloperProductId` is always 0. Any computed cost is non-actionable
  prototype math, not a product price or an authorization to prompt a purchase.
- `skipTimerWithRobux` returns 0 without prompting, charging or changing timers.
- The HUD displays an unavailable paid control. It does not query example product
  IDs or display a fabricated fallback price.

Enabling payments is not a flag flip: it requires owner-verified products, live
regional prices, a single appropriate receipt dispatcher, durable atomic grant and
PurchaseId recording, policy checks, and failure/retry tests. Do not import the
Zombie game's receipt handler into Slime. Nothing here grants from client events.

## Server-only offer/accept API

The former immediate swap is intentionally replaced with two-party confirmation.
All methods remain server-only; there is no new client remote or trade UI.
Future UI adapters must authenticate the caller and pass the actual Player as the
actor, never trust actor IDs supplied by the client.

1. `initiateTwoPhaseTrade(playerA, playerB, petA_UUID, petB_UUID)` reserves the two
   currently owned items without moving them. The initiator is offering, not
   accepting on the recipient's behalf. Result:
   `{ success = false, reason = "AWAITING_ACCEPTANCE", tradeId = "..." }`.
2. `acceptTrade(playerB, tradeId)` queries policy for both players, then revalidates
   the still-live offer and inventories before swapping. A second acceptance or
   an unrelated actor cannot repeat or perform the transfer. `success = true`
   means the in-memory swap committed, not that it was durably saved.
3. `cancelTrade(participant, tradeId)` releases reservations. Player removal and
   service stop also cancel outstanding offers. There is no automatic timeout;
   server UI adapters must expose cancellation rather than abandon offers.

Self-trades, item/recipient collisions, changed ownership/UUIDs and immutable or
metatable-backed inventory dictionaries are rejected before transfer. If either
pet is not `Earned_Free`, both participants must have policy explicitly allowing
paid-item trading; errors/missing policy fail closed for those items. Free items
do not become paid merely because a policy lookup failed.

The ledger uses the existing authoritative inventory dictionaries and performs no
yield or callback between final validation and swap. Its injected inventory lookup
and ID factory are synchronous server-owned helpers, not untrusted extension hooks.
It is not a distributed transaction or a substitute for persistent session locking.

## Verification

```powershell
# Use the already verified temporary executables; never install implicitly.
pnpm --dir bridge --config.verify-deps-before-run=false exec node --test test_luau_framework.mjs test_rojo_split.mjs test_rojo_build.mjs
```

Set `LUNE_BIN` and `ROJO_BIN` to the approved absolute executable paths first.
Executable tests load the real service with mocked Roblox APIs and verify no grants
on rejected payments, free-flow preservation, consent/replay, cancellation, player
departure, policy races and rejected-transfer immutability. They do not spend Robux,
save real player data or prove Studio multiplayer behavior; those remain T9 gates.
