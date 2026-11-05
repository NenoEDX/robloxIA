--!strict
local Rules = {}
Rules.TANK_CAPACITY = 1000
Rules.PACK_CAPACITY = 8
Rules.INTERACTION_DISTANCE = 12
Rules.RESPAWN_SECONDS = 12

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function Rules.canHarvest(juice: number, capacity: number, count: number, slots: number, reward: number): boolean
	return finite(juice) and finite(capacity) and finite(count) and finite(slots) and finite(reward)
		and juice >= 0 and count >= 0 and count % 1 == 0 and slots > 0 and count < slots
		and reward > 0 and juice + reward <= capacity
end

function Rules.completed(started: number?, now: number, duration: number, distance: number, alive: boolean): boolean
	return started ~= nil and finite(started) and finite(now) and finite(distance)
		and duration > 0 and now - started >= duration and now - started <= duration + 4
		and distance >= 0 and distance <= Rules.INTERACTION_DISTANCE and alive
end

return table.freeze(Rules)
