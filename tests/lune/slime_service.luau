--!strict
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Lifecycle = require("../../project_template/src/shared/GameLifecycle")
local Contract = require("../../project_template/src/shared/SlimeEventContract")
local TradeLedger = require("../../project_template/src/shared/SlimeTradeLedger")
local connections = 0
local function signal()
	local listeners = {}
	return { Connect = function(_, callback)
		connections += 1
		table.insert(listeners, callback)
		local active = true
		return { Disconnect = function()
			if active then active = false; connections -= 1; table.remove(listeners, table.find(listeners, callback)) end
		end }
	end, Fire = function(_, ...) for _, callback in table.clone(listeners) do callback(...) end end }
end
local player = { UserId = 42 }
local currentPlayers = { player }
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return currentPlayers end }
local pending = {}
local remoteCount = 0
local subscribed = 0
local modules = {
	Types = {}, SlimeCoreMath = {}, SlimeCatalogs = {
		MUTATIONS = { { id = "mut-1" } },
		SLIMES_BY_ID = { ["slime-1"] = { rarityGrade = "GRADE_01_BASIC", baseStabilityHP = 100, raceId = "race-1" } },
	},
	GameLifecycle = Lifecycle, SlimeEventContract = Contract,
	SlimeTradeLedger = TradeLedger,
	NetworkSecurityService = { createGuardedRemote = function(_name)
		remoteCount += 1
		return { FireClient = function() end }
	end },
}
local services = {
	Players = players,
	HttpService = { GenerateGUID = function() return "pet-1" end },
	ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, name) return name end } end },
	MessagingService = { SubscribeAsync = function()
		subscribed += 1
		return { Disconnect = function() subscribed -= 1 end }
	end },
}
local service = luau.load(fs.readFile("project_template/src/server/SlimeCoreService.luau"), {
	debugName = "SlimeCoreService", environment = {
		game = { GetService = function(_, name) return services[name] or {} end },
		script = { Parent = { WaitForChild = function(_, name) return name end } },
		require = function(name) return assert(modules[name], name) end,
		task = { spawn = function(callback) table.insert(pending, callback) end },
		warn = function(...) error("Unexpected warning") end,
	},
})()
assert(connections == 0 and #pending == 0 and remoteCount == 0, "Require must not start the Slime service")
assert(service.start())
assert(service.getPlayerUnrefinedJuice(player) == 250, "Already-connected players need initialization")
service.addUnrefinedJuice(player, 50)
assert(not service.start() and service.getPlayerUnrefinedJuice(player) == 300)
assert(connections == 2 and remoteCount == 7 and #pending == 1)
local joining = { UserId = 99 }
players.PlayerAdded:Fire(joining)
assert(service.getPlayerUnrefinedJuice(joining) == 250)
service.addUnrefinedJuice(joining, 25)
players.PlayerRemoving:Fire(joining)
assert(service.getPlayerUnrefinedJuice(joining) == 0)
players.PlayerAdded:Fire(joining)
assert(service.getPlayerUnrefinedJuice(joining) == 250, "Rejoin must initialize fresh state")
players.PlayerRemoving:Fire(joining)
assert(service.addPendingDorsalSlime(player, "slime-1", 1).uuid == "pet-1")
local extraction = service.extractToCircularLobby(player)
assert(extraction.success and extraction.securedJuice == 300 and #extraction.extractedSlimes == 1)
service.addUnrefinedJuice(player, 300)
service.stop()
assert(connections == 0)
assert(service.start())
pending[1]()
assert(subscribed == 0, "A stale subscription after restart must not join the new generation")
pending[2]()
assert(subscribed == 1 and service.getPlayerUnrefinedJuice(player) == 300)
assert(#service.getPlayerPets(player) == 1, "Restart must preserve the extracted pet inventory")
service.stop(); service.stop()
assert(connections == 0 and subscribed == 0)
print("PASS slime service: require/start/stop, existing players, state preservation and late subscription cleanup")
