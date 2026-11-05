--!strict
--[[
	SlimeCoreMath.luau
	Motor Matemático Central de "SLIME PIT: Dive for Mutants!" (Abyssal Slime Core)
	- Patrón Boost en 4 etapas (SetAdd -> SetPercent -> SetScale -> SetClamp)
	- Escalado Relativo Anclado (Best Stat Slime + Huges/Titanics 100%..1479%)
	- Mitigación Defensiva Hiperbólica corregida + Cooldown de Muerte (20s..68s)
	- Alquimia Probabilística estilo Fisch (precisión de 4 decimales sumando 100.0000%)
	- Captura Asegurada 1 vez al día GRATIS + Fórmula Anti-Pay-To-Fast por Brecha de Bioma (hasta 10,000+ Robux)
	- Salto de Tiempo Pagado (Skip Timer) para Cooldown y Fermentación Offline
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(SharedFolder:WaitForChild("Types"))
local SlimeCatalogs = require(SharedFolder:WaitForChild("SlimeCatalogs"))

export type DynamicCaptureQuote = Types.DynamicCaptureQuote

local SlimeCoreMath = {}

SlimeCoreMath.DAILY_FREE_CAPTURE_COOLDOWN_SEC = 86400 -- 24 horas para 1 Slime Asegurado Gratis al día
SlimeCoreMath.MAX_SAFE_DOUBLE = 9e15

-- Escalones oficiales de DeveloperProduct en Robux para mapear la cotización dinámica
SlimeCoreMath.ROBUX_PRODUCT_TIERS = table.freeze({
	{ priceRobux = 49, productId = 200101 },
	{ priceRobux = 99, productId = 200102 },
	{ priceRobux = 199, productId = 200103 },
	{ priceRobux = 399, productId = 200104 },
	{ priceRobux = 799, productId = 200105 },
	{ priceRobux = 1499, productId = 200106 },
	{ priceRobux = 2999, productId = 200107 },
	{ priceRobux = 4999, productId = 200108 },
	{ priceRobux = 10000, productId = 200109 },
	{ priceRobux = 19999, productId = 200110 },
})

--[[
	1. Ecuación Maestra de Rendimiento (Patrón Boost de 4 Etapas):
	Stage 1 (SetAdd): B_stat + sum(A_i)
	Stage 2 (SetPercent): 1 + sum(P_mut) + P_lvl
	Stage 3 (SetScale): prod(S_raza_and_crit)
	Stage 4 (SetClamp): min(C_max, Output)
]]
function SlimeCoreMath.computePetOutput(
	baseStat: number,
	flatRelicAdditions: { number },
	mutationPercents: { number },
	levelPercentBonus: number,
	scaleFactors: { number },
	clampMax: number?
): number
	-- Etapa 1: SetAdd
	local stageAdd = math.max(0, baseStat)
	for _, addVal in flatRelicAdditions do
		stageAdd += math.max(0, addVal)
	end

	-- Etapa 2: SetPercent
	local totalPercent = math.max(0, levelPercentBonus)
	for _, mutPct in mutationPercents do
		totalPercent += math.max(0, mutPct)
	end
	local stagePercent = stageAdd * (1 + (totalPercent / 100))

	-- Etapa 3: SetScale
	local stageScale = stagePercent
	for _, scaleFactor in scaleFactors do
		if scaleFactor > 0 then
			stageScale *= scaleFactor
		end
	end

	-- Etapa 4: SetClamp
	local cap = clampMax or SlimeCoreMath.MAX_SAFE_DOUBLE
	return math.min(cap, math.floor(stageScale))
end

--[[
	2. Escalado Relativo Anclado ("Best Stat Slime" + Huges & Titanics):
	Garantiza que las 50 unidades Ultra Especiales escalen del 100% (Huge Nv1)
	al 1479% (Rainbow Shiny Titanic Nv99) respecto al mejor Slime regular del jugador.
]]
function SlimeCoreMath.computeAnchoredUltraPower(
	bestRegularSlimePower: number,
	ultraClass: ("HUGE" | "TITANIC"),
	level: number,
	isGold: boolean,
	isRainbow: boolean,
	isShiny: boolean
): number
	local clampedLevel = math.clamp(level, 1, 99)
	local levelProgress = (clampedLevel - 1) / 98 -- 0.0 en Nv1 -> 1.0 en Nv99

	local baseRatio = if ultraClass == "TITANIC" then 2.0 else 1.0000001
	local levelGrowthRatio = if ultraClass == "TITANIC" then (2.0 * levelProgress) else (1.0 * levelProgress)
	local variantBonus = 0.0
	if isRainbow then
		variantBonus = 0.90
	elseif isGold then
		variantBonus = 0.25
	end

	local shinyFactor = if isShiny then 1.72 else 1.0
	local totalMultiplier = (baseRatio + levelGrowthRatio) * (1.0 + variantBonus) * shinyFactor

	-- Tope de cúspide Rainbow Shiny Titanic Nv99 (~14.79x = 1479%)
	return math.max(1, math.floor(math.max(1, bestRegularSlimePower) * totalMultiplier))
end

--[[
	3. Mitigación Defensiva Hiperbólica Corregida (Corrige el bug inverso de Nivel 1 del PDF):
	En Nivel 1 nunca multiplica el daño x60 ni divide por cero.
]]
function SlimeCoreMath.computeGuardianDamageReceived(
	guardianRawDamage: number,
	armorMitigationPercent: number,
	petLevel: number,
	petStars: number
): number
	local clampedArmor = math.clamp(armorMitigationPercent, 0, 85) / 100
	local safeLevel = math.max(1, petLevel)
	local safeStars = math.max(1, petStars)
	local hyperbolicDefense = 1 + (0.035 * (safeLevel - 1) * (1 + (safeStars - 1) * 0.25))
	local finalDamage = (math.max(0, guardianRawDamage) * (1 - clampedArmor)) / hyperbolicDefense
	return math.max(1, math.floor(finalDamage + 0.5))
end

--[[
	4. Cooldown de Regeneración de Mascota Derrotada (20s en Bioma 1 -> 68s en Bioma 30):
]]
function SlimeCoreMath.computePetDeathCooldown(
	currentBiome: number,
	mutationCooldownReductionPercent: number,
	potionCooldownReductionPercent: number
): number
	local baseCooldownSec = 20
	local clampedBiome = math.clamp(currentBiome, 1, 30)
	local biomeFactor = 1 + (0.08 * clampedBiome)
	local totalReduction = math.clamp((mutationCooldownReductionPercent + potionCooldownReductionPercent) / 100, 0, 0.75)
	return math.max(4, math.floor((baseCooldownSec * biomeFactor * (1 - totalReduction)) * 10) / 10)
end

--[[
	5. Alquimia de Jugos y Ponderación de Suerte Transparente (Estilo Fisch):
	Retorna una tabla de 10 probabilidades exactas que suman 100.0000%.
]]
function SlimeCoreMath.computeAlchemyProbabilities(
	juicePurity: number,
	totalLuckCoefficient: number
): { { gradeIndex: number, probabilityPercent: number, formattedOdds: string } }
	local baseWeights = { 4200, 2500, 1500, 900, 480, 250, 110, 45, 13, 2 }
	local rareThresholdIndex = 5 -- Grado V (Mythical) en adelante se beneficia de la suerte y pureza
	local safePurity = math.clamp(juicePurity, 1, 100)
	local safeLuck = math.max(0, totalLuckCoefficient)

	local dynamicWeights: { number } = table.create(10, 0)
	local weightSum = 0

	for k = 1, 10 do
		local wBase = baseWeights[k]
		local wk: number
		if k >= rareThresholdIndex then
			wk = wBase * (1 + safeLuck * (safePurity / (k * 10)))
		else
			wk = wBase / (1 + 0.5 * safeLuck)
		end
		dynamicWeights[k] = wk
		weightSum += wk
	end

	local results = {}
	for k = 1, 10 do
		local pct = (dynamicWeights[k] / weightSum) * 100
		table.insert(results, {
			gradeIndex = k,
			probabilityPercent = pct,
			formattedOdds = string.format("%.4f%%", pct),
		})
	end
	return results
end

--[[
	6. Curva de Renacimiento (Rebirth) Corregida + Suerte Asintótica por Esencias Doradas (GE):
]]
function SlimeCoreMath.computeRebirthCostAndMultiplier(
	rebirthIndex: number,
	goldenEssences: number
): { costCoins: number, productionMultiplier: number, asymptoticAlchemyLuckBonus: number }
	local r = math.max(0, math.floor(rebirthIndex))
	local ge = math.max(0, goldenEssences)
	local costCoins = math.floor(500 * (1.75 ^ r))
	-- Multiplicador de producción polinómico/escalonado que sí acompaña el crecimiento de costos
	local productionMultiplier = 1 + (r * 0.65) + ((r ^ 1.38) * 0.35)
	-- Asíntota exponencial reservada para suerte alquímica sin desbordar probabilidades
	local asymptoticLuck = (25 - 23 * math.exp(-0.0003 * ge)) / 100
	return {
		costCoins = costCoins,
		productionMultiplier = math.floor(productionMultiplier * 100) / 100,
		asymptoticAlchemyLuckBonus = math.floor(asymptoticLuck * 10000) / 10000,
	}
end

--[[
	7. Fórmula Anti-Pay-To-Fast de Captura Dinámica en Robux + 1 Asegurado Gratis al Día:
	- Una vez cada 24h (86400s), si el Slime pertenece a un bioma desbloqueado (o hasta +1 bioma),
	  el jugador recibe la Captura Asegurada GRATIS (0 Robux).
	- Si ya usó su captura diaria O si se tira de cabeza al fondo del pozo (ej. de Bioma 1 a Bioma 30)
	  a por un Slime del que tiene 0% de probabilidad natural, el precio escala con la brecha:
	  RobuxCost = round( C_base(B_slime) * ((1 + 0.18 * DeltaB) ^ 1.65) * T_mult )
	  Cuando un jugador de Bioma 1 salta al Bioma 30 por un Slime caro/Ultra, cobra 10,000+ Robux.
]]
function SlimeCoreMath.computeDynamicCaptureQuote(
	playerMaxUnlockedBiome: number,
	targetSlimeBiome: number,
	isUltraSlime: boolean,
	isTitanicSlime: boolean,
	lastDailyFreeCaptureOsTime: number,
	currentOsTime: number
): DynamicCaptureQuote
	local safePlayerBiome = math.clamp(playerMaxUnlockedBiome, 1, 30)
	local safeTargetBiome = math.clamp(targetSlimeBiome, 1, 30)
	local biomeGap = math.max(0, safeTargetBiome - safePlayerBiome)

	local elapsedSinceDaily = math.max(0, currentOsTime - lastDailyFreeCaptureOsTime)
	local dailyCooldownReady = (lastDailyFreeCaptureOsTime <= 0)
		or (elapsedSinceDaily >= SlimeCoreMath.DAILY_FREE_CAPTURE_COOLDOWN_SEC)
	local dailyRemainingSec = if dailyCooldownReady
		then 0
		else (SlimeCoreMath.DAILY_FREE_CAPTURE_COOLDOWN_SEC - elapsedSinceDaily)

	-- El asegurado diario gratuito aplica si el cooldown de 24h está listo y no está saltando >1 bioma bloqueado ni es Titanic
	local isDailyFreeAvailable = dailyCooldownReady and (biomeGap <= 1) and (not isTitanicSlime)

	-- Probabilidad natural: 0% si el jugador se tiró a un bioma más profundo del que tiene desbloqueado
	local naturalChance = if biomeGap > 0
		then 0
		else math.max(0.05, math.floor((35 / (1 + (safeTargetBiome - 1) * 0.35)) * 100) / 100)

	local baseBiomeRobux = 49 + (15 * safeTargetBiome) -- 64 R$ en Bioma 1 -> 499 R$ en Bioma 30
	local gapPenaltyFactor = (1 + (0.18 * biomeGap)) ^ 1.65
	local tierMult = if isTitanicSlime then 2.2 elseif isUltraSlime then 1.45 else 1.0

	local rawRobux = math.floor((baseBiomeRobux * gapPenaltyFactor * tierMult) + 0.5)
	if biomeGap >= 25 and isUltraSlime then
		rawRobux = math.max(10000, rawRobux)
	end

	local finalRobux = if isDailyFreeAvailable then 0 else rawRobux

	-- Mapear al DeveloperProduct más cercano para cobro real en MarketplaceService
	local mappedProductId = SlimeCoreMath.ROBUX_PRODUCT_TIERS[1].productId
	for _, tier in SlimeCoreMath.ROBUX_PRODUCT_TIERS do
		mappedProductId = tier.productId
		if tier.priceRobux >= finalRobux then
			break
		end
	end

	return {
		playerMaxBiome = safePlayerBiome,
		targetSlimeBiome = safeTargetBiome,
		biomeGap = biomeGap,
		isDailyFreeAvailable = isDailyFreeAvailable,
		dailyFreeCooldownRemainingSec = dailyRemainingSec,
		computedRobuxCost = finalRobux,
		mappedDeveloperProductId = mappedProductId,
		naturalCatchChancePercent = naturalChance,
	}
end

--[[
	8. Cálculo de Robux para Saltar Tiempo (Skip Timer):
	- Cooldown de escuadrón de mascotas derrotadas
	- Fermentación Alquímica Offline (1 a 12 horas)
]]
function SlimeCoreMath.computeSkipTimerRobux(remainingSeconds: number, timerCategory: ("PET_COOLDOWN" | "FERMENTATION_VAT" | "DAILY_CAPTURE_RESET")): number
	local safeSec = math.max(0, remainingSeconds)
	if safeSec == 0 then
		return 0
	end
	if timerCategory == "PET_COOLDOWN" then
		return math.clamp(math.ceil(safeSec * 0.75), 19, 149)
	elseif timerCategory == "FERMENTATION_VAT" then
		local remainingMinutes = safeSec / 60
		return math.clamp(math.ceil(remainingMinutes * 1.25), 29, 899)
	else
		return 399
	end
end

return table.freeze(SlimeCoreMath)
