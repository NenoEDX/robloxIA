--!strict
--[[
	MonetizationService.luau
	DevEx 2026 Compliant Developer Product Handler & Idempotent Receipt Processing
	para Zombie Awareness (v4.0).
--]]

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local DataPersistenceService = require(script.Parent:WaitForChild("DataPersistenceService") :: any)

local PurchaseHistoryStore: DataStore? = nil
pcall(function()
	PurchaseHistoryStore = DataStoreService:GetDataStore("ZA_PurchaseHistory_v4")
end)

local MonetizationService = {}
MonetizationService.__index = MonetizationService

local inSessionFulfilledReceipts: { [string]: number } = {}
local DEDUPE_CACHE_TTL = 3600

local function cleanDedupeCache()
	local now = os.time()
	for pId, timestamp in pairs(inSessionFulfilledReceipts) do
		if now - timestamp > DEDUPE_CACHE_TTL then
			inSessionFulfilledReceipts[pId] = nil
		end
	end
end

local productHandlers: { [number]: (player: Player) -> boolean } = {
	[1001] = function(player: Player)
		local data = DataPersistenceService.getData(player)
		if data then
			data.scrap += 1500
			data.components += 45
			DataPersistenceService.flushCriticalTransaction(player, "Product_ScrapPack_1001")
			return true
		end
		return false
	end,
	[1002] = function(player: Player)
		local data = DataPersistenceService.getData(player)
		if data then
			data.consciousnessCores += 15
			DataPersistenceService.flushCriticalTransaction(player, "Product_CorePack_1002")
			return true
		end
		return false
	end,
}

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local purchaseId = tostring(receiptInfo.PurchaseId)
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local recordKey = "Receipt_" .. purchaseId

	cleanDedupeCache()

	if PurchaseHistoryStore then
		local store = PurchaseHistoryStore :: DataStore
		local checkSuccess, record = pcall(function()
			return store:GetAsync(recordKey)
		end)
		if checkSuccess and record and record.granted == true then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if PurchaseHistoryStore then
		local store = PurchaseHistoryStore :: DataStore
		local persistSuccess = pcall(function()
			return store:UpdateAsync(recordKey, function(current: any)
				if current and current.granted == true then
					return current
				end
				return {
					purchaseId = purchaseId,
					playerId = playerId,
					productId = productId,
					timestamp = os.time(),
					granted = false,
				}
			end)
		end)
		if not persistSuccess then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	if not inSessionFulfilledReceipts[purchaseId] then
		local handler = productHandlers[productId]
		if not handler then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local grantSuccess, grantOk = pcall(handler, player)
		if not grantSuccess or not grantOk then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		inSessionFulfilledReceipts[purchaseId] = os.time()
	end

	if PurchaseHistoryStore then
		local store = PurchaseHistoryStore :: DataStore
		local updateSuccess = pcall(function()
			return store:UpdateAsync(recordKey, function(saved: any)
				local data = saved or {
					purchaseId = purchaseId,
					playerId = playerId,
					productId = productId,
					timestamp = os.time(),
				}
				data.granted = true
				return data
			end)
		end)
		if not updateSuccess then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.registerProductHandler(productId: number, handler: (player: Player) -> boolean)
	productHandlers[productId] = handler
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt
end

MonetizationService.init()

return MonetizationService
