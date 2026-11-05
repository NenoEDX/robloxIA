--!strict
--[[
	SlimeAssetVFX — per-design Roblox VFX profiles for the slime-v1 asset pack.

	One profile per original model in `exports/slime-v1` (built by
	`agent/generators/run_slime_assets.mjs`). Each profile maps the shared gameplay
	moments (ambient presence, extraction strain and the release pop) onto effect
	lanes that `VFXAndJuiceEngine.CastEffect` actually implements.

	Contract:
	  * Effect lanes are limited to MeleeSlash, HeavyImpact, MagicExplosion and DashBurst.
	  * No mesh, texture, animation or sound asset id is defined here. Nothing is uploaded.
	  * Slugs are asset design identities, not catalog/rarity ids; the catalog binding
	    stays in the gameplay layer.
	  * Unknown slugs return false instead of raising, so a stale caller cannot break a
	    harvest loop.

	The GLB animations (Idle/Extract/Release) are separate from these emitters: glTF
	carries the model and its clips, while these profiles drive Roblox-side particles.
]]

local VFXAndJuiceEngine = require(script.Parent.VFXAndJuiceEngine)

export type SlimeVFXLane = "MeleeSlash" | "HeavyImpact" | "MagicExplosion" | "DashBurst"

export type SlimeVFXProfile = {
	slug: string,
	displayName: string,
	referenceFile: string,
	primary: Color3,
	secondary: Color3,
	ambient: SlimeVFXLane,
	extract: SlimeVFXLane,
	release: SlimeVFXLane,
	scale: number,
	trauma: number,
	debris: number,
}

export type CastOptions = {
	scale: number?,
	target: Model?,
	soundId: string?,
}

local PROFILES: { [string]: SlimeVFXProfile } = {
	classic_blue = {
		slug = "classic_blue",
		displayName = "Classic Blue Slime",
		referenceFile = "Gemini_Generated_Image_o5nhsso5nhsso5nh.jfif",
		primary = Color3.fromRGB(64, 150, 255),
		secondary = Color3.fromRGB(150, 225, 255),
		ambient = "DashBurst",
		extract = "MagicExplosion",
		release = "DashBurst",
		scale = 1.0,
		trauma = 0.28,
		debris = 5,
	},
	mint_droplet = {
		slug = "mint_droplet",
		displayName = "Mint Droplet",
		referenceFile = "Gemini_Generated_Image_t4qh2st4qh2st4qh.jfif",
		primary = Color3.fromRGB(86, 214, 160),
		secondary = Color3.fromRGB(196, 255, 226),
		ambient = "DashBurst",
		extract = "MagicExplosion",
		release = "MeleeSlash",
		scale = 1.0,
		trauma = 0.26,
		debris = 5,
	},
	gel_cube = {
		slug = "gel_cube",
		displayName = "Gel Cube",
		referenceFile = "Gemini_Generated_Image_jnc8o6jnc8o6jnc8.jfif",
		primary = Color3.fromRGB(60, 232, 208),
		secondary = Color3.fromRGB(180, 255, 246),
		ambient = "DashBurst",
		extract = "HeavyImpact",
		release = "HeavyImpact",
		scale = 1.0,
		trauma = 0.3,
		debris = 6,
	},
	spiral_slime = {
		slug = "spiral_slime",
		displayName = "Spiral Slime",
		referenceFile = "Gemini_Generated_Image_a8ausaa8ausaa8au.jfif",
		primary = Color3.fromRGB(40, 214, 232),
		secondary = Color3.fromRGB(170, 255, 255),
		ambient = "DashBurst",
		extract = "MagicExplosion",
		release = "DashBurst",
		scale = 1.0,
		trauma = 0.26,
		debris = 6,
	},
	faceted_crystal = {
		slug = "faceted_crystal",
		displayName = "Faceted Crystal Slime",
		referenceFile = "Gemini_Generated_Image_i1vs4ci1vs4ci1vs.jfif",
		primary = Color3.fromRGB(70, 150, 255),
		secondary = Color3.fromRGB(180, 226, 255),
		ambient = "MagicExplosion",
		extract = "HeavyImpact",
		release = "MeleeSlash",
		scale = 1.1,
		trauma = 0.34,
		debris = 7,
	},
	jellyfish_slime = {
		slug = "jellyfish_slime",
		displayName = "Jellyfish Slime",
		referenceFile = "Gemini_Generated_Image_g67waog67waog67w.jfif",
		primary = Color3.fromRGB(178, 96, 240),
		secondary = Color3.fromRGB(240, 190, 255),
		ambient = "MagicExplosion",
		extract = "MeleeSlash",
		release = "MagicExplosion",
		scale = 1.05,
		trauma = 0.3,
		debris = 6,
	},
	cosmic_orb = {
		slug = "cosmic_orb",
		displayName = "Cosmic Orb Slime",
		referenceFile = "Gemini_Generated_Image_nnuwnfnnuwnfnnuw.jfif",
		primary = Color3.fromRGB(96, 110, 255),
		secondary = Color3.fromRGB(180, 150, 255),
		ambient = "MagicExplosion",
		extract = "DashBurst",
		release = "MagicExplosion",
		scale = 1.1,
		trauma = 0.32,
		debris = 7,
	},
	tornado_slime = {
		slug = "tornado_slime",
		displayName = "Tornado Slime",
		referenceFile = "Gemini_Generated_Image_bsa7cpbsa7cpbsa7.jfif",
		primary = Color3.fromRGB(56, 208, 232),
		secondary = Color3.fromRGB(180, 255, 255),
		ambient = "DashBurst",
		extract = "MagicExplosion",
		release = "HeavyImpact",
		scale = 1.05,
		trauma = 0.3,
		debris = 7,
	},
	celestial_winged = {
		slug = "celestial_winged",
		displayName = "Celestial Winged Slime",
		referenceFile = "Gemini_Generated_Image_ir4dd4ir4dd4ir4d.jfif",
		primary = Color3.fromRGB(128, 120, 255),
		secondary = Color3.fromRGB(190, 240, 255),
		ambient = "MagicExplosion",
		extract = "DashBurst",
		release = "MagicExplosion",
		scale = 1.15,
		trauma = 0.34,
		debris = 8,
	},
	blob_hydra = {
		slug = "blob_hydra",
		displayName = "Blob Hydra",
		referenceFile = "Gemini_Generated_Image_gqrwaggqrwaggqrw.jfif",
		primary = Color3.fromRGB(64, 220, 128),
		secondary = Color3.fromRGB(190, 255, 210),
		ambient = "MagicExplosion",
		extract = "MeleeSlash",
		release = "HeavyImpact",
		scale = 1.1,
		trauma = 0.32,
		debris = 8,
	},
	crystal_golem = {
		slug = "crystal_golem",
		displayName = "Crystal Golem",
		referenceFile = "Gemini_Generated_Image_7skyzw7skyzw7sky.jfif",
		primary = Color3.fromRGB(60, 140, 255),
		secondary = Color3.fromRGB(130, 230, 255),
		ambient = "MagicExplosion",
		extract = "HeavyImpact",
		release = "HeavyImpact",
		scale = 1.25,
		trauma = 0.45,
		debris = 10,
	},
	dragon_hydra = {
		slug = "dragon_hydra",
		displayName = "Dragon Hydra",
		referenceFile = "Gemini_Generated_Image_nonte0nonte0nont.jfif",
		primary = Color3.fromRGB(64, 224, 120),
		secondary = Color3.fromRGB(200, 255, 214),
		ambient = "MeleeSlash",
		extract = "MeleeSlash",
		release = "HeavyImpact",
		scale = 1.2,
		trauma = 0.4,
		debris = 10,
	},
	abyssal_leviathan = {
		slug = "abyssal_leviathan",
		displayName = "Abyssal Leviathan",
		referenceFile = "Gemini_Generated_Image_ofqi2cofqi2cofqi.jfif",
		primary = Color3.fromRGB(40, 200, 235),
		secondary = Color3.fromRGB(160, 250, 255),
		ambient = "MagicExplosion",
		extract = "HeavyImpact",
		release = "MagicExplosion",
		scale = 1.2,
		trauma = 0.38,
		debris = 10,
	},
}

local ORDER: { string } = {
	"classic_blue",
	"mint_droplet",
	"gel_cube",
	"spiral_slime",
	"faceted_crystal",
	"jellyfish_slime",
	"cosmic_orb",
	"tornado_slime",
	"celestial_winged",
	"blob_hydra",
	"crystal_golem",
	"dragon_hydra",
	"abyssal_leviathan",
}

local SlimeAssetVFX = {}

local function cast(profile: SlimeVFXProfile, lane: SlimeVFXLane, cf: CFrame, options: CastOptions?)
	local scale = (options and options.scale) or 1
	local target = options and options.target or nil
	local soundId = options and options.soundId or nil
	VFXAndJuiceEngine.CastEffect(lane, cf, profile.scale * scale, {
		PrimaryColor = profile.primary,
		SecondaryColor = profile.secondary,
		DebrisCount = profile.debris,
		TraumaAmount = profile.trauma * math.clamp(scale, 0.25, 2),
		TargetModel = target,
		SoundId = soundId,
	})
end

--[[
	Every design slug shipped in the pack, in manifest order.
]]
function SlimeAssetVFX.ListSlugs(): { string }
	return table.clone(ORDER)
end

--[[
	Returns the immutable profile for a design slug, or nil when the slug is unknown.
]]
function SlimeAssetVFX.Get(slug: string): SlimeVFXProfile?
	return PROFILES[slug]
end

--[[
	Ambient presence effect (e.g. a node idle shimmer).
]]
function SlimeAssetVFX.PlayAmbient(slug: string, cf: CFrame, options: CastOptions?): boolean
	local profile = PROFILES[slug]
	if profile == nil then
		return false
	end
	cast(profile, profile.ambient, cf, options)
	return true
end

--[[
	Extraction strain effect while the player holds the prompt.
]]
function SlimeAssetVFX.PlayExtract(slug: string, cf: CFrame, options: CastOptions?): boolean
	local profile = PROFILES[slug]
	if profile == nil then
		return false
	end
	cast(profile, profile.extract, cf, options)
	return true
end

--[[
	Release pop when extraction completes or the slime escapes.
]]
function SlimeAssetVFX.PlayRelease(slug: string, cf: CFrame, options: CastOptions?): boolean
	local profile = PROFILES[slug]
	if profile == nil then
		return false
	end
	cast(profile, profile.release, cf, options)
	return true
end

--[[
	Casts one named lane directly; useful for sequencing a scripted moment.
]]
function SlimeAssetVFX.CastLane(slug: string, lane: SlimeVFXLane, cf: CFrame, options: CastOptions?): boolean
	local profile = PROFILES[slug]
	if profile == nil then
		return false
	end
	cast(profile, lane, cf, options)
	return true
end

return SlimeAssetVFX
