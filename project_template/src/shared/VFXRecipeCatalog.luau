--!strict
--[[
	VFXRecipeCatalog.luau
	Intent-driven Fighting-Game & Dopamine VFX Catalog for Roblox Studio MCP.
	Enforces the LihFolk 3-Value Rule (white-hot core, saturated element body,
	dark ink contrast rim), frontal arc clamping (±100°), CameraShake, and HitStop.
]]

export type ElementId = "teal" | "violet" | "fire" | "ice" | "lightning" | "void" | "holy" | "plasma" | "heal"

export type ThreeValuePalette = {
	hotCore: Color3,
	elementBody: Color3,
	darkInkRim: Color3,
}

export type VFXRecipe = {
	recipeId: string,
	name: string,
	moduleName: "LihFolkVFX" | "LihFolkVFX_Abilities",
	preset: string,
	defaultElement: ElementId,
	frontalClampDegrees: number?,
	cameraShakeIntensity: number,
	cameraShakeDuration: number,
	hitStopSeconds: number,
	maxParticlesMobile: number,
	maxParticlesPC: number,
	intentKeywords: { string },
}

export type StoryboardPhase = {
	phaseOrder: number,
	phaseName: string,
	startTimeSeconds: number,
	durationSeconds: number,
	actionType: "atmosphere_shift" | "ground_telegraph" | "projectile_3d_descent" | "impact_climax" | "apply_mutation_stack" | "camera_fov_focus",
	presetUsed: string?,
	required3DMeshAssetId: string?,
}

export type VFXStoryboard = {
	storyboardId: string,
	name: string,
	category: "ultimate_ability" | "world_mutation_event" | "boss_phase",
	defaultElement: ElementId,
	totalDurationSeconds: number,
	phases: { StoryboardPhase },
	intentKeywords: { string },
}

export type MutationSurfaceStack = {
	mutationId: string,
	name: string,
	targetKind: "plant" | "slime" | "prop" | "weapon",
	element: ElementId,
	layer1SurfaceMaterial: string,
	layer2Graft3DAssetId: string,
	layer3HighlightOutline: Color3,
	layer4AmbientParticles: string,
	multiplierHint: number,
}

local ELEMENT_PALETTES: { [ElementId]: ThreeValuePalette } = {
	teal = {
		hotCore = Color3.fromRGB(245, 255, 255),
		elementBody = Color3.fromRGB(0, 225, 210),
		darkInkRim = Color3.fromRGB(8, 32, 48),
	},
	violet = {
		hotCore = Color3.fromRGB(250, 240, 255),
		elementBody = Color3.fromRGB(165, 70, 255),
		darkInkRim = Color3.fromRGB(24, 10, 46),
	},
	fire = {
		hotCore = Color3.fromRGB(255, 250, 220),
		elementBody = Color3.fromRGB(255, 95, 20),
		darkInkRim = Color3.fromRGB(45, 12, 8),
	},
	ice = {
		hotCore = Color3.fromRGB(245, 252, 255),
		elementBody = Color3.fromRGB(70, 195, 255),
		darkInkRim = Color3.fromRGB(10, 28, 52),
	},
	lightning = {
		hotCore = Color3.fromRGB(255, 255, 235),
		elementBody = Color3.fromRGB(255, 215, 35),
		darkInkRim = Color3.fromRGB(28, 22, 50),
	},
	void = {
		hotCore = Color3.fromRGB(235, 210, 255),
		elementBody = Color3.fromRGB(22, 12, 36),
		darkInkRim = Color3.fromRGB(170, 75, 255),
	},
	holy = {
		hotCore = Color3.fromRGB(255, 255, 240),
		elementBody = Color3.fromRGB(255, 205, 65),
		darkInkRim = Color3.fromRGB(52, 34, 10),
	},
	plasma = {
		hotCore = Color3.fromRGB(255, 240, 255),
		elementBody = Color3.fromRGB(255, 50, 165),
		darkInkRim = Color3.fromRGB(40, 8, 36),
	},
	heal = {
		hotCore = Color3.fromRGB(240, 255, 245),
		elementBody = Color3.fromRGB(65, 235, 130),
		darkInkRim = Color3.fromRGB(10, 42, 24),
	},
}

local RECIPES: { VFXRecipe } = {
	{
		recipeId = "combat_slash_heavy",
		name = "Tajo Pesado Frontal",
		moduleName = "LihFolkVFX",
		preset = "SlashSweep",
		defaultElement = "teal",
		frontalClampDegrees = 100,
		cameraShakeIntensity = 0.45,
		cameraShakeDuration = 0.18,
		hitStopSeconds = 0.08,
		maxParticlesMobile = 51,
		maxParticlesPC = 85,
		intentKeywords = { "espada", "corte", "tajo", "slash", "pelea", "ataque pesado" },
	},
	{
		recipeId = "combat_double_crescent",
		name = "Combo Doble Medialuna",
		moduleName = "LihFolkVFX",
		preset = "CrescentDouble",
		defaultElement = "violet",
		frontalClampDegrees = 100,
		cameraShakeIntensity = 0.30,
		cameraShakeDuration = 0.12,
		hitStopSeconds = 0.05,
		maxParticlesMobile = 54,
		maxParticlesPC = 90,
		intentKeywords = { "combo", "doble", "rapido", "medialuna" },
	},
	{
		recipeId = "combat_overhead_slam",
		name = "Golpe Vertical Destructor de Suelo",
		moduleName = "LihFolkVFX",
		preset = "OverheadCleave",
		defaultElement = "fire",
		frontalClampDegrees = 100,
		cameraShakeIntensity = 0.65,
		cameraShakeDuration = 0.24,
		hitStopSeconds = 0.11,
		maxParticlesMobile = 49,
		maxParticlesPC = 80,
		intentKeywords = { "martillo", "slam", "suelo", "grieta", "vertical" },
	},
	{
		recipeId = "combat_thrust_pierce",
		name = "Estocada Perforante Sónica",
		moduleName = "LihFolkVFX",
		preset = "ThrustPierce",
		defaultElement = "ice",
		frontalClampDegrees = 100,
		cameraShakeIntensity = 0.35,
		cameraShakeDuration = 0.14,
		hitStopSeconds = 0.06,
		maxParticlesMobile = 27,
		maxParticlesPC = 45,
		intentKeywords = { "lanza", "estocada", "perforar", "thrust", "puno" },
	},
	{
		recipeId = "combat_dash_afterimage",
		name = "Dash Relámpago con Copias Fantasma",
		moduleName = "LihFolkVFX",
		preset = "DashTrail",
		defaultElement = "lightning",
		frontalClampDegrees = nil,
		cameraShakeIntensity = 0.20,
		cameraShakeDuration = 0.10,
		hitStopSeconds = 0.0,
		maxParticlesMobile = 28,
		maxParticlesPC = 48,
		intentKeywords = { "dash", "esquivar", "velocidad", "fantasma", "afterimage" },
	},
	{
		recipeId = "combat_beam_kamehameha",
		name = "Rayo de Energía / Cañón Láser",
		moduleName = "LihFolkVFX_Abilities",
		preset = "BeamLaser",
		defaultElement = "plasma",
		frontalClampDegrees = nil,
		cameraShakeIntensity = 0.70,
		cameraShakeDuration = 0.35,
		hitStopSeconds = 0.09,
		maxParticlesMobile = 40,
		maxParticlesPC = 80,
		intentKeywords = { "rayo", "laser", "kamehameha", "beam", "canon" },
	},
	{
		recipeId = "combat_ice_crystal_burst",
		name = "Explosión Radial de Cristales",
		moduleName = "LihFolkVFX",
		preset = "IceExplosion",
		defaultElement = "ice",
		frontalClampDegrees = nil,
		cameraShakeIntensity = 0.60,
		cameraShakeDuration = 0.25,
		hitStopSeconds = 0.10,
		maxParticlesMobile = 54,
		maxParticlesPC = 90,
		intentKeywords = { "explosion", "cristales", "hielo", "burst", "aoe" },
	},
	{
		recipeId = "dopamine_slime_extract_pop",
		name = "Extracción Dopamínica y Subida de Nivel",
		moduleName = "LihFolkVFX_Abilities",
		preset = "LevelUp",
		defaultElement = "holy",
		frontalClampDegrees = nil,
		cameraShakeIntensity = 0.35,
		cameraShakeDuration = 0.18,
		hitStopSeconds = 0.06,
		maxParticlesMobile = 60,
		maxParticlesPC = 95,
		intentKeywords = { "extraer", "slime", "recompensa", "dopamina", "levelup", "captura" },
	},
	{
		recipeId = "character_power_aura",
		name = "Aura de Poder y Contorno de Silueta",
		moduleName = "LihFolkVFX_Abilities",
		preset = "Aura",
		defaultElement = "void",
		frontalClampDegrees = nil,
		cameraShakeIntensity = 0.0,
		cameraShakeDuration = 0.0,
		hitStopSeconds = 0.0,
		maxParticlesMobile = 15,
		maxParticlesPC = 30,
		intentKeywords = { "aura", "transformacion", "brillo", "mutacion", "titanico" },
	},
}

local STORYBOARDS: { VFXStoryboard } = {
	{
		storyboardId = "event_meteor_mutation_shower",
		name = "Evento Climático: Lluvia de Meteoritos de Mutación",
		category = "world_mutation_event",
		defaultElement = "fire",
		totalDurationSeconds = 3.2,
		intentKeywords = { "meteorito", "meteoritos", "cielo", "evento", "climatico", "lluvia" },
		phases = {
			{
				phaseOrder = 1,
				phaseName = "Aviso Atmosférico y Tinte de Cielo",
				startTimeSeconds = 0.0,
				durationSeconds = 1.0,
				actionType = "atmosphere_shift",
				presetUsed = nil,
				required3DMeshAssetId = nil,
			},
			{
				phaseOrder = 2,
				phaseName = "Telégrafo de Impacto en Suelo sobre Planta/Slime",
				startTimeSeconds = 0.6,
				durationSeconds = 1.2,
				actionType = "ground_telegraph",
				presetUsed = "Telegraph",
				required3DMeshAssetId = nil,
			},
			{
				phaseOrder = 3,
				phaseName = "Descenso Diagonal del Meteorito 3D con Estela",
				startTimeSeconds = 1.1,
				durationSeconds = 0.7,
				actionType = "projectile_3d_descent",
				presetUsed = "Projectile",
				required3DMeshAssetId = "vfx_mesh_meteorito_roca",
			},
			{
				phaseOrder = 4,
				phaseName = "Impacto, Cráter 3D, HitStop y Onda Expansiva",
				startTimeSeconds = 1.8,
				durationSeconds = 0.6,
				actionType = "impact_climax",
				presetUsed = "OverheadCleave",
				required3DMeshAssetId = "vfx_mesh_crater_anillo",
			},
			{
				phaseOrder = 5,
				phaseName = "Transformación Visual de la Planta o Slime (4 Capas)",
				startTimeSeconds = 2.1,
				durationSeconds = 1.1,
				actionType = "apply_mutation_stack",
				presetUsed = "Aura",
				required3DMeshAssetId = "mutacion_cuernos_cristal",
			},
		},
	},
	{
		storyboardId = "ultimate_abyssal_cataclysm",
		name = "Habilidad Definitiva (Ultimate): Cataclismo Abismal",
		category = "ultimate_ability",
		defaultElement = "void",
		totalDurationSeconds = 2.8,
		intentKeywords = { "definitiva", "ultimate", "ulti", "cataclismo", "especial" },
		phases = {
			{
				phaseOrder = 1,
				phaseName = "Enfoque de Cámara (FOV Zoom) + Oscurecimiento + ChargeUp",
				startTimeSeconds = 0.0,
				durationSeconds = 0.75,
				actionType = "camera_fov_focus",
				presetUsed = "ChargeUp",
				required3DMeshAssetId = nil,
			},
			{
				phaseOrder = 2,
				phaseName = "Descenso del Coloso / Proyectil Definitivo 3D",
				startTimeSeconds = 0.75,
				durationSeconds = 0.55,
				actionType = "projectile_3d_descent",
				presetUsed = "BeamLaser",
				required3DMeshAssetId = "vfx_mesh_nucleo_abismal",
			},
			{
				phaseOrder = 3,
				phaseName = "Detonación Radial de Cristales + HitStop + CameraShake",
				startTimeSeconds = 1.30,
				durationSeconds = 0.80,
				actionType = "impact_climax",
				presetUsed = "IceExplosion",
				required3DMeshAssetId = nil,
			},
			{
				phaseOrder = 4,
				phaseName = "Disipación Suave de Tinta y Grietas Luminosas",
				startTimeSeconds = 2.10,
				durationSeconds = 0.70,
				actionType = "atmosphere_shift",
				presetUsed = nil,
				required3DMeshAssetId = nil,
			},
		},
	},
}

local MUTATION_STACKS: { MutationSurfaceStack } = {
	{
		mutationId = "mut_meteoric_magma",
		name = "Mutación Meteórica Incandescente (Sobre Planta o Slime)",
		targetKind = "plant",
		element = "fire",
		layer1SurfaceMaterial = "CrackedLava_NeonVeins",
		layer2Graft3DAssetId = "mutacion_esquirlas_meteoro",
		layer3HighlightOutline = Color3.fromRGB(255, 110, 25),
		layer4AmbientParticles = "RisingEmbersAndDarkAsh",
		multiplierHint = 8.0,
	},
	{
		mutationId = "mut_celestial_crystal",
		name = "Mutación Cristalizada Celestial (Sobre Planta o Slime)",
		targetKind = "plant",
		element = "ice",
		layer1SurfaceMaterial = "Glass_FacetedIridescent",
		layer2Graft3DAssetId = "mutacion_cuernos_cristal",
		layer3HighlightOutline = Color3.fromRGB(90, 225, 255),
		layer4AmbientParticles = "FloatingPrismGlints",
		multiplierHint = 12.0,
	},
	{
		mutationId = "mut_abyssal_void",
		name = "Mutación Vacío Abismal (Sobre Planta o Slime)",
		targetKind = "slime",
		element = "void",
		layer1SurfaceMaterial = "ForceField_DarkCoreShell",
		layer2Graft3DAssetId = "mutacion_corona_solar",
		layer3HighlightOutline = Color3.fromRGB(175, 70, 255),
		layer4AmbientParticles = "VoidMotesAndOrbitingWisps",
		multiplierHint = 25.0,
	},
}

local VFXRecipeCatalog = {}

function VFXRecipeCatalog.getAllRecipes(): { VFXRecipe }
	return table.clone(RECIPES)
end

function VFXRecipeCatalog.getAllStoryboards(): { VFXStoryboard }
	return table.clone(STORYBOARDS)
end

function VFXRecipeCatalog.getAllMutationStacks(): { MutationSurfaceStack }
	return table.clone(MUTATION_STACKS)
end

function VFXRecipeCatalog.composeCustomStoryboard(
	customName: string,
	category: "ultimate_ability" | "world_mutation_event" | "boss_phase",
	element: ElementId,
	projectileMeshId: string?,
	mutationGraftId: string?
): (VFXStoryboard, ThreeValuePalette)
	local storyboard: VFXStoryboard = {
		storyboardId = "custom_" .. string.lower(string.gsub(customName, "%s+", "_")),
		name = customName,
		category = category,
		defaultElement = element,
		totalDurationSeconds = 2.8,
		intentKeywords = { string.lower(customName) },
		phases = {
			{
				phaseOrder = 1,
				phaseName = "Anticipación (Wind-Up) + Enfoque de Cámara y Luz",
				startTimeSeconds = 0.0,
				durationSeconds = 0.35,
				actionType = "camera_fov_focus",
				presetUsed = "ChargeUp",
				required3DMeshAssetId = nil,
			},
			{
				phaseOrder = 2,
				phaseName = "Telégrafo de Suelo Alineado por Raycast",
				startTimeSeconds = 0.25,
				durationSeconds = 0.65,
				actionType = "ground_telegraph",
				presetUsed = "Telegraph",
				required3DMeshAssetId = nil,
			},
			{
				phaseOrder = 3,
				phaseName = "Trayectoria 3D Fluida (60 Hz Spring Overshoot)",
				startTimeSeconds = 0.65,
				durationSeconds = 0.55,
				actionType = "projectile_3d_descent",
				presetUsed = "Projectile",
				required3DMeshAssetId = projectileMeshId or "vfx_mesh_proyectil_evento",
			},
			{
				phaseOrder = 4,
				phaseName = "Frame de Impacto + HitStop + CameraShake + Onda 3 Tonos",
				startTimeSeconds = 1.20,
				durationSeconds = 0.60,
				actionType = "impact_climax",
				presetUsed = "OverheadCleave",
				required3DMeshAssetId = "vfx_mesh_crater_anillo",
			},
			{
				phaseOrder = 5,
				phaseName = "Imbuición de Mutación de 4 Capas / Residuo Eroded",
				startTimeSeconds = 1.50,
				durationSeconds = 1.30,
				actionType = "apply_mutation_stack",
				presetUsed = "Aura",
				required3DMeshAssetId = mutationGraftId or "mutacion_cuernos_cristal",
			},
		},
	}
	return storyboard, VFXRecipeCatalog.getPalette(element)
end

function VFXRecipeCatalog.getPalette(element: ElementId): ThreeValuePalette
	local palette = ELEMENT_PALETTES[element]
	if not palette then
		return ELEMENT_PALETTES.teal
	end
	return palette
end

function VFXRecipeCatalog.resolveByIntent(intentQuery: string, elementOverride: ElementId?): (VFXRecipe, ThreeValuePalette)
	local q = string.lower(intentQuery or "")
	local chosen: VFXRecipe = RECIPES[1]
	for _, recipe in ipairs(RECIPES) do
		if string.lower(recipe.recipeId) == q or string.lower(recipe.preset) == q then
			chosen = recipe
			break
		end
		for _, kw in ipairs(recipe.intentKeywords) do
			if string.find(q, kw, 1, true) ~= nil then
				chosen = recipe
				break
			end
		end
	end
	local elem: ElementId = elementOverride or chosen.defaultElement
	return chosen, VFXRecipeCatalog.getPalette(elem)
end

return VFXRecipeCatalog
