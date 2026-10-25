--!strict
--[[
	CharacterController.client.luau
	Controlador Táctico de Personaje, Cinemática Procedural (IKControl + Motor6D.Transform + Spring2D),
	Prioridades de Animación (Action4/Action3/Action2), Marcadores (WindupVFX, HitFrame, RecoveryCancel),
	Habilidades Tácticas (Pulso Z, Dash 0.3s i-frames, QTE, Emisor G-20) y Motor VFX
	para Zombie Awareness (v4.0) bajo el estándar RAASE 3.0.
--]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local ZombieCatalogs = require(sharedFolder:WaitForChild("ZombieCatalogs") :: any)
local Janitor = require(sharedFolder:WaitForChild("Janitor") :: any)
local ProceduralAnimator = require(sharedFolder:WaitForChild("ProceduralAnimator") :: any)
local VFXAndJuiceEngine = require(sharedFolder:WaitForChild("VFXAndJuiceEngine") :: any)

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local combatActionRemote = remotesFolder:WaitForChild("ZA_CombatAction") :: RemoteEvent
local tacticalSkillRemote = remotesFolder:WaitForChild("ZA_TacticalSkill") :: RemoteEvent
local vfxReplicateRemote = remotesFolder:WaitForChild("ZA_VFXReplicate") :: UnreliableRemoteEvent

local character: Model? = nil
local rootPart: BasePart? = nil
local waistJoint: Motor6D? = nil
local neckJoint: Motor6D? = nil
local charJanitor = Janitor.new()

-- Oscilador armónico amortiguado 2D (zeta = 0.58) para retroceso balístico e impulso de cámara
local recoilSpring = ProceduralAnimator.CreateSpring2D(28, 0.58, Vector2.zero)

-- Holster Táctico Rápido (Tapón #4 del Gameloop)
local activeQuickSlots = { "G-05", "G-07", "G-09", "G-01", "M-03" }
local currentSlotIndex = 1
local currentWeaponId = activeQuickSlots[1]
local lastFireClock = 0
local lastDashClock = 0
local lastPulseClock = 0
local bufferedNextAttack = false
local inRecoveryWindow = false

local pulseHighlights: { Highlight } = {}

--------------------------------------------------------------------------------
-- 1. ENLACE DE PRIORIDADES DE ANIMACIÓN Y MARCADORES (SECCIÓN 5.2)
--------------------------------------------------------------------------------

local function bindCombatAnimationTrack(
	track: AnimationTrack,
	role: "ActiveAttack" | "HitOrChannel" | "TacticalEvade" | "Locomotion",
	onHitFrameCallback: (() -> ())?
)
	-- Prioridades estrictas según Sección 5.2
	if role == "ActiveAttack" then
		track.Priority = Enum.AnimationPriority.Action4
	elseif role == "HitOrChannel" then
		track.Priority = Enum.AnimationPriority.Action3
	elseif role == "TacticalEvade" then
		track.Priority = Enum.AnimationPriority.Action2
	else
		track.Priority = Enum.AnimationPriority.Movement
	end

	-- Marcador 1: WindupVFX (telegraph de anticipación)
	charJanitor:Add(track:GetMarkerReachedSignal("WindupVFX"):Connect(function()
		if rootPart then
			VFXAndJuiceEngine.CastEffect("DashBurst", rootPart.CFrame, 0.6, {
				PrimaryColor = Color3.fromRGB(255, 190, 60),
				TraumaAmount = 0.08,
			})
		end
	end))

	-- Marcador 2: HitFrame (fotograma exacto de impacto activo)
	charJanitor:Add(track:GetMarkerReachedSignal("HitFrame"):Connect(function()
		if onHitFrameCallback then
			onHitFrameCallback()
		end
	end))

	-- Marcador 3: RecoveryCancel (ventana de fotogramas 8–14 para input buffering)
	charJanitor:Add(track:GetMarkerReachedSignal("RecoveryCancel"):Connect(function()
		inRecoveryWindow = true
		if bufferedNextAttack then
			bufferedNextAttack = false
			track:Stop(0.12)
		end
		task.delay(0.2, function()
			inRecoveryWindow = false
		end)
	end))
end

--------------------------------------------------------------------------------
-- 2. MAPEO DE LOS 9 PRESETS MATEMÁTICOS DE VFX (SECCIÓN 5.3)
--------------------------------------------------------------------------------

local function playPresetVFXAtPosition(presetId: Types.VFXPresetId, worldPos: Vector3)
	local preset = ZombieCatalogs.VFXPresets[presetId]
	if not preset then
		return
	end

	local effectType: Types.VFXEffectType = "HeavyImpact"
	if presetId == "VFX_Melee_Slash_Blood" then
		effectType = "MeleeSlash"
	elseif presetId == "VFX_Rocket_Barrage" or presetId == "VFX_Hulk_Shockwave" then
		effectType = "MagicExplosion"
	elseif presetId == "VFX_Hypnosis_Wave" or presetId == "VFX_Tesla_Arc" then
		effectType = "DashBurst"
	end

	VFXAndJuiceEngine.CastEffect(effectType, CFrame.new(worldPos), math.clamp(preset.sizePeak / 4, 0.6, 2.5), {
		PrimaryColor = preset.colorStart,
		SecondaryColor = preset.colorMid,
		DebrisCount = math.clamp(math.floor(preset.burstCount / 4), 3, 12),
		TraumaAmount = if presetId == "VFX_Rocket_Barrage" or presetId == "VFX_Hulk_Shockwave" then 0.35 else 0.12,
	})
end

vfxReplicateRemote.OnClientEvent:Connect(function(presetId: any, worldPos: any)
	if typeof(presetId) == "string" and typeof(worldPos) == "Vector3" then
		playPresetVFXAtPosition(presetId :: Types.VFXPresetId, worldPos)
	end
end)

--------------------------------------------------------------------------------
-- 3. CICLO DE VIDA DEL PERSONAJE + PROCEDURAL IK (RAASE 3.0)
--------------------------------------------------------------------------------

local function onCharacterAdded(newChar: Model)
	charJanitor:Cleanup()
	character = newChar
	rootPart = newChar:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local upperTorso = newChar:WaitForChild("UpperTorso", 5) :: BasePart?

	if upperTorso then
		waistJoint = upperTorso:WaitForChild("Waist", 5) :: Motor6D?
		neckJoint = upperTorso:WaitForChild("Neck", 5) :: Motor6D?
	end

	-- Adjuntar IKControl anatómico para el jugador local según política dual RAASE 3.0 (<= 12 rigs)
	if rootPart then
		local aimTarget = Instance.new("Attachment")
		aimTarget.Name = "ZA_LocalAimIKTarget"
		aimTarget.Position = Vector3.new(0, 1.5, -8)
		aimTarget.Parent = rootPart
		charJanitor:Add(aimTarget)

		pcall(function()
			local ikCleanup = ProceduralAnimator.AttachIK(newChar, {
				Name = "ZA_RightArmAimIK",
				ControlType = Enum.IKControlType.LookAt,
				ChainRootName = "RightUpperArm",
				EndEffectorName = "RightHand",
				Target = aimTarget,
				SmoothTime = 0.08,
				Weight = 0.65,
				EnableJointLimits = true,
				UpperAngleLimit = 75,
				TwistLowerAngle = -45,
				TwistUpperAngle = 45,
			})
			if ikCleanup then
				charJanitor:Add(ikCleanup)
			end
		end)
	end
end

if localPlayer.Character then
	task.spawn(onCharacterAdded, localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

--------------------------------------------------------------------------------
-- 4. COMBATE EN CLIENTE: DISPARO, PULSO Z, DASH 0.3S, QTE Y EMISOR G-20
--------------------------------------------------------------------------------

local function resolveTargetNPCFromAim(): (Model?, ("Head" | "Torso" | "Legs" | "WeakPoint" | "Back"))
	if not camera or not rootPart then
		return nil, "Torso"
	end

	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = if character then { character } else {}

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 180, rayParams)
	if result and result.Instance then
		local hitPart = result.Instance
		local model = hitPart:FindFirstAncestorOfClass("Model")
		if model and CollectionService:HasTag(model, "ZA_ActiveNPC") then
			local zone: "Head" | "Torso" | "Legs" | "WeakPoint" | "Back" = "Torso"
			if hitPart.Name == "Head" then
				zone = "Head"
			elseif string.find(hitPart.Name, "WeakPoint", 1, true) then
				zone = "WeakPoint"
			elseif string.find(hitPart.Name, "Foot", 1, true) or string.find(hitPart.Name, "Leg", 1, true) then
				zone = "Legs"
			end
			return model, zone
		end
	end

	-- Fallback de asistencia táctica al enemigo más cercano en el cono frontal
	local bestModel: Model? = nil
	local bestDist = 65
	for _, inst in ipairs(CollectionService:GetTagged("ZA_ActiveNPC")) do
		if inst:IsA("Model") and inst.PrimaryPart then
			local d = (inst.PrimaryPart.Position - rootPart.Position).Magnitude
			if d < bestDist then
				bestDist = d
				bestModel = inst
			end
		end
	end
	return bestModel, "Torso"
end

local function fireCurrentWeapon()
	local weaponDef = ZombieCatalogs.Weapons[currentWeaponId]
	if not weaponDef or not rootPart then
		return
	end

	local now = os.clock()
	local minInterval = 1 / math.max(0.5, weaponDef.fireRatePerSec)
	if (now - lastFireClock) < minInterval then
		if inRecoveryWindow then
			bufferedNextAttack = true
		end
		return
	end
	lastFireClock = now

	-- Impulso en el oscilador armónico Spring2D para retroceso de cámara/retícula
	recoilSpring:Impulse(Vector2.new(math.random(-8, 8), 22))

	local targetModel, hitZone = resolveTargetNPCFromAim()
	if targetModel then
		local npcId = targetModel:GetAttribute("ZA_InstanceId")
		if typeof(npcId) == "string" then
			combatActionRemote:FireServer("AttackNPC", currentWeaponId, npcId, hitZone)
			VFXAndJuiceEngine.TriggerHitFlash(targetModel, 0.12)
			if weaponDef.family == "Melee" and character then
				VFXAndJuiceEngine.ApplyHitstop(character, 3)
			end
		end
	else
		playPresetVFXAtPosition(weaponDef.vfxPreset, rootPart.Position + rootPart.CFrame.LookVector * 4)
	end
end

local function activateConsciousnessPulse()
	local now = os.clock()
	if (now - lastPulseClock) < 10.0 then
		return
	end
	lastPulseClock = now
	tacticalSkillRemote:FireServer("Pulse")

	for _, h in ipairs(pulseHighlights) do
		if h and h.Parent then
			h:Destroy()
		end
	end
	table.clear(pulseHighlights)

	for _, inst in ipairs(CollectionService:GetTagged("ZA_ActiveNPC")) do
		if inst:IsA("Model") then
			local faction = inst:GetAttribute("ZA_Faction")
			local hl = Instance.new("Highlight")
			hl.Name = "ZA_ConsciousnessPulseHighlight"
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.FillTransparency = 0.45
			hl.OutlineTransparency = 0.0
			if faction == "Human" then
				hl.FillColor = Color3.fromRGB(40, 180, 255)
				hl.OutlineColor = Color3.fromRGB(160, 235, 255)
			elseif faction == "Mutant" then
				hl.FillColor = Color3.fromRGB(255, 130, 30)
				hl.OutlineColor = Color3.fromRGB(255, 200, 60)
			else
				hl.FillColor = Color3.fromRGB(255, 45, 65)
				hl.OutlineColor = Color3.fromRGB(255, 120, 120)
			end
			hl.Parent = inst
			table.insert(pulseHighlights, hl)
		end
	end

	task.delay(6.0, function()
		for _, h in ipairs(pulseHighlights) do
			if h and h.Parent then
				h:Destroy()
			end
		end
		table.clear(pulseHighlights)
	end)
end

local function activateTacticalDash()
	local now = os.clock()
	if (now - lastDashClock) < 2.2 or not rootPart or not character then
		return
	end
	lastDashClock = now
	tacticalSkillRemote:FireServer("Dash")

	local dashDir = rootPart.CFrame.LookVector
	rootPart.AssemblyLinearVelocity = dashDir * 55 + Vector3.new(0, 8, 0)
	VFXAndJuiceEngine.CastEffect("DashBurst", rootPart.CFrame, 1.0, {
		PrimaryColor = Color3.fromRGB(80, 220, 255),
		TraumaAmount = 0.15,
	})
end

local function channelConsciousnessEmitterG20()
	local targetModel = resolveTargetNPCFromAim()
	if not targetModel then
		return
	end
	local npcId = targetModel:GetAttribute("ZA_InstanceId")
	if typeof(npcId) ~= "string" then
		return
	end

	combatActionRemote:FireServer("G20Start", npcId)
	task.delay(2.05, function()
		combatActionRemote:FireServer("G20Complete", npcId)
	end)
end

--------------------------------------------------------------------------------
-- 5. BINDINGS DE ENTRADA (PC, CONSOLA Y MÓVIL)
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		fireCurrentWeapon()
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY then
		currentSlotIndex = (currentSlotIndex % #activeQuickSlots) + 1
		currentWeaponId = activeQuickSlots[currentSlotIndex]
		localPlayer:SetAttribute("ZA_ActiveWeaponId", currentWeaponId)
	elseif input.KeyCode == Enum.KeyCode.Z or input.KeyCode == Enum.KeyCode.DPadUp then
		activateConsciousnessPulse()
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonB then
		activateTacticalDash()
	elseif input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonL1 then
		channelConsciousnessEmitterG20()
	elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
		local targetModel = resolveTargetNPCFromAim()
		if targetModel then
			local npcId = targetModel:GetAttribute("ZA_InstanceId")
			if typeof(npcId) == "string" then
				tacticalSkillRemote:FireServer("QTE", npcId)
			end
		end
		local prevWeapon = currentWeaponId
		currentWeaponId = "M-03"
		fireCurrentWeapon()
		currentWeaponId = prevWeapon
	elseif input.KeyCode == Enum.KeyCode.E then
		combatActionRemote:FireServer("ExtractVault")
	end
end)

localPlayer:SetAttribute("ZA_ActiveWeaponId", currentWeaponId)
local _ = bindCombatAnimationTrack

--------------------------------------------------------------------------------
-- 6. RENDERSTEPPED: APUNTADO MOTOR6D.TRANSFORM + RETROCESO SPRING2D
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt: number)
	if not character or not rootPart or not camera then
		return
	end

	local springOffset = recoilSpring:Step(dt)

	local worldLookDirection: Vector3
	if UserInputService.MouseEnabled then
		local mousePos = UserInputService:GetMouseLocation()
		local unitRay = camera:ViewportPointToRay(mousePos.X + springOffset.X, mousePos.Y - springOffset.Y)
		worldLookDirection = unitRay.Direction
	else
		worldLookDirection = camera.CFrame.LookVector
	end

	local localLook = rootPart.CFrame:VectorToObjectSpace(worldLookDirection)
	local pitch = math.asin(math.clamp(localLook.Y, -1, 1))
	local yaw = math.atan2(-localLook.X, -localLook.Z)

	if waistJoint and waistJoint.Parent then
		local clampedPitch = math.clamp(pitch * 0.5, -math.rad(30), math.rad(30))
		local clampedYaw = math.clamp(yaw * 0.5, -math.rad(45), math.rad(45))
		local currentPos = waistJoint.Transform.Position
		waistJoint.Transform = CFrame.new(currentPos) * CFrame.Angles(-clampedPitch, clampedYaw, 0)
	end

	if neckJoint and neckJoint.Parent then
		local clampedPitch = math.clamp(pitch * 0.5, -math.rad(45), math.rad(45))
		local clampedYaw = math.clamp(yaw * 0.5, -math.rad(60), math.rad(60))
		local currentPos = neckJoint.Transform.Position
		neckJoint.Transform = CFrame.new(currentPos) * CFrame.Angles(-clampedPitch, clampedYaw, 0)
	end
end)
