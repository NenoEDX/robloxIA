--!strict
--[[
	SlimeCoreService.luau
	Servidor Autoritativo de "SLIME PIT: Dive for Mutants!" (Abyssal Slime Core):
	- Construcción del Anfiteatro Abisal Cónico (Lobby Circular, Malla Persistent, 6 Macro-Rings/30 Biomas).
	- Streaming y control de hoyos vía CollectionService ("AbyssalSlimeHole").
	- Infestación de madrigueras (+500% mutación 600s), combate contra Guardianes,
	  Tanque Dorsal Presurizado y penalización del 25% (UNREFINED_SPILL_PENALTY = 0.25) con Charco Mutagénico.
	- Extracción al Lobby Circular con tope de 10 mutaciones (MAX_MUTATIONS_PER_SLIME = 10) y 4 eventos de animación.
	- Tienda de Evento Día 1 (x1, x3, x10) con auditoría PolicyService.ArePaidRandomItemsRestricted y Cola Determinista.
	- Captura Dinámica en Robux (1x/día gratis asegurada cada 86400s o brecha hasta 10k+ Robux) y Salto de Tiempo.
	- Comercio Two-Phase Commit con UUID, IsPaidItemTradingAllowed y segregación Earned_Free.
	- Bounties de 2 ejes, Fermentación Offline (1-12h) y Panel Global Admin Abuse (MessagingService).
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(SharedFolder:WaitForChild("Types") :: any)
local SlimeCatalogs = require(SharedFolder:WaitForChild("SlimeCatalogs") :: any)
local SlimeCoreMath = require(SharedFolder:WaitForChild("SlimeCoreMath") :: any)
local NetworkSecurityService = require(script.Parent:WaitForChild("NetworkSecurityService") :: any)

export type SlimeDefinition = Types.SlimeDefinition
export type SlimePetInstance = Types.SlimePetInstance
export type MutationDefinition = Types.MutationDefinition
export type EventCrateItem = Types.EventCrateItem
export type DynamicCaptureQuote = Types.DynamicCaptureQuote
export type AdminAbuseCommand = Types.AdminAbuseCommand
export type AcquisitionPath = Types.AcquisitionPath

local SlimeCoreService = {}
SlimeCoreService.__index = SlimeCoreService

SlimeCoreService.UNREFINED_SPILL_PENALTY = 0.25
SlimeCoreService.MAX_MUTATIONS_PER_SLIME = 10
SlimeCoreService.ABYSSAL_HOLE_TAG = "AbyssalSlimeHole"
SlimeCoreService.HOLE_INFESTATION_DURATION_SEC = 600
SlimeCoreService.HOLE_INFESTATION_MUTATION_BUFF = 5.0

-- In-memory state tracking
local playerDorsalTanks: { [number]: { unrefinedJuice: number, pendingSlimes: { SlimePetInstance } } } = {}
local playerInventories: { [number]: { [string]: SlimePetInstance } } = {}
local playerDailyFreeCaptureTime: { [number]: number } = {}
local playerDeterministicQueues: { [number]: { EventCrateItem } } = {}
local activeHoleInfestations: { [Instance]: number } = {}
local lockedTradeItems: { [string]: boolean } = {}
local activeFermentations: {
	[number]: {
		[number]: {
			vatId: number,
			juiceType: string,
			amount: number,
			startTime: number,
			completeTime: number,
		},
	},
} = {}

-- Guarded RemoteEvents
local remotes = {
	ExtractionRarityAnim = NetworkSecurityService.createGuardedRemote("Slime_ExtractionRarityAnim"),
	BaseArrivalAnim = NetworkSecurityService.createGuardedRemote("Slime_BaseArrivalAnim"),
	MutationStrikeDropAnim = NetworkSecurityService.createGuardedRemote("Slime_MutationStrikeDropAnim"),
	PetExtractedMutationAnim = NetworkSecurityService.createGuardedRemote("Slime_PetExtractedMutationAnim"),
	CrateRevealAnim = NetworkSecurityService.createGuardedRemote("Slime_CrateRevealAnim"),
	AdminAbuseBroadcast = NetworkSecurityService.createGuardedRemote("Slime_AdminAbuseBroadcast"),
	DynamicCapturePrompt = NetworkSecurityService.createGuardedRemote("Slime_DynamicCapturePrompt"),
}

--[[
	1. Constructor del Anfiteatro Abisal Cónico Invertido:
	- Circular Lobby superior con Óculo Central
	- Malla Cascarón de Baja Poli Persistent
	- 6 Macro-Rings con 30 Biomes descendentes
	- StreamingMinRadius = 128, StreamingTargetRadius = 256, StreamOutBehavior.Opportunistic
	- Central "AbyssalSlimeHole" tag vía CollectionService
]]
function SlimeCoreService.buildAbyssalAmphitheater(): Folder
	pcall(function()
		Workspace.StreamingMinRadius = 128
		Workspace.StreamingTargetRadius = 256
		Workspace.StreamOutBehavior = Enum.StreamOutBehavior.Opportunistic
	end)

	local existing = Workspace:FindFirstChild("AbyssalAmphitheater")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local container = Instance.new("Folder")
	container.Name = "AbyssalAmphitheater"

	-- Lobby Circular Superior (Y = 600)
	local lobbyModel = Instance.new("Model")
	lobbyModel.Name = "CircularLobby"

	local lobbyFloor = Instance.new("Part")
	lobbyFloor.Name = "LobbyFloorRing"
	lobbyFloor.Size = Vector3.new(160, 4, 160)
	lobbyFloor.Position = Vector3.new(0, 600, 0)
	lobbyFloor.Anchored = true
	lobbyFloor.Material = Enum.Material.SmoothPlastic
	lobbyFloor.Color = Color3.fromRGB(35, 40, 52)
	lobbyFloor.Parent = lobbyModel

	local oculusHole = Instance.new("Part")
	oculusHole.Name = "CentralOculusHole"
	oculusHole.Size = Vector3.new(24, 6, 24)
	oculusHole.Position = Vector3.new(0, 599, 0)
	oculusHole.CanCollide = false
	oculusHole.Transparency = 1
	oculusHole.Anchored = true
	CollectionService:AddTag(oculusHole, SlimeCoreService.ABYSSAL_HOLE_TAG)
	oculusHole.Parent = lobbyModel
	lobbyModel.Parent = container

	-- Malla Cascarón Persistent
	local shellModel = Instance.new("Model")
	shellModel.Name = "PersistentLowPolyShell"
	shellModel:SetAttribute("Persistent", true)
	pcall(function()
		shellModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)

	local shellWall = Instance.new("Part")
	shellWall.Name = "OuterAbyssalConeWall"
	shellWall.Size = Vector3.new(320, 1200, 320)
	shellWall.Position = Vector3.new(0, 0, 0)
	shellWall.Anchored = true
	shellWall.CanCollide = false
	shellWall.Transparency = 0.85
	shellWall.Material = Enum.Material.ForceField
	shellWall.Color = Color3.fromRGB(15, 20, 35)
	shellWall.Parent = shellModel
	shellModel.Parent = container

	-- 6 Macro-Estratos / 30 Biomas descendiendo en espiral cónica
	local biomesFolder = Instance.new("Folder")
	biomesFolder.Name = "MacroRingsAndBiomes"

	for ring = 1, SlimeCatalogs.MACRO_RINGS do
		local ringModel = Instance.new("Model")
		ringModel.Name = string.format("MacroRing_%02d", ring)
		local ringY = 500 - (ring * 160)

		for sub = 1, SlimeCatalogs.SUB_BIOMES_PER_RING do
			local biomeIndex = (ring - 1) * SlimeCatalogs.SUB_BIOMES_PER_RING + sub
			local biomePart = Instance.new("Part")
			biomePart.Name = string.format("BiomePlatform_%02d", biomeIndex)
			local angle = ((sub - 1) / SlimeCatalogs.SUB_BIOMES_PER_RING) * (math.pi * 2)
			local radius = 80 - (ring * 8)
			biomePart.Position = Vector3.new(math.cos(angle) * radius, ringY, math.sin(angle) * radius)
			biomePart.Size = Vector3.new(28, 4, 28)
			biomePart.Anchored = true
			biomePart.Material = Enum.Material.Slate
			biomePart.Color = Color3.fromHSV((biomeIndex * 12 % 360) / 360, 0.7, 0.5)

			local holePart = Instance.new("Part")
			holePart.Name = string.format("SlimeHole_B%02d", biomeIndex)
			holePart.Position = biomePart.Position + Vector3.new(0, 3, 0)
			holePart.Size = Vector3.new(8, 2, 8)
			holePart.Anchored = true
			holePart.CanCollide = false
			holePart.Color = Color3.fromRGB(120, 20, 180)
			CollectionService:AddTag(holePart, SlimeCoreService.ABYSSAL_HOLE_TAG)
			holePart.Parent = biomePart

			biomePart.Parent = ringModel
		end
		ringModel.Parent = biomesFolder
	end
	biomesFolder.Parent = container

	container.Parent = Workspace
	return container
end

--[[
	2. Infestación de Madrigueras (+500% mutación 600s), Combate contra Guardianes
	y Tanque Dorsal con penalización del 25% (UNREFINED_SPILL_PENALTY = 0.25).
]]
function SlimeCoreService.infestSlimeHole(holeInstance: Instance, durationSec: number?): boolean
	if not CollectionService:HasTag(holeInstance, SlimeCoreService.ABYSSAL_HOLE_TAG) then
		return false
	end
	local dur = durationSec or SlimeCoreService.HOLE_INFESTATION_DURATION_SEC
	local expireTime = os.time() + dur
	activeHoleInfestations[holeInstance] = expireTime
	holeInstance:SetAttribute("IsInfested", true)
	holeInstance:SetAttribute("InfestationExpiry", expireTime)

	task.delay(dur, function()
		if activeHoleInfestations[holeInstance] == expireTime then
			activeHoleInfestations[holeInstance] = nil
			holeInstance:SetAttribute("IsInfested", false)
		end
	end)
	return true
end

function SlimeCoreService.isHoleInfested(holeInstance: Instance): boolean
	local exp = activeHoleInfestations[holeInstance]
	return exp ~= nil and os.time() < exp
end

function SlimeCoreService.engageGuardianCombat(
	player: Player,
	guardianSlimeId: string,
	biomeIndex: number
): { outcome: "VICTORY" | "WIPE", damageDealt: number, puddleSpawned: boolean }
	local tank = playerDorsalTanks[player.UserId]
	if not tank then
		return { outcome = "WIPE", damageDealt = 0, puddleSpawned = false }
	end

	local guardianDef = SlimeCatalogs.SLIMES_BY_ID[guardianSlimeId]
	local rawDamage = if guardianDef then guardianDef.basePower else (50 + biomeIndex * 20)

	local pets = SlimeCoreService.getPlayerPets(player)
	local allDefeated = true
	local totalDamageReceived = 0

	for _, pet in pets do
		if pet.cooldownUntilOsTime <= os.time() then
			local dmg = SlimeCoreMath.computeGuardianDamageReceived(rawDamage, 30, pet.level, pet.stars)
			totalDamageReceived += dmg
			pet.currentHP = math.max(0, pet.currentHP - dmg)
			if pet.currentHP <= 0 then
				local cdSec = SlimeCoreMath.computePetDeathCooldown(biomeIndex, 10, 0)
				pet.cooldownUntilOsTime = os.time() + math.floor(cdSec)
			else
				allDefeated = false
			end
		end
	end

	if #pets == 0 or allDefeated then
		-- Derrame del 25% de jugo en Charco Mutagénico
		local unrefined = tank.unrefinedJuice
		local spilledAmount = math.floor(unrefined * SlimeCoreService.UNREFINED_SPILL_PENALTY)
		tank.unrefinedJuice = math.max(0, unrefined - spilledAmount)

		local dropPos = Vector3.new(0, 0, 0)
		local char = player.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				dropPos = root.Position
			end
		end

		local puddle = Instance.new("Part")
		puddle.Name = "MutagenicPuddle"
		puddle.Size = Vector3.new(12, 1, 12)
		puddle.Position = dropPos
		puddle.Anchored = true
		puddle.CanCollide = false
		puddle.Material = Enum.Material.Neon
		puddle.Color = Color3.fromRGB(75, 230, 95)
		puddle:SetAttribute("SpilledJuice", spilledAmount)
		puddle:SetAttribute("OwnerUserId", player.UserId)
		puddle:SetAttribute("RecoverableUntil", os.time() + 300)
		puddle.Parent = Workspace

		task.delay(300, function()
			if puddle and puddle.Parent then
				puddle:Destroy()
			end
		end)

		return { outcome = "WIPE", damageDealt = totalDamageReceived, puddleSpawned = true }
	end

	return { outcome = "VICTORY", damageDealt = totalDamageReceived, puddleSpawned = false }
end

--[[
	3. Extracción al Lobby Circular:
	- Asegura jugo volátil del tanque
	- Procesa slimes asignando hasta MAX_MUTATIONS_PER_SLIME = 10 (nunca 30)
	- Dispara los 4 eventos de animación client-side
]]
function SlimeCoreService.extractToCircularLobby(player: Player): {
	success: boolean,
	securedJuice: number,
	extractedSlimes: { SlimePetInstance },
}
	local tank = playerDorsalTanks[player.UserId]
	if not tank then
		return { success = false, securedJuice = 0, extractedSlimes = {} }
	end

	local secured = tank.unrefinedJuice
	tank.unrefinedJuice = 0

	local processedPets: { SlimePetInstance } = {}
	local inventory = playerInventories[player.UserId] or {}
	playerInventories[player.UserId] = inventory

	local maxMutations = SlimeCoreService.MAX_MUTATIONS_PER_SLIME

	for _, pendingPet in tank.pendingSlimes do
		local currentCount = #pendingPet.mutations
		local mutationPool = SlimeCatalogs.MUTATIONS
		local mutationsToApply = math.min(maxMutations - currentCount, math.random(1, 3))

		for _ = 1, mutationsToApply do
			if #pendingPet.mutations < maxMutations then
				local pick = mutationPool[math.random(1, #mutationPool)]
				if not table.find(pendingPet.mutations, pick.id) then
					table.insert(pendingPet.mutations, pick.id)
					remotes.MutationStrikeDropAnim:FireClient(player, pendingPet, pick)
					remotes.PetExtractedMutationAnim:FireClient(player, pendingPet, pick)
				end
			end
		end

		inventory[pendingPet.uuid] = pendingPet
		table.insert(processedPets, pendingPet)
		remotes.BaseArrivalAnim:FireClient(player, pendingPet, #pendingPet.mutations)
	end

	tank.pendingSlimes = {}

	local highestGrade: Types.SlimeRarityGradeId = "GRADE_01_BASIC"
	for _, pet in processedPets do
		local def = SlimeCatalogs.SLIMES_BY_ID[pet.slimeId]
		if def and def.rarityGrade > highestGrade then
			highestGrade = def.rarityGrade
		end
	end
	remotes.ExtractionRarityAnim:FireClient(player, highestGrade, math.clamp(secured / 1000, 0, 1))

	return {
		success = true,
		securedJuice = secured,
		extractedSlimes = processedPets,
	}
end

--[[
	4. Tienda de Evento Día 1:
	- Soporta x1, x3, x10 cajas con fichas de evento o vía de pago
	- Audita PolicyService.ArePaidRandomItemsRestricted fail-closed
	- Conmuta a Cola Determinista Pre-revelada en jurisdicciones restringidas
]]
function SlimeCoreService.openEventSpecialCrates(player: Player, count: number, usePaidPath: boolean): {
	success: boolean,
	items: { EventCrateItem },
	usedDeterministicQueue: boolean,
}
	local openCount = if count == 10 then 10 elseif count == 3 then 3 else 1

	local policyCheckOk, policyInfo = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)

	local arePaidRandomRestricted = true
	if policyCheckOk and policyInfo and typeof(policyInfo.ArePaidRandomItemsRestricted) == "boolean" then
		arePaidRandomRestricted = policyInfo.ArePaidRandomItemsRestricted
	end

	local pool = SlimeCatalogs.EVENT_CRATE_DAY1_POOL
	local grantedItems: { EventCrateItem } = {}
	local usedDeterministic = false

	if usePaidPath and arePaidRandomRestricted then
		usedDeterministic = true
		local queue = playerDeterministicQueues[player.UserId]
		if not queue or #queue < openCount then
			queue = {}
			for i = 1, 10 do
				local deterministicIndex = ((i * 3 + player.UserId) % #pool) + 1
				table.insert(queue, pool[deterministicIndex])
			end
			playerDeterministicQueues[player.UserId] = queue
		end

		for _ = 1, openCount do
			if #queue > 0 then
				local item = table.remove(queue, 1) :: EventCrateItem
				table.insert(grantedItems, item)
			else
				table.insert(grantedItems, pool[1])
			end
		end
	else
		for _ = 1, openCount do
			local roll = math.random() * 100
			local cumulative = 0
			local selected = pool[1]
			for _, item in pool do
				cumulative += item.probabilityPercent
				if roll <= cumulative then
					selected = item
					break
				end
			end
			table.insert(grantedItems, selected)
		end
	end

	local inventory = playerInventories[player.UserId] or {}
	playerInventories[player.UserId] = inventory

	for _, item in grantedItems do
		local petUuid = HttpService:GenerateGUID(false)
		local pet: SlimePetInstance = {
			uuid = petUuid,
			slimeId = item.slimeId,
			level = 1,
			experience = 0,
			stars = 1,
			raceId = "RACE-01",
			armorId = nil,
			auraId = nil,
			mutations = if item.guaranteedMutationId then { item.guaranteedMutationId } else {},
			currentHP = 150,
			maxHP = 150,
			cooldownUntilOsTime = 0,
			acquisitionPath = "Event_Crate",
			capturedBiome = 1,
		}
		inventory[petUuid] = pet
	end

	remotes.CrateRevealAnim:FireClient(player, grantedItems, openCount > 1)
	return {
		success = true,
		items = grantedItems,
		usedDeterministicQueue = usedDeterministic,
	}
end

--[[
	5. Captura Dinámica en Robux y Salto de Tiempo:
	- 1x/día Captura Asegurada Gratuita cada 86400s
	- Cotización dinámica por brecha de bioma (hasta 10,000+ Robux)
	- Salto de tiempo para Cooldowns y Fermentación Offline
]]
function SlimeCoreService.attemptDynamicSlimeCapture(
	player: Player,
	slimeId: string,
	targetBiome: number
): { success: boolean, quote: DynamicCaptureQuote, pet: SlimePetInstance?, promptedProduct: boolean }
	local slimeDef = SlimeCatalogs.SLIMES_BY_ID[slimeId]
	local isUltra = if slimeDef then slimeDef.isUltraSpecial else false
	local isTitanic = if slimeDef then (slimeDef.ultraClass == "TITANIC") else false

	local playerMaxBiome = (player:GetAttribute("MaxUnlockedBiome") :: number?) or 1
	local lastDaily = playerDailyFreeCaptureTime[player.UserId] or 0

	local quote = SlimeCoreMath.computeDynamicCaptureQuote(
		playerMaxBiome,
		targetBiome,
		isUltra,
		isTitanic,
		lastDaily,
		os.time()
	)

	if quote.isDailyFreeAvailable then
		playerDailyFreeCaptureTime[player.UserId] = os.time()
		local petUuid = HttpService:GenerateGUID(false)
		local pet: SlimePetInstance = {
			uuid = petUuid,
			slimeId = slimeId,
			level = 1,
			experience = 0,
			stars = 1,
			raceId = if slimeDef then slimeDef.raceId else "RACE-01",
			armorId = nil,
			auraId = nil,
			mutations = {},
			currentHP = if slimeDef then slimeDef.baseStabilityHP else 200,
			maxHP = if slimeDef then slimeDef.baseStabilityHP else 200,
			cooldownUntilOsTime = 0,
			acquisitionPath = "Earned_Free" :: Types.AcquisitionPath,
			capturedBiome = targetBiome,
		}

		local inv = playerInventories[player.UserId] or {}
		playerInventories[player.UserId] = inv
		inv[petUuid] = pet

		return { success = true, quote = quote, pet = pet, promptedProduct = false }
	else
		remotes.DynamicCapturePrompt:FireClient(player, quote)
		return { success = false, quote = quote, pet = nil, promptedProduct = true }
	end
end

function SlimeCoreService.skipTimerWithRobux(
	player: Player,
	timerCategory: ("PET_COOLDOWN" | "FERMENTATION_VAT" | "DAILY_CAPTURE_RESET"),
	remainingSeconds: number
): number
	local robuxCost = SlimeCoreMath.computeSkipTimerRobux(remainingSeconds, timerCategory)
	if robuxCost > 0 then
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, 200101)
		end)
	end
	return robuxCost
end

--[[
	6. Comercio Two-Phase Commit con UUID, IsPaidItemTradingAllowed y segregación Earned_Free:
	- Validación de inventario y bloqueo de concurrencia
	- Bounties de 2 ejes y Fermentación Offline
]]
function SlimeCoreService.initiateTwoPhaseTrade(
	playerA: Player,
	playerB: Player,
	petA_UUID: string,
	petB_UUID: string
): { success: boolean, reason: string? }
	local policyAOk, policyA = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(playerA)
	end)
	local policyBOk, policyB = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(playerB)
	end)

	local tradingAllowedA = policyAOk and policyA and (policyA.IsPaidItemTradingAllowed ~= false)
	local tradingAllowedB = policyBOk and policyB and (policyB.IsPaidItemTradingAllowed ~= false)

	local invA = playerInventories[playerA.UserId]
	local invB = playerInventories[playerB.UserId]
	if not invA or not invB then
		return { success = false, reason = "Inventario no disponible" }
	end

	local petA = invA[petA_UUID]
	local petB = invB[petB_UUID]
	if not petA or not petB then
		return { success = false, reason = "Mascota no encontrada" }
	end

	-- Validación de metadatos Earned_Free ante restricción de trading
	if not tradingAllowedA and petA.acquisitionPath ~= ("Earned_Free" :: Types.AcquisitionPath) then
		return { success = false, reason = "Intercambio de items de pago restringido por politica para Jugador A" }
	end
	if not tradingAllowedB and petB.acquisitionPath ~= ("Earned_Free" :: Types.AcquisitionPath) then
		return { success = false, reason = "Intercambio de items de pago restringido por politica para Jugador B" }
	end

	-- Fase 1: Preparación y bloqueo atómico
	if lockedTradeItems[petA_UUID] or lockedTradeItems[petB_UUID] then
		return { success = false, reason = "Item actualmente bloqueado en otra transaccion" }
	end
	lockedTradeItems[petA_UUID] = true
	lockedTradeItems[petB_UUID] = true

	-- Fase 2: Confirmación atómica y desbloqueo
	invA[petA_UUID] = nil
	invB[petB_UUID] = nil
	invA[petB_UUID] = petB
	invB[petA_UUID] = petA

	lockedTradeItems[petA_UUID] = nil
	lockedTradeItems[petB_UUID] = nil

	return { success = true }
end

function SlimeCoreService.getAlchemistBounties(player: Player): {
	{ id: string, targetBiomeMin: number, requiredMutationVector: Types.MutationVectorCategory, rewardCoins: number },
}
	return {
		{ id = "BOUNTY-01", targetBiomeMin = 5, requiredMutationVector = "ECONOMIC", rewardCoins = 5000 },
		{ id = "BOUNTY-02", targetBiomeMin = 12, requiredMutationVector = "ALCHEMICAL_JUICE", rewardCoins = 25000 },
		{ id = "BOUNTY-03", targetBiomeMin = 22, requiredMutationVector = "COMBAT_GUARD", rewardCoins = 100000 },
	}
end

function SlimeCoreService.startOfflineFermentation(player: Player, vatId: number, juiceType: string, amount: number, durationSec: number): boolean
	local dur = math.clamp(durationSec, 3600, 43200)
	local vats = activeFermentations[player.UserId] or {}
	activeFermentations[player.UserId] = vats
	vats[vatId] = {
		vatId = vatId,
		juiceType = juiceType,
		amount = amount,
		startTime = os.time(),
		completeTime = os.time() + dur,
	}
	return true
end

function SlimeCoreService.claimOfflineFermentation(player: Player, vatId: number): { success: boolean, goldenEssencesYield: number }
	local vats = activeFermentations[player.UserId]
	if not vats or not vats[vatId] then
		return { success = false, goldenEssencesYield = 0 }
	end
	local vat = vats[vatId]
	if os.time() < vat.completeTime then
		return { success = false, goldenEssencesYield = 0 }
	end
	vats[vatId] = nil
	local essences = math.max(1, math.floor(vat.amount / 100))
	return { success = true, goldenEssencesYield = essences }
end

--[[
	7. Cross-Server MessagingService Admin Abuse:
	- Emisión y suscripción entre servidores
	- Ejecución de los 5 eventos de LiveOps
]]
function SlimeCoreService.triggerGlobalAdminAbuse(command: Types.AdminAbuseCommand): boolean
	local publishOk = pcall(function()
		MessagingService:PublishAsync("AbyssalAdminAbuseEvents", command)
	end)

	SlimeCoreService.applyLocalAdminAbuse(command)
	return publishOk
end

function SlimeCoreService.applyLocalAdminAbuse(command: Types.AdminAbuseCommand)
	remotes.AdminAbuseBroadcast:FireAllClients(command)

	if command.commandType == "GlobalMutationStorm" then
		for hole in activeHoleInfestations do
			activeHoleInfestations[hole] = os.time() + command.durationSec
		end
	elseif command.commandType == "SpawnAbyssalCannon" then
		local amphitheater = Workspace:FindFirstChild("AbyssalAmphitheater")
		local lobby = if amphitheater then amphitheater:FindFirstChild("CircularLobby") else nil
		if lobby then
			local cannon = Instance.new("Part")
			cannon.Name = "AbyssalLaunchCannon"
			cannon.Size = Vector3.new(10, 16, 10)
			cannon.Position = Vector3.new(30, 608, 0)
			cannon.Anchored = true
			cannon.Material = Enum.Material.Metal
			cannon.Color = Color3.fromRGB(220, 140, 20)
			cannon.Parent = lobby
			task.delay(command.durationSec, function()
				if cannon and cannon.Parent then
					cannon:Destroy()
				end
			end)
		end
	end
end

-- Helpers de estado de jugadores
function SlimeCoreService.getPlayerPets(player: Player): { SlimePetInstance }
	local inv = playerInventories[player.UserId]
	if not inv then
		return {}
	end
	local pets = {}
	for _, pet in inv do
		table.insert(pets, pet)
	end
	return pets
end

function SlimeCoreService.addPendingDorsalSlime(player: Player, slimeId: string, biome: number): SlimePetInstance?
	local tank = playerDorsalTanks[player.UserId]
	if not tank then
		return nil
	end
	local def = SlimeCatalogs.SLIMES_BY_ID[slimeId]
	local pet: SlimePetInstance = {
		uuid = HttpService:GenerateGUID(false),
		slimeId = slimeId,
		level = 1,
		experience = 0,
		stars = 1,
		raceId = if def then def.raceId else "RACE-01",
		armorId = nil,
		auraId = nil,
		mutations = {},
		currentHP = if def then def.baseStabilityHP else 100,
		maxHP = if def then def.baseStabilityHP else 100,
		cooldownUntilOsTime = 0,
		acquisitionPath = "Earned_Free",
		capturedBiome = biome,
	}
	table.insert(tank.pendingSlimes, pet)
	return pet
end

function SlimeCoreService.addUnrefinedJuice(player: Player, amount: number)
	local tank = playerDorsalTanks[player.UserId]
	if tank then
		tank.unrefinedJuice += math.max(0, amount)
	end
end

function SlimeCoreService.getPlayerUnrefinedJuice(player: Player): number
	local tank = playerDorsalTanks[player.UserId]
	return if tank then tank.unrefinedJuice else 0
end

-- Suscripción a eventos globales de MessagingService
task.spawn(function()
	pcall(function()
		MessagingService:SubscribeAsync("AbyssalAdminAbuseEvents", function(message)
			if typeof(message.Data) == "table" then
				SlimeCoreService.applyLocalAdminAbuse(message.Data :: Types.AdminAbuseCommand)
			end
		end)
	end)
end)

Players.PlayerAdded:Connect(function(player: Player)
	playerDorsalTanks[player.UserId] = { unrefinedJuice = 250, pendingSlimes = {} }
	playerInventories[player.UserId] = {}
	playerDailyFreeCaptureTime[player.UserId] = 0
	playerDeterministicQueues[player.UserId] = {}
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerDorsalTanks[player.UserId] = nil
	playerInventories[player.UserId] = nil
	playerDailyFreeCaptureTime[player.UserId] = nil
	playerDeterministicQueues[player.UserId] = nil
	activeFermentations[player.UserId] = nil
end)

return SlimeCoreService
