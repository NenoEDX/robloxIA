--!strict
--[[
	DataPersistenceService.luau
	Persistencia Autoritativa de Zombie Awareness (v4.0) (Sección 6.2):
	- DataStore único "PlayerData" bajo clave "User_{UserId}" con Session Locking obligatorio.
	- Reintentos con Exponential Backoff + Jitter aleatorio.
	- Búfer en memoria con volcados cada 180s (con desfase aleatorio), BindToClose y
	  guardado inmediato en transacciones críticas (Edificio Tier 3, Arma Nivel 10, Contratar Mercenario).
	- Bucle de Mochila Táctica vs. Bóveda Segura (Extracción y penalización del 50% al morir).
	- Generación pasiva por Especialistas Rescatados y Jardín Hidropónico (A-21).
	- Clasificaciones globales de caza de Mega Brutos en MemoryStoreService.
--]]

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local ZombieCatalogs = require(sharedFolder:WaitForChild("ZombieCatalogs") :: any)

local DataPersistenceService = {}
DataPersistenceService.__index = DataPersistenceService

local SESSION_LOCK_TIMEOUT_SEC = 900 -- 15 minutos de gracia
local AUTOSAVE_INTERVAL_SEC = 180 -- Volcado periódico cada 180s según Sección 6.2
local CURRENT_JOB_ID = if game.JobId ~= "" then game.JobId else "Studio_Session_" .. tostring(math.random(10000, 99999))

local playerDataStore: DataStore? = nil
pcall(function()
	playerDataStore = DataStoreService:GetDataStore("PlayerData")
end)

local bossLeaderboardMap: MemoryStoreSortedMap? = nil
pcall(function()
	bossLeaderboardMap = MemoryStoreService:GetSortedMap("MegaBossHuntLeaderboard_v4")
end)

local activeSessions: { [number]: Types.PlayerData } = {}
local savingInProgress: { [number]: boolean } = {}
local activeSavingCount = 0

local function generateRefugeSeed(userId: number): string
	local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	local rng = Random.new(userId + 4096)
	local out = table.create(8)
	for i = 1, 8 do
		local idx = rng:NextInteger(1, #chars)
		out[i] = string.sub(chars, idx, idx)
	end
	return table.concat(out)
end

local function createDefaultPlayerData(userId: number): Types.PlayerData
	return {
		schemaVersion = 4,
		refugeSeed = generateRefugeSeed(userId),
		scrap = 250,
		components = 15,
		consciousnessCores = 1,
		humanLoyalty = 25,
		renegadeUntil = 0,
		g20Tier = 0,
		squadCap = 2,
		ammoPools = {
			Light = 180,
			Medium = 120,
			Heavy = 64,
			Special = 40,
			Explosive = 6,
		},
		weaponLevels = {
			["G-01"] = 1,
			["G-05"] = 1,
			["G-07"] = 1,
			["G-09"] = 1,
			["M-02"] = 1,
			["M-05"] = 1,
		},
		loadout = {
			slot1_PrimaryA = "G-05",
			slot2_PrimaryB = "G-07",
			slot3_Sniper = "G-09",
			slot4_SecondaryA = "G-01",
			slot5_SecondaryB = "G-04",
			slot6_MeleeA = "M-02",
			slot7_MeleeB = "M-05",
			slot8_Special = "G-15",
			slot9_FlexA = "G-03",
			slot10_FlexB = "M-03",
			emitterG20Tier = 0,
		},
		rescuedSpecialists = {
			["H-01"] = 1,
		},
		refugeBuildings = {
			["A-01"] = 1,
			["A-02"] = 1,
			["A-07"] = 1,
			["A-08"] = 1,
			["A-21"] = 1,
		},
		hiredMercenaries = {
			Recruit = true,
			Sniper = false,
			FieldMedic = false,
			Sapper = false,
			Tamer = false,
			Ghost = false,
		},
		activeMercenaries = { "Recruit" },
		liberatedDistricts = {
			Z0 = true,
		},
		skillTree = {
			survivalRank = 1,
			consciousnessRank = 1,
			combatRank = 1,
			pulseUnlocked = true,
			tacticalDashUnlocked = true,
			qteExecutionUnlocked = true,
		},
		tacticalBackpack = {
			unsecuredScrap = 0,
			unsecuredComponents = 0,
			unsecuredCores = 0,
			escortedSpecialists = {},
			unsecuredLootItems = {},
		},
		bestMegaBossKillSec = nil,
		sessionLockTimestamp = nil,
		sessionLockJobId = nil,
	}
end

local function cloneTable<T>(tbl: T): T
	local result = {}
	for k, v in pairs(tbl :: any) do
		if typeof(v) == "table" then
			result[k] = cloneTable(v)
		else
			result[k] = v
		end
	end
	return (result :: any) :: T
end

local function retryWithBackoffAndJitter<T>(fn: () -> T, maxRetries: number?): (boolean, T | string)
	local retries = maxRetries or 4
	local baseDelaySec = 0.8

	for attempt = 1, retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < retries then
			local jitter = math.random() * 0.45
			task.wait(baseDelaySec + jitter)
			baseDelaySec *= 2
		else
			return false, tostring(result)
		end
	end
	return false, "Max retries exceeded"
end

function DataPersistenceService.getDataKey(userId: number): string
	return "User_" .. tostring(userId)
end

function DataPersistenceService.loadData(player: Player): Types.PlayerData?
	local userId = player.UserId
	local key = DataPersistenceService.getDataKey(userId)
	local now = os.time()
	local defaultProfile = createDefaultPlayerData(userId)

	if not playerDataStore or RunService:IsStudio() then
		defaultProfile.sessionLockTimestamp = now
		defaultProfile.sessionLockJobId = CURRENT_JOB_ID
		activeSessions[userId] = defaultProfile
		DataPersistenceService.syncLeaderstats(player, defaultProfile)
		return defaultProfile
	end

	local lockAcquired = false
	local store = playerDataStore :: DataStore

	local success, result = retryWithBackoffAndJitter(function()
		return store:UpdateAsync(key, function(saved: any)
			local data: Types.PlayerData = if type(saved) == "table" and saved.schemaVersion == 4
				then saved
				else cloneTable(defaultProfile)

			if data.sessionLockTimestamp and (now - data.sessionLockTimestamp) < SESSION_LOCK_TIMEOUT_SEC then
				if data.sessionLockJobId and data.sessionLockJobId ~= CURRENT_JOB_ID then
					lockAcquired = false
					return nil
				end
			end

			lockAcquired = true
			data.sessionLockTimestamp = now
			data.sessionLockJobId = CURRENT_JOB_ID
			return data
		end)
	end, 4)

	if not success or not lockAcquired or result == nil then
		warn(string.format("[DataPersistence v4.0] Session lock rechazado para %s (%d).", player.Name, userId))
		player:Kick("Tu perfil de Zombie Awareness v4.0 tiene una sesión bloqueada activa. Reintenta en unos segundos.")
		return nil
	end

	local loadedData = result :: Types.PlayerData
	activeSessions[userId] = loadedData
	DataPersistenceService.syncLeaderstats(player, loadedData)
	return loadedData
end

function DataPersistenceService.syncLeaderstats(player: Player, data: Types.PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats") :: Folder?
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local scrapVal = leaderstats:FindFirstChild("Chatarra") :: IntValue?
	if not scrapVal then
		scrapVal = Instance.new("IntValue")
		scrapVal.Name = "Chatarra"
		scrapVal.Parent = leaderstats
	end
	scrapVal.Value = math.floor(data.scrap)

	local coresVal = leaderstats:FindFirstChild("Nucleos") :: IntValue?
	if not coresVal then
		coresVal = Instance.new("IntValue")
		coresVal.Name = "Nucleos"
		coresVal.Parent = leaderstats
	end
	coresVal.Value = math.floor(data.consciousnessCores)

	player:SetAttribute("ZA_Scrap", data.scrap)
	player:SetAttribute("ZA_Components", data.components)
	player:SetAttribute("ZA_Cores", data.consciousnessCores)
	player:SetAttribute("ZA_UnsecuredScrap", data.tacticalBackpack.unsecuredScrap)
	player:SetAttribute("ZA_UnsecuredComponents", data.tacticalBackpack.unsecuredComponents)
	player:SetAttribute("ZA_UnsecuredCores", data.tacticalBackpack.unsecuredCores)
	player:SetAttribute("ZA_G20Tier", data.g20Tier)
	player:SetAttribute("ZA_HumanLoyalty", data.humanLoyalty)
end

function DataPersistenceService.saveData(player: Player, isReleasingSession: boolean): boolean
	local userId = player.UserId
	local data = activeSessions[userId]
	if not data then
		return false
	end

	if savingInProgress[userId] then
		while savingInProgress[userId] do
			task.wait(0.05)
		end
		if not isReleasingSession then
			return true
		end
	end

	savingInProgress[userId] = true
	activeSavingCount += 1

	local key = DataPersistenceService.getDataKey(userId)
	local okSave = true

	if playerDataStore and not RunService:IsStudio() then
		local store = playerDataStore :: DataStore
		local success, err = retryWithBackoffAndJitter(function()
			return store:UpdateAsync(key, function(current: any)
				if current and current.sessionLockJobId and current.sessionLockJobId ~= CURRENT_JOB_ID then
					warn(string.format("[DataPersistence v4.0] Lock tomado por otro servidor (%s)", tostring(current.sessionLockJobId)))
					return nil
				end

				local snapshot = cloneTable(data)
				if isReleasingSession then
					snapshot.sessionLockTimestamp = nil
					snapshot.sessionLockJobId = nil
				else
					snapshot.sessionLockTimestamp = os.time()
					snapshot.sessionLockJobId = CURRENT_JOB_ID
				end
				return snapshot
			end)
		end, 4)

		if not success then
			okSave = false
			warn(string.format("[DataPersistence v4.0] Error guardando %s: %s", key, tostring(err)))
		end
	end

	if isReleasingSession and okSave then
		activeSessions[userId] = nil
	end

	savingInProgress[userId] = nil
	activeSavingCount -= 1
	return okSave
end

--[[
	Guardado inmediato para transacciones críticas (Sección 6.2):
	- Subir edificio a Tier 3
	- Evolucionar arma a Nivel 10
	- Contratar Mercenario Permanente
--]]
function DataPersistenceService.flushCriticalTransaction(player: Player, transactionName: string)
	local data = activeSessions[player.UserId]
	if not data then
		return
	end
	DataPersistenceService.syncLeaderstats(player, data)
	task.spawn(function()
		DataPersistenceService.saveData(player, false)
	end)
end

function DataPersistenceService.getData(player: Player): Types.PlayerData?
	return activeSessions[player.UserId]
end

--------------------------------------------------------------------------------
-- MOCHILA TÁCTICA VS. BÓVEDA SEGURA (TAPÓN #2 DEL GAMELOOP)
--------------------------------------------------------------------------------

function DataPersistenceService.addUnsecuredLoot(
	player: Player,
	scrapDelta: number,
	componentsDelta: number,
	coresDelta: number
)
	local data = activeSessions[player.UserId]
	if not data then
		return
	end
	data.tacticalBackpack.unsecuredScrap += math.max(0, math.floor(scrapDelta))
	data.tacticalBackpack.unsecuredComponents += math.max(0, math.floor(componentsDelta))
	data.tacticalBackpack.unsecuredCores += math.max(0, math.floor(coresDelta))
	DataPersistenceService.syncLeaderstats(player, data)
end

function DataPersistenceService.stageRescuedSpecialist(player: Player, specialistId: string)
	local data = activeSessions[player.UserId]
	if not data then
		return
	end
	table.insert(data.tacticalBackpack.escortedSpecialists, specialistId)
	player:SetAttribute("ZA_EscortedCount", #data.tacticalBackpack.escortedSpecialists)
end

function DataPersistenceService.extractBackpackToSafeVault(player: Player): {
	extractedScrap: number,
	extractedComponents: number,
	extractedCores: number,
	extractedSpecialists: number,
}
	local data = activeSessions[player.UserId]
	if not data then
		return { extractedScrap = 0, extractedComponents = 0, extractedCores = 0, extractedSpecialists = 0 }
	end

	local bag = data.tacticalBackpack
	local s = bag.unsecuredScrap
	local c = bag.unsecuredComponents
	local k = bag.unsecuredCores
	local specCount = #bag.escortedSpecialists

	data.scrap += s
	data.components += c
	data.consciousnessCores += k

	for _, specId in ipairs(bag.escortedSpecialists) do
		data.rescuedSpecialists[specId] = (data.rescuedSpecialists[specId] or 0) + 1
		if specId == "H-01" then
			data.squadCap = math.min(6, data.squadCap + 1)
		end
	end

	bag.unsecuredScrap = 0
	bag.unsecuredComponents = 0
	bag.unsecuredCores = 0
	table.clear(bag.escortedSpecialists)
	table.clear(bag.unsecuredLootItems)

	player:SetAttribute("ZA_EscortedCount", 0)
	DataPersistenceService.syncLeaderstats(player, data)

	return {
		extractedScrap = s,
		extractedComponents = c,
		extractedCores = k,
		extractedSpecialists = specCount,
	}
end

function DataPersistenceService.applyDeathPenalty(player: Player): {
	droppedScrap: number,
	droppedComponents: number,
	lostEscorts: { string },
}
	local data = activeSessions[player.UserId]
	if not data then
		return { droppedScrap = 0, droppedComponents = 0, lostEscorts = {} }
	end

	local bag = data.tacticalBackpack
	local droppedScrap = math.floor(bag.unsecuredScrap * 0.5)
	local droppedComponents = math.floor(bag.unsecuredComponents * 0.5)
	local lostEscorts = table.clone(bag.escortedSpecialists)

	bag.unsecuredScrap -= droppedScrap
	bag.unsecuredComponents -= droppedComponents
	table.clear(bag.escortedSpecialists)

	player:SetAttribute("ZA_EscortedCount", 0)
	DataPersistenceService.syncLeaderstats(player, data)

	return {
		droppedScrap = droppedScrap,
		droppedComponents = droppedComponents,
		lostEscorts = lostEscorts,
	}
end

--------------------------------------------------------------------------------
-- GENERACIÓN PASIVA POR ESPECIALISTAS Y JARDÍN HIDROPÓNICO (A-21)
--------------------------------------------------------------------------------

function DataPersistenceService.processPassiveProductionTick(player: Player)
	local data = activeSessions[player.UserId]
	if not data then
		return
	end

	-- 1 Día de juego = 24 minutos reales -> 1 tick por minuto = 1/24 de la producción diaria
	local dailyScrap = 0
	local dailyComponents = 0
	local dailyCores = 0

	for specId, count in pairs(data.rescuedSpecialists) do
		local unitDef = ZombieCatalogs.Units[specId]
		if unitDef and unitDef.passiveDailyAmount and count > 0 then
			local totalAmount = unitDef.passiveDailyAmount * count
			if unitDef.passiveResourceType == "Scrap" then
				dailyScrap += totalAmount
			elseif unitDef.passiveResourceType == "Components" then
				dailyComponents += totalAmount
			elseif unitDef.passiveResourceType == "Cores" then
				dailyCores += totalAmount
			end
		end
	end

	-- Jardín Hidropónico A-21: +50 Chatarra/hora por tier
	local hydroTier = data.refugeBuildings["A-21"] or 0
	local hydroPerMin = (50 * hydroTier) / 60

	local scrapGain = math.max(1, math.floor((dailyScrap / 24) + hydroPerMin + 0.5))
	local compGain = math.floor((dailyComponents / 24) + 0.5)
	local coreGain = if dailyCores > 0 and math.random(1, 24) <= dailyCores then 1 else 0

	data.scrap += scrapGain
	data.components += compGain
	data.consciousnessCores += coreGain
	DataPersistenceService.syncLeaderstats(player, data)
end

function DataPersistenceService.recordMegaBossKillTime(player: Player, bossId: string, durationSec: number)
	local data = activeSessions[player.UserId]
	if data then
		if not data.bestMegaBossKillSec or durationSec < data.bestMegaBossKillSec then
			data.bestMegaBossKillSec = durationSec
		end
	end
	if bossLeaderboardMap then
		pcall(function()
			(bossLeaderboardMap :: MemoryStoreSortedMap):SetAsync(
				string.format("%s_%d", bossId, player.UserId),
				durationSec,
				86400 * 7
			)
		end)
	end
end

--------------------------------------------------------------------------------
-- CONEXIONES DE CICLO DE VIDA Y BUCLE DE GUARDADO
--------------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	DataPersistenceService.loadData(player)
end)

Players.PlayerRemoving:Connect(function(player)
	DataPersistenceService.saveData(player, true)
end)

for _, player in Players:GetPlayers() do
	task.spawn(DataPersistenceService.loadData, player)
end

-- Volcado periódico cada 180s con desfase aleatorio entre servidores (Sección 6.2)
task.spawn(function()
	local initialDesync = math.random(5, 25)
	task.wait(initialDesync)
	while true do
		task.wait(AUTOSAVE_INTERVAL_SEC)
		for _, player in Players:GetPlayers() do
			if player.Parent and activeSessions[player.UserId] then
				task.spawn(function()
					DataPersistenceService.saveData(player, false)
				end)
				task.wait(1.2)
			end
		end
	end
end)

-- Tick pasivo de economía del Refugio cada 60 segundos (1/24 de Día de Juego)
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			if player.Parent and activeSessions[player.UserId] then
				DataPersistenceService.processPassiveProductionTick(player)
			end
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			pcall(DataPersistenceService.saveData, player, true)
		end)
	end

	local start = os.clock()
	while activeSavingCount > 0 and (os.clock() - start) < 6 do
		task.wait(0.1)
	end
	print("[DataPersistence v4.0] BindToClose completado con Session Locks liberados.")
end)

return DataPersistenceService
