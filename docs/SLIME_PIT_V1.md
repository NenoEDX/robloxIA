# SLIME PIT V1 — development build

Status: implemented and mounted through official Studio MCP; gameplay and visual
acceptance remain pending. See T9 in [the feature log](../odd/tasks/system-overhaul.md).
Do not describe this build as released or fully verified.

## Play loop

1. Spawn at the sanctuary and walk down the ramp.
2. Approach a slime burrow. Hold **E** (gamepad **X**, or the touch prompt).
3. Pull a slime free, receive juice and see it in the collection/backpack.
4. The backpack holds eight slimes and the tank holds 1,000 juice. Overflow is rejected.
5. Use a biome's **Return** portal, then hold **E** at the sanctuary vault.
6. Depositing secures the collection and reveals catalog mutations. Repeat in the
   Moss Garden, Crystal Hollow and Amber Rift.

The current map has 26 renewable nodes. Captured nodes return after 12 seconds.
The core's existing 250 starting juice is preserved. Inventory survives character
respawn but **not leaving the server**. No DataStore, paid purchase or upload is
claimed. The collection UI displays the first 60 entries and six companions.

## Source and deployment

Official Roblox Studio MCP is the **only Studio transport**. Do not run Rojo serve
or the RASEE Companion Bridge for this build. Local Git files remain canonical;
`project_template/slime.project.json` remains the composition manifest and an
optional offline build format, not an instruction to start another transport.

- Deploy exact file contents with official `multi_edit`; inspect existing scripts
  before edits and verify readback. Never assign `.Source` through `execute_luau`.
- `SlimeStudioSetup.prepare()` creates only the two missing Folder containers.
- `SlimeStudioSetup.archiveLegacy()` moves the specifically named former lobby,
  zombie, spawn and amphitheater into `ServerStorage.SlimePitLegacyArchive`, and
  disables/archives `LobbyAmbienceAnimator`. It does not destroy them.
- `SlimeStudioSetup.activateV1()` disables the two historical presentation
  controllers and enables `SlimePitController`. Their source remains available.
- `SlimePitWorld.build()` creates the idempotent V1 scene. The bootstrap starts
  `SlimeCoreService` and `SlimePitService`; all player rewards remain server-owned.

`SlimePitService` validates prompt identity, enabled state, living character,
distance, elapsed server hold time and capacity. In-range checks continue during
the hold. Reward and node ownership changes contain no yields. The existing core
owns pending pets and deposits; the player's replicated inventory Folder is only
a presentation projection, not an authority for granting rewards.

## Art and effects

The geometry is original procedural Roblox Parts: translucent blob bodies,
eyes/highlights, cheeks, crystal crests, rock walls, biome crystals and sanctuary.
The user-provided slime/HUD concepts inform the direction; no image was uploaded
as a texture, no third-party model imported and no mesh asset ID fabricated.

The three V1 auras are cosmetic catalog entries. Companions register their UUIDs
in `SlimeVisualRegistry`. Hold feedback uses strain/wobble and a progress bar;
capture uses bounded local particle-like bursts. Reduced-motion preference
disables the moving effects without hiding the textual reward feedback.

`Workspace.SlimePopSoundId` is an optional hook for a project-owned sound. It is
unset by default: **no audible pop is claimed until an approved asset is supplied**.

## Verification

```powershell
node bridge/test_all.mjs
```

This runs the same explicit selected suite, without starting Studio or installing
dependencies. Seven optional Lune tests and two Rojo build tests remain skipped
when their executables are absent; these skips are not passes.

In the authorized Studio instance, invoke the versioned test module through MCP:

```lua
return require(game.ReplicatedStorage.RAASE_Shared.SlimePitRulesTests).run()
```

Ten runtime rules cover valid harvest, tank/pack overflow, negative/nonfinite
state, early completion, distance, dead players and missing hold starts. The test
also requires the real shared Types module. Use native movement/keyboard tools to
verify the complete game loop separately; these rule tests cannot prove it.

Current open QA: the first input-driven harvest did not grant a reward; native
captures showed the HUD but a blank 3D view. Bootstrap logs succeeded. A duplicate
toolbar error from the already-installed RASEE plugin is separate from game
scripts and is not silently counted as a clean total console.
