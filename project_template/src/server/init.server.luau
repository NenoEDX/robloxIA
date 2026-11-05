--!strict
--[[
	init.server.luau
	Server Bootstrap Autoritativo para Zombie Awareness (v4.0) bajo el estándar RAASE 3.0.
	Inicializa seguridad Zero-Trust, Persistencia con Session Locking, Generación por Semilla (Z0–Z7),
	Control Territorial de Amenaza, IA Masiva de 3 Facciones (180 NPCs en Object Pool + ServerBossMutex),
	Combate/Arsenal Modular (Lv1–Lv10 + G-20) y el EventSchedulerService (E-01 a E-16).
--]]

local NetworkSecurityService = require(script:WaitForChild("NetworkSecurityService") :: any)
local DataPersistenceService = require(script:WaitForChild("DataPersistenceService") :: any)
local MonetizationService = require(script:WaitForChild("MonetizationService") :: any)
local MissionGenService = require(script:WaitForChild("MissionGenService") :: any)
local ThreatAndDistrictService = require(script:WaitForChild("ThreatAndDistrictService") :: any)
local AIService = require(script:WaitForChild("AIService") :: any)
local CombatAndArsenalService = require(script:WaitForChild("CombatAndArsenalService") :: any)
local EventSchedulerService = require(script:WaitForChild("EventSchedulerService") :: any)
local SlimeCoreService = require(script:WaitForChild("SlimeCoreService") :: any)
SlimeCoreService.start()
game:BindToClose(function() SlimeCoreService.stop() end)

-- Ejecutar el Pipeline Determinista y construir el Anfiteatro Abisal de Slimes Abismales
local worldReport = MissionGenService.generateWorldFromSeed("ZA40SEED")
EventSchedulerService.seedInitialEcosystem()
SlimeCoreService.buildAbyssalAmphitheater()

print(
	string.format(
		"[Zombie Awareness v4.0 / RAASE 3.0] Servidor inicializado | Semilla: %s | Instancias: %d | Pathfinding OK: %s | NPCs Activos: %d",
		worldReport.seedString,
		worldReport.instancesCreated,
		tostring(worldReport.pathfindingVerified),
		AIService.getActiveNPCCount()
	)
)
