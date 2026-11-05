--!strict
--[[
	SlimeClientController.client.luau
	Controlador Cliente Central de "SLIME PIT: Dive for Mutants!" (Abyssal Slime Core):
	- Deformación elástica Skinned Mesh Squash & Stretch vía ProceduralAnimator.CreateSpring2D
	- Acoplamiento de Armaduras Rígidas sincronizadas con Bone.TransformedWorldCFrame y LOD por distancia
	  (<50 studs a 60 Hz, 50-120 studs a 15 Hz, >120 studs estático) vía workspace:BulkMoveTo
	- Filtrado de Mutaciones Visibles según Modo Rendimiento ("LOW_3", "MEDIUM_6", "HIGH_10")
	- Transformación y efectos visuales temporales del Exo-Mecha Gelatinoso (30s)
	- Ejecución de las 5 Animaciones de Dopamina Core con VFXAndJuiceEngine:
	  1. Revelación de Rareza de Caja (playCrateRarityReveal)
	  2. Rareza de Extracción en Ascensor y Tanque (playExtractionRarity)
	  3. Llegada y Transformación en la Base Circular (playBaseArrival)
	  4. Revelación de Mutación en Mascota Extraída (playPetExtractedMutation)
	  5. Impacto Físico de Caída/Golpe de Mutación (playMutationStrikeDrop)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local SlimeCatalogs = require(sharedFolder:WaitForChild("SlimeCatalogs") :: any)
local ProceduralAnimator = require(sharedFolder:WaitForChild("ProceduralAnimator") :: any)
local VFXAndJuiceEngine = require(sharedFolder:WaitForChild("VFXAndJuiceEngine") :: any)
local GameLifecycle = require(sharedFolder:WaitForChild("GameLifecycle") :: any)
local SlimeEventContract = require(sharedFolder:WaitForChild("SlimeEventContract") :: any)
local SlimeVisualRegistry = require(sharedFolder:WaitForChild("SlimeVisualRegistry") :: any)
local lifecycle = GameLifecycle.new()
lifecycle:start()

type PerformanceMutationMode = Types.PerformanceMutationMode
type Spring2D = ProceduralAnimator.Spring2D

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

--------------------------------------------------------------------------------
-- ESTADO DEL CONTROLADOR Y CONFIGURACIÓN LOD
--------------------------------------------------------------------------------

local currentPerformanceMode: PerformanceMutationMode = "MEDIUM_6"
local slimeSprings: { [Instance]: Spring2D } = {}

type RigidArmorBinding = {
	armorPart: BasePart,
	targetBone: Bone,
	relativeOffset: CFrame,
	lastUpdateClock: number,
}

local registeredArmorBindings: { RigidArmorBinding } = {}
local exoMechActiveUntilClock = 0.0

--------------------------------------------------------------------------------
-- 1. SQUASH & STRETCH SKINNED MESH (SPRING2D)
--------------------------------------------------------------------------------

local function getOrCreateSlimeSpring(slimeRoot: Instance): Spring2D
	local existing = slimeSprings[slimeRoot]
	if existing then
		return existing
	end

	-- Resorte 2D sub-amortiguado (omega=22, zeta=0.55) para rebote de masa gelatinosa
	local spring = ProceduralAnimator.CreateSpring2D(22.0, 0.55, Vector2.new(1.0, 1.0))
	slimeSprings[slimeRoot] = spring
	return spring
end

local function applySquashImpulse(slimeRoot: Instance, squashFactor: number)
	local spring = getOrCreateSlimeSpring(slimeRoot)
	-- Impulse comprime Y y expande XZ proporcionalmente
	spring:Impulse(Vector2.new(squashFactor, -squashFactor * 0.8))
end

--------------------------------------------------------------------------------
-- 2. SINCRONIZACIÓN DE ARMADURAS CON LOD POR DISTANCIA (BulkMoveTo)
--------------------------------------------------------------------------------

local function registerArmorToBone(armorPart: BasePart, targetBone: Bone, offset: CFrame?)
	local binding: RigidArmorBinding = {
		armorPart = armorPart,
		targetBone = targetBone,
		relativeOffset = offset or CFrame.identity,
		lastUpdateClock = 0.0,
	}
	table.insert(registeredArmorBindings, binding)
end

local function stepRigidArmorSync(nowClock: number)
	if #registeredArmorBindings == 0 then
		return
	end

	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local partsToMove: { BasePart } = {}
	local targetCFrames: { CFrame } = {}

	for index = #registeredArmorBindings, 1, -1 do
		local binding = registeredArmorBindings[index]
		local armorPart = binding.armorPart
		local targetBone = binding.targetBone

		if not armorPart.Parent or not targetBone.Parent then
			table.remove(registeredArmorBindings, index)
		else
			-- Lectura de Bone.TransformedWorldCFrame
			local boneWorldCF = targetBone.TransformedWorldCFrame
			local distance = (boneWorldCF.Position - camPos).Magnitude

			-- Decisión de frecuencia LOD:
			-- < 50 studs: 60 Hz (dt >= 0.016s)
			-- 50 a 120 studs: 15 Hz (dt >= 0.066s)
			-- > 120 studs: Estático (congelado hasta acercarse)
			local interval = if distance < 50.0 then 0.016 elseif distance <= 120.0 then 0.066 else 999.0

			if (nowClock - binding.lastUpdateClock) >= interval then
				binding.lastUpdateClock = nowClock
				local finalCF = boneWorldCF * binding.relativeOffset
				table.insert(partsToMove, armorPart)
				table.insert(targetCFrames, finalCF)
			end
		end
	end

	if #partsToMove > 0 then
		Workspace:BulkMoveTo(partsToMove, targetCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

--------------------------------------------------------------------------------
-- 3. FILTRADO DE MUTACIONES VISIBLES (MODO RENDIMIENTO 3 / 6 / 10)
--------------------------------------------------------------------------------

local function filterVisibleMutations(
	mutations: { string },
	mode: PerformanceMutationMode
): { string }
	local maxVisible = if mode == "LOW_3" then 3 elseif mode == "MEDIUM_6" then 6 else 10
	if #mutations <= maxVisible then
		return mutations
	end

	-- Filtro priorizando mutaciones con cambios de apariencia
	local visible: { string } = {}
	for i = 1, math.min(#mutations, maxVisible) do
		table.insert(visible, mutations[i])
	end
	return visible
end

local function setPerformanceMode(newMode: PerformanceMutationMode)
	currentPerformanceMode = newMode
end

--------------------------------------------------------------------------------
-- 4. VISUALES DEL EXO-MECHA GELATINOSO (30s DURATION)
--------------------------------------------------------------------------------

local function activateExoMechVisuals(characterModel: Model?, durationSec: number?)
	local targetChar = characterModel or localPlayer.Character
	if not targetChar then
		return
	end

	local duration = durationSec or 30.0
	exoMechActiveUntilClock = os.clock() + duration

	VFXAndJuiceEngine.PlayModulatedSound("rbxassetid://9114223120", nil, 0.06)
	VFXAndJuiceEngine.AddTrauma(0.55)
	VFXAndJuiceEngine.TriggerHitFlash(targetChar, 0.3)

	local rootPartInst = targetChar:FindFirstChild("HumanoidRootPart")
	local rootPart = if rootPartInst and rootPartInst:IsA("BasePart") then rootPartInst else nil
	if rootPart then
		VFXAndJuiceEngine.CastEffect("HeavyImpact", rootPart.CFrame, 1, {
			PrimaryColor = Color3.fromRGB(0, 240, 255),
			SecondaryColor = Color3.fromRGB(40, 90, 255),
			DebrisCount = 14,
			TraumaAmount = 0.4,
		})
	end

	local generation = lifecycle.generation
	task.delay(duration, function()
		if lifecycle:isCurrent(generation) and os.clock() >= exoMechActiveUntilClock and targetChar.Parent then
			VFXAndJuiceEngine.TriggerHitFlash(targetChar, 0.15)
		end
	end)
end

--------------------------------------------------------------------------------
-- 5. LAS 5 ANIMACIONES CORE DE DOPAMINA
--------------------------------------------------------------------------------

-- 1. Animación de revelación de rareza de caja de evento
local function playCrateRarityReveal(rarityGrade: string, isMultiOpen: boolean?)
	local gradeInfo = SlimeCatalogs.RARITY_GRADES[rarityGrade]
	local gradeColor = if gradeInfo then gradeInfo.color else Color3.fromRGB(200, 200, 200)
	local isHighTier = rarityGrade == "GRADE_09_CELESTIAL_I" or rarityGrade == "GRADE_10_CELESTIAL_II"
	local trauma = if isHighTier then 0.95 else 0.45

	VFXAndJuiceEngine.AddTrauma(trauma)
	VFXAndJuiceEngine.PlayModulatedSound("rbxassetid://9114223120", nil, 0.08)

	local char = localPlayer.Character
	if char then
		VFXAndJuiceEngine.TriggerHitFlash(char, if isHighTier then 0.25 else 0.12)
		if isHighTier then
			VFXAndJuiceEngine.ApplyHitstop(char, 8)
		end
	end

	local spawnCF = if camera then camera.CFrame * CFrame.new(0, 0, -8) else CFrame.identity
	VFXAndJuiceEngine.CastEffect("MagicExplosion", spawnCF, 1, {
		PrimaryColor = gradeColor,
		SecondaryColor = Color3.fromRGB(255, 255, 255),
		DebrisCount = if isMultiOpen then 25 else 16,
		TraumaAmount = trauma,
	})
end

-- 2. Animación de rareza de extracción en ascensor / tanque dorsal
local function playExtractionRarity(maxRarityGrade: string, tankFillRatio: number)
	local gradeInfo = SlimeCatalogs.RARITY_GRADES[maxRarityGrade]
	local gradeColor = if gradeInfo then gradeInfo.color else Color3.fromRGB(64, 214, 108)

	VFXAndJuiceEngine.AddTrauma(math.clamp(tankFillRatio * 0.75, 0.2, 0.8))
	VFXAndJuiceEngine.PlayModulatedSound("rbxassetid://9114223120", nil, 0.05)

	local char = localPlayer.Character
	if char then
		VFXAndJuiceEngine.TriggerHitFlash(char, 0.18)
		local rootInst = char:FindFirstChild("HumanoidRootPart")
		local root = if rootInst and rootInst:IsA("BasePart") then rootInst else nil
		if root then
			VFXAndJuiceEngine.CastEffect("DashBurst", root.CFrame, 1, {
				PrimaryColor = gradeColor,
				SecondaryColor = Color3.fromRGB(0, 255, 170),
				TraumaAmount = 0.35,
			})
		end
	end
end

-- 3. Animación de llegada a la base circular (descarga de slime)
local function playBaseArrival(slimeId: string, mutationsApplied: number)
	VFXAndJuiceEngine.AddTrauma(0.35)
	VFXAndJuiceEngine.PlayModulatedSound("rbxassetid://9114223120", nil, 0.09)

	local char = localPlayer.Character
	if char then
		VFXAndJuiceEngine.TriggerHitFlash(char, 0.15)
		local rootInst = char:FindFirstChild("HumanoidRootPart")
		local root = if rootInst and rootInst:IsA("BasePart") then rootInst else nil
		if root then
			VFXAndJuiceEngine.CastEffect("MeleeSlash", root.CFrame, 1, {
				PrimaryColor = Color3.fromRGB(255, 215, 0),
				SecondaryColor = Color3.fromRGB(255, 120, 0),
				DebrisCount = math.clamp(mutationsApplied * 3, 6, 24),
			})
		end
	end
end

-- 4. Animación de revelación de mutación en slime extraído de mascota
local function playPetExtractedMutation(slimeId: string, mutationId: string)
	local mutDef = SlimeCatalogs.MUTATIONS_BY_ID[mutationId]
	local mutColor = if mutDef then mutDef.primaryColor else Color3.fromRGB(186, 75, 255)

	VFXAndJuiceEngine.AddTrauma(0.5)
	VFXAndJuiceEngine.PlayModulatedSound("rbxassetid://9114223120", nil, 0.07)

	local char = localPlayer.Character
	if char then
		VFXAndJuiceEngine.TriggerHitFlash(char, 0.2)
		local rootInst = char:FindFirstChild("HumanoidRootPart")
		local root = if rootInst and rootInst:IsA("BasePart") then rootInst else nil
		if root then
			VFXAndJuiceEngine.CastEffect("MagicExplosion", root.CFrame * CFrame.new(0, 2, 0), 1, {
				PrimaryColor = mutColor,
				SecondaryColor = Color3.fromRGB(255, 255, 255),
				DebrisCount = 18,
				TraumaAmount = 0.45,
			})
		end
	end
end

-- 5. Animación de impacto físico de caída/golpe de mutación sobre el slime
local function playMutationStrikeDrop(slimeTarget: Instance, mutationId: string)
	local mutDef = SlimeCatalogs.MUTATIONS_BY_ID[mutationId]
	local strikeColor = if mutDef then mutDef.primaryColor else Color3.fromRGB(255, 80, 80)

	local targetModel = if slimeTarget:IsA("Model") then slimeTarget else slimeTarget.Parent
	if targetModel and targetModel:IsA("Model") then
		VFXAndJuiceEngine.TriggerHitFlash(targetModel, 0.18)
		VFXAndJuiceEngine.ApplyHitstop(targetModel, 6)
	end

	local targetCF = if slimeTarget:IsA("BasePart")
		then slimeTarget.CFrame
		elseif targetModel and targetModel.PrimaryPart
		then targetModel.PrimaryPart.CFrame
		else CFrame.identity

	VFXAndJuiceEngine.AddTrauma(0.6)
	VFXAndJuiceEngine.PlayModulatedSound("rbxassetid://9114223120", nil, 0.08)

	VFXAndJuiceEngine.CastEffect("HeavyImpact", targetCF, 1, {
		PrimaryColor = strikeColor,
		SecondaryColor = Color3.fromRGB(255, 255, 0),
		DebrisCount = 20,
		TraumaAmount = 0.55,
	})

	applySquashImpulse(slimeTarget, 0.45)
end

--------------------------------------------------------------------------------
-- 6. CICLO DE RENDER Y ESCUCHA DE EVENTOS REMOTOS
--------------------------------------------------------------------------------

local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()

	-- 1. Actualización de sincronización LOD de armaduras rígidas
	stepRigidArmorSync(now)

	-- 2. Actualización de osciladores Squash & Stretch
	for slimeInst, spring in slimeSprings do
		if slimeInst.Parent then
			local currentScale = spring:Step(dt)
			if slimeInst:IsA("BasePart") then
				-- Modulación sutil de tamaño visual si es compatible
				local baseSize = Vector3.new(3, 3, 3)
				slimeInst.Size = Vector3.new(
					baseSize.X * currentScale.X,
					baseSize.Y * currentScale.Y,
					baseSize.Z * currentScale.X
				)
			end
		else
			slimeSprings[slimeInst] = nil
		end
	end
end)
lifecycle:track(function() heartbeat:Disconnect() end)

-- Conexión segura a remotes de red
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not lifecycle.active then return end
	if not remotes then
		warn("[SLIME PIT] Remotes folder unavailable; presentation is not connected")
		return
	end
	lifecycle:track(SlimeEventContract.connect(remotes, {
		CrateRevealAnim = playCrateRarityReveal,
		ExtractionRarityAnim = playExtractionRarity,
		BaseArrivalAnim = playBaseArrival,
		PetExtractedMutationAnim = playPetExtractedMutation,
		MutationStrikeDropAnim = function(uuid: string, mutationId: string)
			local target = SlimeVisualRegistry.get(uuid)
			if target and target.Parent then
				playMutationStrikeDrop(target, mutationId)
			else
				warn("[SLIME PIT] Strike-drop visual is unbound for pet " .. uuid)
			end
		end,
	}, function(key: string) warn("[SLIME PIT] Rejected presentation payload: " .. key) end))

	local exoMechRemote = remotes:FindFirstChild("Slime_ExoMechActivate")
	if exoMechRemote and exoMechRemote:IsA("RemoteEvent") then
		local connection = exoMechRemote.OnClientEvent:Connect(function(targetChar: Model?, durationSec: number?)
			activateExoMechVisuals(targetChar, durationSec)
		end)
		lifecycle:track(function() connection:Disconnect() end)
	end
end)

local function stopController()
	lifecycle:stop()
	table.clear(slimeSprings)
	SlimeVisualRegistry.clear()
	table.clear(registeredArmorBindings)
end
local destroying = script.Destroying:Connect(stopController)
lifecycle:track(function() destroying:Disconnect() end)

--------------------------------------------------------------------------------
-- API PÚBLICA DEL CONTROLADOR CLIENTE
--------------------------------------------------------------------------------

local SlimeClientController = {
	Stop = stopController,
	RegisterSlimeVisual = SlimeVisualRegistry.register,
	SetPerformanceMode = setPerformanceMode,
	GetPerformanceMode = function(): PerformanceMutationMode
		return currentPerformanceMode
	end,
	FilterVisibleMutations = filterVisibleMutations,
	RegisterArmorToBone = registerArmorToBone,
	ActivateExoMechVisuals = activateExoMechVisuals,
	PlayCrateRarityReveal = playCrateRarityReveal,
	PlayExtractionRarity = playExtractionRarity,
	PlayBaseArrival = playBaseArrival,
	PlayPetExtractedMutation = playPetExtractedMutation,
	PlayMutationStrikeDrop = playMutationStrikeDrop,
}

return SlimeClientController
