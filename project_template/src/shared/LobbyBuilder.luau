--!strict
--[[
	LobbyBuilder.luau
	Constructor Arquitectónico de Alta Calidad para el Refugio Seguro (Lobby Z0, 256x256 studs)
	de Zombie Awareness (v4.0) bajo el estándar RAASE 3.0:
	- Cumple estrictamente la Doctrina Dual RAASE 3.0:
	  * Geometría de Roblox (Part, WedgePart, TrussPart) reservada EXCLUSIVAMENTE para arquitectura estructural:
	    cimientos, calzadas, aceras, murallas con adarves, columnas, muros con vanos reales de puertas y ventanas,
	    rodapiés, cornisas, tejados a dos/cuatro aguas y rampas.
	  * Cero decoración con bloques primitivos (cero muebles/barriles/cajas de cubos).
	  * Cero geometría flotante: toda cubierta, tejado, columna y cartel SurfaceGui descansa físicamente sobre muros/postes.
	  * Desfase >= 0.05 studs en cambios de plano para erradicar Z-fighting.
	  * Iluminación atmosférica y táctica con PointLight / SpotLight (Shadows = true) y terminales ProximityPrompt.
--]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local LobbyBuilder = {}

export type BuildingSpec = {
	id: string,
	name: string,
	titleText: string,
	subtitleText: string,
	center: Vector3,
	width: number,
	depth: number,
	wallHeight: number,
	facing: "North" | "South" | "East" | "West",
	wallColor: Color3,
	wallMaterial: Enum.Material,
	trimColor: Color3,
	roofColor: Color3,
	accentColor: Color3,
	glassRoof: boolean?,
}

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number?,
	canCollide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = if canCollide == nil then true else canCollide
	p.Transparency = transparency or 0
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cframe
	w.Anchored = true
	w.CanCollide = true
	w.Transparency = transparency or 0
	w.Color = color
	w.Material = material
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

local function attachWallSign(
	hostPart: BasePart,
	face: Enum.NormalId,
	title: string,
	subtitle: string,
	accentColor: Color3
)
	local sGui = Instance.new("SurfaceGui")
	sGui.Name = "ArchitecturalWallSign"
	sGui.Face = face
	sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sGui.PixelsPerStud = 32
	sGui.LightInfluence = 0.25
	sGui.Brightness = 1.4
	sGui.Parent = hostPart

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(0.92, 0, 0.78, 0)
	bg.Position = UDim2.new(0.04, 0, 0.11, 0)
	bg.BackgroundColor3 = Color3.fromRGB(16, 20, 26)
	bg.BackgroundTransparency = 0.08
	bg.BorderSizePixel = 0
	bg.Parent = sGui

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 4
	stroke.Parent = bg

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.94, 0, 0.56, 0)
	titleLbl.Position = UDim2.new(0.03, 0, 0.06, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.BuilderSansExtraBold
	titleLbl.Text = title
	titleLbl.TextColor3 = Color3.fromRGB(245, 248, 255)
	titleLbl.TextScaled = true
	titleLbl.Parent = bg

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(0.92, 0, 0.32, 0)
	subLbl.Position = UDim2.new(0.04, 0, 0.62, 0)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.BuilderSansBold
	subLbl.Text = subtitle
	subLbl.TextColor3 = accentColor
	subLbl.TextScaled = true
	subLbl.Parent = bg
end

--[[
	Construye un edificio arquitectónico completo con:
	- Losa de cimentación + rodapié perimetral (desfase >= 0.05 studs)
	- 4 Pilares estructurales esquineros
	- Muro frontal con vano real de puerta (8 studs ancho x 10 studs alto), jambas, dintel y letrero SurfaceGui
	- Muros laterales y trasero con vanos reales de ventana y paneles de Glass traslúcido
	- Losa de techo apoyada en las 4 esquinas + cornisa perimetral + tejado a dos aguas en WedgePart
	- Iluminación PointLight cálida/táctica en el interior y ProximityPrompt en el muro de fondo
--]]
function LobbyBuilder.buildArchitecturalBuilding(parent: Instance, spec: BuildingSpec): Model
	local model = Instance.new("Model")
	model.Name = spec.name
	model:SetAttribute("ZA_CatalogABuildingId", spec.id)
	model:SetAttribute("ZA_BuildingTier", 1)
	model.Parent = parent

	local rotY = 0
	if spec.facing == "North" then
		rotY = 0
	elseif spec.facing == "South" then
		rotY = math.pi
	elseif spec.facing == "East" then
		rotY = -math.pi / 2
	elseif spec.facing == "West" then
		rotY = math.pi / 2
	end

	local baseCF = CFrame.new(spec.center) * CFrame.Angles(0, rotY, 0)
	local W = spec.width
	local D = spec.depth
	local H = spec.wallHeight
	local wallThick = 1.5

	-- 1. Cimiento y piso interior (cota Y = 0.0 a 1.0)
	local floor = makePart(
		model,
		"FoundationFloor",
		Vector3.new(W, 1.0, D),
		baseCF * CFrame.new(0, 0.5, 0),
		Color3.fromRGB(68, 72, 78),
		Enum.Material.Concrete
	)
	model.PrimaryPart = floor

	-- Piso interior pulido con desfase de +0.06 studs para evitar Z-fighting
	makePart(
		model,
		"InteriorFloorTile",
		Vector3.new(W - 3.2, 0.12, D - 3.2),
		baseCF * CFrame.new(0, 1.06, 0),
		Color3.fromRGB(82, 88, 96),
		Enum.Material.Slate
	)

	-- 2. 4 Columnas estructurales de esquina (apoyadas sobre la losa hasta Y = H + 1)
	local pillarSize = Vector3.new(2.4, H, 2.4)
	local pillarCoords = {
		{ "Pillar_FrontLeft", Vector3.new(-W / 2 + 1.15, 1 + H / 2, -D / 2 + 1.15) },
		{ "Pillar_FrontRight", Vector3.new(W / 2 - 1.15, 1 + H / 2, -D / 2 + 1.15) },
		{ "Pillar_BackLeft", Vector3.new(-W / 2 + 1.15, 1 + H / 2, D / 2 - 1.15) },
		{ "Pillar_BackRight", Vector3.new(W / 2 - 1.15, 1 + H / 2, D / 2 - 1.15) },
	}
	for _, pc in ipairs(pillarCoords) do
		makePart(model, pc[1], pillarSize, baseCF * CFrame.new(pc[2]), spec.trimColor, Enum.Material.Concrete)
	end

	-- 3. Fachada Frontal (Z = -D/2 + wallThick/2) con puerta central real de 10 studs de ancho x 10 studs de alto
	local doorWidth = 10
	local doorHeight = 10
	local sidePanelWidth = (W - 4.4 - doorWidth) / 2
	local frontZ = -D / 2 + wallThick / 2

	if sidePanelWidth > 1 then
		makePart(
			model,
			"FrontWall_Left",
			Vector3.new(sidePanelWidth, H, wallThick),
			baseCF * CFrame.new(-doorWidth / 2 - sidePanelWidth / 2, 1 + H / 2, frontZ),
			spec.wallColor,
			spec.wallMaterial
		)
		makePart(
			model,
			"FrontWall_Right",
			Vector3.new(sidePanelWidth, H, wallThick),
			baseCF * CFrame.new(doorWidth / 2 + sidePanelWidth / 2, 1 + H / 2, frontZ),
			spec.wallColor,
			spec.wallMaterial
		)
	end

	-- Jambas metálicas del marco de entrada y dintel superior
	makePart(
		model,
		"DoorFrame_Left",
		Vector3.new(0.8, doorHeight, wallThick + 0.3),
		baseCF * CFrame.new(-doorWidth / 2 + 0.4, 1 + doorHeight / 2, frontZ),
		spec.trimColor,
		Enum.Material.CorrodedMetal
	)
	makePart(
		model,
		"DoorFrame_Right",
		Vector3.new(0.8, doorHeight, wallThick + 0.3),
		baseCF * CFrame.new(doorWidth / 2 - 0.4, 1 + doorHeight / 2, frontZ),
		spec.trimColor,
		Enum.Material.CorrodedMetal
	)

	local lintelHeight = H - doorHeight
	local lintel = makePart(
		model,
		"FrontSignLintel",
		Vector3.new(doorWidth + 4, lintelHeight, wallThick + 0.4),
		baseCF * CFrame.new(0, 1 + doorHeight + lintelHeight / 2, frontZ),
		spec.trimColor,
		Enum.Material.Concrete
	)
	attachWallSign(lintel, Enum.NormalId.Front, spec.titleText, spec.subtitleText, spec.accentColor)

	-- Marquesina estructural sobre la entrada apoyada en los pilares del marco
	makePart(
		model,
		"EntranceCanopy",
		Vector3.new(doorWidth + 6, 0.8, 4.5),
		baseCF * CFrame.new(0, 1 + doorHeight + 0.4, frontZ - 2.2),
		spec.roofColor,
		Enum.Material.CorrodedMetal
	)
	-- Franja de acento luminoso bajo la marquesina
	local accentStrip = makePart(
		model,
		"CanopyLightStrip",
		Vector3.new(doorWidth + 4, 0.25, 0.4),
		baseCF * CFrame.new(0, 1 + doorHeight - 0.05, frontZ - 3.8),
		spec.accentColor,
		Enum.Material.Neon
	)
	local entryLight = Instance.new("PointLight")
	entryLight.Color = spec.accentColor
	entryLight.Brightness = 1.8
	entryLight.Range = 22
	entryLight.Shadows = true
	entryLight.Parent = accentStrip

	-- 4. Muro Trasero Cerrado (Z = D/2 - wallThick/2) con panel técnico interior y ProximityPrompt
	local backZ = D / 2 - wallThick / 2
	local backWall = makePart(
		model,
		"BackWall_Solid",
		Vector3.new(W - 4.4, H, wallThick),
		baseCF * CFrame.new(0, 1 + H / 2, backZ),
		spec.wallColor,
		spec.wallMaterial
	)

	-- Placa mural interior para el terminal interactivo (pegada al muro trasero, cero flotación)
	local wallBoard = makePart(
		model,
		"InteriorOperationBoard",
		Vector3.new(12, 6, 0.4),
		baseCF * CFrame.new(0, 6.5, backZ - wallThick / 2 - 0.25),
		Color3.fromRGB(24, 30, 38),
		Enum.Material.SmoothPlastic
	)
	attachWallSign(wallBoard, Enum.NormalId.Front, spec.titleText, "PULSA [E] PARA OPERAR ESTACIÓN", spec.accentColor)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Operar " .. spec.titleText
	prompt.ObjectText = spec.subtitleText
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = wallBoard
	local _ = backWall

	-- Estrado arquitectónico interior frente al muro de operaciones + rampa de acceso y pórtico interior
	local daisDepth = 7.0
	local daisWidth = math.min(W - 8, 20)
	makePart(
		model,
		"InteriorRaisedDais",
		Vector3.new(daisWidth, 0.7, daisDepth),
		baseCF * CFrame.new(0, 1.35, backZ - wallThick / 2 - daisDepth / 2),
		spec.trimColor,
		Enum.Material.Concrete
	)
	makeWedge(
		model,
		"InteriorDaisStepRamp",
		Vector3.new(daisWidth - 4, 0.7, 2.5),
		baseCF * CFrame.new(0, 1.35, backZ - wallThick / 2 - daisDepth - 1.25),
		spec.trimColor,
		Enum.Material.Slate
	)
	for _, colSign in ipairs({ -1, 1 }) do
		makePart(
			model,
			"InteriorSupportColumn_" .. (if colSign < 0 then "Left" else "Right"),
			Vector3.new(1.6, H, 1.6),
			baseCF * CFrame.new(colSign * (daisWidth / 2 - 0.8), 1 + H / 2, 0),
			spec.trimColor,
			Enum.Material.CorrodedMetal
		)
	end
	makePart(
		model,
		"InteriorCeilingCrossBeam",
		Vector3.new(W - 3.2, 1.2, 1.8),
		baseCF * CFrame.new(0, 1 + H - 0.6, 0),
		spec.trimColor,
		Enum.Material.CorrodedMetal
	)

	-- 5. Muros Laterales Izquierdo y Derecho con Ventanales Reales de Glass
	local sideSpan = D - 4.4
	local sillHeight = 4.5
	local winHeight = H - 8.0
	local topBandHeight = H - sillHeight - winHeight

	for _, sideSign in ipairs({ -1, 1 }) do
		local sideX = sideSign * (W / 2 - wallThick / 2)
		local prefix = if sideSign < 0 then "LeftWall" else "RightWall"

		-- Muro inferior (antepecho) con rodapié
		makePart(
			model,
			prefix .. "_LowerSill",
			Vector3.new(wallThick, sillHeight, sideSpan),
			baseCF * CFrame.new(sideX, 1 + sillHeight / 2, 0),
			spec.wallColor,
			spec.wallMaterial
		)
		makePart(
			model,
			prefix .. "_Baseboard",
			Vector3.new(wallThick + 0.3, 1.2, sideSpan),
			baseCF * CFrame.new(sideX, 1.6, 0),
			spec.trimColor,
			Enum.Material.Slate
		)

		-- Panel de ventana en Glass traslúcido
		makePart(
			model,
			prefix .. "_WindowGlass",
			Vector3.new(0.4, winHeight, sideSpan - 4),
			baseCF * CFrame.new(sideX, 1 + sillHeight + winHeight / 2, 0),
			Color3.fromRGB(165, 215, 240),
			Enum.Material.Glass,
			0.45
		)

		-- Montantes verticales del ventanal
		for m = -1, 1 do
			makePart(
				model,
				prefix .. "_Mullion_" .. tostring(m + 2),
				Vector3.new(wallThick + 0.2, winHeight, 1.4),
				baseCF * CFrame.new(sideX, 1 + sillHeight + winHeight / 2, m * (sideSpan / 3)),
				spec.trimColor,
				Enum.Material.CorrodedMetal
			)
		end

		-- Friso superior sobre la ventana
		makePart(
			model,
			prefix .. "_UpperFrieze",
			Vector3.new(wallThick, topBandHeight, sideSpan),
			baseCF * CFrame.new(sideX, 1 + sillHeight + winHeight + topBandHeight / 2, 0),
			spec.wallColor,
			spec.wallMaterial
		)
	end

	-- 6. Cubierta Estructural (apoyada exactamente en cota Y = 1 + H sobre los 4 muros y pilares)
	local roofBaseY = 1 + H
	local roofMat = if spec.glassRoof then Enum.Material.Glass else Enum.Material.Concrete
	local roofTrans = if spec.glassRoof then 0.35 else 0

	local roofSlab = makePart(
		model,
		"RoofDeckSlab",
		Vector3.new(W + 1.2, 1.2, D + 1.2),
		baseCF * CFrame.new(0, roofBaseY + 0.6, 0),
		spec.roofColor,
		roofMat,
		roofTrans
	)

	-- Cornisa perimetral superior (desfase +0.06 studs)
	makePart(
		model,
		"RoofCorniceTrim",
		Vector3.new(W + 2.4, 1.0, D + 2.4),
		baseCF * CFrame.new(0, roofBaseY + 1.26, 0),
		spec.trimColor,
		Enum.Material.CorrodedMetal
	)

	-- Tejado superior a dos aguas en WedgePart apoyado sobre la losa de techo
	local gableHeight = 3.5
	makeWedge(
		model,
		"GableRoof_Left",
		Vector3.new(D + 0.8, gableHeight, W / 2),
		baseCF * CFrame.new(-W / 4, roofBaseY + 1.76 + gableHeight / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		spec.roofColor,
		if spec.glassRoof then Enum.Material.Glass else Enum.Material.CorrodedMetal,
		if spec.glassRoof then 0.35 else 0
	)
	makeWedge(
		model,
		"GableRoof_Right",
		Vector3.new(D + 0.8, gableHeight, W / 2),
		baseCF * CFrame.new(W / 4, roofBaseY + 1.76 + gableHeight / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		spec.roofColor,
		if spec.glassRoof then Enum.Material.Glass else Enum.Material.CorrodedMetal,
		if spec.glassRoof then 0.35 else 0
	)

	-- 7. Luminaria interior colgada del techo con PointLight y sombras reales
	local ceilingLamp = makePart(
		model,
		"CeilingLightFixture",
		Vector3.new(6, 0.4, 2),
		baseCF * CFrame.new(0, roofBaseY - 0.25, 0),
		Color3.fromRGB(255, 240, 200),
		Enum.Material.Neon
	)
	local interiorLight = Instance.new("PointLight")
	interiorLight.Color = Color3.fromRGB(255, 235, 195)
	interiorLight.Brightness = 2.2
	interiorLight.Range = 36
	interiorLight.Shadows = true
	interiorLight.Parent = ceilingLamp
	local _ = roofSlab

	return model
end

--[[
	Construye una Torre de Vigilancia Esquinera (A-14) con fuste de hormigón,
	casamata superior techada en sus 4 esquinas, escalera TrussPart y reflectores SpotLight.
--]]
local function buildCornerWatchtower(parent: Instance, name: string, cornerCenter: Vector3): Model
	local tower = Instance.new("Model")
	tower.Name = name
	tower:SetAttribute("ZA_CatalogABuildingId", "A-14")
	tower.Parent = parent

	local baseH = 26
	local shaft = makePart(
		tower,
		"TowerConcreteShaft",
		Vector3.new(16, baseH, 16),
		CFrame.new(cornerCenter + Vector3.new(0, baseH / 2, 0)),
		Color3.fromRGB(62, 68, 76),
		Enum.Material.Concrete
	)
	tower.PrimaryPart = shaft

	-- Plataforma de casamata en cota Y = baseH + 1
	local deckY = baseH + 1
	makePart(
		tower,
		"WatchtowerDeck",
		Vector3.new(20, 2, 20),
		CFrame.new(cornerCenter + Vector3.new(0, deckY, 0)),
		Color3.fromRGB(48, 54, 62),
		Enum.Material.CorrodedMetal
	)

	-- 4 Pilares de la casamata superior (altura 8 studs) + techo piramidal apoyado en las 4 esquinas
	local cabinH = 8
	for _, dx in ipairs({ -8.5, 8.5 }) do
		for _, dz in ipairs({ -8.5, 8.5 }) do
			makePart(
				tower,
				string.format("CabinPillar_%d_%d", math.floor(dx), math.floor(dz)),
				Vector3.new(2, cabinH, 2),
				CFrame.new(cornerCenter + Vector3.new(dx, deckY + 1 + cabinH / 2, dz)),
				Color3.fromRGB(42, 46, 52),
				Enum.Material.CorrodedMetal
			)
		end
	end

	-- Parapetos perimetrales de la casamata
	makePart(
		tower,
		"Parapet_N",
		Vector3.new(20, 3.2, 1.2),
		CFrame.new(cornerCenter + Vector3.new(0, deckY + 2.6, -9.4)),
		Color3.fromRGB(75, 82, 92),
		Enum.Material.Concrete
	)
	makePart(
		tower,
		"Parapet_S",
		Vector3.new(20, 3.2, 1.2),
		CFrame.new(cornerCenter + Vector3.new(0, deckY + 2.6, 9.4)),
		Color3.fromRGB(75, 82, 92),
		Enum.Material.Concrete
	)
	makePart(
		tower,
		"Parapet_W",
		Vector3.new(1.2, 3.2, 17.6),
		CFrame.new(cornerCenter + Vector3.new(-9.4, deckY + 2.6, 0)),
		Color3.fromRGB(75, 82, 92),
		Enum.Material.Concrete
	)
	makePart(
		tower,
		"Parapet_E",
		Vector3.new(1.2, 3.2, 17.6),
		CFrame.new(cornerCenter + Vector3.new(9.4, deckY + 2.6, 0)),
		Color3.fromRGB(75, 82, 92),
		Enum.Material.Concrete
	)

	-- Techo de la torre apoyado sobre los 4 pilares de casamata
	local roofY = deckY + 1 + cabinH + 0.6
	local roofCap = makePart(
		tower,
		"TowerRoofCap",
		Vector3.new(21.2, 1.2, 21.2),
		CFrame.new(cornerCenter + Vector3.new(0, roofY, 0)),
		Color3.fromRGB(38, 44, 52),
		Enum.Material.CorrodedMetal
	)

	local spot = Instance.new("SpotLight")
	spot.Color = Color3.fromRGB(255, 245, 215)
	spot.Brightness = 2.6
	spot.Range = 60
	spot.Angle = 65
	spot.Face = Enum.NormalId.Bottom
	spot.Shadows = true
	spot.Parent = roofCap

	-- Escalera estructural TrussPart adosada a la cara interior
	local truss = Instance.new("TrussPart")
	truss.Name = "TowerAccessLadder"
	truss.Size = Vector3.new(2, baseH + 2, 2)
	truss.CFrame = CFrame.new(cornerCenter + Vector3.new(0, (baseH + 2) / 2, 9.2))
	truss.Anchored = true
	truss.Color = Color3.fromRGB(95, 105, 115)
	truss.Material = Enum.Material.CorrodedMetal
	truss.Parent = tower

	return tower
end

--[[
	Construye las Murallas Perimetrales de 256x256 studs con Adarve transitable,
	contrafuertes estructurales y el Gran Pórtico Blindado Norte hacia Z1.
--]]
local function buildFortifiedPerimeter(parent: Instance, center: Vector3)
	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "PerimeterFortifications"
	wallFolder.Parent = parent

	local wallH = 18
	local wallThick = 5
	local halfSpan = 124
	local wallColor = Color3.fromRGB(72, 78, 86)
	local trimColor = Color3.fromRGB(52, 58, 66)

	-- Murallas Sur, Este y Oeste completas + Pasarelas superiores con parapeto
	local solidWalls = {
		{ "CurtainWall_South", Vector3.new(220, wallH, wallThick), Vector3.new(0, wallH / 2, halfSpan) },
		{ "CurtainWall_West", Vector3.new(wallThick, wallH, 220), Vector3.new(-halfSpan, wallH / 2, 0) },
		{ "CurtainWall_East", Vector3.new(wallThick, wallH, 220), Vector3.new(halfSpan, wallH / 2, 0) },
	}
	for _, sw in ipairs(solidWalls) do
		makePart(
			wallFolder,
			sw[1],
			sw[2],
			CFrame.new(center + sw[3]),
			wallColor,
			Enum.Material.Concrete
		)
		-- Coronación / pasarela transitable de la muralla
		makePart(
			wallFolder,
			sw[1] .. "_WalkwayTop",
			sw[2] * Vector3.new(1, 0, 1) + Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(center + sw[3] + Vector3.new(0, wallH / 2 + 0.6, 0)),
			trimColor,
			Enum.Material.Slate
		)
	end

	-- Muralla Norte dividida en dos lienzos dejando el Pórtico Blindado de 28 studs en el centro
	local gateWidth = 28
	local northSegLen = (220 - gateWidth) / 2
	makePart(
		wallFolder,
		"CurtainWall_NorthWest",
		Vector3.new(northSegLen, wallH, wallThick),
		CFrame.new(center + Vector3.new(-gateWidth / 2 - northSegLen / 2, wallH / 2, -halfSpan)),
		wallColor,
		Enum.Material.Concrete
	)
	makePart(
		wallFolder,
		"CurtainWall_NorthEast",
		Vector3.new(northSegLen, wallH, wallThick),
		CFrame.new(center + Vector3.new(gateWidth / 2 + northSegLen / 2, wallH / 2, -halfSpan)),
		wallColor,
		Enum.Material.Concrete
	)

	-- Gran Pórtico Blindado Norte (Salida a Z1–Z7)
	local gatePos = center + Vector3.new(0, 0, -halfSpan)
	makePart(
		wallFolder,
		"NorthGate_PillarWest",
		Vector3.new(6, 24, 8),
		CFrame.new(gatePos + Vector3.new(-gateWidth / 2 - 2, 12, 0)),
		trimColor,
		Enum.Material.Concrete
	)
	makePart(
		wallFolder,
		"NorthGate_PillarEast",
		Vector3.new(6, 24, 8),
		CFrame.new(gatePos + Vector3.new(gateWidth / 2 + 2, 12, 0)),
		trimColor,
		Enum.Material.Concrete
	)

	local gateHeader = makePart(
		wallFolder,
		"NorthGate_ArmoredHeader",
		Vector3.new(gateWidth + 10, 6, 8.4),
		CFrame.new(gatePos + Vector3.new(0, 21, 0)),
		Color3.fromRGB(45, 52, 60),
		Enum.Material.CorrodedMetal
	)
	attachWallSign(
		gateHeader,
		Enum.NormalId.Back,
		"PUERTA NORTE // SALIDA A ZONA DE MISIÓN (Z1–Z7)",
		"ADVERTENCIA: AMENAZA ACTIVA MÁS ALLÁ DEL PERÍMETRO SEGURO Z0",
		Color3.fromRGB(246, 173, 85)
	)
	attachWallSign(
		gateHeader,
		Enum.NormalId.Front,
		"REFUGIO SEGURO Z0 — BASTIÓN HUMANO",
		"ZONA DE EXTRACCIÓN Y DESCONTAMINACIÓN",
		Color3.fromRGB(72, 187, 120)
	)

	-- 4 Torres Bastión Esquinera (A-14)
	buildCornerWatchtower(wallFolder, "A14_Watchtower_NW", center + Vector3.new(-118, 0, -118))
	buildCornerWatchtower(wallFolder, "A14_Watchtower_NE", center + Vector3.new(118, 0, -118))
	buildCornerWatchtower(wallFolder, "A14_Watchtower_SW", center + Vector3.new(-118, 0, 118))
	buildCornerWatchtower(wallFolder, "A14_Watchtower_SE", center + Vector3.new(118, 0, 118))
end

--[[
	Construye el Helipuerto Táctico de Extracción (A-23) con rampa caminable en WedgePart,
	marcas de pista incrustadas con desfase >= 0.05 studs y letrero en muro de control.
--]]
local function buildHelipadA23(parent: Instance, padCenter: Vector3): Model
	local heli = Instance.new("Model")
	heli.Name = "A23_HelipuertoDeExtraccion"
	heli:SetAttribute("ZA_CatalogABuildingId", "A-23")
	heli.Parent = parent

	local deck = makePart(
		heli,
		"HelipadConcreteDeck",
		Vector3.new(44, 2.4, 44),
		CFrame.new(padCenter + Vector3.new(0, 1.2, 0)),
		Color3.fromRGB(54, 60, 68),
		Enum.Material.Concrete
	)
	heli.PrimaryPart = deck
	CollectionService:AddTag(deck, "ZA_SafeExtractionZone")

	-- Rampa de acceso oeste en WedgePart (pendiente suave caminable)
	makeWedge(
		heli,
		"HelipadAccessRamp",
		Vector3.new(14, 2.4, 10),
		CFrame.new(padCenter + Vector3.new(-27, 1.2, 0)) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(68, 74, 82),
		Enum.Material.Concrete
	)

	-- Marcas "H" de aterrizaje con desfase de +0.06 studs sobre la plataforma
	local markY = 2.46
	makePart(heli, "H_LeftBar", Vector3.new(2.2, 0.12, 18), CFrame.new(padCenter + Vector3.new(-6, markY, 0)), Color3.fromRGB(246, 204, 65), Enum.Material.SmoothPlastic)
	makePart(heli, "H_RightBar", Vector3.new(2.2, 0.12, 18), CFrame.new(padCenter + Vector3.new(6, markY, 0)), Color3.fromRGB(246, 204, 65), Enum.Material.SmoothPlastic)
	makePart(heli, "H_CrossBar", Vector3.new(10, 0.12, 2.2), CFrame.new(padCenter + Vector3.new(0, markY, 0)), Color3.fromRGB(246, 204, 65), Enum.Material.SmoothPlastic)

	-- Muro de control táctico al sur del helipuerto (soporta el letrero y el ProximityPrompt de Extracción)
	local controlWall = makePart(
		heli,
		"HelipadControlWall",
		Vector3.new(24, 9, 2),
		CFrame.new(padCenter + Vector3.new(0, 4.5, 21)),
		Color3.fromRGB(45, 52, 62),
		Enum.Material.CorrodedMetal
	)
	attachWallSign(
		controlWall,
		Enum.NormalId.Front,
		"[A-23] HELIPUERTO DE EXTRACCIÓN TÁCTICA",
		"ASEGURA TU MOCHILA TÁCTICA Y DESPLIEGA HACIA PUESTOS AVANZADOS",
		Color3.fromRGB(72, 187, 120)
	)

	local extractPrompt = Instance.new("ProximityPrompt")
	extractPrompt.ActionText = "Extraer Botín a Bóveda Segura"
	extractPrompt.ObjectText = "Helipuerto A-23 (Zona Segura Z0)"
	extractPrompt.HoldDuration = 0.25
	extractPrompt.MaxActivationDistance = 18
	extractPrompt.RequiresLineOfSight = false
	extractPrompt.Parent = controlWall

	-- 4 Balizas de pista en las esquinas de la losa
	for _, dx in ipairs({ -20, 20 }) do
		for _, dz in ipairs({ -20, 20 }) do
			local beacon = makePart(
				heli,
				string.format("RunwayBeacon_%d_%d", dx, dz),
				Vector3.new(1.2, 1.0, 1.2),
				CFrame.new(padCenter + Vector3.new(dx, 2.9, dz)),
				Color3.fromRGB(56, 178, 172),
				Enum.Material.Neon
			)
			local bl = Instance.new("PointLight")
			bl.Color = Color3.fromRGB(56, 178, 172)
			bl.Brightness = 1.6
			bl.Range = 14
			bl.Parent = beacon
		end
	end

	return heli
end

--[[
	Configura la atmósfera cinematográfica de Roblox Studio (Atmosphere, BloomEffect, ColorCorrectionEffect)
	para que el Lobby Z0 se vea con contraste arquitectónico, iluminación cálida y profundidad volumétrica.
--]]
function LobbyBuilder.configureAtmosphericLighting()
	pcall(function()
		Lighting.Ambient = Color3.fromRGB(52, 58, 68)
		Lighting.OutdoorAmbient = Color3.fromRGB(85, 92, 105)
		Lighting.Brightness = 2.4
		Lighting.ClockTime = 16.8 -- Hora dorada táctica
		Lighting.GeographicLatitude = 38
		Lighting.GlobalShadows = true
	end)

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.28
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(185, 175, 165)
	atmo.Decay = Color3.fromRGB(95, 88, 82)
	atmo.Glare = 0.15
	atmo.Haze = 1.2
	atmo.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.45
	bloom.Size = 24
	bloom.Threshold = 1.15
	bloom.Parent = Lighting

	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.08
	cc.Saturation = 0.06
	cc.Parent = Lighting
end

--[[
	Construye el Refugio Seguro completo (Z0_SafeHaven_Persistent, 256x256 studs)
	centrado en `centerPosition`.
--]]
function LobbyBuilder.buildCompleteSafeHavenZ0(parent: Instance, centerPosition: Vector3): Model
	LobbyBuilder.configureAtmosphericLighting()

	local haven = Instance.new("Model")
	haven.Name = "Z0_SafeHaven_Persistent"
	pcall(function()
		(haven :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	haven.Parent = parent

	-- 1. Cimiento Maestro de 256x256 studs (cota superior Y = centerPosition.Y)
	local groundY = centerPosition.Y
	local baseOrigin = Vector3.new(centerPosition.X, groundY, centerPosition.Z)

	local mainSlab = makePart(
		haven,
		"HavenFoundation_256x256",
		Vector3.new(256, 4, 256),
		CFrame.new(baseOrigin + Vector3.new(0, -2, 0)),
		Color3.fromRGB(64, 68, 74),
		Enum.Material.Concrete
	)
	haven.PrimaryPart = mainSlab

	-- 2. Red de Calzadas Asfálticas, Aceras Elevadas, Plaza Central y Pórticos Viales (desfase >= 0.08 studs)
	makePart(
		haven,
		"MainAvenue_NorthSouth",
		Vector3.new(28, 0.16, 228),
		CFrame.new(baseOrigin + Vector3.new(0, 0.08, 0)),
		Color3.fromRGB(40, 44, 48),
		Enum.Material.Asphalt
	)
	makePart(
		haven,
		"CrossAvenue_EastWest",
		Vector3.new(220, 0.16, 24),
		CFrame.new(baseOrigin + Vector3.new(0, 0.09, -5)),
		Color3.fromRGB(40, 44, 48),
		Enum.Material.Asphalt
	)
	-- Aceras peatonales elevadas a ambos lados de la avenida principal (+0.36 studs)
	for _, sideX in ipairs({ -16.5, 16.5 }) do
		makePart(
			haven,
			"Sidewalk_North_" .. tostring(sideX),
			Vector3.new(5, 0.36, 72),
			CFrame.new(baseOrigin + Vector3.new(sideX, 0.18, -74)),
			Color3.fromRGB(92, 98, 106),
			Enum.Material.Concrete
		)
		makePart(
			haven,
			"Sidewalk_South_" .. tostring(sideX),
			Vector3.new(5, 0.36, 78),
			CFrame.new(baseOrigin + Vector3.new(sideX, 0.18, 68)),
			Color3.fromRGB(92, 98, 106),
			Enum.Material.Concrete
		)
	end

	makePart(
		haven,
		"CentralCommandPlaza",
		Vector3.new(64, 0.22, 64),
		CFrame.new(baseOrigin + Vector3.new(0, 0.11, -5)),
		Color3.fromRGB(78, 84, 92),
		Enum.Material.Slate
	)

	-- Monumento / Torreta de Telemetría Central Z0 en el corazón de la Plaza Central
	local monument = Instance.new("Model")
	monument.Name = "CentralPlaza_TelemetryPylon"
	monument.Parent = haven
	local plinth1 = makePart(
		monument,
		"PlinthBase_Step1",
		Vector3.new(14, 1.2, 14),
		CFrame.new(baseOrigin + Vector3.new(0, 0.75, -5)),
		Color3.fromRGB(58, 64, 72),
		Enum.Material.Concrete
	)
	monument.PrimaryPart = plinth1
	makePart(
		monument,
		"PlinthBase_Step2",
		Vector3.new(10, 1.4, 10),
		CFrame.new(baseOrigin + Vector3.new(0, 2.05, -5)),
		Color3.fromRGB(45, 52, 60),
		Enum.Material.Slate
	)
	local pylonCore = Instance.new("TrussPart")
	pylonCore.Name = "TelemetryLatticeCore"
	pylonCore.Size = Vector3.new(2, 18, 2)
	pylonCore.CFrame = CFrame.new(baseOrigin + Vector3.new(0, 11.75, -5))
	pylonCore.Anchored = true
	pylonCore.Color = Color3.fromRGB(75, 85, 98)
	pylonCore.Material = Enum.Material.CorrodedMetal
	pylonCore.Parent = monument

	local headerBox = makePart(
		monument,
		"TelemetryDisplayHeader",
		Vector3.new(8.5, 4.2, 8.5),
		CFrame.new(baseOrigin + Vector3.new(0, 15.5, -5)),
		Color3.fromRGB(28, 34, 44),
		Enum.Material.SmoothPlastic
	)
	for _, faceId in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		attachWallSign(
			headerBox,
			faceId,
			"Z0 // REFUGIO CENTRAL",
			"PERÍMETRO SEGURO ACTIVO — 6 ESTACIONES OPERATIVAS",
			Color3.fromRGB(0, 230, 210)
		)
	end
	local topBeacon = makePart(
		monument,
		"TelemetryTopBeacon",
		Vector3.new(2.4, 1.6, 2.4),
		CFrame.new(baseOrigin + Vector3.new(0, 21.5, -5)),
		Color3.fromRGB(0, 240, 220),
		Enum.Material.Neon
	)
	local pylonLight = Instance.new("PointLight")
	pylonLight.Color = Color3.fromRGB(0, 240, 220)
	pylonLight.Brightness = 2.5
	pylonLight.Range = 42
	pylonLight.Shadows = true
	pylonLight.Parent = topBeacon

	-- Pórticos Estructurales de Iluminación y Señalización Vial sobre la Avenida Norte-Sur
	local gantrySpecs = {
		{
			name = "AvenueGantry_North",
			zOffset = -44,
			title = "SECTOR NORTE // MANDO Y ARMERÍA",
			sub = "<- [A-02] ARMERÍA & BÓVEDA | [A-01] CENTRO DE MANDO | CUARTEL [A-05] ->",
			color = Color3.fromRGB(99, 179, 237),
		},
		{
			name = "AvenueGantry_South",
			zOffset = 46,
			title = "SECTOR SUR // LABORATORIO Y EXTRACCIÓN",
			sub = "<- [A-06] CONCIENCIA & [A-21] HIDROPÓNICO | HELIPUERTO [A-23] ->",
			color = Color3.fromRGB(72, 187, 120),
		},
	}
	for _, g in ipairs(gantrySpecs) do
		local gModel = Instance.new("Model")
		gModel.Name = g.name
		gModel.Parent = haven
		makePart(
			gModel,
			"GantryCol_West",
			Vector3.new(2.2, 15, 2.2),
			CFrame.new(baseOrigin + Vector3.new(-16.5, 7.6, g.zOffset)),
			Color3.fromRGB(48, 54, 64),
			Enum.Material.CorrodedMetal
		)
		makePart(
			gModel,
			"GantryCol_East",
			Vector3.new(2.2, 15, 2.2),
			CFrame.new(baseOrigin + Vector3.new(16.5, 7.6, g.zOffset)),
			Color3.fromRGB(48, 54, 64),
			Enum.Material.CorrodedMetal
		)
		local beam = makePart(
			gModel,
			"GantryOverheadBeam",
			Vector3.new(35.2, 3.2, 2.6),
			CFrame.new(baseOrigin + Vector3.new(0, 16.6, g.zOffset)),
			Color3.fromRGB(36, 42, 52),
			Enum.Material.CorrodedMetal
		)
		attachWallSign(beam, Enum.NormalId.Front, g.title, g.sub, g.color)
		attachWallSign(beam, Enum.NormalId.Back, g.title, g.sub, g.color)
		local roadLamp = makePart(
			gModel,
			"GantryRoadLamp",
			Vector3.new(12, 0.35, 1.2),
			CFrame.new(baseOrigin + Vector3.new(0, 14.85, g.zOffset)),
			Color3.fromRGB(255, 242, 210),
			Enum.Material.Neon
		)
		local sl = Instance.new("SpotLight")
		sl.Color = Color3.fromRGB(255, 242, 210)
		sl.Brightness = 2.6
		sl.Range = 45
		sl.Angle = 75
		sl.Face = Enum.NormalId.Bottom
		sl.Shadows = true
		sl.Parent = roadLamp
	end

	-- Líneas viales centrales amarillas (desfase +0.20 studs)
	for zStep = -95, 95, 22 do
		if math.abs(zStep + 5) > 28 then
			makePart(
				haven,
				"RoadStripe_" .. tostring(zStep),
				Vector3.new(0.8, 0.08, 8),
				CFrame.new(baseOrigin + Vector3.new(0, 0.20, zStep)),
				Color3.fromRGB(236, 190, 55),
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- 3. 4 SpawnLocations Tácticos distribuidos en la Plaza de Despliegue Sur (separación >= 12 studs)
	local spawnOffsets = {
		Vector3.new(-18, 0.35, 88),
		Vector3.new(-6, 0.35, 88),
		Vector3.new(6, 0.35, 88),
		Vector3.new(18, 0.35, 88),
	}
	for idx, sOff in ipairs(spawnOffsets) do
		local sp = Instance.new("SpawnLocation")
		sp.Name = "Z0_TacticalSpawn_" .. tostring(idx)
		sp.Size = Vector3.new(8, 0.5, 8)
		sp.CFrame = CFrame.new(baseOrigin + sOff)
		sp.Anchored = true
		sp.Enabled = true
		sp.Duration = 0
		sp.Color = Color3.fromRGB(56, 161, 105)
		sp.Material = Enum.Material.Concrete
		sp.TopSurface = Enum.SurfaceType.Smooth
		sp.Parent = haven
	end

	-- 4. Murallas Perimetrales, Pórtico Blindado Norte y 4 Torres de Vigilancia (A-14)
	buildFortifiedPerimeter(haven, baseOrigin)

	-- 5. Los 6 Edificios Arquitectónicos del Catálogo A con Interiores, Ventanas Glass y Letreros SurfaceGui
	local buildingSpecs: { BuildingSpec } = {
		{
			id = "A-01",
			name = "A01_CentroDeMando",
			titleText = "[A-01] CENTRO DE MANDO DEL REFUGIO",
			subtitleText = "NÚCLEO DE GOBERNANZA Y DEFENSA DE ASENTAMIENTO",
			center = baseOrigin + Vector3.new(0, 0, -68),
			width = 48,
			depth = 30,
			wallHeight = 18,
			facing = "South",
			wallColor = Color3.fromRGB(62, 82, 112),
			wallMaterial = Enum.Material.Concrete,
			trimColor = Color3.fromRGB(40, 50, 68),
			roofColor = Color3.fromRGB(34, 42, 54),
			accentColor = Color3.fromRGB(99, 179, 237),
		},
		{
			id = "A-02",
			name = "A02_ArmeriaYBoveda",
			titleText = "[A-02 / A-08] ARMERÍA MODULAR & BÓVEDA",
			subtitleText = "EVOLUCIÓN DE ARMAS LV.1–10 | REFUNDIR 80% | LOADOUT 10 SLOTS",
			center = baseOrigin + Vector3.new(-68, 0, -35),
			width = 42,
			depth = 28,
			wallHeight = 16,
			facing = "East",
			wallColor = Color3.fromRGB(128, 78, 56),
			wallMaterial = Enum.Material.Brick,
			trimColor = Color3.fromRGB(55, 48, 46),
			roofColor = Color3.fromRGB(44, 38, 36),
			accentColor = Color3.fromRGB(246, 173, 85),
		},
		{
			id = "A-06",
			name = "A06_LaboratorioConciencia",
			titleText = "[A-06] LABORATORIO DE CONCIENCIA",
			subtitleText = "CALIBRACIÓN DEL EMISOR G-20 & SÍNTESIS DE NÚCLEOS",
			center = baseOrigin + Vector3.new(-68, 0, 28),
			width = 40,
			depth = 26,
			wallHeight = 16,
			facing = "East",
			wallColor = Color3.fromRGB(82, 102, 115),
			wallMaterial = Enum.Material.Concrete,
			trimColor = Color3.fromRGB(42, 62, 74),
			roofColor = Color3.fromRGB(32, 48, 58),
			accentColor = Color3.fromRGB(0, 255, 220),
		},
		{
			id = "A-05",
			name = "A05_CuartelMercenarios",
			titleText = "[A-05] CUARTEL DE MERCENARIOS",
			subtitleText = "RECLUTA | FRANCOTIRADOR | MÉDICO | ZAPADOR | DOMADORA | FANTASMA",
			center = baseOrigin + Vector3.new(68, 0, -35),
			width = 42,
			depth = 28,
			wallHeight = 16,
			facing = "West",
			wallColor = Color3.fromRGB(72, 96, 76),
			wallMaterial = Enum.Material.Concrete,
			trimColor = Color3.fromRGB(46, 58, 48),
			roofColor = Color3.fromRGB(36, 46, 38),
			accentColor = Color3.fromRGB(104, 211, 145),
		},
		{
			id = "A-07",
			name = "A07_SalaDeMapas",
			titleText = "[A-07] SALA DE MAPAS Y RADAR",
			subtitleText = "TELEMETRÍA DE AMENAZA Z1–Z7 & ALERTAS DE EVENTOS E-01..E-16",
			center = baseOrigin + Vector3.new(68, 0, 24),
			width = 36,
			depth = 24,
			wallHeight = 15,
			facing = "West",
			wallColor = Color3.fromRGB(78, 86, 108),
			wallMaterial = Enum.Material.Concrete,
			trimColor = Color3.fromRGB(48, 54, 70),
			roofColor = Color3.fromRGB(38, 44, 58),
			accentColor = Color3.fromRGB(144, 205, 244),
		},
		{
			id = "A-21",
			name = "A21_InvernaderoHidroponico",
			titleText = "[A-21] JARDÍN HIDROPÓNICO",
			subtitleText = "PRODUCCIÓN PASIVA CONTINUA: +50 CHATARRA / HORA",
			center = baseOrigin + Vector3.new(-68, 0, 82),
			width = 38,
			depth = 24,
			wallHeight = 13,
			facing = "East",
			wallColor = Color3.fromRGB(68, 92, 78),
			wallMaterial = Enum.Material.Concrete,
			trimColor = Color3.fromRGB(48, 68, 56),
			roofColor = Color3.fromRGB(140, 210, 185),
			accentColor = Color3.fromRGB(154, 230, 180),
			glassRoof = true,
		},
	}

	for _, bSpec in ipairs(buildingSpecs) do
		LobbyBuilder.buildArchitecturalBuilding(haven, bSpec)
	end

	-- 6. Helipuerto de Despliegue y Extracción Segura (A-23) en el Cuadrante Sureste
	buildHelipadA23(haven, baseOrigin + Vector3.new(68, 0, 78))

	return haven
end

return LobbyBuilder
