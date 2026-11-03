--!strict
-- Zombie-only composition. Modules remain children of this Script for sibling imports.
-- The legacy mixed bootstrap remains unchanged and is not mapped by zombie.project.json.

require(script:WaitForChild("NetworkSecurityService") :: ModuleScript)
require(script:WaitForChild("DataPersistenceService") :: ModuleScript)
require(script:WaitForChild("MonetizationService") :: ModuleScript)
local MissionGenService = require(script:WaitForChild("MissionGenService") :: ModuleScript)
require(script:WaitForChild("ThreatAndDistrictService") :: ModuleScript)
local AIService = require(script:WaitForChild("AIService") :: ModuleScript)
require(script:WaitForChild("CombatAndArsenalService") :: ModuleScript)
local EventSchedulerService = require(script:WaitForChild("EventSchedulerService") :: ModuleScript)

local worldReport = MissionGenService.generateWorldFromSeed("ZA40SEED")
EventSchedulerService.seedInitialEcosystem()

print(string.format(
	"[Zombie Awareness v4.0 / RAASE 3.0] Server initialized | Seed: %s | Instances: %d | Pathfinding OK: %s | Active NPCs: %d",
	worldReport.seedString,
	worldReport.instancesCreated,
	tostring(worldReport.pathfindingVerified),
	AIService.getActiveNPCCount()
))
