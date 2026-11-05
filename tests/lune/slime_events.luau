--!strict
local Contract = require("../../project_template/src/shared/SlimeEventContract")
local calls = {}
local function handler(...) table.insert(calls, table.pack(...)) end
local pet = { uuid = "pet-1", slimeId = "slime-1", mutations = { "mut-1" } }
local mutation = { id = "mut-1" }
assert(Contract.dispatch("ExtractionRarityAnim", handler, "GRADE_01_BASIC", 0.5))
assert(calls[1][1] == "GRADE_01_BASIC" and calls[1][2] == 0.5)
assert(Contract.dispatch("BaseArrivalAnim", handler, pet, 1))
assert(calls[2][1] == "slime-1" and calls[2][2] == 1)
assert(Contract.dispatch("PetExtractedMutationAnim", handler, pet, mutation))
assert(calls[3][1] == "slime-1" and calls[3][2] == "mut-1")
assert(Contract.dispatch("MutationStrikeDropAnim", handler, pet, mutation))
assert(calls[4][1] == "pet-1" and calls[4][2] == "mut-1")
assert(Contract.dispatch("CrateRevealAnim", handler, {
	{ rarityGrade = "GRADE_01_BASIC" }, { rarityGrade = "GRADE_10_CELESTIAL_II" },
}, true))
assert(calls[5][1] == "GRADE_10_CELESTIAL_II" and calls[5][2] == true)
assert(Contract.dispatch("AdminAbuseBroadcast", handler, {
	commandType = "HostBroadcast", triggeredByName = "Creator", durationSec = 10,
}))
assert(calls[6][1] == "HostBroadcast" and calls[6][2] == "Creator")
for _, args in {
	{ "ExtractionRarityAnim", "GRADE_01_BASIC", 0 / 0 },
	{ "ExtractionRarityAnim", "GRADE_01_BASIC", math.huge },
	{ "ExtractionRarityAnim", "GRADE_01_BASIC", -1 },
	{ "ExtractionRarityAnim", "GRADE_99_BAD", 0.5 },
	{ "ExtractionRarityAnim", "bad", 0.5 },
	{ "BaseArrivalAnim", "not a pet", 1 },
	{ "BaseArrivalAnim", pet, 1.5 },
	{ "BaseArrivalAnim", pet, 11 },
	{ "PetExtractedMutationAnim", pet, { id = string.rep("x", 129) } },
	{ "MutationStrikeDropAnim", pet, "not a mutation" },
	{ "CrateRevealAnim", {}, false },
	{ "CrateRevealAnim", table.create(11, { rarityGrade = "GRADE_01_BASIC" }), false },
	{ "CrateRevealAnim", { { rarityGrade = "GRADE_01_BASIC" } }, "true" },
	{ "AdminAbuseBroadcast", { commandType = "HostBroadcast" } },
	{ "unknown", pet, mutation },
} do
	assert(not Contract.dispatch(args[1], handler, args[2], args[3]))
end
assert(#calls == 6, "Malformed packets must not reach presentation")

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() local i = table.find(callbacks, callback); if i then table.remove(callbacks, i) end end }
		end,
		Fire = function(_, ...) for _, callback in table.clone(callbacks) do callback(...) end end,
	}
end
local remote = { Name = Contract.Names.ExtractionRarityAnim, OnClientEvent = signal(), IsA = function(_, name) return name == "RemoteEvent" end }
local children = {}
local folder = { ChildAdded = signal(), GetChildren = function() return children end }
local rejected = 0
local stop = Contract.connect(folder, { ExtractionRarityAnim = handler }, function() rejected += 1 end)
table.insert(children, remote)
folder.ChildAdded:Fire(remote)
folder.ChildAdded:Fire(remote)
remote.OnClientEvent:Fire("GRADE_01_BASIC", 0.2)
assert(#calls == 7, "Late replication must bind once")
remote.OnClientEvent:Fire("bad", 0.2)
assert(rejected == 1 and #calls == 7)
stop(); stop()
remote.OnClientEvent:Fire("GRADE_01_BASIC", 0.2)
folder.ChildAdded:Fire(remote)
assert(#calls == 7, "Cleanup must disconnect all listeners")
local expected = { "ExtractionRarityAnim", "BaseArrivalAnim", "MutationStrikeDropAnim", "PetExtractedMutationAnim", "CrateRevealAnim", "AdminAbuseBroadcast", "DynamicCapturePrompt" }
local count = 0
for _ in Contract.Names do count += 1 end
assert(count == #expected)
for _, key in expected do assert(Contract.Names[key] == "Slime_" .. key) end
print("PASS slime events: wire compatibility, payload adaptation, rejection, late replication and cleanup")
