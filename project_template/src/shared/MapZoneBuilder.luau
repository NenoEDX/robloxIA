--!strict
--[[
	MapZoneBuilder.luau
	Enforces the Two-Stage Top-Down + Per-Zone Reference Map Pipeline in Roblox Studio.
	Hard Invariant: Zero mindless primitive block decorations ("decoraciones sin criterio").
	Every zone decoration (fences/verjas, machines/máquinas, arches, crystals) must
	reference an approved 3D model and use grounded placement (`placeOnGround` or `modularSnap`).
]]

export type Prop3DSpec = {
	assetId: string,
	name: string,
	category: "tiny" | "small" | "medium" | "module" | "building" | "hero",
	placementRule: "placeOnGround" | "modularSnap",
	position: Vector3,
	yawDegrees: number,
	keepClearRadiusStuds: number?,
}

export type ZoneSpec = {
	zoneId: string,
	name: string,
	zoneReferences: { string },
	dominantHue: Color3,
	accentHue: Color3,
	decorationMode: "curated_3d_models" | "primitive_blocks" | "random_scatter",
	props3d: { Prop3DSpec },
}

export type TopographySpec = {
	minHeightStuds: number,
	maxHeightStuds: number,
	elevationStyle: "terraced_amphitheater" | "sloped_valley" | "tiered_plateaus" | "flat_arena",
	hasRampsOrStairs: boolean,
}

export type TopDownMapSpec = {
	mapId: string,
	topDownPlanApproved: boolean,
	topDownPlanSource: string,
	topography: TopographySpec?,
	mainPathWidthStuds: number,
	walkSpeedStudsPerSec: number,
	zones: { ZoneSpec },
}

export type ValidationResult = {
	ok: boolean,
	stage: string,
	errors: { string },
}

local MapZoneBuilder = {}

function MapZoneBuilder.validateBlueprint(spec: TopDownMapSpec): ValidationResult
	local errors: { string } = {}

	if not spec.topDownPlanApproved or spec.topDownPlanSource == "" then
		table.insert(errors, "MISSING_TOP_DOWN_PLAN: Stage 1 requires an approved top-down 2D plan and topography before building.")
		return {
			ok = false,
			stage = "awaiting_stage_1_top_down_plan",
			errors = errors,
		}
	end

	if spec.topography and spec.topography.maxHeightStuds < spec.topography.minHeightStuds then
		table.insert(errors, "INVALID_TOPOGRAPHY_RANGE: maxHeightStuds must be >= minHeightStuds.")
	end

	if spec.mainPathWidthStuds < 16 then
		table.insert(errors, string.format("PATH_TOO_NARROW: Main path is %.1f studs; minimum is 16 studs.", spec.mainPathWidthStuds))
	end

	if #spec.zones == 0 then
		table.insert(errors, "NO_ZONES_DEFINED: Blueprint must define at least one zone.")
	end

	for _, zone in ipairs(spec.zones) do
		if #zone.zoneReferences == 0 then
			table.insert(errors, string.format("MISSING_ZONE_REFERENCE: Zone '%s' requires at least one visual reference in Stage 2.", zone.zoneId))
		end

		if zone.decorationMode ~= "curated_3d_models" then
			table.insert(
				errors,
				string.format(
					"MINDLESS_DECORATION_FORBIDDEN: Zone '%s' uses '%s'; only 'curated_3d_models' (3D fence, 3D machine, etc.) is allowed.",
					zone.zoneId,
					tostring(zone.decorationMode)
				)
			)
		end

		if #zone.props3d == 0 then
			table.insert(errors, string.format("EMPTY_ZONE_3D_PROPS: Zone '%s' must declare explicit 3D prop models.", zone.zoneId))
		end

		for _, prop in ipairs(zone.props3d) do
			if prop.assetId == "" then
				table.insert(errors, string.format("INVALID_PROP_ID: Zone '%s' has a prop with an empty assetId.", zone.zoneId))
			end
			if prop.placementRule ~= "placeOnGround" and prop.placementRule ~= "modularSnap" then
				table.insert(
					errors,
					string.format("UNGROUNDED_PROP_PLACEMENT: Prop '%s' in zone '%s' must use placeOnGround or modularSnap.", prop.assetId, zone.zoneId)
				)
			end
		end
	end

	local stage = "ready_for_mcp_build"
	if #errors > 0 then
		stage = "validation_failed"
	end

	return {
		ok = #errors == 0,
		stage = stage,
		errors = errors,
	}
end

function MapZoneBuilder.computeGroundedCFrame(groundPoint: Vector3, groundNormal: Vector3, yawDegrees: number, alignToNormal: boolean): CFrame
	local yawRad = math.rad(yawDegrees)
	local baseRot = CFrame.Angles(0, yawRad, 0)
	if not alignToNormal then
		return CFrame.new(groundPoint) * baseRot
	end
	local up = groundNormal.Unit
	local forward = baseRot.LookVector
	local right = forward:Cross(up)
	if right.Magnitude < 1e-4 then
		return CFrame.new(groundPoint) * baseRot
	end
	right = right.Unit
	local adjustedForward = up:Cross(right).Unit
	return CFrame.fromMatrix(groundPoint, right, up, -adjustedForward)
end

return MapZoneBuilder
