--!strict
--[[
	EventSchedulerService.luau
	Planificador de Eventos Procedurales de Tres Facciones (E-01 a E-16) (Sección 4.2):
	- Evalúa cada 90 a 180 segundos la amenaza y el estado de los campamentos para instanciar
	  hasta 3 eventos dinámicos simultáneos del catálogo de 16 eventos.
	- Orquesta el ciclo solar de 24 minutos (20m Día + 4m E-09 Noche de Caza).
	- Dispara automáticamente E-10 (Incursión al Refugio Propio en Z0) al liberar Z5.
	- Mantiene la dinámica de spawn infinito en las 2 Zonas Especiales (Oeste y Este).
--]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local ZombieCatalogs = require(sharedFolder:WaitForChild("ZombieCatalogs") :: any)

local DataPersistenceService = require(script.Parent:WaitForChild("DataPersistenceService") :: any)
local ThreatAndDistrictService = require(script.Parent:WaitForChild("ThreatAndDistrictService") :: any)
local AIService = require(script.Parent:WaitForChild("AIService") :: any)

local EventSchedulerService = {}
EventSchedulerService.__index = EventSchedulerService

local MAX_CONCURRENT_EVENTS = 3 -- Máximo 3 eventos dinámicos simultáneos (Sección 4.2)

export type ActiveEventInstance = {
	eventId: Types.ProceduralEventId,
	config: Types.ProceduralEventConfig,
	districtId: Types.DistrictId,
	startedAt: number,
	expiresAt: number,
	spawnedNpcIds: { string },
	resolved: boolean,
}

local activeEvents: { [string]: ActiveEventInstance } = {}
local activeEventCount = 0

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local eventAlertRemote = remotesFolder:FindFirstChild("ZA_EventAlert") :: RemoteEvent
if not eventAlertRemote then
	eventAlertRemote = Instance.new("RemoteEvent")
	eventAlertRemote.Name = "ZA_EventAlert"
	eventAlertRemote.Parent = remotesFolder
end

local function broadcastEventAlert(
	status: "STARTED" | "COMPLETED" | "FAILED",
	ev: ActiveEventInstance,
	message: string
)
	Workspace:SetAttribute("ZA_LastEventAlert", string.format("[%s] %s (%s): %s", ev.eventId, ev.config.name, ev.districtId, message))
	eventAlertRemote:FireAllClients({
		status = status,
		eventId = ev.eventId,
		name = ev.config.name,
		districtId = ev.districtId,
		durationSec = ev.config.durationSec,
		message = message,
	})
end

local function spawnSquadForEvent(evId: Types.ProceduralEventId, distId: Types.DistrictId): { string }
	local center = ZombieCatalogs.Districts[distId].centerPosition
	local spawnedIds: { string } = {}

	local function spawnAdd(unitId: string, offset: Vector3)
		local npc = AIService.spawnNPC(unitId, center + offset, distId)
		if npc then
			table.insert(spawnedIds, npc.instanceId)
		end
	end

	if evId == "E-01" then
		-- Choque de Patrullas (HvZ)
		spawnAdd("H-19", Vector3.new(-12, 0, -10))
		spawnAdd("H-20", Vector3.new(-8, 0, -10))
		spawnAdd("Z-01", Vector3.new(12, 0, 10))
		spawnAdd("Z-02", Vector3.new(16, 0, 10))
		spawnAdd("Z-03", Vector3.new(14, 0, 14))
	elseif evId == "E-02" then
		-- Supervivientes Acorralados (Especialistas H-02, H-03, H-04)
		spawnAdd("H-02", Vector3.new(0, 0, 0))
		spawnAdd("H-03", Vector3.new(3, 0, 0))
		spawnAdd("Z-02", Vector3.new(15, 0, 12))
		spawnAdd("Z-04", Vector3.new(-15, 0, 12))
		spawnAdd("M-01", Vector3.new(0, 0, -18))
	elseif evId == "E-03" then
		-- Operación de Limpieza
		spawnAdd("H-20", Vector3.new(-6, 0, 0))
		spawnAdd("H-29", Vector3.new(0, 0, 0))
		spawnAdd("Z-05", Vector3.new(18, 0, 15))
		spawnAdd("Z-22", Vector3.new(22, 0, 15))
	elseif evId == "E-04" then
		-- Guerra de Bandas (ZvM)
		spawnAdd("Z-01", Vector3.new(-15, 0, 0))
		spawnAdd("Z-08", Vector3.new(-18, 0, 4))
		spawnAdd("Z-36", Vector3.new(-12, 0, -4))
		spawnAdd("M-08", Vector3.new(15, 0, 0))
		spawnAdd("M-10", Vector3.new(18, 0, 4))
		spawnAdd("M-30", Vector3.new(12, 0, -4))
	elseif evId == "E-05" then
		-- Horda Errante (Amenaza > 70%)
		for i = 1, 6 do
			spawnAdd("Z-01", Vector3.new(i * 4 - 12, 0, 20))
		end
		spawnAdd("Z-07", Vector3.new(0, 0, 26))
	elseif evId == "E-06" then
		-- Caída de Suministros (3 Facciones convergen)
		spawnAdd("H-21", Vector3.new(-16, 0, -16))
		spawnAdd("M-09", Vector3.new(16, 0, -16))
		spawnAdd("Z-14", Vector3.new(0, 0, 18))
	elseif evId == "E-07" then
		-- Jefe Errante Desatado (Titán Z-59 o Colosales M-59)
		local bossUnit = if math.random() < 0.5 then "Z-59" else "M-59"
		spawnAdd(bossUnit, Vector3.new(0, 0, 15))
	elseif evId == "E-08" then
		-- Cierre de Cuarentena (Amenaza x2, Loot raro x2 por 10 min)
		local st = ThreatAndDistrictService.getDistrictState(distId)
		if st then
			st.quarantineLockedUntil = os.time() + 600
		end
		spawnAdd("Z-38", Vector3.new(-10, 0, 10))
		spawnAdd("M-21", Vector3.new(10, 0, 10))
	elseif evId == "E-10" then
		-- Incursión al Refugio Propio en Z0 (Al liberar Z5)
		spawnAdd("M-25", Vector3.new(-30, 0, -90))
		spawnAdd("M-03", Vector3.new(-24, 0, -90))
		spawnAdd("M-54", Vector3.new(25, 0, -90))
	elseif evId == "E-11" then
		-- Caravana del Mercader
		spawnAdd("H-08", Vector3.new(0, 0, -12))
		spawnAdd("H-11", Vector3.new(-4, 0, -10))
	elseif evId == "E-12" then
		-- Guerra de Tótems
		spawnAdd("M-12", Vector3.new(10, 0, 10))
		spawnAdd("M-39", Vector3.new(14, 0, 10))
		spawnAdd("Z-51", Vector3.new(-14, 0, 10))
	elseif evId == "E-13" then
		-- Asedio Mutante a Campamento Humano (Capitán M-25 + Saboteadores M-03 + Rompemuros M-54)
		spawnAdd("M-25", Vector3.new(28, 0, 28))
		spawnAdd("M-03", Vector3.new(24, 0, 28))
		spawnAdd("M-54", Vector3.new(32, 0, 28))
		spawnAdd("H-20", Vector3.new(-8, 0, -55))
	elseif evId == "E-14" then
		-- Asalto Humano a Bastión Mutante (Libera Inspector VIP H-07)
		spawnAdd("H-29", Vector3.new(-20, 0, -20))
		spawnAdd("H-20", Vector3.new(-16, 0, -20))
		spawnAdd("H-07", Vector3.new(20, 0, 20))
		spawnAdd("M-22", Vector3.new(16, 0, 18))
	elseif evId == "E-15" then
		-- Batalla Campal de Tres Bandas (HvZvM)
		spawnAdd("H-24", Vector3.new(-22, 0, -18))
		spawnAdd("M-23", Vector3.new(22, 0, -18))
		spawnAdd("Z-55", Vector3.new(0, 0, 22))
	end

	return spawnedIds
end

function EventSchedulerService.startEvent(
	eventId: Types.ProceduralEventId,
	targetDistrictId: Types.DistrictId?
): ActiveEventInstance?
	if activeEventCount >= MAX_CONCURRENT_EVENTS and eventId ~= "E-09" and eventId ~= "E-10" and eventId ~= "E-16" then
		return nil
	end

	local cfg = ZombieCatalogs.ProceduralEvents[eventId]
	if not cfg then
		return nil
	end

	local distId: Types.DistrictId = targetDistrictId or cfg.allowedZones[math.random(1, #cfg.allowedZones)]
	local key = eventId .. "_" .. distId
	if activeEvents[key] then
		return activeEvents[key]
	end

	local spawnedIds = spawnSquadForEvent(eventId, distId)
	local now = os.clock()
	local instance: ActiveEventInstance = {
		eventId = eventId,
		config = cfg,
		districtId = distId,
		startedAt = now,
		expiresAt = now + cfg.durationSec,
		spawnedNpcIds = spawnedIds,
		resolved = false,
	}

	activeEvents[key] = instance
	activeEventCount += 1
	broadcastEventAlert("STARTED", instance, cfg.rewardSummary)

	task.delay(cfg.durationSec, function()
		EventSchedulerService.resolveEvent(key)
	end)

	return instance
end

function EventSchedulerService.resolveEvent(eventKey: string)
	local ev = activeEvents[eventKey]
	if not ev or ev.resolved then
		return
	end
	ev.resolved = true
	activeEvents[eventKey] = nil
	activeEventCount = math.max(0, activeEventCount - 1)

	-- Verificar si sobrevivieron enemigos hostiles del evento
	local hostilesAlive = 0
	local humansAlive = 0
	for _, npcId in ipairs(ev.spawnedNpcIds) do
		local npc = AIService.getActiveNPC(npcId)
		if npc and npc.hp > 0 then
			if npc.faction == "Human" then
				humansAlive += 1
			else
				hostilesAlive += 1
			end
		end
	end

	if hostilesAlive == 0 or humansAlive > hostilesAlive then
		-- Éxito del evento para la facción humana / jugador
		if ev.eventId == "E-03" then
			ThreatAndDistrictService.modifyThreat(ev.districtId, -50, "CleanupEscortSuccess")
		elseif ev.eventId == "E-05" then
			ThreatAndDistrictService.modifyThreat(ev.districtId, -40, "WanderingHordeAmbush")
		elseif ev.eventId == "E-02" or ev.eventId == "E-14" then
			local specialistReward = if ev.eventId == "E-14" then "H-07" else "H-02"
			for _, plr in Players:GetPlayers() do
				DataPersistenceService.stageRescuedSpecialist(plr, specialistReward)
			end
		elseif ev.eventId == "E-10" then
			-- Defender el Refugio Propio en Z0 otorga +1 mejora permanente gratuita
			for _, plr in Players:GetPlayers() do
				local data = DataPersistenceService.getData(plr)
				if data then
					local curLv = data.weaponLevels["G-05"] or 1
					data.weaponLevels["G-05"] = math.min(10, curLv + 1)
					DataPersistenceService.syncLeaderstats(plr, data)
				end
			end
		end
		broadcastEventAlert("COMPLETED", ev, "Objetivo táctico asegurado")
	else
		-- Penalización por no intervención o fallo (Sección 4.2)
		if ev.config.failurePenaltyThreat > 0 then
			ThreatAndDistrictService.modifyThreat(ev.districtId, ev.config.failurePenaltyThreat, "EventFailed_" .. ev.eventId)
		end
		if ev.eventId == "E-10" then
			-- Si caen las defensas en E-10 se pierde el 10% de los materiales del lobby
			for _, plr in Players:GetPlayers() do
				local data = DataPersistenceService.getData(plr)
				if data then
					data.scrap = math.floor(data.scrap * 0.90)
					data.components = math.floor(data.components * 0.90)
					DataPersistenceService.syncLeaderstats(plr, data)
				end
			end
		end
		broadcastEventAlert("FAILED", ev, "Sector comprometido; amenaza incrementada")
	end
end

function EventSchedulerService.getActiveEvents(): { [string]: ActiveEventInstance }
	return activeEvents
end

-- Disparar E-10 (Incursión al Refugio Propio en Z0) automáticamente al liberar Z5 (Sección 4.2)
ThreatAndDistrictService.onDistrictLiberated(function(distId: Types.DistrictId)
	if distId == "Z5" then
		EventSchedulerService.startEvent("E-10", "Z0")
	end
end)

-- Población inicial de guarniciones, patrullas y Crisoles ZvM al arrancar el servidor
function EventSchedulerService.seedInitialEcosystem()
	-- Guardias del Refugio Z0
	local z0Center = ZombieCatalogs.Districts.Z0.centerPosition
	AIService.spawnNPC("H-20", z0Center + Vector3.new(-18, 0, -20), "Z0")
	AIService.spawnNPC("H-20", z0Center + Vector3.new(18, 0, -20), "Z0")
	AIService.spawnNPC("H-04", z0Center + Vector3.new(0, 0, -12), "Z0")

	-- Patrullas y nidos iniciales en Z1..Z4
	AIService.spawnNPC("Z-01", ZombieCatalogs.Districts.Z1.centerPosition + Vector3.new(15, 0, 15), "Z1")
	AIService.spawnNPC("Z-02", ZombieCatalogs.Districts.Z1.centerPosition + Vector3.new(-15, 0, 15), "Z1")
	AIService.spawnNPC("H-09", ZombieCatalogs.Districts.Z1.centerPosition + Vector3.new(0, 0, -45), "Z1")

	AIService.spawnNPC("Z-22", ZombieCatalogs.Districts.Z2.centerPosition + Vector3.new(12, 0, 12), "Z2")
	AIService.spawnNPC("Z-10", ZombieCatalogs.Districts.Z3.centerPosition + Vector3.new(-12, 0, 12), "Z3")
	AIService.spawnNPC("M-10", ZombieCatalogs.Districts.Z4.centerPosition + Vector3.new(14, 0, -14), "Z4")

	-- Choque perpetuo en los 2 Crisoles de Guerra Infinita (Oeste y Este)
	local westCenter = ZombieCatalogs.Districts.Special_West.centerPosition
	AIService.spawnNPC("Z-51", westCenter + Vector3.new(-16, 0, 0), "Special_West")
	AIService.spawnNPC("M-30", westCenter + Vector3.new(16, 0, 0), "Special_West")

	local eastCenter = ZombieCatalogs.Districts.Special_East.centerPosition
	AIService.spawnNPC("M-51", eastCenter + Vector3.new(16, 0, 0), "Special_East")
	AIService.spawnNPC("Z-36", eastCenter + Vector3.new(-16, 0, 0), "Special_East")

	-- Lanzar primer evento táctico en Z1
	EventSchedulerService.startEvent("E-01", "Z1")
end

-- Bucle principal del EventSchedulerService (cada 90 a 180 segundos evalúa amenaza y campamentos)
task.spawn(function()
	while true do
		local waitSec = math.random(90, 180)
		task.wait(waitSec)

		if activeEventCount < MAX_CONCURRENT_EVENTS then
			local states = ThreatAndDistrictService.getAllDistrictStates()
			local candidateEvents: { Types.ProceduralEventId } = {
				"E-01",
				"E-02",
				"E-03",
				"E-04",
				"E-06",
				"E-08",
				"E-11",
				"E-12",
				"E-13",
				"E-14",
				"E-15",
			}

			-- Verificar triggers por umbral de amenaza (>70% E-05, >90% E-07)
			for distId, st in pairs(states) do
				if not st.liberated and st.maxThreat > 0 then
					local ratio = st.threatLevel / st.maxThreat
					if ratio >= 0.90 then
						EventSchedulerService.startEvent("E-07", distId)
						break
					elseif ratio >= 0.70 then
						EventSchedulerService.startEvent("E-05", distId)
						break
					end
				end
			end

			if activeEventCount < MAX_CONCURRENT_EVENTS then
				local pick = candidateEvents[math.random(1, #candidateEvents)]
				EventSchedulerService.startEvent(pick, nil)
			end
		end
	end
end)

-- Ciclo Solar de 24 Minutos (20 min Día + 4 min E-09 Noche de Caza)
task.spawn(function()
	while true do
		-- Fase Diurna (20 minutos)
		ThreatAndDistrictService.setNightHuntActive(false)
		pcall(function()
			Lighting.ClockTime = 14.0
			Lighting.Brightness = 2.2
		end)
		task.wait(20 * 60)

		-- Fase Nocturna: Evento Global E-09 Noche de Caza (4 minutos)
		ThreatAndDistrictService.setNightHuntActive(true)
		pcall(function()
			Lighting.ClockTime = 1.5
			Lighting.Brightness = 0.8
		end)
		EventSchedulerService.startEvent("E-09", "Z3")
		task.wait(4 * 60)
	end
end)

return EventSchedulerService
