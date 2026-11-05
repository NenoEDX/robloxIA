# Slime lifecycle and presentation contracts

`GameLifecycle` is a small pure Luau resource scope, not a new game engine.
`start(setup?)` is idempotent; `track(cleanup)` registers reverse-order cleanup;
`stop()` runs every callback even if one fails and returns the collected errors.
Failed startup rolls back registered resources. Generations identify stale async
work so a subscription finishing after stop/restart is disconnected, not adopted.

Both Slime bootstraps explicitly call `SlimeCoreService.start()` and bind `stop()`
to shutdown. Requiring that service no longer creates its remotes, player listeners
or cross-server subscription. The separate legacy `NetworkSecurityService` still
has its own existing require-time setup; T5 does not rewrite that shared service.
Already-connected players initialize once. Stop/restart preserves process-memory
Slime inventory/tank state; this is **not persistent player storage**.

## Wire compatibility

`SlimeEventContract.Names` is the canonical seven-name server table. Server event
names and positional payloads remain unchanged. The client adapter validates and
converts them before calling existing presentation functions:

| Event suffix (all prefixed `Slime_`) | Existing wire arguments | Presentation arguments |
| --- | --- | --- |
| ExtractionRarityAnim | grade, fill ratio | grade, fill ratio |
| BaseArrivalAnim | pet table, mutation count | slime ID, mutation count |
| PetExtractedMutationAnim | pet table, mutation table | slime ID, mutation ID |
| MutationStrikeDropAnim | pet table, mutation table | pet UUID, mutation ID |
| CrateRevealAnim | crate item array, multi-open flag | highest grade, multi-open flag |
| AdminAbuseBroadcast | command table | command type, creator name |
| DynamicCapturePrompt | quote table | informational quote, never purchase execution |

`connect` binds existing and later-replicated remotes once per instance; its cleanup
disconnects both discovery and event listeners. Invalid payloads call the supplied
rejection reporter and do not reach animation/HUD code. This presentation guard
does not replace authoritative server validation or a purchase receipt handler.

Strike-drop requires the existing real slime Instance. The visual owner requires
`RAASE_Shared.SlimeVisualRegistry`, calls `register(petUuid, instance)` and invokes
the returned unbind callback on removal. A LocalScript's return value is not an
external API; the registry ModuleScript is the usable client-local integration seam.
No pet-renderer exists in this slice: unbound UUIDs are reported,
not mapped to an invented pedestal or the player character. The optional legacy
ExoMech listener and direct visual APIs remain available. `DynamicCapturePrompt`
remains available for a later authorized UI; it does not enable paid capture.
Controllers expose `Stop()` and clean up their owned listeners on script destruction.
Presentation calls use the existing VFX API positions: numeric scale precedes the
effect options table, and pitch variance follows the optional sound position.

## Verification and remaining integration

```powershell
$env:LUNE_BIN = "C:\ApprovedTools\lune.exe"
$env:ROJO_BIN = "C:\ApprovedTools\rojo.exe"
pnpm --dir bridge --config.verify-deps-before-run=false exec node --test test_luau_framework.mjs test_rojo_split.mjs test_rojo_build.mjs
```

These are explicit local executable paths, not download instructions. Tests execute
the real pure Luau modules and the service source with mocked Roblox boundaries.
The service test also catches syntax errors that textual tests cannot detect.
The client test executes its real listener code with signature-checked VFX stubs;
it proves dispatch and argument compatibility, not rendering fidelity.
Rojo verifies composition, not behavior. No purchase, DataStore, MessagingService
connection, Roblox scene or network session is used by these tests. Real viewport,
multiplayer, replication and model binding remain Studio/T9 verification work.
