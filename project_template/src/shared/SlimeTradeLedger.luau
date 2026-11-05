--!strict
-- Server-owned, session-only offers. All yielding policy work occurs before accept.
local Ledger = {}
Ledger.__index = Ledger
export type Result = { success: boolean, reason: string?, tradeId: string? }
type Inventory = { [string]: any }
local function failure(reason: string): Result return { success = false, reason = reason } end
local function userId(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end

function Ledger.new(inventoryFor: (number) -> Inventory?, nextId: () -> string)
	return setmetatable({ _inventoryFor = inventoryFor, _nextId = nextId, _offers = {}, _locks = {} }, Ledger)
end

function Ledger._release(self: any, id: string)
	local offer = self._offers[id]
	if not offer then return end
	self._locks[offer.itemA] = nil
	self._locks[offer.itemB] = nil
	self._offers[id] = nil
end

function Ledger.offer(self: any, a: number, b: number, itemA: string, itemB: string): Result
	if not userId(a) or not userId(b) or a == b then return failure("INVALID_PARTICIPANTS") end
	if type(itemA) ~= "string" or itemA == "" or type(itemB) ~= "string" or itemB == "" or itemA == itemB then
		return failure("INVALID_ITEMS")
	end
	local invA, invB = self._inventoryFor(a), self._inventoryFor(b)
	if not invA or not invB or invA == invB then return failure("INVENTORY_UNAVAILABLE") end
	local petA, petB = invA[itemA], invB[itemB]
	if not petA or not petB or petA.uuid ~= itemA or petB.uuid ~= itemB then return failure("ITEM_NOT_OWNED") end
	if invA[itemB] or invB[itemA] then return failure("DESTINATION_COLLISION") end
	if self._locks[itemA] or self._locks[itemB] then return failure("ITEM_RESERVED") end
	local id = self._nextId()
	if type(id) ~= "string" or id == "" or self._offers[id] then return failure("INVALID_TRADE_ID") end
	self._offers[id] = { a = a, b = b, itemA = itemA, itemB = itemB, invA = invA, invB = invB, petA = petA, petB = petB }
	self._locks[itemA], self._locks[itemB] = id, id
	return { success = false, reason = "AWAITING_ACCEPTANCE", tradeId = id }
end

function Ledger.participants(self: any, actor: number, id: string): (number?, number?)
	local offer = self._offers[id]
	if not offer or (actor ~= offer.a and actor ~= offer.b) then return nil, nil end
	return offer.a, offer.b
end

function Ledger.cancel(self: any, actor: number, id: string): Result
	if not self:participants(actor, id) then return failure("TRADE_NOT_FOUND") end
	self:_release(id)
	return { success = true }
end

function Ledger.cancelFor(self: any, actor: number)
	local ids = {}
	for id, offer in self._offers do if actor == offer.a or actor == offer.b then table.insert(ids, id) end end
	for _, id in ids do self:_release(id) end
end

function Ledger.clear(self: any)
	table.clear(self._offers)
	table.clear(self._locks)
end

function Ledger.accept(self: any, actor: number, id: string, paidAllowedA: boolean, paidAllowedB: boolean): Result
	local offer = self._offers[id]
	if not offer or (actor ~= offer.a and actor ~= offer.b) then return failure("TRADE_NOT_FOUND") end
	if actor ~= offer.b then return failure("AWAITING_ACCEPTANCE") end
	local invA, invB = self._inventoryFor(offer.a), self._inventoryFor(offer.b)
	local reason = nil
	if invA ~= offer.invA or invB ~= offer.invB or not invA or not invB
		or invA[offer.itemA] ~= offer.petA or invB[offer.itemB] ~= offer.petB
		or offer.petA.uuid ~= offer.itemA or offer.petB.uuid ~= offer.itemB then
		reason = "INVENTORY_CHANGED"
	elseif invA[offer.itemB] or invB[offer.itemA] then
		reason = "DESTINATION_COLLISION"
	elseif table.isfrozen(invA) or table.isfrozen(invB) or getmetatable(invA) ~= nil or getmetatable(invB) ~= nil then
		reason = "INVENTORY_NOT_MUTABLE"
	elseif (offer.petA.acquisitionPath ~= "Earned_Free" or offer.petB.acquisitionPath ~= "Earned_Free")
		and (paidAllowedA ~= true or paidAllowedB ~= true) then
		reason = "PAID_ITEM_TRADING_RESTRICTED"
	end
	if reason then self:_release(id); return failure(reason) end
	-- Plain mutable dictionaries; no callbacks or yields between validation and commit.
	invA[offer.itemA], invB[offer.itemB] = nil, nil
	invA[offer.itemB], invB[offer.itemA] = offer.petB, offer.petA
	self:_release(id)
	return { success = true }
end

return Ledger
