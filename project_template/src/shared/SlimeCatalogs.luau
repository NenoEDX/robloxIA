--!strict
--[[
	SlimeCatalogs.luau
	Catálogo Maestro de "SLIME PIT: Dive for Mutants!" (Abyssal Slime Core)
	- 10 Chasis Skinned Mesh con 4 huesos ("Base", "Centro", "Corona", "Nucleo")
	- 30 Biomas en 6 Macro-Estratos (Anillos) x 5 Sub-Biomas
	- 300 Slimes Regulares (Stat Slimes) + 50 Slimes Ultra Especiales (Huges & Titanics) = 350 Slimes
	- 50 Mutaciones Aleatorias en 5 Vectores con flag changesAppearance y prioridad visual
	- 10 Razas de Ascendencia, 25 Sets de Armadura, 30 Auras de Estatus
	- Caja Especial de Tienda de Evento Día 1 con 10 Slimes (desde Común hasta 0.001% / 0.0010%)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(SharedFolder:WaitForChild("Types"))

export type SlimeChassisDefinition = Types.SlimeChassisDefinition
export type SlimeRaceDefinition = Types.SlimeRaceDefinition
export type MutationDefinition = Types.MutationDefinition
export type SlimeDefinition = Types.SlimeDefinition
export type EventCrateItem = Types.EventCrateItem
export type SlimeRarityGradeId = Types.SlimeRarityGradeId

local SlimeCatalogs = {}

SlimeCatalogs.GAME_TITLE = "SLIME PIT: Dive for Mutants!"
SlimeCatalogs.GAME_SUBTITLE = "Abyssal Slime Core"
SlimeCatalogs.REGULAR_SLIME_COUNT = 300
SlimeCatalogs.ULTRA_SLIME_COUNT = 50
SlimeCatalogs.TOTAL_SLIME_COUNT = 350
SlimeCatalogs.TOTAL_BIOMES = 30
SlimeCatalogs.MACRO_RINGS = 6
SlimeCatalogs.SUB_BIOMES_PER_RING = 5
SlimeCatalogs.MAX_MUTATIONS_PER_SLIME = 10

-- V1 cosmetic auras; earned in the world, never purchased.
SlimeCatalogs.AURAS = table.freeze({
	{ id = "AURA-MOSS", name = "Sporelight", color = Color3.fromRGB(165, 246, 117) },
	{ id = "AURA-CRYSTAL", name = "Crystal pulse", color = Color3.fromRGB(68, 231, 225) },
	{ id = "AURA-AMBER", name = "Amber embers", color = Color3.fromRGB(255, 183, 84) },
})

SlimeCatalogs.SKINNED_BONES = table.freeze({
	"Base",
	"Centro",
	"Corona",
	"Nucleo",
})

-- 10 Grados de Rareza Codificados Cromáticamente (Tabla Pág. 7 del Documento)
SlimeCatalogs.RARITY_GRADES = table.freeze({
	GRADE_01_BASIC = {
		id = "GRADE_01_BASIC" :: SlimeRarityGradeId,
		rank = 1,
		name = "Basic",
		colorName = "Gris",
		color = Color3.fromRGB(165, 170, 178),
		juiceCoinBonusPercent = 20,
		abyssalGemBonusPercent = 10,
		critChancePercent = 2,
	},
	GRADE_02_RARE = {
		id = "GRADE_02_RARE" :: SlimeRarityGradeId,
		rank = 2,
		name = "Rare",
		colorName = "Verde",
		color = Color3.fromRGB(64, 214, 108),
		juiceCoinBonusPercent = 40,
		abyssalGemBonusPercent = 20,
		critChancePercent = 4,
	},
	GRADE_03_EPIC = {
		id = "GRADE_03_EPIC" :: SlimeRarityGradeId,
		rank = 3,
		name = "Epic",
		colorName = "Azul",
		color = Color3.fromRGB(58, 148, 255),
		juiceCoinBonusPercent = 60,
		abyssalGemBonusPercent = 30,
		critChancePercent = 7,
	},
	GRADE_04_LEGENDARY = {
		id = "GRADE_04_LEGENDARY" :: SlimeRarityGradeId,
		rank = 4,
		name = "Legendary",
		colorName = "Naranja",
		color = Color3.fromRGB(255, 148, 42),
		juiceCoinBonusPercent = 80,
		abyssalGemBonusPercent = 35,
		critChancePercent = 11,
	},
	GRADE_05_MYTHICAL = {
		id = "GRADE_05_MYTHICAL" :: SlimeRarityGradeId,
		rank = 5,
		name = "Mythical",
		colorName = "Rojo",
		color = Color3.fromRGB(255, 58, 76),
		juiceCoinBonusPercent = 100,
		abyssalGemBonusPercent = 40,
		critChancePercent = 14,
	},
	GRADE_06_EXOTIC = {
		id = "GRADE_06_EXOTIC" :: SlimeRarityGradeId,
		rank = 6,
		name = "Exotic",
		colorName = "Púrpura",
		color = Color3.fromRGB(186, 75, 255),
		juiceCoinBonusPercent = 120,
		abyssalGemBonusPercent = 45,
		critChancePercent = 17,
	},
	GRADE_07_DIVINE = {
		id = "GRADE_07_DIVINE" :: SlimeRarityGradeId,
		rank = 7,
		name = "Divine",
		colorName = "Amarillo",
		color = Color3.fromRGB(255, 224, 66),
		juiceCoinBonusPercent = 140,
		abyssalGemBonusPercent = 50,
		critChancePercent = 20,
	},
	GRADE_08_SUPERIOR = {
		id = "GRADE_08_SUPERIOR" :: SlimeRarityGradeId,
		rank = 8,
		name = "Superior",
		colorName = "Cian",
		color = Color3.fromRGB(48, 242, 255),
		juiceCoinBonusPercent = 160,
		abyssalGemBonusPercent = 55,
		critChancePercent = 23,
	},
	GRADE_09_CELESTIAL_I = {
		id = "GRADE_09_CELESTIAL_I" :: SlimeRarityGradeId,
		rank = 9,
		name = "Celestial I",
		colorName = "Rosa y Azul",
		color = Color3.fromRGB(255, 94, 218),
		juiceCoinBonusPercent = 180,
		abyssalGemBonusPercent = 60,
		critChancePercent = 26,
	},
	GRADE_10_CELESTIAL_II = {
		id = "GRADE_10_CELESTIAL_II" :: SlimeRarityGradeId,
		rank = 10,
		name = "Celestial II / Secret",
		colorName = "Azul Oscuro",
		color = Color3.fromRGB(28, 36, 138),
		juiceCoinBonusPercent = 200,
		abyssalGemBonusPercent = 65,
		critChancePercent = 30,
	},
})

-- 10 Geometrías Base de Slime (Chasis Skinned MeshPart)
SlimeCatalogs.CHASSES = table.freeze({
	{ id = "CHASSIS-01", name = "Esférico", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "ShortHop", guardianAttackRadius = 12, baseScale = Vector3.new(3.2, 2.8, 3.2) },
	{ id = "CHASSIS-02", name = "Gota", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "ElasticBounce", guardianAttackRadius = 14, baseScale = Vector3.new(3.0, 3.6, 3.0) },
	{ id = "CHASSIS-03", name = "Cubo Gelatinoso", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "TumbleSlam", guardianAttackRadius = 15, baseScale = Vector3.new(3.5, 3.5, 3.5) },
	{ id = "CHASSIS-04", name = "Cristaloide", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "ShardDash", guardianAttackRadius = 16, baseScale = Vector3.new(3.4, 4.0, 3.4) },
	{ id = "CHASSIS-05", name = "Tentacular", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "WhipCrawl", guardianAttackRadius = 18, baseScale = Vector3.new(3.8, 3.4, 3.8) },
	{ id = "CHASSIS-06", name = "Hidra", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "MultiLunge", guardianAttackRadius = 20, baseScale = Vector3.new(4.2, 4.2, 4.2) },
	{ id = "CHASSIS-07", name = "Espiral", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "VortexSpin", guardianAttackRadius = 18, baseScale = Vector3.new(3.6, 3.8, 3.6) },
	{ id = "CHASSIS-08", name = "Coloso", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "HeavyCharge", guardianAttackRadius = 24, baseScale = Vector3.new(5.5, 5.0, 5.5) },
	{ id = "CHASSIS-09", name = "Núcleo Flotante", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "LevitationPulse", guardianAttackRadius = 22, baseScale = Vector3.new(3.8, 4.4, 3.8) },
	{ id = "CHASSIS-10", name = "Leviatán", bones = SlimeCatalogs.SKINNED_BONES, movementPattern = "AbyssalSweep", guardianAttackRadius = 28, baseScale = Vector3.new(6.8, 6.0, 6.8) },
})

-- 10 Razas Principales (Linajes de Ascendencia)
SlimeCatalogs.RACES = table.freeze({
	{ id = "RACE-01", name = "Orgánica", factionBonusPercent = 10, primaryColor = Color3.fromRGB(92, 224, 114), accentFeature = "SporeCrest" },
	{ id = "RACE-02", name = "Elemental", factionBonusPercent = 15, primaryColor = Color3.fromRGB(255, 118, 54), accentFeature = "FlameCore" },
	{ id = "RACE-03", name = "Mineral", factionBonusPercent = 18, primaryColor = Color3.fromRGB(96, 198, 255), accentFeature = "CrystalSpikes" },
	{ id = "RACE-04", name = "Abisal", factionBonusPercent = 22, primaryColor = Color3.fromRGB(54, 88, 214), accentFeature = "BiolumFins" },
	{ id = "RACE-05", name = "Mecánica", factionBonusPercent = 25, primaryColor = Color3.fromRGB(198, 208, 220), accentFeature = "GyroRings" },
	{ id = "RACE-06", name = "Angelical", factionBonusPercent = 30, primaryColor = Color3.fromRGB(255, 244, 178), accentFeature = "SeraphWings" },
	{ id = "RACE-07", name = "Demoníaca", factionBonusPercent = 35, primaryColor = Color3.fromRGB(220, 38, 62), accentFeature = "ObsidianHorns" },
	{ id = "RACE-08", name = "Cósmica", factionBonusPercent = 42, primaryColor = Color3.fromRGB(168, 72, 255), accentFeature = "NebulaHalo" },
	{ id = "RACE-09", name = "Vacío", factionBonusPercent = 50, primaryColor = Color3.fromRGB(40, 22, 88), accentFeature = "SingularityRift" },
	{ id = "RACE-10", name = "Primordial", factionBonusPercent = 65, primaryColor = Color3.fromRGB(255, 198, 58), accentFeature = "AncientCrown" },
})

-- 50 Mutaciones Aleatorias en 5 Vectores Funcionales (IDs 1-50: MUT-01..MUT-50)
local RAW_MUTATION_GROUPS = {
	{
		vector = "ECONOMIC" :: Types.MutationVectorCategory,
		entries = {
			{ id = "MUT-01", name = "Dorada" },
			{ id = "MUT-02", name = "Arcoíris" },
			{ id = "MUT-03", name = "Radiante (Shiny)" },
			{ id = "MUT-04", name = "Cristalizada" },
			{ id = "MUT-05", name = "Midas" },
			{ id = "MUT-06", name = "Cuántica" },
			{ id = "MUT-07", name = "Diamantina" },
			{ id = "MUT-08", name = "Hiper-Inflacionaria" },
			{ id = "MUT-09", name = "Subastadora" },
			{ id = "MUT-10", name = "Sintética" },
		},
		baseStatBonus = 25,
		stepBonus = 8,
	},
	{
		vector = "COMBAT_GUARD" :: Types.MutationVectorCategory,
		entries = {
			{ id = "MUT-11", name = "Acorazada" },
			{ id = "MUT-12", name = "Vampírica" },
			{ id = "MUT-13", name = "Espinosa" },
			{ id = "MUT-14", name = "Berserker" },
			{ id = "MUT-15", name = "Fénix" },
			{ id = "MUT-16", name = "Colosal" },
			{ id = "MUT-17", name = "Fásica" },
			{ id = "MUT-18", name = "Impenetrable" },
			{ id = "MUT-19", name = "Detonante" },
			{ id = "MUT-20", name = "Parásita" },
		},
		baseStatBonus = 15,
		stepBonus = 5,
	},
	{
		vector = "ALCHEMICAL_JUICE" :: Types.MutationVectorCategory,
		entries = {
			{ id = "MUT-21", name = "Fermentada" },
			{ id = "MUT-22", name = "Destilada" },
			{ id = "MUT-23", name = "Catalítica" },
			{ id = "MUT-24", name = "Pura" },
			{ id = "MUT-25", name = "Volátil" },
			{ id = "MUT-26", name = "Viscosa" },
			{ id = "MUT-27", name = "Alquímica" },
			{ id = "MUT-28", name = "Transmutadora" },
			{ id = "MUT-29", name = "Saturada" },
			{ id = "MUT-30", name = "Efervescente" },
		},
		baseStatBonus = 18,
		stepBonus = 4,
	},
	{
		vector = "ABYSSAL_EXPLORATION" :: Types.MutationVectorCategory,
		entries = {
			{ id = "MUT-31", name = "Gravitatoria" },
			{ id = "MUT-32", name = "Luminiscente" },
			{ id = "MUT-33", name = "Abisal" },
			{ id = "MUT-34", name = "Magnética" },
			{ id = "MUT-35", name = "Veloz" },
			{ id = "MUT-36", name = "Anfibia" },
			{ id = "MUT-37", name = "Térmica" },
			{ id = "MUT-38", name = "Espectral" },
			{ id = "MUT-39", name = "Anclada" },
			{ id = "MUT-40", name = "Sónica" },
		},
		baseStatBonus = 20,
		stepBonus = 5,
	},
	{
		vector = "COSMIC_ADMIN" :: Types.MutationVectorCategory,
		entries = {
			{ id = "MUT-41", name = "Glitch" },
			{ id = "MUT-42", name = "Admin-Touched" },
			{ id = "MUT-43", name = "Singularidad" },
			{ id = "MUT-44", name = "Serafín" },
			{ id = "MUT-45", name = "Archidemonio" },
			{ id = "MUT-46", name = "Supernova" },
			{ id = "MUT-47", name = "Paradoja" },
			{ id = "MUT-48", name = "Omnisciente" },
			{ id = "MUT-49", name = "Corrupta" },
			{ id = "MUT-50", name = "Primigenia" },
		},
		baseStatBonus = 80,
		stepBonus = 15,
	},
}

local mutationsList: { MutationDefinition } = {}
local mutationsById: { [string]: MutationDefinition } = {}

for groupIdx, group in RAW_MUTATION_GROUPS do
	for idxInGroup, entry in group.entries do
		local numericId = (groupIdx - 1) * 10 + idxInGroup
		local mutId = entry.id
		local mutName = entry.name
		local isShiny = (numericId == 3)
		local isRainbow = (numericId == 2)
		local isGold = (numericId == 1)

		local statPercent = group.baseStatBonus + (idxInGroup - 1) * group.stepBonus
		if isGold then
			statPercent = 25
		elseif isRainbow then
			statPercent = 90
		elseif isShiny then
			statPercent = 100
		end

		local scaleMult = if isShiny then 1.72 elseif groupIdx == 5 then 1.35 + (idxInGroup * 0.05) else 1.0
		local mitigation = if groupIdx == 2 then 25 + (idxInGroup - 1) * 4 elseif groupIdx == 5 then 40 else 0
		local cdReduction = if numericId == 15 then 65 elseif groupIdx == 2 then 15 + idxInGroup * 3 else 0
		local alchemyBonus = if groupIdx == 3 then 15 + (idxInGroup - 1) * 3 else 0
		-- Algunas cambian la apariencia directamente (prioridad alta en Modo Rendimiento 3/6)
		local changesAppearance = (idxInGroup <= 6) or (groupIdx == 5)
		local visualPriority = (groupIdx * 20) + idxInGroup + (if changesAppearance then 50 else 0)

		local def: MutationDefinition = table.freeze({
			id = mutId,
			numericId = numericId,
			name = mutName,
			vector = group.vector,
			statPercentBonus = statPercent,
			scaleMultiplier = scaleMult,
			damageMitigationPercent = mitigation,
			cooldownReductionPercent = cdReduction,
			alchemyPurityBonusPercent = alchemyBonus,
			changesAppearance = changesAppearance,
			visualPriority = visualPriority,
			primaryColor = Color3.fromHSV(((numericId * 19) % 360) / 360, 0.82, 0.96),
			appearanceTag = "App_" .. mutId,
		})
		table.insert(mutationsList, def)
		mutationsById[mutId] = def
	end
end

SlimeCatalogs.MUTATIONS = table.freeze(mutationsList)
SlimeCatalogs.MUTATIONS_BY_ID = table.freeze(mutationsById)

-- Caja Especializada de la Tienda del Evento Día 1 (10 Slimes desde Común hasta 0.001% / 0.0010%)
-- Suma matemática exacta: 45 + 25 + 15 + 8 + 4 + 2 + 0.85 + 0.139 + 0.01 + 0.001 = 100.0000%
SlimeCatalogs.EVENT_CRATE_DAY1_POOL = table.freeze({
	{
		id = "EV-01",
		slimeId = "SLIME-001",
		name = "Slime de Rocío Luminiscente",
		rarityGrade = "GRADE_01_BASIC" :: SlimeRarityGradeId,
		probabilityPercent = 45.0,
		formattedOdds = "45.0000%",
		guaranteedMutationId = nil,
		isUltra = false,
	},
	{
		id = "EV-02",
		slimeId = "SLIME-025",
		name = "Slime Coralino Abisal",
		rarityGrade = "GRADE_02_RARE" :: SlimeRarityGradeId,
		probabilityPercent = 25.0,
		formattedOdds = "25.0000%",
		guaranteedMutationId = "MUT-01",
		isUltra = false,
	},
	{
		id = "EV-03",
		slimeId = "SLIME-060",
		name = "Slime de Magma Sulfúrico",
		rarityGrade = "GRADE_03_EPIC" :: SlimeRarityGradeId,
		probabilityPercent = 15.0,
		formattedOdds = "15.0000%",
		guaranteedMutationId = "MUT-11",
		isUltra = false,
	},
	{
		id = "EV-04",
		slimeId = "SLIME-110",
		name = "Slime Cristaloide de Cuarzo",
		rarityGrade = "GRADE_04_LEGENDARY" :: SlimeRarityGradeId,
		probabilityPercent = 8.0,
		formattedOdds = "8.0000%",
		guaranteedMutationId = "MUT-04",
		isUltra = false,
	},
	{
		id = "EV-05",
		slimeId = "SLIME-150",
		name = "Slime Voltaico de Tormenta",
		rarityGrade = "GRADE_05_MYTHICAL" :: SlimeRarityGradeId,
		probabilityPercent = 4.0,
		formattedOdds = "4.0000%",
		guaranteedMutationId = "MUT-21",
		isUltra = false,
	},
	{
		id = "EV-06",
		slimeId = "SLIME-200",
		name = "Slime Espectral del Óculo",
		rarityGrade = "GRADE_06_EXOTIC" :: SlimeRarityGradeId,
		probabilityPercent = 2.0,
		formattedOdds = "2.0000%",
		guaranteedMutationId = "MUT-38",
		isUltra = false,
	},
	{
		id = "EV-07",
		slimeId = "SLIME-250",
		name = "Slime Serafín de Luz",
		rarityGrade = "GRADE_07_DIVINE" :: SlimeRarityGradeId,
		probabilityPercent = 0.85,
		formattedOdds = "0.8500%",
		guaranteedMutationId = "MUT-44",
		isUltra = false,
	},
	{
		id = "EV-08",
		slimeId = "SLIME-290",
		name = "Slime Archidemonio de Foso",
		rarityGrade = "GRADE_08_SUPERIOR" :: SlimeRarityGradeId,
		probabilityPercent = 0.139,
		formattedOdds = "0.1390%",
		guaranteedMutationId = "MUT-45",
		isUltra = false,
	},
	{
		id = "EV-09",
		slimeId = "ULTRA-01",
		name = "Abyssal Huge: Coloso de Vacío",
		rarityGrade = "GRADE_09_CELESTIAL_I" :: SlimeRarityGradeId,
		probabilityPercent = 0.01,
		formattedOdds = "0.0100%",
		guaranteedMutationId = "MUT-02",
		isUltra = true,
	},
	{
		id = "EV-10",
		slimeId = "ULTRA-50",
		name = "Abyssal Titanic: Primigenio Singularidad",
		rarityGrade = "GRADE_10_CELESTIAL_II" :: SlimeRarityGradeId,
		probabilityPercent = 0.001,
		formattedOdds = "0.0010%",
		guaranteedMutationId = "MUT-43",
		isUltra = true,
	},
})

local GRADE_ORDER: { SlimeRarityGradeId } = {
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

-- Generador determinista de los 300 Slimes Regulares (30 Biomas x 10 Variantes) + 50 Ultra Especiales
local allSlimesById: { [string]: SlimeDefinition } = {}

for biome = 1, SlimeCatalogs.TOTAL_BIOMES do
	local macroRing = math.ceil(biome / SlimeCatalogs.SUB_BIOMES_PER_RING)
	for variant = 1, 10 do
		local index = (biome - 1) * 10 + variant
		local slimeId = string.format("SLIME-%03d", index)
		local chassis = SlimeCatalogs.CHASSES[variant]
		local race = SlimeCatalogs.RACES[((biome + variant - 2) % 10) + 1]
		local grade = GRADE_ORDER[variant]
		local basePower = math.floor(15 * (1.34 ^ (biome - 1)) * (1 + (variant - 1) * 0.28))

		allSlimesById[slimeId] = table.freeze({
			id = slimeId,
			name = string.format("Slime %s [B%02d-V%d]", chassis.name, biome, variant),
			biomeIndex = biome,
			macroRingIndex = macroRing,
			chassisId = chassis.id,
			raceId = race.id,
			rarityGrade = grade,
			isUltraSpecial = false,
			ultraClass = "NONE" :: "NONE",
			anchoredBaseRatio = 1.0,
			anchoredMaxRatioLv99 = 1.0,
			basePower = basePower,
			baseCoinsPerSec = math.max(1, math.floor(basePower * 0.65)),
			baseStabilityHP = 100 + biome * 45 + variant * 15,
			juiceType = string.format("Jugo_Bioma_%02d", biome),
		})
	end
end

for ultraIdx = 1, SlimeCatalogs.ULTRA_SLIME_COUNT do
	local ultraId = string.format("ULTRA-%02d", ultraIdx)
	local isTitanic = (ultraIdx > 40) -- 40 Huges + 10 Titanics (Biomas 26-30)
	local biome = 26 + ((ultraIdx - 1) % 5)
	local chassis = SlimeCatalogs.CHASSES[((ultraIdx - 1) % 10) + 1]
	local race = SlimeCatalogs.RACES[((ultraIdx + 3) % 10) + 1]

	allSlimesById[ultraId] = table.freeze({
		id = ultraId,
		name = if isTitanic
			then string.format("Abyssal Titanic #%02d (%s)", ultraIdx - 40, race.name)
			else string.format("Abyssal Huge #%02d (%s)", ultraIdx, race.name),
		biomeIndex = biome,
		macroRingIndex = 6,
		chassisId = chassis.id,
		raceId = race.id,
		rarityGrade = if isTitanic then ("GRADE_10_CELESTIAL_II" :: SlimeRarityGradeId) else ("GRADE_09_CELESTIAL_I" :: SlimeRarityGradeId),
		isUltraSpecial = true,
		ultraClass = if isTitanic then ("TITANIC" :: "TITANIC") else ("HUGE" :: "HUGE"),
		anchoredBaseRatio = if isTitanic then 2.0 else 1.0000001,
		anchoredMaxRatioLv99 = if isTitanic then 4.0 else 2.0,
		basePower = 0, -- Calculado dinámicamente como % del Mejor Slime Regular del jugador
		baseCoinsPerSec = 0,
		baseStabilityHP = if isTitanic then 8000 else 4200,
		juiceType = "Esencia_Abisal_Pura",
	})
end

SlimeCatalogs.SLIMES_BY_ID = table.freeze(allSlimesById)

return table.freeze(SlimeCatalogs)
