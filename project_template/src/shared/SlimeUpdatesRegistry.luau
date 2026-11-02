--!strict
--[[
	SlimeUpdatesRegistry.luau
	ARCHIVO ÚNICO DE ACTUALIZACIONES RÁPIDAS (Zero-Token / $0 Template Pack Propio).
	Para sacar un Update nuevo cada semana en "Slimes Abismales: ¡Sumérgete y Escapa!",
	solo se agrega una entrada aquí en ~10 líneas sin tocar el resto del código del juego.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local SlimeFrameworkTemplate = require(SharedFolder:WaitForChild("SlimeFrameworkTemplate"))

local SlimeUpdatesRegistry = {}

-- Ejemplo listo para usar: Plantilla de Actualización Semanal (se activa en 1 llamada)
SlimeUpdatesRegistry.UPDATES = table.freeze({
	SlimeFrameworkTemplate.registerWeeklyUpdate({
		updateId = "UPD_02_ABYSSAL_TRENCH",
		title = "Actualización 2: Fosa de Singularidad",
		versionTag = "v1.1.0",
		newSlimes = {
			{
				id = "SLIME-UPD2-01",
				name = "Slime Bioluminiscente Real",
				biomeIndex = 12,
				chassisIndex = 4,
				raceIndex = 4,
				rarityRank = 6,
			},
			{
				id = "ULTRA-UPD2-TITANIC",
				name = "Abyssal Titanic: Emperador del Óculo",
				biomeIndex = 30,
				chassisIndex = 10,
				raceIndex = 10,
				rarityRank = 10,
				ultraClass = "TITANIC",
			},
		},
		newMutations = {
			{
				id = "MUT-UPD2-01",
				numericId = 51,
				name = "Hiper-Abisal",
				vector = "COSMIC_ADMIN",
				statPercentBonus = 150,
				scaleMultiplier = 1.85,
				changesAppearance = true,
				colorRGB = { 35, 245, 255 },
			},
		},
	}),
})

return table.freeze(SlimeUpdatesRegistry)
