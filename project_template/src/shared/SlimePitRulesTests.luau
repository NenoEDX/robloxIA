--!strict
-- Executed through the official Studio MCP; no source-text assertions.
local Tests = {}

function Tests.run(): { passed: number }
	local candidate = script.Parent:FindFirstChild("SlimePitRules")
	assert(candidate, "RED: SlimePitRules is not implemented")
	local Rules = require(candidate :: ModuleScript)
	assert(script.Parent:FindFirstChild("Types"), "Shared type module must be deployed")
	require(script.Parent.Types)
	local passed = 0
	local function check(value: boolean, message: string)
		assert(value, message)
		passed += 1
	end
	check(Rules.canHarvest(0, 1000, 0, 8, 100), "Empty pack accepts a node")
	check(not Rules.canHarvest(950, 1000, 0, 8, 100), "Tank overflow rejects")
	check(not Rules.canHarvest(0, 1000, 8, 8, 100), "Full pack rejects")
	check(not Rules.canHarvest(0, 1000, 0, 8, -1), "Negative rewards reject")
	check(not Rules.canHarvest(0/0, 1000, 0, 8, 100), "Nonfinite state rejects")
	check(not Rules.completed(10, 11, 2, 3, true), "Early trigger rejects")
	check(Rules.completed(10, 12.1, 2, 3, true), "Held prompt completes")
	check(not Rules.completed(10, 13, 2, 30, true), "Distant trigger rejects")
	check(not Rules.completed(10, 13, 2, 3, false), "Dead player rejects")
	check(not Rules.completed(nil, 13, 2, 3, true), "Unstarted hold rejects")
	return { passed = passed }
end

return Tests
