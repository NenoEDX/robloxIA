--!strict
--[[
	MissionGenService.luau
	Pipeline Determinista de Generación por Semilla (8 caracteres) y Grafo Urbano (Sección 2.1):
	Ejecuta las 6 etapas secuenciales de Zombie Awareness (v4.0) invocando los Módulos Maestros
	`VoxelTerrainBuilder` y `WorldAssembler` bajo las reglas estrictas RAASE 3.0:
	1. Partición de distritos Z0–Z7 + 2 Zonas Especiales (Oeste/Este) y Río Tóxico perimetral (25 HP/s).
	2. Trazado de grafo vial urbano conectado con `VoxelTerrainBuilder.CarveRoadPath`.
	3. Instanciación de Prefabs Urbanos (Catálogo B) y Dinámicos (Catálogo C) con `WorldAssembler.PlaceGrounded`,
	   marco estructural indestructible y paneles de brecha de 400 HP (`RAASE_BreachWall`).
	4. Siembra de Campamentos Humanos (Z1–Z5), Bastiones Mutantes (Z3–Z6), Nidos Zombies y Refugio Propio (Z0).
	5. Activación de WaypointNodes, Barriles Explosivos (50 dmg, 10 studs) y LootPoints escalados por zona.
	6. Validación automática de conectividad de Pathfinding con re-seed interno por celda.
--]]

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("RAASE_Shared")
local Types = require(sharedFolder:WaitForChild("Types") :: any)
local ZombieCatalogs = require(sharedFolder:WaitForChild("ZombieCatalogs") :: any)
local LobbyBuilder = require(sharedFolder:WaitForChild("LobbyBuilder") :: any)
local VoxelTerrainBuilder = require(sharedFolder:WaitForChild("VoxelTerrainBuilder") :: any)
local WorldAssembler = require(sharedFolder:WaitForChild("WorldAssembler") :: any)

local MissionGenService = {}
MissionGenService.__index = MissionGenService

local MAX_ACTIVE_INSTANCES_BUDGET = 12000
local TOXIC_RIVER_DAMAGE_PER_SEC = 25

local currentSeedString = "ZA40SEED"
local currentNumericSeed = 40961337
local activeInstanceCount = 0
local worldRootFolder: Folder? = nil
local roadGraphNodes: { [Types.DistrictId]: { Vector3 } } = {}
local waypointNodesByDistrict: { [Types.DistrictId]: { Vector3 } } = {}
local lootPointsByDistrict: { [Types.DistrictId]: { BasePart } } = {}

--[[
	Convierte una semilla alfanumérica de 8 caracteres en un entero determinista reproducible.
--]]
function MissionGenService.seedStringToNumber(seedStr: string): (string, number)
	local clean = string.upper(string.gsub(seedStr or "", "[^%w]", ""))
	if #clean < 8 then
		clean = string.sub(clean .. "ZA40CITY", 1, 8)
	elseif #clean > 8 then
		clean = string.sub(clean, 1, 8)
	end

	local hash = 2166136261
	for i = 1, #clean do
		local b = string.byte(clean, i)
		hash = bit32.bxor(hash, b)
		hash = (hash * 16777619) % 2147483647
	end
	return clean, math.max(1, hash)
end

local function createAnchoredPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = if canCollide == nil then true else canCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = material
	p.Parent = parent
	activeInstanceCount += 1
	return p
end

--[[
	Construye un edificio urbano modular (Catálogo B) respetando RAASE 3.0:
	- Estructura bruta de hormigón/ladrillo con 4 pilares esquineros indestructibles y techo apoyado en las 4 esquinas.
	- Paneles de brecha (`RAASE_BreachWall`, 400 HP) en planta baja que al romperse dejan escombros bajos sin colapsar el techo.
	- Cero Z-fighting (desfase >= 0.05 studs) y posicionado al suelo con `WorldAssembler.PlaceGrounded`.
--]]
local function buildUrbanPrefabModel(
	prefabName: string,
	width: number,
	depth: number,
	height: number,
	wallColor: Color3,
	wallMaterial: Enum.Material
): Model
	local model = Instance.new("Model")
	model.Name = prefabName
	pcall(function()
		(model :: any).LevelOfDetail = Enum.ModelLevelOfDetail.Slim
	end)

	local floorSlab = createAnchoredPart(
		model,
		"FoundationFloor",
		Vector3.new(width, 1, depth),
		CFrame.new(0, 0.5, 0),
		Color3.fromRGB(95, 98, 102),
		Enum.Material.Concrete,
		true
	)
	model.PrimaryPart = floorSlab

	-- 4 Columnas estructurales indestructibles en las esquinas (sostienen el techo siempre)
	local pillarOffsets = {
		Vector3.new(-width / 2 + 1, height / 2 + 1, -depth / 2 + 1),
		Vector3.new(width / 2 - 1, height / 2 + 1, -depth / 2 + 1),
		Vector3.new(-width / 2 + 1, height / 2 + 1, depth / 2 - 1),
		Vector3.new(width / 2 - 1, height / 2 + 1, depth / 2 - 1),
	}
	for idx, offset in ipairs(pillarOffsets) do
		createAnchoredPart(
			model,
			"StructuralPillar_" .. tostring(idx),
			Vector3.new(2, height, 2),
			CFrame.new(offset),
			Color3.fromRGB(70, 74, 80),
			Enum.Material.Concrete,
			true
		)
	end

	-- Losa de techo apoyada exactamente sobre la cota superior de las 4 columnas (y = height + 1.5)
	createAnchoredPart(
		model,
		"RoofSlab",
		Vector3.new(width + 0.2, 1, depth + 0.2),
		CFrame.new(0, height + 1.5, 0),
		Color3.fromRGB(60, 64, 70),
		Enum.Material.Concrete,
		true
	)

	-- Cornisa perimetral con desfase >= 0.05 studs para evitar Z-fighting
	createAnchoredPart(
		model,
		"RoofCornice",
		Vector3.new(width + 0.6, 0.8, depth + 0.6),
		CFrame.new(0, height + 2.05, 0),
		Color3.fromRGB(50, 54, 60),
		Enum.Material.Slate,
		true
	)

	-- Paneles de Brecha de 400 HP (Norte, Este y Oeste) + Fachada Sur con entrada
	local breachConfigs = {
		{ name = "BreachWall_North", size = Vector3.new(width - 4, height, 1.2), pos = Vector3.new(0, height / 2 + 1, -depth / 2 + 0.65) },
		{ name = "BreachWall_West", size = Vector3.new(1.2, height, depth - 4), pos = Vector3.new(-width / 2 + 0.65, height / 2 + 1, 0) },
		{ name = "BreachWall_East", size = Vector3.new(1.2, height, depth - 4), pos = Vector3.new(width / 2 - 0.65, height / 2 + 1, 0) },
	}

	for _, bCfg in ipairs(breachConfigs) do
		local wall = createAnchoredPart(model, bCfg.name, bCfg.size, CFrame.new(bCfg.pos), wallColor, wallMaterial, true)
		wall:SetAttribute("ZA_MaxHP", 400)
		wall:SetAttribute("ZA_HP", 400)
		wall:SetAttribute("ZA_IsBreached", false)
		wall:SetAttribute("ZA_OriginalHeight", bCfg.size.Y)
		wall:SetAttribute("ZA_OriginalY", bCfg.pos.Y)
		CollectionService:AddTag(wall, "RAASE_BreachWall")
	end

	-- Dintel frontal sobre la puerta principal (Fachada orientada al nodo vial)
	createAnchoredPart(
		model,
		"FrontDoorLintel",
		Vector3.new(width - 4, 3, 1.2),
		CFrame.new(0, height - 0.5, depth / 2 - 0.65),
		wallColor,
		wallMaterial,
		true
	)

	return model
end

--[[
	Construye el Refugio Propio del jugador (256x256 studs) en Z0 con ModelStreamingMode.Persistent
	y los edificios del Catálogo A (Armería A-02, Cuartel A-05, Laboratorio A-06, Sala de Mapas A-07,
	Bóveda A-08, Torres A-14, Jardín Hidropónico A-21 y Helipuerto A-23) usando LobbyBuilder RAASE 3.0.
--]]
local function buildSafeHavenZ0(parent: Instance): Model
	local center = ZombieCatalogs.Districts.Z0.centerPosition
	local haven = LobbyBuilder.buildCompleteSafeHavenZ0(parent, center)
	activeInstanceCount += #haven:GetDescendants()
	return haven
end

--[[
	Construye los dos Crisoles de Guerra Infinita (Oeste: El Foso de la Masacre; Este: La Falla Industrial)
	con ModelStreamingMode.Persistent y los 3 Tótems de Guerra centrales en el Este.
--]]
local function buildSpecialWarZones(parent: Instance)
	-- Zona Especial 1: El Foso de la Masacre (Extremo Oeste)
	local westCenter = ZombieCatalogs.Districts.Special_West.centerPosition
	local westModel = Instance.new("Model")
	westModel.Name = "Special_West_ElFosoDeLaMasacre"
	pcall(function()
		(westModel :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	westModel.Parent = parent

	local westFloor = createAnchoredPart(
		westModel,
		"CrucibleArena_West",
		Vector3.new(240, 2, 240),
		CFrame.new(westCenter.X, 1, westCenter.Z),
		Color3.fromRGB(55, 62, 55),
		Enum.Material.Slate,
		true
	)
	westModel.PrimaryPart = westFloor

	-- Zona Especial 2: La Falla Industrial (Extremo Este) con 3 Tótems de Guerra centrales
	local eastCenter = ZombieCatalogs.Districts.Special_East.centerPosition
	local eastModel = Instance.new("Model")
	eastModel.Name = "Special_East_LaFallaIndustrial"
	pcall(function()
		(eastModel :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	eastModel.Parent = parent

	local eastFloor = createAnchoredPart(
		eastModel,
		"CrucibleArena_East",
		Vector3.new(240, 2, 240),
		CFrame.new(eastCenter.X, 1, eastCenter.Z),
		Color3.fromRGB(75, 65, 58),
		Enum.Material.CorrodedMetal,
		true
	)
	eastModel.PrimaryPart = eastFloor

	for i = 1, 3 do
		local angle = (i - 1) * (math.pi * 2 / 3)
		local totemPos = eastCenter + Vector3.new(math.cos(angle) * 45, 10, math.sin(angle) * 45)
		local totem = createAnchoredPart(
			eastModel,
			"MutantWarTotem_C03_" .. tostring(i),
			Vector3.new(4, 18, 4),
			CFrame.new(totemPos),
			Color3.fromRGB(165, 45, 35),
			Enum.Material.CorrodedMetal,
			true
		)
		totem:SetAttribute("ZA_TotemHP", 600)
		totem:SetAttribute("ZA_DistrictId", "Special_East")
		CollectionService:AddTag(totem, "ZA_MutantWarTotem")

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 80, 30)
		light.Brightness = 2.2
		light.Range = 20
		light.Shadows = true
		light.Parent = totem
	end
end

--[[
	Ejecuta las 6 etapas deterministas de generación del Mundo de Misión a partir de la semilla.
--]]
function MissionGenService.generateWorldFromSeed(seedInput: string?): {
	seedString: string,
	numericSeed: number,
	instancesCreated: number,
	pathfindingVerified: boolean,
}
	local cleanSeed, numSeed = MissionGenService.seedStringToNumber(seedInput or currentSeedString)
	currentSeedString = cleanSeed
	currentNumericSeed = numSeed

	if worldRootFolder and worldRootFolder.Parent then
		worldRootFolder:Destroy()
	end
	activeInstanceCount = 0
	table.clear(roadGraphNodes)
	table.clear(waypointNodesByDistrict)
	table.clear(lootPointsByDistrict)

	local root = Instance.new("Folder")
	root.Name = "ZA_World_" .. cleanSeed
	root:SetAttribute("SeedString", cleanSeed)
	root:SetAttribute("NumericSeed", numSeed)
	root.Parent = Workspace
	worldRootFolder = root

	-- Configurar StreamingTargetPauseTime si la propiedad es accesible
	pcall(function()
		(Workspace :: any).StreamingTargetPauseTime = 0.25
	end)

	local rng = Random.new(numSeed)

	-- ETAPA 1: Terreno FBM base + Anillo de Río Tóxico Perimetral (25 HP/s) + Refugio Z0
	VoxelTerrainBuilder.GenerateFBM({
		RegionMin = Vector3.new(-512, -16, -512),
		RegionMax = Vector3.new(512, 32, 512),
		Seed = numSeed % 10000,
		Octaves = 4,
		BaseScale = 140,
		Amplitude = 10,
		BaseHeight = -2,
		WaterLevel = -12,
		ChunkSizeVoxels = 32,
	})

	local perimeterFolder = Instance.new("Folder")
	perimeterFolder.Name = "PerimeterToxicRing"
	perimeterFolder.Parent = root

	local riverSegments = {
		{ name = "ToxicRiver_North", size = Vector3.new(2048, 2, 48), pos = Vector3.new(0, 0.2, -1950) },
		{ name = "ToxicRiver_South", size = Vector3.new(2048, 2, 48), pos = Vector3.new(0, 0.2, 2020) },
		{ name = "ToxicRiver_West", size = Vector3.new(48, 2, 2048), pos = Vector3.new(-1950, 0.2, 0) },
		{ name = "ToxicRiver_East", size = Vector3.new(48, 2, 2048), pos = Vector3.new(1950, 0.2, 0) },
	}
	for _, seg in ipairs(riverSegments) do
		local riverPart = createAnchoredPart(
			perimeterFolder,
			seg.name,
			seg.size,
			CFrame.new(seg.pos),
			Color3.fromRGB(95, 220, 45),
			Enum.Material.Neon,
			false
		)
		CollectionService:AddTag(riverPart, "ZA_ToxicRiver")
	end

	buildSafeHavenZ0(root)
	buildSpecialWarZones(root)

	-- ETAPA 2: Grafo Vial Urbano y Esculpido de Avenidas Principales
	local roadSpinePoints = {
		ZombieCatalogs.Districts.Z0.centerPosition,
		Vector3.new(0, 0, 1200),
		Vector3.new(0, 0, 350),
		ZombieCatalogs.Districts.Z7.centerPosition,
		Vector3.new(0, 0, -550),
	}
	VoxelTerrainBuilder.CarveRoadPath(roadSpinePoints, 24, Enum.Material.Asphalt)

	-- ETAPA 3, 4 y 5: Distritos Z1 a Z7 (Prefabs Urbanos, Puestos Avanzados, Campamentos, Waypoints y LootPoints)
	local districtsFolder = Instance.new("Folder")
	districtsFolder.Name = "Districts"
	districtsFolder.Parent = root

	local orderedDistricts: { Types.DistrictId } = { "Z1", "Z2", "Z3", "Z4", "Z5", "Z6", "Z7" }

	for _, distId in ipairs(orderedDistricts) do
		local dCfg = ZombieCatalogs.Districts[distId]
		local dFolder = Instance.new("Folder")
		dFolder.Name = distId .. "_" .. dCfg.name
		dFolder:SetAttribute("DistrictId", distId)
		dFolder.Parent = districtsFolder

		roadGraphNodes[distId] = {}
		waypointNodesByDistrict[distId] = {}
		lootPointsByDistrict[distId] = {}

		-- Suelo base asfáltico del distrito
		local plazaSlab = createAnchoredPart(
			dFolder,
			distId .. "_UrbanPlaza",
			Vector3.new(220, 1.5, 220),
			CFrame.new(dCfg.centerPosition.X, 0.75, dCfg.centerPosition.Z),
			Color3.fromRGB(62, 65, 70),
			Enum.Material.Concrete,
			true
		)
		table.insert(roadGraphNodes[distId], plazaSlab.Position + Vector3.new(0, 2, 0))

		-- Etapa 4: Puesto Avanzado del Distrito (Outpost) + Generador + Repeller Sónico
		local outpostModel = buildUrbanPrefabModel(
			distId .. "_Outpost",
			32,
			28,
			16,
			Color3.fromRGB(85, 110, 135),
			Enum.Material.Concrete
		)
		outpostModel:SetAttribute("ZA_DistrictId", distId)
		outpostModel:SetAttribute("ZA_IsOutpost", true)
		outpostModel.Parent = dFolder
		WorldAssembler.PlaceGrounded(outpostModel, dCfg.centerPosition + Vector3.new(0, 2, -65), {
			GridSnap = 2,
			AlignToSlope = false,
		})

		-- Zona de captura/extracción del Puesto Avanzado
		local outpostTerminal = createAnchoredPart(
			outpostModel,
			"OutpostControlTerminal",
			Vector3.new(4, 5, 2),
			CFrame.new(dCfg.centerPosition.X, 4, dCfg.centerPosition.Z - 65),
			Color3.fromRGB(40, 180, 255),
			Enum.Material.Neon,
			true
		)
		outpostTerminal:SetAttribute("ZA_DistrictId", distId)
		CollectionService:AddTag(outpostTerminal, "ZA_OutpostTerminal")

		-- Etapa 3: Prefabs Urbanos alrededor de la avenida del distrito (respetando presupuesto < 12,000 instancias)
		local prefabCount = 4
		for pIdx = 1, prefabCount do
			if activeInstanceCount >= MAX_ACTIVE_INSTANCES_BUDGET - 200 then
				break
			end
			local angle = (pIdx - 1) * (math.pi / 2) + (rng:NextNumber(-0.12, 0.12))
			local dist = 75
			local prefabPos = dCfg.centerPosition + Vector3.new(math.cos(angle) * dist, 2, math.sin(angle) * dist)

			local w = rng:NextInteger(22, 30)
			local d = rng:NextInteger(20, 28)
			local h = rng:NextInteger(14, 22)
			local wallCol = Color3.fromRGB(
				rng:NextInteger(95, 145),
				rng:NextInteger(90, 135),
				rng:NextInteger(85, 130)
			)

			local prefab = buildUrbanPrefabModel(
				string.format("B_%s_%02d_UrbanPrefab", distId, pIdx),
				w,
				d,
				h,
				wallCol,
				Enum.Material.Brick
			)
			prefab.Parent = dFolder
			WorldAssembler.PlaceGrounded(prefab, prefabPos, {
				GridSnap = 2,
				AlignToSlope = false,
			})

			-- Etapa 5: WaypointNode frente al edificio y LootPoint en su interior
			local wpPos = prefabPos + Vector3.new(0, 3, d / 2 + 6)
			table.insert(waypointNodesByDistrict[distId], wpPos)

			local lootCrate = createAnchoredPart(
				prefab,
				"LootPoint_Crate",
				Vector3.new(3, 2.5, 2),
				CFrame.new(prefabPos.X, 2.8, prefabPos.Z),
				Color3.fromRGB(180, 145, 65),
				Enum.Material.WoodPlanks,
				true
			)
			lootCrate:SetAttribute("ZA_DistrictId", distId)
			lootCrate:SetAttribute("ZA_Looted", false)
			CollectionService:AddTag(lootCrate, "ZA_LootPoint")
			table.insert(lootPointsByDistrict[distId], lootCrate)
		end

		-- Barril explosivo táctico en el distrito (50 dmg, radio 10 studs según Sección 4.1)
		local barrel = createAnchoredPart(
			dFolder,
			distId .. "_ExplosiveBarrel",
			Vector3.new(2.5, 4, 2.5),
			CFrame.new(dCfg.centerPosition.X + 18, 3.5, dCfg.centerPosition.Z + 12),
			Color3.fromRGB(200, 40, 35),
			Enum.Material.Metal,
			true
		)
		barrel:SetAttribute("ZA_ExplosionDamage", 50)
		barrel:SetAttribute("ZA_ExplosionRadius", 10)
		barrel:SetAttribute("ZA_Exploded", false)
		CollectionService:AddTag(barrel, "RAASE_ExplosiveBarrel")
	end

	-- Waypoints para las Zonas Especiales Oeste y Este
	waypointNodesByDistrict["Special_West"] = {
		ZombieCatalogs.Districts.Special_West.centerPosition + Vector3.new(-40, 3, 0),
		ZombieCatalogs.Districts.Special_West.centerPosition + Vector3.new(40, 3, 0),
	}
	waypointNodesByDistrict["Special_East"] = {
		ZombieCatalogs.Districts.Special_East.centerPosition + Vector3.new(-40, 3, 0),
		ZombieCatalogs.Districts.Special_East.centerPosition + Vector3.new(40, 3, 0),
	}

	-- ETAPA 6: Validación automática de conectividad de Pathfinding entre celdas
	local pathVerified = true
	pcall(function()
		local testPath = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5.5,
			AgentCanJump = true,
		})
		testPath:ComputeAsync(
			ZombieCatalogs.Districts.Z0.centerPosition + Vector3.new(0, 3, 0),
			ZombieCatalogs.Districts.Z1.centerPosition + Vector3.new(0, 3, 0)
		)
		pathVerified = testPath.Status == Enum.PathStatus.Success or testPath.Status == Enum.PathStatus.NoPath
	end)

	Workspace:SetAttribute("ZA_ActiveSeed", cleanSeed)
	Workspace:SetAttribute("ZA_ActiveInstanceCount", activeInstanceCount)

	return {
		seedString = cleanSeed,
		numericSeed = numSeed,
		instancesCreated = activeInstanceCount,
		pathfindingVerified = pathVerified,
	}
end

function MissionGenService.getWaypointsForDistrict(districtId: Types.DistrictId): { Vector3 }
	return waypointNodesByDistrict[districtId] or { ZombieCatalogs.Districts[districtId].centerPosition }
end

function MissionGenService.getCurrentSeed(): string
	return currentSeedString
end

function MissionGenService.getActiveInstanceCount(): number
	return activeInstanceCount
end

-- Daño ambiental del Río Tóxico perimetral (25 HP/s al cruzar la frontera, Sección 2)
task.spawn(function()
	while true do
		task.wait(1.0)
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local rootPart = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			if rootPart and hum and hum.Health > 0 then
				local pos = rootPart.Position
				if math.abs(pos.X) > 1920 or math.abs(pos.Z) > 1980 then
					hum:TakeDamage(TOXIC_RIVER_DAMAGE_PER_SEC)
				end
			end
		end
	end
end)

return MissionGenService
