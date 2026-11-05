--!strict
--[[
	CombatAndArsenalService.luau
	Combate Autoritativo, Economía de Arsenal Modular (Lv1–Lv10), Emisor de Conciencia (G-20),
	Árbol de Habilidades Tácticas (Pulso, Dash i-frames 0.3s, QTE) y Destrucción de Entorno (400 HP)
	para Zombie Awareness (v4.0) (Secciones 1, 4.1, 5.3 y 6.2).
--]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local ZombieCatalogs = require(sharedFolder:WaitForChild("ZombieCatalogs") :: any)
local VFXAndJuiceEngine = require(sharedFolder:WaitForChild("VFXAndJuiceEngine") :: any)

local NetworkSecurityService = require(script.Parent:WaitForChild("NetworkSecurityService") :: any)
local DataPersistenceService = require(script.Parent:WaitForChild("DataPersistenceService") :: any)
local ThreatAndDistrictService = require(script.Parent:WaitForChild("ThreatAndDistrictService") :: any)
local AIService = require(script.Parent:WaitForChild("AIService") :: any)
local MissionGenService = require(script.Parent:WaitForChild("MissionGenService") :: any)

local CombatAndArsenalService = {}
CombatAndArsenalService.__index = CombatAndArsenalService

local MAX_BASE_PLAYER_SPEED = 25 -- 25 studs/s + dash registrado (Sección 6.2)
local G20_MAX_DISTANCE_STUDS = 60 -- <= 60 studs (Sección 1 y 6.2)
local G20_CHANNEL_DURATION_SEC = 2.0 -- 2.0 s canalización

local activeDashUntil: { [number]: number } = {}
local g20ChannelStartByPlayer: { [number]: { targetId: string, startedAt: number } } = {}
local lastPlayerPositions: { [number]: { pos: Vector3, timestamp: number } } = {}

-- Remotes autoritativos protegidos con Token Bucket
local combatActionRemote = NetworkSecurityService.createGuardedRemote("ZA_CombatAction")
local arsenalActionRemote = NetworkSecurityService.createGuardedRemote("ZA_ArsenalAction")
local tacticalSkillRemote = NetworkSecurityService.createGuardedRemote("ZA_TacticalSkill")
local vfxReplicateRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ZA_VFXReplicate") :: UnreliableRemoteEvent
if not vfxReplicateRemote then
	vfxReplicateRemote = Instance.new("UnreliableRemoteEvent")
	vfxReplicateRemote.Name = "ZA_VFXReplicate"
	vfxReplicateRemote.Parent = ReplicatedStorage:WaitForChild("Remotes")
end

--------------------------------------------------------------------------------
-- 1. EVOLUCIÓN DE ARMAS LV 1 A LV 10 Y REFUNDICIÓN AL 80% (ARMERÍA A-02)
--------------------------------------------------------------------------------

function CombatAndArsenalService.upgradeWeapon(player: Player, weaponId: string): (boolean, string)
	local data = DataPersistenceService.getData(player)
	if not data then
		return false, "Perfil no cargado"
	end

	local def = ZombieCatalogs.Weapons[weaponId]
	if not def then
		return false, "Arma inválida"
	end

	local currentLv = data.weaponLevels[weaponId] or 1
	if currentLv >= 10 then
		return false, "El arma ya alcanzó el Nivel 10 Conciencia"
	end

	local nextLv = currentLv + 1
	local cost = ZombieCatalogs.GetUpgradeCost(nextLv)

	if data.scrap < cost.scrap or data.components < cost.components or data.consciousnessCores < cost.cores then
		return false, string.format(
			"Recursos insuficientes (Requiere %d Chatarra, %d Componentes, %d Núcleos)",
			cost.scrap,
			cost.components,
			cost.cores
		)
	end

	data.scrap -= cost.scrap
	data.components -= cost.components
	data.consciousnessCores -= cost.cores
	data.weaponLevels[weaponId] = nextLv

	if nextLv == 10 then
		DataPersistenceService.flushCriticalTransaction(player, "WeaponLv10_" .. weaponId)
	else
		DataPersistenceService.syncLeaderstats(player, data)
	end

	return true, string.format("%s mejorada a Nivel %d", def.name, nextLv)
end

--[[
	Tapón #4 del Gameloop: Permite desmontar mejoras de un arma recuperando el 80%
	de Chatarra y Componentes invertidos para evitar callejones sin salida económicos.
--]]
function CombatAndArsenalService.salvageWeaponUpgrades(player: Player, weaponId: string): (boolean, string)
	local data = DataPersistenceService.getData(player)
	if not data then
		return false, "Perfil no cargado"
	end

	local currentLv = data.weaponLevels[weaponId] or 1
	if currentLv <= 1 then
		return false, "El arma está en Nivel 1 base"
	end

	local totalScrap = 0
	local totalComp = 0
	for lv = 2, currentLv do
		local c = ZombieCatalogs.GetUpgradeCost(lv)
		totalScrap += c.scrap
		totalComp += c.components
	end

	local refundScrap = math.floor(totalScrap * 0.80)
	local refundComp = math.floor(totalComp * 0.80)

	data.weaponLevels[weaponId] = 1
	data.scrap += refundScrap
	data.components += refundComp
	DataPersistenceService.syncLeaderstats(player, data)

	return true, string.format("Reembolsados %d Chatarra y %d Componentes (80%%)", refundScrap, refundComp)
end

--------------------------------------------------------------------------------
-- 2. CONSTRUCCIÓN EN REFUGIO PROPIO (CATÁLOGO A) Y CUARTEL DE MERCENARIOS (A-05)
--------------------------------------------------------------------------------

function CombatAndArsenalService.upgradeRefugeBuilding(player: Player, buildingId: string): (boolean, string)
	local data = DataPersistenceService.getData(player)
	if not data then
		return false, "Perfil no cargado"
	end

	local bCfg = ZombieCatalogs.RefugeBuildings[buildingId]
	if not bCfg then
		return false, "Edificio del Catálogo A no encontrado"
	end

	local currentTier = data.refugeBuildings[buildingId] or 0
	if currentTier >= bCfg.maxTier then
		return false, "El edificio ya está en Tier 3 máximo"
	end

	if bCfg.requiredSpecialistId and (data.rescuedSpecialists[bCfg.requiredSpecialistId] or 0) <= 0 then
		return false, "Requiere rescatar primero al especialista " .. tostring(bCfg.requiredSpecialistId)
	end

	local nextTier = currentTier + 1
	local scrapCost = bCfg.baseScrapCost * nextTier
	local compCost = bCfg.baseComponentsCost * nextTier
	local coreCost = bCfg.baseCoresCost * nextTier

	if data.scrap < scrapCost or data.components < compCost or data.consciousnessCores < coreCost then
		return false, "Recursos insuficientes para mejorar " .. bCfg.name
	end

	data.scrap -= scrapCost
	data.components -= compCost
	data.consciousnessCores -= coreCost
	data.refugeBuildings[buildingId] = nextTier

	-- Si mejora el Laboratorio de Conciencia (A-06), desbloquea/mejora el Emisor G-20 (Tapón #5)
	if buildingId == "A-06" and data.g20Tier < nextTier then
		data.g20Tier = math.min(2, nextTier)
		data.loadout.emitterG20Tier = data.g20Tier
	end

	if nextTier == 3 then
		DataPersistenceService.flushCriticalTransaction(player, "BuildingTier3_" .. buildingId)
	else
		DataPersistenceService.syncLeaderstats(player, data)
	end

	return true, string.format("%s mejorado a Tier %d", bCfg.name, nextTier)
end

function CombatAndArsenalService.hireAndDeployMercenary(player: Player, mercId: Types.MercenaryId): (boolean, string)
	local data = DataPersistenceService.getData(player)
	if not data then
		return false, "Perfil no cargado"
	end

	local mCfg = ZombieCatalogs.Mercenaries[mercId]
	if not mCfg then
		return false, "Mercenario inválido"
	end

	if not data.hiredMercenaries[mercId] then
		if data.scrap < mCfg.hireScrap or data.consciousnessCores < mCfg.hireCores then
			return false, "Recursos insuficientes para contratar a " .. mCfg.name
		end
		data.scrap -= mCfg.hireScrap
		data.consciousnessCores -= mCfg.hireCores
		data.hiredMercenaries[mercId] = true
		DataPersistenceService.flushCriticalTransaction(player, "HireMerc_" .. mercId)
	end

	-- Máximo 3 Mercenarios activos en partida (Sección 4.1)
	if #data.activeMercenaries >= 3 and not table.find(data.activeMercenaries, mercId) then
		table.remove(data.activeMercenaries, 1)
	end
	if not table.find(data.activeMercenaries, mercId) then
		table.insert(data.activeMercenaries, mercId)
	end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local spawnPos = if root then root.Position + Vector3.new(5, 0, 5) else ZombieCatalogs.Districts.Z0.centerPosition

	AIService.spawnNPC(mCfg.unitId, spawnPos, "Z0", player.UserId)

	-- Si es la Domadora (Tamer), despliega además su mascota zombi permanente (Sección 1)
	if mercId == "Tamer" then
		local pet = AIService.spawnNPC("Z-04", spawnPos + Vector3.new(-4, 0, 4), "Z0", player.UserId)
		if pet then
			AIService.hypnotizeNPC(pet.instanceId, player, nil)
		end
	end

	return true, string.format("Mercenario %s desplegado en escuadrón", mCfg.name)
end

--------------------------------------------------------------------------------
-- 3. DESTRUCCIÓN DE MUROS DE 400 HP Y BARRILES EXPLOSIVOS (50 DMG, 10 STUDS)
--------------------------------------------------------------------------------

function CombatAndArsenalService.damageBreachWall(wallPart: BasePart, damage: number): boolean
	if not CollectionService:HasTag(wallPart, "RAASE_BreachWall") then
		return false
	end
	if wallPart:GetAttribute("ZA_IsBreached") == true then
		return false
	end

	local currentHp = (wallPart:GetAttribute("ZA_HP") :: number?) or 400
	local newHp = math.max(0, currentHp - damage)
	wallPart:SetAttribute("ZA_HP", newHp)

	if newHp <= 0 then
		-- Tapón #6: Convertir en umbral de escombros bajo (1.5 studs) sin dejar techos flotando
		wallPart:SetAttribute("ZA_IsBreached", true)
		local origSize = wallPart.Size
		wallPart.Size = Vector3.new(origSize.X, 1.5, origSize.Z)
		wallPart.Position = Vector3.new(wallPart.Position.X, 1.75, wallPart.Position.Z)
		wallPart.Material = Enum.Material.Slate
		AIService.invalidatePathCacheNearPosition(wallPart.Position)
		vfxReplicateRemote:FireAllClients("VFX_Hulk_Shockwave", wallPart.Position)
		return true
	end
	return false
end

function CombatAndArsenalService.repairBreachWall(player: Player, wallPart: BasePart): (boolean, string)
	if not CollectionService:HasTag(wallPart, "RAASE_BreachWall") then
		return false, "No es un panel de brecha reparable"
	end
	if wallPart:GetAttribute("ZA_IsBreached") ~= true then
		return false, "El muro ya está íntegro"
	end
	if not NetworkSecurityService.validateProximity(player, wallPart.Position, 15) then
		return false, "Demasiado lejos para reparar el muro"
	end

	local origH = (wallPart:GetAttribute("ZA_OriginalHeight") :: number?) or 14
	local origY = (wallPart:GetAttribute("ZA_OriginalY") :: number?) or 8
	wallPart.Size = Vector3.new(wallPart.Size.X, origH, wallPart.Size.Z)
	wallPart.Position = Vector3.new(wallPart.Position.X, origY, wallPart.Position.Z)
	wallPart.Material = Enum.Material.Brick
	wallPart:SetAttribute("ZA_HP", 400)
	wallPart:SetAttribute("ZA_IsBreached", false)
	AIService.invalidatePathCacheNearPosition(wallPart.Position)

	return true, "Muro reconstruido a 400 HP"
end

function CombatAndArsenalService.detonateExplosiveBarrel(barrelPart: BasePart, attackerPlayer: Player?)
	if not CollectionService:HasTag(barrelPart, "RAASE_ExplosiveBarrel") then
		return
	end
	if barrelPart:GetAttribute("ZA_Exploded") == true then
		return
	end

	barrelPart:SetAttribute("ZA_Exploded", true)
	local pos = barrelPart.Position
	local radius = (barrelPart:GetAttribute("ZA_ExplosionRadius") :: number?) or 10
	local dmg = (barrelPart:GetAttribute("ZA_ExplosionDamage") :: number?) or 50

	barrelPart.Transparency = 1
	barrelPart.CanCollide = false
	vfxReplicateRemote:FireAllClients("VFX_Rocket_Barrage", pos)

	-- Aplicar 50 dmg en radio de 10 studs a NPCs y muros de brecha
	for _, npc in ipairs(AIService.getAllActiveNPCs()) do
		if (npc.rootPart.Position - pos).Magnitude <= radius then
			AIService.applyDamageToNPC(npc.instanceId, dmg * 2, "WeakPoint", "Human")
		end
	end

	local partsInRadius = Workspace:GetPartBoundsInRadius(pos, radius)
	for _, part in ipairs(partsInRadius) do
		if CollectionService:HasTag(part, "RAASE_BreachWall") then
			CombatAndArsenalService.damageBreachWall(part, 200)
		end
	end
end

--------------------------------------------------------------------------------
-- 4. ATAQUE AUTORITATIVO, DAÑO POR EXTREMIDAD Y RECOMPENSAS DE BOTÍN
--------------------------------------------------------------------------------

function CombatAndArsenalService.processWeaponAttack(
	player: Player,
	weaponId: string,
	targetInstanceId: string,
	hitZone: ("Head" | "Torso" | "Legs" | "WeakPoint" | "Back")?
): (boolean, string)
	local data = DataPersistenceService.getData(player)
	if not data then
		return false, "Sin datos de sesión"
	end

	local weaponDef = ZombieCatalogs.Weapons[weaponId]
	if not weaponDef then
		return false, "Arma no registrada"
	end

	local lv = data.weaponLevels[weaponId] or 1
	local computed = ZombieCatalogs.GetWeaponStatsAtLevel(weaponId, lv)

	-- Validar y consumir munición si no es arma Melee
	if weaponDef.ammoFamily ~= "None" then
		local poolCount = (data.ammoPools :: any)[weaponDef.ammoFamily] or 0
		if poolCount <= 0 then
			return false, "Sin munición de familia " .. weaponDef.ammoFamily
		end
		(data.ammoPools :: any)[weaponDef.ammoFamily] = poolCount - 1
	end

	local npc = AIService.getActiveNPC(targetInstanceId)
	if not npc then
		return false, "Objetivo inexistente"
	end

	-- Validar distancia máxima autoritativa
	if not NetworkSecurityService.validateProximity(player, npc.rootPart.Position, weaponDef.rangeStuds + 12) then
		return false, "Objetivo fuera del alcance efectivo del arma"
	end

	-- Tapón #3: Protección Anti-Griefing en ataque a aliados humanos
	if npc.faction == "Human" and npc.ownerUserId ~= player.UserId then
		data.renegadeUntil = os.time() + 300
		data.humanLoyalty = math.max(-100, data.humanLoyalty - 25)
		player:SetAttribute("ZA_IsRenegade", true)
	end

	local rawDamage = computed.damage
	if hitZone == "Head" and weaponDef.slotCategory == "Sniper" then
		-- Francotiradores tienen x3.0 en Headshot (compensamos el x2.5 base de AIService)
		rawDamage = rawDamage * (3.0 / 2.5)
	end

	local targetUnitId = npc.unitId
	local targetDistrict = npc.districtId
	local targetPos = npc.rootPart.Position
	local isBoss = targetUnitId == "Z-BOSS-01" or targetUnitId == "M-BOSS-01"

	local res = AIService.applyDamageToNPC(targetInstanceId, rawDamage, hitZone, "Human")
	vfxReplicateRemote:FireAllClients(weaponDef.vfxPreset, targetPos)

	if res.killed then
		local rarity = ThreatAndDistrictService.rollLootRarity(targetDistrict)
		local scrapReward = if rarity == "Unique"
			then 120
			elseif rarity == "Legendary" then 75
			elseif rarity == "Epic" then 45
			elseif rarity == "Rare" then 25
			else 12
		local compReward = if rarity == "Unique" or rarity == "Legendary" then 4 elseif rarity == "Epic" then 2 else 1
		local coreReward = if rarity == "Unique" then 2 elseif rarity == "Legendary" then 1 else 0

		-- Evento E-16: Derrotar al Mega Bruto Líder otorga 50 Núcleos y el Emisor G-20 Soberano (Tier 3)
		if isBoss then
			coreReward += 50
			data.g20Tier = 3
			data.loadout.emitterG20Tier = 3
			DataPersistenceService.flushCriticalTransaction(player, "MegaBossDefeated_" .. targetUnitId)
		end

		DataPersistenceService.addUnsecuredLoot(player, scrapReward, compReward, coreReward)
	end

	return true, string.format("Impacto confirmado (%d dmg)", res.damageApplied)
end

--------------------------------------------------------------------------------
-- 5. VALIDACIÓN SERVER-SIDE DEL EMISOR DE CONCIENCIA (G-20) (SECCIÓN 1 Y 6.2)
--------------------------------------------------------------------------------

function CombatAndArsenalService.startChannelingG20(player: Player, targetNpcId: string): (boolean, string)
	local data = DataPersistenceService.getData(player)
	if not data or data.g20Tier <= 0 then
		return false, "Emisor de Conciencia (G-20) aún no desbloqueado en el Laboratorio A-06"
	end

	local npc = AIService.getActiveNPC(targetNpcId)
	if not npc then
		return false, "Objetivo inválido"
	end

	if not NetworkSecurityService.validateProximity(player, npc.rootPart.Position, G20_MAX_DISTANCE_STUDS) then
		return false, "Objetivo fuera del rango de 60 studs del Emisor G-20"
	end

	g20ChannelStartByPlayer[player.UserId] = {
		targetId = targetNpcId,
		startedAt = os.clock(),
	}
	vfxReplicateRemote:FireAllClients("VFX_Hypnosis_Wave", npc.rootPart.Position)
	return true, "Canalizando Emisor de Conciencia (2.0s)..."
end

function CombatAndArsenalService.completeChannelingG20(player: Player, targetNpcId: string): (boolean, string)
	local data = DataPersistenceService.getData(player)
	if not data or data.g20Tier <= 0 then
		return false, "Emisor G-20 no disponible"
	end

	local session = g20ChannelStartByPlayer[player.UserId]
	local requiredSec = if data.g20Tier >= 3 then 0.8 else (G20_CHANNEL_DURATION_SEC - 0.15)
	if not session or session.targetId ~= targetNpcId or (os.clock() - session.startedAt) < requiredSec then
		return false, "Canalización de 2.0s incompleta"
	end
	g20ChannelStartByPlayer[player.UserId] = nil

	local npc = AIService.getActiveNPC(targetNpcId)
	if not npc then
		return false, "El objetivo murió antes de completar la hipnosis"
	end

	if not NetworkSecurityService.validateProximity(player, npc.rootPart.Position, G20_MAX_DISTANCE_STUDS) then
		return false, "El objetivo salió del radio de 60 studs"
	end

	-- Verificar línea de visión con Raycast
	local char = player.Character
	local pRoot = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if pRoot then
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { char, npc.model }
		local dir = npc.rootPart.Position - pRoot.Position
		local hit = Workspace:Raycast(pRoot.Position, dir, rayParams)
		if hit and hit.Instance and hit.Instance.CanCollide then
			return false, "Línea de visión bloqueada hacia el objetivo"
		end
	end

	local duration = if data.g20Tier >= 3 then nil else 90
	local ok, msg = AIService.hypnotizeNPC(targetNpcId, player, duration)
	if ok then
		vfxReplicateRemote:FireAllClients("VFX_Hypnosis_Wave", npc.rootPart.Position)
	end
	return ok, msg
end

--------------------------------------------------------------------------------
-- 6. HABILIDADES TÁCTICAS: DASH (0.3S I-FRAMES), PULSO Y EJECUCIÓN QTE
--------------------------------------------------------------------------------

function CombatAndArsenalService.triggerTacticalDash(player: Player): (boolean, string)
	local char = player.Character
	if not char then
		return false, "Sin personaje activo"
	end
	if char:GetAttribute("ZA_SnaredByWire") == true then
		return false, "Enganchado por alambre de púas (Z-16): Dash bloqueado"
	end

	local now = os.clock()
	activeDashUntil[player.UserId] = now + 0.8
	char:SetAttribute("ZA_DashInvulnerable", true)

	task.delay(0.3, function()
		if char and char.Parent then
			char:SetAttribute("ZA_DashInvulnerable", false)
		end
	end)

	return true, "Dash Táctico activado (0.3s i-frames)"
end

function CombatAndArsenalService.triggerConsciousnessPulse(player: Player): (boolean, string)
	player:SetAttribute("ZA_PulseActive", true)
	task.delay(6.0, function()
		if player and player.Parent then
			player:SetAttribute("ZA_PulseActive", false)
		end
	end)
	return true, "Pulso de Conciencia activo por 6s"
end

function CombatAndArsenalService.executeQTEFinisher(player: Player, targetNpcId: string): (boolean, string)
	local npc = AIService.getActiveNPC(targetNpcId)
	if not npc then
		return false, "Objetivo no válido para QTE"
	end
	if not NetworkSecurityService.validateProximity(player, npc.rootPart.Position, 12) then
		return false, "Demasiado lejos para ejecución QTE"
	end

	if (npc.hp / npc.maxHp) <= 0.25 and npc.definition.pathPriority >= 3 then
		AIService.applyDamageToNPC(targetNpcId, npc.hp + 100, "Head", "Human")
		return true, "Ejecución QTE completada"
	end
	return false, "El enemigo aún tiene más del 25% de salud"
end

--------------------------------------------------------------------------------
-- 7. LISTENERS DE RED CON TOKEN BUCKET Y VALIDACIÓN DE VELOCIDAD (25 STUDS/S)
--------------------------------------------------------------------------------

NetworkSecurityService.listenGuarded(combatActionRemote, function(player: Player, actionType: any, arg1: any, arg2: any, arg3: any)
	if typeof(actionType) ~= "string" then
		return
	end
	if actionType == "AttackNPC" and typeof(arg1) == "string" and typeof(arg2) == "string" then
		local zone = if typeof(arg3) == "string" then arg3 else "Torso"
		CombatAndArsenalService.processWeaponAttack(player, arg1, arg2, zone :: any)
	elseif actionType == "G20Start" and typeof(arg1) == "string" then
		CombatAndArsenalService.startChannelingG20(player, arg1)
	elseif actionType == "G20Complete" and typeof(arg1) == "string" then
		CombatAndArsenalService.completeChannelingG20(player, arg1)
	elseif actionType == "ExtractVault" then
		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root then
			local distId = ThreatAndDistrictService.getDistrictAtPosition(root.Position)
			local st = ThreatAndDistrictService.getDistrictState(distId)
			if distId == "Z0" or (st and st.liberated) then
				DataPersistenceService.extractBackpackToSafeVault(player)
			end
		end
	end
end, 1)

NetworkSecurityService.listenGuarded(arsenalActionRemote, function(player: Player, actionType: any, targetId: any, extraArg: any)
	if typeof(actionType) ~= "string" or typeof(targetId) ~= "string" then
		return
	end
	if actionType == "UpgradeWeapon" then
		CombatAndArsenalService.upgradeWeapon(player, targetId)
	elseif actionType == "SalvageWeapon" then
		CombatAndArsenalService.salvageWeaponUpgrades(player, targetId)
	elseif actionType == "UpgradeBuilding" then
		CombatAndArsenalService.upgradeRefugeBuilding(player, targetId)
	elseif actionType == "HireMercenary" then
		CombatAndArsenalService.hireAndDeployMercenary(player, targetId :: any)
	elseif actionType == "AssignSpecialist" and typeof(extraArg) == "string" then
		ThreatAndDistrictService.assignSpecialistToDistrict(player, targetId :: any, extraArg)
	end
end, 2)

NetworkSecurityService.listenGuarded(tacticalSkillRemote, function(player: Player, skillName: any, targetId: any)
	if typeof(skillName) ~= "string" then
		return
	end
	if skillName == "Dash" then
		CombatAndArsenalService.triggerTacticalDash(player)
	elseif skillName == "Pulse" then
		CombatAndArsenalService.triggerConsciousnessPulse(player)
	elseif skillName == "QTE" and typeof(targetId) == "string" then
		CombatAndArsenalService.executeQTEFinisher(player, targetId)
	end
end, 2)

-- Anti-Exploit de Velocidad Máxima (25 studs/s + dash registrado, Sección 6.2)
task.spawn(function()
	while true do
		task.wait(1.0)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			if root and hum and hum.Health > 0 then
				local prev = lastPlayerPositions[player.UserId]
				if prev then
					local dt = math.max(0.1, now - prev.timestamp)
					local horizDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(prev.pos.X, 0, prev.pos.Z)).Magnitude
					local speed = horizDist / dt
					local dashBonus = if (activeDashUntil[player.UserId] or 0) >= prev.timestamp then 35 else 0
					local maxAllowed = MAX_BASE_PLAYER_SPEED + dashBonus + 8 -- margen de latencia de red
					if speed > maxAllowed and horizDist < 400 then
						root.CFrame = CFrame.new(prev.pos)
					end
				end
				lastPlayerPositions[player.UserId] = { pos = root.Position, timestamp = now }
			end
		end
	end
end)

return CombatAndArsenalService
