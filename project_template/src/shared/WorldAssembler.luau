--!strict
-- WorldAssembler.luau — Módulo Maestro RAASE 3.0
-- Ensamblado declarativo de mundos con anclaje físico por Raycast vertical hacia abajo,
-- compensación exacta de Bounding Box (GetExtentsSize), alineación opcional a pendientes,
-- snapping determinista a grilla y SmartUpsert (RN-10 Soberanía del Creador).

local Types = require(script.Parent.Types)

export type GroundPlacementOptions = Types.GroundPlacementOptions

local WorldAssembler = {}

--[[
	Cuantiza las coordenadas X y Z al múltiplo más cercano de gridStep (en studs),
	preservando la coordenada Y para el cálculo posterior de asentamiento por Raycast.
]]
function WorldAssembler.SnapVector3(position: Vector3, gridStep: number?): Vector3
	local step = gridStep or 0
	if step <= 0 then
		return position
	end
	local snappedX = math.round(position.X / step) * step
	local snappedZ = math.round(position.Z / step) * step
	return Vector3.new(snappedX, position.Y, snappedZ)
end

local function computeInstanceHeight(instance: PVInstance): number
	if instance:IsA("Model") then
		return instance:GetExtentsSize().Y
	elseif instance:IsA("BasePart") then
		return instance.Size.Y
	end
	return 0
end

local function buildSlopeAlignedCFrame(position: Vector3, surfaceNormal: Vector3, currentCFrame: CFrame): CFrame
	local upVector = surfaceNormal.Unit
	local currentLook = currentCFrame.LookVector
	local rightVector = currentLook:Cross(upVector)
	if rightVector.Magnitude < 0.001 then
		rightVector = Vector3.new(1, 0, 0):Cross(upVector)
	end
	rightVector = rightVector.Unit
	local backVector = rightVector:Cross(upVector).Unit
	return CFrame.fromMatrix(position, rightVector, upVector, backVector)
end

--[[
	Posiciona un Model o BasePart exactamente sobre la superficie física (Terrain o arquitectura)
	disparando un Raycast vertical hacia abajo y compensando la mitad de su altura (GetExtentsSize().Y / 2).
	Elimina el anti-patrón de props flotantes o enterrados en terreno irregular.
]]
function WorldAssembler.PlaceGrounded(
	model: PVInstance,
	position: Vector3,
	options: GroundPlacementOptions?
): CFrame
	local opts: GroundPlacementOptions = options or {}
	local snappedPos = WorldAssembler.SnapVector3(position, opts.GridSnap)
	local raycastHeight = opts.RaycastHeight or 250
	local raycastDepth = opts.RaycastDepth or 600
	local verticalOffset = opts.VerticalOffset or 0

	local filterList: { Instance } = { model }
	if opts.FilterExclude then
		for _, inst in opts.FilterExclude do
			table.insert(filterList, inst)
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = filterList
	rayParams.IgnoreWater = true

	local rayOrigin = Vector3.new(snappedPos.X, snappedPos.Y + raycastHeight, snappedPos.Z)
	local rayDirection = Vector3.new(0, -(raycastHeight + raycastDepth), 0)
	local hitResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)

	local extentsHeight = computeInstanceHeight(model)
	local halfHeight = extentsHeight * 0.5

	local currentPivot = model:GetPivot()
	local targetCFrame: CFrame

	if hitResult then
		local groundedPos = Vector3.new(
			snappedPos.X,
			hitResult.Position.Y + halfHeight + verticalOffset,
			snappedPos.Z
		)
		if opts.AlignToSlope then
			targetCFrame = buildSlopeAlignedCFrame(groundedPos, hitResult.Normal, currentPivot)
		else
			targetCFrame = currentPivot.Rotation + groundedPos
		end
	else
		local fallbackPos = Vector3.new(snappedPos.X, snappedPos.Y + halfHeight + verticalOffset, snappedPos.Z)
		targetCFrame = currentPivot.Rotation + fallbackPos
	end

	model:PivotTo(targetCFrame)
	return targetCFrame
end

--[[
	Implementa RN-10 (Soberanía del Creador / SmartUpsert):
	- Si ya existe una instancia con `name` en `parent` y tiene el atributo `RAASE_Locked == true`
	  (o `options.PreserveExistingTransform == true`), preserva su CFrame/Pivot manual del creador.
	- De lo contrario, clona o actualiza la instancia y la asienta sobre el terreno vía PlaceGrounded.
]]
function WorldAssembler.SmartUpsert(
	parent: Instance,
	template: Model,
	name: string,
	targetPosition: Vector3,
	options: GroundPlacementOptions?
): Model
	local opts: GroundPlacementOptions = options or {}
	local existing = parent:FindFirstChild(name)

	if existing and existing:IsA("Model") then
		local isLocked = existing:GetAttribute("RAASE_Locked") == true or opts.PreserveExistingTransform == true
		if isLocked then
			return existing
		end
		WorldAssembler.PlaceGrounded(existing, targetPosition, opts)
		return existing
	end

	local clone = template:Clone()
	clone.Name = name
	clone:SetAttribute("RAASE_Managed", true)
	clone.Parent = parent
	WorldAssembler.PlaceGrounded(clone, targetPosition, opts)
	return clone
end

return WorldAssembler
