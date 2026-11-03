--!strict
-- SLIME PIT only. Do not import Zombie persistence, purchases, AI, or world generation.
-- Existing Slime gameplay limitations are tracked separately in T5/T6.

require(script:WaitForChild("NetworkSecurityService") :: ModuleScript)
local SlimeCoreService = require(script:WaitForChild("SlimeCoreService") :: ModuleScript)

local world = SlimeCoreService.buildAbyssalAmphitheater()
print(string.format("[SLIME PIT] Server initialized | World: %s", world:GetFullName()))
