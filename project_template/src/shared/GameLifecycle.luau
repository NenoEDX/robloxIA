--!strict
-- Pure lifecycle scope. Cleanup callbacks own their resources; no Roblox globals.
local GameLifecycle = {}
GameLifecycle.__index = GameLifecycle

export type Scope = typeof(setmetatable({
	active = false,
	generation = 0,
	_cleanups = {} :: { () -> () },
}, GameLifecycle))

function GameLifecycle.new(): Scope
	return setmetatable({ active = false, generation = 0, _cleanups = {} }, GameLifecycle)
end

function GameLifecycle.isCurrent(self: Scope, generation: number): boolean
	return self.active and self.generation == generation
end

function GameLifecycle.track(self: Scope, cleanup: () -> ())
	if self.active then
		table.insert(self._cleanups, cleanup)
	else
		cleanup()
	end
end

function GameLifecycle.stop(self: Scope): (boolean, { string })
	if not self.active then return false, {} end
	self.active = false
	local cleanups = self._cleanups
	self._cleanups = {}
	local errors = {}
	for i = #cleanups, 1, -1 do
		local ok, reason = pcall(cleanups[i])
		if not ok then table.insert(errors, tostring(reason)) end
	end
	return true, errors
end

function GameLifecycle.start(self: Scope, setup: (() -> ())?): boolean
	if self.active then return false end
	self.generation += 1
	self.active = true
	if setup then
		local ok, reason = pcall(setup)
		if not ok then
			self:stop()
			error(reason, 0)
		end
	end
	return true
end

return GameLifecycle
