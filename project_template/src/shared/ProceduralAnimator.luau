--!strict
-- ProceduralAnimator.luau — Módulo Maestro RAASE 3.0
-- Cinemática Inversa (IKControl nativo) con límites anatómicos (BallSocketConstraint / HingeConstraint)
-- para héroes/bosses, oscilador armónico amortiguado 2D (Spring2D, zeta in [0.45, 0.75]) para UI/cámara,
-- y controlador de Flipbooks 2D (ImageRectOffset / ImageRectSize).
--
-- Nota de presupuesto de CPU:
--   * Usar AttachIK (IKControl) para el jugador local, héroes y bosses (<= 12 rigs simultáneos).
--   * Para hordas masivas (> 15 NPCs), mantener el ciclo trigonométrico ligero Motor6D.Transform.

local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)

export type IKRigConfig = Types.IKRigConfig

export type Spring2D = {
	Position: Vector2,
	Velocity: Vector2,
	Target: Vector2,
	Omega0: number,
	Zeta: number,
	SetTarget: (self: Spring2D, newTarget: Vector2) -> (),
	Impulse: (self: Spring2D, velocityDelta: Vector2) -> (),
	Step: (self: Spring2D, dt: number) -> Vector2,
}

export type FlipbookController = {
	ImageLabel: ImageLabel,
	Columns: number,
	Rows: number,
	FrameWidthPx: number,
	FrameHeightPx: number,
	TotalFrames: number,
	Fps: number,
	CurrentFrame: number,
	Playing: boolean,
	Loop: boolean,
	Step: (self: FlipbookController, dt: number) -> (),
	Play: (self: FlipbookController, loop: boolean?) -> (),
	Stop: (self: FlipbookController) -> (),
}

local ProceduralAnimator = {}

local function ensureAttachmentOnPart(part: BasePart, name: string): Attachment
	local existing = part:FindFirstChild(name)
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local att = Instance.new("Attachment")
	att.Name = name
	att.Parent = part
	return att
end

--[[
	Aplica límites articulares anatómicos (BallSocketConstraint / HingeConstraint con LimitsEnabled = true)
	entre ChainRoot y EndEffector para evitar hiper-extensión robótica durante la resolución de IKControl.
]]
function ProceduralAnimator.ApplyAnatomicalLimits(
	chainRoot: BasePart,
	endEffector: BasePart,
	upperAngle: number?,
	twistLower: number?,
	twistUpper: number?
): BallSocketConstraint
	local constraintName = "RAASE_AnatomicalBallSocket_" .. chainRoot.Name .. "_" .. endEffector.Name
	local existing = endEffector:FindFirstChild(constraintName)
	if existing and existing:IsA("BallSocketConstraint") then
		return existing
	end

	local att0 = ensureAttachmentOnPart(chainRoot, "RAASE_IKRootAtt")
	local att1 = ensureAttachmentOnPart(endEffector, "RAASE_IKEffectorAtt")

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = constraintName
	socket.Attachment0 = att0
	socket.Attachment1 = att1
	socket.LimitsEnabled = true
	socket.UpperAngle = math.clamp(upperAngle or 65, 5, 175)
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = math.clamp(twistLower or -45, -175, 0)
	socket.TwistUpperAngle = math.clamp(twistUpper or 45, 0, 175)
	socket.Parent = endEffector

	return socket
end

--[[
	Configura y adjunta una instancia nativa IKControl dentro del Humanoid o AnimationController del personaje.
	Elimina la necesidad de exportar o subir archivos .rbxm de animación por cada interacción contextual
	(apuntar armas, agarrar objetos, plantar pies en pendientes, mirar objetivos).
]]
function ProceduralAnimator.AttachIK(character: Model, config: IKRigConfig): IKControl?
	local controller: Instance? = character:FindFirstChildOfClass("Humanoid")
		or character:FindFirstChildOfClass("AnimationController")
	if not controller then
		return nil
	end

	local chainRootInst = character:FindFirstChild(config.ChainRootName, true)
	local endEffectorInst = character:FindFirstChild(config.EndEffectorName, true)
	if not (chainRootInst and chainRootInst:IsA("BasePart")) then
		return nil
	end
	if not (endEffectorInst and endEffectorInst:IsA("BasePart")) then
		return nil
	end

	local controlName = config.Name or ("RAASE_IK_" .. config.EndEffectorName)
	local existing = controller:FindFirstChild(controlName)
	local ikControl: IKControl
	if existing and existing:IsA("IKControl") then
		ikControl = existing
	else
		ikControl = Instance.new("IKControl")
		ikControl.Name = controlName
	end

	ikControl.Type = config.ControlType or Enum.IKControlType.Transform
	ikControl.ChainRoot = chainRootInst
	ikControl.EndEffector = endEffectorInst
	ikControl.Target = config.Target
	if config.Pole then
		ikControl.Pole = config.Pole
	end
	ikControl.SmoothTime = config.SmoothTime or 0.08
	ikControl.Weight = math.clamp(config.Weight or 1.0, 0, 1)
	ikControl.Enabled = true
	ikControl.Parent = controller

	if config.EnableJointLimits then
		ProceduralAnimator.ApplyAnatomicalLimits(
			chainRootInst,
			endEffectorInst,
			config.UpperAngleLimit,
			config.TwistLowerAngle,
			config.TwistUpperAngle
		)
	end

	return ikControl
end

--[[
	Crea un oscilador armónico amortiguado de segundo orden en 2D:
	  x'' + 2 * zeta * omega0 * x' + (omega0 ^ 2) * (x - x_target) = 0
	Con factor de amortiguamiento zeta acotado por defecto en [0.45, 0.75] (sub-amortiguado)
	para producir rebote elástico orgánico en UI, cursores y cámaras.
]]
function ProceduralAnimator.CreateSpring2D(
	omega0: number?,
	zeta: number?,
	initialPosition: Vector2?
): Spring2D
	local startPos = initialPosition or Vector2.zero
	local clampedZeta = math.clamp(zeta or 0.58, 0.45, 0.75)
	local naturalFreq = math.max(omega0 or 18.0, 0.1)

	local spring: Spring2D = {
		Position = startPos,
		Velocity = Vector2.zero,
		Target = startPos,
		Omega0 = naturalFreq,
		Zeta = clampedZeta,
		SetTarget = function(self: Spring2D, newTarget: Vector2)
			self.Target = newTarget
		end,
		Impulse = function(self: Spring2D, velocityDelta: Vector2)
			self.Velocity = self.Velocity + velocityDelta
		end,
		Step = function(self: Spring2D, dt: number): Vector2
			local safeDt = math.min(dt, 1 / 15)
			local displacement = self.Position - self.Target
			local springForce = displacement * -(self.Omega0 * self.Omega0)
			local dampingForce = self.Velocity * -(2.0 * self.Zeta * self.Omega0)
			local acceleration = springForce + dampingForce

			self.Velocity = self.Velocity + acceleration * safeDt
			self.Position = self.Position + self.Velocity * safeDt
			return self.Position
		end,
	}

	return spring
end

--[[
	Controlador determinista de Spritesheets 2D para ImageLabel / ImageButton usando
	ImageRectSize e ImageRectOffset sobre una grilla (columns x rows).
]]
function ProceduralAnimator.CreateFlipbookController(
	imageLabel: ImageLabel,
	columns: number,
	rows: number,
	frameWidthPx: number,
	frameHeightPx: number,
	fps: number?
): FlipbookController
	local cols = math.max(1, math.floor(columns))
	local rws = math.max(1, math.floor(rows))
	local totalFrames = cols * rws
	local frameRate = math.max(1, fps or 24)
	local accumulator = 0.0

	imageLabel.ImageRectSize = Vector2.new(frameWidthPx, frameHeightPx)
	imageLabel.ImageRectOffset = Vector2.zero

	local function applyFrame(frameIndexZeroBased: number)
		local clamped = frameIndexZeroBased % totalFrames
		local col = clamped % cols
		local row = math.floor(clamped / cols)
		imageLabel.ImageRectOffset = Vector2.new(col * frameWidthPx, row * frameHeightPx)
	end

	local controller: FlipbookController = {
		ImageLabel = imageLabel,
		Columns = cols,
		Rows = rws,
		FrameWidthPx = frameWidthPx,
		FrameHeightPx = frameHeightPx,
		TotalFrames = totalFrames,
		Fps = frameRate,
		CurrentFrame = 0,
		Playing = false,
		Loop = true,
		Step = function(self: FlipbookController, dt: number)
			if not self.Playing then
				return
			end
			accumulator += dt
			local frameDuration = 1.0 / self.Fps
			while accumulator >= frameDuration do
				accumulator -= frameDuration
				local nextFrame = self.CurrentFrame + 1
				if nextFrame >= self.TotalFrames then
					if self.Loop then
						self.CurrentFrame = 0
					else
						self.CurrentFrame = self.TotalFrames - 1
						self.Playing = false
						break
					end
				else
					self.CurrentFrame = nextFrame
				end
				applyFrame(self.CurrentFrame)
			end
		end,
		Play = function(self: FlipbookController, loop: boolean?)
			self.Loop = if loop == nil then true else loop
			self.CurrentFrame = 0
			accumulator = 0.0
			self.Playing = true
			applyFrame(0)
		end,
		Stop = function(self: FlipbookController)
			self.Playing = false
		end,
	}

	return controller
end

--[[
	Vincula un FlipbookController al bucle RenderStepped y devuelve la conexión RBXScriptConnection.
]]
function ProceduralAnimator.BindFlipbookToRenderStep(controller: FlipbookController): RBXScriptConnection
	return RunService.RenderStepped:Connect(function(dt: number)
		controller:Step(dt)
	end)
end

return ProceduralAnimator
