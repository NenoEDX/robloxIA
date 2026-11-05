--!strict
-- Preserve server wire payloads; validate and adapt them at the presentation boundary.
local Contract = {}
Contract.Names = table.freeze({
	ExtractionRarityAnim = "Slime_ExtractionRarityAnim",
	BaseArrivalAnim = "Slime_BaseArrivalAnim",
	MutationStrikeDropAnim = "Slime_MutationStrikeDropAnim",
	PetExtractedMutationAnim = "Slime_PetExtractedMutationAnim",
	CrateRevealAnim = "Slime_CrateRevealAnim",
	AdminAbuseBroadcast = "Slime_AdminAbuseBroadcast",
	DynamicCapturePrompt = "Slime_DynamicCapturePrompt",
})

local function text(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 128
end
local function numberIn(value: any, low: number, high: number): boolean
	return type(value) == "number" and value == value and value >= low and value <= high
end
local function grade(value: any): boolean
	if not text(value) then return false end
	local rank = string.match(value, "^GRADE_(%d%d)_[A-Z_]+$")
	return rank ~= nil and numberIn(tonumber(rank), 1, 10)
end
local function pet(value: any): boolean
	return type(value) == "table" and text(value.slimeId) and text(value.uuid)
end

function Contract.dispatch(key: string, handler: (...any) -> (), a: any, b: any): boolean
	if key == "ExtractionRarityAnim" then
		if not grade(a) or not numberIn(b, 0, 1) then return false end
		handler(a, b)
	elseif key == "BaseArrivalAnim" then
		if not pet(a) or not numberIn(b, 0, 10) or b % 1 ~= 0 then return false end
		handler(a.slimeId, b)
	elseif key == "PetExtractedMutationAnim" or key == "MutationStrikeDropAnim" then
		if not pet(a) or type(b) ~= "table" or not text(b.id) then return false end
		handler(if key == "MutationStrikeDropAnim" then a.uuid else a.slimeId, b.id)
	elseif key == "CrateRevealAnim" then
		if type(a) ~= "table" or #a < 1 or #a > 10 or type(b) ~= "boolean" then return false end
		local highest = ""
		for _, item in a do
			if type(item) ~= "table" or not grade(item.rarityGrade) then return false end
			if item.rarityGrade > highest then highest = item.rarityGrade end
		end
		handler(highest, b)
	elseif key == "AdminAbuseBroadcast" then
		if type(a) ~= "table" or not text(a.commandType) or not text(a.triggeredByName) then return false end
		handler(a.commandType, a.triggeredByName)
	elseif key == "DynamicCapturePrompt" then
		if type(a) ~= "table" or not numberIn(a.computedRobuxCost, 0, 1e9)
			or type(a.isDailyFreeAvailable) ~= "boolean" then return false end
		handler(a) -- Informational only: never initiates a purchase.
	else
		return false
	end
	return true
end

-- The folder/signal boundary is duck-typed for executable tests without Studio.
function Contract.connect(folder: any, handlers: { [string]: (...any) -> () }, onRejected: (string) -> ()): () -> ()
	local active = true
	local connections = {}
	local bound = {}
	local function attach(remote: any)
		if not active or bound[remote] or not remote:IsA("RemoteEvent") then return end
		for key, handler in handlers do
			if remote.Name == Contract.Names[key] then
				bound[remote] = true
				table.insert(connections, remote.OnClientEvent:Connect(function(a: any, b: any)
					if active and not Contract.dispatch(key, handler, a, b) then onRejected(key) end
				end))
			end
		end
	end
	table.insert(connections, folder.ChildAdded:Connect(attach))
	for _, remote in folder:GetChildren() do attach(remote) end
	return function()
		if not active then return end
		active = false
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
		table.clear(bound)
	end
end

return Contract
