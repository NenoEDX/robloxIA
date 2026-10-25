--!strict
--[[
	ZombieCatalogs.luau
	Catálogo Maestro Determinista de Zombie Awareness (v4.0):
	- 150 Unidades de 3 Facciones + 2 Mega Brutos Líderes (H-01..H-30, M-01..M-60 + M-BOSS-01, Z-01..Z-60 + Z-BOSS-01)
	- 32 Armas Modulares (Lv1–Lv10, 91 Módulos Geométricos) + Emisor de Conciencia G-20 (3 Tiers)
	- 6 Esqueletos Maestros (RIG-01 a RIG-06)
	- 9 Presets Matemáticos de VFX (ParticleEmitter & Beam)
	- Distritos Z0–Z7 + 2 Zonas Especiales Infinitas (Oeste y Este)
	- 16 Eventos Procedurales (E-01 a E-16) y Edificios del Refugio Propio (Catálogo A)
--]]

local Types = require(script.Parent:WaitForChild("Types") :: any)

local ZombieCatalogs = {}

--------------------------------------------------------------------------------
-- 1. LOS 9 PRESETS MATEMÁTICOS DE VFX (SECCIÓN 5.3)
--------------------------------------------------------------------------------

ZombieCatalogs.VFXPresets = {
	VFX_Muzzle_Ballistic = {
		id = "VFX_Muzzle_Ballistic",
		flipbookLayout = "Grid4x4",
		flipbookMode = "OneShot",
		colorStart = Color3.fromRGB(255, 255, 200),
		colorMid = Color3.fromRGB(255, 140, 20),
		colorEnd = Color3.fromRGB(80, 80, 80),
		sizeStart = 0.8,
		sizePeak = 2.2,
		sizeEnd = 0.5,
		squash = 0.4,
		lightEmission = 1.0,
		rate = 0,
		burstCount = 6,
		lifetimeMin = 0.08,
		lifetimeMax = 0.14,
		speedMin = 12,
		speedMax = 20,
		drag = 8,
		acceleration = Vector3.new(0, 0, 0),
	},
	VFX_Flame_Stream = {
		id = "VFX_Flame_Stream",
		flipbookLayout = "Grid8x8",
		flipbookMode = "OneShot",
		colorStart = Color3.fromRGB(180, 220, 255),
		colorMid = Color3.fromRGB(255, 160, 0),
		colorEnd = Color3.fromRGB(30, 30, 30),
		sizeStart = 1.2,
		sizePeak = 4.5,
		sizeEnd = 6.0,
		squash = 0,
		lightEmission = 0.85,
		rate = 65,
		burstCount = 12,
		lifetimeMin = 0.6,
		lifetimeMax = 0.9,
		speedMin = 35,
		speedMax = 45,
		drag = 2.5,
		acceleration = Vector3.new(0, 8, 0),
	},
	VFX_Toxic_Acid = {
		id = "VFX_Toxic_Acid",
		flipbookLayout = "Grid4x4",
		flipbookMode = "Loop",
		colorStart = Color3.fromRGB(160, 255, 40),
		colorMid = Color3.fromRGB(50, 200, 20),
		colorEnd = Color3.fromRGB(20, 70, 30),
		sizeStart = 1.5,
		sizePeak = 5.0,
		sizeEnd = 7.5,
		squash = -0.3,
		lightEmission = 0.4,
		rate = 25,
		burstCount = 30,
		lifetimeMin = 1.2,
		lifetimeMax = 2.0,
		speedMin = 4,
		speedMax = 10,
		drag = 3,
		acceleration = Vector3.new(0, -10, 0),
	},
	VFX_Tesla_Arc = {
		id = "VFX_Tesla_Arc",
		flipbookLayout = "Grid4x4",
		flipbookMode = "Random",
		colorStart = Color3.fromRGB(255, 255, 255),
		colorMid = Color3.fromRGB(60, 180, 255),
		colorEnd = Color3.fromRGB(20, 60, 200),
		sizeStart = 0.4,
		sizePeak = 1.8,
		sizeEnd = 0.2,
		squash = 0.6,
		lightEmission = 1.0,
		rate = 0,
		burstCount = 12,
		lifetimeMin = 0.1,
		lifetimeMax = 0.25,
		speedMin = 15,
		speedMax = 30,
		drag = 5,
		acceleration = Vector3.new(0, 0, 0),
	},
	VFX_Hypnosis_Wave = {
		id = "VFX_Hypnosis_Wave",
		flipbookLayout = "None",
		flipbookMode = "Loop",
		colorStart = Color3.fromRGB(0, 255, 220),
		colorMid = Color3.fromRGB(180, 60, 255),
		colorEnd = Color3.fromRGB(60, 0, 120),
		sizeStart = 0.5,
		sizePeak = 3.5,
		sizeEnd = 6.0,
		squash = 0,
		lightEmission = 1.0,
		rate = 40,
		burstCount = 20,
		lifetimeMin = 0.45,
		lifetimeMax = 0.55,
		speedMin = 28,
		speedMax = 32,
		drag = 1,
		acceleration = Vector3.new(0, 0, 0),
	},
	VFX_Hulk_Shockwave = {
		id = "VFX_Hulk_Shockwave",
		flipbookLayout = "Grid4x4",
		flipbookMode = "OneShot",
		colorStart = Color3.fromRGB(255, 80, 0),
		colorMid = Color3.fromRGB(140, 130, 120),
		colorEnd = Color3.fromRGB(70, 65, 60),
		sizeStart = 2.0,
		sizePeak = 6.0,
		sizeEnd = 8.0,
		squash = -0.5,
		lightEmission = 0.8,
		rate = 0,
		burstCount = 45,
		lifetimeMin = 0.4,
		lifetimeMax = 0.8,
		speedMin = 25,
		speedMax = 45,
		drag = 4,
		acceleration = Vector3.new(0, -35, 0),
	},
	VFX_Melee_Slash_Blood = {
		id = "VFX_Melee_Slash_Blood",
		flipbookLayout = "Grid4x4",
		flipbookMode = "OneShot",
		colorStart = Color3.fromRGB(180, 10, 10),
		colorMid = Color3.fromRGB(130, 5, 5),
		colorEnd = Color3.fromRGB(70, 0, 0),
		sizeStart = 0.6,
		sizePeak = 1.6,
		sizeEnd = 2.4,
		squash = 0.3,
		lightEmission = 0.0,
		rate = 0,
		burstCount = 15,
		lifetimeMin = 0.25,
		lifetimeMax = 0.45,
		speedMin = 10,
		speedMax = 22,
		drag = 2,
		acceleration = Vector3.new(0, -50, 0),
	},
	VFX_Rocket_Barrage = {
		id = "VFX_Rocket_Barrage",
		flipbookLayout = "Grid8x8",
		flipbookMode = "OneShot",
		colorStart = Color3.fromRGB(255, 255, 220),
		colorMid = Color3.fromRGB(255, 110, 0),
		colorEnd = Color3.fromRGB(25, 25, 25),
		sizeStart = 2.0,
		sizePeak = 10.0,
		sizeEnd = 14.0,
		squash = 0,
		lightEmission = 1.0,
		rate = 0,
		burstCount = 35,
		lifetimeMin = 0.5,
		lifetimeMax = 1.1,
		speedMin = 20,
		speedMax = 50,
		drag = 6,
		acceleration = Vector3.new(0, 4, 0),
	},
	VFX_Weapon_Lv10_Aura = {
		id = "VFX_Weapon_Lv10_Aura",
		flipbookLayout = "None",
		flipbookMode = "Loop",
		colorStart = Color3.fromRGB(255, 100, 0),
		colorMid = Color3.fromRGB(40, 160, 255),
		colorEnd = Color3.fromRGB(160, 40, 255),
		sizeStart = 0.15,
		sizePeak = 0.45,
		sizeEnd = 0.0,
		squash = 0,
		lightEmission = 1.0,
		rate = 18,
		burstCount = 10,
		lifetimeMin = 0.6,
		lifetimeMax = 1.0,
		speedMin = 0.5,
		speedMax = 1.5,
		drag = 1,
		acceleration = Vector3.new(0, 2, 0),
	},
} :: { [Types.VFXPresetId]: Types.VFXPresetConfig }

--------------------------------------------------------------------------------
-- 2. LOS 6 RIGS MAESTROS (SECCIÓN 5.2)
--------------------------------------------------------------------------------

ZombieCatalogs.MasterRigs = {
	["RIG-01"] = {
		id = "RIG-01",
		name = "R15_Human_Tactical",
		heightStuds = 5.5,
		description = "15 partes R15 + WeaponBone en RightHand y ShieldBone en LeftLowerArm",
	},
	["RIG-02"] = {
		id = "RIG-02",
		name = "R15_Mutant_Green",
		heightStuds = 5.8,
		description = "R15 con torso ensanchado 1.2x, BackTankBone y RPG_Bone",
	},
	["RIG-03"] = {
		id = "RIG-03",
		name = "Rig_Anthro_Predator",
		heightStuds = 5.8,
		description = "Esqueleto digitígrado con JawBone, Tail_01..03 y locomoción bípeda/cuadrúpeda",
	},
	["RIG-04"] = {
		id = "RIG-04",
		name = "R15_Zombie_Horde",
		heightStuds = 5.5,
		description = "R15 asimétrico con desfase de fotogramas y soporte de derribo por piernas",
	},
	["RIG-05"] = {
		id = "RIG-05",
		name = "Rig_QuadHulk_Brute",
		heightStuds = 11.0,
		description = "Esqueleto pesado 11 studs con GrabSocket y BackArtillerySocket (4 patas y bípedo)",
	},
	["RIG-06"] = {
		id = "RIG-06",
		name = "Rig_MegaBrute_Titan",
		heightStuds = 27.0,
		description = "Esqueleto colosal 26–28 studs con 28 huesos y WeakPoint_Head/Chest/Back",
	},
}

--------------------------------------------------------------------------------
-- 3. CATÁLOGO DE 150 UNIDADES + 2 MEGA BRUTOS LÍDERES (SECCIÓN 3)
--------------------------------------------------------------------------------

local Units: { [string]: Types.UnitDefinition } = {}

local function registerUnit(u: Types.UnitDefinition)
	Units[u.id] = u
end

-- 3.1.1 Especialistas Humanos (H-01 a H-08)
local humanSpecialists: { { any } } = {
	{ "H-01", "Ciudadano (Citizen)", 80, 10, 13, 18, "Tubo de hierro / Pistola 9mm", "Requisito Refugio; +100 Chatarra/día y amplía escuadrón", "VFX_Muzzle_Ballistic", "Scrap", 100 },
	{ "H-02", "Constructor (Builder)", 110, 22, 12, 6, "Martillo de obra / Llave inglesa", "Construye muros, barricadas y fábricas; +5 Componentes/día", "VFX_Melee_Slash_Blood", "Components", 5 },
	{ "H-03", "Ingeniero (Engineer)", 100, 25, 13, 25, "Soldador / Subfusil compacto", "Activa Generadores, Repellers y Torretas; +150 Chatarra/día", "VFX_Tesla_Arc", "Scrap", 150 },
	{ "H-04", "Médico de Campaña (Medic)", 95, 18, 14, 22, "Bisturí táctico / Pistola silenciada", "Desbloquea Enfermería; aura curación +5 HP/s en 15 studs", "VFX_Muzzle_Ballistic", "HealAura", 5 },
	{ "H-05", "Explorador (Ranger)", 115, 45, 16, 55, "Rifle de caza / Machete", "Reduce coste scouting; mejora señuelos; +5 Componentes/día", "VFX_Muzzle_Ballistic", "Components", 5 },
	{ "H-06", "Hacker de Campo", 85, 20, 14, 24, "Tablet blindada / Beretta", "Desbloquea ATMs, almacenes y Cachés Militares sin alarma", "VFX_Tesla_Arc", "Cores", 1 },
	{ "H-07", "Maestro Armero (Inspector VIP)", 140, 55, 13, 20, "Escopeta Remington personalizada", "Inspector VIP; escoltarlo desbloquea tiers de armas y armaduras", "VFX_Muzzle_Ballistic", "Components", 8 },
	{ "H-08", "Intendente / Mercader", 130, 30, 11, 18, "Escopeta recortada (Coach Gun)", "Gestiona Almacén y comercio de Núcleos; -15% coste munición", "VFX_Muzzle_Ballistic", "Scrap", 120 },
}

for _, row in ipairs(humanSpecialists) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Human",
		subFaction = "Human_Specialist",
		masterRig = "RIG-01",
		poolCategory = "Pool_Human",
		pathPriority = 4,
		hp = row[3],
		dps = row[4],
		speed = row[5],
		rangeStuds = row[6],
		heightStuds = 5.5,
		weaponOrTool = row[7],
		tacticalBehavior = row[8],
		vfxPreset = row[9],
		primaryColor = Color3.fromRGB(60, 130, 210),
		accentColor = Color3.fromRGB(120, 220, 255),
		hypnotizable = false,
		crucibleWeight = 0,
		passiveResourceType = row[10],
		passiveDailyAmount = row[11],
	})
end

-- 3.1.2 Fuerzas Humanas Melee (H-09 a H-18)
local humanMelee: { { any } } = {
	{ "H-09", "Miliciano de Calle", 110, 32, 15, 5, "Bate con Clavos (M-05)", "Patrulla Z1-Z2; aplica sangrado 4 dmg/s a corredores", "VFX_Melee_Slash_Blood" },
	{ "H-10", "Leñador Superviviente", 145, 48, 13, 6, "Hacha de Doble Filo (M-04)", "Rompe escudos de Zombies Blindados (Z-36) en 2 golpes", "VFX_Melee_Slash_Blood" },
	{ "H-11", "Guardia Antidisturbios", 220, 28, 11, 5, "Escudo Balístico (M-12) + Porra", "Muro de contención; bloquea 100% daño frontal y empuja", "VFX_Melee_Slash_Blood" },
	{ "H-12", "Guerrillero de Emboscada", 105, 65, 18, 5, "Cuchillo Ka-Bar / Daga (M-09)", "Sigilo en cobertura; crítico x2.5 por la espalda a mutantes", "VFX_Melee_Slash_Blood" },
	{ "H-13", "Demoledor de Trinchera", 175, 55, 12, 6, "Mazo Pesado Thor (M-06)", "Interrumpe canalizaciones y cargas de Brutos con golpe sísmico", "VFX_Hulk_Shockwave" },
	{ "H-14", "Espadachín Urbano", 125, 78, 17, 6, "Katana (M-03)", "Limpiador de hordas; 3er golpe ejecuta tajo frontal 120°", "VFX_Melee_Slash_Blood" },
	{ "H-15", "Bombero de Rescate", 190, 52, 12, 6, "Hacha de Bombero (M-11)", "Inmune al fuego; derriba puertas bloqueadas de 1 golpe", "VFX_Melee_Slash_Blood" },
	{ "H-16", "Lancero de Perímetro", 130, 42, 14, 9, "Lanza Improvisada (M-08)", "Ataca tras barricadas (alcance 9 studs) frenando Hulks", "VFX_Melee_Slash_Blood" },
	{ "H-17", "Carnicero del Páramo", 160, 85, 13, 5, "Motosierra (M-07)", "Daño continuo 12 ticks/s contra objetivos en fosos", "VFX_Melee_Slash_Blood" },
	{ "H-18", "Campeón de Arena", 260, 95, 15, 7, "Espadón de Chatarra / Guanteletes (M-01 Lv10)", "Élite en Z5-Z6; usa Quake Leap AoE y Taunt", "VFX_Hulk_Shockwave" },
}

for _, row in ipairs(humanMelee) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Human",
		subFaction = "Human_Melee",
		masterRig = "RIG-01",
		poolCategory = "Pool_Human",
		pathPriority = 4,
		hp = row[3],
		dps = row[4],
		speed = row[5],
		rangeStuds = row[6],
		heightStuds = 5.5,
		weaponOrTool = row[7],
		tacticalBehavior = row[8],
		vfxPreset = row[9],
		primaryColor = Color3.fromRGB(50, 110, 175),
		accentColor = Color3.fromRGB(220, 230, 245),
		hypnotizable = false,
		crucibleWeight = 0,
	})
end

-- 3.1.3 Fuerzas Humanas con Armas de Fuego, Guerrilla y Artillería (H-19 a H-30)
local humanRanged: { { any } } = {
	{ "H-19", "Recluta de Milicia", 100, 38, 14, 35, "Pistola Colt / Beretta (G-01)", "Infantería básica; retrocede disparando a <10 studs", "VFX_Muzzle_Ballistic" },
	{ "H-20", "Soldado Regular (Soldier)", 140, 68, 14, 45, "Rifle de Asalto (G-05)", "Columna defensiva de puestos avanzados; ráfagas en cobertura", "VFX_Muzzle_Ballistic" },
	{ "H-21", "Escopetero de Asalto", 150, 82, 13, 20, "Escopeta Winchester / Mossberg (G-07)", "Guardián de puertas; 8 perdigones y alto knockback", "VFX_Muzzle_Ballistic" },
	{ "H-22", "Guerrillero Urbano", 125, 75, 16, 38, "AK-74 / MP5 (G-03) + Molotov", "Flanqueador rápido en callejones; bloquea calles con fuego", "VFX_Flame_Stream" },
	{ "H-23", "Francotirador de Torre", 95, 110, 12, 85, "Dragunov / Barrett (G-10)", "Apostado en Torres (A-14); prioriza Gritones y Capitanes", "VFX_Muzzle_Ballistic" },
	{ "H-24", "Artillero de Apoyo", 180, 125, 10, 55, "Ametralladora M60 / Browning (G-12)", "Fuego de supresión continuo; reduce 30% avance de warbands", "VFX_Muzzle_Ballistic" },
	{ "H-25", "Purificador Químico", 165, 115, 11, 22, "Lanzallamas ROKS / M2 (G-15)", "Quema hordas masivas y enjambres de ratas; tanque protegido", "VFX_Flame_Stream" },
	{ "H-26", "Granadero de Asedio", 145, 90, 13, 50, "Lanzagranadas (G-14) + F1 Grenades", "Bombardea grupos tras muros; explosión AoE 8 studs", "VFX_Rocket_Barrage" },
	{ "H-27", "Zapador de Demolición", 155, 85, 13, 28, "Panzermine + Cargas C4 + Escopeta", "Siembra minas antitanque y vuela muros para abrir rutas", "VFX_Rocket_Barrage" },
	{ "H-28", "Operador Experimental", 135, 105, 14, 42, "Rifle Tesla (G-16) / Rifle Corrosivo (G-19)", "Científico armado Z5-Z7; encadena electricidad a 3 enemigos", "VFX_Tesla_Arc" },
	{ "H-29", "Capitán de Escuadrón (Captain)", 210, 140, 13, 65, "Bazooka / RPG (G-11) + Desert Eagle", "Oficial de alto rango; cohetes anti-Hulk y Rage Injection", "VFX_Rocket_Barrage" },
	{ "H-30", "Comandante de Bastión", 320, 180, 12, 60, "Minigun (G-13)", "Líder supremo Z6; aura de mando +25% daño y armadura", "VFX_Muzzle_Ballistic" },
}

for _, row in ipairs(humanRanged) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Human",
		subFaction = "Human_Ranged",
		masterRig = "RIG-01",
		poolCategory = "Pool_Human",
		pathPriority = 4,
		hp = row[3],
		dps = row[4],
		speed = row[5],
		rangeStuds = row[6],
		heightStuds = 5.5,
		weaponOrTool = row[7],
		tacticalBehavior = row[8],
		vfxPreset = row[9],
		primaryColor = Color3.fromRGB(40, 95, 160),
		accentColor = Color3.fromRGB(255, 200, 70),
		hypnotizable = false,
		crucibleWeight = 0,
	})
end

-- 3.2.1 Subfacción 1: Mutantes Normales Piel Verde (M-01 a M-25)
local mutantGreen: { { any } } = {
	{ "M-01", "Recluta Chasca", 65, 18, 15, 5, "Cuchillo oxidado (Combat Knife)", "Avanza en warbands 5+; primera línea de choque", "VFX_Melee_Slash_Blood" },
	{ "M-02", "Acuchillador Verde", 75, 24, 24, 5, "Doble cuchilla de chatarra (Gerber)", "Hit-and-Run en zigzag; apuñala y retrocede 10 studs", "VFX_Melee_Slash_Blood" },
	{ "M-03", "Saboteador de Campamento", 85, 20, 17, 8, "Machete + Bombas incendiarias", "Ignora al jugador para demoler barricadas, generadores y torretas", "VFX_Flame_Stream" },
	{ "M-04", "Explorador con Pistola", 70, 22, 16, 35, "Pistola Colt oxidada (G-01 Lv1)", "Cobertura ligera; lanza bengala verde para alertar warband", "VFX_Muzzle_Ballistic" },
	{ "M-05", "Pistolero Dual", 85, 34, 15, 32, "Dos pistolas Beretta Cheetah", "Flanqueador lateral con doble fogonazo alternado", "VFX_Muzzle_Ballistic" },
	{ "M-06", "Lanzador de Jabalinas", 70, 20, 13, 40, "Jabalinas con punta explosiva", "Tiro parabólico (18 m/s) contra soldados tras muros", "VFX_Rocket_Barrage" },
	{ "M-07", "Ballestero de Chatarra", 80, 26, 13, 35, "Ballesta pesada (Crossbow)", "Hitscan 35 studs con fuerte knockback; se agacha al recargar", "VFX_Muzzle_Ballistic" },
	{ "M-08", "Escopetero de Trinchera", 110, 38, 13, 15, "Escopeta de dos cañones (Coach Gun)", "Avanza de cobertura en cobertura y descarga ambos cañones", "VFX_Muzzle_Ballistic" },
	{ "M-09", "Asaltante con Subfusil", 95, 36, 16, 35, "Subfusil MP5 modificado", "Corre en parejas ejecutando maniobras de pinza (FLANK)", "VFX_Muzzle_Ballistic" },
	{ "M-10", "Fusilero de Warband", 115, 42, 14, 45, "Rifle AK-74 de chatarra", "Unidad estándar de fuego mutante Z3-Z5 a 45 studs", "VFX_Muzzle_Ballistic" },
	{ "M-11", "Tirador de Precisión", 90, 55, 12, 80, "Rifle Enfield / Dragunov", "Apostado en azoteas; láser rojo 1.5s antes del disparo", "VFX_Muzzle_Ballistic" },
	{ "M-12", "Chamán de Grito de Guerra", 105, 18, 13, 15, "Lanza ceremonial + Pistola bengalas", "Aura 15 studs (+30% daño e inmunidad al pánico mutante)", "VFX_Hulk_Shockwave" },
	{ "M-13", "Capataz de Escuadrón", 130, 32, 13, 40, "Látigo metálico (8 st) + Revólver .44", "Marca al jugador; todos los mutantes verdes concentran fuego", "VFX_Muzzle_Ballistic" },
	{ "M-14", "Artillero de Púas", 125, 44, 12, 42, "Cañón de Púas (G-18)", "Clavos ferroviarios magnetizados con 1 rebote en callejones", "VFX_Tesla_Arc" },
	{ "M-15", "Químico Bilioso", 115, 35, 12, 38, "Rifle Corrosivo (G-19) + Frascos ácido", "Reduce 20% armadura del jugador y corroe barricadas", "VFX_Toxic_Acid" },
	{ "M-16", "Incinerador Verde", 140, 48, 11, 22, "Lanzallamas Flammenwerfer", "Despeja edificios; tanque trasero explota en AoE si le disparan", "VFX_Flame_Stream" },
	{ "M-17", "Granadero de Chatarra", 130, 45, 13, 45, "Cinturón de Mills Bombs / Z Grenades", "Lanza granadas cada 4s para forzar salida de cobertura", "VFX_Rocket_Barrage" },
	{ "M-18", "Trampero de Asedio", 110, 30, 14, 28, "Escopeta automática (G-08) + Minas", "Despliega cepos y minas mientras ejecuta RETREAT", "VFX_Muzzle_Ballistic" },
	{ "M-19", "Supresor Pesado", 175, 58, 10, 50, "Ametralladora Slostin / M60", "Camina disparando desde cadera; hombreras -25% daño", "VFX_Muzzle_Ballistic" },
	{ "M-20", "Francotirador Anti-Blindaje", 105, 75, 11, 85, "Rifle Barrett de chatarra", "Élite Z5-Z6; perfora coberturas ligeras e inflige sangrado", "VFX_Muzzle_Ballistic" },
	{ "M-21", "Operador de Arco Voltaico", 135, 50, 13, 40, "Rifle Tesla robado (G-16)", "Ralentiza 25% al jugador y desactiva torretas humanas 3s", "VFX_Tesla_Arc" },
	{ "M-22", "Guardia Pretoriano Verde", 210, 46, 11, 30, "Escudo antidisturbios con púas + Subfusil", "Escolta de Capitanes Mutantes; dispara por tronera", "VFX_Muzzle_Ballistic" },
	{ "M-23", "Verdugo con Minigun", 240, 72, 9, 50, "Minigun de 4 barriles", "1.5s spin-up con sirena antes de lluvia de balas letal", "VFX_Muzzle_Ballistic" },
	{ "M-24", "Artillero de Mortero", 160, 65, 10, 80, "Mortero portátil + Pistola .44", "Dispara obuses verticales a 80 studs con círculo rojo 1.5s", "VFX_Rocket_Barrage" },
	{ "M-25", "Capitán Mutante Acorazado", 350, 95, 10, 65, "Lanzacohetes RPG / Stinger + Machete", "Líder táctico verde (-40% daño balístico); ordena cargas", "VFX_Rocket_Barrage" },
}

for _, row in ipairs(mutantGreen) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Mutant",
		subFaction = "Mutant_Green",
		masterRig = "RIG-02",
		poolCategory = "Pool_Mutant_Green",
		pathPriority = 3,
		hp = row[3],
		dps = row[4],
		speed = row[5],
		rangeStuds = row[6],
		heightStuds = 5.8,
		weaponOrTool = row[7],
		tacticalBehavior = row[8],
		vfxPreset = row[9],
		primaryColor = Color3.fromRGB(75, 145, 65),
		accentColor = Color3.fromRGB(190, 60, 40),
		hypnotizable = false,
		crucibleWeight = 8,
	})
end

-- 3.2.2 Subfacción 2: Mutantes Antropomórficos / "Furros" Melee (M-26 a M-50)
local mutantAnthro: { { any } } = {
	{ "M-26", "Ratonero Saqueador (M-A01)", 30, 10, 28, 4, "Incisivos infectados + Daga", "Enjambres 8-12; roba loot del suelo y huye a alcantarillas", "VFX_Melee_Slash_Blood" },
	{ "M-27", "Hombre-Hiena (M-A02)", 75, 18, 22, 5, "Mandíbula trituradora", "Risa estridente aplica micro-stun 0.5s antes de morder", "VFX_Melee_Slash_Blood" },
	{ "M-28", "Hombre-Serpiente (M-A03)", 85, 22, 16, 6, "Colmillos + Garras venenosas", "Se desliza bajo vehículos; veneno ignora armadura", "VFX_Toxic_Acid" },
	{ "M-29", "Hombre-Araña (M-A04)", 95, 24, 19, 14, "4 Brazos quitinosos + Red", "Trepa muros/techos; lanza red (-40% vel 3s) y cae en picada", "VFX_Melee_Slash_Blood" },
	{ "M-30", "Hombre-Lobo Mutante (M-A05)", 160, 32, 23, 6, "Garras XL de hueso", "Regenera 5 HP/s; caza en manadas coordinadas en ZvM", "VFX_Melee_Slash_Blood" },
	{ "M-31", "Buitrero Carroñero (M-A06)", 90, 22, 25, 6, "Espolones + Pico ganchudo", "Planea desde azoteas; devora cadáveres para curarse y buff vel", "VFX_Melee_Slash_Blood" },
	{ "M-32", "Cocodrilo de Alcantarilla (M-A07)", 220, 34, 14, 6, "Mandíbula + Cola acorazada", "Acecha en agua Z4; agarra con Death-Roll (QTE, 15 dmg/s)", "VFX_Melee_Slash_Blood" },
	{ "M-33", "Escorpido Acorazado (M-A08)", 135, 26, 15, 7, "Pinzas + Aguijón caudal", "Cola bloquea 60% daño melee frontal y paraliza 1s", "VFX_Toxic_Acid" },
	{ "M-34", "Crisálido de Quitina (M-A09)", 195, 28, 11, 5, "Cuchillas de antebrazo", "Caparazón biológico -50% daño balístico; exige melee o fuego", "VFX_Melee_Slash_Blood" },
	{ "M-35", "Camaleón Acechador", 95, 38, 21, 9, "Lengua prensil + Garras", "Mimetismo óptico (95% transparente inmóvil); crítico al pasar", "VFX_Melee_Slash_Blood" },
	{ "M-36", "Jabalí Rompelíneas", 185, 26, 25, 6, "Colmillos inferiores curvos", "Carga ciega recta que destruye barricadas y derriba (knockdown)", "VFX_Hulk_Shockwave" },
	{ "M-37", "Pantera Sombría", 140, 40, 27, 5, "Garras retráctiles", "Se desvanece en humo negro tras 4s sin visión y reaparece detrás", "VFX_Melee_Slash_Blood" },
	{ "M-38", "Tigre Dientes de Sable", 175, 44, 24, 7, "Colmillos gigantes + Zarpas", "Salta 18 studs desde arbustos; desgarra -15% armadura", "VFX_Melee_Slash_Blood" },
	{ "M-39", "Gorila Espalda Plateada", 260, 38, 15, 7, "Puños colosales", "Golpea suelo con onda sísmica AoE 7 studs (telegraph 0.8s)", "VFX_Hulk_Shockwave" },
	{ "M-40", "Oso Pardo Mutado", 310, 42, 13, 7, "Zarpas de demolición", "Tanque melee de warbands furras; barrido frontal 180°", "VFX_Melee_Slash_Blood" },
	{ "M-41", "Murciélago Vampiro", 110, 28, 26, 6, "Garras alares + Mordida", "Saltos acrobáticos; cada mordida cura 40% del daño (lifesteal)", "VFX_Melee_Slash_Blood" },
	{ "M-42", "Mantis Segadora", 120, 52, 23, 6, "Guadañas quitinosas", "4 golpes/s; golpe final del combo ignora bloqueo con escudo", "VFX_Melee_Slash_Blood" },
	{ "M-43", "Tejón Berserker", 150, 30, 18, 5, "Garras excavadoras", "Al <30% HP entra en Furia: inmune a stun, DPS 50 y vel 30", "VFX_Melee_Slash_Blood" },
	{ "M-44", "Tiburón de Fango", 210, 46, 17, 22, "Mandíbula aserrada + Ancla", "Lanza ancla encadenada que engancha y atrae al jugador", "VFX_Melee_Slash_Blood" },
	{ "M-45", "Avispa Verdugo", 95, 34, 28, 6, "Aguijón de antebrazo", "Flota a 4 studs del suelo; estocadas en picado de alta velocidad", "VFX_Toxic_Acid" },
	{ "M-46", "Puercoespín de Hierro", 180, 25, 14, 8, "Púas dorsales + Puños", "Refleja 35% daño melee y lanza abanico de púas a corta distancia", "VFX_Melee_Slash_Blood" },
	{ "M-47", "Toro Minotauro", 280, 48, 22, 7, "Cuernos acorazados + Hacha", "Carga arrastrando hacha; embestir contra muro aturde 1.5s", "VFX_Hulk_Shockwave" },
	{ "M-48", "Dragón de Komodo", 200, 36, 15, 6, "Mordida infecciosa + Coletazo", "Aplica Necrosis: reduce 50% curación recibida durante 8s", "VFX_Toxic_Acid" },
	{ "M-49", "Canguro Boxeador", 145, 35, 25, 6, "Guantes de chatarra + Patada", "Saltos evasivos laterales y doble patada frontal con knockback", "VFX_Hulk_Shockwave" },
	{ "M-50", "Quimera Alfa Antropomórfica (M-A10)", 380, 55, 19, 8, "Garras, Cuernos y Cola", "Mini-jefe Furro: adapta estilo según extremidad herida", "VFX_Hulk_Shockwave" },
}

for _, row in ipairs(mutantAnthro) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Mutant",
		subFaction = "Mutant_Anthro",
		masterRig = "RIG-03",
		poolCategory = "Pool_Mutant_Anthro",
		pathPriority = 3,
		hp = row[3],
		dps = row[4],
		speed = row[5],
		rangeStuds = row[6],
		heightStuds = 5.8,
		weaponOrTool = row[7],
		tacticalBehavior = row[8],
		vfxPreset = row[9],
		primaryColor = Color3.fromRGB(130, 95, 60),
		accentColor = Color3.fromRGB(255, 170, 30),
		hypnotizable = false,
		crucibleWeight = 10,
	})
end

-- 3.2.3 Subfacción 3: Brutos Mutantes Tipo Hulk (M-51 a M-60) + M-BOSS-01
local mutantBrutes: { { any } } = {
	{ "M-51", "Triturador Cuadrúpedo (M-H01)", 420, 38, 14, 8, "Corre en 4 patas; maza de hormigón", "Arranca asfalto y golpea suelo con screen-shake 8 studs", "VFX_Hulk_Shockwave" },
	{ "M-52", "Desgarrador XL (M-H02)", 450, 44, 18, 8, "Galope cuadrúpedo; garras óseas XL", "Salta en 4 patas con combo de 4 zarpazos (4to imbloqueable)", "VFX_Melee_Slash_Blood" },
	{ "M-53", "Cañonero de Chatarra (M-H03)", 440, 45, 10, 45, "4 patas; se yergue para lanzar vehículos", "Agarra coches y contenedores y los lanza cada 1.5s a 26 m/s", "VFX_Hulk_Shockwave" },
	{ "M-54", "Rompemuros (M-H04)", 580, 35, 12, 8, "Carga cuadrúpeda con cráneo blindado", "Destruye barricadas al instante y abre brechas en muros de 400 HP", "VFX_Hulk_Shockwave" },
	{ "M-55", "Bruto Granadero", 500, 50, 11, 40, "Cuadrúpedo con racimos de barriles/granadas", "Arroja abanico de 5 granadas de fragmentación o tóxicas", "VFX_Rocket_Barrage" },
	{ "M-56", "Sanguinario Voraz (M-H06)", 490, 40, 15, 8, "Acecho 4 patas; mandíbula desencajada", "Cada golpe o mordida le cura 50% del daño infligido", "VFX_Melee_Slash_Blood" },
	{ "M-57", "Saltarín Sísmico (M-H07)", 480, 42, 16, 50, "Impulso 4 extremidades", "Salta hasta 50 studs sobre edificios y cae en AoE 8 studs", "VFX_Hulk_Shockwave" },
	{ "M-58", "Bruto Artillero (Lanzacohetes)", 620, 65, 9, 70, "4 patas + Lanzacohetes Múltiple dorsal", "Dispara salvas de 3 cohetes guiados por láser hacia torretas", "VFX_Rocket_Barrage" },
	{ "M-59", "Colosales Secuestrador (M-H08)", 850, 45, 11, 10, "Bípedo/Cuadrúpedo masivo", "Agarra soldados/mercenarios en GrabSocket y los usa como garrote", "VFX_Hulk_Shockwave" },
	{ "M-60", "Alfa Supremo / Behemut (M-H09/10)", 1250, 55, 11, 18, "Jefe de Zona Mutante; brazos mutables", "Aura +30% daño zonal; muta brazos en maza, lanza, escudo o cañón", "VFX_Hulk_Shockwave" },
}

for _, row in ipairs(mutantBrutes) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Mutant",
		subFaction = "Mutant_Brute",
		masterRig = "RIG-05",
		poolCategory = "Pool_Brute",
		pathPriority = 2,
		hp = row[3],
		dps = row[4],
		speed = row[5],
		rangeStuds = row[6],
		heightStuds = 11.0,
		weaponOrTool = row[7],
		tacticalBehavior = row[8],
		vfxPreset = row[9],
		primaryColor = Color3.fromRGB(55, 115, 45),
		accentColor = Color3.fromRGB(255, 90, 20),
		hypnotizable = false,
		crucibleWeight = 35,
	})
end

registerUnit({
	id = "M-BOSS-01",
	name = "COLOSO MUTANTE SUPREMO (Mega Bruto Líder)",
	faction = "Mutant",
	subFaction = "Mutant_MegaBoss",
	masterRig = "RIG-06",
	poolCategory = "Pool_Brute",
	pathPriority = 1,
	hp = 32000,
	dps = 85,
	speed = 10,
	rangeStuds = 80,
	heightStuds = 28.0,
	weaponOrTool = "Armadura de Reactor Nuclear + Cohetes de Asedio + Camiones",
	tacticalBehavior = "Líder absoluto Mutante (Z7 y Falla Industrial Este); lanza camiones, salvas de cohetes, muros de carne y absorbe mutantes heridos",
	vfxPreset = "VFX_Rocket_Barrage",
	primaryColor = Color3.fromRGB(45, 100, 40),
	accentColor = Color3.fromRGB(120, 255, 60),
	hypnotizable = false,
	crucibleWeight = 1000,
})

-- 3.3.1 Subfacción 1: Zombies Melee y Mutaciones Urbanas (Z-01 a Z-20)
local zombieMelee: { { any } } = {
	{ "Z-01", "Caminante (Z-N01)", 45, 8, 8, 4, "Garras y mordida", "Grupos de 6 a 12; base del Object Pool masivo", "VFX_Melee_Slash_Blood" },
	{ "Z-02", "Corredor (Z-N02)", 40, 12, 22, 4, "Mordida frenética", "Acelera en zigzag (0.8s telegraph); si dañan piernas gatea", "VFX_Melee_Slash_Blood" },
	{ "Z-03", "Reventador Urbano (Z-N03)", 80, 18, 10, 5, "Tubo de plomo pesado", "Destruye puertas de madera y barricadas en 2 impactos", "VFX_Melee_Slash_Blood" },
	{ "Z-04", "Salvaje Saltador (Z-N04)", 55, 20, 18, 8, "Garras afiladas", "Salto rasante (lunge) de 15 studs telegrafiado 0.6s", "VFX_Melee_Slash_Blood" },
	{ "Z-05", "Ghoul Ardiente (Z-N05)", 60, 15, 12, 5, "Cuerpo en llamas", "Inmune al fuego; quema en radio 4 studs y explota al morir (25 dmg)", "VFX_Flame_Stream" },
	{ "Z-06", "Ghoul Marcador (Z-N06)", 50, 10, 10, 4, "Garras con feromonas", "Impregna al jugador 60s haciendo que la horda lo priorice", "VFX_Toxic_Acid" },
	{ "Z-07", "Gritón Invocador (Z-N08)", 70, 0, 11, 40, "Cuerdas vocales mutadas", "Cada 12s emite aullido que instancia 4 zombies del pool local", "VFX_Hypnosis_Wave" },
	{ "Z-08", "Pululante Tóxico (Z-N10)", 45, 8, 10, 4, "Pústulas infecciosas", "Al morir libera nube tóxica 8 studs (20 dmg + DoT 3s)", "VFX_Toxic_Acid" },
	{ "Z-09", "Bombero Infectado (Z-N11)", 130, 26, 11, 6, "Hacha de Bombero", "Inmune al fuego; hachazo pesado aplica knockdown 1.2s", "VFX_Melee_Slash_Blood" },
	{ "Z-10", "Cirujano del Distrito Médico", 75, 24, 15, 4, "Sierra ósea quirúrgica", "Spawn Z3; aplica hemorragia severa y -15% velocidad", "VFX_Melee_Slash_Blood" },
	{ "Z-11", "Leñador con Motosierra", 115, 32, 13, 5, "Motosierra oxidada", "Arcos descontrolados; destruye coberturas de madera al instante", "VFX_Melee_Slash_Blood" },
	{ "Z-12", "Preso Encadenado", 95, 22, 12, 7, "Bola de presidio con cadena", "Gira bola de acero en área corta; tropieza si falla", "VFX_Hulk_Shockwave" },
	{ "Z-13", "Cocinero Carnicero", 105, 25, 11, 5, "Dos cuchillos de carnicero", "Arroja un cuchillo al iniciar persecución y ataca con golpes dobles", "VFX_Melee_Slash_Blood" },
	{ "Z-14", "Atleta Infectado", 65, 16, 25, 4, "Placaje corporal", "Humanoide zombi más rápido; salta vallas bajas y empuja 6 studs", "VFX_Melee_Slash_Blood" },
	{ "Z-15", "Reptante de Alcantarilla", 35, 14, 14, 3, "Mordida a los tobillos", "Carece de piernas; se arrastra sin ser detectado por torretas altas", "VFX_Melee_Slash_Blood" },
	{ "Z-16", "Portador de Alambre", 85, 19, 11, 5, "Brazos con alambre de púas", "Engancha al jugador impidiendo usar Dash Táctico durante 2s", "VFX_Melee_Slash_Blood" },
	{ "Z-17", "Sepulturero", 100, 23, 10, 6, "Pala metálica", "Golpe vertical aturde 0.6s y levanta tierra que ciega cámara", "VFX_Hulk_Shockwave" },
	{ "Z-18", "Paciente Cero Eléctrico", 90, 22, 14, 5, "Cables de alta tensión", "Escapado Z3/Z7; descarga pulso eléctrico al ser golpeado en melee", "VFX_Tesla_Arc" },
	{ "Z-19", "Acechador Nocturno", 80, 28, 19, 5, "Garras alargadas", "Durante Noche de Caza (E-09) duplica visión y gana +25% daño/vel", "VFX_Melee_Slash_Blood" },
	{ "Z-20", "Amalgama de Carne", 160, 30, 9, 6, "Múltiples brazos fusionados", "Al morir se divide en 2 Reptantes (Z-15) independientes", "VFX_Melee_Slash_Blood" },
}

for _, row in ipairs(zombieMelee) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Zombie",
		subFaction = "Zombie_Melee",
		masterRig = "RIG-04",
		poolCategory = "Pool_Zombie_Base",
		pathPriority = 5,
		hp = row[3],
		dps = row[4],
		speed = row[5],
		rangeStuds = row[6],
		heightStuds = 5.5,
		weaponOrTool = row[7],
		tacticalBehavior = row[8],
		vfxPreset = row[9],
		primaryColor = Color3.fromRGB(105, 115, 100),
		accentColor = Color3.fromRGB(165, 35, 35),
		hypnotizable = true,
		crucibleWeight = 5,
	})
end

-- 3.3.2 Subfacción 2: Zombies Armados a Distancia y Portadores Explosivos (Z-21 a Z-35)
local zombieRanged: { { any } } = {
	{ "Z-21", "Vómitor Ácido (Z-N07)", 65, 14, 9, 30, "Proyectil de ácido (12 m/s)", "Escupe bola ácida que deja charco corrosivo (4 dmg/s por 5s)", "VFX_Toxic_Acid" },
	{ "Z-22", "Policía Infectado (Z-N12)", 95, 20, 12, 45, "Escopeta de servicio", "IA Híbrida Táctica-Z: cobertura ligera, 6 cartuchos, recarga 2.5s", "VFX_Muzzle_Ballistic" },
	{ "Z-23", "Guardia de Seguridad", 75, 15, 11, 35, "Pistola 9mm", "Dispara erráticamente por espasmos musculares mientras avanza", "VFX_Muzzle_Ballistic" },
	{ "Z-24", "Soldado Caído (Rifle)", 115, 26, 10, 50, "Rifle de Asalto (G-05)", "Spawn Z6; dedo trabado en gatillo con ráfagas largas de 10 balas", "VFX_Muzzle_Ballistic" },
	{ "Z-25", "Zombie Bomba de Gas (Action Bomb)", 80, 60, 15, 6, "Bombona de propano dorsal", "Corre hacia defensas y explota (AoE 6 studs) o si disparan al tanque", "VFX_Rocket_Barrage" },
	{ "Z-26", "Infectado con Subfusil", 85, 22, 14, 30, "Subfusil Uzi/MP5 encajado", "Corre disparando lluvia de balas en cono de 45°", "VFX_Muzzle_Ballistic" },
	{ "Z-27", "Lanzador de Huesos", 90, 24, 11, 40, "Costillas óseas afiladas", "Arranca crecimientos óseos del torso y los lanza como proyectiles", "VFX_Melee_Slash_Blood" },
	{ "Z-28", "Artillero Anclado (LMG)", 150, 35, 7, 55, "Ametralladora Ligera (G-12) fusionada", "Sin recarga pero se sobrecalienta tras ráfagas continuas", "VFX_Muzzle_Ballistic" },
	{ "Z-29", "Francotirador Zombificado", 80, 45, 8, 80, "Rifle de Francotirador", "Atado a torres de Z6; dispara con destello blanco previo", "VFX_Muzzle_Ballistic" },
	{ "Z-30", "Portador de Barril Tóxico", 110, 30, 10, 10, "Barril químico en brazos", "Arroja barril corrosivo a <10 studs contra muros o jugadores", "VFX_Toxic_Acid" },
	{ "Z-31", "Infectado con Lanzallamas", 135, 32, 9, 20, "Lanzallamas con fugas", "Barredor corto alcance; deja rastro de fuego en sus pisadas", "VFX_Flame_Stream" },
	{ "Z-32", "Escupidor de Enjambre", 95, 18, 10, 35, "Colmena de insectos necrófagos", "Dispara esfera de moscas carnívoras que persigue 4s", "VFX_Toxic_Acid" },
	{ "Z-33", "Zombie con Lanzagranadas", 125, 40, 9, 50, "Lanzagranadas de tambor (G-14)", "Antiguo militar Z6; granadas rebotan con fuego amigo zombi", "VFX_Rocket_Barrage" },
	{ "Z-34", "Artillero de Arpones", 105, 28, 11, 35, "Cañón arponero industrial", "Spawn Z5; arpón con cable Beam que ralentiza 50%", "VFX_Muzzle_Ballistic" },
	{ "Z-35", "Comandante Infectado (Pistola de Furia)", 140, 30, 12, 40, "Revólver .44 + Inyector roto", "Envenena soldados humanos y acelera +20% a zombies cercanos", "VFX_Muzzle_Ballistic" },
}

for _, row in ipairs(zombieRanged) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Zombie",
		subFaction = "Zombie_Ranged",
		masterRig = "RIG-04",
		poolCategory = "Pool_Zombie_Base",
		pathPriority = 5,
		hp = row[3],
		dps = row[4],
		speed = row[5],
		rangeStuds = row[6],
		heightStuds = 5.5,
		weaponOrTool = row[7],
		tacticalBehavior = row[8],
		vfxPreset = row[9],
		primaryColor = Color3.fromRGB(90, 105, 95),
		accentColor = Color3.fromRGB(140, 210, 60),
		hypnotizable = true,
		crucibleWeight = 8,
	})
end

-- 3.3.3 Subfacción 3: Zombies Acorazados y Bestias Infectadas (Z-36 a Z-50)
local zombieArmoredAndBeasts: { { any } } = {
	{ "Z-36", "Blindado Antidisturbios (Z-N09)", "RIG-04", 220, 16, 8, 18, "Escudo antidisturbios + Escopeta", "100% bloqueo frontal; débil por espalda, explosivos (x2) o Hacha M-04", "VFX_Muzzle_Ballistic" },
	{ "Z-37", "Soldado Kevlar Pesado", "RIG-04", 240, 22, 9, 5, "Chaleco y casco Kevlar", "-50% daño torso/cabeza; disparos a piernas lo derriban", "VFX_Melee_Slash_Blood" },
	{ "Z-38", "Juggernaut EOD (Desactivador)", "RIG-04", 320, 28, 6, 6, "Traje antibombas + Maza", "Inmune a explosiones/derribos; vulnerable a ácido G-19 y Tesla G-16", "VFX_Hulk_Shockwave" },
	{ "Z-39", "Soldador Acorazado", "RIG-04", 200, 25, 10, 6, "Placas de acero + Soplete", "Tanque de acetileno en cadera explota con 3 disparos precisos", "VFX_Flame_Stream" },
	{ "Z-40", "Minero Subterráneo", "RIG-04", 190, 30, 11, 5, "Casco reforzado + Pico perforador", "Inmune a headshot crítico; ignora 30% armadura; SpotLight frontal", "VFX_Melee_Slash_Blood" },
	{ "Z-41", "Sabueso Infectado (Z-A01)", "RIG-03", 55, 14, 26, 4, "Colmillos de jauría", "Rodea al jugador en grupos de 3+ antes de atacar al cuello", "VFX_Melee_Slash_Blood" },
	{ "Z-42", "Warg de Asedio (Z-A02)", "RIG-03", 90, 22, 24, 5, "Placas óseas + Embestida", "Aplica knockdown 0.8s; disparar patas delanteras lo hace rodar", "VFX_Melee_Slash_Blood" },
	{ "Z-43", "Alfa Lobo Infectado (Z-A03)", "RIG-03", 240, 28, 20, 6, "Líder de Manada", "Aullido invoca 4 Wargs/Sabuesos y da +25% daño a bestias", "VFX_Melee_Slash_Blood" },
	{ "Z-44", "Simio Demoledor (Z-A04)", "RIG-03", 160, 24, 14, 7, "Puños bestiales", "Trepa prefabs en Z4 y cae con onda AoE 7 studs; headshot x2.5", "VFX_Hulk_Shockwave" },
	{ "Z-45", "Oso Zombie (Z-A05)", "RIG-03", 300, 30, 12, 7, "Zarpas necrosadas", "Tanque bestial con barrido frontal AoE; vulnerable por espalda", "VFX_Melee_Slash_Blood" },
	{ "Z-46", "Felino Fantasma (Z-A06)", "RIG-03", 120, 26, 28, 6, "Garras + Sigilo (20% opacidad)", "Salta sobre retaguardia; Pulso de Conciencia revela su silueta", "VFX_Melee_Slash_Blood" },
	{ "Z-47", "Hiena Necrófaga (Z-A07)", "RIG-03", 60, 12, 22, 5, "Risa gutural + Mordida", "Ataca en círculos 3-5; risa aplica micro-aturdimiento 0.5s", "VFX_Melee_Slash_Blood" },
	{ "Z-48", "Pantera de Medianoche (Z-A08)", "RIG-03", 130, 32, 26, 5, "Garras sombrías", "Crítico x2.5 por la espalda; Escudo M-12 anula su crítico", "VFX_Melee_Slash_Blood" },
	{ "Z-49", "Jabalí Acorazado (Z-A09)", "RIG-03", 170, 20, 24, 6, "Placas óseas frontales", "Pulveriza mesas/vallas; se aturde 1s si choca contra hormigón", "VFX_Hulk_Shockwave" },
	{ "Z-50", "Quimera Zombie (Z-A10)", "RIG-03", 450, 34, 18, 8, "Fusión oso/lobo/ciervo + Aliento tóxico", "Mini-jefe: adapta ataques según daño localizado en patas o cabeza", "VFX_Toxic_Acid" },
}

for _, row in ipairs(zombieArmoredAndBeasts) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Zombie",
		subFaction = "Zombie_ArmoredBeast",
		masterRig = row[3],
		poolCategory = "Pool_Zombie_Base",
		pathPriority = 4,
		hp = row[4],
		dps = row[5],
		speed = row[6],
		rangeStuds = row[7],
		heightStuds = 5.6,
		weaponOrTool = row[8],
		tacticalBehavior = row[9],
		vfxPreset = row[10],
		primaryColor = Color3.fromRGB(70, 80, 75),
		accentColor = Color3.fromRGB(185, 45, 45),
		hypnotizable = row[1] ~= "Z-50",
		crucibleWeight = 12,
	})
end

-- 3.3.4 Subfacción 4: Brutos Zombies Tipo Hulk/Troll (Z-51 a Z-60) + Z-BOSS-01
local zombieBrutes: { { any } } = {
	{ "Z-51", "Bruto Estándar (Z-H01)", 420, 35, 9, 7, "Puños hipertrofiados", "Tanque melee puro; cada puñetazo genera screen-shake 6 studs", "VFX_Hulk_Shockwave" },
	{ "Z-52", "Aplastador Sísmico (Z-H02)", 480, 70, 8, 10, "Salto vertical AoE", "Aterriza aplastando radio 10 studs (telegraph 1.0s); exige Dash", "VFX_Hulk_Shockwave" },
	{ "Z-53", "Pedrero Urbano (Z-H03)", 400, 38, 7, 42, "Trozos de asfalto y coches", "Lanza vehículos a 14 m/s con explosión AoE 6 studs", "VFX_Hulk_Shockwave" },
	{ "Z-54", "Devorador (Z-H04)", 500, 45, 10, 7, "Mandíbula pectoral gigante", "Agarra y devora 2.5s (20 dmg/s); requiere QTE o golpe aliado", "VFX_Melee_Slash_Blood" },
	{ "Z-55", "Colmillos XL (Z-H05)", 450, 40, 14, 8, "Garras de hueso desproporcionadas", "Hulk zombi más veloz; 3er zarpazo atraviesa cualquier bloqueo", "VFX_Melee_Slash_Blood" },
	{ "Z-56", "Acorazado de Hueso (Z-H06)", 600, 28, 6, 7, "Placas óseas calcificadas", "-50% daño general; grietas amarillas Neon reciben daño x3", "VFX_Hulk_Shockwave" },
	{ "Z-57", "Hulk Tóxico (Z-H07)", 430, 20, 8, 9, "Aura corrosiva 9 studs", "Daña al jugador y derrite coberturas cercanas continuamente", "VFX_Toxic_Acid" },
	{ "Z-58", "Hulk Ígneo (Z-H08)", 430, 20, 8, 8, "Aura ígnea 8 studs", "Inmune al fuego; deja charcos de llamas persistentes al pisar", "VFX_Flame_Stream" },
	{ "Z-59", "Titán Destructor (Z-H09)", 900, 45, 9, 12, "Columna de hormigón con varillas", "Mini-jefe que abre huecos en muros de prefabs (400 HP)", "VFX_Hulk_Shockwave" },
	{ "Z-60", "Coloso de Zona (Z-H10)", 1200, 50, 8, 12, "Ondas en anillo + Invocación", "Jefe de Zona Zombie: invoca 3 Caminantes/Corredores cada 20s", "VFX_Hulk_Shockwave" },
}

for _, row in ipairs(zombieBrutes) do
	registerUnit({
		id = row[1],
		name = row[2],
		faction = "Zombie",
		subFaction = "Zombie_Brute",
		masterRig = "RIG-05",
		poolCategory = "Pool_Brute",
		pathPriority = 2,
		hp = row[3],
		dps = row[4],
		speed = row[5],
		rangeStuds = row[6],
		heightStuds = 11.0,
		weaponOrTool = row[7],
		tacticalBehavior = row[8],
		vfxPreset = row[9],
		primaryColor = Color3.fromRGB(80, 90, 85),
		accentColor = Color3.fromRGB(120, 255, 80),
		hypnotizable = false,
		crucibleWeight = 35,
	})
end

registerUnit({
	id = "Z-BOSS-01",
	name = "DIOS ZOMBI TROLL (Mega Bruto Líder)",
	faction = "Zombie",
	subFaction = "Zombie_MegaBoss",
	masterRig = "RIG-06",
	poolCategory = "Pool_Brute",
	pathPriority = 1,
	hp = 30000,
	dps = 80,
	speed = 9,
	rangeStuds = 60,
	heightStuds = 26.0,
	weaponOrTool = "Piel Pétrea Necrótica + Grietas de Energía Tóxica",
	tacticalBehavior = "Líder Supremo Zombie (Z7 y Foso de la Masacre Oeste): 4 fases (lanza jugadores, invoca 6 corredores/15s, agrieta el suelo y expone núcleos en F4)",
	vfxPreset = "VFX_Hulk_Shockwave",
	primaryColor = Color3.fromRGB(65, 75, 65),
	accentColor = Color3.fromRGB(80, 255, 40),
	hypnotizable = false,
	crucibleWeight = 1000,
})

ZombieCatalogs.Units = Units

--------------------------------------------------------------------------------
-- 4. ARSENAL MODULAR DE 32 ARMAS (LV 1 A LV 10) + EMISOR G-20 (SECCIÓN 4.1 Y 5.1)
--------------------------------------------------------------------------------

ZombieCatalogs.MaterialTiers = {
	[1] = "Tier1_Scrap_Rust",
	[2] = "Tier2_Salvaged_Iron",
	[3] = "Tier3_Militia_Steel",
	[4] = "Tier4_Reinforced_Polymer",
	[5] = "Tier5_SpecOps_Carbon",
	[6] = "Tier6_Hardened_Titanium",
	[7] = "Tier7_BioHazard_Anodized",
	[8] = "Tier8_Voltaic_Prototype",
	[9] = "Tier9_Apex_Composite",
	[10] = "Tier10_Consciousness_Neon",
}

ZombieCatalogs.ModularPartPools = {
	ReceiversCount = 32, -- Receiver_G01 .. Receiver_M12
	BarrelsCount = 10, -- Barrel_01 .. Barrel_10
	StocksCount = 8, -- Stock_01 .. Stock_08
	MagsCount = 8, -- Mag_01 .. Mag_08
	OpticsCount = 12, -- Optic_01 .. Optic_12
	MuzzlesCount = 8, -- Muzzle_01 .. Muzzle_08
}

local Weapons: { [string]: Types.WeaponDefinition } = {}

local function registerWeapon(w: Types.WeaponDefinition)
	Weapons[w.id] = w
end

local weaponRows: { { any } } = {
	-- Armas de Fuego y Especiales (G-01 a G-20)
	{ "G-01", "01P1", "Pistola Colt / Beretta 9mm", "Pistol", "Secondary", "Light", 24, 4.5, 15, 1.4, 65, 2.5, 2.5, "VFX_Muzzle_Ballistic", Color3.fromRGB(40, 160, 255) },
	{ "G-02", "01P3", "Revólver .44 / Desert Eagle", "Pistol", "Secondary", "Light", 58, 2.2, 8, 1.8, 75, 1.8, 2.5, "VFX_Muzzle_Ballistic", Color3.fromRGB(255, 190, 50) },
	{ "G-03", "03A1", "Subfusil MP5 / Uzi Táctico", "Rifle", "Primary", "Light", 20, 10.0, 32, 1.6, 55, 4.0, 2.2, "VFX_Muzzle_Ballistic", Color3.fromRGB(80, 220, 255) },
	{ "G-04", "03A1-S", "Subfusil Táctico Silenciado", "Rifle", "Secondary", "Light", 22, 9.0, 28, 1.5, 60, 3.2, 2.5, "VFX_Muzzle_Ballistic", Color3.fromRGB(100, 255, 200) },
	{ "G-05", "03A2", "Rifle de Asalto AK-74 / M4", "Rifle", "Primary", "Medium", 34, 7.5, 30, 2.0, 95, 2.2, 2.5, "VFX_Muzzle_Ballistic", Color3.fromRGB(255, 100, 0) },
	{ "G-06", "03A2-B", "Carabina de Ráfaga Táctica", "Rifle", "Primary", "Medium", 38, 6.8, 27, 1.9, 105, 1.6, 2.5, "VFX_Muzzle_Ballistic", Color3.fromRGB(255, 140, 40) },
	{ "G-07", "02S2", "Escopeta Winchester / Mossberg", "Shotgun", "Primary", "Heavy", 88, 1.4, 8, 2.4, 35, 6.5, 2.0, "VFX_Muzzle_Ballistic", Color3.fromRGB(255, 70, 70) },
	{ "G-08", "02S3", "Escopeta Automática de Tambor", "Shotgun", "Primary", "Heavy", 62, 3.2, 12, 2.6, 32, 7.5, 2.0, "VFX_Muzzle_Ballistic", Color3.fromRGB(255, 50, 90) },
	{ "G-09", "04SR1", "Rifle de Caza / Enfield", "Rifle", "Sniper", "Medium", 95, 1.5, 6, 2.2, 140, 0.5, 3.0, "VFX_Muzzle_Ballistic", Color3.fromRGB(120, 255, 120) },
	{ "G-10", "04SR3", "Francotirador Dragunov / Barrett .50", "Rifle", "Sniper", "Medium", 165, 1.1, 5, 2.8, 180, 0.2, 3.0, "VFX_Muzzle_Ballistic", Color3.fromRGB(255, 40, 120) },
	{ "G-11", "06RL2", "Lanzacohetes Anti-Hulk RPG / Stinger", "Heavy", "Special", "Explosive", 280, 0.6, 2, 3.2, 110, 1.0, 1.5, "VFX_Rocket_Barrage", Color3.fromRGB(255, 120, 0) },
	{ "G-12", "05MG1", "Ametralladora Pesada M60 / Browning", "Heavy", "Primary", "Heavy", 36, 9.5, 80, 3.5, 85, 3.8, 2.2, "VFX_Muzzle_Ballistic", Color3.fromRGB(255, 200, 40) },
	{ "G-13", "05MG3", "Minigun de 6 Barriles", "Heavy", "Special", "Heavy", 28, 16.0, 150, 4.0, 75, 5.0, 2.0, "VFX_Muzzle_Ballistic", Color3.fromRGB(255, 215, 0) },
	{ "G-14", "07GL", "Lanzagranadas de Tambor MGL", "Heavy", "Special", "Explosive", 145, 1.8, 6, 3.0, 70, 2.0, 1.5, "VFX_Rocket_Barrage", Color3.fromRGB(255, 95, 30) },
	{ "G-15", "09F1", "Lanzallamas ROKS / M2 Purificador", "Heavy", "Special", "Special", 18, 12.0, 100, 2.8, 24, 8.0, 1.2, "VFX_Flame_Stream", Color3.fromRGB(60, 190, 255) },
	{ "G-16", "10TS1", "Rifle Tesla de Arco Voltaico", "Heavy", "Special", "Special", 68, 3.0, 20, 2.4, 55, 1.0, 2.0, "VFX_Tesla_Arc", Color3.fromRGB(60, 180, 255) },
	{ "G-17", "09F3", "Rifle Ígneo de Plasma Termita", "Rifle", "Primary", "Special", 46, 5.5, 25, 2.1, 65, 1.8, 2.2, "VFX_Flame_Stream", Color3.fromRGB(255, 110, 20) },
	{ "G-18", "10SP1", "Cañón de Púas Magnético", "Heavy", "Primary", "Heavy", 74, 2.8, 14, 2.2, 70, 1.2, 2.5, "VFX_Tesla_Arc", Color3.fromRGB(160, 40, 255) },
	{ "G-19", "10AC1", "Rifle Corrosivo Bio-Ácido", "Rifle", "Special", "Special", 52, 4.2, 24, 2.2, 65, 2.0, 2.0, "VFX_Toxic_Acid", Color3.fromRGB(120, 255, 40) },
	{ "G-20", "11CE0", "Emisor de Conciencia", "Emitter", "ConsciousnessEmitter", "Special", 0, 0.5, 5, 2.0, 60, 0.0, 1.0, "VFX_Hypnosis_Wave", Color3.fromRGB(0, 255, 220) },
	-- Armas Cuerpo a Cuerpo (M-01 a M-12)
	{ "M-01", "01M9", "Espadón de Chatarra / Guanteletes", "Melee", "Melee", "None", 95, 1.3, 1, 0, 7, 0, 1.5, "VFX_Hulk_Shockwave", Color3.fromRGB(255, 140, 0) },
	{ "M-02", "01M3", "Machete Táctico de Supervivencia", "Melee", "Melee", "None", 45, 2.4, 1, 0, 5.5, 0, 1.5, "VFX_Melee_Slash_Blood", Color3.fromRGB(200, 240, 255) },
	{ "M-03", "01M4", "Katana Urbana de Acero Templado", "Melee", "Melee", "None", 68, 2.2, 1, 0, 6.5, 0, 1.8, "VFX_Melee_Slash_Blood", Color3.fromRGB(100, 200, 255) },
	{ "M-04", "01M5", "Hacha de Doble Filo Rompe-Escudos", "Melee", "Melee", "None", 82, 1.5, 1, 0, 6.0, 0, 1.6, "VFX_Melee_Slash_Blood", Color3.fromRGB(255, 60, 60) },
	{ "M-05", "01M0", "Bate con Clavos de Milicia", "Melee", "Melee", "None", 42, 2.1, 1, 0, 5.5, 0, 1.5, "VFX_Melee_Slash_Blood", Color3.fromRGB(255, 210, 90) },
	{ "M-06", "01M6", "Mazo Pesado Thor Sísmico", "Melee", "Melee", "None", 110, 1.0, 1, 0, 6.5, 0, 1.5, "VFX_Hulk_Shockwave", Color3.fromRGB(80, 190, 255) },
	{ "M-07", "01M2", "Motosierra Butcher Destripadora", "Melee", "Melee", "None", 22, 8.0, 1, 0, 5.5, 0, 1.3, "VFX_Melee_Slash_Blood", Color3.fromRGB(255, 50, 20) },
	{ "M-08", "01M7", "Lanza Improvisada de Perímetro", "Melee", "Melee", "None", 58, 1.9, 1, 0, 9.0, 0, 1.8, "VFX_Melee_Slash_Blood", Color3.fromRGB(140, 255, 190) },
	{ "M-09", "01M1", "Cuchillo Ka-Bar / Daga de Sigilo", "Melee", "Melee", "None", 38, 3.2, 1, 0, 4.5, 0, 2.5, "VFX_Melee_Slash_Blood", Color3.fromRGB(170, 80, 255) },
	{ "M-10", "01M8", "Garras Quirúrgicas Dobles", "Melee", "Melee", "None", 48, 3.0, 1, 0, 5.0, 0, 1.8, "VFX_Melee_Slash_Blood", Color3.fromRGB(0, 255, 160) },
	{ "M-11", "01M10", "Hacha de Bombero Ignífuga", "Melee", "Melee", "None", 74, 1.7, 1, 0, 6.0, 0, 1.6, "VFX_Melee_Slash_Blood", Color3.fromRGB(255, 120, 40) },
	{ "M-12", "11S1", "Escudo Balístico + Porra Táctica", "Melee", "Melee", "None", 40, 2.0, 1, 0, 5.5, 0, 1.4, "VFX_Melee_Slash_Blood", Color3.fromRGB(60, 150, 255) },
}

for _, row in ipairs(weaponRows) do
	registerWeapon({
		id = row[1],
		code = row[2],
		name = row[3],
		family = row[4],
		slotCategory = row[5],
		ammoFamily = row[6],
		baseDamage = row[7],
		fireRatePerSec = row[8],
		magazineSize = row[9],
		reloadSeconds = row[10],
		rangeStuds = row[11],
		spreadDeg = row[12],
		headshotMultiplier = row[13],
		vfxPreset = row[14],
		lv10AuraColor = row[15],
	})
end

ZombieCatalogs.Weapons = Weapons

--[[
	Calcula las estadísticas exactas de cualquier arma en el Nivel N (1 <= N <= 10).
	En Nivel 10 alcanza: +80% daño, +50% cargador, -30% tiempo de recarga y -50% dispersión.
--]]
function ZombieCatalogs.GetWeaponStatsAtLevel(weaponId: string, level: number): Types.WeaponComputedStats
	local def = Weapons[weaponId]
	if not def then
		error("WeaponId no encontrado en catálogo: " .. tostring(weaponId))
	end

	local clampedLv = math.clamp(math.floor(level), 1, 10)
	local alpha = (clampedLv - 1) / 9 -- 0.0 en Lv1 -> 1.0 en Lv10

	local damage = math.floor(def.baseDamage * (1 + 0.80 * alpha) * 10) / 10
	local mag = math.max(1, math.floor(def.magazineSize * (1 + 0.50 * alpha) + 0.5))
	local reloadSec = math.floor(def.reloadSeconds * (1 - 0.30 * alpha) * 100) / 100
	local spread = math.floor(def.spreadDeg * (1 - 0.50 * alpha) * 100) / 100

	return {
		weaponId = weaponId,
		level = clampedLv,
		damage = damage,
		magazineSize = mag,
		reloadSeconds = reloadSec,
		spreadDeg = spread,
		dps = math.floor(damage * def.fireRatePerSec * 10) / 10,
		materialTierName = ZombieCatalogs.MaterialTiers[clampedLv] or "Tier1_Scrap_Rust",
	}
end

function ZombieCatalogs.GetUpgradeCost(targetLevel: number): { scrap: number, components: number, cores: number }
	local lv = math.clamp(math.floor(targetLevel), 2, 10)
	local scrap = 75 * (lv - 1) * lv
	local components = if lv >= 4 then (lv - 3) * 8 else 0
	local cores = if lv >= 8 then (lv - 7) * 3 else 0
	return {
		scrap = scrap,
		components = components,
		cores = cores,
	}
end

--------------------------------------------------------------------------------
-- 5. DISTRITOS Z0–Z7 + 2 ZONAS ESPECIALES INFINITAS (SECCIÓN 2.1 Y 4.1)
--------------------------------------------------------------------------------

ZombieCatalogs.Districts = {
	Z0 = {
		id = "Z0",
		name = "Refugio Seguro (Borde Sur)",
		ringOrder = 0,
		initialThreat = 0,
		maxThreat = 0,
		passiveRegenPerMin = 0,
		centerPosition = Vector3.new(0, 0, 1750),
		radiusStuds = 256,
		streamingPersistent = true,
		lootWeights = { Common = 85, Rare = 15, Epic = 0, Legendary = 0, Unique = 0 },
	},
	Z1 = {
		id = "Z1",
		name = "Suburbios Residenciales (Anillo Exterior)",
		ringOrder = 1,
		initialThreat = 100,
		maxThreat = 100,
		passiveRegenPerMin = 5,
		centerPosition = Vector3.new(-650, 0, 1200),
		radiusStuds = 420,
		streamingPersistent = false,
		lootWeights = { Common = 75, Rare = 20, Epic = 4, Legendary = 1, Unique = 0 },
	},
	Z2 = {
		id = "Z2",
		name = "Centro Comercial Colapsado (Anillo Exterior)",
		ringOrder = 1,
		initialThreat = 250,
		maxThreat = 250,
		passiveRegenPerMin = 5,
		centerPosition = Vector3.new(650, 0, 1200),
		radiusStuds = 450,
		streamingPersistent = false,
		lootWeights = { Common = 68, Rare = 24, Epic = 6, Legendary = 2, Unique = 0 },
	},
	Z3 = {
		id = "Z3",
		name = "Distrito Médico y Cuarentena (Anillo Medio)",
		ringOrder = 2,
		initialThreat = 450,
		maxThreat = 450,
		passiveRegenPerMin = 5,
		centerPosition = Vector3.new(-750, 0, 350),
		radiusStuds = 480,
		streamingPersistent = false,
		lootWeights = { Common = 58, Rare = 28, Epic = 10, Legendary = 3, Unique = 1 },
	},
	Z4 = {
		id = "Z4",
		name = "Parque Botánico y Zoológico Mutado (Anillo Medio)",
		ringOrder = 2,
		initialThreat = 700,
		maxThreat = 700,
		passiveRegenPerMin = 5,
		centerPosition = Vector3.new(750, 0, 350),
		radiusStuds = 500,
		streamingPersistent = false,
		lootWeights = { Common = 48, Rare = 32, Epic = 14, Legendary = 5, Unique = 1 },
	},
	Z5 = {
		id = "Z5",
		name = "Zona Industrial y Fundición (Anillo Interior)",
		ringOrder = 3,
		initialThreat = 1000,
		maxThreat = 1000,
		passiveRegenPerMin = 5,
		centerPosition = Vector3.new(-550, 0, -550),
		radiusStuds = 500,
		streamingPersistent = false,
		lootWeights = { Common = 38, Rare = 34, Epic = 18, Legendary = 8, Unique = 2 },
	},
	Z6 = {
		id = "Z6",
		name = "Base Militar Acorazada (Anillo Interior)",
		ringOrder = 3,
		initialThreat = 1400,
		maxThreat = 1400,
		passiveRegenPerMin = 5,
		centerPosition = Vector3.new(550, 0, -550),
		radiusStuds = 520,
		streamingPersistent = false,
		lootWeights = { Common = 28, Rare = 35, Epic = 23, Legendary = 10, Unique = 4 },
	},
	Z7 = {
		id = "Z7",
		name = "Núcleo de Infección Central",
		ringOrder = 4,
		initialThreat = 2000,
		maxThreat = 2000,
		passiveRegenPerMin = 5,
		centerPosition = Vector3.new(0, 0, -100),
		radiusStuds = 460,
		streamingPersistent = false,
		lootWeights = { Common = 20, Rare = 35, Epic = 28, Legendary = 12, Unique = 5 },
	},
	Special_West = {
		id = "Special_West",
		name = "Zona Especial 1: El Foso de la Masacre (Extremo Oeste)",
		ringOrder = 5,
		initialThreat = 2000,
		maxThreat = 2000,
		passiveRegenPerMin = 0,
		centerPosition = Vector3.new(-1650, 0, 0),
		radiusStuds = 380,
		streamingPersistent = true,
		lootWeights = { Common = 15, Rare = 35, Epic = 30, Legendary = 14, Unique = 6 },
	},
	Special_East = {
		id = "Special_East",
		name = "Zona Especial 2: La Falla Industrial (Extremo Este)",
		ringOrder = 5,
		initialThreat = 2000,
		maxThreat = 2000,
		passiveRegenPerMin = 0,
		centerPosition = Vector3.new(1650, 0, 0),
		radiusStuds = 380,
		streamingPersistent = true,
		lootWeights = { Common = 15, Rare = 35, Epic = 30, Legendary = 14, Unique = 6 },
	},
} :: { [Types.DistrictId]: Types.DistrictConfig }

--------------------------------------------------------------------------------
-- 6. MATRIZ DE 16 EVENTOS PROCEDURALES (SECCIÓN 4.2)
--------------------------------------------------------------------------------

ZombieCatalogs.ProceduralEvents = {
	["E-01"] = {
		id = "E-01",
		name = "Choque de Patrullas (HvZ)",
		factions = { "Human", "Zombie" },
		allowedZones = { "Z1", "Z2", "Z3", "Z4", "Z5", "Z6" },
		durationSec = 240,
		triggerType = "Auto",
		rewardSummary = "Lealtad humana, munición y loot de ambos bandos",
		failurePenaltyThreat = 20,
	},
	["E-02"] = {
		id = "E-02",
		name = "Supervivientes Acorralados",
		factions = { "Human", "Zombie", "Mutant" },
		allowedZones = { "Z1", "Z2", "Z3", "Z4", "Z5" },
		durationSec = 90,
		triggerType = "Timer",
		rewardSummary = "Rescatar especialistas (Ingeniero, Constructor, Médico) suma 2 aliados permanentes",
		failurePenaltyThreat = 15,
	},
	["E-03"] = {
		id = "E-03",
		name = "Operación de Limpieza",
		factions = { "Human", "Zombie" },
		allowedZones = { "Z2", "Z3", "Z4", "Z5", "Z6" },
		durationSec = 300,
		triggerType = "Auto",
		rewardSummary = "Escoltar Soldados y Capitanes reduce -50 la amenaza del distrito al instante",
		failurePenaltyThreat = 25,
	},
	["E-04"] = {
		id = "E-04",
		name = "Guerra de Bandas (ZvM)",
		factions = { "Zombie", "Mutant" },
		allowedZones = { "Z3", "Z4", "Z5", "Z6" },
		durationSec = 300,
		triggerType = "Auto",
		rewardSummary = "Horda zombi choca con warband mutante; rematar al vencedor otorga doble loot",
		failurePenaltyThreat = 10,
	},
	["E-05"] = {
		id = "E-05",
		name = "Horda Errante",
		factions = { "Zombie" },
		allowedZones = { "Z1", "Z2", "Z3", "Z4", "Z5", "Z6" },
		durationSec = 240,
		triggerType = "Threat70",
		rewardSummary = "Columna de 30+ zombies guiada por Baliza C-07; emboscarlos resta -40 amenaza",
		failurePenaltyThreat = 30,
	},
	["E-06"] = {
		id = "E-06",
		name = "Caída de Suministros",
		factions = { "Human", "Zombie", "Mutant" },
		allowedZones = { "Z1", "Z2", "Z3", "Z4", "Z5", "Z6", "Z7" },
		durationSec = 180,
		triggerType = "Auto",
		rewardSummary = "Caja aérea C-01 con 1 objeto Épico garantizado disputada por las 3 facciones",
		failurePenaltyThreat = 15,
	},
	["E-07"] = {
		id = "E-07",
		name = "Jefe Errante Desatado",
		factions = { "Zombie", "Mutant" },
		allowedZones = { "Z3", "Z4", "Z5", "Z6" },
		durationSec = 300,
		triggerType = "Threat90",
		rewardSummary = "Un Titán (Z-59) o Colosales (M-59) patrulla demoliendo muros; alto drop de Núcleos",
		failurePenaltyThreat = 45,
	},
	["E-08"] = {
		id = "E-08",
		name = "Cierre de Cuarentena",
		factions = { "Zombie", "Mutant" },
		allowedZones = { "Z2", "Z3", "Z4", "Z5", "Z6" },
		durationSec = 600,
		triggerType = "Auto",
		rewardSummary = "Muros desplegables C-02 sellan el distrito; amenaza x2 pero probabilidad de loot raro x2",
		failurePenaltyThreat = 50,
	},
	["E-09"] = {
		id = "E-09",
		name = "Noche de Caza",
		factions = { "Zombie", "Mutant" },
		allowedZones = { "Z1", "Z2", "Z3", "Z4", "Z5", "Z6", "Z7" },
		durationSec = 240,
		triggerType = "NightCycle",
		rewardSummary = "Probabilidad de loot raro +30% global; enemigos ganan +25% visión y +25% daño",
		failurePenaltyThreat = 20,
	},
	["E-10"] = {
		id = "E-10",
		name = "Incursión al Refugio Propio",
		factions = { "Mutant", "Human" },
		allowedZones = { "Z0" },
		durationSec = 300,
		triggerType = "LiberateZ5",
		rewardSummary = "Defender Z0 junto a torretas otorga +1 mejora de arma permanente gratuita",
		failurePenaltyThreat = 0,
	},
	["E-11"] = {
		id = "E-11",
		name = "Caravana del Mercader",
		factions = { "Human" },
		allowedZones = { "Z2", "Z3", "Z4", "Z5", "Z6" },
		durationSec = 120,
		triggerType = "Auto",
		rewardSummary = "Puesto fortificado C-04 permite comprar armas raras y cargas de hipnosis con Núcleos",
		failurePenaltyThreat = 0,
	},
	["E-12"] = {
		id = "E-12",
		name = "Guerra de Tótems",
		factions = { "Mutant", "Zombie" },
		allowedZones = { "Z4", "Z5", "Z6" },
		durationSec = 360,
		triggerType = "Auto",
		rewardSummary = "Destruir el Tótem C-03 provoca furia suicida de la warband mutante contra la horda zombi",
		failurePenaltyThreat = 35,
	},
	["E-13"] = {
		id = "E-13",
		name = "Asedio Mutante a Campamento Humano",
		factions = { "Mutant", "Human" },
		allowedZones = { "Z2", "Z3", "Z4", "Z5", "Z6" },
		durationSec = 240,
		triggerType = "Auto",
		rewardSummary = "Defender el campamento de M-25 + M-54 desbloquea la fábrica del distrito",
		failurePenaltyThreat = 100,
	},
	["E-14"] = {
		id = "E-14",
		name = "Asalto Humano a Bastión Mutante",
		factions = { "Human", "Mutant" },
		allowedZones = { "Z3", "Z4", "Z5", "Z6" },
		durationSec = 300,
		triggerType = "Auto",
		rewardSummary = "Apoyar el asalto militar permite saquear la armería mutante y liberar al Inspector VIP (H-07)",
		failurePenaltyThreat = 40,
	},
	["E-15"] = {
		id = "E-15",
		name = "Batalla Campal de Tres Bandas (HvZvM)",
		factions = { "Human", "Zombie", "Mutant" },
		allowedZones = { "Z3", "Z4", "Z5", "Z6" },
		durationSec = 360,
		triggerType = "Auto",
		rewardSummary = "Choque simultáneo en plaza central; ideal para usar el Emisor de Conciencia G-20",
		failurePenaltyThreat = 30,
	},
	["E-16"] = {
		id = "E-16",
		name = "Despertar del Crisol (Mega Bruto Líder)",
		factions = { "Zombie", "Mutant" },
		allowedZones = { "Special_West", "Special_East" },
		durationSec = 1500,
		triggerType = "Crucible1000",
		rewardSummary = "Emerge Z-BOSS-01 o M-BOSS-01 bajo ServerBossMutex; derrotarlo da 50 Núcleos y G-20 Soberano",
		failurePenaltyThreat = 500,
	},
} :: { [Types.ProceduralEventId]: Types.ProceduralEventConfig }

--------------------------------------------------------------------------------
-- 7. EDIFICIOS DEL REFUGIO PROPIO (CATÁLOGO A) Y MERCENARIOS
--------------------------------------------------------------------------------

ZombieCatalogs.RefugeBuildings = {
	["A-01"] = {
		id = "A-01",
		name = "Centro de Mando del Refugio",
		maxTier = 3,
		requiredSpecialistId = "H-01",
		baseScrapCost = 200,
		baseComponentsCost = 10,
		baseCoresCost = 0,
		description = "Núcleo del asentamiento personal (256x256 studs); amplía capacidad defensiva",
	},
	["A-02"] = {
		id = "A-02",
		name = "Armería Modular",
		maxTier = 3,
		requiredSpecialistId = "H-07",
		baseScrapCost = 250,
		baseComponentsCost = 15,
		baseCoresCost = 1,
		description = "Habilita evolución de armas Nivel 1 a Nivel 10 y refundición al 80%",
	},
	["A-05"] = {
		id = "A-05",
		name = "Cuartel de Mercenarios",
		maxTier = 3,
		requiredSpecialistId = "H-29",
		baseScrapCost = 300,
		baseComponentsCost = 20,
		baseCoresCost = 2,
		description = "Permite contratar y desplegar hasta 3 Mercenarios Permanentes en partida",
	},
	["A-06"] = {
		id = "A-06",
		name = "Laboratorio de Conciencia",
		maxTier = 3,
		requiredSpecialistId = "H-28",
		baseScrapCost = 400,
		baseComponentsCost = 30,
		baseCoresCost = 5,
		description = "Desbloquea y calibra el Emisor de Conciencia (G-20) y sintetiza Núcleos",
	},
	["A-07"] = {
		id = "A-07",
		name = "Sala de Mapas y Radar de Conciencia",
		maxTier = 3,
		requiredSpecialistId = "H-05",
		baseScrapCost = 180,
		baseComponentsCost = 12,
		baseCoresCost = 0,
		description = "Sincroniza en tiempo real la amenaza de Z1–Z7 y alertas de eventos E-01..E-16",
	},
	["A-08"] = {
		id = "A-08",
		name = "Bóveda Acorazada de Loadout",
		maxTier = 3,
		requiredSpecialistId = "H-08",
		baseScrapCost = 220,
		baseComponentsCost = 14,
		baseCoresCost = 0,
		description = "Almacena el arsenal seguro y configura los 10 slots activos + G-20",
	},
	["A-14"] = {
		id = "A-14",
		name = "Torre de Vigilancia y Torretas Automáticas",
		maxTier = 3,
		requiredSpecialistId = "H-03",
		baseScrapCost = 260,
		baseComponentsCost = 18,
		baseCoresCost = 1,
		description = "Defensa perimetral del Refugio frente a la incursión mutante E-10",
	},
	["A-21"] = {
		id = "A-21",
		name = "Jardín Hidropónico y Recicladora",
		maxTier = 3,
		requiredSpecialistId = "H-02",
		baseScrapCost = 150,
		baseComponentsCost = 8,
		baseCoresCost = 0,
		description = "Genera +50 Chatarra/hora pasiva adicional para el jugador",
	},
	["A-23"] = {
		id = "A-23",
		name = "Helipuerto de Despliegue Táctico",
		maxTier = 3,
		requiredSpecialistId = "H-03",
		baseScrapCost = 350,
		baseComponentsCost = 25,
		baseCoresCost = 2,
		description = "Extracción rápida e inserción directa hacia puestos avanzados liberados",
	},
} :: { [string]: Types.RefugeBuildingConfig }

ZombieCatalogs.Mercenaries = {
	Recruit = { id = "Recruit", name = "Recluta de Asalto", unitId = "H-20", hireScrap = 200, hireCores = 0 },
	Sniper = { id = "Sniper", name = "Francotirador de Élite", unitId = "H-23", hireScrap = 350, hireCores = 1 },
	FieldMedic = { id = "FieldMedic", name = "Médico de Campaña", unitId = "H-04", hireScrap = 400, hireCores = 2 },
	Sapper = { id = "Sapper", name = "Zapador de Demolición", unitId = "H-27", hireScrap = 450, hireCores = 2 },
	Tamer = { id = "Tamer", name = "Domadora (Mascota Zombi Permanente)", unitId = "H-28", hireScrap = 600, hireCores = 5 },
	Ghost = { id = "Ghost", name = "Fantasma de Sigilo", unitId = "H-12", hireScrap = 550, hireCores = 4 },
}

return ZombieCatalogs
