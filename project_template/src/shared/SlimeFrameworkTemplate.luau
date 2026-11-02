--!strict
--[[
	SlimeFrameworkTemplate.luau
	Framework Propio Desde Cero de Plantillas Declarativas ("Zero-Token Update Engine")
	para "Slimes Abismales: ¡Sumérgete y Escapa! (SLIME PIT: Dive for Mutants!)".

	Propósito:
	Permitir que cualquier actualización semanal (nuevos Slimes, Cajas de Evento 0.001%,
	Mutaciones, Biomas o Eventos de Admin Abuse) se declare en bloques de 5 a 12 líneas
	con valores por defecto inteligentes, sin volver a leer ni tocar el motor de servidor,
	matemática, cliente o interfaz (reducción del ~90% de tokens en futuras sesiones).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(SharedFolder:WaitForChild("Types"))
local SlimeCatalogs = require(SharedFolder:WaitForChild("SlimeCatalogs"))

export type SlimeRarityGradeId = Types.SlimeRarityGradeId
export type MutationVectorCategory = Types.MutationVectorCategory
export type SlimeDefinition = Types.SlimeDefinition
export type MutationDefinition = Types.MutationDefinition
export type EventCrateItem = Types.EventCrateItem

export type CompactSlimeTemplate = {
	id: string,
	name: string,
	biomeIndex: number?,
	chassisIndex: number?, -- 1..10 (default: 1 Esférico)
	raceIndex: number?, -- 1..10 (default: 1 Orgánica)
	rarityRank: number?, -- 1..10 (default: calculado por bioma)
	ultraClass: ("NONE" | "HUGE" | "TITANIC")?,
	basePowerOverride: number?,
}

export type CompactMutationTemplate = {
	id: string,
	numericId: number,
	name: string,
	vector: MutationVectorCategory?,
	statPercentBonus: number,
	scaleMultiplier: number?,
	damageMitigationPercent: number?,
	cooldownReductionPercent: number?,
	alchemyPurityBonusPercent: number?,
	changesAppearance: boolean?,
	colorRGB: { number }?,
}

export type CompactEventCrateTemplate = {
	crateId: string,
	crateTitle: string,
	freeTokenCurrency: string?,
	freeTokenCost: number?,
	openMultipliers: { number }?, -- ej. { 1, 3, 10 }
	items: {
		{
			id: string,
			slimeId: string,
			name: string,
			rarityRank: number, -- 1..10
			probabilityPercent: number, -- ej. 45.0 hasta 0.001 (0.0010%)
			guaranteedMutationId: string?,
			isUltra: boolean?,
		}
	},
}

export type WeeklyUpdateManifest = {
	updateId: string,
	title: string,
	versionTag: string,
	newSlimes: { CompactSlimeTemplate }?,
	newMutations: { CompactMutationTemplate }?,
	newCrates: { CompactEventCrateTemplate }?,
	activeAdminEventPresets: { string }?,
}

local GRADE_BY_RANK: { SlimeRarityGradeId } = {
	"GRADE_01_BASIC",
	"GRADE_02_RARE",
	"GRADE_03_EPIC",
	"GRADE_04_LEGENDARY",
	"GRADE_05_MYTHICAL",
	"GRADE_06_EXOTIC",
	"GRADE_07_DIVINE",
	"GRADE_08_SUPERIOR",
	"GRADE_09_CELESTIAL_I",
	"GRADE_10_CELESTIAL_II",
}

local SlimeFrameworkTemplate = {}

local registeredUpdates: { [string]: WeeklyUpdateManifest } = {}
local customSlimesRegistry: { [string]: SlimeDefinition } = {}
local customMutationsRegistry: { [string]: MutationDefinition } = {}
local customCratesRegistry: { [string]: {
	crateId: string,
	crateTitle: string,
	freeTokenCurrency: string,
	freeTokenCost: number,
	openMultipliers: { number },
	items: { EventCrateItem },
	deterministicSeedQueue: { string },
} } = {}

--[[
	Convierte una plantilla mínima de 5 líneas en un SlimeDefinition completo y validado.
]]
function SlimeFrameworkTemplate.defineSlimeFromTemplate(tpl: CompactSlimeTemplate): SlimeDefinition
	local biome = math.clamp(tpl.biomeIndex or 1, 1, SlimeCatalogs.TOTAL_BIOMES)
	local macroRing = math.ceil(biome / SlimeCatalogs.SUB_BIOMES_PER_RING)
	local chassisIdx = math.clamp(tpl.chassisIndex or 1, 1, #SlimeCatalogs.CHASSES)
	local raceIdx = math.clamp(tpl.raceIndex or 1, 1, #SlimeCatalogs.RACES)
	local ultraClass = tpl.ultraClass or "NONE"
	local isUltra = (ultraClass ~= "NONE")

	local defaultRank = if ultraClass == "TITANIC"
		then 10
		elseif ultraClass == "HUGE"
		then 9
		else math.clamp(math.ceil(biome / 3), 1, 10)
	local rank = math.clamp(tpl.rarityRank or defaultRank, 1, 10)
	local grade = GRADE_BY_RANK[rank]

	local computedPower = if isUltra
		then 0
		else (tpl.basePowerOverride or math.floor(15 * (1.34 ^ (biome - 1)) * (1 + (rank - 1) * 0.28)))

	local def: SlimeDefinition = table.freeze({
		id = tpl.id,
		name = tpl.name,
		biomeIndex = biome,
		macroRingIndex = macroRing,
		chassisId = SlimeCatalogs.CHASSES[chassisIdx].id,
		raceId = SlimeCatalogs.RACES[raceIdx].id,
		rarityGrade = grade,
		isUltraSpecial = isUltra,
		ultraClass = ultraClass,
		anchoredBaseRatio = if ultraClass == "TITANIC" then 2.0 elseif ultraClass == "HUGE" then 1.0000001 else 1.0,
		anchoredMaxRatioLv99 = if ultraClass == "TITANIC" then 4.0 elseif ultraClass == "HUGE" then 2.0 else 1.0,
		basePower = computedPower,
		baseCoinsPerSec = math.max(1, math.floor(computedPower * 0.65)),
		baseStabilityHP = if ultraClass == "TITANIC"
			then 8000
			elseif ultraClass == "HUGE"
			then 4200
			else (100 + biome * 45 + rank * 15),
		juiceType = if isUltra then "Esencia_Abisal_Pura" else string.format("Jugo_Bioma_%02d", biome),
	})

	customSlimesRegistry[def.id] = def
	return def
end

--[[
	Convierte una plantilla compacta de mutación en un MutationDefinition completo
	con soporte automático para el Modo Rendimiento (3 / 6 / 10 visibles).
]]
function SlimeFrameworkTemplate.defineMutationFromTemplate(tpl: CompactMutationTemplate): MutationDefinition
	local rgb = tpl.colorRGB or { 120, 220, 255 }
	local changesApp = if tpl.changesAppearance ~= nil then tpl.changesAppearance else true
	local def: MutationDefinition = table.freeze({
		id = tpl.id,
		numericId = tpl.numericId,
		name = tpl.name,
		vector = tpl.vector or "ECONOMIC",
		statPercentBonus = tpl.statPercentBonus,
		scaleMultiplier = tpl.scaleMultiplier or 1.0,
		damageMitigationPercent = tpl.damageMitigationPercent or 0,
		cooldownReductionPercent = tpl.cooldownReductionPercent or 0,
		alchemyPurityBonusPercent = tpl.alchemyPurityBonusPercent or 0,
		changesAppearance = changesApp,
		visualPriority = 100 + tpl.numericId + (if changesApp then 50 else 0),
		primaryColor = Color3.fromRGB(rgb[1] or 255, rgb[2] or 255, rgb[3] or 255),
		appearanceTag = "App_" .. tpl.id,
	})

	customMutationsRegistry[def.id] = def
	return def
end

--[[
	Registra una Caja de Evento (10 Slimes desde común hasta 0.0010%), normaliza sus
	probabilidades a 4 decimales para cumplir PolicyService 2026 y pre-construye la
	Escalera de Extracción Determinista para regiones con ArePaidRandomItemsRestricted = true.
]]
function SlimeFrameworkTemplate.defineEventCrateFromTemplate(tpl: CompactEventCrateTemplate)
	local builtItems: { EventCrateItem } = {}
	local totalProb = 0

	for _, rawItem in tpl.items do
		totalProb += rawItem.probabilityPercent
		local rank = math.clamp(rawItem.rarityRank, 1, 10)
		local itemDef: EventCrateItem = table.freeze({
			id = rawItem.id,
			slimeId = rawItem.slimeId,
			name = rawItem.name,
			rarityGrade = GRADE_BY_RANK[rank],
			probabilityPercent = rawItem.probabilityPercent,
			formattedOdds = string.format("%.4f%%", rawItem.probabilityPercent),
			guaranteedMutationId = rawItem.guaranteedMutationId,
			isUltra = (rawItem.isUltra == true) or (rank >= 9),
		})
		table.insert(builtItems, itemDef)
	end

	-- Validar que sume ~100.0000%
	assert(math.abs(totalProb - 100.0) < 0.001, "EventCrate probabilities must sum to 100.0000%")

	-- Construir la cola determinista pre-revelada (10 pasos) para usuarios restringidos
	local seedQueue: { string } = {}
	for idx = 1, 10 do
		local sourceItem = builtItems[((idx - 1) % #builtItems) + 1]
		table.insert(seedQueue, sourceItem.id)
	end

	local crateRecord = table.freeze({
		crateId = tpl.crateId,
		crateTitle = tpl.crateTitle,
		freeTokenCurrency = tpl.freeTokenCurrency or "AbyssalEventTokens",
		freeTokenCost = tpl.freeTokenCost or 100,
		openMultipliers = table.freeze(tpl.openMultipliers or { 1, 3, 10 }),
		items = table.freeze(builtItems),
		deterministicSeedQueue = table.freeze(seedQueue),
	})

	customCratesRegistry[tpl.crateId] = crateRecord
	return crateRecord
end

--[[
	Registra un Manifiesto de Actualización Semanal Completo en un solo paso declarativo.
]]
function SlimeFrameworkTemplate.registerWeeklyUpdate(manifest: WeeklyUpdateManifest): WeeklyUpdateManifest
	if manifest.newSlimes then
		for _, slimeTpl in manifest.newSlimes do
			SlimeFrameworkTemplate.defineSlimeFromTemplate(slimeTpl)
		end
	end
	if manifest.newMutations then
		for _, mutTpl in manifest.newMutations do
			SlimeFrameworkTemplate.defineMutationFromTemplate(mutTpl)
		end
	end
	if manifest.newCrates then
		for _, crateTpl in manifest.newCrates do
			SlimeFrameworkTemplate.defineEventCrateFromTemplate(crateTpl)
		end
	end

	local frozen = table.freeze(manifest)
	registeredUpdates[manifest.updateId] = frozen
	return frozen
end

function SlimeFrameworkTemplate.resolveSlime(slimeId: string): SlimeDefinition?
	return customSlimesRegistry[slimeId] or SlimeCatalogs.SLIMES_BY_ID[slimeId]
end

function SlimeFrameworkTemplate.resolveMutation(mutationId: string): MutationDefinition?
	return customMutationsRegistry[mutationId] or SlimeCatalogs.MUTATIONS_BY_ID[mutationId]
end

function SlimeFrameworkTemplate.getEventCrate(crateId: string)
	return customCratesRegistry[crateId]
end

function SlimeFrameworkTemplate.getAllUpdates(): { [string]: WeeklyUpdateManifest }
	return registeredUpdates
end

-- Registrar por defecto la Actualización Base Día 1 (UPD_01_LAUNCH) usando el propio framework
SlimeFrameworkTemplate.registerWeeklyUpdate({
	updateId = "UPD_01_LAUNCH",
	title = "Slimes Abismales: ¡Sumérgete y Escapa! — Lanzamiento Abisal",
	versionTag = "v1.0.0",
	newCrates = {
		{
			crateId = "CRATE_EVENT_DAY1",
			crateTitle = "Caja Especial Abisal Día 1",
			freeTokenCurrency = "AbyssalEventTokens",
			freeTokenCost = 100,
			openMultipliers = { 1, 3, 10 },
			items = {
				{ id = "EV-01", slimeId = "SLIME-001", name = "Slime de Rocío Luminiscente", rarityRank = 1, probabilityPercent = 45.0 },
				{ id = "EV-02", slimeId = "SLIME-025", name = "Slime Coralino Abisal", rarityRank = 2, probabilityPercent = 25.0, guaranteedMutationId = "MUT-01" },
				{ id = "EV-03", slimeId = "SLIME-060", name = "Slime de Magma Sulfúrico", rarityRank = 3, probabilityPercent = 15.0, guaranteedMutationId = "MUT-11" },
				{ id = "EV-04", slimeId = "SLIME-110", name = "Slime Cristaloide de Cuarzo", rarityRank = 4, probabilityPercent = 8.0, guaranteedMutationId = "MUT-04" },
				{ id = "EV-05", slimeId = "SLIME-150", name = "Slime Voltaico de Tormenta", rarityRank = 5, probabilityPercent = 4.0, guaranteedMutationId = "MUT-21" },
				{ id = "EV-06", slimeId = "SLIME-200", name = "Slime Espectral del Óculo", rarityRank = 6, probabilityPercent = 2.0, guaranteedMutationId = "MUT-38" },
				{ id = "EV-07", slimeId = "SLIME-250", name = "Slime Serafín de Luz", rarityRank = 7, probabilityPercent = 0.85, guaranteedMutationId = "MUT-44" },
				{ id = "EV-08", slimeId = "SLIME-290", name = "Slime Archidemonio de Foso", rarityRank = 8, probabilityPercent = 0.139, guaranteedMutationId = "MUT-45" },
				{ id = "EV-09", slimeId = "ULTRA-01", name = "Abyssal Huge: Coloso de Vacío", rarityRank = 9, probabilityPercent = 0.01, guaranteedMutationId = "MUT-02", isUltra = true },
				{ id = "EV-10", slimeId = "ULTRA-50", name = "Abyssal Titanic: Primigenio Singularidad", rarityRank = 10, probabilityPercent = 0.001, guaranteedMutationId = "MUT-43", isUltra = true },
			},
		},
	},
	activeAdminEventPresets = {
		"GlobalMutationStorm",
		"AbyssalInversion",
		"SpawnAbyssalCannon",
		"HostBroadcast",
		"PlayerTriggeredAbuse",
	},
})

return table.freeze(SlimeFrameworkTemplate)
