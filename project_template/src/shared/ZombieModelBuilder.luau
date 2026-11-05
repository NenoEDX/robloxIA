--!strict
--[[
	ZombieModelBuilder.luau
	Constructor Anatómico y de Variantes Visuales para los 61 Zombies de Zombie Awareness (v4.0):
	- Subfacción 1 (Z-01 a Z-20): Zombies Melee y Mutaciones Urbanas (RIG-04)
	- Subfacción 2 (Z-21 a Z-35): Zombies Armados a Distancia y Portadores Explosivos (RIG-04)
	- Subfacción 3 (Z-36 a Z-40): Zombies Acorazados Pesados (RIG-04)
	- Subfacción 3B (Z-41 a Z-50): Bestias Infectadas Cuadrúpedas y Simiescas (RIG-03)
	- Subfacción 4 (Z-51 a Z-60): Brutos Zombies Tipo Hulk/Troll de 11–14.5 studs (RIG-05)
	- Mega Bruto Líder (Z-BOSS-01): Dios Zombi Troll de 26 studs con WeakPoint_Head/Chest/Back (RIG-06)

	También expone `buildZombieShowcaseGallery(parent, origin)` para desplegar la Galería de Inspección
	Detallada al costado del Lobby Z0 con pedestales iluminados y fichas técnicas en SurfaceGui.
--]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:FindFirstChild("RAASE_Shared")
local ZombieCatalogs: any = if sharedFolder and sharedFolder:FindFirstChild("ZombieCatalogs")
	then require(sharedFolder:FindFirstChild("ZombieCatalogs") :: any)
	else nil

local ZombieModelBuilder = {}

local FALLBACK_ZOMBIE_META: { [string]: { name: string, rig: string, sub: string, hp: number, dps: number, speed: number, weapon: string } } = {
	["Z-01"] = { name = "Caminante (Z-N01)", rig = "RIG-04", sub = "Zombie_Melee", hp = 45, dps = 8, speed = 8, weapon = "Garras y mordida" },
	["Z-02"] = { name = "Corredor (Z-N02)", rig = "RIG-04", sub = "Zombie_Melee", hp = 40, dps = 12, speed = 22, weapon = "Mordida frenética" },
	["Z-03"] = { name = "Reventador Urbano (Z-N03)", rig = "RIG-04", sub = "Zombie_Melee", hp = 80, dps = 18, speed = 10, weapon = "Tubo de plomo pesado" },
	["Z-04"] = { name = "Salvaje Saltador (Z-N04)", rig = "RIG-04", sub = "Zombie_Melee", hp = 55, dps = 20, speed = 18, weapon = "Garras afiladas" },
	["Z-05"] = { name = "Ghoul Ardiente (Z-N05)", rig = "RIG-04", sub = "Zombie_Melee", hp = 60, dps = 15, speed = 12, weapon = "Cuerpo en llamas" },
	["Z-06"] = { name = "Ghoul Marcador (Z-N06)", rig = "RIG-04", sub = "Zombie_Melee", hp = 50, dps = 10, speed = 10, weapon = "Garras con feromonas" },
	["Z-07"] = { name = "Gritón Invocador (Z-N08)", rig = "RIG-04", sub = "Zombie_Melee", hp = 70, dps = 0, speed = 11, weapon = "Cuerdas vocales mutadas" },
	["Z-08"] = { name = "Pululante Tóxico (Z-N10)", rig = "RIG-04", sub = "Zombie_Melee", hp = 45, dps = 8, speed = 10, weapon = "Pústulas infecciosas" },
	["Z-09"] = { name = "Bombero Infectado (Z-N11)", rig = "RIG-04", sub = "Zombie_Melee", hp = 130, dps = 26, speed = 11, weapon = "Hacha de Bombero" },
	["Z-10"] = { name = "Cirujano Distrito Médico", rig = "RIG-04", sub = "Zombie_Melee", hp = 75, dps = 24, speed = 15, weapon = "Sierra ósea quirúrgica" },
	["Z-11"] = { name = "Leñador con Motosierra", rig = "RIG-04", sub = "Zombie_Melee", hp = 115, dps = 32, speed = 13, weapon = "Motosierra oxidada" },
	["Z-12"] = { name = "Preso Encadenado", rig = "RIG-04", sub = "Zombie_Melee", hp = 95, dps = 22, speed = 12, weapon = "Bola de presidio con cadena" },
	["Z-13"] = { name = "Cocinero Carnicero", rig = "RIG-04", sub = "Zombie_Melee", hp = 105, dps = 25, speed = 11, weapon = "Dos cuchillos de carnicero" },
	["Z-14"] = { name = "Atleta Infectado", rig = "RIG-04", sub = "Zombie_Melee", hp = 65, dps = 16, speed = 25, weapon = "Placaje corporal" },
	["Z-15"] = { name = "Reptante de Alcantarilla", rig = "RIG-04", sub = "Zombie_Melee", hp = 35, dps = 14, speed = 14, weapon = "Mordida a los tobillos (Sin piernas)" },
	["Z-16"] = { name = "Portador de Alambre", rig = "RIG-04", sub = "Zombie_Melee", hp = 85, dps = 19, speed = 11, weapon = "Brazos con alambre de púas" },
	["Z-17"] = { name = "Sepulturero", rig = "RIG-04", sub = "Zombie_Melee", hp = 100, dps = 23, speed = 10, weapon = "Pala metálica" },
	["Z-18"] = { name = "Paciente Cero Eléctrico", rig = "RIG-04", sub = "Zombie_Melee", hp = 90, dps = 22, speed = 14, weapon = "Cables de alta tensión" },
	["Z-19"] = { name = "Acechador Nocturno", rig = "RIG-04", sub = "Zombie_Melee", hp = 80, dps = 28, speed = 19, weapon = "Garras alargadas nocturnas" },
	["Z-20"] = { name = "Amalgama de Carne", rig = "RIG-04", sub = "Zombie_Melee", hp = 160, dps = 30, speed = 9, weapon = "Múltiples brazos fusionados" },
	["Z-21"] = { name = "Vómitor Ácido (Z-N07)", rig = "RIG-04", sub = "Zombie_Ranged", hp = 65, dps = 14, speed = 9, weapon = "Proyectil de ácido (12 m/s)" },
	["Z-22"] = { name = "Policía Infectado (Z-N12)", rig = "RIG-04", sub = "Zombie_Ranged", hp = 95, dps = 20, speed = 12, weapon = "Escopeta de servicio" },
	["Z-23"] = { name = "Guardia de Seguridad", rig = "RIG-04", sub = "Zombie_Ranged", hp = 75, dps = 15, speed = 11, weapon = "Pistola 9mm" },
	["Z-24"] = { name = "Soldado Caído (Rifle)", rig = "RIG-04", sub = "Zombie_Ranged", hp = 115, dps = 26, speed = 10, weapon = "Rifle de Asalto (G-05)" },
	["Z-25"] = { name = "Zombie Bomba de Gas", rig = "RIG-04", sub = "Zombie_Ranged", hp = 80, dps = 60, speed = 15, weapon = "Bombona de propano dorsal" },
	["Z-26"] = { name = "Infectado con Subfusil", rig = "RIG-04", sub = "Zombie_Ranged", hp = 85, dps = 22, speed = 14, weapon = "Subfusil Uzi/MP5 encajado" },
	["Z-27"] = { name = "Lanzador de Huesos", rig = "RIG-04", sub = "Zombie_Ranged", hp = 90, dps = 24, speed = 11, weapon = "Costillas óseas afiladas" },
	["Z-28"] = { name = "Artillero Anclado (LMG)", rig = "RIG-04", sub = "Zombie_Ranged", hp = 150, dps = 35, speed = 7, weapon = "Ametralladora Ligera (G-12)" },
	["Z-29"] = { name = "Francotirador Zombificado", rig = "RIG-04", sub = "Zombie_Ranged", hp = 80, dps = 45, speed = 8, weapon = "Rifle de Francotirador" },
	["Z-30"] = { name = "Portador de Barril Tóxico", rig = "RIG-04", sub = "Zombie_Ranged", hp = 110, dps = 30, speed = 10, weapon = "Barril químico en brazos" },
	["Z-31"] = { name = "Infectado con Lanzallamas", rig = "RIG-04", sub = "Zombie_Ranged", hp = 135, dps = 32, speed = 9, weapon = "Lanzallamas con fugas" },
	["Z-32"] = { name = "Escupidor de Enjambre", rig = "RIG-04", sub = "Zombie_Ranged", hp = 95, dps = 18, speed = 10, weapon = "Colmena de insectos necrófagos" },
	["Z-33"] = { name = "Zombie con Lanzagranadas", rig = "RIG-04", sub = "Zombie_Ranged", hp = 125, dps = 40, speed = 9, weapon = "Lanzagranadas de tambor (G-14)" },
	["Z-34"] = { name = "Artillero de Arpones", rig = "RIG-04", sub = "Zombie_Ranged", hp = 105, dps = 28, speed = 11, weapon = "Cañón arponero industrial" },
	["Z-35"] = { name = "Comandante Infectado", rig = "RIG-04", sub = "Zombie_Ranged", hp = 140, dps = 30, speed = 12, weapon = "Revólver .44 + Inyector Furia" },
	["Z-36"] = { name = "Blindado Antidisturbios", rig = "RIG-04", sub = "Zombie_ArmoredBeast", hp = 220, dps = 16, speed = 8, weapon = "Escudo antidisturbios + Escopeta" },
	["Z-37"] = { name = "Soldado Kevlar Pesado", rig = "RIG-04", sub = "Zombie_ArmoredBeast", hp = 240, dps = 22, speed = 9, weapon = "Chaleco y casco Kevlar" },
	["Z-38"] = { name = "Juggernaut EOD", rig = "RIG-04", sub = "Zombie_ArmoredBeast", hp = 320, dps = 28, speed = 6, weapon = "Traje antibombas + Maza" },
	["Z-39"] = { name = "Soldador Acorazado", rig = "RIG-04", sub = "Zombie_ArmoredBeast", hp = 200, dps = 25, speed = 10, weapon = "Placas de acero + Soplete" },
	["Z-40"] = { name = "Minero Subterráneo", rig = "RIG-04", sub = "Zombie_ArmoredBeast", hp = 190, dps = 30, speed = 11, weapon = "Casco SpotLight + Pico perforador" },
	["Z-41"] = { name = "Sabueso Infectado (Z-A01)", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 55, dps = 14, speed = 26, weapon = "Colmillos de jauría (4 patas)" },
	["Z-42"] = { name = "Warg de Asedio (Z-A02)", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 90, dps = 22, speed = 24, weapon = "Placas óseas + Embestida" },
	["Z-43"] = { name = "Alfa Lobo Infectado (Z-A03)", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 240, dps = 28, speed = 20, weapon = "Líder de Manada (Aullido)" },
	["Z-44"] = { name = "Simio Demoledor (Z-A04)", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 160, dps = 24, speed = 14, weapon = "Puños bestiales + Salto AoE" },
	["Z-45"] = { name = "Oso Zombie (Z-A05)", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 300, dps = 30, speed = 12, weapon = "Zarpas necrosadas" },
	["Z-46"] = { name = "Felino Fantasma (Z-A06)", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 120, dps = 26, speed = 28, weapon = "Garras + Sigilo traslúcido" },
	["Z-47"] = { name = "Hiena Necrófaga (Z-A07)", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 60, dps = 12, speed = 22, weapon = "Risa aturdidora + Mordida" },
	["Z-48"] = { name = "Pantera de Medianoche", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 130, dps = 32, speed = 26, weapon = "Garras sombrías (Crítico x2.5)" },
	["Z-49"] = { name = "Jabalí Acorazado (Z-A09)", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 170, dps = 20, speed = 24, weapon = "Colmillos y placas frontales" },
	["Z-50"] = { name = "Quimera Zombie (Z-A10)", rig = "RIG-03", sub = "Zombie_ArmoredBeast", hp = 450, dps = 34, speed = 18, weapon = "Fusión oso/lobo/ciervo + Ácido" },
	["Z-51"] = { name = "Bruto Estándar (Z-H01)", rig = "RIG-05", sub = "Zombie_Brute", hp = 420, dps = 35, speed = 9, weapon = "Puños hipertrofiados (11 studs)" },
	["Z-52"] = { name = "Aplastador Sísmico (Z-H02)", rig = "RIG-05", sub = "Zombie_Brute", hp = 480, dps = 70, speed = 8, weapon = "Salto vertical AoE 10 studs" },
	["Z-53"] = { name = "Pedrero Urbano (Z-H03)", rig = "RIG-05", sub = "Zombie_Brute", hp = 400, dps = 38, speed = 7, weapon = "Lanza bloques de asfalto" },
	["Z-54"] = { name = "Devorador (Z-H04)", rig = "RIG-05", sub = "Zombie_Brute", hp = 500, dps = 45, speed = 10, weapon = "Mandíbula pectoral gigante" },
	["Z-55"] = { name = "Colmillos XL (Z-H05)", rig = "RIG-05", sub = "Zombie_Brute", hp = 450, dps = 40, speed = 14, weapon = "Hojas óseas XL imbloqueables" },
	["Z-56"] = { name = "Acorazado de Hueso (Z-H06)", rig = "RIG-05", sub = "Zombie_Brute", hp = 600, dps = 28, speed = 6, weapon = "Placas óseas + Grietas Neon x3" },
	["Z-57"] = { name = "Hulk Tóxico (Z-H07)", rig = "RIG-05", sub = "Zombie_Brute", hp = 430, dps = 20, speed = 8, weapon = "Aura corrosiva 9 studs" },
	["Z-58"] = { name = "Hulk Ígneo (Z-H08)", rig = "RIG-05", sub = "Zombie_Brute", hp = 430, dps = 20, speed = 8, weapon = "Aura ígnea 8 studs" },
	["Z-59"] = { name = "Titán Destructor (Z-H09)", rig = "RIG-05", sub = "Zombie_Brute", hp = 900, dps = 45, speed = 9, weapon = "Columna de hormigón con varillas" },
	["Z-60"] = { name = "Coloso de Zona (Z-H10)", rig = "RIG-05", sub = "Zombie_Brute", hp = 1200, dps = 50, speed = 8, weapon = "Corona ósea + Invocación" },
	["Z-BOSS-01"] = { name = "DIOS ZOMBI TROLL", rig = "RIG-06", sub = "Zombie_MegaBoss", hp = 30000, dps = 80, speed = 9, weapon = "Coloso 26 studs + 3 WeakPoints" },
}

local function getZombieMeta(unitId: string)
	local catUnit = if ZombieCatalogs and ZombieCatalogs.Units then ZombieCatalogs.Units[unitId] else nil
	local fb = FALLBACK_ZOMBIE_META[unitId]
	return {
		name = if catUnit then catUnit.name elseif fb then fb.name else unitId,
		masterRig = if catUnit then catUnit.masterRig elseif fb then fb.rig else "RIG-04",
		subFaction = if catUnit then catUnit.subFaction elseif fb then fb.sub else "Zombie_Melee",
		hp = if catUnit then catUnit.hp elseif fb then fb.hp else 100,
		dps = if catUnit then catUnit.dps elseif fb then fb.dps else 15,
		speed = if catUnit then catUnit.speed elseif fb then fb.speed else 12,
		weaponOrTool = if catUnit then catUnit.weaponOrTool elseif fb then fb.weapon else "Garras",
		primaryColor = if catUnit then catUnit.primaryColor else Color3.fromRGB(85, 100, 82),
		accentColor = if catUnit then catUnit.accentColor else Color3.fromRGB(220, 45, 45),
	}
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

local function wedge(
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
	w.CanCollide = false
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Color = color
	w.Material = material
	w.Transparency = transparency or 0
	w.Parent = parent
	return w
end

local function addGlowLight(parent: Instance, color: Color3, brightness: number, range: number)
	local pl = Instance.new("PointLight")
	pl.Color = color
	pl.Brightness = brightness
	pl.Range = range
	pl.Shadows = false
	pl.Parent = parent
end

--[[
	Construye la cabeza detallada de un Zombie (cráneo, mandíbula inferior, cuencas oculares, pupilas Neon,
	cejas y cicatrices/variaciones según `unitId`).
--]]
local function buildDetailedZombieHead(
	model: Instance,
	headCF: CFrame,
	scale: number,
	skinColor: Color3,
	eyeColor: Color3,
	jawOpen: number,
	skinMat: Enum.Material
): Part
	local cranium = part(
		model,
		"Head",
		Vector3.new(1.35 * scale, 1.15 * scale, 1.35 * scale),
		headCF * CFrame.new(0, 0.12 * scale, 0),
		skinColor,
		skinMat
	)

	-- Mandíbula inferior articulada (más abierta en Gritones, Devoradores y Jefes)
	part(
		model,
		"LowerJaw",
		Vector3.new(1.12 * scale, 0.42 * scale, 1.18 * scale),
		headCF * CFrame.new(0, (-0.42 - jawOpen * 0.25) * scale, -0.06 * scale) * CFrame.Angles(math.rad(jawOpen * 22), 0, 0),
		skinColor:Lerp(Color3.fromRGB(45, 35, 35), 0.25),
		skinMat
	)

	-- Dientes inferiores y superiores visibles
	part(
		model,
		"UpperTeethRow",
		Vector3.new(0.82 * scale, 0.14 * scale, 0.22 * scale),
		headCF * CFrame.new(0, -0.22 * scale, -0.62 * scale),
		Color3.fromRGB(215, 205, 175),
		Enum.Material.Slate
	)

	-- Ceño fruncido / arco superciliar
	part(
		model,
		"BrowRidge",
		Vector3.new(1.26 * scale, 0.22 * scale, 0.35 * scale),
		headCF * CFrame.new(0, 0.32 * scale, -0.58 * scale),
		skinColor:Lerp(Color3.new(0, 0, 0), 0.22),
		skinMat
	)

	-- Ojos infectados luminosos (Neon)
	for _, side in ipairs({ -1, 1 }) do
		part(
			model,
			if side < 0 then "EyeSocket_L" else "EyeSocket_R",
			Vector3.new(0.32 * scale, 0.24 * scale, 0.16 * scale),
			headCF * CFrame.new(side * 0.32 * scale, 0.15 * scale, -0.64 * scale),
			Color3.fromRGB(20, 18, 22),
			Enum.Material.SmoothPlastic
		)
		part(
			model,
			if side < 0 then "EyeGlow_L" else "EyeGlow_R",
			Vector3.new(0.20 * scale, 0.15 * scale, 0.18 * scale),
			headCF * CFrame.new(side * 0.32 * scale, 0.15 * scale, -0.67 * scale),
			eyeColor,
			Enum.Material.Neon
		)
	end

	return cranium
end

--[[
	Equipa el arma, herramienta, mutación o blindaje específico de cada uno de los 61 Zombies (`Z-01`..`Z-60` y `Z-BOSS-01`).
--]]
local function attachZombieSpecificMutationsAndGear(
	model: Model,
	unitId: string,
	originCF: CFrame,
	scale: number,
	rightHandCF: CFrame,
	leftHandCF: CFrame,
	torsoCF: CFrame,
	headCF: CFrame
)
	local bloodCol = Color3.fromRGB(150, 22, 22)
	local boneCol = Color3.fromRGB(222, 214, 192)
	local toxicNeon = Color3.fromRGB(115, 255, 55)
	local fireNeon = Color3.fromRGB(255, 110, 20)
	local elecNeon = Color3.fromRGB(65, 210, 255)
	local steelCol = Color3.fromRGB(95, 102, 112)
	local darkMetal = Color3.fromRGB(42, 46, 54)

	if unitId == "Z-01" then
		-- Caminante: costillas expuestas y garras ensangrentadas
		for i = 1, 3 do
			part(model, "ExposedRib_" .. i, Vector3.new(1.1, 0.12, 0.15), torsoCF * CFrame.new(0, 0.35 - i * 0.22, -0.58), boneCol, Enum.Material.Slate)
		end
		part(model, "BloodClaw_R", Vector3.new(0.45, 0.55, 0.65), rightHandCF * CFrame.new(0, -0.2, -0.25), bloodCol, Enum.Material.Slate)
	elseif unitId == "Z-02" then
		-- Corredor: espolones óseos aerodinámicos y venas carmesí en pecho/piernas
		wedge(model, "SprintCrest", Vector3.new(0.25, 0.8, 1.2), torsoCF * CFrame.new(0, 0.4, 0.65), bloodCol, Enum.Material.Slate)
		part(model, "ClawTalon_R", Vector3.new(0.2, 0.8, 0.3), rightHandCF * CFrame.new(0, -0.35, -0.2), bloodCol, Enum.Material.Neon)
		part(model, "ClawTalon_L", Vector3.new(0.2, 0.8, 0.3), leftHandCF * CFrame.new(0, -0.35, -0.2), bloodCol, Enum.Material.Neon)
	elseif unitId == "Z-03" then
		-- Reventador Urbano: pesado tubo de plomo con brida en mano derecha
		part(model, "LeadPipe_Shaft", Vector3.new(0.45, 3.8, 0.45), rightHandCF * CFrame.new(0, 0.2, -1.2) * CFrame.Angles(math.rad(75), 0, 0), steelCol, Enum.Material.CorrodedMetal)
		part(model, "LeadPipe_Flange", Vector3.new(0.85, 0.5, 0.85), rightHandCF * CFrame.new(0, 0.6, -2.8) * CFrame.Angles(math.rad(75), 0, 0), darkMetal, Enum.Material.Metal)
	elseif unitId == "Z-04" then
		-- Salvaje Saltador: garras largas de rapaz en manos y espinas dorsales
		for _, hCF in ipairs({ rightHandCF, leftHandCF }) do
			for c = -1, 1 do
				wedge(model, "RaptorClaw", Vector3.new(0.12, 0.95, 0.35), hCF * CFrame.new(c * 0.16, -0.45, -0.25), boneCol, Enum.Material.Slate)
			end
		end
	elseif unitId == "Z-05" then
		-- Ghoul Ardiente: grietas de magma en torso, cráneo en llamas y PointLight ígneo
		local core = part(model, "BurningCore", Vector3.new(1.5, 1.4, 1.05), torsoCF * CFrame.new(0, 0.1, -0.05), fireNeon, Enum.Material.Neon)
		addGlowLight(core, fireNeon, 2.2, 14)
		for i = 1, 4 do
			wedge(model, "FlameCrown_" .. i, Vector3.new(0.3, 0.9, 0.4), headCF * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0.75, 0), fireNeon, Enum.Material.Neon)
		end
	elseif unitId == "Z-06" then
		-- Ghoul Marcador: glándulas de feromonas verdes en hombros y garras ácidas
		for _, s in ipairs({ -1, 1 }) do
			part(model, "PheromoneSac_" .. s, Vector3.new(0.85, 0.85, 0.85), torsoCF * CFrame.new(s * 1.05, 0.85, 0.15), Color3.fromRGB(185, 240, 45), Enum.Material.Neon, Enum.PartType.Ball, 0.15)
		end
		part(model, "PheromoneClaws_R", Vector3.new(0.45, 0.7, 0.45), rightHandCF * CFrame.new(0, -0.3, -0.15), toxicNeon, Enum.Material.Neon)
	elseif unitId == "Z-07" then
		-- Gritón Invocador: caja torácica resonante abierta y garganta bioluminiscente violeta/cian
		local throat = part(model, "SonicVocalSac", Vector3.new(1.1, 1.0, 0.9), headCF * CFrame.new(0, -0.55, -0.35), Color3.fromRGB(170, 90, 255), Enum.Material.Neon, Enum.PartType.Ball)
		addGlowLight(throat, Color3.fromRGB(170, 90, 255), 2.0, 14)
		for i = 1, 4 do
			part(model, "ResonatorRib_" .. i, Vector3.new(1.8, 0.16, 0.2), torsoCF * CFrame.new(0, 0.6 - i * 0.28, -0.55), boneCol, Enum.Material.Slate)
		end
	elseif unitId == "Z-08" then
		-- Pululante Tóxico: racimo de pústulas infecciosas hinchadas en espalda y pecho
		local pustuleOffsets = {
			Vector3.new(-0.55, 0.5, 0.55),
			Vector3.new(0.5, 0.65, 0.55),
			Vector3.new(0, 0.1, 0.65),
			Vector3.new(-0.45, 0.35, -0.55),
			Vector3.new(0.55, -0.15, 0.5),
		}
		for idx, off in ipairs(pustuleOffsets) do
			part(model, "ToxicPustule_" .. idx, Vector3.new(0.85, 0.85, 0.85), torsoCF * CFrame.new(off), toxicNeon, Enum.Material.Neon, Enum.PartType.Ball, 0.2)
		end
	elseif unitId == "Z-09" then
		-- Bombero Infectado: casco de bombero amarillo, franjas reflectantes y Hacha de Bombero roja
		part(model, "FirefighterHelmet_Dome", Vector3.new(1.55, 0.65, 1.75), headCF * CFrame.new(0, 0.55, 0.08), Color3.fromRGB(235, 185, 30), Enum.Material.SmoothPlastic)
		part(model, "ReflectiveStripe_Torso", Vector3.new(2.12, 0.28, 1.22), torsoCF * CFrame.new(0, -0.15, 0), Color3.fromRGB(240, 245, 80), Enum.Material.Neon)
		part(model, "FireAxe_Handle", Vector3.new(0.28, 3.6, 0.28), rightHandCF * CFrame.new(0, 0.2, -1.1) * CFrame.Angles(math.rad(75), 0, 0), Color3.fromRGB(130, 80, 45), Enum.Material.Wood)
		wedge(model, "FireAxe_Blade", Vector3.new(0.22, 1.1, 1.25), rightHandCF * CFrame.new(0, 0.65, -2.55) * CFrame.Angles(math.rad(75), 0, 0), Color3.fromRGB(210, 35, 35), Enum.Material.Metal)
	elseif unitId == "Z-10" then
		-- Cirujano del Distrito Médico: espejo frontal quirúrgico, mascarilla y Sierra Ósea Circular
		part(model, "SurgicalMask", Vector3.new(1.22, 0.55, 0.4), headCF * CFrame.new(0, -0.18, -0.55), Color3.fromRGB(90, 195, 185), Enum.Material.Fabric)
		part(model, "HeadMirror", Vector3.new(0.45, 0.45, 0.15), headCF * CFrame.new(0, 0.48, -0.68), Color3.fromRGB(220, 235, 250), Enum.Material.Metal)
		part(model, "BoneSaw_Motor", Vector3.new(0.55, 0.6, 1.4), rightHandCF * CFrame.new(0, 0, -0.6), steelCol, Enum.Material.Metal)
		part(model, "BoneSaw_Disc", Vector3.new(0.12, 1.35, 1.35), rightHandCF * CFrame.new(0, 0, -1.55), Color3.fromRGB(210, 215, 225), Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif unitId == "Z-11" then
		-- Leñador con Motosierra: cuerpo de motor rojo + espada metálica de motosierra
		part(model, "Chainsaw_EngineBlock", Vector3.new(0.95, 0.95, 1.45), rightHandCF * CFrame.new(0.15, 0.1, -0.55), Color3.fromRGB(205, 45, 35), Enum.Material.Metal)
		part(model, "Chainsaw_GuideBar", Vector3.new(0.18, 0.55, 2.8), rightHandCF * CFrame.new(0.15, 0.05, -2.4), steelCol, Enum.Material.CorrodedMetal)
		part(model, "Chainsaw_BloodEdge", Vector3.new(0.24, 0.62, 2.85), rightHandCF * CFrame.new(0.15, 0.05, -2.4), bloodCol, Enum.Material.Slate, nil, 0.35)
	elseif unitId == "Z-12" then
		-- Preso Encadenado: grilletes, cadena pesada y Bola de Acero de Presidio
		part(model, "Shackle_R", Vector3.new(0.75, 0.35, 0.75), rightHandCF * CFrame.new(0, 0.2, 0), darkMetal, Enum.Material.Metal)
		for link = 1, 4 do
			part(model, "ChainLink_" .. link, Vector3.new(0.28, 0.45, 0.28), rightHandCF * CFrame.new(0, -link * 0.38, -link * 0.32), steelCol, Enum.Material.CorrodedMetal)
		end
		part(model, "PrisonIronBall", Vector3.new(1.85, 1.85, 1.85), rightHandCF * CFrame.new(0, -1.75, -1.65), darkMetal, Enum.Material.CorrodedMetal, Enum.PartType.Ball)
	elseif unitId == "Z-13" then
		-- Cocinero Carnicero: gorro alto de chef, delantal ensangrentado y 2 cuchillos de carnicero
		part(model, "ButcherApron", Vector3.new(1.95, 2.1, 0.18), torsoCF * CFrame.new(0, -0.25, -0.58), Color3.fromRGB(215, 200, 195), Enum.Material.Fabric)
		part(model, "BloodStain_Apron", Vector3.new(1.4, 1.2, 0.2), torsoCF * CFrame.new(0.1, -0.2, -0.6), bloodCol, Enum.Material.Slate)
		part(model, "ChefToqueHat", Vector3.new(1.25, 1.1, 1.25), headCF * CFrame.new(0, 0.95, 0), Color3.fromRGB(235, 235, 240), Enum.Material.Fabric)
		for _, hCF in ipairs({ rightHandCF, leftHandCF }) do
			part(model, "CleaverBlade", Vector3.new(0.14, 0.95, 1.65), hCF * CFrame.new(0, -0.1, -0.95), steelCol, Enum.Material.Metal)
		end
	elseif unitId == "Z-14" then
		-- Atleta Infectado: hombreras deportivas de placaje y dorsal numérico
		for _, s in ipairs({ -1, 1 }) do
			part(model, "TackleShoulderPad_" .. s, Vector3.new(1.15, 0.75, 1.45), torsoCF * CFrame.new(s * 1.25, 0.85, 0), Color3.fromRGB(185, 35, 35), Enum.Material.SmoothPlastic)
		end
		part(model, "AthleteVisorHelmet", Vector3.new(1.48, 1.25, 1.48), headCF * CFrame.new(0, 0.15, 0), Color3.fromRGB(185, 35, 35), Enum.Material.SmoothPlastic)
	elseif unitId == "Z-15" then
		-- Reptante de Alcantarilla: vértebras expuestas y rastro viscoso (sin piernas, construido a ras de suelo)
		for v = 1, 4 do
			part(model, "ExposedSpineVert_" .. v, Vector3.new(0.45, 0.45, 0.35), torsoCF * CFrame.new(0, 0.2 - v * 0.38, 0.55), boneCol, Enum.Material.Slate)
		end
	elseif unitId == "Z-16" then
		-- Portador de Alambre: espirales de alambre de púas en brazos y torso
		for coil = 1, 5 do
			part(model, "BarbedWireCoil_Torso_" .. coil, Vector3.new(2.25, 0.14, 1.35), torsoCF * CFrame.new(0, 0.8 - coil * 0.32, 0) * CFrame.Angles(0, 0, math.rad(coil * 8 - 16)), steelCol, Enum.Material.CorrodedMetal)
		end
		part(model, "BarbedSpikes_R", Vector3.new(0.85, 1.6, 0.85), rightHandCF * CFrame.new(0, 0.4, 0), steelCol, Enum.Material.CorrodedMetal)
	elseif unitId == "Z-17" then
		-- Sepulturero: sombrero de ala ancha y Pala Metálica larga
		part(model, "GravediggerHatBrim", Vector3.new(2.3, 0.16, 2.3), headCF * CFrame.new(0, 0.55, 0), Color3.fromRGB(35, 32, 30), Enum.Material.Fabric)
		part(model, "ShovelShaft", Vector3.new(0.24, 4.5, 0.24), rightHandCF * CFrame.new(0, 0.3, -1.2) * CFrame.Angles(math.rad(72), 0, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
		wedge(model, "ShovelSpade", Vector3.new(0.95, 0.2, 1.25), rightHandCF * CFrame.new(0, 0.85, -3.4) * CFrame.Angles(math.rad(72), 0, 0), steelCol, Enum.Material.Metal)
	elseif unitId == "Z-18" then
		-- Paciente Cero Eléctrico: bobinas Tesla dorsales y arcos de alta tensión
		for _, s in ipairs({ -1, 1 }) do
			local coil = part(model, "TeslaBackNode_" .. s, Vector3.new(0.55, 1.8, 0.55), torsoCF * CFrame.new(s * 0.65, 0.75, 0.7), elecNeon, Enum.Material.Neon)
			addGlowLight(coil, elecNeon, 1.8, 12)
		end
		part(model, "HighVoltageCable_R", Vector3.new(0.22, 2.2, 0.22), rightHandCF * CFrame.new(0, 0.6, -0.3), elecNeon, Enum.Material.Neon)
	elseif unitId == "Z-19" then
		-- Acechador Nocturno: 4 ojos carmesí adicionales, cresta dorsal de espinas negras y garras curvas
		for i = 1, 4 do
			wedge(model, "NightStalkerSpine_" .. i, Vector3.new(0.22, 0.95, 0.55), torsoCF * CFrame.new(0, 0.9 - i * 0.4, 0.75), Color3.fromRGB(190, 20, 35), Enum.Material.Neon)
		end
		for _, hCF in ipairs({ rightHandCF, leftHandCF }) do
			wedge(model, "NightScytheClaw", Vector3.new(0.18, 1.35, 0.45), hCF * CFrame.new(0, -0.55, -0.35), Color3.fromRGB(220, 25, 40), Enum.Material.Neon)
		end
	elseif unitId == "Z-20" then
		-- Amalgama de Carne: par extra de brazos secundarios y segunda cabeza mutada en el hombro izquierdo
		part(model, "FusedSecondHead", Vector3.new(0.95, 0.95, 0.95), torsoCF * CFrame.new(-0.95, 1.05, -0.25) * CFrame.Angles(0, 0, math.rad(28)), Color3.fromRGB(135, 85, 85), Enum.Material.Slate)
		for _, s in ipairs({ -1, 1 }) do
			part(model, "ExtraMutatedArm_" .. s, Vector3.new(0.65, 2.1, 0.65), torsoCF * CFrame.new(s * 1.35, -0.1, -0.55) * CFrame.Angles(math.rad(65), 0, s * math.rad(25)), Color3.fromRGB(145, 75, 75), Enum.Material.Slate)
		end
	elseif unitId == "Z-21" then
		-- Vómitor Ácido: estómago hinchado traslúcido verde y chorro ácido en mandíbula
		local sac = part(model, "AcidBellySac", Vector3.new(1.85, 1.65, 1.45), torsoCF * CFrame.new(0, -0.2, -0.45), toxicNeon, Enum.Material.Neon, Enum.PartType.Ball, 0.25)
		addGlowLight(sac, toxicNeon, 1.8, 12)
		part(model, "AcidMouthStream", Vector3.new(0.45, 0.85, 0.45), headCF * CFrame.new(0, -0.65, -0.65), toxicNeon, Enum.Material.Neon)
	elseif unitId == "Z-22" then
		-- Policía Infectado: gorra policial octogonal, placa dorada y Escopeta táctica
		part(model, "PoliceCap", Vector3.new(1.45, 0.45, 1.55), headCF * CFrame.new(0, 0.62, -0.08), Color3.fromRGB(25, 38, 68), Enum.Material.Fabric)
		part(model, "PoliceBadge", Vector3.new(0.32, 0.38, 0.12), torsoCF * CFrame.new(-0.45, 0.45, -0.58), Color3.fromRGB(245, 200, 55), Enum.Material.Metal)
		part(model, "ServiceShotgun_Body", Vector3.new(0.32, 0.48, 2.6), rightHandCF * CFrame.new(0, 0.1, -1.1), darkMetal, Enum.Material.Metal)
		part(model, "ServiceShotgun_Pump", Vector3.new(0.42, 0.38, 0.9), rightHandCF * CFrame.new(0, -0.1, -1.4), Color3.fromRGB(95, 60, 35), Enum.Material.Wood)
	elseif unitId == "Z-23" then
		-- Guardia de Seguridad: pistola 9mm en mano y radio táctica en hombro
		part(model, "SecurityPistol_9mm", Vector3.new(0.26, 0.45, 1.05), rightHandCF * CFrame.new(0, 0.1, -0.45), darkMetal, Enum.Material.Metal)
		part(model, "ShoulderRadio", Vector3.new(0.35, 0.55, 0.25), torsoCF * CFrame.new(0.75, 0.75, -0.55), darkMetal, Enum.Material.Metal)
	elseif unitId == "Z-24" then
		-- Soldado Caído (Rifle): casco militar verde oliva, chaleco y Rifle de Asalto G-05
		part(model, "CombatHelmet", Vector3.new(1.5, 0.65, 1.55), headCF * CFrame.new(0, 0.48, 0), Color3.fromRGB(62, 78, 56), Enum.Material.Slate)
		part(model, "AssaultRifle_G05", Vector3.new(0.32, 0.55, 2.85), rightHandCF * CFrame.new(0, 0.1, -1.2), darkMetal, Enum.Material.Metal)
		part(model, "AssaultRifle_Mag", Vector3.new(0.26, 0.75, 0.38), rightHandCF * CFrame.new(0, -0.35, -1.1), darkMetal, Enum.Material.Metal)
	elseif unitId == "Z-25" then
		-- Zombie Bomba de Gas: gran bombona roja de propano dorsal con válvula Neon parpadeante
		part(model, "PropaneBombTank", Vector3.new(2.2, 1.35, 1.35), torsoCF * CFrame.new(0, 0.25, 0.95) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(215, 38, 32), Enum.Material.Metal, Enum.PartType.Cylinder)
		local fuse = part(model, "BombWarningValve", Vector3.new(0.55, 0.55, 0.55), torsoCF * CFrame.new(0, 1.55, 0.95), fireNeon, Enum.Material.Neon, Enum.PartType.Ball)
		addGlowLight(fuse, fireNeon, 2.2, 14)
	elseif unitId == "Z-26" then
		-- Infectado con Subfusil: Uzi/MP5 con cargador largo
		part(model, "SMG_Receiver", Vector3.new(0.28, 0.48, 1.55), rightHandCF * CFrame.new(0, 0.1, -0.65), darkMetal, Enum.Material.Metal)
		part(model, "SMG_ExtendedMag", Vector3.new(0.22, 0.95, 0.28), rightHandCF * CFrame.new(0, -0.45, -0.65), steelCol, Enum.Material.Metal)
	elseif unitId == "Z-27" then
		-- Lanzador de Huesos: abanico de jabalinas óseas en espalda y lanza de hueso en mano
		for b = -1, 1 do
			wedge(model, "BackBoneSpike_" .. b, Vector3.new(0.25, 1.8, 0.35), torsoCF * CFrame.new(b * 0.5, 0.85, 0.65) * CFrame.Angles(math.rad(-25), 0, b * math.rad(15)), boneCol, Enum.Material.Slate)
		end
		part(model, "BoneJavelin_R", Vector3.new(0.22, 0.22, 3.4), rightHandCF * CFrame.new(0, 0.1, -1.2), boneCol, Enum.Material.Slate)
	elseif unitId == "Z-28" then
		-- Artillero Anclado (LMG): ametralladora pesada G-12 con tambor y cañón al rojo vivo
		part(model, "LMG_HeavyBody", Vector3.new(0.55, 0.68, 3.2), rightHandCF * CFrame.new(0, 0.1, -1.35), darkMetal, Enum.Material.Metal)
		part(model, "LMG_AmmoBox", Vector3.new(0.75, 0.75, 0.85), rightHandCF * CFrame.new(0, -0.35, -0.95), Color3.fromRGB(65, 85, 55), Enum.Material.Metal)
		part(model, "LMG_OverheatBarrel", Vector3.new(0.26, 0.26, 1.4), rightHandCF * CFrame.new(0, 0.15, -2.85), fireNeon, Enum.Material.Neon)
	elseif unitId == "Z-29" then
		-- Francotirador Zombificado: capucha ghillie musgosa y rifle largo con mira blanca brillante
		part(model, "GhillieShroud", Vector3.new(2.3, 1.6, 1.6), torsoCF * CFrame.new(0, 0.55, 0.15), Color3.fromRGB(65, 82, 52), Enum.Material.Grass)
		part(model, "SniperRifle_Long", Vector3.new(0.28, 0.45, 4.2), rightHandCF * CFrame.new(0, 0.15, -1.8), darkMetal, Enum.Material.Metal)
		part(model, "SniperScope_Glint", Vector3.new(0.32, 0.32, 0.95), rightHandCF * CFrame.new(0, 0.48, -1.5), Color3.fromRGB(245, 250, 255), Enum.Material.Neon)
	elseif unitId == "Z-30" then
		-- Portador de Barril Tóxico: carga un barril químico amarillo/verde frente al pecho
		part(model, "CarriedToxicBarrel", Vector3.new(2.2, 1.65, 1.65), torsoCF * CFrame.new(0, 0.25, -1.35) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(215, 185, 35), Enum.Material.Metal, Enum.PartType.Cylinder)
		part(model, "BarrelSludgeTop", Vector3.new(0.2, 1.5, 1.5), torsoCF * CFrame.new(0, 1.28, -1.35) * CFrame.Angles(0, 0, math.pi / 2), toxicNeon, Enum.Material.Neon, Enum.PartType.Cylinder)
	elseif unitId == "Z-31" then
		-- Infectado con Lanzallamas: 2 cilindros dorsales y cañón lanzallamas con piloto encendido
		for _, s in ipairs({ -0.48, 0.48 }) do
			part(model, "FuelCylinder_" .. tostring(s), Vector3.new(2.1, 0.75, 0.75), torsoCF * CFrame.new(s, 0.2, 0.85) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(190, 55, 30), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		part(model, "FlamethrowerNozzle", Vector3.new(0.38, 0.45, 2.7), rightHandCF * CFrame.new(0, 0.05, -1.15), darkMetal, Enum.Material.CorrodedMetal)
		part(model, "PilotFlameTip", Vector3.new(0.42, 0.42, 0.55), rightHandCF * CFrame.new(0, 0.05, -2.65), fireNeon, Enum.Material.Neon, Enum.PartType.Ball)
	elseif unitId == "Z-32" then
		-- Escupidor de Enjambre: colmena orgánica porosa incrustada en torso y hombro
		part(model, "InsectHiveMass", Vector3.new(1.65, 1.85, 1.55), torsoCF * CFrame.new(0.45, 0.35, -0.15), Color3.fromRGB(135, 115, 65), Enum.Material.Slate, Enum.PartType.Ball)
		for i = 1, 4 do
			part(model, "SwarmOrb_" .. i, Vector3.new(0.32, 0.32, 0.32), torsoCF * CFrame.new(math.cos(i * 1.5) * 1.35, 0.9 + (i % 2) * 0.4, math.sin(i * 1.5) * 1.1), Color3.fromRGB(165, 225, 55), Enum.Material.Neon, Enum.PartType.Ball)
		end
	elseif unitId == "Z-33" then
		-- Zombie con Lanzagranadas: lanzagranadas de tambor rotatorio G-14
		part(model, "GrenadeLauncher_Frame", Vector3.new(0.45, 0.55, 2.4), rightHandCF * CFrame.new(0, 0.1, -1.0), darkMetal, Enum.Material.Metal)
		part(model, "RotaryDrumMag", Vector3.new(0.85, 0.95, 0.95), rightHandCF * CFrame.new(0, -0.05, -0.95) * CFrame.Angles(0, math.pi / 2, 0), steelCol, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif unitId == "Z-34" then
		-- Artillero de Arpones: cañón arponero industrial con arpón sobresaliendo
		part(model, "HarpoonGun_Body", Vector3.new(0.48, 0.62, 2.7), rightHandCF * CFrame.new(0, 0.1, -1.1), Color3.fromRGB(145, 95, 45), Enum.Material.CorrodedMetal)
		wedge(model, "HarpoonSpearTip", Vector3.new(0.35, 0.35, 1.2), rightHandCF * CFrame.new(0, 0.1, -2.85), steelCol, Enum.Material.Metal)
	elseif unitId == "Z-35" then
		-- Comandante Infectado: gorra de oficial, inyector de furia en cuello y Revólver .44
		part(model, "CommanderPeakCap", Vector3.new(1.5, 0.55, 1.6), headCF * CFrame.new(0, 0.62, -0.05), Color3.fromRGB(95, 25, 28), Enum.Material.Fabric)
		part(model, "RageInjectorVial", Vector3.new(0.28, 0.95, 0.28), headCF * CFrame.new(0.65, -0.15, 0) * CFrame.Angles(0, 0, math.rad(-35)), Color3.fromRGB(255, 55, 85), Enum.Material.Neon)
		part(model, "Revolver44", Vector3.new(0.28, 0.52, 1.35), rightHandCF * CFrame.new(0, 0.15, -0.55), steelCol, Enum.Material.Metal)
	elseif unitId == "Z-36" then
		-- Blindado Antidisturbios: gran escudo balístico frontal con mirilla Glass + casco con visera
		part(model, "RiotHelmet", Vector3.new(1.55, 1.25, 1.55), headCF * CFrame.new(0, 0.12, 0), darkMetal, Enum.Material.Metal)
		part(model, "RiotBallisticShield", Vector3.new(2.4, 3.9, 0.32), leftHandCF * CFrame.new(0.35, 0.35, -0.75), darkMetal, Enum.Material.Metal)
		part(model, "RiotShieldViewport", Vector3.new(1.6, 0.65, 0.38), leftHandCF * CFrame.new(0.35, 1.25, -0.75), Color3.fromRGB(160, 215, 245), Enum.Material.Glass, nil, 0.35)
		part(model, "RiotShotgun", Vector3.new(0.32, 0.45, 2.2), rightHandCF * CFrame.new(0, 0.1, -0.9), steelCol, Enum.Material.Metal)
	elseif unitId == "Z-37" then
		-- Soldado Kevlar Pesado: peto Kevlar grueso, hombreras y casco blindado
		part(model, "HeavyKevlarVest", Vector3.new(2.35, 2.25, 1.55), torsoCF * CFrame.new(0, 0.1, 0), Color3.fromRGB(52, 60, 52), Enum.Material.Slate)
		part(model, "KevlarHelmet", Vector3.new(1.58, 0.85, 1.62), headCF * CFrame.new(0, 0.38, 0), Color3.fromRGB(52, 60, 52), Enum.Material.Slate)
	elseif unitId == "Z-38" then
		-- Juggernaut EOD: cuello blindado masivo, peto antibombas y Maza de Demolición
		part(model, "EOD_BlastSuitTorso", Vector3.new(2.65, 2.5, 1.85), torsoCF * CFrame.new(0, 0.1, 0), Color3.fromRGB(68, 72, 62), Enum.Material.Slate)
		part(model, "EOD_BlastCollar", Vector3.new(2.2, 0.85, 1.9), headCF * CFrame.new(0, -0.25, 0.05), Color3.fromRGB(55, 60, 50), Enum.Material.Metal)
		part(model, "EOD_SlamMaulShaft", Vector3.new(0.32, 3.8, 0.32), rightHandCF * CFrame.new(0, 0.2, -1.2) * CFrame.Angles(math.rad(75), 0, 0), steelCol, Enum.Material.Metal)
		part(model, "EOD_SlamMaulHead", Vector3.new(1.35, 1.1, 1.35), rightHandCF * CFrame.new(0, 0.7, -2.9) * CFrame.Angles(math.rad(75), 0, 0), darkMetal, Enum.Material.Metal)
	elseif unitId == "Z-39" then
		-- Soldador Acorazado: careta de soldador con ranura ígnea, tanque de acetileno en cadera y soplete
		part(model, "WelderMask", Vector3.new(1.48, 1.45, 0.45), headCF * CFrame.new(0, 0.05, -0.58), steelCol, Enum.Material.CorrodedMetal)
		part(model, "WelderVisorSlit", Vector3.new(1.05, 0.24, 0.52), headCF * CFrame.new(0, 0.18, -0.58), fireNeon, Enum.Material.Neon)
		part(model, "AcetyleneHipTank", Vector3.new(1.45, 0.72, 0.72), torsoCF * CFrame.new(-1.18, -0.65, 0.2) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(215, 45, 35), Enum.Material.Metal, Enum.PartType.Cylinder)
		part(model, "PlasmaTorchGun", Vector3.new(0.32, 0.45, 1.65), rightHandCF * CFrame.new(0, 0.1, -0.7), steelCol, Enum.Material.Metal)
		part(model, "PlasmaTorchArc", Vector3.new(0.28, 0.28, 0.65), rightHandCF * CFrame.new(0, 0.1, -1.75), elecNeon, Enum.Material.Neon)
	elseif unitId == "Z-40" then
		-- Minero Subterráneo: casco amarillo con lámpara SpotLight real y Pico Perforador
		part(model, "MinerHardHat", Vector3.new(1.52, 0.62, 1.62), headCF * CFrame.new(0, 0.52, 0), Color3.fromRGB(235, 190, 35), Enum.Material.SmoothPlastic)
		local lamp = part(model, "MinerHeadLamp", Vector3.new(0.42, 0.42, 0.35), headCF * CFrame.new(0, 0.62, -0.78), Color3.fromRGB(255, 250, 210), Enum.Material.Neon)
		local sl = Instance.new("SpotLight")
		sl.Color = Color3.fromRGB(255, 248, 200)
		sl.Brightness = 2.4
		sl.Range = 28
		sl.Angle = 55
		sl.Face = Enum.NormalId.Front
		sl.Parent = lamp
		part(model, "PickaxeShaft", Vector3.new(0.26, 3.4, 0.26), rightHandCF * CFrame.new(0, 0.2, -1.0) * CFrame.Angles(math.rad(75), 0, 0), Color3.fromRGB(120, 80, 45), Enum.Material.Wood)
		part(model, "PickaxeHeadCross", Vector3.new(2.2, 0.32, 0.35), rightHandCF * CFrame.new(0, 0.6, -2.5) * CFrame.Angles(math.rad(75), 0, 0), steelCol, Enum.Material.Metal)
	elseif unitId == "Z-51" then
		-- Bruto Estándar: venas carmesí y brazaletes de hormigón roto en ambos puños
		for _, hCF in ipairs({ rightHandCF, leftHandCF }) do
			part(model, "HulkFistGauntlet", Vector3.new(1.85, 1.95, 1.85), hCF, Color3.fromRGB(90, 95, 88), Enum.Material.Slate)
		end
	elseif unitId == "Z-52" then
		-- Aplastador Sísmico: placas de roca volcánica y anillos sísmicos naranjas en antebrazos
		for _, hCF in ipairs({ rightHandCF, leftHandCF }) do
			part(model, "SeismicRockFist", Vector3.new(2.2, 2.2, 2.2), hCF, Color3.fromRGB(65, 62, 58), Enum.Material.Slate)
			part(model, "SeismicShockRing", Vector3.new(2.35, 0.35, 2.35), hCF * CFrame.new(0, 0.5, 0), fireNeon, Enum.Material.Neon)
		end
	elseif unitId == "Z-53" then
		-- Pedrero Urbano: sostiene un enorme bloque de asfalto con varillas sobre las manos
		part(model, "HurledAsphaltBoulder", Vector3.new(4.8, 2.6, 3.4), torsoCF * CFrame.new(0, 2.2, -2.4) * CFrame.Angles(math.rad(12), math.rad(18), 0), Color3.fromRGB(48, 52, 56), Enum.Material.Asphalt)
		part(model, "BoulderRoadStripe", Vector3.new(0.6, 0.15, 3.3), torsoCF * CFrame.new(0.5, 3.52, -2.4) * CFrame.Angles(math.rad(12), math.rad(18), 0), Color3.fromRGB(240, 195, 45), Enum.Material.SmoothPlastic)
	elseif unitId == "Z-54" then
		-- Devorador: Mandíbula Pectoral Gigante abierta en el centro del tórax con colmillos
		part(model, "ChestMawCavity", Vector3.new(2.6, 2.4, 0.55), torsoCF * CFrame.new(0, 0.1, -1.25), Color3.fromRGB(95, 15, 22), Enum.Material.Slate)
		for t = -2, 2 do
			wedge(model, "ChestMawUpperTooth_" .. t, Vector3.new(0.35, 0.65, 0.45), torsoCF * CFrame.new(t * 0.48, 1.05, -1.45) * CFrame.Angles(math.pi, 0, 0), boneCol, Enum.Material.Slate)
			wedge(model, "ChestMawLowerTooth_" .. t, Vector3.new(0.35, 0.65, 0.45), torsoCF * CFrame.new(t * 0.48, -0.85, -1.45), boneCol, Enum.Material.Slate)
		end
	elseif unitId == "Z-55" then
		-- Colmillos XL: hojas óseas gigantes de 4 studs en ambos brazos y colmillos mandibulares XL
		for _, hCF in ipairs({ rightHandCF, leftHandCF }) do
			wedge(model, "XLBoneScytheBlade", Vector3.new(0.38, 1.2, 4.4), hCF * CFrame.new(0, -0.2, -1.8), boneCol, Enum.Material.Slate)
		end
		for _, s in ipairs({ -1, 1 }) do
			wedge(model, "XLTusk_" .. s, Vector3.new(0.32, 1.45, 0.45), headCF * CFrame.new(s * 0.55, -0.1, -0.85) * CFrame.Angles(math.rad(-25), 0, 0), boneCol, Enum.Material.Slate)
		end
	elseif unitId == "Z-56" then
		-- Acorazado de Hueso: exoesqueleto óseo calcificado con grietas amarillas Neon (punto débil x3)
		part(model, "CalcifiedCarapace_Chest", Vector3.new(4.1, 3.6, 2.7), torsoCF * CFrame.new(0, 0.2, 0), boneCol, Enum.Material.Slate)
		for c = -1, 1 do
			part(model, "WeakCrack_Neon_" .. c, Vector3.new(0.28, 2.8, 2.82), torsoCF * CFrame.new(c * 1.1, 0.2, 0) * CFrame.Angles(0, 0, math.rad(c * 14)), Color3.fromRGB(255, 225, 45), Enum.Material.Neon)
		end
	elseif unitId == "Z-57" then
		-- Hulk Tóxico: cráteres dorsales y venas de ácido Neon verde + luz tóxica
		local heart = part(model, "ToxicHulkCore", Vector3.new(2.2, 2.2, 2.2), torsoCF * CFrame.new(0, 0.3, -0.5), toxicNeon, Enum.Material.Neon, Enum.PartType.Ball, 0.15)
		addGlowLight(heart, toxicNeon, 2.6, 18)
		for i = 1, 4 do
			part(model, "AcidBackVent_" .. i, Vector3.new(0.95, 1.4, 0.95), torsoCF * CFrame.new((i - 2.5) * 0.95, 1.2, 1.15) * CFrame.Angles(math.rad(-25), 0, 0), toxicNeon, Enum.Material.Neon, Enum.PartType.Cylinder)
		end
	elseif unitId == "Z-58" then
		-- Hulk Ígneo: fisuras volcánicas incandescentes y cuernos de magma
		local heart = part(model, "IgnisHulkCore", Vector3.new(2.4, 2.4, 2.4), torsoCF * CFrame.new(0, 0.3, -0.45), fireNeon, Enum.Material.Neon, Enum.PartType.Ball, 0.1)
		addGlowLight(heart, fireNeon, 2.8, 18)
		for _, s in ipairs({ -1, 1 }) do
			wedge(model, "MagmaShoulderHorn_" .. s, Vector3.new(0.85, 2.4, 1.2), torsoCF * CFrame.new(s * 2.1, 2.2, 0.2) * CFrame.Angles(0, 0, s * math.rad(-22)), fireNeon, Enum.Material.Neon)
		end
	elseif unitId == "Z-59" then
		-- Titán Destructor: blande una Columna de Hormigón Armado de 9 studs con varillas expuestas
		part(model, "ConcretePillarClub", Vector3.new(1.85, 8.8, 1.85), rightHandCF * CFrame.new(0, 0.8, -3.2) * CFrame.Angles(math.rad(72), 0, 0), Color3.fromRGB(115, 118, 124), Enum.Material.Concrete)
		for r = -1, 1, 2 do
			part(model, "ExposedRebar_" .. r, Vector3.new(0.18, 2.2, 0.18), rightHandCF * CFrame.new(r * 0.45, 1.4, -7.8) * CFrame.Angles(math.rad(72), 0, 0), Color3.fromRGB(145, 75, 45), Enum.Material.CorrodedMetal)
		end
	elseif unitId == "Z-60" then
		-- Coloso de Zona: corona imperial de espinas óseas, hombreras monolíticas y núcleo de invocación
		for i = -2, 2 do
			wedge(model, "ZoneColossusCrown_" .. i, Vector3.new(0.55, 2.8, 0.95), torsoCF * CFrame.new(i * 0.85, 2.6, 0.85) * CFrame.Angles(math.rad(-20), 0, i * math.rad(-10)), boneCol, Enum.Material.Slate)
		end
		local core = part(model, "SummonerChestCore", Vector3.new(1.85, 1.85, 1.85), torsoCF * CFrame.new(0, 0.45, -1.15), Color3.fromRGB(130, 255, 95), Enum.Material.Neon, Enum.PartType.Ball)
		addGlowLight(core, Color3.fromRGB(130, 255, 95), 2.8, 20)
	end
end

--[[
	Construye una Bestia Infectada Cuadrúpeda o Simiesca (`Z-41` a `Z-50`, RIG-03)
	con anatomía animal articulada (4 patas con muslo/canilla/zarpa, torso animal, cuello, cabeza con fauces,
	cola y mutaciones propias de lobo, warg, oso, simio, pantera, hiena, jabalí o quimera).
--]]
local function buildBeastZombieRIG03(
	model: Model,
	unitId: string,
	originCF: CFrame,
	skinColor: Color3,
	accentColor: Color3
): BasePart
	local isApe = (unitId == "Z-44")
	local isBear = (unitId == "Z-45" or unitId == "Z-50")
	local isGhostCat = (unitId == "Z-46")
	local isMidnightPanther = (unitId == "Z-48")
	local isBoar = (unitId == "Z-49")
	local isAlpha = (unitId == "Z-43" or unitId == "Z-50")

	local scale = if unitId == "Z-50" then 1.45 elseif isBear or isApe then 1.32 elseif isAlpha then 1.22 else 1.0
	local trans = if isGhostCat then 0.42 else 0
	local bodyMat = if isGhostCat then Enum.Material.Glass elseif isMidnightPanther then Enum.Material.SmoothPlastic else Enum.Material.Slate

	local bodyColor = skinColor
	if isMidnightPanther then
		bodyColor = Color3.fromRGB(22, 24, 30)
	elseif isGhostCat then
		bodyColor = Color3.fromRGB(110, 215, 235)
	elseif isBear then
		bodyColor = Color3.fromRGB(78, 58, 46)
	elseif isBoar then
		bodyColor = Color3.fromRGB(85, 72, 62)
	end

	local bodyY = 2.4 * scale
	local rootPart = part(
		model,
		"HumanoidRootPart",
		Vector3.new(2.2 * scale, 1.8 * scale, 4.2 * scale),
		originCF * CFrame.new(0, bodyY, 0),
		bodyColor,
		bodyMat,
		nil,
		trans
	)

	-- Caja torácica delantera más ancha y grupa trasera
	part(
		model,
		"BeastChestRibcage",
		Vector3.new(2.5 * scale, 2.1 * scale, 2.4 * scale),
		originCF * CFrame.new(0, bodyY + (if isApe then 0.65 else 0.18) * scale, -1.0 * scale),
		bodyColor,
		bodyMat,
		nil,
		trans
	)
	part(
		model,
		"BeastHindquarters",
		Vector3.new(2.1 * scale, 1.75 * scale, 2.0 * scale),
		originCF * CFrame.new(0, bodyY - (if unitId == "Z-47" then 0.3 else 0) * scale, 1.2 * scale),
		bodyColor:Lerp(Color3.new(0, 0, 0), 0.12),
		bodyMat,
		nil,
		trans
	)

	-- Cabeza y Fauces Bestiales con colmillos
	local headCF = originCF * CFrame.new(0, bodyY + (if isApe then 1.45 else 0.95) * scale, -2.55 * scale)
	local beastHead = part(
		model,
		"Head",
		Vector3.new(1.55 * scale, 1.35 * scale, 1.85 * scale),
		headCF,
		bodyColor,
		bodyMat,
		nil,
		trans
	)
	-- Hocico y mandíbula inferior con colmillos
	part(
		model,
		"BeastSnoutUpper",
		Vector3.new(1.15 * scale, 0.62 * scale, 1.35 * scale),
		headCF * CFrame.new(0, -0.05 * scale, -1.1 * scale),
		bodyColor,
		bodyMat,
		nil,
		trans
	)
	part(
		model,
		"BeastJawLower",
		Vector3.new(0.98 * scale, 0.38 * scale, 1.25 * scale),
		headCF * CFrame.new(0, -0.58 * scale, -0.95 * scale) * CFrame.Angles(math.rad(22), 0, 0),
		Color3.fromRGB(115, 35, 38),
		Enum.Material.Slate,
		nil,
		trans
	)
	for _, s in ipairs({ -1, 1 }) do
		part(
			model,
			"BeastEye_" .. s,
			Vector3.new(0.24 * scale, 0.20 * scale, 0.24 * scale),
			headCF * CFrame.new(s * 0.48 * scale, 0.25 * scale, -0.78 * scale),
			accentColor,
			Enum.Material.Neon
		)
		wedge(
			model,
			"BeastFang_" .. s,
			Vector3.new(0.18 * scale, 0.55 * scale, 0.22 * scale),
			headCF * CFrame.new(s * 0.38 * scale, -0.35 * scale, -1.45 * scale),
			Color3.fromRGB(230, 222, 198),
			Enum.Material.Slate
		)
		wedge(
			model,
			"BeastEar_" .. s,
			Vector3.new(0.28 * scale, 0.68 * scale, 0.42 * scale),
			headCF * CFrame.new(s * 0.58 * scale, 0.85 * scale, 0.25 * scale),
			bodyColor,
			bodyMat,
			trans
		)
	end

	-- 4 Extremidades articuladas con zarpas apoyadas exactamente en Y = 0
	local legPositions = {
		{ "FrontLeft", Vector3.new(-1.15 * scale, 0, -1.35 * scale), true },
		{ "FrontRight", Vector3.new(1.15 * scale, 0, -1.35 * scale), true },
		{ "HindLeft", Vector3.new(-1.05 * scale, 0, 1.45 * scale), false },
		{ "HindRight", Vector3.new(1.05 * scale, 0, 1.45 * scale), false },
	}
	for _, lp in ipairs(legPositions) do
		local limbName = lp[1]
		local offset = lp[2]
		local isFront = lp[3]
		local limbThick = (if isFront and (isApe or isBear) then 0.95 else 0.68) * scale
		part(
			model,
			limbName .. "_UpperLeg",
			Vector3.new(limbThick, bodyY * 0.62, limbThick * 1.15),
			originCF * CFrame.new(offset.X, bodyY * 0.72, offset.Z) * CFrame.Angles(math.rad(if isFront then 12 else -14), 0, 0),
			bodyColor,
			bodyMat,
			nil,
			trans
		)
		part(
			model,
			limbName .. "_LowerLeg",
			Vector3.new(limbThick * 0.85, bodyY * 0.55, limbThick * 0.9),
			originCF * CFrame.new(offset.X, bodyY * 0.28, offset.Z + (if isFront then -0.15 else 0.15)),
			bodyColor:Lerp(Color3.new(0, 0, 0), 0.15),
			bodyMat,
			nil,
			trans
		)
		part(
			model,
			limbName .. "_ClawPaw",
			Vector3.new(limbThick * 1.05, 0.35 * scale, limbThick * 1.35),
			originCF * CFrame.new(offset.X, 0.18 * scale, offset.Z - 0.22 * scale),
			Color3.fromRGB(45, 42, 40),
			Enum.Material.Slate,
			nil,
			trans
		)
	end

	-- Rasgos únicos por especie bestial (Z-42 placas, Z-49 colmillos jabalí, Z-50 cornamenta quimera)
	if unitId == "Z-42" or unitId == "Z-49" then
		for p = 1, 4 do
			wedge(
				model,
				"BoneArmorRidge_" .. p,
				Vector3.new(1.8 * scale, 0.75 * scale, 0.95 * scale),
				originCF * CFrame.new(0, bodyY + 1.2 * scale, (-1.4 + p * 0.75) * scale),
				Color3.fromRGB(220, 212, 188),
				Enum.Material.Slate
			)
		end
	end
	if isBoar then
		for _, s in ipairs({ -1, 1 }) do
			wedge(
				model,
				"BoarGiantTusk_" .. s,
				Vector3.new(0.32 * scale, 1.35 * scale, 0.55 * scale),
				headCF * CFrame.new(s * 0.65 * scale, -0.1 * scale, -1.45 * scale) * CFrame.Angles(math.rad(35), 0, s * math.rad(-18)),
				Color3.fromRGB(235, 228, 205),
				Enum.Material.Slate
			)
		end
	end
	if unitId == "Z-50" then
		-- Quimera Zombie: gran cornamenta ósea ramificada y aliento tóxico Neon
		for _, s in ipairs({ -1, 1 }) do
			part(model, "ChimeraAntlerMain_" .. s, Vector3.new(0.28, 2.6, 0.28), headCF * CFrame.new(s * 0.75, 1.35, -0.1) * CFrame.Angles(math.rad(-18), 0, s * math.rad(-28)), Color3.fromRGB(225, 218, 195), Enum.Material.Slate)
			part(model, "ChimeraAntlerBranch_" .. s, Vector3.new(0.22, 1.5, 0.22), headCF * CFrame.new(s * 1.25, 1.85, -0.45) * CFrame.Angles(math.rad(25), 0, s * math.rad(-52)), Color3.fromRGB(225, 218, 195), Enum.Material.Slate)
		end
		local breath = part(model, "ChimeraToxicMawGlow", Vector3.new(0.95, 0.65, 0.95), headCF * CFrame.new(0, -0.35, -1.35), Color3.fromRGB(110, 255, 65), Enum.Material.Neon, Enum.PartType.Ball, 0.2)
		addGlowLight(breath, Color3.fromRGB(110, 255, 65), 2.4, 16)
	end

	local _ = beastHead
	return rootPart
end

--[[
	Construye el modelo 3D completo y detallado de cualquier Zombie (`Z-01`..`Z-60` y `Z-BOSS-01`)
	apoyado exactamente sobre `originCF.Position`.
--]]
function ZombieModelBuilder.buildZombieModel(unitId: string, originCF: CFrame): Model
	local unitDef = getZombieMeta(unitId)
	local unitName = unitDef.name
	local rigType = unitDef.masterRig
	local subFaction = unitDef.subFaction
	local cleanId = string.gsub(unitId, "%-", "")
	local blenderMeshPrefix = "mesh_zombie_" .. cleanId

	local model = Instance.new("Model")
	model.Name = string.format("%s_%s", unitId, string.gsub(unitName, "[^%w_]", ""))
	model:SetAttribute("ZA_UnitId", unitId)
	model:SetAttribute("ZA_UnitName", unitName)
	model:SetAttribute("ZA_Faction", "Zombie")
	model:SetAttribute("ZA_SubFaction", subFaction)
	model:SetAttribute("ZA_MasterRig", rigType)
	model:SetAttribute("ZA_BlenderMeshPrefix", blenderMeshPrefix)
	model:SetAttribute("ZA_BlenderShowcaseBundle", "exports/zombies-v4/ZA_All61Zombies_Showcase.fbx")
	if unitDef then
		model:SetAttribute("ZA_MaxHP", unitDef.hp)
		model:SetAttribute("ZA_DPS", unitDef.dps)
		model:SetAttribute("ZA_Speed", unitDef.speed)
	end
	CollectionService:AddTag(model, "ZA_ZombieModel")

	local hum = Instance.new("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	if unitDef then
		hum.MaxHealth = unitDef.hp
		hum.Health = unitDef.hp
		hum.WalkSpeed = unitDef.speed
	end
	hum.Parent = model

	local animator = Instance.new("Animator")
	animator.Parent = hum

	-- Si el creador ya importó la malla Blender (.fbx/.glb) en ReplicatedStorage.Assets.Zombies, clonarla directamente
	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	local zombiesAssets = if assetsRoot then assetsRoot:FindFirstChild("Zombies") else nil
	if zombiesAssets then
		for _, child in ipairs(zombiesAssets:GetChildren()) do
			if string.sub(child.Name, 1, #blenderMeshPrefix) == blenderMeshPrefix or child.Name == unitId then
				local cloned = child:Clone()
				if cloned:IsA("BasePart") then
					cloned.Name = "HumanoidRootPart"
					cloned.Anchored = true
					cloned.CanCollide = false
					cloned.CFrame = originCF * CFrame.new(0, cloned.Size.Y / 2, 0)
					cloned.Parent = model
					model.PrimaryPart = cloned
					return model
				elseif cloned:IsA("Model") then
					cloned:PivotTo(originCF)
					for _, desc in ipairs(cloned:GetChildren()) do
						desc.Parent = model
					end
					if not model.PrimaryPart then
						local firstPart = model:FindFirstChildWhichIsA("BasePart")
						if firstPart then
							firstPart.Name = "HumanoidRootPart"
							model.PrimaryPart = firstPart
						end
					end
					cloned:Destroy()
					return model
				end
			end
		end
	end

	-- Caso especial 1: Bestias Infectadas Cuadrúpedas / Simiescas (Z-41 a Z-50, RIG-03)
	if rigType == "RIG-03" then
		local root = buildBeastZombieRIG03(
			model,
			unitId,
			originCF,
			if unitDef then unitDef.primaryColor else Color3.fromRGB(75, 85, 78),
			if unitDef then unitDef.accentColor else Color3.fromRGB(220, 45, 45)
		)
		model.PrimaryPart = root
		return model
	end

	-- Caso especial 2: Reptante de Alcantarilla (Z-15, sin piernas, arrastrándose a ras del suelo)
	if unitId == "Z-15" then
		local skinCol = Color3.fromRGB(92, 108, 88)
		local torsoCF = originCF * CFrame.new(0, 0.65, 0) * CFrame.Angles(math.rad(-78), 0, 0)
		local root = part(model, "HumanoidRootPart", Vector3.new(1.85, 2.1, 1.05), torsoCF, skinCol, Enum.Material.Slate)
		model.PrimaryPart = root
		local headCF = originCF * CFrame.new(0, 1.15, -1.35)
		buildDetailedZombieHead(model, headCF, 1.0, skinCol, Color3.fromRGB(235, 45, 45), 0.5, Enum.Material.Slate)
		local rHandCF = originCF * CFrame.new(0.95, 0.35, -2.1)
		local lHandCF = originCF * CFrame.new(-0.95, 0.35, -1.85)
		part(model, "CrawlArm_R", Vector3.new(0.55, 0.55, 1.85), originCF * CFrame.new(1.05, 0.45, -1.2), skinCol, Enum.Material.Slate)
		part(model, "CrawlArm_L", Vector3.new(0.55, 0.55, 1.85), originCF * CFrame.new(-1.05, 0.45, -1.0), skinCol, Enum.Material.Slate)
		attachZombieSpecificMutationsAndGear(model, unitId, originCF, 1.0, rHandCF, lHandCF, torsoCF, headCF)
		return model
	end

	-- Determinar escala anatómica según RIG-04 (Humanoide 5.5 studs), RIG-05 (Bruto Hulk 11–14.5 studs) o RIG-06 (Dios Zombi Troll 26 studs)
	local scale = 1.0
	local torsoWidthMul = 1.0
	if rigType == "RIG-05" then
		scale = if unitId == "Z-60" then 2.45 elseif unitId == "Z-59" then 2.2 else 1.95
		torsoWidthMul = 1.42
	elseif rigType == "RIG-06" or unitId == "Z-BOSS-01" then
		scale = 4.55 -- ~26 studs de altura total
		torsoWidthMul = 1.58
	end

	-- Paleta de piel y vestimenta diferenciada por subfacción y unidad
	local skinColor = Color3.fromRGB(102, 118, 96)
	local clothUpper = Color3.fromRGB(58, 64, 72)
	local clothLower = Color3.fromRGB(42, 46, 54)
	local eyeColor = Color3.fromRGB(235, 45, 40)
	local skinMat = Enum.Material.Slate

	if unitId == "Z-05" or unitId == "Z-58" then
		skinColor = Color3.fromRGB(38, 34, 34)
		clothUpper = Color3.fromRGB(28, 24, 24)
		eyeColor = Color3.fromRGB(255, 130, 20)
	elseif unitId == "Z-06" or unitId == "Z-08" or unitId == "Z-21" or unitId == "Z-57" or unitId == "Z-BOSS-01" then
		skinColor = Color3.fromRGB(78, 108, 74)
		eyeColor = Color3.fromRGB(115, 255, 55)
	elseif unitId == "Z-07" then
		skinColor = Color3.fromRGB(128, 118, 135)
		eyeColor = Color3.fromRGB(185, 95, 255)
	elseif unitId == "Z-09" then
		clothUpper = Color3.fromRGB(165, 125, 32)
		clothLower = Color3.fromRGB(45, 42, 38)
	elseif unitId == "Z-10" then
		clothUpper = Color3.fromRGB(72, 148, 142)
		clothLower = Color3.fromRGB(62, 128, 124)
	elseif unitId == "Z-11" then
		clothUpper = Color3.fromRGB(155, 38, 38)
		clothLower = Color3.fromRGB(42, 58, 82)
	elseif unitId == "Z-12" then
		clothUpper = Color3.fromRGB(215, 105, 32)
		clothLower = Color3.fromRGB(205, 98, 28)
	elseif unitId == "Z-18" then
		skinColor = Color3.fromRGB(95, 115, 130)
		eyeColor = Color3.fromRGB(70, 220, 255)
	elseif unitId == "Z-19" then
		skinColor = Color3.fromRGB(26, 28, 36)
		clothUpper = Color3.fromRGB(18, 20, 26)
	elseif unitId == "Z-22" or unitId == "Z-36" then
		clothUpper = Color3.fromRGB(28, 42, 72)
		clothLower = Color3.fromRGB(22, 32, 56)
	elseif unitId == "Z-24" or unitId == "Z-33" or unitId == "Z-37" then
		clothUpper = Color3.fromRGB(62, 76, 54)
		clothLower = Color3.fromRGB(52, 64, 46)
	end

	-- Alturas anatómicas acumuladas desde Y = 0 (pies clavados al suelo)
	local footH = 0.35 * scale
	local shinH = 1.15 * scale
	local thighH = 1.15 * scale
	local pelvisY = footH + shinH + thighH
	local lowerTorsoH = 0.85 * scale
	local upperTorsoH = 1.45 * scale * (if torsoWidthMul > 1 then 1.12 else 1.0)
	local torsoCenterY = pelvisY + lowerTorsoH + upperTorsoH / 2

	local torsoCF = originCF * CFrame.new(0, torsoCenterY, 0) * CFrame.Angles(math.rad(-7), 0, 0)
	local rootPart = part(
		model,
		"HumanoidRootPart",
		Vector3.new(2.0 * scale * torsoWidthMul, upperTorsoH, 1.15 * scale * torsoWidthMul),
		torsoCF,
		clothUpper,
		Enum.Material.Fabric
	)
	model.PrimaryPart = rootPart

	-- Pelvis / Abdomen inferior
	local lowerTorsoCF = originCF * CFrame.new(0, pelvisY + lowerTorsoH / 2, 0.08 * scale)
	part(
		model,
		"LowerTorso",
		Vector3.new(1.75 * scale * torsoWidthMul, lowerTorsoH, 1.02 * scale * torsoWidthMul),
		lowerTorsoCF,
		clothLower,
		Enum.Material.Slate
	)

	-- Pectorales / Musculatura superior en Brutos y Jefe
	if torsoWidthMul > 1 then
		for _, s in ipairs({ -1, 1 }) do
			part(
				model,
				"BrutePectoral_" .. s,
				Vector3.new(1.35 * scale, 1.05 * scale, 0.45 * scale),
				torsoCF * CFrame.new(s * 0.72 * scale, 0.22 * scale, -0.68 * scale),
				skinColor,
				skinMat
			)
		end
	end

	-- Pierna Izquierda y Derecha (Muslo + Rodilla + Canilla + Bota/Pie en Y = footH/2)
	local hipOffsetX = 0.54 * scale * torsoWidthMul
	for _, s in ipairs({ -1, 1 }) do
		local sideLabel = if s < 0 then "Left" else "Right"
		part(
			model,
			sideLabel .. "UpperLeg",
			Vector3.new(0.82 * scale, thighH, 0.85 * scale),
			originCF * CFrame.new(s * hipOffsetX, footH + shinH + thighH / 2, 0.05 * scale),
			clothLower,
			Enum.Material.Fabric
		)
		part(
			model,
			sideLabel .. "LowerLeg",
			Vector3.new(0.72 * scale, shinH, 0.75 * scale),
			originCF * CFrame.new(s * hipOffsetX, footH + shinH / 2, 0.08 * scale),
			skinColor,
			skinMat
		)
		part(
			model,
			sideLabel .. "Foot",
			Vector3.new(0.78 * scale, footH, 1.25 * scale),
			originCF * CFrame.new(s * hipOffsetX, footH / 2, -0.18 * scale),
			Color3.fromRGB(34, 36, 40),
			Enum.Material.Slate
		)
	end

	-- Cuello y Cabeza detallada
	local headCF = torsoCF * CFrame.new(0, upperTorsoH / 2 + 0.72 * scale, -0.18 * scale) * CFrame.Angles(math.rad(7), 0, 0)
	part(
		model,
		"Neck",
		Vector3.new(0.68 * scale, 0.45 * scale, 0.68 * scale),
		torsoCF * CFrame.new(0, upperTorsoH / 2 + 0.18 * scale, -0.05 * scale),
		skinColor,
		skinMat
	)
	local jawOpen = if unitId == "Z-07" or unitId == "Z-54" or unitId == "Z-BOSS-01" then 1.2 else 0.35
	local headPart = buildDetailedZombieHead(model, headCF, scale, skinColor, eyeColor, jawOpen, skinMat)

	-- Brazos articulados (Hombro + Brazo Superior + Antebrazo + Mano/Garra)
	local shoulderX = (1.28 * torsoWidthMul) * scale
	local shoulderY = upperTorsoH / 2 - 0.22 * scale
	local armReachAngle = if subFaction == "Zombie_Ranged" then 68 else 48

	local rightHandCF = torsoCF
	local leftHandCF = torsoCF

	for _, s in ipairs({ -1, 1 }) do
		local sideLabel = if s < 0 then "Left" else "Right"
		local shCF = torsoCF * CFrame.new(s * shoulderX, shoulderY, 0)
		part(
			model,
			sideLabel .. "UpperArm",
			Vector3.new(0.75 * scale * torsoWidthMul, 1.25 * scale, 0.75 * scale * torsoWidthMul),
			shCF * CFrame.Angles(math.rad(armReachAngle * 0.65), 0, s * math.rad(8)) * CFrame.new(0, -0.55 * scale, 0),
			clothUpper,
			Enum.Material.Fabric
		)
		local forearmCF = shCF
			* CFrame.Angles(math.rad(armReachAngle), 0, s * math.rad(6))
			* CFrame.new(0, -1.55 * scale, -0.25 * scale)
		part(
			model,
			sideLabel .. "LowerArm",
			Vector3.new(0.68 * scale * torsoWidthMul, 1.2 * scale, 0.68 * scale * torsoWidthMul),
			forearmCF,
			skinColor,
			skinMat
		)
		local handCF = forearmCF * CFrame.new(0, -0.72 * scale, -0.1 * scale)
		part(
			model,
			sideLabel .. "Hand",
			Vector3.new(0.62 * scale * torsoWidthMul, 0.55 * scale, 0.65 * scale * torsoWidthMul),
			handCF,
			skinColor:Lerp(Color3.fromRGB(130, 30, 30), 0.3),
			skinMat
		)
		if s > 0 then
			rightHandCF = handCF
		else
			leftHandCF = handCF
		end
	end

	-- Caso especial 3: DIOS ZOMBI TROLL (Z-BOSS-01, 26 studs) con los 3 WeakPoints Oficiales y Monolitos Dorsales
	if unitId == "Z-BOSS-01" then
		local wpHead = part(
			model,
			"WeakPoint_Head",
			Vector3.new(1.8, 1.2, 1.8),
			headCF * CFrame.new(0, 2.8, 0),
			Color3.fromRGB(95, 255, 45),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		wpHead:SetAttribute("ZA_WeakPointMultiplier", 2.5)
		addGlowLight(wpHead, Color3.fromRGB(95, 255, 45), 3.2, 26)

		local wpChest = part(
			model,
			"WeakPoint_Chest",
			Vector3.new(3.2, 3.2, 1.6),
			torsoCF * CFrame.new(0, 0.5, -3.6),
			Color3.fromRGB(95, 255, 45),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		wpChest:SetAttribute("ZA_WeakPointMultiplier", 2.0)
		addGlowLight(wpChest, Color3.fromRGB(95, 255, 45), 3.5, 32)

		local wpBack = part(
			model,
			"WeakPoint_Back",
			Vector3.new(3.4, 3.8, 1.8),
			torsoCF * CFrame.new(0, 0.8, 3.6),
			Color3.fromRGB(120, 255, 65),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		wpBack:SetAttribute("ZA_WeakPointMultiplier", 2.2)

		-- Hombreras pétreas colosales y estalagmitas dorsales
		for _, s in ipairs({ -1, 1 }) do
			part(
				model,
				"TrollStonePauldron_" .. s,
				Vector3.new(5.5, 4.2, 5.8),
				torsoCF * CFrame.new(s * 6.8, 2.8, 0),
				Color3.fromRGB(52, 58, 52),
				Enum.Material.Slate
			)
			wedge(
				model,
				"TrollCrystalHorn_" .. s,
				Vector3.new(1.6, 5.5, 2.2),
				torsoCF * CFrame.new(s * 6.8, 6.8, 0.5) * CFrame.Angles(0, 0, s * math.rad(-18)),
				Color3.fromRGB(95, 255, 45),
				Enum.Material.Neon
			)
		end
	else
		attachZombieSpecificMutationsAndGear(model, unitId, originCF, scale, rightHandCF, leftHandCF, torsoCF, headCF)
	end

	local _ = headPart
	return model
end

--[[
	Construye la Galería / Pabellón de Inspección Detallada de los 61 Zombies (`ZA_ZombieShowcase_Gallery`)
	al costado oeste del Lobby Z0 para visualizar cada modelo a detalle con su pedestal y ficha técnica.
--]]
function ZombieModelBuilder.buildZombieShowcaseGallery(parent: Instance, galleryOrigin: Vector3): Folder
	local existing = parent:FindFirstChild("ZA_ZombieShowcase_Gallery")
	if existing then
		existing:Destroy()
	end

	local gallery = Instance.new("Folder")
	gallery.Name = "ZA_ZombieShowcase_Gallery"
	gallery.Parent = parent

	-- Plataforma pavimentada de exposición (260 x 150 studs) con iluminación y pasillos de inspección
	part(
		gallery,
		"ShowcaseFoundationDeck",
		Vector3.new(272, 2, 168),
		CFrame.new(galleryOrigin + Vector3.new(0, -1, 0)),
		Color3.fromRGB(48, 52, 58),
		Enum.Material.Concrete
	)
	part(
		gallery,
		"ShowcaseWalkwayFloor",
		Vector3.new(266, 0.16, 162),
		CFrame.new(galleryOrigin + Vector3.new(0, 0.08, 0)),
		Color3.fromRGB(34, 38, 44),
		Enum.Material.Slate
	)

	-- Muro de Cabecera de la Galería con Letrero Principal SurfaceGui
	local headerWall = part(
		gallery,
		"ShowcaseHeaderBannerWall",
		Vector3.new(96, 12, 2.5),
		CFrame.new(galleryOrigin + Vector3.new(0, 6, -78)),
		Color3.fromRGB(26, 32, 40),
		Enum.Material.CorrodedMetal
	)
	local sGui = Instance.new("SurfaceGui")
	sGui.Face = Enum.NormalId.Back
	sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sGui.PixelsPerStud = 32
	sGui.Parent = headerWall
	local hLbl = Instance.new("TextLabel")
	hLbl.Size = UDim2.new(0.96, 0, 0.86, 0)
	hLbl.Position = UDim2.new(0.02, 0, 0.07, 0)
	hLbl.BackgroundTransparency = 1
	hLbl.Font = Enum.Font.BuilderSansExtraBold
	hLbl.Text = "GALERÍA ANATÓMICA: 60 ZOMBIES (Z-01..Z-60) + DIOS ZOMBI TROLL (Z-BOSS-01)"
	hLbl.TextColor3 = Color3.fromRGB(120, 255, 95)
	hLbl.TextScaled = true
	hLbl.Parent = sGui

	local function createPedestalSign(pedestal: BasePart, unitId: string, nameText: string, subText: string, accent: Color3)
		local signPart = part(
			pedestal.Parent :: Instance,
			"Plaque_" .. unitId,
			Vector3.new(6.8, 2.4, 0.35),
			pedestal.CFrame * CFrame.new(0, 0.3, 4.1),
			Color3.fromRGB(18, 22, 28),
			Enum.Material.SmoothPlastic
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 36
		gui.LightInfluence = 0.15
		gui.Parent = signPart

		local t1 = Instance.new("TextLabel")
		t1.Size = UDim2.new(0.94, 0, 0.54, 0)
		t1.Position = UDim2.new(0.03, 0, 0.05, 0)
		t1.BackgroundTransparency = 1
		t1.Font = Enum.Font.BuilderSansExtraBold
		t1.Text = string.format("[%s] %s", unitId, nameText)
		t1.TextColor3 = Color3.fromRGB(245, 248, 255)
		t1.TextScaled = true
		t1.Parent = gui

		local t2 = Instance.new("TextLabel")
		t2.Size = UDim2.new(0.94, 0, 0.38, 0)
		t2.Position = UDim2.new(0.03, 0, 0.58, 0)
		t2.BackgroundTransparency = 1
		t2.Font = Enum.Font.BuilderSansBold
		t2.Text = subText
		t2.TextColor3 = accent
		t2.TextScaled = true
		t2.Parent = gui
	end

	-- Organizar las 4 filas por Subfacción para poder recorrerlas e inspeccionarlas cómodamente:
	-- Fila 1 (Z = -58): Z-01 a Z-20 (Melee & Mutaciones Urbanas)
	-- Fila 2 (Z = -24): Z-21 a Z-35 (Armados a Distancia & Explosivos)
	-- Fila 3 (Z = +10): Z-36 a Z-50 (Acorazados Z-36..40 + Bestias Cuadrúpedas Z-41..50)
	-- Fila 4 (Z = +48): Z-51 a Z-60 (Brutos Tipo Hulk/Troll 11–14.5 studs) + Z-BOSS-01 (Dios Zombi Troll 26 studs)
	local rows = {
		{ prefix = "Row1_Melee", zOffset = -58, startIdx = 1, endIdx = 20, spacing = 12.5, accent = Color3.fromRGB(235, 75, 75) },
		{ prefix = "Row2_Ranged", zOffset = -24, startIdx = 21, endIdx = 35, spacing = 14.5, accent = Color3.fromRGB(165, 235, 75) },
		{ prefix = "Row3_ArmoredAndBeasts", zOffset = 10, startIdx = 36, endIdx = 50, spacing = 14.5, accent = Color3.fromRGB(95, 205, 250) },
		{ prefix = "Row4_BrutesHulk", zOffset = 48, startIdx = 51, endIdx = 60, spacing = 18.5, accent = Color3.fromRGB(255, 175, 55) },
	}

	for _, r in ipairs(rows) do
		local count = r.endIdx - r.startIdx + 1
		local rowWidth = (count - 1) * r.spacing
		for idx = r.startIdx, r.endIdx do
			local unitId = string.format("Z-%02d", idx)
			local uDef = getZombieMeta(unitId)
			local colIndex = idx - r.startIdx
			local xPos = -rowWidth / 2 + colIndex * r.spacing
			local pedPos = galleryOrigin + Vector3.new(xPos, 0.5, r.zOffset)

			local ped = part(
				gallery,
				"Pedestal_" .. unitId,
				Vector3.new(7.5, 1.0, 7.5),
				CFrame.new(pedPos),
				Color3.fromRGB(62, 68, 76),
				Enum.Material.Concrete
			)
			-- Mirando hacia el Sur (+Z, hacia el pasillo del espectador)
			local modelCF = CFrame.new(pedPos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.pi, 0)
			local zModel = ZombieModelBuilder.buildZombieModel(unitId, modelCF)
			zModel.Parent = gallery

			createPedestalSign(
				ped,
				unitId,
				uDef.name,
				string.format("HP %d | DPS %d | %s", uDef.hp, uDef.dps, uDef.weaponOrTool),
				r.accent
			)
		end
	end

	-- Pedestal de Honor para el Mega Jefe: Z-BOSS-01 DIOS ZOMBI TROLL (26 studs) al extremo derecho de la Fila 4
	local bossPedPos = galleryOrigin + Vector3.new(108, 0.8, 48)
	local bossPed = part(
		gallery,
		"Pedestal_Z_BOSS_01",
		Vector3.new(18, 1.6, 18),
		CFrame.new(bossPedPos),
		Color3.fromRGB(42, 68, 46),
		Enum.Material.Slate
	)
	local bossCF = CFrame.new(bossPedPos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.pi, 0)
	local bossModel = ZombieModelBuilder.buildZombieModel("Z-BOSS-01", bossCF)
	bossModel.Parent = gallery
	createPedestalSign(
		bossPed,
		"Z-BOSS-01",
		"DIOS ZOMBI TROLL (26 STUDS)",
		"HP 30,000 | DPS 80 | 3 PUNTOS DÉBILES (CABEZA / PECHO / ESPALDA)",
		Color3.fromRGB(95, 255, 55)
	)

	return gallery
end

return ZombieModelBuilder
