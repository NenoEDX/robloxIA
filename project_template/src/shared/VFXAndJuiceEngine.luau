--!strict
-- VFXAndJuiceEngine.luau — Módulo Maestro RAASE 3.0
-- Motor unificado de Game Feel ("Juice") y VFX procedural de 5 capas:
--   1. Cámara de Trauma Cúbico (S = T^3 en Enum.RenderPriority.Camera.Value + 1 con ruido Perlin)
--   2. Hit-Flash mediante instancia Highlight blanca (FillTransparency 0.1 -> 1.0 en 0.12s)
--   3. Hitstop / Frame-Freeze seguro ante re-entrada + FOV Punch con restauración por token
--   4. Modulación de pitch de audio (±9%, PlaybackSpeed in [0.91, 1.09]) + Knockback físico
--   5. Composición VFX de 5 Capas (CastEffect):
--        Capa 1: Core Flash (PointLight + destello central de 0.08s)
--        Capa 2: Shockwave Ring (anillo expansivo con TweenService EasingStyle.Quart)
--        Capa 3: Slash Trail / Main Body (Beam con FaceCamera = false y LightEmission = 1)
--        Capa 4: Directional Sparks (ParticleEmitter con VelocityParallel y Squash = -1.5)
--        Capa 5: Voxel Debris Contextual (Raycast al suelo heredando Material y Color exactos)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Types = require(script.Parent.Types)

export type VFXEffectType = Types.VFXEffectType
export type VFXCastOptions = Types.VFXCastOptions

export type ImpactConfig = {
	hitstopFrames: number?,
	fovPunch: number?,
	shake: string?,
	trauma: number?,
	impactFrame: string?,
	flipbook: string?,
	flipbookFrames: number?,
	meshFlash: string?,
	sound: string?,
	targetModel: Model?,
	position: CFrame,
}

local VFXAndJuiceEngine = {}

local FRAME_TIME = 1 / 60
local TRAUMA_BINDING_NAME = "RAASE_CubicTraumaCamera"
local TRAUMA_DECAY_PER_SEC = 1.35
local MAX_ROTATION_RAD = math.rad(6.5)
local MAX_OFFSET_STUDS = 0.85

local currentTrauma = 0.0
local traumaLoopBound = false
local traumaTime = 0.0
local traumaSeed = 1337.0

--[[
	Calcula la intensidad no lineal de sacudida S a partir del nivel de trauma T in [0, 1]
	siguiendo la ley cúbica S = T^3.
]]
function VFXAndJuiceEngine.ComputeTraumaShake(trauma: number): number
	local clamped = math.clamp(trauma, 0.0, 1.0)
	return clamped * clamped * clamped
end

local function ensureTraumaRenderStep()
	if traumaLoopBound or not RunService:IsClient() then
		return
	end
	traumaLoopBound = true
	traumaSeed = os.clock() * 100.0

	RunService:BindToRenderStep(TRAUMA_BINDING_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if currentTrauma <= 0.0001 then
			currentTrauma = 0.0
			traumaLoopBound = false
			RunService:UnbindFromRenderStep(TRAUMA_BINDING_NAME)
			return
		end

		local cam = workspace.CurrentCamera
		traumaTime += dt
		currentTrauma = math.max(0.0, currentTrauma - TRAUMA_DECAY_PER_SEC * dt)
		if not cam then
			return
		end

		local shakeIntensity = VFXAndJuiceEngine.ComputeTraumaShake(currentTrauma)
		local freq = 36.0
		local pitch = math.noise(traumaSeed, traumaTime * freq) * MAX_ROTATION_RAD * shakeIntensity
		local yaw = math.noise(traumaSeed + 101.3, traumaTime * freq) * MAX_ROTATION_RAD * shakeIntensity
		local roll = math.noise(traumaSeed + 202.7, traumaTime * freq) * (MAX_ROTATION_RAD * 0.65) * shakeIntensity

		local offsetX = math.noise(traumaSeed + 303.1, traumaTime * freq) * MAX_OFFSET_STUDS * shakeIntensity
		local offsetY = math.noise(traumaSeed + 404.9, traumaTime * freq) * MAX_OFFSET_STUDS * shakeIntensity

		cam.CFrame = cam.CFrame * CFrame.new(offsetX, offsetY, 0) * CFrame.Angles(pitch, yaw, roll)
	end)
end

--[[
	Inyecta trauma aditivo T in [0, 1] al sistema de cámara cúbica (S = T^3).
]]
function VFXAndJuiceEngine.AddTrauma(amount: number): number
	currentTrauma = math.clamp(currentTrauma + math.max(0, amount), 0.0, 1.0)
	if currentTrauma > 0 then
		ensureTraumaRenderStep()
	end
	return currentTrauma
end

--------------------------------------------------------------------------------
-- Hit-Flash vía instancia Highlight (FillColor blanco, 0.1 -> 1.0 en 0.12s)
--------------------------------------------------------------------------------

local highlightTokens: { [Instance]: number } = {}

function VFXAndJuiceEngine.TriggerHitFlash(targetModel: Instance?, duration: number?)
	if not targetModel then
		return
	end
	local flashDuration = duration or 0.12
	local nextToken = (highlightTokens[targetModel] or 0) + 1
	highlightTokens[targetModel] = nextToken

	local existing = targetModel:FindFirstChild("RAASE_HitFlashHighlight")
	local highlight: Highlight
	if existing and existing:IsA("Highlight") then
		highlight = existing
	else
		highlight = Instance.new("Highlight")
		highlight.Name = "RAASE_HitFlashHighlight"
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Adornee = targetModel
		highlight.Parent = targetModel
	end

	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 0.1
	highlight.Enabled = true

	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(flashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1.0 }
	)
	tween:Play()
	tween.Completed:Once(function()
		if highlightTokens[targetModel] == nextToken and highlight.Parent ~= nil then
			highlight.Enabled = false
		end
	end)
end

--------------------------------------------------------------------------------
-- Hitstop (anti re-entrada, snapshot único, restauración exacta)
--------------------------------------------------------------------------------

local hitstopActive = false
local hitstopSaved: {
	humanoid: Humanoid?,
	character: Model?,
	walkSpeed: number?,
	useJumpPower: boolean?,
	jumpPower: number?,
	jumpingWasEnabled: boolean?,
	tracks: { [AnimationTrack]: number },
} = { tracks = {} }

function VFXAndJuiceEngine.ApplyHitstop(character: Model?, frames: number)
	if not character or frames <= 0 or hitstopActive then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	hitstopActive = true
	hitstopSaved = {
		humanoid = humanoid,
		character = character,
		walkSpeed = humanoid.WalkSpeed,
		useJumpPower = humanoid.UseJumpPower,
		jumpPower = humanoid.JumpPower,
		jumpingWasEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
		tracks = {},
	}

	humanoid.WalkSpeed = 0
	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	elseif hitstopSaved.jumpingWasEnabled then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			hitstopSaved.tracks[track] = track.Speed
			track:AdjustSpeed(0)
		end
	end

	task.delay(frames * FRAME_TIME, function()
		local saved = hitstopSaved
		hitstopActive = false
		hitstopSaved = { tracks = {} }

		local savedHumanoid = saved.humanoid
		if not savedHumanoid or savedHumanoid.Parent == nil or savedHumanoid.Health <= 0 then
			return
		end

		if saved.walkSpeed ~= nil then
			savedHumanoid.WalkSpeed = saved.walkSpeed
		end
		if saved.useJumpPower then
			if saved.jumpPower ~= nil then
				savedHumanoid.JumpPower = saved.jumpPower
			end
		elseif saved.jumpingWasEnabled then
			savedHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
		for track, speed in saved.tracks do
			if track.Parent ~= nil then
				pcall(function()
					track:AdjustSpeed(speed)
				end)
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- FOV Punch
--------------------------------------------------------------------------------

local fovToken = 0
local activeFovTweens: { Tween } = {}

function VFXAndJuiceEngine.PunchFov(degrees: number)
	local cam = workspace.CurrentCamera
	if not cam or degrees <= 0 then
		return
	end
	for _, t in activeFovTweens do
		t:Cancel()
	end
	table.clear(activeFovTweens)

	fovToken += 1
	local token = fovToken
	local originalFov = cam.FieldOfView

	local tweenIn = TweenService:Create(
		cam,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = originalFov + degrees }
	)
	table.insert(activeFovTweens, tweenIn)
	tweenIn:Play()
	tweenIn.Completed:Once(function()
		if token ~= fovToken or cam.Parent == nil then
			return
		end
		table.clear(activeFovTweens)
		local tweenOut = TweenService:Create(
			cam,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = originalFov }
		)
		table.insert(activeFovTweens, tweenOut)
		tweenOut:Play()
	end)
end

--------------------------------------------------------------------------------
-- Audio Pitch Modulation (±9% en [0.91, 1.09]) + Knockback Impulse
--------------------------------------------------------------------------------

local soundPool: { Sound } = {}
local soundIndex = 0
local soundRig: Attachment? = nil

function VFXAndJuiceEngine.PlayModulatedSound(
	soundOrId: Sound | string,
	atPosition: Vector3?,
	pitchVariance: number?,
	knockbackTarget: BasePart?,
	knockbackImpulse: Vector3?
): number
	local variance = math.clamp(pitchVariance or 0.09, 0.0, 0.35)
	local minPitch = 1.0 - variance
	local maxPitch = 1.0 + variance
	local chosenPitch = minPitch + math.random() * (maxPitch - minPitch)

	if typeof(soundOrId) == "Instance" and soundOrId:IsA("Sound") then
		soundOrId.PlaybackSpeed = chosenPitch
		soundOrId:Play()
	elseif typeof(soundOrId) == "string" and soundOrId ~= "" then
		if not soundRig or soundRig.Parent == nil then
			local attachment = Instance.new("Attachment")
			attachment.Name = "RAASE_JuiceSoundRig"
			attachment.Parent = workspace.Terrain
			soundRig = attachment
			soundPool = {}
			soundIndex = 0
		end
		if #soundPool == 0 then
			for _ = 1, 4 do
				local s = Instance.new("Sound")
				s.RollOffMaxDistance = 90
				s.Parent = soundRig
				table.insert(soundPool, s)
			end
		end
		soundIndex = (soundIndex % #soundPool) + 1
		local pooledSound = soundPool[soundIndex]
		if pooledSound and soundRig then
			pooledSound.SoundId = soundOrId
			pooledSound.PlaybackSpeed = chosenPitch
			if atPosition then
				soundRig.WorldPosition = atPosition
			end
			pooledSound:Play()
		end
	end

	if knockbackTarget and knockbackImpulse then
		local root = knockbackTarget.AssemblyRootPart or knockbackTarget
		root:ApplyImpulse(knockbackImpulse)
	end

	return chosenPitch
end

--------------------------------------------------------------------------------
-- 5-Layer Procedural VFX Composition (CastEffect)
--------------------------------------------------------------------------------

local function spawnLayer1CoreFlash(cframe: CFrame, scale: number, primaryColor: Color3)
	local host = Instance.new("Part")
	host.Name = "RAASE_VFX_CoreFlash"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Shape = Enum.PartType.Ball
	host.Material = Enum.Material.Neon
	host.Color = Color3.new(1, 1, 1)
	host.Size = Vector3.one * (1.2 * scale)
	host.CFrame = cframe
	host.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = primaryColor
	light.Brightness = 4.5
	light.Range = 14 * scale
	light.Shadows = false
	light.Parent = host

	local tween = TweenService:Create(
		host,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * (3.6 * scale), Transparency = 1 }
	)
	tween:Play()
	Debris:AddItem(host, 0.1)
end

local function spawnLayer2ShockwaveRing(cframe: CFrame, scale: number, secondaryColor: Color3, meshFlashId: string?)
	local ring = Instance.new("Part")
	ring.Name = "RAASE_VFX_ShockwaveRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = secondaryColor
	ring.Size = Vector3.new(1.5 * scale, 0.25 * scale, 1.5 * scale)
	ring.CFrame = cframe
	ring.Parent = workspace

	if meshFlashId and meshFlashId ~= "" then
		local special = Instance.new("SpecialMesh")
		special.MeshType = Enum.MeshType.FileMesh
		special.MeshId = meshFlashId
		special.Scale = Vector3.one * scale
		special.Parent = ring
	else
		local cylMesh = Instance.new("CylinderMesh")
		cylMesh.Scale = Vector3.new(1, 0.15, 1)
		cylMesh.Parent = ring
	end

	local targetSize = Vector3.new(18 * scale, 0.08 * scale, 18 * scale)
	local tween = TweenService:Create(
		ring,
		TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = targetSize, Transparency = 1.0 }
	)
	tween:Play()
	Debris:AddItem(ring, 0.32)
end

local function spawnLayer3SlashBeam(cframe: CFrame, scale: number, primaryColor: Color3, secondaryColor: Color3)
	local host = Instance.new("Part")
	host.Name = "RAASE_VFX_SlashHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.one
	host.CFrame = cframe
	host.Parent = workspace

	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(-2.2 * scale, 0, -0.8 * scale)
	att0.Parent = host

	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(2.2 * scale, 0, 0.8 * scale)
	att1.Parent = host

	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.FaceCamera = false
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Width0 = 1.6 * scale
	beam.Width1 = 0.2 * scale
	beam.CurveSize0 = 1.8 * scale
	beam.CurveSize1 = -1.8 * scale
	beam.Color = ColorSequence.new(primaryColor, secondaryColor)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	beam.Parent = host

	task.delay(0.14, function()
		if beam.Parent ~= nil then
			beam.Enabled = false
		end
	end)
	Debris:AddItem(host, 0.2)
end

local function spawnLayer4DirectionalSparks(cframe: CFrame, scale: number, primaryColor: Color3)
	local host = Instance.new("Part")
	host.Name = "RAASE_VFX_SparksHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.one * 0.5
	host.CFrame = cframe
	host.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Squash = NumberSequence.new(-1.5)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Drag = 5
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(28 * scale, 52 * scale)
	emitter.Lifetime = NumberRange.new(0.14, 0.26)
	emitter.SpreadAngle = Vector2.new(180, 75)
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), primaryColor)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = host
	emitter:Emit(14)

	Debris:AddItem(host, 0.4)
end

local function spawnLayer5ContextualVoxelDebris(cframe: CFrame, scale: number, debrisCount: number)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	local hit = workspace:Raycast(cframe.Position + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), rayParams)
	local sampledMaterial = Enum.Material.Slate
	local sampledColor = Color3.fromRGB(115, 112, 108)

	if hit and hit.Instance then
		sampledMaterial = hit.Material
		if hit.Instance:IsA("Terrain") then
			local ok, terrainColor = pcall(function()
				return workspace.Terrain:GetMaterialColor(sampledMaterial)
			end)
			if ok and typeof(terrainColor) == "Color3" then
				sampledColor = terrainColor
			end
		elseif hit.Instance:IsA("BasePart") then
			sampledColor = hit.Instance.Color
		end
	end

	local count = math.clamp(debrisCount, 0, 16)
	for i = 1, count do
		local angle = (i / math.max(1, count)) * math.pi * 2 + (math.random() * 0.35)
		local radius = 1.4 * scale
		local offset = Vector3.new(math.cos(angle) * radius, 0.6 * scale, math.sin(angle) * radius)

		local cube = Instance.new("Part")
		cube.Name = "RAASE_VFX_VoxelDebris"
		cube.Anchored = false
		cube.CanCollide = true
		cube.CanQuery = false
		cube.CanTouch = false
		cube.Material = sampledMaterial
		cube.Color = sampledColor
		local side = (0.55 + math.random() * 0.55) * scale
		cube.Size = Vector3.new(side, side, side)
		cube.CFrame = CFrame.new(cframe.Position + offset)
			* CFrame.Angles(math.random() * 3.14, math.random() * 3.14, 0)
		cube.Parent = workspace

		local mass = cube:GetMass()
		local outDir = Vector3.new(math.cos(angle), 1.35 + math.random() * 0.6, math.sin(angle)).Unit
		cube:ApplyImpulse(outDir * (mass * (26 + math.random() * 16) * scale))
		cube:ApplyAngularImpulse(Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12)) * mass)

		task.delay(0.85, function()
			if cube.Parent ~= nil then
				local shrink = TweenService:Create(
					cube,
					TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In),
					{ Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 }
				)
				shrink:Play()
			end
		end)
		Debris:AddItem(cube, 1.3)
	end
end

--[[
	Dispara la composición completa de 5 capas de VFX y Game Feel (Juice) en una sola llamada declarativa.
]]
function VFXAndJuiceEngine.CastEffect(
	effectType: VFXEffectType,
	cframe: CFrame,
	scale: number?,
	options: VFXCastOptions?
)
	local opts: VFXCastOptions = options or {}
	local s = math.max(scale or 1.0, 0.1)

	local defaultPrimary = Color3.fromRGB(255, 200, 90)
	local defaultSecondary = Color3.fromRGB(255, 95, 45)
	if effectType == "MagicExplosion" then
		defaultPrimary = Color3.fromRGB(110, 210, 255)
		defaultSecondary = Color3.fromRGB(65, 95, 255)
	elseif effectType == "DashBurst" then
		defaultPrimary = Color3.fromRGB(220, 245, 255)
		defaultSecondary = Color3.fromRGB(130, 200, 255)
	end

	local primaryColor = opts.PrimaryColor or defaultPrimary
	local secondaryColor = opts.SecondaryColor or defaultSecondary
	local debrisCount = opts.DebrisCount or (if effectType == "HeavyImpact" then 8 else 5)

	-- Capas 1 a 5 de VFX
	spawnLayer1CoreFlash(cframe, s, primaryColor)
	spawnLayer2ShockwaveRing(cframe, s, secondaryColor, opts.MeshFlashId)
	spawnLayer3SlashBeam(cframe, s, primaryColor, secondaryColor)
	spawnLayer4DirectionalSparks(cframe, s, primaryColor)
	spawnLayer5ContextualVoxelDebris(cframe, s, debrisCount)

	-- Capas de Game Feel (Juice)
	local trauma = opts.TraumaAmount or (if effectType == "HeavyImpact" then 0.55 else 0.32)
	VFXAndJuiceEngine.AddTrauma(trauma)

	if opts.FovPunch and opts.FovPunch > 0 then
		VFXAndJuiceEngine.PunchFov(opts.FovPunch)
	end

	if opts.TargetModel then
		VFXAndJuiceEngine.TriggerHitFlash(opts.TargetModel, 0.12)
	end

	local localPlayer = Players.LocalPlayer
	if localPlayer and localPlayer.Character and (opts.HitstopFrames or 0) > 0 then
		VFXAndJuiceEngine.ApplyHitstop(localPlayer.Character, opts.HitstopFrames or 3)
	end

	if opts.SoundId then
		local targetRoot: BasePart? = nil
		if opts.TargetModel and opts.TargetModel.PrimaryPart then
			targetRoot = opts.TargetModel.PrimaryPart
		end
		VFXAndJuiceEngine.PlayModulatedSound(
			opts.SoundId,
			cframe.Position,
			0.09,
			targetRoot,
			opts.KnockbackImpulse
		)
	end
end

--[[
	Compatibilidad directa con Sequencer.play (roblox-37-vfx-combat-pipeline).
]]
function VFXAndJuiceEngine.play(config: ImpactConfig)
	local traumaFromProfile = 0.28
	if config.shake == "heavy" then
		traumaFromProfile = 0.52
	elseif config.shake == "ultimate" then
		traumaFromProfile = 0.82
	end

	VFXAndJuiceEngine.CastEffect("HeavyImpact", config.position, 1.0, {
		HitstopFrames = config.hitstopFrames,
		FovPunch = config.fovPunch,
		TraumaAmount = config.trauma or traumaFromProfile,
		SoundId = config.sound,
		MeshFlashId = config.meshFlash,
		FlipbookId = config.flipbook,
		FlipbookFrames = config.flipbookFrames,
		TargetModel = config.targetModel,
	})
end

return VFXAndJuiceEngine
