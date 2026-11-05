--!strict
-- ModuleScript state is client-local; LocalScript return values are not public APIs.
local Registry = {}
local visuals: { [string]: Instance } = {}

function Registry.register(uuid: string, visual: Instance): () -> ()
	visuals[uuid] = visual
	return function() if visuals[uuid] == visual then visuals[uuid] = nil end end
end

function Registry.get(uuid: string): Instance?
	return visuals[uuid]
end

function Registry.clear()
	table.clear(visuals)
end

return Registry
