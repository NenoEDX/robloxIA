--!strict
local fs = require("@lune/fs")
local luau = require("@lune/luau")
for _, file in {
	"shared/GameLifecycle.luau", "shared/SlimeEventContract.luau",
	"shared/SlimeVisualRegistry.luau",
	"shared/SlimeTradeLedger.luau",
	"shared/Types.luau", "shared/SlimeCatalogs.luau",
	"shared/SlimePitRules.luau", "shared/SlimePitRulesTests.luau",
	"shared/SlimePitWorld.luau", "shared/SlimeStudioSetup.luau",
	"shared/VFXRecipeCatalog.luau", "shared/MapZoneBuilder.luau",
	"server/SlimePitService.luau", "client/SlimePitController.client.luau",
	"server/SlimeCoreService.luau", "server/init.server.luau",
	"bootstrap/slime.server.luau", "client/SlimeClientController.client.luau",
	"client/SlimeHUDController.client.luau",
} do
	luau.load(fs.readFile("project_template/src/" .. file), { debugName = file })
end
print("PASS syntax: selected Slime sources compile (not a typecheck or Studio run)")
