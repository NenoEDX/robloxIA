--!strict
-- SLIME PIT only. Do not import Zombie persistence, purchases, AI, or world generation.
-- Existing Slime gameplay limitations are tracked separately in T5/T6.

require(script:WaitForChild("NetworkSecurityService") :: ModuleScript)
local SlimeCoreService = require(script:WaitForChild("SlimeCoreService") :: ModuleScript)
local SlimePitService = require(script:WaitForChild("SlimePitService") :: ModuleScript)

SlimeCoreService.start()
SlimePitService.start()
game:BindToClose(function()
	SlimePitService.stop()
	SlimeCoreService.stop()
end)
