--!strict
--[[
	ThreatAndDistrictService.luau
	Control Territorial, Amenaza por Distrito (Z0–Z7), Fortificación y Liberación (Sección 1 y 2.2):
	- Regeneración pasiva de +5 puntos de amenaza por minuto en zonas no liberadas.
	- Asignación de Especialistas rescatados (Constructores H-02, Ingenieros H-03, Soldados H-20, Capitanes H-29)
	  para reconstruir el Puesto Avanzado (Outpost), la Fábrica/Mina, el Repeller sónico y las Torretas.
	- Conversión dinámica al llegar a Amenaza 0: detiene regeneración pasiva, habilita Persistent Streaming,
	  abre extracción segura y tienda del puesto avanzado, y dispara E-10 al liberar Z5.
	- Distribución matemática de botín por anillo (Z1: 4%/1%/0% -> Z7: 28% Épico, 12% Legendario, 5% Único).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local ZombieCatalogs = require(sharedFolder:WaitForChild("ZombieCatalogs") :: any)

local DataPersistenceService = require(script.Parent:WaitForChild("DataPersistenceService") :: any)

local ThreatAndDistrictService = {}
ThreatAndDistrictService.__index = ThreatAndDistrictService

local districtStates: { [Types.DistrictId]: Types.DistrictRuntimeState } = {}
local liberationCallbacks: { (districtId: Types.DistrictId) -> () } = {}
local nightHuntBonusActive = false

local function initDistrictStates()
	for distId, cfg in pairs(ZombieCatalogs.Districts) do
		local isSafe = distId == "Z0"
		districtStates[distId] = {
			id = distId,
			threatLevel = cfg.initialThreat,
			maxThreat = cfg.maxThreat,
			liberated = isSafe,
			outpostRebuilt = isSafe,
			factoryRebuilt = isSafe,
			shelterRebuilt = isSafe,
			repellerActive = isSafe,
			assignedBuilders = if isSafe then 2 else 0,
			assignedEngineers = if isSafe then 2 else 0,
			assignedSoldiers = if isSafe then 4 else 0,
			assignedCaptains = if isSafe then 1 else 0,
			quarantineLockedUntil = 0,
		}
		Workspace:SetAttribute("ZA_Threat_" .. distId, cfg.initialThreat)
		Workspace:SetAttribute("ZA_Liberated_" .. distId, isSafe)
	end
end

initDistrictStates()

local function syncDistrictAttributes(distId: Types.DistrictId)
	local st = districtStates[distId]
	if not st then
		return
	end
	Workspace:SetAttribute("ZA_Threat_" .. distId, st.threatLevel)
	Workspace:SetAttribute("ZA_Liberated_" .. distId, st.liberated)
	Workspace:SetAttribute("ZA_Repeller_" .. distId, st.repellerActive)
	Workspace:SetAttribute("ZA_Factory_" .. distId, st.factoryRebuilt)
end

function ThreatAndDistrictService.getDistrictState(distId: Types.DistrictId): Types.DistrictRuntimeState?
	return districtStates[distId]
end

function ThreatAndDistrictService.getAllDistrictStates(): { [Types.DistrictId]: Types.DistrictRuntimeState }
	return districtStates
end

function ThreatAndDistrictService.onDistrictLiberated(callback: (districtId: Types.DistrictId) -> ())
	table.insert(liberationCallbacks, callback)
end

function ThreatAndDistrictService.setNightHuntActive(active: boolean)
	nightHuntBonusActive = active
	Workspace:SetAttribute("ZA_NightHuntActive", active)
end

function ThreatAndDistrictService.isNightHuntActive(): boolean
	return nightHuntBonusActive
end

function ThreatAndDistrictService.modifyThreat(distId: Types.DistrictId, delta: number, reason: string?): number
	local st = districtStates[distId]
	if not st or distId == "Z0" then
		return 0
	end

	-- Si el distrito ya fue liberado permanentemente, su amenaza no vuelve a subir salvo invasión de Mega Bruto E-16
	if st.liberated and delta > 0 and reason ~= "MegaBossRampage" then
		return st.threatLevel
	end

	-- Si está bajo Cierre de Cuarentena (E-08), los incrementos de amenaza se duplican
	local effectiveDelta = delta
	if delta > 0 and os.time() < st.quarantineLockedUntil then
		effectiveDelta = delta * 2
	end

	st.threatLevel = math.clamp(math.floor(st.threatLevel + effectiveDelta), 0, st.maxThreat)

	if st.threatLevel == 0 and not st.liberated and distId ~= "Special_West" and distId ~= "Special_East" then
		ThreatAndDistrictService.liberateDistrict(distId)
	else
		syncDistrictAttributes(distId)
	end

	return st.threatLevel
end

function ThreatAndDistrictService.liberateDistrict(distId: Types.DistrictId)
	local st = districtStates[distId]
	if not st or st.liberated then
		return
	end

	st.threatLevel = 0
	st.liberated = true
	st.outpostRebuilt = true
	st.repellerActive = true
	syncDistrictAttributes(distId)

	-- Otorgar progreso de liberación y extraer automáticamente la mochila táctica de los jugadores presentes
	for _, player in Players:GetPlayers() do
		local data = DataPersistenceService.getData(player)
		if data then
			data.liberatedDistricts[distId] = true
			data.humanLoyalty = math.min(100, data.humanLoyalty + 15)
			DataPersistenceService.extractBackpackToSafeVault(player)
		end
	end

	for _, cb in ipairs(liberationCallbacks) do
		task.spawn(cb, distId)
	end
end

--[[
	Asigna especialistas rescatados por el jugador al Puesto Avanzado de un distrito (Sección 2.2):
	- H-02 Constructor: levanta muros, barricadas y reconstruye la Fábrica (-35 amenaza).
	- H-03 Ingeniero: activa el generador, el Repeller sónico y las torretas automáticas (-40 amenaza).
	- H-20 Soldado: guarnece el perímetro (-25 amenaza).
	- H-29 Capitán: lidera la defensa del puesto (-60 amenaza).
--]]
function ThreatAndDistrictService.assignSpecialistToDistrict(
	player: Player,
	distId: Types.DistrictId,
	specialistId: string
): (boolean, string)
	local st = districtStates[distId]
	if not st or distId == "Z0" then
		return false, "Distrito inválido para fortificación"
	end

	local data = DataPersistenceService.getData(player)
	if not data then
		return false, "Perfil de jugador no cargado"
	end

	local available = data.rescuedSpecialists[specialistId] or 0
	if available <= 0 then
		return false, "No dispones de especialistas rescatados de tipo " .. tostring(specialistId)
	end

	data.rescuedSpecialists[specialistId] = available - 1

	if specialistId == "H-02" then
		st.assignedBuilders += 1
		st.factoryRebuilt = true
		st.shelterRebuilt = true
		ThreatAndDistrictService.modifyThreat(distId, -35, "BuilderFortification")
	elseif specialistId == "H-03" then
		st.assignedEngineers += 1
		st.repellerActive = true
		st.outpostRebuilt = true
		ThreatAndDistrictService.modifyThreat(distId, -40, "EngineerRepeller")
	elseif specialistId == "H-20" then
		st.assignedSoldiers += 1
		ThreatAndDistrictService.modifyThreat(distId, -25, "SoldierGarrison")
	elseif specialistId == "H-29" then
		st.assignedCaptains += 1
		ThreatAndDistrictService.modifyThreat(distId, -60, "CaptainCommand")
	else
		ThreatAndDistrictService.modifyThreat(distId, -20, "SpecialistSupport")
	end

	syncDistrictAttributes(distId)
	DataPersistenceService.syncLeaderstats(player, data)
	return true, string.format("Especialista %s asignado a %s (Amenaza actual: %d)", specialistId, distId, st.threatLevel)
end

--[[
	Calcula la rareza de botín para un distrito según las probabilidades de la Sección 4.1,
	aplicando los multiplicadores de E-08 (Cierre de Cuarentena x2) y E-09 (Noche de Caza +30%).
--]]
function ThreatAndDistrictService.rollLootRarity(distId: Types.DistrictId): Types.LootRarity
	local cfg = ZombieCatalogs.Districts[distId] or ZombieCatalogs.Districts.Z1
	local st = districtStates[distId]
	local w = cfg.lootWeights

	local rareBoost = 1.0
	if st and os.time() < st.quarantineLockedUntil then
		rareBoost *= 2.0
	end
	if nightHuntBonusActive then
		rareBoost *= 1.30
	end

	local uniqueWeight = w.Unique * rareBoost
	local legendaryWeight = w.Legendary * rareBoost
	local epicWeight = w.Epic * rareBoost
	local rareWeight = w.Rare * rareBoost
	local commonWeight = w.Common

	local total = uniqueWeight + legendaryWeight + epicWeight + rareWeight + commonWeight
	local roll = math.random() * total

	if roll <= uniqueWeight then
		return "Unique"
	elseif roll <= uniqueWeight + legendaryWeight then
		return "Legendary"
	elseif roll <= uniqueWeight + legendaryWeight + epicWeight then
		return "Epic"
	elseif roll <= uniqueWeight + legendaryWeight + epicWeight + rareWeight then
		return "Rare"
	end
	return "Common"
end

function ThreatAndDistrictService.getDistrictAtPosition(position: Vector3): Types.DistrictId
	local bestId: Types.DistrictId = "Z1"
	local bestDist = math.huge

	for distId, cfg in pairs(ZombieCatalogs.Districts) do
		local d = (Vector3.new(position.X, 0, position.Z) - Vector3.new(cfg.centerPosition.X, 0, cfg.centerPosition.Z)).Magnitude
		if d <= cfg.radiusStuds and d < bestDist then
			bestDist = d
			bestId = distId
		end
	end
	return bestId
end

-- Regeneración pasiva de amenaza (+5 puntos por minuto en distritos no liberados, Sección 1 y 2.2)
task.spawn(function()
	while true do
		task.wait(60)
		for distId, st in pairs(districtStates) do
			local cfg = ZombieCatalogs.Districts[distId]
			if cfg and not st.liberated and cfg.passiveRegenPerMin > 0 then
				-- Si el Repeller sónico fue activado por un Ingeniero (H-03), frena la regeneración pasiva
				if not st.repellerActive then
					ThreatAndDistrictService.modifyThreat(distId, cfg.passiveRegenPerMin, "PassiveRegen")
				end
			end
		end
	end
end)

return ThreatAndDistrictService
