--!strict
--[[
	AIService.luau
	Motor de IA Masiva de Tres Facciones, Percepción por Lotes, Cola de Pathfinding,
	Steering Behaviors, Object Pooling de 180 NPCs y Regla de Exclusión Mutua (ServerBossMutex)
	para Zombie Awareness (v4.0) (Secciones 2.2, 3 y 6.1).
--]]

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local ZombieCatalogs = require(sharedFolder:WaitForChild("ZombieCatalogs") :: any)
local Janitor = require(sharedFolder:WaitForChild("Janitor") :: any)
local WorldAssembler = require(sharedFolder:WaitForChild("WorldAssembler") :: any)

local ThreatAndDistrictService = require(script.Parent:WaitForChild("ThreatAndDistrictService") :: any)

local AIService = {}
AIService.__index = AIService

-- Presupuestos Técnicos (Sección 6.1)
local MAX_NPCS_NORMAL = 180 -- 120 base + 60 eventos/Zonas Especiales
local MAX_NPCS_THROTTLED = 120 -- Contracción automática si Heartbeat < 30 Hz
local PERCEPTION_BATCH_NORMAL = 20 -- 20 NPCs/fotograma (ciclo rotativo de 5 frames = 83 ms)
local PERCEPTION_BATCH_THROTTLED = 10
local MAX_CONCURRENT_PATHFINDING = 4 -- Máximo 4 ComputeAsync simultáneos
local SWARM_STEERING_THRESHOLD = 6 -- 6+ zombies Z-01..Z-20 activan Steering Behaviors
local MAX_ALLIED_SWARM_SERVER = 24 -- Tope global de zombies hipnotizados por G-20
local CRUCIBLE_SUMMON_THRESHOLD = 1000 -- 1.000 puntos de Muerte de Facción

export type AIState = "IDLE" | "PERCEIVE" | "CHASE" | "ATTACK" | "COVER" | "FLANK" | "RETREAT" | "ESCORT" | "HYPNOTIZED"

export type ActiveNPC = {
	instanceId: string,
	unitId: string,
	definition: Types.UnitDefinition,
	faction: Types.FactionId,
	districtId: Types.DistrictId,
	model: Model,
	rootPart: BasePart,
	humanoid: Humanoid?,
	hp: number,
	maxHp: number,
	speed: number,
	state: AIState,
	targetEntityId: string?,
	targetPosition: Vector3?,
	ownerUserId: number?,
	hypnotizedExpiresAt: number?,
	legsCrippled: boolean,
	berserkActive: boolean,
	markedMultiplier: number,
	lastAttackClock: number,
	lastSpecialClock: number,
	waypoints: { Vector3 },
	waypointIndex: number,
	janitor: any,
}

type PathRequest = {
	npcId: string,
	priority: Types.PathfindingPriority,
	fromPos: Vector3,
	toPos: Vector3,
	enqueuedAt: number,
}

-- Contenedores de Pool y Entidades Activas
local poolStorageFolder = ServerStorage:FindFirstChild("ZA_ObjectPools") :: Folder
if not poolStorageFolder then
	poolStorageFolder = Instance.new("Folder")
	poolStorageFolder.Name = "ZA_ObjectPools"
	poolStorageFolder.Parent = ServerStorage
end

local activeNPCsFolder = Workspace:FindFirstChild("ZA_ActiveNPCs") :: Folder
if not activeNPCsFolder then
	activeNPCsFolder = Instance.new("Folder")
	activeNPCsFolder.Name = "ZA_ActiveNPCs"
	activeNPCsFolder.Parent = Workspace
end

local objectPools: { [Types.PoolCategory]: { Model } } = {
	Pool_Human = {},
	Pool_Mutant_Green = {},
	Pool_Mutant_Anthro = {},
	Pool_Zombie_Base = {},
	Pool_Brute = {},
}

local activeNPCs: { [string]: ActiveNPC } = {}
local activeNPCList: { ActiveNPC } = {}
local alliedSwarmCount = 0
local npcSerialCounter = 0

-- Estado del Gobernador de Rendimiento y Percepción por Lotes
local currentServerHz = 60
local isPerformanceThrottled = false
local perceptionCursor = 1

-- Cola Priorizada de Pathfinding y Caché Espacial
local pathQueue: { PathRequest } = {}
local activeComputeAsyncCount = 0
local spatialRouteCache: { [string]: { waypoints: { Vector3 }, timestamp: number } } = {}

-- Estado de los Crisoles de Guerra Infinita y Exclusión Mutua (ServerBossMutex)
local crucibleState: Types.CrucibleRuntimeState = {
	westDeathPoints = 0,
	eastDeathPoints = 0,
	totemsRemainingEast = 3,
	serverBossMutex = false,
	activeMegaBossId = nil,
	activeMegaBossHp = 0,
	activeMegaBossMaxHp = 0,
	bossSpawnedAt = nil,
}

-- UnreliableRemoteEvent para replicar estados de NPCs en paquetes de 10 unidades (<50 KB/s)
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local npcBatchSyncRemote = remotesFolder:FindFirstChild("ZA_NPCBatchSync") :: UnreliableRemoteEvent
if not npcBatchSyncRemote then
	npcBatchSyncRemote = Instance.new("UnreliableRemoteEvent")
	npcBatchSyncRemote.Name = "ZA_NPCBatchSync"
	npcBatchSyncRemote.Parent = remotesFolder
end

local function syncCrucibleAttributes()
	Workspace:SetAttribute("ZA_WestCruciblePoints", crucibleState.westDeathPoints)
	Workspace:SetAttribute("ZA_EastCruciblePoints", crucibleState.eastDeathPoints)
	Workspace:SetAttribute("ZA_ServerBossMutex", crucibleState.serverBossMutex)
	Workspace:SetAttribute("ZA_ActiveMegaBossId", crucibleState.activeMegaBossId or "")
	Workspace:SetAttribute("ZA_ActiveMegaBossHp", crucibleState.activeMegaBossHp)
	Workspace:SetAttribute("ZA_ActiveMegaBossMaxHp", crucibleState.activeMegaBossMaxHp)
end

syncCrucibleAttributes()

--------------------------------------------------------------------------------
-- 1. CONSTRUCCIÓN Y RECICLAJE DE MODELOS EN OBJECT POOL (CERO :Destroy())
--------------------------------------------------------------------------------

local function buildPooledRigModel(poolCategory: Types.PoolCategory): Model
	local model = Instance.new("Model")
	model.Name = "Pooled_" .. poolCategory

	local isBrute = poolCategory == "Pool_Brute"
	local torsoSize = if isBrute then Vector3.new(4.5, 5.0, 3.0) else Vector3.new(2.0, 2.5, 1.2)
	local headSize = if isBrute then Vector3.new(2.4, 2.4, 2.4) else Vector3.new(1.4, 1.4, 1.4)

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = torsoSize
	rootPart.Anchored = true
	rootPart.CanCollide = true
	rootPart.TopSurface = Enum.SurfaceType.Smooth
	rootPart.BottomSurface = Enum.SurfaceType.Smooth
	rootPart.Material = Enum.Material.SmoothPlastic
	rootPart.Parent = model
	model.PrimaryPart = rootPart

	-- Attachments estandarizados RAASE 3.0 / Sección 5.1
	local auraAttachment = Instance.new("Attachment")
	auraAttachment.Name = "AuraCenterAttachment"
	auraAttachment.Parent = rootPart

	local muzzleAttachment = Instance.new("Attachment")
	muzzleAttachment.Name = "MuzzleAttachment"
	muzzleAttachment.Position = Vector3.new(0, 0.5, -torsoSize.Z / 2 - 0.8)
	muzzleAttachment.Parent = rootPart

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = headSize
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.SmoothPlastic
	head.CFrame = rootPart.CFrame * CFrame.new(0, torsoSize.Y / 2 + headSize.Y / 2, 0)
	head.Parent = model

	-- Puntos débiles para Jefes y Acorazados (RIG-05 / RIG-06)
	local weakSpot = Instance.new("Part")
	weakSpot.Name = "WeakPoint_Chest"
	weakSpot.Size = Vector3.new(1.2, 1.2, 0.4)
	weakSpot.Anchored = true
	weakSpot.CanCollide = false
	weakSpot.Material = Enum.Material.Neon
	weakSpot.Transparency = 0.25
	weakSpot.CFrame = rootPart.CFrame * CFrame.new(0, 0.2, -torsoSize.Z / 2 - 0.05)
	weakSpot.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.EvaluateStateMachine = false
	humanoid.Parent = model

	return model
end

local function acquireModelFromPool(def: Types.UnitDefinition): Model
	local pool = objectPools[def.poolCategory]
	local model: Model
	if pool and #pool > 0 then
		model = table.remove(pool) :: Model
	else
		model = buildPooledRigModel(def.poolCategory)
	end

	model.Name = def.id .. "_" .. def.name
	local rootPart = model.PrimaryPart :: BasePart
	local scaleRatio = def.heightStuds / 5.5
	rootPart.Size = Vector3.new(2.0 * math.min(2.8, scaleRatio), def.heightStuds * 0.55, 1.2 * math.min(2.5, scaleRatio))
	rootPart.Color = def.primaryColor

	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		local hDim = math.clamp(1.3 * math.sqrt(scaleRatio), 1.2, 4.2)
		head.Size = Vector3.new(hDim, hDim, hDim)
		head.Color = def.primaryColor
	end

	local weak = model:FindFirstChild("WeakPoint_Chest") :: BasePart?
	if weak then
		weak.Color = def.accentColor
		weak.Transparency = if def.subFaction == "Zombie_Brute"
				or def.subFaction == "Mutant_Brute"
				or def.subFaction == "Zombie_MegaBoss"
				or def.subFaction == "Mutant_MegaBoss"
			then 0.05
			else 0.6
	end

	return model
end

local function releaseModelToPool(npc: ActiveNPC)
	npc.janitor:Cleanup()
	local model = npc.model
	model.Parent = poolStorageFolder
	if model.PrimaryPart then
		model.PrimaryPart.CFrame = CFrame.new(0, -500, 0)
	end
	local pool = objectPools[npc.definition.poolCategory]
	if pool then
		table.insert(pool, model)
	end
end

--------------------------------------------------------------------------------
-- 2. SPAWN, RECICLAJE Y GOBERNADOR DE PRESUPUESTO (180 / 120 UNIDADES)
--------------------------------------------------------------------------------

function AIService.getMaxNPCBudget(): number
	return if isPerformanceThrottled then MAX_NPCS_THROTTLED else MAX_NPCS_NORMAL
end

function AIService.getActiveNPCCount(): number
	return #activeNPCList
end

function AIService.spawnNPC(
	unitId: string,
	position: Vector3,
	districtId: Types.DistrictId?,
	ownerUserId: number?
): ActiveNPC?
	local def = ZombieCatalogs.Units[unitId]
	if not def then
		warn("[AIService] UnitId desconocido: " .. tostring(unitId))
		return nil
	end

	-- Regla de Exclusión Mutua (ServerBossMutex) para Mega Brutos Líderes
	if unitId == "Z-BOSS-01" or unitId == "M-BOSS-01" then
		if crucibleState.serverBossMutex and crucibleState.activeMegaBossId ~= nil then
			return nil
		end
	end

	-- Verificar presupuesto de 180 / 120 NPCs (los Mega Brutos siempre tienen reserva prioritaria)
	if #activeNPCList >= AIService.getMaxNPCBudget() and def.pathPriority > 1 then
		return nil
	end

	npcSerialCounter += 1
	local instanceId = string.format("NPC_%s_%d", unitId, npcSerialCounter)
	local resolvedDistrict: Types.DistrictId = districtId or ThreatAndDistrictService.getDistrictAtPosition(position)

	local model = acquireModelFromPool(def)
	model:SetAttribute("ZA_InstanceId", instanceId)
	model:SetAttribute("ZA_UnitId", unitId)
	model:SetAttribute("ZA_Faction", def.faction)
	model:SetAttribute("ZA_DistrictId", resolvedDistrict)
	model:SetAttribute("ZA_HP", def.hp)
	model:SetAttribute("ZA_MaxHP", def.hp)
	CollectionService:AddTag(model, "ZA_ActiveNPC")

	model.Parent = activeNPCsFolder
	WorldAssembler.PlaceGrounded(model, position, {
		GridSnap = 1,
		AlignToSlope = false,
	})

	local rootPart = model.PrimaryPart :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		head.CFrame = rootPart.CFrame * CFrame.new(0, rootPart.Size.Y / 2 + head.Size.Y / 2, 0)
	end
	local weak = model:FindFirstChild("WeakPoint_Chest") :: BasePart?
	if weak then
		weak.CFrame = rootPart.CFrame * CFrame.new(0, 0.2, -rootPart.Size.Z / 2 - 0.05)
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = def.hp
		hum.Health = def.hp
	end

	local npcJanitor = Janitor.new()
	local initialState: AIState = if ownerUserId ~= nil then "ESCORT" else "PERCEIVE"

	local npc: ActiveNPC = {
		instanceId = instanceId,
		unitId = unitId,
		definition = def,
		faction = def.faction,
		districtId = resolvedDistrict,
		model = model,
		rootPart = rootPart,
		humanoid = hum,
		hp = def.hp,
		maxHp = def.hp,
		speed = def.speed,
		state = initialState,
		targetEntityId = nil,
		targetPosition = nil,
		ownerUserId = ownerUserId,
		hypnotizedExpiresAt = nil,
		legsCrippled = false,
		berserkActive = false,
		markedMultiplier = 1.0,
		lastAttackClock = 0,
		lastSpecialClock = os.clock(),
		waypoints = {},
		waypointIndex = 1,
		janitor = npcJanitor,
	}

	activeNPCs[instanceId] = npc
	table.insert(activeNPCList, npc)

	if unitId == "Z-BOSS-01" or unitId == "M-BOSS-01" then
		crucibleState.serverBossMutex = true
		crucibleState.activeMegaBossId = unitId :: any
		crucibleState.activeMegaBossHp = def.hp
		crucibleState.activeMegaBossMaxHp = def.hp
		crucibleState.bossSpawnedAt = os.clock()
		syncCrucibleAttributes()
	end

	return npc
end

function AIService.despawnOrRecycleNPC(instanceId: string, killerFaction: Types.FactionId?)
	local npc = activeNPCs[instanceId]
	if not npc then
		return
	end

	activeNPCs[instanceId] = nil
	for i = #activeNPCList, 1, -1 do
		if activeNPCList[i].instanceId == instanceId then
			table.remove(activeNPCList, i)
			break
		end
	end

	if npc.state == "HYPNOTIZED" then
		alliedSwarmCount = math.max(0, alliedSwarmCount - 1)
	end

	local deathPos = npc.rootPart.Position
	local unitId = npc.unitId
	local distId = npc.districtId

	-- Si era un Mega Bruto Líder, liberar ServerBossMutex
	if unitId == "Z-BOSS-01" or unitId == "M-BOSS-01" then
		crucibleState.serverBossMutex = false
		crucibleState.activeMegaBossId = nil
		crucibleState.activeMegaBossHp = 0
		if unitId == "Z-BOSS-01" then
			crucibleState.westDeathPoints = 0
		else
			crucibleState.eastDeathPoints = 0
		end
		syncCrucibleAttributes()
	end

	-- Mecánica Z-20 Amalgama de Carne: al morir se divide en 2 Reptantes (Z-15) independientes
	if unitId == "Z-20" then
		AIService.spawnNPC("Z-15", deathPos + Vector3.new(-2.5, 0, 0), distId)
		AIService.spawnNPC("Z-15", deathPos + Vector3.new(2.5, 0, 0), distId)
	end

	-- Actualizar amenaza o contadores de los Crisoles de Masacre ZvM
	if distId == "Special_West" or distId == "Special_East" then
		AIService.addCrucibleDeathPoints(distId, npc.definition.crucibleWeight)
	elseif npc.faction ~= "Human" and killerFaction == "Human" then
		local threatReduction = if npc.definition.poolCategory == "Pool_Brute" then -15 else -3
		ThreatAndDistrictService.modifyThreat(distId, threatReduction, "EnemyEliminated")
	end

	releaseModelToPool(npc)
end

--------------------------------------------------------------------------------
-- 3. CRISOLES DE GUERRA INFINITA Y REGLA SERVERBOSSMUTEX (SECCIÓN 2.2)
--------------------------------------------------------------------------------

function AIService.addCrucibleDeathPoints(zoneId: Types.DistrictId, points: number)
	if points <= 0 then
		return
	end

	local capWhenLocked = math.floor(CRUCIBLE_SUMMON_THRESHOLD * 0.99) -- 990 pts (99%) bajo bloqueo Mutex

	if zoneId == "Special_West" then
		if crucibleState.serverBossMutex then
			if crucibleState.activeMegaBossId == "M-BOSS-01" then
				crucibleState.westDeathPoints = math.min(capWhenLocked, crucibleState.westDeathPoints + points)
			end
		else
			crucibleState.westDeathPoints = math.min(CRUCIBLE_SUMMON_THRESHOLD, crucibleState.westDeathPoints + points)
			if crucibleState.westDeathPoints >= CRUCIBLE_SUMMON_THRESHOLD then
				local center = ZombieCatalogs.Districts.Special_West.centerPosition
				AIService.spawnNPC("Z-BOSS-01", center + Vector3.new(0, 4, 0), "Special_West")
			end
		end
	elseif zoneId == "Special_East" then
		if crucibleState.serverBossMutex then
			if crucibleState.activeMegaBossId == "Z-BOSS-01" then
				crucibleState.eastDeathPoints = math.min(capWhenLocked, crucibleState.eastDeathPoints + points)
			end
		else
			crucibleState.eastDeathPoints = math.min(CRUCIBLE_SUMMON_THRESHOLD, crucibleState.eastDeathPoints + points)
			if crucibleState.eastDeathPoints >= CRUCIBLE_SUMMON_THRESHOLD then
				local center = ZombieCatalogs.Districts.Special_East.centerPosition
				AIService.spawnNPC("M-BOSS-01", center + Vector3.new(0, 4, 0), "Special_East")
			end
		end
	end

	syncCrucibleAttributes()
end

function AIService.notifyEastWarTotemDestroyed()
	crucibleState.totemsRemainingEast = math.max(0, crucibleState.totemsRemainingEast - 1)
	if crucibleState.totemsRemainingEast == 0 then
		AIService.addCrucibleDeathPoints("Special_East", CRUCIBLE_SUMMON_THRESHOLD)
	end
end

function AIService.getCrucibleState(): Types.CrucibleRuntimeState
	return crucibleState
end

--------------------------------------------------------------------------------
-- 4. CONTROL MENTAL E INFECCIÓN (EMISOR G-20 Y DOMADORA)
--------------------------------------------------------------------------------

function AIService.hypnotizeNPC(npcId: string, player: Player, durationSec: number?): (boolean, string)
	local npc = activeNPCs[npcId]
	if not npc then
		return false, "Objetivo no encontrado"
	end

	if not npc.definition.hypnotizable then
		return false, "Los Hulks (Z-H/M-H), Mutantes Verdes y Mega Brutos poseen inmunidad contractual al G-20"
	end

	if alliedSwarmCount >= MAX_ALLIED_SWARM_SERVER then
		return false, "Sub-pool AlliedSwarm lleno en el servidor"
	end

	npc.faction = "Human"
	npc.state = "HYPNOTIZED"
	npc.ownerUserId = player.UserId
	npc.hypnotizedExpiresAt = if durationSec then os.clock() + durationSec else nil
	npc.rootPart.Color = Color3.fromRGB(0, 255, 220)
	npc.model:SetAttribute("ZA_Faction", "Human")
	npc.model:SetAttribute("ZA_HypnotizedBy", player.UserId)
	alliedSwarmCount += 1

	return true, "Unidad hipnotizada por el Emisor de Conciencia (G-20)"
end

--------------------------------------------------------------------------------
-- 5. COLA PRIORIZADA DE PATHFINDING (MÁX. 4 COMPUTEASYNC) Y CACHÉ ESPACIAL
--------------------------------------------------------------------------------

local function cellKey(pos: Vector3): string
	return string.format("%d_%d", math.floor(pos.X / 48), math.floor(pos.Z / 48))
end

function AIService.invalidatePathCacheNearPosition(pos: Vector3)
	local keyPrefix = cellKey(pos)
	for routeKey in pairs(spatialRouteCache) do
		if string.find(routeKey, keyPrefix, 1, true) then
			spatialRouteCache[routeKey] = nil
		end
	end
end

function AIService.enqueuePathRequest(npc: ActiveNPC, targetPos: Vector3)
	local routeKey = cellKey(npc.rootPart.Position) .. "->" .. cellKey(targetPos)
	local cached = spatialRouteCache[routeKey]
	if cached and (os.clock() - cached.timestamp) < 30 then
		npc.waypoints = cached.waypoints
		npc.waypointIndex = 1
		return
	end

	-- Evitar duplicados en la cola para el mismo NPC
	for _, req in ipairs(pathQueue) do
		if req.npcId == npc.instanceId then
			req.toPos = targetPos
			return
		end
	end

	table.insert(pathQueue, {
		npcId = npc.instanceId,
		priority = npc.definition.pathPriority,
		fromPos = npc.rootPart.Position,
		toPos = targetPos,
		enqueuedAt = os.clock(),
	})

	-- Ordenar estrictamente por jerarquía táctica: MegaBrutes (1) > Hulks (2) > Mutants (3) > Humans (4) > Zombies (5)
	table.sort(pathQueue, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return a.enqueuedAt < b.enqueuedAt
	end)
end

local function processPathfindingQueue()
	while activeComputeAsyncCount < MAX_CONCURRENT_PATHFINDING and #pathQueue > 0 do
		local req = table.remove(pathQueue, 1) :: PathRequest
		local npc = activeNPCs[req.npcId]
		if npc and npc.model.Parent then
			activeComputeAsyncCount += 1
			task.spawn(function()
				local ok, waypointsResult = pcall(function()
					local path = PathfindingService:CreatePath({
						AgentRadius = if npc.definition.poolCategory == "Pool_Brute" then 4 else 2,
						AgentHeight = npc.definition.heightStuds,
						AgentCanJump = true,
					})
					path:ComputeAsync(req.fromPos, req.toPos)
					if path.Status == Enum.PathStatus.Success then
						local pts = {}
						for _, wp in ipairs(path:GetWaypoints()) do
							table.insert(pts, wp.Position)
						end
						return pts
					end
					return { req.toPos }
				end)
				activeComputeAsyncCount = math.max(0, activeComputeAsyncCount - 1)

				if ok and waypointsResult and activeNPCs[req.npcId] then
					npc.waypoints = waypointsResult
					npc.waypointIndex = 1
					local routeKey = cellKey(req.fromPos) .. "->" .. cellKey(req.toPos)
					spatialRouteCache[routeKey] = {
						waypoints = waypointsResult,
						timestamp = os.clock(),
					}
				end
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- 6. PERCEPCIÓN POR LOTES (20 NPCS/FRAME) Y STEERING BEHAVIORS
--------------------------------------------------------------------------------

local function evaluateNPCPerception(npc: ActiveNPC)
	local myPos = npc.rootPart.Position
	local lookVec = npc.rootPart.CFrame.LookVector
	local nightMult = if ThreatAndDistrictService.isNightHuntActive() then 1.25 else 1.0
	local maxVisionDist = 75 * nightMult
	local audioDist = 60 * nightMult

	-- Cono de visión: 120° (cos 60° = 0.5) para zombies, 90° (cos 45° = 0.707) para mutantes y humanos
	local minDot = if npc.faction == "Zombie" then 0.5 else 0.7071

	-- Si es aliado/hipnotizado con dueño, seguir al dueño si no hay enemigos cerca
	local bestTargetPos: Vector3? = nil
	local bestTargetId: string? = nil
	local bestDist = math.huge

	-- Buscar jugadores hostiles (si el NPC no es Human)
	if npc.faction ~= "Human" then
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local pRoot = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			local pHum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			if pRoot and pHum and pHum.Health > 0 then
				local toTarget = pRoot.Position - myPos
				local dist = toTarget.Magnitude
				if dist <= maxVisionDist then
					local dir = if dist > 0.01 then toTarget.Unit else lookVec
					if lookVec:Dot(dir) >= minDot or dist <= audioDist * 0.45 then
						if dist < bestDist then
							bestDist = dist
							bestTargetPos = pRoot.Position
							bestTargetId = "Player_" .. tostring(player.UserId)
						end
					end
				end
			end
		end
	end

	-- Buscar NPCs de facciones enemigas (Guerra de Tres Bandas HvZvM)
	for _, other in ipairs(activeNPCList) do
		if other.instanceId ~= npc.instanceId and other.faction ~= npc.faction and other.hp > 0 then
			local toOther = other.rootPart.Position - myPos
			local dist = toOther.Magnitude
			if dist <= maxVisionDist and dist < bestDist then
				bestDist = dist
				bestTargetPos = other.rootPart.Position
				bestTargetId = other.instanceId
			end
		end
	end

	if bestTargetPos then
		npc.targetPosition = bestTargetPos
		npc.targetEntityId = bestTargetId
		if npc.faction == "Mutant" and npc.definition.subFaction == "Mutant_Green" and (npc.hp / npc.maxHp) <= 0.25 then
			npc.state = "RETREAT"
		elseif bestDist <= npc.definition.rangeStuds then
			npc.state = "ATTACK"
		else
			npc.state = "CHASE"
		end
	elseif npc.ownerUserId then
		local ownerPlayer = Players:GetPlayerByUserId(npc.ownerUserId)
		local ownerChar = if ownerPlayer then ownerPlayer.Character else nil
		local ownerRoot = if ownerChar then ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if ownerRoot then
			npc.targetPosition = ownerRoot.Position + Vector3.new(4, 0, 4)
			npc.state = "ESCORT"
		end
	else
		npc.state = "PERCEIVE"
	end

	-- Habilidad especial Z-07 Gritón Invocador: cada 12s invoca 4 zombies del pool
	if npc.unitId == "Z-07" and (os.clock() - npc.lastSpecialClock) >= 12 then
		npc.lastSpecialClock = os.clock()
		for i = 1, 4 do
			local angle = i * (math.pi / 2)
			AIService.spawnNPC("Z-01", myPos + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6), npc.districtId)
		end
	end
end

--[[
	Calcula el vector de Steering Behavior (Seek + Separation + Obstacle Avoidance)
	cuando 6 o más zombies avanzan juntos o en persecución directa.
--]]
local function computeSteeringDirection(npc: ActiveNPC, goalPos: Vector3): Vector3
	local myPos = npc.rootPart.Position
	local toGoal = Vector3.new(goalPos.X - myPos.X, 0, goalPos.Z - myPos.Z)
	local seekVec = if toGoal.Magnitude > 0.1 then toGoal.Unit else Vector3.zero

	local separationVec = Vector3.zero
	local nearbyZombieCount = 0

	for _, other in ipairs(activeNPCList) do
		if other.instanceId ~= npc.instanceId then
			local delta = Vector3.new(myPos.X - other.rootPart.Position.X, 0, myPos.Z - other.rootPart.Position.Z)
			local d = delta.Magnitude
			if d > 0.01 and d < 5.5 then
				separationVec += (delta.Unit / d) * 2.2
				if other.faction == "Zombie" then
					nearbyZombieCount += 1
				end
			end
		end
	end

	-- Si hay menos de 6 zombies y tiene waypoints de Pathfinding calculados, usar el siguiente waypoint
	if nearbyZombieCount < SWARM_STEERING_THRESHOLD and #npc.waypoints > 0 and npc.waypointIndex <= #npc.waypoints then
		local wp = npc.waypoints[npc.waypointIndex]
		local toWp = Vector3.new(wp.X - myPos.X, 0, wp.Z - myPos.Z)
		if toWp.Magnitude < 3.0 then
			npc.waypointIndex += 1
		else
			seekVec = toWp.Unit
		end
	elseif (os.clock() - npc.lastSpecialClock) > 3.5 then
		npc.lastSpecialClock = os.clock()
		AIService.enqueuePathRequest(npc, goalPos)
	end

	local combined = seekVec + separationVec
	if npc.state == "RETREAT" then
		combined = -seekVec + separationVec
	end
	return if combined.Magnitude > 0.01 then combined.Unit else Vector3.new(0, 0, -1)
end

local function stepActiveNPCMovementAndCombat(dt: number)
	local now = os.clock()
	local nightDamageMult = if ThreatAndDistrictService.isNightHuntActive() then 1.25 else 1.0

	for i = #activeNPCList, 1, -1 do
		local npc = activeNPCList[i]
		if not npc or not npc.model.Parent then
			continue
		end

		-- Expiración de hipnosis G-20 temporal
		if npc.state == "HYPNOTIZED" and npc.hypnotizedExpiresAt and now >= npc.hypnotizedExpiresAt then
			AIService.despawnOrRecycleNPC(npc.instanceId, "Human")
			continue
		end

		-- Mecánica M-30 Hombre-Lobo Mutante: regenera pasivamente 5 HP/s
		if npc.unitId == "M-30" and npc.hp > 0 and npc.hp < npc.maxHp then
			npc.hp = math.min(npc.maxHp, npc.hp + 5 * dt)
			npc.model:SetAttribute("ZA_HP", math.floor(npc.hp))
		end

		local targetPos = npc.targetPosition
		if targetPos and (npc.state == "CHASE" or npc.state == "RETREAT" or npc.state == "ESCORT") then
			local moveDir = computeSteeringDirection(npc, targetPos)
			local effectiveSpeed = npc.speed
			if npc.legsCrippled then
				effectiveSpeed *= 0.35
			end
			if npc.berserkActive then
				effectiveSpeed *= 2.0
			end

			local newPos = npc.rootPart.Position + moveDir * (effectiveSpeed * dt)
			local lookCFrame = CFrame.lookAt(newPos, newPos + moveDir)
			npc.rootPart.CFrame = lookCFrame

			local head = npc.model:FindFirstChild("Head") :: BasePart?
			if head then
				head.CFrame = lookCFrame * CFrame.new(0, npc.rootPart.Size.Y / 2 + head.Size.Y / 2, 0)
			end
			local weak = npc.model:FindFirstChild("WeakPoint_Chest") :: BasePart?
			if weak then
				weak.CFrame = lookCFrame * CFrame.new(0, 0.2, -npc.rootPart.Size.Z / 2 - 0.05)
			end
		elseif npc.state == "ATTACK" and (now - npc.lastAttackClock) >= 1.0 then
			npc.lastAttackClock = now
			local dmg = npc.definition.dps * nightDamageMult * (if npc.berserkActive then 1.65 else 1.0)
			local targetId = npc.targetEntityId

			if targetId and string.sub(targetId, 1, 7) == "Player_" then
				local uid = tonumber(string.sub(targetId, 8))
				local plr = if uid then Players:GetPlayerByUserId(uid) else nil
				local char = if plr then plr.Character else nil
				local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
				if hum and hum.Health > 0 and not (char and char:GetAttribute("ZA_DashInvulnerable") == true) then
					hum:TakeDamage(dmg)
					-- M-41 Murciélago Vampiro (40% lifesteal) y M-56 Sanguinario Voraz (50% lifesteal)
					if npc.unitId == "M-41" then
						npc.hp = math.min(npc.maxHp, npc.hp + dmg * 0.40)
					elseif npc.unitId == "M-56" then
						npc.hp = math.min(npc.maxHp, npc.hp + dmg * 0.50)
					end
				end
			elseif targetId and activeNPCs[targetId] then
				AIService.applyDamageToNPC(targetId, dmg, "Torso", npc.faction)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- 7. DAÑO LOCALIZADO POR EXTREMIDAD Y ACTUALIZACIÓN DE SALUD DE JEFES
--------------------------------------------------------------------------------

function AIService.applyDamageToNPC(
	instanceId: string,
	rawDamage: number,
	hitZone: ("Head" | "Torso" | "Legs" | "WeakPoint" | "Back")?,
	attackerFaction: Types.FactionId?
): { killed: boolean, remainingHp: number, damageApplied: number }
	local npc = activeNPCs[instanceId]
	if not npc then
		return { killed = false, remainingHp = 0, damageApplied = 0 }
	end

	local mult = npc.markedMultiplier
	local zone = hitZone or "Torso"

	-- Reglas de daño localizado (Sección 3.3.3 y 6.2)
	if zone == "Head" then
		if npc.unitId == "Z-40" then
			mult *= 1.0 -- Minero Subterráneo inmune a crítico de headshot
		else
			mult *= 2.5
		end
	elseif zone == "WeakPoint" or zone == "Back" then
		mult *= 3.0 -- Grietas de Acorazado (Z-56), tanque de Soldador (Z-39) o puntos débiles de Mega Bruto
	elseif zone == "Legs" then
		-- Z-02 Corredor y Z-37 Soldado Kevlar se derriban/gatean al recibir disparos en las piernas
		if npc.unitId == "Z-02" or npc.unitId == "Z-37" then
			npc.legsCrippled = true
			npc.model:SetAttribute("ZA_LegsCrippled", true)
		end
	end

	-- Bloqueo frontal de escudos (Z-36, H-11, M-22) si no es por la espalda ni punto débil
	if (npc.unitId == "Z-36" or npc.unitId == "H-11") and zone == "Torso" then
		mult *= 0.15
	elseif npc.unitId == "Z-56" and zone ~= "WeakPoint" then
		mult *= 0.50 -- Acorazado de Hueso -50% daño general
	elseif npc.unitId == "M-25" and zone ~= "Head" then
		mult *= 0.60 -- Capitán Mutante Acorazado -40% daño balístico
	end

	local finalDamage = math.max(1, math.floor(rawDamage * mult))
	npc.hp = math.max(0, npc.hp - finalDamage)
	npc.model:SetAttribute("ZA_HP", npc.hp)
	if npc.humanoid then
		npc.humanoid.Health = npc.hp
	end

	-- M-43 Tejón Berserker: al bajar al 30% de HP entra en Furia
	if npc.unitId == "M-43" and not npc.berserkActive and (npc.hp / npc.maxHp) <= 0.30 and npc.hp > 0 then
		npc.berserkActive = true
		npc.model:SetAttribute("ZA_Berserk", true)
	end

	if npc.unitId == "Z-BOSS-01" or npc.unitId == "M-BOSS-01" then
		crucibleState.activeMegaBossHp = npc.hp
		syncCrucibleAttributes()
	end

	if npc.hp <= 0 then
		AIService.despawnOrRecycleNPC(instanceId, attackerFaction or "Human")
		return { killed = true, remainingHp = 0, damageApplied = finalDamage }
	end

	return { killed = false, remainingHp = npc.hp, damageApplied = finalDamage }
end

function AIService.getActiveNPC(instanceId: string): ActiveNPC?
	return activeNPCs[instanceId]
end

function AIService.getAllActiveNPCs(): { ActiveNPC }
	return activeNPCList
end

--------------------------------------------------------------------------------
-- 8. BUCLE HEARTBEAT: GOBERNADOR 30 HZ + PERCEPCIÓN POR LOTES + RED 10 UNIDADES
--------------------------------------------------------------------------------

local lastReplicationClock = 0

RunService.Heartbeat:Connect(function(dt: number)
	-- Gobernador de rendimiento automático (<30 Hz contrae lote 20->10 y cap 180->120)
	local instantHz = if dt > 0 then 1 / dt else 60
	currentServerHz = currentServerHz * 0.9 + instantHz * 0.1
	isPerformanceThrottled = currentServerHz < 30

	-- 1. Percepción por Lotes: procesa únicamente 20 NPCs (o 10 bajo throttle) por fotograma
	local totalNPCs = #activeNPCList
	if totalNPCs > 0 then
		local batchSize = if isPerformanceThrottled then PERCEPTION_BATCH_THROTTLED else PERCEPTION_BATCH_NORMAL
		local count = math.min(batchSize, totalNPCs)
		for _ = 1, count do
			if perceptionCursor > totalNPCs then
				perceptionCursor = 1
			end
			local npc = activeNPCList[perceptionCursor]
			if npc then
				evaluateNPCPerception(npc)
			end
			perceptionCursor += 1
		end
	end

	-- 2. Despachar hasta 4 llamadas PathfindingService:ComputeAsync() priorizadas
	processPathfindingQueue()

	-- 3. Movimiento por Steering Behaviors y ataques activos
	stepActiveNPCMovementAndCombat(dt)

	-- 4. Replicación agrupada en paquetes de máximo 10 unidades por evento vía UnreliableRemoteEvent
	local now = os.clock()
	if (now - lastReplicationClock) >= 0.20 and totalNPCs > 0 then
		lastReplicationClock = now
		local packet = table.create(math.min(10, totalNPCs))
		for idx = 1, math.min(10, totalNPCs) do
			local n = activeNPCList[idx]
			table.insert(packet, {
				id = n.instanceId,
				u = n.unitId,
				f = n.faction,
				hp = n.hp,
				p = n.rootPart.Position,
				s = n.state,
			})
		end
		npcBatchSyncRemote:FireAllClients(packet)
	end
end)

return AIService
