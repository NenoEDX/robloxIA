--!strict
-- VoxelTerrainBuilder.luau — Módulo Maestro RAASE 3.0
-- Síntesis procedural de terreno de vóxeles suaves con FBM Perlin (4-6 octavas),
-- ocupancia fraccional continua [0, 1], asignación de materiales por pendiente/altitud
-- y esculpido de caminos mediante ReadVoxels / WriteVoxels a resolución 4x4x4 studs.

local Types = require(script.Parent.Types)

export type VoxelTerrainConfig = Types.VoxelTerrainConfig

local VoxelTerrainBuilder = {}

local VOXEL_RESOLUTION = 4

local function create3DTable<T>(sizeX: number, sizeY: number, sizeZ: number, defaultValue: T): { { { T } } }
	local grid = table.create(sizeX)
	for x = 1, sizeX do
		local colY = table.create(sizeY)
		for y = 1, sizeY do
			colY[y] = table.create(sizeZ, defaultValue)
		end
		grid[x] = colY
	end
	return grid
end

--[[
	Evalúa ruido Perlin Fractal Brownian Motion (FBM) 2D normalizado en aproximadamente [-1, 1].
	Usa 4 a 6 octavas superpuestas con persistencia y lacunaridad configurables.
]]
function VoxelTerrainBuilder.SampleFBM2D(
	worldX: number,
	worldZ: number,
	seed: number,
	octaves: number?,
	lacunarity: number?,
	persistence: number?,
	baseScale: number?
): number
	local numOctaves = math.clamp(octaves or 5, 1, 8)
	local lac = lacunarity or 2.0
	local pers = persistence or 0.5
	local scale = math.max(baseScale or 180.0, 0.001)

	local total = 0.0
	local frequency = 1.0 / scale
	local amplitude = 1.0
	local maxAmplitude = 0.0

	for i = 1, numOctaves do
		local seedOffset = seed + (i * 137.5)
		local n = math.noise(worldX * frequency + seedOffset, worldZ * frequency - seedOffset, seed * 0.13)
		total += n * amplitude
		maxAmplitude += amplitude
		amplitude *= pers
		frequency *= lac
	end

	if maxAmplitude <= 0 then
		return 0
	end
	return math.clamp(total / maxAmplitude, -1, 1)
end

--[[
	Genera terreno de vóxeles suaves sobre workspace.Terrain usando Region3:ExpandToGrid(4),
	ocupancia fraccional continua [0, 1] (sin escalonado "Minecraft") y selección automática
	de materiales según altitud y gradiente (pendiente).
]]
function VoxelTerrainBuilder.GenerateFBM(config: VoxelTerrainConfig): Region3
	local terrain = workspace.Terrain
	local region = Region3.new(config.RegionMin, config.RegionMax):ExpandToGrid(VOXEL_RESOLUTION)

	local seed = config.Seed or 1337
	local octaves = math.clamp(config.Octaves or 5, 4, 6)
	local lacunarity = config.Lacunarity or 2.05
	local persistence = config.Persistence or 0.48
	local baseScale = config.BaseScale or 220
	local amplitude = config.Amplitude or 64
	local baseHeight = config.BaseHeight or 16
	local waterLevel = config.WaterLevel or 8
	local snowHeight = config.SnowHeight or (baseHeight + amplitude * 0.72)
	local steepSlope = config.SteepSlopeThreshold or 0.62
	local chunkSize = math.max(config.ChunkSizeVoxels or 32, 8)

	local regionCFrame = region.CFrame
	local regionSize = region.Size
	local minCorner = regionCFrame.Position - (regionSize * 0.5)

	local totalVoxelsX = math.round(regionSize.X / VOXEL_RESOLUTION)
	local totalVoxelsY = math.round(regionSize.Y / VOXEL_RESOLUTION)
	local totalVoxelsZ = math.round(regionSize.Z / VOXEL_RESOLUTION)

	local function getHeightAt(wx: number, wz: number): number
		local fbm = VoxelTerrainBuilder.SampleFBM2D(wx, wz, seed, octaves, lacunarity, persistence, baseScale)
		return baseHeight + fbm * amplitude
	end

	for startX = 0, totalVoxelsX - 1, chunkSize do
		local countX = math.min(chunkSize, totalVoxelsX - startX)
		for startZ = 0, totalVoxelsZ - 1, chunkSize do
			local countZ = math.min(chunkSize, totalVoxelsZ - startZ)

			local chunkMin = minCorner
				+ Vector3.new(startX * VOXEL_RESOLUTION, 0, startZ * VOXEL_RESOLUTION)
			local chunkMax = chunkMin
				+ Vector3.new(countX * VOXEL_RESOLUTION, totalVoxelsY * VOXEL_RESOLUTION, countZ * VOXEL_RESOLUTION)
			local chunkRegion = Region3.new(chunkMin, chunkMax):ExpandToGrid(VOXEL_RESOLUTION)

			local materials = create3DTable(countX, totalVoxelsY, countZ, Enum.Material.Air)
			local occupancies = create3DTable(countX, totalVoxelsY, countZ, 0)

			for vx = 1, countX do
				local worldX = chunkMin.X + (vx - 0.5) * VOXEL_RESOLUTION
				for vz = 1, countZ do
					local worldZ = chunkMin.Z + (vz - 0.5) * VOXEL_RESOLUTION

					local surfaceHeight = getHeightAt(worldX, worldZ)
					local hDx = getHeightAt(worldX + VOXEL_RESOLUTION, worldZ) - surfaceHeight
					local hDz = getHeightAt(worldX, worldZ + VOXEL_RESOLUTION) - surfaceHeight
					local slope = math.sqrt(hDx * hDx + hDz * hDz) / VOXEL_RESOLUTION

					local surfaceMaterial = Enum.Material.Grass
					if slope >= steepSlope then
						surfaceMaterial = Enum.Material.Rock
					elseif surfaceHeight <= waterLevel + 3.5 then
						surfaceMaterial = Enum.Material.Sand
					elseif surfaceHeight >= snowHeight then
						surfaceMaterial = Enum.Material.Snow
					end

					for vy = 1, totalVoxelsY do
						local voxelBottomY = chunkMin.Y + (vy - 1) * VOXEL_RESOLUTION
						local voxelCenterY = voxelBottomY + (VOXEL_RESOLUTION * 0.5)

						-- Ocupancia fraccional continua en [0, 1] para suavizado orgánico de vóxeles
						local rawOccupancy = (surfaceHeight - voxelBottomY) / VOXEL_RESOLUTION
						local occ = math.clamp(rawOccupancy, 0, 1)

						if occ > 0 then
							occupancies[vx][vy][vz] = occ
							if surfaceHeight - voxelCenterY > VOXEL_RESOLUTION * 2.5 then
								materials[vx][vy][vz] = Enum.Material.Rock
							else
								materials[vx][vy][vz] = surfaceMaterial
							end
						elseif voxelCenterY <= waterLevel then
							occupancies[vx][vy][vz] = 1
							materials[vx][vy][vz] = Enum.Material.Water
						end
					end
				end
			end

			terrain:WriteVoxels(chunkRegion, VOXEL_RESOLUTION, materials, occupancies)
			task.wait()
		end
	end

	return region
end

--[[
	Esculpe y aplana un camino orgánico sobre el terreno existente interpolando entre
	una secuencia de puntos 3D, leyendo los vóxeles actuales (ReadVoxels), suavizando la
	ocupancia fraccional y pintando el material de calzada (por defecto Cobblestone).
]]
function VoxelTerrainBuilder.CarveRoadPath(
	points: { Vector3 },
	widthStuds: number,
	roadMaterial: Enum.Material?
)
	if #points < 2 then
		return
	end

	local terrain = workspace.Terrain
	local matRoad = roadMaterial or Enum.Material.Cobblestone
	local halfWidth = math.max(widthStuds * 0.5, VOXEL_RESOLUTION)
	local blendMargin = VOXEL_RESOLUTION * 1.5

	for i = 1, #points - 1 do
		local p0 = points[i]
		local p1 = points[i + 1]
		local segDelta = p1 - p0
		local segLen = segDelta.Magnitude
		if segLen > 0.01 then
			local padding = halfWidth + blendMargin + VOXEL_RESOLUTION
			local minBounds = Vector3.new(
				math.min(p0.X, p1.X) - padding,
				math.min(p0.Y, p1.Y) - VOXEL_RESOLUTION * 3,
				math.min(p0.Z, p1.Z) - padding
			)
			local maxBounds = Vector3.new(
				math.max(p0.X, p1.X) + padding,
				math.max(p0.Y, p1.Y) + VOXEL_RESOLUTION * 4,
				math.max(p0.Z, p1.Z) + padding
			)

			local region = Region3.new(minBounds, maxBounds):ExpandToGrid(VOXEL_RESOLUTION)
			local materials, occupancies, resolution = terrain:ReadVoxels(region, VOXEL_RESOLUTION)
			local size = materials.Size
			local regionMin = region.CFrame.Position - (region.Size * 0.5)

			local seg2D = Vector2.new(p1.X - p0.X, p1.Z - p0.Z)
			local segLenSq2D = math.max(seg2D.X * seg2D.X + seg2D.Y * seg2D.Y, 0.0001)

			for vx = 1, size.X do
				local wx = regionMin.X + (vx - 0.5) * resolution
				for vz = 1, size.Z do
					local wz = regionMin.Z + (vz - 0.5) * resolution

					local rel2D = Vector2.new(wx - p0.X, wz - p0.Z)
					local t = math.clamp((rel2D.X * seg2D.X + rel2D.Y * seg2D.Y) / segLenSq2D, 0, 1)
					local closestX = p0.X + seg2D.X * t
					local closestZ = p0.Z + seg2D.Y * t
					local targetRoadY = p0.Y + (p1.Y - p0.Y) * t

					local dist2D = math.sqrt((wx - closestX) ^ 2 + (wz - closestZ) ^ 2)
					if dist2D <= halfWidth + blendMargin then
						local roadWeight = 1.0
						if dist2D > halfWidth then
							roadWeight = 1.0 - math.clamp((dist2D - halfWidth) / blendMargin, 0, 1)
						end

						for vy = 1, size.Y do
							local voxelBottomY = regionMin.Y + (vy - 1) * resolution
							local desiredOcc = math.clamp((targetRoadY - voxelBottomY) / resolution, 0, 1)
							local currentOcc = occupancies[vx][vy][vz]
							local blendedOcc = currentOcc + (desiredOcc - currentOcc) * roadWeight
							occupancies[vx][vy][vz] = blendedOcc

							if roadWeight >= 0.45 and desiredOcc > 0.05 and desiredOcc <= 1.0 then
								if voxelBottomY + resolution >= targetRoadY - resolution then
									materials[vx][vy][vz] = matRoad
								end
							elseif blendedOcc <= 0.01 then
								materials[vx][vy][vz] = Enum.Material.Air
								occupancies[vx][vy][vz] = 0
							end
						end
					end
				end
			end

			terrain:WriteVoxels(region, VOXEL_RESOLUTION, materials, occupancies)
			task.wait()
		end
	end
end

return VoxelTerrainBuilder
