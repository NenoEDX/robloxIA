--!strict
-- impact_sequencer.luau — Plantilla de referencia RAASE 2.1 (roblox-37-vfx-combat-pipeline)
-- Secuenciador de impacto con hitstop, camera juice, flash aditivo e impact frame.
-- Uso CLIENT-SIDE (los efectos son cosméticos; el daño lo confirma el servidor).
--
-- Disparo recomendado: desde el marcador de la animación (sincronía real):
--   local track = animator:LoadAnimation(attackAnim)
--   track:GetMarkerReachedSignal("Hit"):Connect(function()
--       Sequencer.play({ position = hitCFrame, ... })
--   end)
--
-- Notas de diseño (v1 — correcciones post-Judgment Day):
--   * Hitstop con guard anti re-entrada y restauración exacta (snapshot único).
--   * FOV: captura el valor actual y lo restaura (no hardcodea 70).
--   * Shake: aplica/quita offset por frame — sin acumulación ni drift.
--   * Impact frames: rate-limit 1/s + ScreenGui dedicado (DisplayOrder alto).
--   * Pools ligeros internos (sin dependencia de PartCache); a escala, migrar a PartCache (roblox-08).
--   * Assets (flipbook, mesh, sonido, impact frame) se generan/importan vía roblox-36-asset-pipeline.
--
-- CONTRATOS:
--   * Colocación: StarterPlayerScripts (UNA instancia por cliente). En StarterCharacterScripts
--     se duplicaría el estado por respawn (GUI/rigs/pools).
--   * Shake: asume que el CFrame base de la cámara se reescribe cada frame por el módulo de
--     cámara default (o tu cámara propia) ANTES de nuestra prioridad (Camera + 1). Con
--     CameraType.Scriptable que no refresca base cada frame, no usar el shake sin adaptarlo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

export type ImpactConfig = {
	hitstopFrames: number?,
	fovPunch: number?,
	shake: string?,
	impactFrame: string?,
	flipbook: string?,
	flipbookFrames: number?, -- 4 | 16 | 64 → Grid2x2/Grid4x4/Grid8x8 (default 16)
	meshFlash: string?,
	sound: string?,
	position: CFrame,
}

local Sequencer = {}

local FRAME_TIME = 1 / 60

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
	tracks: { [AnimationTrack]: number },
} = { tracks = {} }

local function applyHitstop(character: Model?, frames: number)
	if not character or frames <= 0 or hitstopActive then
		return -- un hitstop ya en curso: se ignora el solapado (evita el brick de doble restore)
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
		-- JumpHeight mode: JumpPower está deprecado; solo deshabilitar si estaba habilitado.
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
		-- Guard: solo abortar si el humanoid ya no existe o murió (un re-parent vivo SÍ se restaura).
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
-- FOV punch (captura y restaura el FOV real de la cámara)
--------------------------------------------------------------------------------

local fovToken = 0
local activeFovTweens: { Tween } = {}

local function cancelActiveFovTweens()
	for _, t in activeFovTweens do
		t:Cancel() -- Cancel NO restaura valores; el token evita que callbacks viejos actúen
	end
	table.clear(activeFovTweens)
end

local function punchFov(degrees: number)
	local cam = workspace.CurrentCamera
	if not cam or degrees <= 0 then
		return
	end
	cancelActiveFovTweens()
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
		-- Completed también dispara en Cancel: el token decide si esta pasada sigue vigente.
		if token ~= fovToken then
			return
		end
		table.clear(activeFovTweens)
		if cam.Parent == nil then
			return -- cámara destruida: nada que restaurar
		end
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
-- Camera shake (offset por frame: aplica y quita — sin acumulación)
--------------------------------------------------------------------------------

local SHAKE_PROFILES: { [string]: { amplitude: number, duration: number } } = {
	light = { amplitude = 0.08, duration = 0.12 },
	heavy = { amplitude = 0.22, duration = 0.2 },
	ultimate = { amplitude = 0.45, duration = 0.35 },
}

local SHAKE_BINDING_NAME = "RAASE_ImpactShake"
local shakeToken = 0

local function shake(profile: string)
	local cfg = SHAKE_PROFILES[profile]
	if not cfg then
		return
	end
	-- Nueva pasada reemplaza la anterior (mismo binding) y el token invalida callbacks viejos.
	shakeToken += 1
	local token = shakeToken

	local elapsed = 0
	local seed = os.clock() * 1000

	RunService:BindToRenderStep(SHAKE_BINDING_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
		if token ~= shakeToken then
			return
		end
		local cam = workspace.CurrentCamera
		elapsed += dt
		if not cam or elapsed >= cfg.duration then
			RunService:UnbindFromRenderStep(SHAKE_BINDING_NAME)
			return
		end
		local decay = 1 - (elapsed / cfg.duration)
		local amp = cfg.amplitude * decay
		-- Corremos DESPUÉS del update de cámara (Camera + 1): la base es fresca cada frame,
		-- por eso aplicamos el offset sin acumulación. Ver CONTRATOS en el encabezado.
		cam.CFrame = cam.CFrame * CFrame.Angles(
			math.noise(seed, elapsed * 40) * amp,
			math.noise(seed + 100, elapsed * 40) * amp,
			0
		)
	end)
end

--------------------------------------------------------------------------------
-- Mesh flash (pool ligero por asset: reutiliza una parte por meshId)
--------------------------------------------------------------------------------

local flashPool: { [string]: Part } = {}
local flashTokens: { [string]: number } = {}

local function spawnMeshFlash(meshId: string?, at: CFrame)
	if not meshId or meshId == "" then
		return
	end
	local part = flashPool[meshId]
	if part and part.Parent == nil then
		part = nil
	end
	if not part then
		part = Instance.new("Part")
		part.Name = "RAASE_MeshFlash"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Size = Vector3.new(3, 3, 0.2)

		local special = Instance.new("SpecialMesh")
		special.MeshType = Enum.MeshType.FileMesh
		special.MeshId = meshId
		special.Scale = Vector3.new(1, 1, 1)
		special.Parent = part
		part.Parent = workspace
		flashPool[meshId] = part
	end
	-- El caller debe pasar un CFrame orientado (lookAt) para slashes direccionales.
	flashTokens[meshId] = (flashTokens[meshId] or 0) + 1
	local token = flashTokens[meshId]
	part.CFrame = at
	part.Transparency = 0
	task.delay(0.08, function()
		-- Token: un reuso posterior del pool no debe ocultar el flash más nuevo.
		if part ~= nil and flashTokens[meshId] == token then
			part.Transparency = 1
		end
	end)
end

--------------------------------------------------------------------------------
-- Impact frame (ScreenGui dedicado + rate-limit 1/s + reuso de label)
--------------------------------------------------------------------------------

local impactGui: ScreenGui? = nil
local lastImpactFrameAt = 0
local impactLabelToken = 0

local function flashImpactFrame(imageId: string?, parentPlayerGui: Instance?)
	if not imageId or imageId == "" or not parentPlayerGui then
		return
	end
	local now = os.clock()
	if now - lastImpactFrameAt < 1 then
		return -- presupuesto: máximo 1 impact frame por segundo
	end
	lastImpactFrameAt = now

	if not impactGui or impactGui.Parent == nil then
		local gui = Instance.new("ScreenGui")
		gui.Name = "RAASE_ImpactFrames"
		gui.DisplayOrder = 1000
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		local label = Instance.new("ImageLabel")
		label.Name = "ImpactFrame"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.ZIndex = 100
		label.Visible = false
		label.Parent = gui

		gui.Parent = parentPlayerGui
		impactGui = gui
	end

	local label = impactGui:FindFirstChild("ImpactFrame") :: ImageLabel?
	if not label then
		return
	end
	-- Nota: GUI de Roblox no tiene blend aditivo nativo; se simula con transparencia.
	impactLabelToken += 1
	local token = impactLabelToken
	label.Image = imageId
	label.ImageTransparency = 0.2
	label.Visible = true
	task.delay(FRAME_TIME * 2, function()
		-- Token: no ocultar una pasada más nueva.
		if label ~= nil and impactLabelToken == token then
			label.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
-- Sonido (pool round-robin de 4 con attachment persistente)
--------------------------------------------------------------------------------

local soundPool: { Sound } = {}
local soundIndex = 0
local soundRig: Attachment? = nil

local function playSound(soundId: string?, at: CFrame)
	if not soundId or soundId == "" then
		return
	end
	if not soundRig or soundRig.Parent == nil then
		local attachment = Instance.new("Attachment")
		attachment.Name = "RAASE_ImpactSoundRig"
		attachment.Parent = workspace.Terrain
		soundRig = attachment
		-- Rig nuevo ⇒ pool viejo quedó huérfano: reconstruir.
		soundPool = {}
		soundIndex = 0
	end
	if #soundPool == 0 then
		for _ = 1, 4 do
			local s = Instance.new("Sound")
			s.RollOffMaxDistance = 80
			s.Parent = soundRig
			table.insert(soundPool, s)
		end
	end
	soundIndex = (soundIndex % #soundPool) + 1
	local sound = soundPool[soundIndex]
	if not sound then
		return
	end
	sound.SoundId = soundId
	soundRig.WorldPosition = at.Position
	sound:Play()
end

--------------------------------------------------------------------------------
-- Flipbook (emisor reutilizado por asset; Lifetime calculado para el sheet completo)
--------------------------------------------------------------------------------

local FLIPBOOK_LAYOUTS: { [number]: Enum.ParticleFlipbookLayout } = {
	[4] = Enum.ParticleFlipbookLayout.Grid2x2,
	[16] = Enum.ParticleFlipbookLayout.Grid4x4,
	[64] = Enum.ParticleFlipbookLayout.Grid8x8,
}

local flipbookPool: { [string]: ParticleEmitter } = {}

local function playFlipbook(flipbookId: string?, frames: number?, at: CFrame)
	local frameCount = frames or 16
	local layout = FLIPBOOK_LAYOUTS[frameCount]
	if not flipbookId or flipbookId == "" or not layout then
		return
	end
	local key = flipbookId .. "#" .. tostring(frameCount)
	local emitter = flipbookPool[key]
	if emitter and emitter.Parent == nil then
		emitter = nil
	end
	if not emitter then
		local host = Instance.new("Part")
		host.Name = "RAASE_FlipbookHost"
		host.Anchored = true
		host.CanCollide = false
		host.CanQuery = false
		host.CanTouch = false
		host.Transparency = 1
		host.Parent = workspace

		local particle = Instance.new("ParticleEmitter")
		particle.Texture = flipbookId
		particle.FlipbookLayout = layout
		particle.FlipbookFramerate = NumberRange.new(24, 30)
		particle.FlipbookStartRandom = false
		particle.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		particle.Speed = NumberRange.new(0)
		particle.Rate = 0
		-- Lifetime DEBE cubrir el sheet completo: frames/24fps + margen
		-- (16 frames ≈ 0.72 s; 64 frames ≈ 2.72 s). Un lifetime menor trunca la animación.
		particle.Lifetime = NumberRange.new((frameCount / 24) + 0.05)
		particle.Parent = host
		flipbookPool[key] = particle
		emitter = particle
	end
	local host = emitter.Parent :: BasePart?
	if host then
		host.CFrame = at
	end
	emitter:Emit(1)
end

--------------------------------------------------------------------------------
-- API pública
--------------------------------------------------------------------------------

-- play(): orquesta el impacto completo. Llamar SOLO tras confirmación de daño
-- del servidor (o desde el marcador "Hit" de la animación en el cliente).
function Sequencer.play(config: ImpactConfig)
	local character = player.Character
	local playerGui = player:FindFirstChildOfClass("PlayerGui")

	applyHitstop(character, config.hitstopFrames or 0)
	punchFov(config.fovPunch or 0)
	shake(config.shake or "light")
	spawnMeshFlash(config.meshFlash, config.position)
	flashImpactFrame(config.impactFrame, playerGui)
	playSound(config.sound, config.position)
	playFlipbook(config.flipbook, config.flipbookFrames, config.position)
end

return Sequencer
