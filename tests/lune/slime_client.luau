--!strict
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Lifecycle = require("../../project_template/src/shared/GameLifecycle")
local Contract = require("../../project_template/src/shared/SlimeEventContract")
local Registry = require("../../project_template/src/shared/SlimeVisualRegistry")
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			table.insert(listeners, callback)
			return { Disconnect = function() local i = table.find(listeners, callback); if i then table.remove(listeners, i) end end }
		end,
		Fire = function(_, ...) for _, callback in table.clone(listeners) do callback(...) end end,
		Count = function() return #listeners end,
	}
end
local remotes = {}
local children = {}
for key, name in Contract.Names do
	remotes[key] = { Name = name, OnClientEvent = signal(), IsA = function(_, class) return class == "RemoteEvent" end }
	table.insert(children, remotes[key])
end
local remoteFolder = { ChildAdded = signal(), GetChildren = function() return children end, FindFirstChild = function() return nil end }
local effects = {}
local flashes = {}
local warnings = {}
local heartbeat = signal()
local destroying = signal()
local modules = {
	Types = {}, GameLifecycle = Lifecycle, SlimeEventContract = Contract,
	SlimeVisualRegistry = Registry,
	SlimeCatalogs = { RARITY_GRADES = {}, MUTATIONS_BY_ID = {} },
	ProceduralAnimator = { CreateSpring2D = function() return { Impulse = function() end } end },
	VFXAndJuiceEngine = {
		AddTrauma = function() end,
		PlayModulatedSound = function(_id, position, variance)
			assert(position == nil and type(variance) == "number", "Sound position is not pitch variance")
		end,
		TriggerHitFlash = function(model) table.insert(flashes, model) end,
		ApplyHitstop = function() end,
		CastEffect = function(kind, cf, scale, options)
			assert(math.max(scale or 1, 0.1) == 1 and type(options) == "table", "Effect scale must not be options")
			table.insert(effects, { kind, cf })
		end,
	},
}
local services = {
	Players = { LocalPlayer = {} }, Workspace = {}, RunService = { Heartbeat = heartbeat },
	ReplicatedStorage = { WaitForChild = function(_, name)
		if name == "Remotes" then return remoteFolder end
		return { WaitForChild = function(_, moduleName) return moduleName end }
	end },
}
local client = luau.load(fs.readFile("project_template/src/client/SlimeClientController.client.luau"), {
	debugName = "SlimeClientController", environment = {
		game = { GetService = function(_, name) return services[name] or {} end },
		script = { Destroying = destroying }, require = function(name) return modules[name] end,
		task = { spawn = function(callback) callback() end, delay = function() end },
		Color3 = { fromRGB = function(...) return { ... } end },
		Vector2 = { new = function(...) return { ... } end }, CFrame = { identity = {} },
		warn = function(message) table.insert(warnings, message) end,
	},
})()
assert(heartbeat.Count() == 1)
local pet = { uuid = "pet-1", slimeId = "slime-1" }
remotes.BaseArrivalAnim.OnClientEvent:Fire(pet, 2)
remotes.PetExtractedMutationAnim.OnClientEvent:Fire(pet, { id = "mut-1" })
remotes.CrateRevealAnim.OnClientEvent:Fire({ { rarityGrade = "GRADE_01_BASIC" } }, false)
assert(#effects == 1 and effects[1][1] == "MagicExplosion")
remotes.MutationStrikeDropAnim.OnClientEvent:Fire(pet, { id = "mut-1" })
assert(#warnings == 1 and #effects == 1, "Unbound pet must not become an invented target")
local cf = {}
local model = { Parent = {}, PrimaryPart = { CFrame = cf }, IsA = function(_, class) return class == "Model" end }
local unbind = Registry.register("pet-1", model)
assert(Registry.get("pet-1") == model)
remotes.MutationStrikeDropAnim.OnClientEvent:Fire(pet, { id = "mut-1" })
assert(#effects == 2 and effects[2][1] == "HeavyImpact" and effects[2][2] == cf)
assert(flashes[1] == model)
client.SetPerformanceMode("LOW_3")
assert(client.GetPerformanceMode() == "LOW_3")
assert(#client.FilterVisibleMutations({ "a", "b", "c", "d" }, "LOW_3") == 3)
unbind()
assert(Registry.get("pet-1") == nil)
destroying:Fire()
assert(heartbeat.Count() == 0 and remoteFolder.ChildAdded.Count() == 0)
for _, remote in remotes do assert(remote.OnClientEvent.Count() == 0) end
remotes.CrateRevealAnim.OnClientEvent:Fire({ { rarityGrade = "GRADE_01_BASIC" } }, false)
assert(#effects == 2 and #warnings == 1)
print("PASS actual Slime client: wire payloads, model binding, previous API and cleanup")
