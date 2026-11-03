--!strict
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Lifecycle = require("../../project_template/src/shared/GameLifecycle")
local Contract = require("../../project_template/src/shared/SlimeEventContract")
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			table.insert(listeners, callback)
			return { Disconnect = function() local i = table.find(listeners, callback); if i then table.remove(listeners, i) end end }
		end,
		Fire = function(_, ...) for _, callback in table.clone(listeners) do callback(...) end end,
	}
end
local function harness()
	local h = { policyCalls = 0, prompts = 0, events = 0, now = 100000, guid = 0, policies = { true, true } }
	h.players = { { UserId = 1, GetAttribute = function() return 1 end }, { UserId = 2, GetAttribute = function() return 1 end } }
	h.removing = signal()
	local modules = {
		Types = {}, GameLifecycle = Lifecycle, SlimeEventContract = Contract,
		SlimeCatalogs = {
			MUTATIONS = { { id = "m1" } },
			SLIMES_BY_ID = { s1 = { rarityGrade = "GRADE_01_BASIC", baseStabilityHP = 100, raceId = "r1" } },
			EVENT_CRATE_DAY1_POOL = { { slimeId = "s1", rarityGrade = "GRADE_01_BASIC", probabilityPercent = 100 } },
		},
		SlimeCoreMath = {
			computeSkipTimerRobux = function() return 100 end,
			computeDynamicCaptureQuote = function(_, _, _, _, last, now)
				return { isDailyFreeAvailable = now - last >= 86400, mappedDeveloperProductId = 200101, computedRobuxCost = 100 }
			end,
		},
		NetworkSecurityService = { createGuardedRemote = function()
			return { FireClient = function() h.events += 1 end }
		end },
	}
	local services = {
		Players = { PlayerAdded = signal(), PlayerRemoving = h.removing,
			GetPlayers = function() return h.players end,
			GetPlayerByUserId = function(_, id) return h.players[id] end },
		ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, name) return name end } end },
		HttpService = { GenerateGUID = function() h.guid += 1; return "id-" .. h.guid end },
		PolicyService = { GetPolicyInfoForPlayerAsync = function(_, player)
			h.policyCalls += 1
			if h.onPolicy then h.onPolicy() end
			if h.policyError then error("offline") end
			return { IsPaidItemTradingAllowed = h.policies[player.UserId], ArePaidRandomItemsRestricted = false }
		end },
		MarketplaceService = { PromptProductPurchase = function() h.prompts += 1 end },
	}
	h.service = luau.load(fs.readFile("project_template/src/server/SlimeCoreService.luau"), {
		debugName = "SlimeCoreService", environment = {
			game = { GetService = function(_, name) return services[name] or {} end },
			script = { Parent = { WaitForChild = function(_, name) return name end } },
			require = function(name)
				if name == "SlimeTradeLedger" then return require("../../project_template/src/shared/SlimeTradeLedger") end
				return assert(modules[name], name)
			end,
			task = { spawn = function() end }, os = { time = function() return h.now end }, warn = function() end,
		},
	})()
	h.service.start()
	return h
end
local function seed(h, player)
	local pet = h.service.addPendingDorsalSlime(player, "s1", 1)
	assert(h.service.extractToCircularLobby(player).success)
	return pet
end
local failures = {}
local cases = 0
local function check(name, callback)
	cases += 1
	local ok, reason = pcall(callback)
	if not ok then table.insert(failures, name .. ": " .. tostring(reason)) end
end
check("paid crates fail closed without granting or querying", function()
	local h = harness()
	local result = h.service.openEventSpecialCrates(h.players[1], 1, true)
	assert(not result.success and result.reason == "PAID_FEATURE_UNAVAILABLE")
	assert(#result.items == 0 and #h.service.getPlayerPets(h.players[1]) == 0)
	assert(h.policyCalls == 0 and h.events == 0 and h.prompts == 0)
	assert(not h.service.openEventSpecialCrates(h.players[1], 2, false).success)
	assert(h.service.openEventSpecialCrates(h.players[1], 1, false).success, "Free server-authorized crate remains available")
	assert(#h.service.getPlayerPets(h.players[1]) == 1)
end)
check("capture and timer never prompt unconfigured products", function()
	local h = harness()
	local p = h.players[1]
	assert(not h.service.attemptDynamicSlimeCapture(p, "unknown", 1).success)
	assert(#h.service.getPlayerPets(p) == 0, "Unknown slime cannot consume the free capture")
	local free = h.service.attemptDynamicSlimeCapture(p, "s1", 1)
	assert(free.success and not free.promptedProduct and #h.service.getPlayerPets(p) == 1)
	local paid = h.service.attemptDynamicSlimeCapture(p, "s1", 1)
	assert(not paid.success and not paid.promptedProduct and paid.reason == "PAID_FEATURE_UNAVAILABLE")
	assert(paid.quote.mappedDeveloperProductId == 0 and h.events == 0 and h.prompts == 0)
	assert(h.service.skipTimerWithRobux(p, "DAILY_CAPTURE_RESET", 10) == 0 and h.prompts == 0)
	assert(#h.service.getPlayerPets(p) == 1)
	local caps = h.service.getCapabilities()
	assert(caps.persistence == "session-only" and caps.paidPurchases == false and caps.trading == "offer-accept")
end)
check("trade waits for counterparty and commits once without duplicating pets", function()
	local h = harness()
	local a, b = h.players[1], h.players[2]
	local petA, petB = seed(h, a), seed(h, b)
	local offer = h.service.initiateTwoPhaseTrade(a, b, petA.uuid, petB.uuid)
	assert(not offer.success and offer.reason == "AWAITING_ACCEPTANCE" and type(offer.tradeId) == "string")
	assert(h.service.getPlayerPets(a)[1] == petA and h.service.getPlayerPets(b)[1] == petB)
	assert(not h.service.acceptTrade({ UserId = 99 }, offer.tradeId).success)
	assert(not h.service.acceptTrade(a, offer.tradeId).success, "Initiator alone cannot confirm for the recipient")
	assert(h.service.acceptTrade(b, offer.tradeId).success)
	assert(h.service.getPlayerPets(a)[1] == petB and h.service.getPlayerPets(b)[1] == petA)
	assert(not h.service.acceptTrade(b, offer.tradeId).success, "Replay cannot grant again")
end)
check("self, collision, cancel and departing-player reservations leave data safe", function()
	local h = harness()
	local a, b = h.players[1], h.players[2]
	local petA, petB = seed(h, a), seed(h, b)
	assert(not h.service.initiateTwoPhaseTrade(a, a, petA.uuid, petA.uuid).success)
	local offer = h.service.initiateTwoPhaseTrade(a, b, petA.uuid, petB.uuid)
	assert(not h.service.initiateTwoPhaseTrade(a, b, petA.uuid, petB.uuid).success)
	assert(not h.service.cancelTrade({ UserId = 99 }, offer.tradeId).success)
	assert(h.service.cancelTrade(a, offer.tradeId).success)
	local nextOffer = h.service.initiateTwoPhaseTrade(a, b, petA.uuid, petB.uuid)
	h.removing:Fire(b)
	assert(not h.service.acceptTrade(a, nextOffer.tradeId).success)
	assert(h.service.getPlayerPets(a)[1] == petA)
end)
check("paid item policy applies to both participants and policy yields cannot revive stale offers", function()
	local h = harness()
	local a, b = h.players[1], h.players[2]
	local petA, petB = seed(h, a), seed(h, b)
	petA.acquisitionPath = "Event_Crate"
	h.policies[2] = false
	local offer = h.service.initiateTwoPhaseTrade(a, b, petA.uuid, petB.uuid)
	assert(not h.service.acceptTrade(b, offer.tradeId).success)
	assert(h.service.getPlayerPets(a)[1] == petA and h.service.getPlayerPets(b)[1] == petB)
	h.policies[2] = true
	local nextOffer = h.service.initiateTwoPhaseTrade(a, b, petA.uuid, petB.uuid)
	h.onPolicy = function() h.onPolicy = nil; h.service.cancelTrade(a, nextOffer.tradeId) end
	assert(not h.service.acceptTrade(b, nextOffer.tradeId).success)
	assert(h.service.getPlayerPets(a)[1] == petA and h.service.getPlayerPets(b)[1] == petB)
end)
check("ledger rejects collisions, changed UUIDs and immutable inventories before transfers", function()
	local Ledger = require("../../project_template/src/shared/SlimeTradeLedger")
	local a = { uuid = "a", acquisitionPath = "Earned_Free" }
	local b = { uuid = "b", acquisitionPath = "Earned_Free" }
	local inventories = { { a = a, b = b }, { b = b } }
	local id = 0
	local ledger = Ledger.new(function(user) return inventories[user] end, function() id += 1; return tostring(id) end)
	assert(ledger:offer(1, 2, "a", "b").reason == "DESTINATION_COLLISION")
	inventories[1].b = nil
	local changed = ledger:offer(1, 2, "a", "b")
	a.uuid = "changed"
	assert(ledger:accept(2, changed.tradeId, true, true).reason == "INVENTORY_CHANGED")
	a.uuid = "a"
	local frozen = ledger:offer(1, 2, "a", "b")
	table.freeze(inventories[2])
	assert(ledger:accept(2, frozen.tradeId, true, true).reason == "INVENTORY_NOT_MUTABLE")
	assert(inventories[1].a == a and inventories[1].b == nil and inventories[2].b == b)
end)
check("stop and concurrent acceptance cannot revive a reservation", function()
	local h = harness(); local a, b = h.players[1], h.players[2]
	local pa, pb = seed(h, a), seed(h, b)
	local offer = h.service.initiateTwoPhaseTrade(a, b, pa.uuid, pb.uuid)
	h.onPolicy = function() h.onPolicy = nil; h.service.stop() end
	assert(not h.service.acceptTrade(b, offer.tradeId).success)
	local other = harness(); local a2, b2 = other.players[1], other.players[2]
	local pa2, pb2 = seed(other, a2), seed(other, b2)
	local pending = other.service.initiateTwoPhaseTrade(a2, b2, pa2.uuid, pb2.uuid)
	local nested
	other.onPolicy = function() other.onPolicy = nil; nested = other.service.acceptTrade(b2, pending.tradeId) end
	assert(not other.service.acceptTrade(b2, pending.tradeId).success and nested.success)
	assert(other.service.getPlayerPets(a2)[1] == pb2 and other.service.getPlayerPets(b2)[1] == pa2)
end)
check("policy errors and missing booleans deny paid but not free transfers", function()
	local h = harness(); local a, b = h.players[1], h.players[2]
	local pa, pb = seed(h, a), seed(h, b); pa.acquisitionPath = "Event_Crate"
	h.policies[2] = nil
	local offer = h.service.initiateTwoPhaseTrade(a, b, pa.uuid, pb.uuid)
	assert(not h.service.acceptTrade(b, offer.tradeId).success)
	h.policies[2] = true; h.policyError = true
	offer = h.service.initiateTwoPhaseTrade(a, b, pa.uuid, pb.uuid)
	assert(not h.service.acceptTrade(b, offer.tradeId).success)
	pa.acquisitionPath = "Earned_Free"
	offer = h.service.initiateTwoPhaseTrade(a, b, pa.uuid, pb.uuid)
	assert(h.service.acceptTrade(b, offer.tradeId).success)
end)
for _, failure in failures do print("FAIL " .. failure) end
assert(#failures == 0, tostring(#failures) .. " transaction rules failed")
print("PASS Slime state and transactions: " .. cases .. " rules")
