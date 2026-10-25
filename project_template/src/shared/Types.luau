--!strict

export type PlayerData = {
	coins: number,
	gems: number,
	jumpMultiplier: number,
	speedMultiplier: number,
	inventory: { string },
	unlockedIslands: { string },
	schemaVersion: number,
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

export type IslandBiome = "Grass" | "Desert" | "Ice" | "Volcanic"

export type IslandConfig = {
	name: string,
	biome: IslandBiome,
	radius: number,
	position: Vector3,
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

return {}
