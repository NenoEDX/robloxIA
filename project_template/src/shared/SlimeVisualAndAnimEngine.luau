--!strict
--[[
	SlimeVisualAndAnimEngine.luau
	Motor Visual y de Animación Procedural para "SLIME PIT: Dive for Mutants!" (Abyssal Slime Core).
	- Constructor paramétrico de los 10 chasis Skinned Mesh (4 huesos: Base, Centro, Corona, Núcleo, CanCollide = false)
	- Deformación elástica Squash & Stretch vía ProceduralAnimator.CreateSpring2D
	- Sincronización de armaduras acopladas leyendo Bone.TransformedWorldCFrame con LOD por distancia (<50 studs 60Hz, 50-120 studs 15Hz, >120 studs asleep)
	- Fusión Exo-Mecha Gelatinoso pre-riggeado (30s)
	- Regla de Tope de 10 Mutaciones (MAX_MUTATIONS_PER_SLIME = 10) y Modo Rendimiento (filterVisibleMutations: LOW_3 = 3, MEDIUM_6 = 6, HIGH_10 = 10)
	- 5 Cinemáticas Core de Dopamina:
		1. buildCrateRarityAnimationSpec (Apertura de Cajas de Evento Día 1)
		2. buildExtractionRarityAnimationSpec (Extracción en Ascensor y Tanque Dorsal)
		3. buildBaseArrivalAnimationSpec (Llegada a Base Circular)
		4. buildPetExtractedMutationAnimationSpec (Revelación de Mutación en Mascota)
		5. buildMutationStrikeDropAnimationSpec (Impacto Físico de Caída de Mutación)
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SharedFolder = script.Parent
local Types = require(SharedFolder:WaitForChild("Types"))
local SlimeCatalogs = require(SharedFolder:WaitForChild("SlimeCatalogs"))
local ProceduralAnimator = require(SharedFolder:WaitForChild("ProceduralAnimator"))
local VFXAndJuiceEngine = require(SharedFolder:WaitForChild("VFXAndJuiceEngine"))

export type PerformanceMutationMode = Types.PerformanceMutationMode
export type SlimeRarityGradeId = Types.SlimeRarityGradeId
export type SlimePetInstance = Types.SlimePetInstance
export type MutationDefinition = Types.MutationDefinition
export type SlimeChassisDefinition = Types.SlimeChassisDefinition
export type Spring2D = ProceduralAnimator.Spring2D

export type SlimeVisualRig = {
	model: Model,
	rootPart: BasePart,
	meshPart: BasePart,
	bones: { [string]: Bone },
	chassisId: string,
	squashSpring: Spring2D,
	armorAttachments: { [string]: Attachment },
	currentLODTier: ("HIGH" | "MEDIUM" | "SLEEP"),
	lodAccumulator: number,
}

export type AnimationStep = {
	timeSec: number,
	actionName: string,
	payload: { [string]: any },
}

export type DopamineAnimationSpec = {
	animationType: string,
	totalDurationSec: number,
	soundId: string?,
	trauma: number,
	hitstopFrames: number,
	fovPunch: number,
	primaryColor: Color3,
	steps: { AnimationStep },
}

local SlimeVisualAndAnimEngine = {}

-- Límite estricto de mutaciones por Slime al llegar a la base (evita la saturación de 30 mutaciones)
SlimeVisualAndAnimEngine.MAX_MUTATIONS_PER_SLIME = 10

-- Modos de Rendimiento para renderizado de mutaciones simultáneas
SlimeVisualAndAnimEngine.PERFORMANCE_MODES = table.freeze({
	LOW_3 = 3,
	MEDIUM_6 = 6,
	HIGH_10 = 10,
})

-- Umbrales de distancia para acoplamiento de armaduras con LOD (TransformedWorldCFrame)
SlimeVisualAndAnimEngine.DISTANCE_LOD_THRESHOLDS = table.freeze({
	HIGH_STUDS = 50, -- <50 studs: 60Hz
	MEDIUM_STUDS = 120, -- 50-120 studs: 15Hz
	-- >120 studs: Asleep (0Hz / congelado)
})

-- Duración de la transformación Exo-Mecha Gelatinoso pre-riggeado
SlimeVisualAndAnimEngine.EXO_MECH_DURATION_SEC = 30

--[[
	Filtra las mutaciones activas de un Slime según el Modo Rendimiento seleccionado:
	- LOW_3: Máximo 3 mutaciones visibles
	- MEDIUM_6: Máximo 6 mutaciones visibles
	- HIGH_10: Máximo 10 mutaciones visibles
	Prioriza aquellas con `changesAppearance = true` y mayor `visualPriority` descendente.
]]
function SlimeVisualAndAnimEngine.filterVisibleMutations(
	mutationIds: { string },
	mode: PerformanceMutationMode
): { string }
	local limit = SlimeVisualAndAnimEngine.PERFORMANCE_MODES[mode]
		or SlimeVisualAndAnimEngine.PERFORMANCE_MODES.MEDIUM_6
	limit = math.clamp(limit, 1, SlimeVisualAndAnimEngine.MAX_MUTATIONS_PER_SLIME)

	local list: { MutationDefinition } = {}
	for _, mutId in mutationIds do
		local def = SlimeCatalogs.MUTATIONS_BY_ID[mutId]
		if def then
			table.insert(list, def)
		end
	end

	table.sort(list, function(a: MutationDefinition, b: MutationDefinition): boolean
		if a.changesAppearance ~= b.changesAppearance then
			return a.changesAppearance == true
		end
		return a.visualPriority > b.visualPriority
	end)

	local result: { string } = {}
	local count = math.min(#list, limit)
	for i = 1, count do
		table.insert(result, list[i].id)
	end
	return result
end

--[[
	Construye el rig paramétrico del chasis Skinned Mesh (1 de 10) con 4 huesos jerárquicos:
	Base, Centro, Corona y Núcleo, con CanCollide = false en todas las partes físicas.
]]
function SlimeVisualAndAnimEngine.createSlimeChassisRig(
	chassisId: string,
	position: Vector3?,
	parent: Instance?
): SlimeVisualRig
	local chosenChassis: Types.SlimeChassisDefinition? = nil
	for _, c in SlimeCatalogs.CHASSES do
		if c.id == chassisId then
			chosenChassis = c
			break
		end
	end
	if not chosenChassis then
		chosenChassis = SlimeCatalogs.CHASSES[1]
	end

	local model = Instance.new("Model")
	model.Name = "SlimeRig_" .. chosenChassis.id

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = chosenChassis.baseScale
	rootPart.CanCollide = false
	rootPart.CanTouch = false
	rootPart.CanQuery = false
	rootPart.Transparency = 1
	rootPart.Position = position or Vector3.zero
	rootPart.Parent = model
	model.PrimaryPart = rootPart

	local meshPart = Instance.new("Part")
	meshPart.Name = "SlimeMesh"
	meshPart.Size = chosenChassis.baseScale
	meshPart.CanCollide = false
	meshPart.CanTouch = false
	meshPart.CanQuery = false
	meshPart.Material = Enum.Material.Glass
	meshPart.Transparency = 0.25
	meshPart.Color = Color3.fromRGB(80, 220, 160)
	meshPart.CFrame = rootPart.CFrame
	meshPart.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = meshPart
	weld.Parent = meshPart

	-- 4 huesos del Skinned Mesh: Base, Centro, Corona, Núcleo
	local bones: { [string]: Bone } = {}
	local boneOffsets = {
		Base = Vector3.new(0, -chosenChassis.baseScale.Y * 0.42, 0),
		Centro = Vector3.new(0, 0, 0),
		Corona = Vector3.new(0, chosenChassis.baseScale.Y * 0.38, 0),
		Nucleo = Vector3.new(0, chosenChassis.baseScale.Y * 0.05, 0),
	}

	local boneCentro = Instance.new("Bone")
	boneCentro.Name = "Bone_Centro"
	boneCentro.CFrame = CFrame.new(boneOffsets.Centro)
	boneCentro.Parent = meshPart
	bones["Centro"] = boneCentro

	local boneBase = Instance.new("Bone")
	boneBase.Name = "Bone_Base"
	boneBase.CFrame = CFrame.new(boneOffsets.Base)
	boneBase.Parent = boneCentro
	bones["Base"] = boneBase

	local boneCorona = Instance.new("Bone")
	boneCorona.Name = "Bone_Corona"
	boneCorona.CFrame = CFrame.new(boneOffsets.Corona)
	boneCorona.Parent = boneCentro
	bones["Corona"] = boneCorona

	local boneNucleo = Instance.new("Bone")
	boneNucleo.Name = "Bone_Nucleo"
	boneNucleo.CFrame = CFrame.new(boneOffsets.Nucleo)
	boneNucleo.Parent = boneCentro
	bones["Nucleo"] = boneNucleo

	-- Acoples para piezas de armadura
	local armorAttachments: { [string]: Attachment } = {}
	for boneName, bone in bones do
		local att = Instance.new("Attachment")
		att.Name = "Att_" .. boneName
		att.Parent = bone
		armorAttachments[boneName] = att
	end

	local squashSpring = ProceduralAnimator.CreateSpring2D(14.0, 0.58, Vector2.new(1.0, 1.0))

	local rig: SlimeVisualRig = {
		model = model,
		rootPart = rootPart,
		meshPart = meshPart,
		bones = bones,
		chassisId = chosenChassis.id,
		squashSpring = squashSpring,
		armorAttachments = armorAttachments,
		currentLODTier = "HIGH",
		lodAccumulator = 0,
	}

	if parent then
		model.Parent = parent
	end

	return rig
end

--[[
	Aplica deformación elástica no lineal (Squash & Stretch) sobre los huesos del chasis
	utilizando el oscilador armónico Spring2D de ProceduralAnimator.
]]
function SlimeVisualAndAnimEngine.applySquashAndStretch(
	rig: SlimeVisualRig,
	impulse: Vector2,
	dt: number
)
	if impulse.Magnitude > 0 then
		rig.squashSpring:Impulse(impulse)
	end
	local scale2D = rig.squashSpring:Step(dt)
	local sx = math.clamp(scale2D.X, 0.45, 2.2)
	local sy = math.clamp(scale2D.Y, 0.45, 2.2)

	local boneCorona = rig.bones["Corona"]
	local boneBase = rig.bones["Base"]
	local boneCentro = rig.bones["Centro"]

	if boneCorona then
		boneCorona.Transform = CFrame.new(0, (sy - 1.0) * 1.2, 0)
	end
	if boneBase then
		boneBase.Transform = CFrame.new(0, -(sy - 1.0) * 0.4, 0)
	end
	if boneCentro then
		boneCentro.Transform = CFrame.Angles(0, 0, (sx - sy) * 0.15)
	end
end

--[[
	Sincroniza armaduras acopladas al Slime leyendo Bone.TransformedWorldCFrame
	aplicando una política de LOD estricta según la distancia a la cámara del jugador:
	- < 50 studs: 60 Hz (tiempo real cada frame)
	- 50..120 studs: 15 Hz (tasa reducida ahorrando CPU)
	- > 120 studs: Asleep (0 Hz / sin costo de cálculo)
]]
function SlimeVisualAndAnimEngine.syncArmorAttachmentsWithLOD(
	rig: SlimeVisualRig,
	armorModel: Model?,
	cameraCFrame: CFrame,
	dt: number
): "HIGH" | "MEDIUM" | "SLEEP"
	if not armorModel then
		return "SLEEP"
	end

	local dist = (rig.rootPart.Position - cameraCFrame.Position).Magnitude

	if dist < SlimeVisualAndAnimEngine.DISTANCE_LOD_THRESHOLDS.HIGH_STUDS then
		-- < 50 studs: 60 Hz
		rig.currentLODTier = "HIGH"
		for boneName, bone in rig.bones do
			local piece = armorModel:FindFirstChild("Armor_" .. boneName)
			if piece and piece:IsA("BasePart") then
				piece.CFrame = bone.TransformedWorldCFrame
			end
		end
	elseif dist <= SlimeVisualAndAnimEngine.DISTANCE_LOD_THRESHOLDS.MEDIUM_STUDS then
		-- 50..120 studs: 15 Hz
		rig.currentLODTier = "MEDIUM"
		rig.lodAccumulator = rig.lodAccumulator + dt
		if rig.lodAccumulator >= (1 / 15) then
			rig.lodAccumulator = 0
			for boneName, bone in rig.bones do
				local piece = armorModel:FindFirstChild("Armor_" .. boneName)
				if piece and piece:IsA("BasePart") then
					piece.CFrame = bone.TransformedWorldCFrame
				end
			end
		end
	else
		-- > 120 studs: Asleep / frozen
		rig.currentLODTier = "SLEEP"
	end

	return rig.currentLODTier
end

--[[
	Construye la especificación cinemática para la transformación de Exo-Mecha Gelatinoso
	pre-riggeado por 30 segundos, amalgamando slimes y mutaciones en una forma titánica.
]]
function SlimeVisualAndAnimEngine.buildExoSlimeAmalgamationSpec(
	primarySlime: SlimePetInstance,
	absorbedSlimes: { SlimePetInstance }
): DopamineAnimationSpec
	local steps: { AnimationStep } = {
		{
			timeSec = 0.0,
			actionName = "SlimeConvergence",
			payload = {
				primaryId = primarySlime.slimeId,
				absorbedCount = #absorbedSlimes,
				convergenceRadiusStuds = 18.0,
			},
		},
		{
			timeSec = 0.6,
			actionName = "GelatinousFusionBlast",
			payload = {
				flashColor = Color3.fromRGB(168, 72, 255),
				traumaImpulse = 0.85,
				debrisCount = 14,
			},
		},
		{
			timeSec = 1.5,
			actionName = "MechChassisMaterialize",
			payload = {
				targetScale = 3.5,
				armorHardening = true,
				shieldAura = "NebulaExoShell",
			},
		},
		{
			timeSec = 2.5,
			actionName = "ExoArmoredCoreReady",
			payload = {
				activeDurationSec = SlimeVisualAndAnimEngine.EXO_MECH_DURATION_SEC,
				statBoostMultiplier = 2.5,
			},
		},
		{
			timeSec = SlimeVisualAndAnimEngine.EXO_MECH_DURATION_SEC - 1.0,
			actionName = "MechDecayWarning",
			payload = {
				pulseRate = 4.0,
			},
		},
		{
			timeSec = SlimeVisualAndAnimEngine.EXO_MECH_DURATION_SEC,
			actionName = "ExoMechDissolve",
			payload = {
				dissipationParticles = true,
			},
		},
	}

	return {
		animationType = "ExoSlimeAmalgamation",
		totalDurationSec = SlimeVisualAndAnimEngine.EXO_MECH_DURATION_SEC,
		soundId = "rbxassetid://9114223175",
		trauma = 0.85,
		hitstopFrames = 12,
		fovPunch = 16.0,
		primaryColor = Color3.fromRGB(168, 72, 255),
		steps = steps,
	}
end

--[[
	1. Cinemática de Apertura de Cajas Especiales Día 1:
	Escala desde un desbloqueo ágil para grados comunes hasta una cinemática abisal de impacto
	cósmico para el tier 0.0010% (0.001%, Celestial II).
]]
function SlimeVisualAndAnimEngine.buildCrateRarityAnimationSpec(
	rarityGrade: SlimeRarityGradeId,
	isMultiOpen: boolean
): DopamineAnimationSpec
	local gradeInfo = SlimeCatalogs.RARITY_GRADES[rarityGrade]
		or SlimeCatalogs.RARITY_GRADES.GRADE_01_BASIC
	local rank = gradeInfo.rank

	local duration = 1.6
	local trauma = 0.15
	local hitstop = 2
	local fovPunch = 3.0
	local soundId = "rbxassetid://9114223175"
	local steps: { AnimationStep } = {}

	if rank <= 3 then
		-- Basic, Rare, Epic
		duration = if isMultiOpen then 0.9 else 1.5
		trauma = 0.20
		hitstop = 3
		fovPunch = 4.0
		steps = {
			{ timeSec = 0.0, actionName = "CrateDrop", payload = { bounce = true } },
			{ timeSec = 0.4, actionName = "CrateOpen", payload = { flashColor = gradeInfo.color } },
			{ timeSec = 0.8, actionName = "SlimeReveal", payload = { rank = rank, isMulti = isMultiOpen } },
		}
	elseif rank <= 6 then
		-- Legendary, Mythical, Exotic
		duration = if isMultiOpen then 1.5 else 2.4
		trauma = 0.45
		hitstop = 6
		fovPunch = 8.0
		steps = {
			{ timeSec = 0.0, actionName = "CrateDrop", payload = { heavyImpact = true } },
			{ timeSec = 0.5, actionName = "CrateVibrate", payload = { vibrationFreq = 30 } },
			{ timeSec = 1.0, actionName = "LightRaysBurst", payload = { rayColor = gradeInfo.color } },
			{ timeSec = 1.5, actionName = "ShockwavePop", payload = { trauma = 0.35 } },
			{ timeSec = 1.9, actionName = "SlimeAscend", payload = { rank = rank } },
		}
	elseif rank <= 8 then
		-- Divine, Superior
		duration = if isMultiOpen then 2.0 else 3.2
		trauma = 0.70
		hitstop = 9
		fovPunch = 12.0
		steps = {
			{ timeSec = 0.0, actionName = "CrateDrop", payload = { groundCrater = true } },
			{ timeSec = 0.6, actionName = "GoldenVibration", payload = { goldenRays = true } },
			{ timeSec = 1.2, actionName = "ShellCracking", payload = { fissureGlow = gradeInfo.color } },
			{ timeSec = 1.8, actionName = "NovaBurst", payload = { shockwaveRadius = 25 } },
			{ timeSec = 2.4, actionName = "AlchemicalAuraBloom", payload = { auraGlow = true } },
			{ timeSec = 2.8, actionName = "SlimeCrownReveal", payload = { rank = rank } },
		}
	else
		-- Celestial I y Celestial II (0.001% Primigenio Singularidad)
		duration = if isMultiOpen then 2.8 else 4.6
		trauma = 0.95
		hitstop = 14
		fovPunch = 18.0
		steps = {
			{ timeSec = 0.0, actionName = "CrateDescentFromAbyss", payload = { portalOpening = true } },
			{ timeSec = 0.8, actionName = "GravityInversionQuake", payload = { floatingDebris = true } },
			{ timeSec = 1.6, actionName = "AbyssalRiftOpening", payload = { cosmicVoidFog = true } },
			{ timeSec = 2.4, actionName = "SingularityImplosion", payload = { silenceDip = true } },
			{ timeSec = 3.2, actionName = "CelestialSupernovaBurst", payload = { color = gradeInfo.color, odds = "0.001%" } },
			{ timeSec = 4.0, actionName = "PrimordialTitanicManifestation", payload = { rank = rank, isTitanic = true } },
		}
	end

	return {
		animationType = "CrateRarityReveal",
		totalDurationSec = duration,
		soundId = soundId,
		trauma = trauma,
		hitstopFrames = hitstop,
		fovPunch = fovPunch,
		primaryColor = gradeInfo.color,
		steps = steps,
	}
end

--[[
	2. Cinemática de Extracción por Rareza en Ascensor y Tanque Dorsal:
	Regula la presión de vapor, turbulencia de burbujas y sirenas luminiscentes
	según el ratio de llenado del tanque (0..1) y la máxima rareza extraída.
]]
function SlimeVisualAndAnimEngine.buildExtractionRarityAnimationSpec(
	maxRarityGrade: SlimeRarityGradeId,
	tankFillRatio: number
): DopamineAnimationSpec
	local gradeInfo = SlimeCatalogs.RARITY_GRADES[maxRarityGrade]
		or SlimeCatalogs.RARITY_GRADES.GRADE_01_BASIC
	local clampedFill = math.clamp(tankFillRatio, 0.0, 1.0)
	local isHighRisk = (clampedFill >= 0.75) or (gradeInfo.rank >= 7)

	local steps: { AnimationStep } = {
		{
			timeSec = 0.0,
			actionName = "VentSteamRelease",
			payload = {
				fillRatio = clampedFill,
				steamVolume = clampedFill * 2.5,
			},
		},
		{
			timeSec = 0.6,
			actionName = "ElevatorWinchEngage",
			payload = {
				cableTension = true,
				shaftVerticalSpeed = 48.0,
			},
		},
		{
			timeSec = 1.4,
			actionName = "AbyssalShaftAscent",
			payload = {
				strataGlow = gradeInfo.color,
				sirenAlert = isHighRisk,
			},
		},
		{
			timeSec = 2.2,
			actionName = "AuraWarningKlaxon",
			payload = {
				beaconPulse = true,
				highestGradeRank = gradeInfo.rank,
			},
		},
		{
			timeSec = 3.0,
			actionName = "LobbyAirlockDecompression",
			payload = {
				dockingSuccess = true,
			},
		},
	}

	return {
		animationType = "ExtractionAscent",
		totalDurationSec = 3.2,
		soundId = "rbxassetid://9114223175",
		trauma = if isHighRisk then 0.55 else 0.25,
		hitstopFrames = if isHighRisk then 6 else 2,
		fovPunch = if isHighRisk then 8.0 else 3.0,
		primaryColor = gradeInfo.color,
		steps = steps,
	}
end

--[[
	3. Cinemática de Llegada a la Base Circular:
	Descarga el Slime extraído en el pedestal del Lobby, activando el rebote
	gelatinoso y aplicando las mutaciones recibidas (tope estricto de 10).
]]
function SlimeVisualAndAnimEngine.buildBaseArrivalAnimationSpec(
	slimeInstance: SlimePetInstance,
	mutationsApplied: { string }
): DopamineAnimationSpec
	local clampedMutations = math.min(#mutationsApplied, SlimeVisualAndAnimEngine.MAX_MUTATIONS_PER_SLIME)

	local steps: { AnimationStep } = {
		{
			timeSec = 0.0,
			actionName = "ChuteSlideExit",
			payload = {
				slimeUuid = slimeInstance.uuid,
				slimeId = slimeInstance.slimeId,
			},
		},
		{
			timeSec = 0.4,
			actionName = "GelatinousImpactBounce",
			payload = {
				springImpulse = Vector2.new(1.8, -2.4),
			},
		},
		{
			timeSec = 0.9,
			actionName = "PedestalAlignmentScan",
			payload = {
				scanBeamColor = Color3.fromRGB(58, 148, 255),
			},
		},
		{
			timeSec = 1.4,
			actionName = "MutagenicActivationSequence",
			payload = {
				mutationsCount = clampedMutations,
				mutations = mutationsApplied,
			},
		},
		{
			timeSec = 2.0,
			actionName = "SanctuaryRegistration",
			payload = {
				registered = true,
			},
		},
	}

	return {
		animationType = "BaseArrival",
		totalDurationSec = 2.2,
		soundId = "rbxassetid://9114223175",
		trauma = 0.35,
		hitstopFrames = 4,
		fovPunch = 5.0,
		primaryColor = Color3.fromRGB(58, 148, 255),
		steps = steps,
	}
end

--[[
	4. Cinemática de Mutación Obtenida en Mascota Extraída:
	Revelación al activar una nueva mutación en la mascota con halo alquímico
	y despliegue de estandarte de estadísticas.
]]
function SlimeVisualAndAnimEngine.buildPetExtractedMutationAnimationSpec(
	slimeInstance: SlimePetInstance,
	mutationDef: MutationDefinition
): DopamineAnimationSpec
	local steps: { AnimationStep } = {
		{
			timeSec = 0.0,
			actionName = "MutationOrbFloat",
			payload = {
				mutId = mutationDef.id,
				vector = mutationDef.vector,
			},
		},
		{
			timeSec = 0.5,
			actionName = "DnaAlchemicalHalo",
			payload = {
				haloColor = mutationDef.primaryColor,
			},
		},
		{
			timeSec = 1.0,
			actionName = "GeneticInfusion",
			payload = {
				nucleusTarget = "Bone_Nucleo",
				changesAppearance = mutationDef.changesAppearance,
			},
		},
		{
			timeSec = 1.5,
			actionName = "StatBannerPopup",
			payload = {
				mutName = mutationDef.name,
				bonusPercent = mutationDef.statPercentBonus,
				tag = mutationDef.appearanceTag,
			},
		},
	}

	return {
		animationType = "PetExtractedMutation",
		totalDurationSec = 1.8,
		soundId = "rbxassetid://9114223175",
		trauma = 0.30,
		hitstopFrames = 3,
		fovPunch = 4.5,
		primaryColor = mutationDef.primaryColor,
		steps = steps,
	}
end

--[[
	5. Cinemática de Caída e Impacto Físico de la Mutación sobre el Slime:
	Un proyectil alquímico / rayo cósmico impacta desde el cenit sobre los huesos
	Bone_Corona y Bone_Centro, activando HitFlash, deformación y transformación visual.
]]
function SlimeVisualAndAnimEngine.buildMutationStrikeDropAnimationSpec(
	slimeInstance: SlimePetInstance,
	mutationDef: MutationDefinition
): DopamineAnimationSpec
	local steps: { AnimationStep } = {
		{
			timeSec = 0.0,
			actionName = "SkyCometDescend",
			payload = {
				startAltitudeStuds = 60,
				trailColor = mutationDef.primaryColor,
			},
		},
		{
			timeSec = 0.4,
			actionName = "DirectSlamImpact",
			payload = {
				targetBone = "Bone_Corona",
				hitstopFrames = 6,
				trauma = 0.45,
			},
		},
		{
			timeSec = 0.7,
			actionName = "AppearanceMorph",
			payload = {
				scaleMultiplier = mutationDef.scaleMultiplier,
				tint = mutationDef.primaryColor,
				changesAppearance = mutationDef.changesAppearance,
				appearanceTag = mutationDef.appearanceTag,
			},
		},
		{
			timeSec = 1.2,
			actionName = "MutantRoarShockwave",
			payload = {
				shockwaveRadius = 16.0,
			},
		},
	}

	return {
		animationType = "MutationStrikeDrop",
		totalDurationSec = 1.5,
		soundId = "rbxassetid://9114223175",
		trauma = 0.45,
		hitstopFrames = 6,
		fovPunch = 7.0,
		primaryColor = mutationDef.primaryColor,
		steps = steps,
	}
end

--[[
	Ejecuta en tiempo real el Game Feel ("Juice") coordinado con VFXAndJuiceEngine
	ante el impacto físico de una mutación.
]]
function SlimeVisualAndAnimEngine.playMutationDropJuice(
	targetModel: Model?,
	mutationDef: MutationDefinition,
	hitPosition: Vector3?
)
	VFXAndJuiceEngine.AddTrauma(0.45)
	if targetModel then
		VFXAndJuiceEngine.TriggerHitFlash(targetModel, 0.14)
		VFXAndJuiceEngine.ApplyHitstop(targetModel, 6)
	end
	VFXAndJuiceEngine.PunchFov(7.0)

	local pos = hitPosition
		or (if targetModel and targetModel.PrimaryPart then targetModel.PrimaryPart.Position else Vector3.zero)

	VFXAndJuiceEngine.PlayModulatedSound("rbxassetid://9114223175", pos, 0.09, nil, nil)

	pcall(function()
		VFXAndJuiceEngine.CastEffect("HeavyImpact", CFrame.new(pos), {
			PrimaryColor = mutationDef.primaryColor,
			SecondaryColor = Color3.new(1, 1, 1),
			DebrisCount = 8,
			TraumaAmount = 0.45,
			FovPunch = 7.0,
			TargetModel = targetModel,
		})
	end)
end

return table.freeze(SlimeVisualAndAnimEngine)
