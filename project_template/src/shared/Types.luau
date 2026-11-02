--!strict
--[[
	Types.luau
	Contratos Maestros de Tipos para Zombie Awareness (v4.0) bajo el estándar RAASE 3.0.
	Incluye los contratos de los 4 Módulos Maestros y el ecosistema completo de 3 Facciones
	(150 unidades, 32 armas Lv1–10 + Emisor G-20, Distritos Z0–Z7 + 2 Zonas Especiales,
	16 Eventos Procedurales y Persistencia con Session Locking).
--]]

export type FactionId = "Human" | "Mutant" | "Zombie"

export type SubFactionId =
	"Human_Specialist"
	| "Human_Melee"
	| "Human_Ranged"
	| "Mutant_Green"
	| "Mutant_Anthro"
	| "Mutant_Brute"
	| "Mutant_MegaBoss"
	| "Zombie_Melee"
	| "Zombie_Ranged"
	| "Zombie_ArmoredBeast"
	| "Zombie_Brute"
	| "Zombie_MegaBoss"

export type DistrictId =
	"Z0"
	| "Z1"
	| "Z2"
	| "Z3"
	| "Z4"
	| "Z5"
	| "Z6"
	| "Z7"
	| "Special_West"
	| "Special_East"

export type MasterRigId = "RIG-01" | "RIG-02" | "RIG-03" | "RIG-04" | "RIG-05" | "RIG-06"

export type PoolCategory =
	"Pool_Human"
	| "Pool_Mutant_Green"
	| "Pool_Mutant_Anthro"
	| "Pool_Zombie_Base"
	| "Pool_Brute"

export type PathfindingPriority = 1 | 2 | 3 | 4 | 5

export type AmmoFamily = "Light" | "Medium" | "Heavy" | "Special" | "Explosive" | "None"

export type WeaponFamily = "Pistol" | "Rifle" | "Shotgun" | "Heavy" | "Melee" | "Emitter"

export type WeaponSlotCategory =
	"Primary"
	| "Sniper"
	| "Secondary"
	| "Melee"
	| "Special"
	| "Flexible"
	| "ConsciousnessEmitter"

export type LootRarity = "Common" | "Rare" | "Epic" | "Legendary" | "Unique"

export type MercenaryId = "Recruit" | "Sniper" | "FieldMedic" | "Sapper" | "Tamer" | "Ghost"

export type VFXPresetId =
	"VFX_Muzzle_Ballistic"
	| "VFX_Flame_Stream"
	| "VFX_Toxic_Acid"
	| "VFX_Tesla_Arc"
	| "VFX_Hypnosis_Wave"
	| "VFX_Hulk_Shockwave"
	| "VFX_Melee_Slash_Blood"
	| "VFX_Rocket_Barrage"
	| "VFX_Weapon_Lv10_Aura"

export type ProceduralEventId =
	"E-01"
	| "E-02"
	| "E-03"
	| "E-04"
	| "E-05"
	| "E-06"
	| "E-07"
	| "E-08"
	| "E-09"
	| "E-10"
	| "E-11"
	| "E-12"
	| "E-13"
	| "E-14"
	| "E-15"
	| "E-16"

export type UnitDefinition = {
	id: string,
	name: string,
	faction: FactionId,
	subFaction: SubFactionId,
	masterRig: MasterRigId,
	poolCategory: PoolCategory,
	pathPriority: PathfindingPriority,
	hp: number,
	dps: number,
	speed: number,
	rangeStuds: number,
	heightStuds: number,
	weaponOrTool: string,
	tacticalBehavior: string,
	vfxPreset: VFXPresetId,
	primaryColor: Color3,
	accentColor: Color3,
	hypnotizable: boolean,
	crucibleWeight: number,
	passiveResourceType: ("Scrap" | "Components" | "Cores" | "HealAura")?,
	passiveDailyAmount: number?,
}

export type WeaponDefinition = {
	id: string,
	code: string,
	name: string,
	family: WeaponFamily,
	slotCategory: WeaponSlotCategory,
	ammoFamily: AmmoFamily,
	baseDamage: number,
	fireRatePerSec: number,
	magazineSize: number,
	reloadSeconds: number,
	rangeStuds: number,
	spreadDeg: number,
	headshotMultiplier: number,
	vfxPreset: VFXPresetId,
	lv10AuraColor: Color3,
}

export type WeaponComputedStats = {
	weaponId: string,
	level: number,
	damage: number,
	magazineSize: number,
	reloadSeconds: number,
	spreadDeg: number,
	dps: number,
	materialTierName: string,
}

export type VFXPresetConfig = {
	id: VFXPresetId,
	flipbookLayout: ("Grid4x4" | "Grid8x8" | "None"),
	flipbookMode: ("OneShot" | "Loop" | "Random"),
	colorStart: Color3,
	colorMid: Color3,
	colorEnd: Color3,
	sizeStart: number,
	sizePeak: number,
	sizeEnd: number,
	squash: number,
	lightEmission: number,
	rate: number,
	burstCount: number,
	lifetimeMin: number,
	lifetimeMax: number,
	speedMin: number,
	speedMax: number,
	drag: number,
	acceleration: Vector3,
}

export type DistrictConfig = {
	id: DistrictId,
	name: string,
	ringOrder: number,
	initialThreat: number,
	maxThreat: number,
	passiveRegenPerMin: number,
	centerPosition: Vector3,
	radiusStuds: number,
	streamingPersistent: boolean,
	lootWeights: {
		Common: number,
		Rare: number,
		Epic: number,
		Legendary: number,
		Unique: number,
	},
}

export type DistrictRuntimeState = {
	id: DistrictId,
	threatLevel: number,
	maxThreat: number,
	liberated: boolean,
	outpostRebuilt: boolean,
	factoryRebuilt: boolean,
	shelterRebuilt: boolean,
	repellerActive: boolean,
	assignedBuilders: number,
	assignedEngineers: number,
	assignedSoldiers: number,
	assignedCaptains: number,
	quarantineLockedUntil: number,
}

export type CrucibleRuntimeState = {
	westDeathPoints: number,
	eastDeathPoints: number,
	totemsRemainingEast: number,
	serverBossMutex: boolean,
	activeMegaBossId: ("Z-BOSS-01" | "M-BOSS-01")?,
	activeMegaBossHp: number,
	activeMegaBossMaxHp: number,
	bossSpawnedAt: number?,
}

export type ProceduralEventConfig = {
	id: ProceduralEventId,
	name: string,
	factions: { FactionId },
	allowedZones: { DistrictId },
	durationSec: number,
	triggerType: "Auto" | "Timer" | "Threat70" | "Threat90" | "NightCycle" | "LiberateZ5" | "Crucible1000",
	rewardSummary: string,
	failurePenaltyThreat: number,
}

export type RefugeBuildingConfig = {
	id: string,
	name: string,
	maxTier: number,
	requiredSpecialistId: string?,
	baseScrapCost: number,
	baseComponentsCost: number,
	baseCoresCost: number,
	description: string,
}

export type TacticalBackpack = {
	unsecuredScrap: number,
	unsecuredComponents: number,
	unsecuredCores: number,
	escortedSpecialists: { string },
	unsecuredLootItems: { string },
}

export type LoadoutSlots = {
	slot1_PrimaryA: string,
	slot2_PrimaryB: string,
	slot3_Sniper: string,
	slot4_SecondaryA: string,
	slot5_SecondaryB: string,
	slot6_MeleeA: string,
	slot7_MeleeB: string,
	slot8_Special: string,
	slot9_FlexA: string,
	slot10_FlexB: string,
	emitterG20Tier: number,
}

export type SkillTreeState = {
	survivalRank: number,
	consciousnessRank: number,
	combatRank: number,
	pulseUnlocked: boolean,
	tacticalDashUnlocked: boolean,
	qteExecutionUnlocked: boolean,
}

export type PlayerData = {
	schemaVersion: number,
	refugeSeed: string,
	scrap: number,
	components: number,
	consciousnessCores: number,
	humanLoyalty: number,
	renegadeUntil: number,
	g20Tier: number,
	squadCap: number,
	ammoPools: {
		Light: number,
		Medium: number,
		Heavy: number,
		Special: number,
		Explosive: number,
	},
	weaponLevels: { [string]: number },
	loadout: LoadoutSlots,
	rescuedSpecialists: { [string]: number },
	refugeBuildings: { [string]: number },
	hiredMercenaries: { [MercenaryId]: boolean },
	activeMercenaries: { MercenaryId },
	liberatedDistricts: { [DistrictId]: boolean },
	skillTree: SkillTreeState,
	tacticalBackpack: TacticalBackpack,
	bestMegaBossKillSec: number?,
	sessionLockTimestamp: number?,
	sessionLockJobId: string?,
}

export type PurchaseRecord = {
	purchaseId: string,
	productId: number,
	timestamp: number,
	granted: boolean,
}

export type TokenBucket = {
	tokens: number,
	lastRefill: number,
	maxTokens: number,
	refillRatePerSec: number,
}

export type VoxelTerrainConfig = {
	RegionMin: Vector3,
	RegionMax: Vector3,
	Seed: number?,
	Octaves: number?,
	Lacunarity: number?,
	Persistence: number?,
	BaseScale: number?,
	Amplitude: number?,
	BaseHeight: number?,
	WaterLevel: number?,
	SnowHeight: number?,
	SteepSlopeThreshold: number?,
	ChunkSizeVoxels: number?,
}

export type GroundPlacementOptions = {
	GridSnap: number?,
	AlignToSlope: boolean?,
	RaycastHeight: number?,
	RaycastDepth: number?,
	VerticalOffset: number?,
	PreserveExistingTransform: boolean?,
	FilterExclude: { Instance }?,
}

export type IKRigConfig = {
	Name: string?,
	ControlType: Enum.IKControlType?,
	ChainRootName: string,
	EndEffectorName: string,
	Target: Instance,
	Pole: Attachment?,
	SmoothTime: number?,
	Weight: number?,
	EnableJointLimits: boolean?,
	UpperAngleLimit: number?,
	TwistLowerAngle: number?,
	TwistUpperAngle: number?,
}

export type VFXEffectType = "MeleeSlash" | "HeavyImpact" | "MagicExplosion" | "DashBurst"

export type VFXCastOptions = {
	PrimaryColor: Color3?,
	SecondaryColor: Color3?,
	DebrisCount: number?,
	HitstopFrames: number?,
	TraumaAmount: number?,
	FovPunch: number?,
	SoundId: string?,
	MeshFlashId: string?,
	FlipbookId: string?,
	FlipbookFrames: number?,
	TargetModel: Model?,
	KnockbackImpulse: Vector3?,
}

-- ============================================================================
-- SLIME PIT: DIVE FOR MUTANTS! (ABYSSAL SLIME CORE) CONTRACTS
-- ============================================================================

export type SlimeRarityGradeId =
	"GRADE_01_BASIC"
	| "GRADE_02_RARE"
	| "GRADE_03_EPIC"
	| "GRADE_04_LEGENDARY"
	| "GRADE_05_MYTHICAL"
	| "GRADE_06_EXOTIC"
	| "GRADE_07_DIVINE"
	| "GRADE_08_SUPERIOR"
	| "GRADE_09_CELESTIAL_I"
	| "GRADE_10_CELESTIAL_II"

export type PerformanceMutationMode = "LOW_3" | "MEDIUM_6" | "HIGH_10"

export type AcquisitionPath = "Earned_Free" | "Paid_Deterministic" | "Event_Crate"

export type SlimeChassisDefinition = {
	id: string,
	name: string,
	bones: { string },
	movementPattern: string,
	guardianAttackRadius: number,
	baseScale: Vector3,
}

export type SlimeRaceDefinition = {
	id: string,
	name: string,
	factionBonusPercent: number,
	primaryColor: Color3,
	accentFeature: string,
}

export type MutationVectorCategory =
	"ECONOMIC"
	| "COMBAT_GUARD"
	| "ALCHEMICAL_JUICE"
	| "ABYSSAL_EXPLORATION"
	| "COSMIC_ADMIN"

export type MutationDefinition = {
	id: string,
	numericId: number,
	name: string,
	vector: MutationVectorCategory,
	statPercentBonus: number,
	scaleMultiplier: number,
	damageMitigationPercent: number,
	cooldownReductionPercent: number,
	alchemyPurityBonusPercent: number,
	changesAppearance: boolean,
	visualPriority: number,
	primaryColor: Color3,
	appearanceTag: string,
}

export type SlimeDefinition = {
	id: string,
	name: string,
	biomeIndex: number,
	macroRingIndex: number,
	chassisId: string,
	raceId: string,
	rarityGrade: SlimeRarityGradeId,
	isUltraSpecial: boolean,
	ultraClass: ("NONE" | "HUGE" | "TITANIC"),
	anchoredBaseRatio: number,
	anchoredMaxRatioLv99: number,
	basePower: number,
	baseCoinsPerSec: number,
	baseStabilityHP: number,
	juiceType: string,
}

export type SlimePetInstance = {
	uuid: string,
	slimeId: string,
	level: number,
	experience: number,
	stars: number,
	raceId: string,
	armorId: string?,
	auraId: string?,
	mutations: { string }, -- Hard-capped at MAX_MUTATIONS_PER_SLIME = 10
	currentHP: number,
	maxHP: number,
	cooldownUntilOsTime: number,
	acquisitionPath: AcquisitionPath,
	capturedBiome: number,
}

export type EventCrateItem = {
	id: string,
	slimeId: string,
	name: string,
	rarityGrade: SlimeRarityGradeId,
	probabilityPercent: number,
	formattedOdds: string,
	guaranteedMutationId: string?,
	isUltra: boolean,
}

export type DynamicCaptureQuote = {
	playerMaxBiome: number,
	targetSlimeBiome: number,
	biomeGap: number,
	isDailyFreeAvailable: boolean,
	dailyFreeCooldownRemainingSec: number,
	computedRobuxCost: number,
	mappedDeveloperProductId: number,
	naturalCatchChancePercent: number,
}

export type AdminAbuseCommand = {
	commandType:
		"GlobalMutationStorm"
		| "AbyssalInversion"
		| "SpawnAbyssalCannon"
		| "HostBroadcast"
		| "PlayerTriggeredAbuse",
	triggeredByUserId: number,
	triggeredByName: string,
	durationSec: number,
	targetMutationId: string?,
	sourceBiome: number?,
	targetBiome: number?,
}

return {}
