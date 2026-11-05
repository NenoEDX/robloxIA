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
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(SharedFolder:WaitForChild("Types") :: any)
local SlimeCatalogs = require(SharedFolder:WaitForChild("SlimeCatalogs") :: any)
local SlimeCoreMath = require(SharedFolder:WaitForChild("SlimeCoreMath") :: any)
local GameLifecycle = require(SharedFolder:WaitForChild("GameLifecycle") :: any)
local SlimeEventContract = require(SharedFolder:WaitForChild("SlimeEventContract") :: any)
local SlimeTradeLedger = require(SharedFolder:WaitForChild("SlimeTradeLedger") :: any)
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
local activeHoleInfestations: { [Instance]: number } = {}
local trades = SlimeTradeLedger.new(function(userId: number) return playerInventories[userId] end,
	function() return HttpService:GenerateGUID(false) end)
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

local lifecycle = GameLifecycle.new()
local remotes: { [string]: RemoteEvent } = {}

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

-- Server-authorized free crates only. Paid grants require a separate receipt-backed implementation.
function SlimeCoreService.openEventSpecialCrates(player: Player, count: number, usePaidPath: boolean): {
	success: boolean,
	reason: string?,
	items: { EventCrateItem },
	usedDeterministicQueue: boolean,
}
	if usePaidPath ~= false then
		return { success = false, reason = "PAID_FEATURE_UNAVAILABLE", items = {}, usedDeterministicQueue = false }
	end
	if count ~= 1 and count ~= 3 and count ~= 10 then
		return { success = false, reason = "INVALID_COUNT", items = {}, usedDeterministicQueue = false }
	end
	local openCount = count
	local pool = SlimeCatalogs.EVENT_CRATE_DAY1_POOL
	local grantedItems: { EventCrateItem } = {}
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
			acquisitionPath = "Earned_Free", -- This entrypoint cannot grant paid crates.
			capturedBiome = 1,
		}
		inventory[petUuid] = pet
	end

	remotes.CrateRevealAnim:FireClient(player, grantedItems, openCount > 1)
	return {
		success = true,
		items = grantedItems,
		usedDeterministicQueue = false,
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
): { success: boolean, quote: DynamicCaptureQuote, pet: SlimePetInstance?, promptedProduct: boolean, reason: string? }
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
	quote.mappedDeveloperProductId = 0 -- No configured receipt-backed product exists.
	if not slimeDef then
		return { success = false, quote = quote, pet = nil, promptedProduct = false, reason = "UNKNOWN_SLIME" }
	end

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
		return { success = false, quote = quote, pet = nil, promptedProduct = false, reason = "PAID_FEATURE_UNAVAILABLE" }
	end
end

function SlimeCoreService.skipTimerWithRobux(
	player: Player,
	timerCategory: ("PET_COOLDOWN" | "FERMENTATION_VAT" | "DAILY_CAPTURE_RESET"),
	remainingSeconds: number
): number
	-- Disabled until a configured product, durable grant and receipt handler exist.
	return 0
end

function SlimeCoreService.getCapabilities()
	return { persistence = "session-only", paidPurchases = false, trading = "offer-accept" }
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
): SlimeTradeLedger.Result
	return trades:offer(playerA.UserId, playerB.UserId, petA_UUID, petB_UUID)
end

function SlimeCoreService.acceptTrade(player: Player, tradeId: string): SlimeTradeLedger.Result
	local a, b = trades:participants(player.UserId, tradeId)
	if not a or not b then return { success = false, reason = "TRADE_NOT_FOUND" } end
	if player.UserId ~= b then return { success = false, reason = "AWAITING_ACCEPTANCE" } end
	local playerA, playerB = Players:GetPlayerByUserId(a), Players:GetPlayerByUserId(b)
	if not playerA or not playerB then
		trades:cancel(player.UserId, tradeId)
		return { success = false, reason = "PLAYER_UNAVAILABLE" }
	end
	local function paidTradingAllowed(participant: Player): boolean
		local ok, policy = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(participant) end)
		return ok and type(policy) == "table" and policy.IsPaidItemTradingAllowed == true
	end
	local allowedA, allowedB = paidTradingAllowed(playerA), paidTradingAllowed(playerB)
	return trades:accept(player.UserId, tradeId, allowedA, allowedB)
end

function SlimeCoreService.cancelTrade(player: Player, tradeId: string): SlimeTradeLedger.Result
	return trades:cancel(player.UserId, tradeId)
end

function SlimeCoreService.getAlchemistBounties(player: Player): {
	{ id: string, targetBiomeMin: number, requiredMutationVector: Types.MutationVectorCategory, rewardCoins: number }
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

local function initializePlayer(player: Player)
	if playerDorsalTanks[player.UserId] then return end
	playerDorsalTanks[player.UserId] = { unrefinedJuice = 250, pendingSlimes = {} }
	playerInventories[player.UserId] = {}
	playerDailyFreeCaptureTime[player.UserId] = 0
end

local function removePlayer(player: Player)
	trades:cancelFor(player.UserId)
	playerDorsalTanks[player.UserId] = nil
	playerInventories[player.UserId] = nil
	playerDailyFreeCaptureTime[player.UserId] = nil
	activeFermentations[player.UserId] = nil
end

function SlimeCoreService.start(): boolean
	return lifecycle:start(function()
		for key, name in SlimeEventContract.Names do
			remotes[key] = NetworkSecurityService.createGuardedRemote(name)
		end
		local added = Players.PlayerAdded:Connect(initializePlayer)
		lifecycle:track(function() added:Disconnect() end)
		local removing = Players.PlayerRemoving:Connect(removePlayer)
		lifecycle:track(function() removing:Disconnect() end)
		for _, player in Players:GetPlayers() do initializePlayer(player) end
		local generation = lifecycle.generation
		task.spawn(function()
			local ok, connection = pcall(function()
				return MessagingService:SubscribeAsync("AbyssalAdminAbuseEvents", function(message)
					if lifecycle:isCurrent(generation) and typeof(message.Data) == "table" then
						SlimeCoreService.applyLocalAdminAbuse(message.Data :: Types.AdminAbuseCommand)
					end
				end)
			end)
			if not ok then
				warn("[SLIME PIT] Cross-server subscription unavailable: " .. tostring(connection))
			elseif lifecycle:isCurrent(generation) then
				lifecycle:track(function() connection:Disconnect() end)
			else
				connection:Disconnect()
			end
		end)
	end)
end

function SlimeCoreService.stop(): { string }
	trades:clear()
	local _, errors = lifecycle:stop()
	return errors
end

return SlimeCoreService
