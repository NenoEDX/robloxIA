# Isolated game compositions

Use an explicit project file. `project_template/default.project.json` is retained
unchanged for legacy work; it still contains the old mixed composition and is
not the entrypoint for either isolated game.

| Game | Project | Local serve port | Server modules | Client controllers | Shared modules |
| --- | --- | --- | --- | --- | --- |
| Zombie Awareness | `project_template/zombie.project.json` | 34872 | 8 | 2 | 9 |
| SLIME PIT | `project_template/slime.project.json` | 34874 (legacy, not started) | 3 | 3 (2 legacy disabled) | 14 |

For T9, official Studio MCP is the sole transport. The retained port settings are
offline compatibility metadata, not a request to run Rojo. The shared instance names remain
`RAASE_Server`, `RAASE_Shared`, and `RAASE_Client`, but each game uses a separate
place/session. No files are moved or copied between game source directories.

## Ownership and imports

- Every `$path` is an explicit existing Luau file, relative to `project_template`.
- `RAASE_Server` is a **Script**, not a Folder. Its child ModuleScripts keep
  `script.Parent:WaitForChild(...)` imports working.
  Rojo infers that class from the bootstrap's `.server.luau` filename. Do not
  combine an explicit `$className` with a file `$path`: Rojo 7.7.1 rejects it.
- Each bootstrap loads only its game's services. Zombie constructs its seeded
  world and initial ecosystem; Slime now constructs the V1 biome map and starts
  server-authoritative node interactions through `SlimePitService`.
- Client controllers are explicitly enumerated rather than importing `src/client`.
- Shared primitives are reused from their original files. Zombie-only catalogs
  are not shipped in Slime; Slime-only modules are not shipped in Zombie.
- `Packages` is not mapped: no selected module imports it, and the original
  repository does not contain that directory.
- Untracked LihFolk additions in the original checkout are not silently imported.
  Their controlled preservation and integration remain separate tasks.

## Build and serve

Optional offline build commands and the unchanged Zombie serve command:

```powershell
rojo build project_template/zombie.project.json -o "$env:TEMP/ZombieAwareness.rbxlx"
rojo build project_template/slime.project.json -o "$env:TEMP/SlimePit.rbxlx"
rojo serve project_template/zombie.project.json
```

**Do not start a Slime sync server for T9.** Use the official MCP deployment in
[SLIME PIT V1](SLIME_PIT_V1.md). For other server-based workflows, use separate local
test copies and verify the game/session identity before connecting. The three
RAASE containers are explicitly owned (`$ignoreUnknownInstances: false`), so
sync can remove unmapped children inside them. Preserve a place backup first;
do not swap projects in a shared editing session. For published test places,
configure `servePlaceIds` using the verified target IDs, not historical memory.

The bootstrap still runs its existing game-specific world generation at Play.
Slime now has explicit service startup/cleanup and shared event/payload adapters;
see [Game lifecycle](GAME_LIFECYCLE.md) for executable Luau checks and visual binding.
Moving authored worlds out of startup, persistence/purchases and actual Studio
integration remain separate work; a composition build does not prove those systems.

## Offline verification

```powershell
pnpm --dir bridge --config.verify-deps-before-run=false exec node --test test_rojo_split.mjs
```

This parses the actual public project files, checks exact service/controller/
shared-module membership, class and parent layout, existing in-root file paths,
and distinct ports. It also checks the currently used static import forms,
bootstrap service membership, and bootstrap API names; unsupported import forms
fail rather than being silently skipped. It does **not** execute Luau or replace a real Rojo build,
Studio playtest, multiplayer check, or performance measurement.

## Real build regression gate

With an independently verified Rojo 7.7.1 executable, opt into the build tests:

```powershell
$env:ROJO_BIN = "C:/path/to/verified/rojo.exe"
pnpm --dir bridge --config.verify-deps-before-run=false exec node --test test_rojo_build.mjs
Remove-Item Env:ROJO_BIN
```

The tests invoke `build` for both project files and check the generated XML.
They write only to fresh system temporary directories and remove their outputs.
They never download tools, start `serve`, connect to Studio, or publish a place.
Without `ROJO_BIN`, both tests report **skipped**, not verified. An invalid
executable or unsuccessful build fails the test. Keep the separate structural
tests for exact membership/import checks, and use Studio for runtime proof.

Reference: https://rojo.space/docs/v7/project-format/
